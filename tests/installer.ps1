param(
    [Parameter(Mandatory)][string]$Zip,
    [Parameter(Mandatory)][string]$InstallerZip
)
$ErrorActionPreference = 'Stop'
if (Get-Process -Name PBZ -ErrorAction SilentlyContinue) {
    throw 'Close the game before running installer integration tests.'
}
$zipPath = (Resolve-Path -LiteralPath $Zip).ProviderPath
$manifest = Get-Content -LiteralPath "$zipPath.manifest.json" -Raw | ConvertFrom-Json
$installerPath = (Resolve-Path -LiteralPath $InstallerZip).ProviderPath
$installerManifest = Get-Content -LiteralPath "$installerPath.manifest.json" -Raw | ConvertFrom-Json
if ((Get-FileHash -LiteralPath $zipPath).Hash -ne $manifest.zipSha256 -or
    (Get-FileHash -LiteralPath $installerPath).Hash -ne $installerManifest.zipSha256) { throw 'ZIP hash mismatch' }
$build = [IO.Path]::GetFullPath("$PSScriptRoot/../build")
$fixture = Join-Path $build ('installer-test-' + [guid]::NewGuid().ToString('N'))
$expanded = Join-Path $fixture 'extracted download [1]!'
$download = Join-Path $fixture 'ZIP download [2]!'
$loader = 'ProjectPBZ/PBZModLoader'
$manager = 'ProjectPBZ/Content/JavaScript/PBZModLoader/manager.js'
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $expanded)
[IO.Compression.ZipFile]::ExtractToDirectory($installerPath, $download)
$expandedCmd = Join-Path $expanded 'PBZModLoader-Install.cmd'
$zipCmd = Join-Path $download 'PBZModLoader-Install.cmd'
Copy-Item -LiteralPath $zipCmd -Destination $expandedCmd -Force

function New-Game($name, $platform) {
    $root = Join-Path $fixture "$name [game]!"
    [void][IO.Directory]::CreateDirectory((Join-Path $root 'ProjectPBZ'))
    [void][IO.Directory]::CreateDirectory((Join-Path $root "platform/$platform"))
    [IO.File]::WriteAllText((Join-Path $root "platform/$platform/PBZ.exe"), 'fixture, never executed')
    $root
}

function Invoke-Installer($cmd, $game, $expected, [string[]]$answers = @()) {
    $output = if ($answers.Count) { $answers | & $cmd $game -NoPause } else { & $cmd $game -NoPause }
    if ($LASTEXITCODE -ne $expected) { throw "Unexpected installer result ($LASTEXITCODE) in ${game}: $output" }
    if (Get-ChildItem -LiteralPath $game -Force -Filter '.pbz-loader-install-*') { throw 'Temporary stage was not cleaned up' }
    $output
}

function Assert-Text($path, $expected) {
    if ([IO.File]::ReadAllText($path) -cne $expected) { throw "Unexpected file content: $path" }
}

function Assert-Hash($path, $relative) {
    $expected = $manifest.files.PSObject.Properties[$relative].Value
    if (!$expected -or (Get-FileHash -LiteralPath $path).Hash -ne $expected) { throw "Hash mismatch: $path" }
}

function Assert-Absent($path) {
    if (Test-Path -LiteralPath $path) { throw "Unexpected file or directory: $path" }
}

$missing = New-Game 'missing player ZIP' 'steam'
$output = Invoke-Installer $zipCmd $missing 1
if (!($output -match 'place it next to this script')) { throw 'Missing instructions for obtaining the player ZIP' }
Assert-Absent (Join-Path $missing $loader)
Copy-Item -LiteralPath $zipPath -Destination $download
Write-Output 'PASS standalone installer asks for the separate player ZIP'

$steam = New-Game 'clean Steam' 'steam'
Invoke-Installer $expandedCmd $steam 0 | Out-Null
foreach ($entry in $manifest.files.PSObject.Properties | Where-Object { $_.Name -like 'ProjectPBZ/*' -or $_.Name -eq 'platform/steam/version.dll' }) {
    Assert-Hash (Join-Path $steam $entry.Name) $entry.Name
}
if (!(Test-Path -LiteralPath (Join-Path $steam "$loader/mods") -PathType Container) -or
    (Get-ChildItem -LiteralPath (Join-Path $steam "$loader/mods") -Force)) { throw 'Fresh mods directory is missing or not empty' }
Assert-Absent (Join-Path $steam 'platform/wegame')
Assert-Absent (Join-Path $steam 'PBZModLoader-Backups')
Write-Output 'PASS extracted ZIP installs only the Steam payload and creates an empty mods directory'

$wegame = New-Game 'clean WeGame' 'wegame'
Invoke-Installer $zipCmd $wegame 0 | Out-Null
Assert-Hash (Join-Path $wegame 'platform/wegame/version.dll') 'platform/wegame/version.dll'
Assert-Hash (Join-Path $wegame "$loader/compiler/tsc.exe") "$loader/compiler/tsc.exe"
Assert-Absent (Join-Path $wegame 'platform/steam')
Write-Output 'PASS installer beside an unopened ZIP targets WeGame'

$update = New-Game 'update alternate entry' 'steam'
$dll = Join-Path $update 'platform/steam/version.dll'
[IO.File]::WriteAllText($dll, 'other tool')
Copy-Item -LiteralPath (Join-Path $expanded '备用入口/hid.dll') -Destination (Join-Path $update 'platform/steam/hid.dll')
Copy-Item -LiteralPath (Join-Path $expanded '备用入口/winmm.dll') -Destination (Join-Path $update 'platform/steam/winmm.dll')
[void][IO.Directory]::CreateDirectory((Join-Path $update "$loader/mods/user-mod"))
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName((Join-Path $update $manager)))
[IO.File]::WriteAllText((Join-Path $update "$loader/mods.ini"), 'user configuration')
[IO.File]::WriteAllText((Join-Path $update "$loader/mods/user-mod/main.js"), 'user mod')
[IO.File]::WriteAllText((Join-Path $update $manager), 'old manager')
Invoke-Installer $zipCmd $update 0 '1' | Out-Null
Assert-Text $dll 'other tool'
Assert-Text (Join-Path $update "$loader/mods.ini") 'user configuration'
Assert-Text (Join-Path $update "$loader/mods/user-mod/main.js") 'user mod'
Assert-Hash (Join-Path $update $manager) $manager
Assert-Hash (Join-Path $update 'platform/steam/hid.dll') '备用入口/hid.dll'
Assert-Absent (Join-Path $update 'platform/steam/winmm.dll')
$backup = Get-ChildItem -LiteralPath (Join-Path $update 'PBZModLoader-Backups') -Directory
Assert-Text (Join-Path $backup.FullName $manager) 'old manager'
Assert-Hash (Join-Path $backup.FullName 'platform/steam/winmm.dll') '备用入口/winmm.dll'
Write-Output 'PASS duplicate cleanup retains the selected alternate DLL, foreign DLL, configuration, and mods'

$conflict = New-Game 'unrecognized entry' 'steam'
$dll = Join-Path $conflict 'platform/steam/version.dll'
[IO.File]::WriteAllText($dll, 'unrecognized DLL')
Invoke-Installer $expandedCmd $conflict 1 | Out-Null
Assert-Text $dll 'unrecognized DLL'
Assert-Absent (Join-Path $conflict $loader)
Write-Output 'PASS unknown DLL ownership fails without changing the game'

$multiple = New-Game 'all five entries' 'steam'
$entries = @('version.dll', 'hid.dll', 'winmm.dll', 'dsound.dll', 'dxgi.dll')
foreach ($name in $entries) {
    $relative = if ($name -eq 'version.dll') { "platform/steam/$name" } else { "备用入口/$name" }
    Copy-Item -LiteralPath (Join-Path $expanded $relative) -Destination (Join-Path $multiple "platform/steam/$name")
}
$output = Invoke-Installer $expandedCmd $multiple 0 '0'
if (!($output -match 'Cancelled\.')) { throw 'Cancellation message missing' }
foreach ($name in $entries) {
    $relative = if ($name -eq 'version.dll') { "platform/steam/$name" } else { "备用入口/$name" }
    Assert-Hash (Join-Path $multiple "platform/steam/$name") $relative
}
Assert-Absent (Join-Path $multiple $loader)
Assert-Absent (Join-Path $multiple 'PBZModLoader-Backups')
$output = Invoke-Installer $expandedCmd $multiple 0 @('x', '6', '5')
if (@($output -match 'Invalid number').Count -ne 2 -or !($output -match '5\. dxgi\.dll')) {
    throw 'Expected all five choices and a retry after each invalid input'
}
Assert-Hash (Join-Path $multiple 'platform/steam/dxgi.dll') '备用入口/dxgi.dll'
Assert-Hash (Join-Path $multiple $manager) $manager
$backup = Get-ChildItem -LiteralPath (Join-Path $multiple 'PBZModLoader-Backups') -Directory
foreach ($name in $entries -ne 'dxgi.dll') {
    $relative = if ($name -eq 'version.dll') { "platform/steam/$name" } else { "备用入口/$name" }
    Assert-Absent (Join-Path $multiple "platform/steam/$name")
    Assert-Hash (Join-Path $backup.FullName "platform/steam/$name") $relative
}
Assert-Absent (Join-Path $backup.FullName 'platform/steam/dxgi.dll')
Write-Output 'PASS all five entries can be selected, invalid choices retry, and cancellation does not write files'

$rollback = New-Game 'rollback' 'steam'
$blocked = Join-Path $rollback "$loader/compiler/tsc.exe"
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($blocked))
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName((Join-Path $rollback $manager)))
[IO.File]::WriteAllText($blocked, 'locked compiler')
[IO.File]::WriteAllText((Join-Path $rollback $manager), 'old manager')
Copy-Item -LiteralPath (Join-Path $expanded 'platform/steam/version.dll') -Destination (Join-Path $rollback 'platform/steam/version.dll')
Copy-Item -LiteralPath (Join-Path $expanded '备用入口/hid.dll') -Destination (Join-Path $rollback 'platform/steam/hid.dll')
$handle = [IO.File]::Open($blocked, 'Open', 'Read', 'Read')
try { Invoke-Installer $expandedCmd $rollback 1 '1' | Out-Null } finally { $handle.Dispose() }
Assert-Text $blocked 'locked compiler'
Assert-Text (Join-Path $rollback $manager) 'old manager'
Assert-Hash (Join-Path $rollback 'platform/steam/version.dll') 'platform/steam/version.dll'
Assert-Hash (Join-Path $rollback 'platform/steam/hid.dll') '备用入口/hid.dll'
Assert-Absent (Join-Path $rollback "$loader/compiler/lib.d.ts")
Assert-Absent (Join-Path $rollback 'PBZModLoader-Backups')
Write-Output 'PASS a locked file rolls back duplicate cleanup, prior replacements, and additions'

$inside = New-Game 'installer inside game' 'wegame'
$nested = Join-Path $inside 'PBZModLoader download'
[void][IO.Directory]::CreateDirectory($nested)
foreach ($folder in $inside, $nested) {
    $insideCmd = Join-Path $folder 'PBZModLoader-Install.cmd'
    Copy-Item -LiteralPath $expandedCmd -Destination $insideCmd
    $output = Invoke-Installer $insideCmd $inside 1
    if ($output -notcontains "脚本所在目录 / Installer folder: $folder" -or
        $output -notcontains "目标游戏根目录 / Game root: $inside") { throw 'Missing source or target path in location error' }
}
$exeFolder = Join-Path $inside 'platform\wegame'
$output = Invoke-Installer $expandedCmd $exeFolder 1
if ($output -notcontains "所选目录 / Selected folder: $exeFolder" -or
    !($output -match 'game root containing both ProjectPBZ and platform')) { throw 'Missing guidance for selecting the game root' }
Assert-Absent (Join-Path $inside $loader)
Write-Output 'PASS the installer shows both locations for an in-game extraction and guides users who select the EXE folder'

Copy-Item -LiteralPath $zipPath -Destination (Join-Path $download 'duplicate.zip')
$duplicate = New-Game 'two packages' 'steam'
Invoke-Installer $zipCmd $duplicate 1 | Out-Null
Assert-Absent (Join-Path $duplicate $loader)
Write-Output 'PASS ambiguous ZIP selection fails without writing game files'
Write-Output "Fixtures: $fixture"
