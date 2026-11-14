@echo off
setlocal DisableDelayedExpansion
chcp 65001 >nul
set "PBZ_LOADER_INSTALL_SCRIPT=%~f0"
set "PBZ_LOADER_INSTALL_GAME=%~1"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -Sta -Command "$source = [IO.File]::ReadAllText($env:PBZ_LOADER_INSTALL_SCRIPT); & ([scriptblock]::Create(($source -split '(?m)^:POWERSHELL\r?$', 2)[1]))"
set "PBZ_LOADER_INSTALL_RESULT=%ERRORLEVEL%"
if /I not "%~2"=="-NoPause" pause
exit /b %PBZ_LOADER_INSTALL_RESULT%
:POWERSHELL
$ErrorActionPreference = 'Stop'
$loader = 'ProjectPBZ/PBZModLoader'
$scripts = 'ProjectPBZ/Content/JavaScript/PBZModLoader'
$alternates = 'hid.dll', 'winmm.dll', 'dsound.dll', 'dxgi.dll'

# SHA-256 by filename from previously shipped PBZModLoader release manifests.
# Add hashes from newly shipped builds before publishing a later installer.
$known = @{
    'version.dll' = @(
        '2b08fe18fdae8297fa6ea9daf09682d801d2cd359acd685c63d81517a9ee28f4'
        '13fd9a72d02f0e717204b0c56c8360f1a46caecdb929c2386f9132e49c0c9d39'
        'a7d2aea139142e21d0628ecebed7984204a156709cd4ec228520e866f420f8c0'
        '643fde8f9a3c800203c2caa879ba0fed58c772c4fc5b599a7032f87f69c98044'
        '7f60504084f97ba9d9092a6e3f531d0c6bd8c0a7563a6c9e6c6438d54e9e7a13'
        'e6fe38aa0011167a5dbced3fa4b8f0eb4b806aad27228544b7420eea31c56ccf'
        '75766784da0e21ab68253fe664df4636389715fe63548184a7ff812d7a6e0741'
    )
    'hid.dll' = @(
        '423b54a581690490b7da605e8387b05eafdc66818408209085cd66bb18cee7c0'
        'cc4f0acdcdf632a21878f0f54ece8e33248898b24efc29ed6c9503a4fb32075d'
        'b0ff0c66f1e6a81084f0cd559994d15269dde3041bd6de01435245bc67737537'
        'a10e82c78e624aca1561edc1b513cb86ea83a3214735e327a14f319cd3b18ec4'
        'a55f39364b85299dd2f9ace46fc17fd1698065919d4ad363ceca41364c8af51d'
    )
    'winmm.dll' = @(
        'c6f8564dec7a08f1ffa9c66560d1350c7c60b9753a4f459d3b00255c048d88bc'
        '80950ee58c679072eb1a4d04b2bbb7da898817507b272b2638cc1a236b999f77'
        'bbe57299ba6e42d987d644b2e9a275f0c5574bb52f7b68d6dd4c3d389645d3d9'
        'cc4d417d786b4972a01fb7aa51c35785d4eef7ff981056e08942f1a7a63b15ad'
        '96e85aae102be347326ba98f4b163829f4278b3455ec53d48773eeb18c3bb0ff'
    )
    'dsound.dll' = @(
        'c7a731ce1e88d7b1f1be4584edb489c8418652ac9ad01e0d470e1b2f3fe7bb93'
        '101af776588d5af909c0fa9d6eff0ee4bf671f4b7b12bc36081c339cd50d60eb'
        'f2bfa297f3abb8d9c5b10065a1003844c4c09e615b36e23f88d7d927e339920f'
        'd628b6690b02c5e72fa1b6d46b91e586af5a39d22c45892d50867ff5a1f0387e'
        '34f061d91f22e7d0042622091ecaa8ad9c0e9dba52b111cdc40f8922aafcce34'
    )
    'dxgi.dll' = @(
        'b05e83de20aa8a20c7d619632039ac38feb43ac87e55016b483cae94db92ff43'
        'd57d16e4f665c6683b5fcb81c4ac24b602cdf9de121820dd6517ce8015be040f'
        'ad3ec5a50c1d3c0f8c51ea0d6bed0e233277dc54b976076bc4ac76b8d8bf4f31'
        '193a050932830e2b12969f78846608a4c6264c18b3c6d21a537f145b7b598521'
        'a5d0507a867984a06ca1965b7c94d02b3f2c8976635eed836e8fdd0da4a68f71'
    )
}

function Get-GamePlatforms($root) {
    if (Test-Path -LiteralPath (Join-Path $root 'ProjectPBZ') -PathType Container) {
        'steam', 'wegame' | Where-Object {
            Test-Path -LiteralPath (Join-Path $root "platform/$_/PBZ.exe") -PathType Leaf
        }
    }
}

function Find-SteamGame {
    $libraries = foreach ($key in 'HKCU:/Software/Valve/Steam', 'HKLM:/Software/WOW6432Node/Valve/Steam', 'HKLM:/Software/Valve/Steam') {
        $reg = Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
        $steam = if ($reg.SteamPath) { $reg.SteamPath } else { $reg.InstallPath }
        if (!$steam) { continue }
        $steam
        $vdf = Join-Path $steam 'steamapps/libraryfolders.vdf'
        if ([IO.File]::Exists($vdf)) {
            foreach ($match in [regex]::Matches([IO.File]::ReadAllText($vdf), '"path"\s+"([^"]+)"')) {
                $match.Groups[1].Value.Replace('\\', '\')
            }
        }
    }
    foreach ($library in $libraries | Sort-Object -Unique) {
        $manifest = Join-Path $library 'steamapps/appmanifest_4115450.acf'
        if ([IO.File]::Exists($manifest) -and [IO.File]::ReadAllText($manifest) -match '"installdir"\s+"([^"\\/:]+)"') {
            $folder = Join-Path $library "steamapps/common/$($Matches[1])"
            if (@(Get-GamePlatforms $folder) -contains 'steam') { (Get-Item -LiteralPath $folder).FullName }
        }
    }
}

function Select-GameFolder {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object Windows.Forms.FolderBrowserDialog
    try {
        $dialog.Description = '请选择同时包含 ProjectPBZ 和 platform 的游戏根目录 / Select the game root containing both ProjectPBZ and platform'
        $dialog.ShowNewFolderButton = $false
        if ($dialog.ShowDialog() -eq 'OK') { $dialog.SelectedPath }
    } finally { $dialog.Dispose() }
}

function Select-LoaderEntry($entries, $exeDir, $backupDir) {
    Write-Host '在 PBZ.exe 旁检测到多个已确认的 PBZModLoader 入口。 / Multiple confirmed PBZModLoader entries were found beside PBZ.exe.'
    Write-Host "PBZ.exe 所在目录 / Executable folder: $exeDir"
    Write-Host '请选择要保留并升级的入口，其余已确认的入口会移入备份后继续安装。 / Choose one entry to keep and update. The installer will move the other confirmed entries to the backup folder and continue.'
    Write-Host "备份目录 / Backup folder: $backupDir"
    for ($i = 0; $i -lt $entries.Count; $i++) {
        Write-Host "  $($i + 1). $($entries[$i])"
    }
    Write-Host '  0. 取消安装 / Cancel installation'
    while ($true) {
        Write-Host '输入编号并按 Enter / Enter a number and press Enter'
        $answer = [Console]::ReadLine()
        if ([string]::IsNullOrWhiteSpace($answer)) { return }
        $number = 0
        if ([int]::TryParse($answer, [ref]$number) -and $number -ge 0 -and $number -le $entries.Count) {
            if ($number -gt 0) { return $entries[$number - 1] }
            return
        }
        Write-Host '编号无效，请重新输入。 / Invalid number. Try again.'
    }
}

function Assert-GameClosed {
    if (Get-Process -Name PBZ -ErrorAction SilentlyContinue) {
        throw '请先退出游戏，再运行安装器。 / Close the game before installing.'
    }
}

function Assert-Path($path, [switch]$Directory) {
    for ($current = $path; $current; $current = [IO.Path]::GetDirectoryName($current)) {
        $item = Get-Item -LiteralPath $current -Force -ErrorAction SilentlyContinue
        if (!$item) { continue }
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw "安装路径包含符号链接或目录联接 / Linked install path: $current"
        }
        $expectDirectory = $Directory -or $current -ne $path
        if ($item.PSIsContainer -ne $expectDirectory) {
            throw "文件与目录冲突 / File or directory conflict: $current"
        }
    }
}

function Get-Hash($source) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $stream = if ($source -is [IO.FileInfo]) { $source.OpenRead() } else { $source.Open() }
        try { [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
        finally { $stream.Dispose() }
    } finally { $sha.Dispose() }
}

function New-InstallDirectory($path, $undo) {
    if ([IO.Directory]::Exists($path)) { return }
    New-InstallDirectory ([IO.Path]::GetDirectoryName($path)) $undo
    [void][IO.Directory]::CreateDirectory($path)
    $undo.Push(@{ Directory = $path })
}

$zip = $null
$stage = $null
$mutex = $null
$locked = $false
$exitCode = 0
try {
    Assert-GameClosed
    $downloads = [IO.Path]::GetDirectoryName($env:PBZ_LOADER_INSTALL_SCRIPT)
    $game = $env:PBZ_LOADER_INSTALL_GAME
    if (!$game) {
        $games = @(Find-SteamGame | Sort-Object -Unique)
        if ($games.Count -eq 1) { $game = $games[0] } else { $game = Select-GameFolder }
    }
    if (!$game) { Write-Host '已取消 / Cancelled.'; exit 0 }
    $target = Get-Item -LiteralPath $game -Force -ErrorAction SilentlyContinue
    if (!$target -or !$target.PSIsContainer) {
        throw "找不到游戏目录 / Game folder not found: $game`n请选择同时包含 ProjectPBZ 和 platform 的游戏根目录。 / Select the game root containing both ProjectPBZ and platform."
    }
    $game = $target.FullName
    $gamePrefix = $game.TrimEnd('\') + '\'
    $platforms = @(Get-GamePlatforms $game)
    if ($platforms.Count -ne 1) {
        throw "所选目录 / Selected folder: $game`n请选择同时包含 ProjectPBZ 和 platform 的游戏根目录；PBZ.exe 应位于 platform\steam 或 platform\wegame。 / Select the game root containing both ProjectPBZ and platform. PBZ.exe should be under platform\steam or platform\wegame."
    }
    if ($downloads.StartsWith($gamePrefix, [StringComparison]::OrdinalIgnoreCase) -or $downloads -eq $game -or
        @(Get-GamePlatforms $downloads).Count) {
        throw "脚本所在目录 / Installer folder: $downloads`n目标游戏根目录 / Game root: $game`n请将安装器解压到游戏目录之外（例如下载文件夹），将玩家主包 ZIP 放在 PBZModLoader-Install.cmd 旁，从那里运行脚本。如需选择安装位置，请选择上面的游戏根目录。 / Extract the installer outside the game, such as in Downloads. Put the player ZIP beside PBZModLoader-Install.cmd and run the script there. If prompted, select the game root shown above."
    }
    Assert-Path $game -Directory
    $platformDir = "platform/$($platforms[0])"
    Assert-Path (Join-Path $game "$platformDir/PBZ.exe")
    $ini = "$loader/mods.ini"
    $legacy = Join-Path $game 'ProjectPBZ/Mods/PBZModLoader'
    if ((Test-Path -LiteralPath $legacy) -and ![IO.File]::Exists((Join-Path $game $ini))) {
        throw '检测到旧版配置目录，请先按安装说明迁移。 / Follow the manual guide to migrate the legacy loader directory first.'
    }

    $mutex = [Threading.Mutex]::new($false, 'Local\PBZModLoaderInstaller')
    try { $locked = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $locked = $true }
    if (!$locked) { throw '安装器已在运行。 / Another installer is running.' }

    $proxies = @{ 'version.dll' = "$platformDir/version.dll" }
    foreach ($name in $alternates) { $proxies[$name] = "备用入口/$name" }
    $required = @($ini, "$loader/TOOLCHAIN-LICENSE.txt", "$scripts/bootstrap.js", "$scripts/manager.js",
        "$loader/compiler/tsc.exe", "$loader/compiler/LICENSE", "$loader/compiler/NOTICE.txt", "$loader/compiler/lib.d.ts") + @($proxies.Values)
    $compilerLib = '^ProjectPBZ/PBZModLoader/compiler/lib(?:\.[a-z0-9]+)*\.d\.ts$'
    $payload = @{}
    if ([IO.File]::Exists((Join-Path $downloads "$scripts/bootstrap.js"))) {
        $packageName = $downloads
        foreach ($path in $required) {
            $item = Get-Item -LiteralPath (Join-Path $downloads $path) -ErrorAction SilentlyContinue
            if ($item -is [IO.FileInfo]) { $payload[$path] = $item }
        }
        foreach ($item in Get-ChildItem -LiteralPath (Join-Path $downloads "$loader/compiler") -File -ErrorAction SilentlyContinue) {
            $path = "$loader/compiler/$($item.Name)"
            if ($path -match $compilerLib) { $payload[$path] = $item }
        }
    } else {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        foreach ($file in Get-ChildItem -LiteralPath $downloads -Filter '*.zip' -File) {
            try { $candidate = [IO.Compression.ZipFile]::OpenRead($file.FullName) }
            catch [IO.InvalidDataException] { continue }
            try {
                $entries = @($candidate.Entries | Where-Object { $_.FullName.Replace('\', '/') -eq "$scripts/bootstrap.js" })
                if (!$entries.Count) { continue }
                if ($zip) { throw '安装器旁只保留一个加载器 ZIP。 / Keep only one loader ZIP beside the installer.' }
                $zip = $candidate
                $packageName = $file.Name
                foreach ($entry in $zip.Entries) {
                    $path = $entry.FullName.Replace('\', '/')
                    if ($path -notin $required -and $path -notmatch $compilerLib) { continue }
                    if ($payload.ContainsKey($path)) { throw "ZIP 文件重复 / Duplicate ZIP entry: $path" }
                    $payload[$path] = $entry
                }
            } finally { if ($candidate -ne $zip) { $candidate.Dispose() } }
        }
        if (!$zip) {
            throw "脚本所在目录 / Installer folder: $downloads`n请下载玩家主包 PBZModLoader-<版本>-win64.zip，放在本脚本旁，再运行脚本。也可在游戏目录之外完整解压主包，将脚本放入解压目录后运行。 / Download the main player ZIP (PBZModLoader-<version>-win64.zip), place it next to this script, and run the script again. You can also extract the full player ZIP outside the game and run the script from the extracted folder.`n目标游戏根目录 / Game root: $game"
        }
    }
    foreach ($path in $required) {
        if (!$payload.ContainsKey($path) -or !$payload[$path].Length) { throw "安装包缺少文件或文件为空 / Missing or empty package file: $path" }
    }

    $owned = @()
    $unknown = @()
    $installedHashes = @{}
    foreach ($name in @('version.dll') + $alternates) {
        $dll = Join-Path $game "$platformDir/$name"
        Assert-Path $dll
        if (![IO.File]::Exists($dll)) { continue }
        $hash = Get-Hash ([IO.FileInfo]$dll)
        $installedHashes[$name] = $hash
        if ($hash -in $known[$name] -or $hash -eq (Get-Hash $payload[$proxies[$name]])) { $owned += $name }
        else { $unknown += $name }
    }
    if (!$owned.Count -and $unknown.Count) {
        throw "无法确认 PBZ.exe 旁的 DLL 来源（$($unknown -join ', ')）。 / Unknown DLL ownership beside PBZ.exe: $($unknown -join ', ').`nPBZ.exe 所在目录 / Executable folder: $(Join-Path $game $platformDir)`n请参照安装说明选择可用的入口手动安装。 / Follow the manual guide to choose an available entry."
    }
    $id = [guid]::NewGuid().ToString('N')
    $backup = Join-Path $game "PBZModLoader-Backups/$(Get-Date -Format yyyyMMdd-HHmmss)-$id"
    $entryName = if ($owned.Count) { $owned[0] } else { 'version.dll' }
    if ($owned.Count -gt 1) {
        $entryName = Select-LoaderEntry $owned (Join-Path $game $platformDir) $backup
        if (!$entryName) { Write-Host '已取消 / Cancelled.'; exit 0 }
    }
    $entryPath = "$platformDir/$entryName"
    $mods = Join-Path $game "$loader/mods"
    Assert-Path $mods -Directory
    $files = @($payload.Keys | Where-Object { $_ -like 'ProjectPBZ/*' } | Sort-Object) + $entryPath
    foreach ($path in $files) { Assert-Path (Join-Path $game $path) }

    Write-Host "安装包 / Package: $packageName"
    Write-Host "游戏目录 / Game folder: $game"
    Write-Host "加载器入口 / Loader entry: $entryPath"
    $stage = Join-Path $game ".pbz-loader-install-$id"
    Assert-Path $backup -Directory
    [void][IO.Directory]::CreateDirectory($stage)
    $changes = @(foreach ($name in $owned -ne $entryName) {
        $path = "$platformDir/$name"
        @{ Target = (Join-Path $game $path); Saved = (Join-Path $backup $path); OldHash = $installedHashes[$name] }
    })
    $changes += @(foreach ($path in $files) {
        $target = Join-Path $game $path
        if ($path -eq $ini -and [IO.File]::Exists($target)) { continue }
        $source = if ($path -eq $entryPath) { $payload[$proxies[$entryName]] } else { $payload[$path] }
        $incoming = Join-Path $stage $path
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($incoming))
        if ($source -is [IO.FileInfo]) { [void]$source.CopyTo($incoming) }
        else { [IO.Compression.ZipFileExtensions]::ExtractToFile($source, $incoming) }
        $newHash = Get-Hash ([IO.FileInfo]$incoming)
        $oldHash = if ($path -eq $entryPath) { $installedHashes[$entryName] }
            elseif ([IO.File]::Exists($target)) { Get-Hash ([IO.FileInfo]$target) }
        if ($oldHash -ne $newHash -or $path -eq $entryPath) {
            @{ Target = $target; Saved = (Join-Path $backup $path); Incoming = $incoming; OldHash = $oldHash; NewHash = $newHash }
        }
    })

    Assert-GameClosed
    $undo = [Collections.Generic.Stack[object]]::new()
    try {
        foreach ($change in $changes) {
            Assert-Path $change.Target
            if ($change.OldHash) {
                if ((Get-Hash ([IO.FileInfo]$change.Target)) -ne $change.OldHash) { throw "安装期间文件被修改 / File changed during installation: $($change.Target)" }
                if ($change.OldHash -eq $change.NewHash) { continue }
                New-InstallDirectory ([IO.Path]::GetDirectoryName($change.Saved)) $undo
                [IO.File]::Move($change.Target, $change.Saved)
                $undo.Push(@{ From = $change.Saved; To = $change.Target })
            }
            if (!$change.Incoming) { continue }
            New-InstallDirectory ([IO.Path]::GetDirectoryName($change.Target)) $undo
            [IO.File]::Move($change.Incoming, $change.Target)
            $undo.Push(@{ From = $change.Target; To = $change.Incoming })
            if ((Get-Hash ([IO.FileInfo]$change.Target)) -ne $change.NewHash) { throw "安装文件校验失败 / Installed file hash mismatch: $($change.Target)" }
        }
        New-InstallDirectory $mods $undo
    } catch {
        while ($undo.Count) {
            $step = $undo.Pop()
            try {
                if ($step.Directory) { [IO.Directory]::Delete($step.Directory) }
                else { [IO.File]::Move($step.From, $step.To) }
            } catch { Write-Warning "无法恢复 / Could not restore: $_" }
        }
        throw
    }
    Write-Host '安装完成。请从原游戏平台启动游戏。 / Installed. Start the game from your platform client.'
    Write-Host 'MOD 目录 / Mods: ProjectPBZ\PBZModLoader\mods'
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    $exitCode = 1
} finally {
    if ($backup -and [IO.Directory]::Exists($backup)) { Write-Host "备份 / Backup: $backup" }
    if ($zip) { $zip.Dispose() }
    if ($stage -and [IO.Path]::GetDirectoryName($stage) -eq $game -and
        [IO.Path]::GetFileName($stage) -match '^\.pbz-loader-install-[a-f0-9]{32}$') {
        Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    }
    if ($locked) { $mutex.ReleaseMutex() }
    if ($mutex) { $mutex.Dispose() }
}
exit $exitCode
