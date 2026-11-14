param([string]$Version = '1.0.0')
$ErrorActionPreference = 'Stop'
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Invalid installer version' }

$zip = Join-Path $PSScriptRoot "releases/PBZModLoader-Installer-$Version.zip"
$manifest = "$zip.manifest.json"
if ((Test-Path -LiteralPath $zip) -or (Test-Path -LiteralPath $manifest)) {
    throw 'Installer release already exists. Choose a new installer version.'
}
$files = 'PBZModLoader-Install.cmd', 'PBZModLoader-Installer-README.txt'
$hashes = [ordered]@{}
foreach ($name in $files) {
    $source = Join-Path "$PSScriptRoot/runtime" $name
    $hashes[$name] = (Get-FileHash -LiteralPath $source).Hash.ToLowerInvariant()
}
[void][IO.Directory]::CreateDirectory((Split-Path -Parent $zip))
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::Open($zip, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($name in $files) {
        [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, (Join-Path "$PSScriptRoot/runtime" $name), $name)
    }
} finally { $archive.Dispose() }

$archive = [IO.Compression.ZipFile]::OpenRead($zip)
try {
    if (Compare-Object $files @($archive.Entries.FullName)) { throw 'Installer ZIP entry allowlist mismatch' }
    foreach ($name in $files) {
        $stream = $archive.GetEntry($name).Open()
        try {
            if ((Get-FileHash -InputStream $stream).Hash -ne $hashes[$name]) { throw "Installer ZIP hash mismatch: $name" }
        } finally { $stream.Dispose() }
    }
} finally { $archive.Dispose() }

[ordered]@{ version = $Version; zipSha256 = (Get-FileHash -LiteralPath $zip).Hash.ToLowerInvariant(); files = $hashes; verified = $true } |
    ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $manifest -Encoding utf8
Write-Output "PASS standalone installer ZIP allowlist and SHA-256 checks"
Write-Output $zip
