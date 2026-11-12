param([Parameter(Mandatory)][string]$Zip)
$ErrorActionPreference = 'Stop'
$zipPath = (Resolve-Path -LiteralPath $Zip).ProviderPath
$manifest = Get-Content -LiteralPath "$zipPath.manifest.json" -Raw | ConvertFrom-Json
$fixture = Join-Path (Resolve-Path -LiteralPath "$PSScriptRoot/../build").ProviderPath ('installer-test-' + [guid]::NewGuid().ToString('N'))
$expanded = Join-Path $fixture 'extracted download [1]!'
$download = Join-Path $fixture 'ZIP download [2]!'
$loader = 'ProjectPBZ/PBZModLoader'
$manager = 'ProjectPBZ/Content/JavaScript/PBZModLoader/manager.js'
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Directory]::CreateDirectory($download) | Out-Null
[IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $expanded)
Copy-Item -LiteralPath (Join-Path $expanded 'PBZModLoader-Install.cmd'), $zipPath -Destination $download
$expandedCmd = Join-Path $expanded 'PBZModLoader-Install.cmd'
$zipCmd = Join-Path $download 'PBZModLoader-Install.cmd'

function New-Game($name, $platform) {
    $root = Join-Path $fixture "$name [game]!"
    [void][IO.Directory]::CreateDirectory((Join-Path $root 'ProjectPBZ'))
    [void][IO.Directory]::CreateDirectory((Join-Path $root "platform/$platform"))
    [IO.File]::WriteAllText((Join-Path $root "platform/$platform/PBZ.exe"), 'fixture, never executed')
    $root
}

function Invoke-Installer($cmd, $game, $expected) {
    $output = & $cmd $game -NoPause
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
[void][IO.Directory]::CreateDirectory((Join-Path $update "$loader/mods/user-mod"))
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName((Join-Path $update $manager)))
[IO.File]::WriteAllText((Join-Path $update "$loader/mods.ini"), 'user configuration')
[IO.File]::WriteAllText((Join-Path $update "$loader/mods/user-mod/main.js"), 'user mod')
[IO.File]::WriteAllText((Join-Path $update $manager), 'old manager')
Invoke-Installer $zipCmd $update 0 | Out-Null
Assert-Text $dll 'other tool'
Assert-Text (Join-Path $update "$loader/mods.ini") 'user configuration'
Assert-Text (Join-Path $update "$loader/mods/user-mod/main.js") 'user mod'
Assert-Hash (Join-Path $update $manager) $manager
Assert-Hash (Join-Path $update 'platform/steam/hid.dll') '备用入口/hid.dll'
$backup = Get-ChildItem -LiteralPath (Join-Path $update 'PBZModLoader-Backups') -Directory
Assert-Text (Join-Path $backup.FullName $manager) 'old manager'
Write-Output 'PASS update retains a known alternate entry, foreign DLL, configuration, and mods; replaced files are backed up'

$conflict = New-Game 'unrecognized entry' 'steam'
$dll = Join-Path $conflict 'platform/steam/version.dll'
[IO.File]::WriteAllText($dll, 'unrecognized DLL')
Invoke-Installer $expandedCmd $conflict 1 | Out-Null
Assert-Text $dll 'unrecognized DLL'
Assert-Absent (Join-Path $conflict $loader)
Copy-Item -LiteralPath (Join-Path $expanded 'platform/steam/version.dll') -Destination $dll -Force
Copy-Item -LiteralPath (Join-Path $expanded '备用入口/hid.dll') -Destination (Join-Path $conflict 'platform/steam/hid.dll')
Invoke-Installer $expandedCmd $conflict 1 | Out-Null
Assert-Hash $dll 'platform/steam/version.dll'
Assert-Hash (Join-Path $conflict 'platform/steam/hid.dll') '备用入口/hid.dll'
Assert-Absent (Join-Path $conflict $loader)
Write-Output 'PASS unknown DLL ownership and multiple loader entries fail without changing the game'

$rollback = New-Game 'rollback' 'steam'
$blocked = Join-Path $rollback "$loader/compiler/tsc.exe"
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($blocked))
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName((Join-Path $rollback $manager)))
[IO.File]::WriteAllText($blocked, 'locked compiler')
[IO.File]::WriteAllText((Join-Path $rollback $manager), 'old manager')
$handle = [IO.File]::Open($blocked, 'Open', 'Read', 'Read')
try { Invoke-Installer $expandedCmd $rollback 1 | Out-Null } finally { $handle.Dispose() }
Assert-Text $blocked 'locked compiler'
Assert-Text (Join-Path $rollback $manager) 'old manager'
Assert-Absent (Join-Path $rollback 'platform/steam/version.dll')
Assert-Absent (Join-Path $rollback "$loader/compiler/lib.d.ts")
Assert-Absent (Join-Path $rollback 'PBZModLoader-Backups')
Write-Output 'PASS a locked file triggers rollback of prior replacements and additions'

Copy-Item -LiteralPath $zipPath -Destination (Join-Path $download 'duplicate.zip')
$duplicate = New-Game 'two packages' 'steam'
Invoke-Installer $zipCmd $duplicate 1 | Out-Null
Assert-Absent (Join-Path $duplicate $loader)
Write-Output 'PASS ambiguous ZIP selection fails without writing game files'
Write-Output "Fixtures: $fixture"
