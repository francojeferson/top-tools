<#
.SYNOPSIS
    Performs an automatic, non-administrator Windows 11 user-cache cleanup.
 
.DESCRIPTION
    This script only removes explicitly identified, user-accessible cache and
    temporary data. It never requests elevation or modifies system settings.
 
    Browser cookies, history, active sessions, and offline website data are
    removed. Saved passwords, bookmarks, favorites, and reading lists are kept.
 
    Normal mode performs cleanup automatically.
    Use -DryRun to preview actions without deleting anything.
 
.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File .\UserCleanup.ps1
 
.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File .\UserCleanup.ps1 -DryRun
#>
 
[CmdletBinding()]
param(
    [switch]$DryRun
)
 
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Continue'
 
# ---------------------------------------------------------------------------
# Runtime statistics. No persistent log file is created.
# ---------------------------------------------------------------------------
 
$Stats = [ordered]@{
    Candidates       = 0
    CandidateBytes    = [int64]0
    RemovedFiles     = 0
    RemovedFolders   = 0
    RemovedBytes     = [int64]0
    SkippedCount     = 0
    ErrorCount       = 0
    SkippedExamples  = New-Object System.Collections.Generic.List[string]
    ErrorExamples    = New-Object System.Collections.Generic.List[string]
    ClosedProcesses  = New-Object System.Collections.Generic.List[string]
    RelaunchedApps   = New-Object System.Collections.Generic.List[string]
}
 
$Categories = New-Object System.Collections.Generic.List[string]
$Targets = New-Object System.Collections.Generic.List[object]
$TargetKeys = @{}
$SeenFiles = @{}
 
function Add-Category {
    param([string]$Name)
 
    if (-not $Categories.Contains($Name)) {
        [void]$Categories.Add($Name)
    }
}
 
function Add-Skipped {
    param([string]$Message)
 
    $Stats.SkippedCount++
    if ($Stats.SkippedExamples.Count -lt 30) {
        [void]$Stats.SkippedExamples.Add($Message)
    }
}
 
function Add-Error {
    param([string]$Message)
 
    $Stats.ErrorCount++
    if ($Stats.ErrorExamples.Count -lt 30) {
        [void]$Stats.ErrorExamples.Add($Message)
    }
}
 
function Format-Size {
    param([int64]$Bytes)
 
    if ($Bytes -ge 1TB) {
        return ('{0:N2} TB' -f ($Bytes / 1TB))
    }
 
    if ($Bytes -ge 1GB) {
        return ('{0:N2} GB' -f ($Bytes / 1GB))
    }
 
    if ($Bytes -ge 1MB) {
        return ('{0:N2} MB' -f ($Bytes / 1MB))
    }
 
    if ($Bytes -ge 1KB) {
        return ('{0:N2} KB' -f ($Bytes / 1KB))
    }
 
    return ('{0} bytes' -f $Bytes)
}
 
# ---------------------------------------------------------------------------
# Path-safety functions
# ---------------------------------------------------------------------------
 
$AllowedRoots = New-Object System.Collections.Generic.List[string]
 
foreach ($Root in @(
    $env:LOCALAPPDATA,
    $env:APPDATA,
    $env:USERPROFILE,
    $env:ProgramData,
    $env:SystemRoot
)) {
    if (-not [string]::IsNullOrWhiteSpace($Root)) {
        try {
            $FullRoot = [IO.Path]::GetFullPath($Root).TrimEnd('\')
            if (-not $AllowedRoots.Contains($FullRoot)) {
                [void]$AllowedRoots.Add($FullRoot)
            }
        }
        catch {
            Add-Error "Could not validate allowed root: $Root"
        }
    }
}
 
function Get-NormalizedPath {
    param([string]$Path)
 
    try {
        return ([IO.Path]::GetFullPath($Path)).TrimEnd('\')
    }
    catch {
        return $null
    }
}
 
function Test-SafePath {
    param([string]$Path)
 
    $FullPath = Get-NormalizedPath $Path
 
    if ([string]::IsNullOrWhiteSpace($FullPath)) {
        return $false
    }
 
    # Never permit a drive root or one of the broad allowed roots itself.
    foreach ($Root in $AllowedRoots) {
        if ($FullPath.Equals($Root, [StringComparison]::OrdinalIgnoreCase)) {
            return $false
        }
 
        if ($FullPath.StartsWith(($Root + '\'), [StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
 
    return $false
}
 
function Add-Target {
    param(
        [string]$Path,
        [ValidateSet('File', 'DirectoryContents')]
        [string]$Type,
        [string]$Category
    )
 
    Add-Category $Category
 
    if (-not (Test-SafePath $Path)) {
        Add-Skipped "Rejected unsafe path: $Path"
        return
    }
 
    $FullPath = Get-NormalizedPath $Path
    $Key = "$Type|$($FullPath.ToLowerInvariant())"
 
    if (-not $TargetKeys.ContainsKey($Key)) {
        $TargetKeys[$Key] = $true
 
        [void]$Targets.Add([pscustomobject]@{
            Path     = $FullPath
            Type     = $Type
            Category = $Category
        })
    }
}
 
function Add-DirectoryContents {
    param(
        [string]$Path,
        [string]$Category
    )
 
    Add-Target -Path $Path -Type DirectoryContents -Category $Category
}
 
function Add-ExactFile {
    param(
        [string]$Path,
        [string]$Category
    )
 
    Add-Target -Path $Path -Type File -Category $Category
}
 
function Add-FilesMatchingPattern {
    param(
        [string]$Directory,
        [string]$Filter,
        [string]$Category
    )
 
    Add-Category $Category
 
    if (-not (Test-SafePath $Directory)) {
        Add-Skipped "Rejected unsafe pattern directory: $Directory"
        return
    }
 
    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) {
        return
    }
 
    try {
        $Items = Get-ChildItem -LiteralPath $Directory -Filter $Filter `
            -File -Force -ErrorAction SilentlyContinue
 
        foreach ($Item in $Items) {
            Add-ExactFile -Path $Item.FullName -Category $Category
        }
    }
    catch {
        Add-Error "Could not enumerate $Directory`: $($_.Exception.Message)"
    }
}
 
# ---------------------------------------------------------------------------
# Deletion functions
# ---------------------------------------------------------------------------
 
# These extensions are deliberately excluded, even when found inside a
# report or cache directory.
$ExcludedExtensions = @(
    '.dmp',
    '.mdmp',
    '.hdmp',
    '.dump'
)
 
function Process-File {
    param(
        [string]$Path,
        [string]$Category
    )
 
    $FullPath = Get-NormalizedPath $Path
 
    if ([string]::IsNullOrWhiteSpace($FullPath)) {
        return
    }
 
    $Key = $FullPath.ToLowerInvariant()
 
    if ($SeenFiles.ContainsKey($Key)) {
        return
    }
 
    $SeenFiles[$Key] = $true
 
    if (-not (Test-SafePath $FullPath)) {
        Add-Skipped "Unsafe file skipped: $FullPath"
        return
    }
 
    try {
        $Item = Get-Item -LiteralPath $FullPath -Force -ErrorAction Stop
 
        if ($Item.PSIsContainer) {
            Add-Skipped "Directory supplied where file was expected: $FullPath"
            return
        }
 
        if (($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            Add-Skipped "Reparse-point file skipped: $FullPath"
            return
        }
 
        $Length = [int64]$Item.Length
 
        if ($ExcludedExtensions -contains $Item.Extension.ToLowerInvariant()) {
            Add-Skipped "Memory/crash dump excluded: $FullPath"
            return
        }
 
        if ($DryRun) {
            $Stats.Candidates++
            $Stats.CandidateBytes += $Length
            return
        }
 
        try {
            Remove-Item -LiteralPath $FullPath -Force -ErrorAction Stop
            $Stats.RemovedFiles++
            $Stats.RemovedBytes += $Length
        }
        catch {
            Add-Skipped "File was locked, protected, or could not be deleted: $FullPath"
        }
    }
    catch {
        # Missing files are normal during cache cleanup and are not errors.
        if (Test-Path -LiteralPath $FullPath) {
            Add-Skipped "Could not inspect file: $FullPath"
        }
    }
}
 
function Process-DirectoryContents {
    param(
        [string]$Path,
        [string]$Category
    )
 
    $FullPath = Get-NormalizedPath $Path
 
    if (-not (Test-SafePath $FullPath)) {
        Add-Skipped "Unsafe directory skipped: $Path"
        return
    }
 
    if (-not (Test-Path -LiteralPath $FullPath -PathType Container)) {
        return
    }
 
    try {
        $RootItem = Get-Item -LiteralPath $FullPath -Force -ErrorAction Stop
 
        if (($RootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            Add-Skipped "Reparse-point directory skipped: $FullPath"
            return
        }
 
        $Files = Get-ChildItem -LiteralPath $FullPath -File -Force `
            -Recurse -ErrorAction SilentlyContinue
 
        foreach ($File in $Files) {
            Process-File -Path $File.FullName -Category $Category
        }
 
        if (-not $DryRun) {
            # Remove empty child directories, but never remove the target
            # directory itself. Reparse points are never followed or removed.
            $Directories = Get-ChildItem -LiteralPath $FullPath -Directory `
                -Force -Recurse -ErrorAction SilentlyContinue |
                Sort-Object FullName -Descending
 
            foreach ($Directory in $Directories) {
                try {
                    if (($Directory.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                        Add-Skipped "Reparse-point directory skipped: $($Directory.FullName)"
                        continue
                    }
 
                    $Children = Get-ChildItem -LiteralPath $Directory.FullName `
                        -Force -ErrorAction SilentlyContinue
 
                    if ($null -eq $Children) {
                        Remove-Item -LiteralPath $Directory.FullName `
                            -Force -ErrorAction Stop
                        $Stats.RemovedFolders++
                    }
                }
                catch {
                    Add-Skipped "Directory could not be removed: $($Directory.FullName)"
                }
            }
        }
    }
    catch {
        Add-Error "Could not inspect directory $FullPath`: $($_.Exception.Message)"
    }
}
 
# ---------------------------------------------------------------------------
# Browser-target functions
# ---------------------------------------------------------------------------
 
function Add-ChromiumProfileTargets {
    param(
        [string]$BrowserName,
        [string]$UserDataRoot
    )
 
    Add-Category "$BrowserName browser data"
 
    if (-not (Test-Path -LiteralPath $UserDataRoot -PathType Container)) {
        return
    }
 
    try {
        $Profiles = Get-ChildItem -LiteralPath $UserDataRoot -Directory `
            -Force -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Name -eq 'Default' -or
                $_.Name -eq 'Guest Profile' -or
                $_.Name -like 'Profile *'
            }
    }
    catch {
        Add-Error "Could not enumerate $BrowserName profiles"
        return
    }
 
    foreach ($Profile in $Profiles) {
        $ProfilePath = $Profile.FullName
 
        # Cache and website-data directories. These do not contain saved
        # passwords or bookmarks.
        foreach ($RelativePath in @(
            'Cache',
            'Code Cache',
            'GPUCache',
            'Sessions',
            'Session Storage',
            'Local Storage',
            'IndexedDB',
            'File System',
            'Service Worker\CacheStorage',
            'Service Worker\ScriptCache',
            'Service Worker\Database'
        )) {
            Add-DirectoryContents `
                -Path (Join-Path $ProfilePath $RelativePath) `
                -Category "$BrowserName browser cache and website data"
        }
 
        # These files contain cookies, history, and active-session state.
        # Login Data and Bookmarks are intentionally not included.
        foreach ($RelativePath in @(
            'Cookies',
            'Cookies-journal',
            'Network\Cookies',
            'Network\Cookies-journal',
            'History',
            'History-journal',
            'Current Session',
            'Current Tabs',
            'Last Session',
            'Last Tabs'
        )) {
            Add-ExactFile `
                -Path (Join-Path $ProfilePath $RelativePath) `
                -Category "$BrowserName browser cookies, history, and sessions"
        }
    }
}
 
function Add-ChromiumBrowser {
    param(
        [string]$Name,
        [string[]]$Roots
    )
 
    foreach ($Root in $Roots) {
        Add-ChromiumProfileTargets -BrowserName $Name -UserDataRoot $Root
    }
}
 
function Add-FirefoxTargets {
    Add-Category 'Mozilla Firefox browser data'
 
    $FirefoxProfileRoots = @(
        (Join-Path $env:APPDATA 'Mozilla\Firefox\Profiles'),
        (Join-Path $env:LOCALAPPDATA 'Mozilla\Firefox\Profiles')
    )
 
    foreach ($ProfileRoot in $FirefoxProfileRoots) {
        if (-not (Test-Path -LiteralPath $ProfileRoot -PathType Container)) {
            continue
        }
 
        $Profiles = Get-ChildItem -LiteralPath $ProfileRoot -Directory `
            -Force -ErrorAction SilentlyContinue
 
        foreach ($Profile in $Profiles) {
            $ProfilePath = $Profile.FullName
 
            foreach ($RelativePath in @(
                'cache2',
                'startupCache',
                'thumbnails',
                'sessionstore-backups',
                'storage\default',
                'storage\temporary'
            )) {
                Add-DirectoryContents `
                    -Path (Join-Path $ProfilePath $RelativePath) `
                    -Category 'Firefox cache, sessions, and offline website data'
            }
 
            foreach ($RelativePath in @(
                'cookies.sqlite',
                'cookies.sqlite-wal',
                'cookies.sqlite-shm',
                'sessionstore.jsonlz4'
            )) {
                Add-ExactFile `
                    -Path (Join-Path $ProfilePath $RelativePath) `
                    -Category 'Firefox cookies and sessions'
            }
 
            # places.sqlite contains both history and bookmarks, so it must
            # never be deleted. If sqlite3.exe is available, history visits
            # can be removed from the database without deleting bookmarks.
            $PlacesDatabase = Join-Path $ProfilePath 'places.sqlite'
            if (Test-Path -LiteralPath $PlacesDatabase -PathType Leaf) {
                Add-Category 'Firefox browsing history'
                $script:FirefoxHistoryDatabases += $PlacesDatabase
            }
        }
    }
}
 
# ---------------------------------------------------------------------------
# Process handling
# ---------------------------------------------------------------------------
 
$ProcessMap = @(
    [pscustomobject]@{
        Label     = 'Microsoft Edge'
        Names     = @('msedge')
        Browser   = $true
    },
    [pscustomobject]@{
        Label     = 'Google Chrome'
        Names     = @('chrome')
        Browser   = $true
    },
    [pscustomobject]@{
        Label     = 'Mozilla Firefox'
        Names     = @('firefox')
        Browser   = $true
    },
    [pscustomobject]@{
        Label     = 'Brave'
        Names     = @('brave')
        Browser   = $true
    },
    [pscustomobject]@{
        Label     = 'Opera'
        Names     = @('opera')
        Browser   = $true
    },
    [pscustomobject]@{
        Label     = 'Vivaldi'
        Names     = @('vivaldi')
        Browser   = $true
    },
    [pscustomobject]@{
        Label     = 'Microsoft Teams'
        Names     = @('Teams', 'ms-teams', 'msteams')
        Browser   = $false
    },
    [pscustomobject]@{
        Label     = 'Discord'
        Names     = @('Discord', 'DiscordPTB', 'DiscordCanary')
        Browser   = $false
    },
    [pscustomobject]@{
        Label     = 'Spotify'
        Names     = @('Spotify')
        Browser   = $false
    },
    [pscustomobject]@{
        Label     = 'Steam'
        Names     = @('steam')
        Browser   = $false
    },
    [pscustomobject]@{
        Label     = 'Epic Games Launcher'
        Names     = @('EpicGamesLauncher')
        Browser   = $false
    },
    [pscustomobject]@{
        Label     = 'Slack'
        Names     = @('slack')
        Browser   = $false
    },
    [pscustomobject]@{
        Label     = 'Visual Studio Code'
        Names     = @('Code', 'VSCodium')
        Browser   = $false
    },
    [pscustomobject]@{
        Label     = 'Zoom'
        Names     = @('Zoom')
        Browser   = $false
    }
)
 
$ClosedBrowserExecutables = New-Object System.Collections.Generic.List[string]
 
function Get-ProcessExecutable {
    param([System.Diagnostics.Process]$Process)
 
    try {
        return $Process.MainModule.FileName
    }
    catch {
        return $null
    }
}
 
function Close-SupportedProcesses {
    if ($DryRun) {
        Write-Host 'Dry-run mode: running applications will not be closed.' `
            -ForegroundColor Yellow
        return
    }
 
    Write-Host ''
    Write-Host 'Closing supported applications where possible...' `
        -ForegroundColor Cyan
 
    $SeenProcessIds = @{}
 
    foreach ($Entry in $ProcessMap) {
        foreach ($ProcessName in $Entry.Names) {
            $Processes = Get-Process -Name $ProcessName `
                -ErrorAction SilentlyContinue
 
            foreach ($Process in ($Processes | Sort-Object Id -Unique)) {
                if ($SeenProcessIds.ContainsKey($Process.Id)) {
                    continue
                }
 
                $SeenProcessIds[$Process.Id] = $true
                $Executable = Get-ProcessExecutable $Process
 
                try {
                    $ClosedWindow = $Process.CloseMainWindow()
 
                    if (-not $ClosedWindow) {
                        Add-Skipped "Could not request $($Entry.Label) to close (PID $($Process.Id))"
                        continue
                    }
 
                    [void]$Process.WaitForExit(10000)
 
                    $StillRunning = Get-Process -Id $Process.Id `
                        -ErrorAction SilentlyContinue
 
                    if ($null -eq $StillRunning) {
                        [void]$Stats.ClosedProcesses.Add(
                            "$($Entry.Label) (PID $($Process.Id))"
                        )
 
                        if ($Entry.Browser -and
                            -not [string]::IsNullOrWhiteSpace($Executable) -and
                            (Test-Path -LiteralPath $Executable -PathType Leaf)) {
                            if (-not $ClosedBrowserExecutables.Contains($Executable)) {
                                [void]$ClosedBrowserExecutables.Add($Executable)
                            }
                        }
                    }
                    else {
                        Add-Skipped "$($Entry.Label) remained open; locked files will be skipped"
                    }
                }
                catch {
                    Add-Skipped "Could not close $($Entry.Label) (PID $($Process.Id))"
                }
            }
        }
    }
}
 
function Relaunch-ClosedBrowsers {
    if ($DryRun) {
        return
    }
 
    foreach ($Executable in $ClosedBrowserExecutables) {
        try {
            Start-Process -FilePath $Executable -ErrorAction Stop
            [void]$Stats.RelaunchedApps.Add($Executable)
        }
        catch {
            Add-Error "Could not relaunch browser: $Executable"
        }
    }
}
 
# ---------------------------------------------------------------------------
# Define cleanup targets
# ---------------------------------------------------------------------------
 
$FirefoxHistoryDatabases = New-Object System.Collections.Generic.List[string]
 
Add-Category 'User temporary files'
Add-DirectoryContents -Path $env:TEMP -Category 'User temporary files'
 
Add-Category 'User-accessible Windows cache data'
Add-DirectoryContents `
    -Path (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\INetCache') `
    -Category 'User-accessible Windows cache data'
 
Add-Category 'DirectX shader cache'
Add-DirectoryContents `
    -Path (Join-Path $env:LOCALAPPDATA 'D3DSCache') `
    -Category 'DirectX shader cache'
 
Add-Category 'Thumbnail and icon caches'
$ExplorerCachePath = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Explorer'
Add-FilesMatchingPattern `
    -Directory $ExplorerCachePath `
    -Filter 'thumbcache_*.db' `
    -Category 'Thumbnail and icon caches'
Add-FilesMatchingPattern `
    -Directory $ExplorerCachePath `
    -Filter 'iconcache_*.db' `
    -Category 'Thumbnail and icon caches'
 
Add-Category 'Windows Error Reporting data'
$WerPath = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\WER'
foreach ($RelativePath in @('ReportArchive', 'ReportQueue', 'Temp')) {
    Add-DirectoryContents `
        -Path (Join-Path $WerPath $RelativePath) `
        -Category 'Windows Error Reporting data'
}

# System-level WER reports (accessible without admin).
$SystemWerPath = Join-Path $env:ProgramData 'Microsoft\Windows\WER'
foreach ($RelativePath in @('ReportArchive', 'ReportQueue', 'Temp')) {
    Add-DirectoryContents `
        -Path (Join-Path $SystemWerPath $RelativePath) `
        -Category 'Windows Error Reporting data'
}

# ---------------------------------------------------------------------------
# System-level caches accessible without administrator privileges
# ---------------------------------------------------------------------------

Add-Category 'Windows log files'
Add-DirectoryContents `
    -Path (Join-Path $env:SystemRoot 'Logs') `
    -Category 'Windows log files'
Add-DirectoryContents `
    -Path (Join-Path $env:SystemRoot 'System32\LogFiles') `
    -Category 'Windows log files'

Add-Category 'Windows minidump files'
Add-DirectoryContents `
    -Path (Join-Path $env:SystemRoot 'Minidump') `
    -Category 'Windows minidump files'

Add-Category 'Windows Update temporary downloads'
Add-DirectoryContents `
    -Path (Join-Path $env:SystemRoot 'SoftwareDistribution\Download') `
    -Category 'Windows Update temporary downloads'

Add-Category 'WDF framework logs'
Add-DirectoryContents `
    -Path (Join-Path $env:ProgramData 'Microsoft\WDF') `
    -Category 'WDF framework logs'

# ---------------------------------------------------------------------------
# User-accessible caches not covered by cleanmgr
# ---------------------------------------------------------------------------

Add-Category 'Legacy web cache'
Add-DirectoryContents `
    -Path (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\WebCache') `
    -Category 'Legacy web cache'
Add-DirectoryContents `
    -Path (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\INetCookies') `
    -Category 'Legacy web cache'

Add-Category 'Diagnostic telemetry data'
Add-DirectoryContents `
    -Path (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\DiagTrack') `
    -Category 'Diagnostic telemetry data'
Add-DirectoryContents `
    -Path (Join-Path $env:LOCALAPPDATA 'DiagnosticsHub') `
    -Category 'Diagnostic telemetry data'

Add-Category 'OneDrive logs'
Add-DirectoryContents `
    -Path (Join-Path $env:LOCALAPPDATA 'Microsoft\OneDrive\logs') `
    -Category 'OneDrive logs'

Add-Category 'Font cache'
Add-DirectoryContents `
    -Path (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\FontCache') `
    -Category 'Font cache'

Add-Category 'Windows Search logs'
Add-DirectoryContents `
    -Path (Join-Path $env:LOCALAPPDATA 'Microsoft\Search\Data\Applications\Windows\GatherLogs') `
    -Category 'Windows Search logs'

# Chromium-based browsers, including commonly installed alternatives.
Add-ChromiumBrowser `
    -Name 'Microsoft Edge' `
    -Roots @(
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data')
    )
 
Add-ChromiumBrowser `
    -Name 'Google Chrome' `
    -Roots @(
        (Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data')
    )
 
Add-ChromiumBrowser `
    -Name 'Brave' `
    -Roots @(
        (Join-Path $env:LOCALAPPDATA 'BraveSoftware\Brave-Browser\User Data')
    )
 
Add-ChromiumBrowser `
    -Name 'Opera' `
    -Roots @(
        (Join-Path $env:APPDATA 'Opera Software\Opera Stable'),
        (Join-Path $env:APPDATA 'Opera Software\Opera GX Stable')
    )
 
Add-ChromiumBrowser `
    -Name 'Vivaldi' `
    -Roots @(
        (Join-Path $env:LOCALAPPDATA 'Vivaldi\User Data')
    )
 
Add-FirefoxTargets
 
# ---------------------------------------------------------------------------
# Common third-party application caches
# ---------------------------------------------------------------------------
 
# Microsoft Teams classic and new Teams.
$ClassicTeams = Join-Path $env:APPDATA 'Microsoft\Teams'
foreach ($RelativePath in @(
    'Cache',
    'Code Cache',
    'GPUCache',
    'Service Worker\CacheStorage',
    'Service Worker\ScriptCache',
    'IndexedDB',
    'Local Storage',
    'Session Storage'
)) {
    Add-DirectoryContents `
        -Path (Join-Path $ClassicTeams $RelativePath) `
        -Category 'Microsoft Teams cache'
}
 
$TeamsPackages = Join-Path $env:LOCALAPPDATA 'Packages'
if (Test-Path -LiteralPath $TeamsPackages -PathType Container) {
    Get-ChildItem -LiteralPath $TeamsPackages -Directory -Force `
        -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like 'MSTeams*' } |
        ForEach-Object {
            $NewTeamsRoot = Join-Path $_.FullName 'LocalCache\Microsoft\MSTeams'
 
            foreach ($RelativePath in @(
                'Cache',
                'Code Cache',
                'GPUCache',
                'Service Worker\CacheStorage',
                'Service Worker\ScriptCache',
                'IndexedDB',
                'Local Storage',
                'Session Storage'
            )) {
                Add-DirectoryContents `
                    -Path (Join-Path $NewTeamsRoot $RelativePath) `
                    -Category 'Microsoft Teams cache'
            }
        }
}
 
# Discord, including PTB and Canary profiles.
foreach ($DiscordRoot in @(
    (Join-Path $env:APPDATA 'discord'),
    (Join-Path $env:APPDATA 'discordptb'),
    (Join-Path $env:APPDATA 'discordcanary')
)) {
    foreach ($RelativePath in @(
        'Cache',
        'Code Cache',
        'GPUCache',
        'Service Worker\CacheStorage',
        'Service Worker\ScriptCache',
        'IndexedDB',
        'Local Storage',
        'Session Storage'
    )) {
        Add-DirectoryContents `
            -Path (Join-Path $DiscordRoot $RelativePath) `
            -Category 'Discord cache'
    }
}
 
# Spotify: only browser/cache directories are targeted, not downloaded music
# or the main application data directory.
$SpotifyRoot = Join-Path $env:APPDATA 'Spotify'
foreach ($RelativePath in @(
    'Browser\Cache',
    'Browser\Code Cache',
    'Browser\GPUCache',
    'Browser\Service Worker\CacheStorage'
)) {
    Add-DirectoryContents `
        -Path (Join-Path $SpotifyRoot $RelativePath) `
        -Category 'Spotify cache'
}
 
# Epic Games Launcher.
$EpicRoot = Join-Path $env:LOCALAPPDATA 'EpicGamesLauncher\Saved'
foreach ($RelativePath in @(
    'webcache',
    'webcache_4147',
    'webcache_4430',
    'Logs'
)) {
    Add-DirectoryContents `
        -Path (Join-Path $EpicRoot $RelativePath) `
        -Category 'Epic Games Launcher cache and logs'
}
 
# Steam locations that may exist outside protected installation folders.
foreach ($SteamRoot in @(
    (Join-Path $env:LOCALAPPDATA 'Steam'),
    (Join-Path $env:APPDATA 'Steam')
)) {
    Add-DirectoryContents `
        -Path (Join-Path $SteamRoot 'htmlcache') `
        -Category 'Steam cache'
}
 
# Slack.
foreach ($SlackRoot in @(
    (Join-Path $env:APPDATA 'Slack'),
    (Join-Path $env:LOCALAPPDATA 'slack')
)) {
    foreach ($RelativePath in @(
        'Cache',
        'Code Cache',
        'GPUCache',
        'Service Worker\CacheStorage',
        'Logs'
    )) {
        Add-DirectoryContents `
            -Path (Join-Path $SlackRoot $RelativePath) `
            -Category 'Slack cache and logs'
    }
}
 
# Adobe cache locations. Configuration and project folders are excluded.
foreach ($AdobeRoot in @(
    (Join-Path $env:APPDATA 'Adobe'),
    (Join-Path $env:LOCALAPPDATA 'Adobe')
)) {
    foreach ($RelativePath in @(
        'Common\Media Cache Files',
        'Common\Media Cache',
        'Acrobat\DC\Cache'
    )) {
        Add-DirectoryContents `
            -Path (Join-Path $AdobeRoot $RelativePath) `
            -Category 'Adobe cache'
    }
}
 
# Visual Studio Code and VSCodium.
foreach ($CodeRoot in @(
    (Join-Path $env:APPDATA 'Code'),
    (Join-Path $env:APPDATA 'VSCodium')
)) {
    foreach ($RelativePath in @(
        'Cache',
        'CachedData',
        'GPUCache',
        'Service Worker\CacheStorage',
        'Service Worker\ScriptCache'
    )) {
        Add-DirectoryContents `
            -Path (Join-Path $CodeRoot $RelativePath) `
            -Category 'Visual Studio Code cache'
    }
}
 
# JetBrains application caches. Only directories named "caches" are used.
$JetBrainsRoot = Join-Path $env:LOCALAPPDATA 'JetBrains'
if (Test-Path -LiteralPath $JetBrainsRoot -PathType Container) {
    Get-ChildItem -LiteralPath $JetBrainsRoot -Directory -Force `
        -ErrorAction SilentlyContinue |
        ForEach-Object {
            Add-DirectoryContents `
                -Path (Join-Path $_.FullName 'caches') `
                -Category 'JetBrains application cache'
        }
}
 
# Additional common Electron application cache locations.
foreach ($AppRoot in @(
    (Join-Path $env:APPDATA 'GitHub Desktop'),
    (Join-Path $env:APPDATA 'Notion'),
    (Join-Path $env:APPDATA 'Postman'),
    (Join-Path $env:APPDATA 'Figma'),
    (Join-Path $env:APPDATA 'Obsidian')
)) {
    foreach ($RelativePath in @(
        'Cache',
        'Code Cache',
        'GPUCache',
        'Service Worker\CacheStorage',
        'Service Worker\ScriptCache'
    )) {
        Add-DirectoryContents `
            -Path (Join-Path $AppRoot $RelativePath) `
            -Category 'Common application cache'
    }
}
 
# User-level graphics-driver shader caches.
foreach ($ShaderRoot in @(
    (Join-Path $env:LOCALAPPDATA 'NVIDIA Corporation\NV_Cache'),
    (Join-Path $env:LOCALAPPDATA 'AMD\DxCache')
)) {
    Add-DirectoryContents `
        -Path $ShaderRoot `
        -Category 'Graphics-driver shader cache'
}
 
# ---------------------------------------------------------------------------
# Execute cleanup
# ---------------------------------------------------------------------------
 
Write-Host ''
if ($DryRun) {
    Write-Host 'DRY-RUN MODE: no files will be deleted.' -ForegroundColor Yellow
}
else {
    Write-Warning 'Automatic cleanup is starting.'
    Write-Warning 'Browsers and supported applications may be closed.'
    Write-Warning 'Browser cookies, history, active sessions, and offline website data will be removed.'
    Write-Warning 'You may be signed out of websites. Saved passwords and bookmarks are preserved.'
}
 
Close-SupportedProcesses
 
foreach ($Target in $Targets) {
    if ($Target.Type -eq 'File') {
        Process-File -Path $Target.Path -Category $Target.Category
    }
    elseif ($Target.Type -eq 'DirectoryContents') {
        Process-DirectoryContents -Path $Target.Path -Category $Target.Category
    }
}
 
# ---------------------------------------------------------------------------
# Firefox history cleanup
# ---------------------------------------------------------------------------
 
# places.sqlite contains Firefox bookmarks and history. It is never deleted.
# If sqlite3.exe is already installed and available, only history visits are
# removed. Otherwise, Firefox history is reported as unavailable.
$SqliteCommand = Get-Command 'sqlite3.exe' `
    -ErrorAction SilentlyContinue
 
$SeenFirefoxDatabases = @{}
 
foreach ($Database in $FirefoxHistoryDatabases) {
    $NormalizedDatabase = Get-NormalizedPath $Database
 
    if ([string]::IsNullOrWhiteSpace($NormalizedDatabase) -or
        $SeenFirefoxDatabases.ContainsKey($NormalizedDatabase)) {
        continue
    }
 
    $SeenFirefoxDatabases[$NormalizedDatabase] = $true
 
    if ($DryRun) {
        if ($null -ne $SqliteCommand) {
            Write-Host "Dry-run: Firefox history would be cleared from $NormalizedDatabase"
        }
        else {
            Add-Skipped 'Firefox history requires sqlite3.exe; places.sqlite was preserved'
        }
        continue
    }
 
    if ($null -eq $SqliteCommand) {
        Add-Skipped 'Firefox history skipped because sqlite3.exe is not installed'
        continue
    }
 
    if (-not (Test-Path -LiteralPath $NormalizedDatabase -PathType Leaf)) {
        continue
    }
 
    try {
        $BeforeSize = [int64](Get-Item -LiteralPath $NormalizedDatabase).Length
 
        $Sql = @'
PRAGMA busy_timeout=5000;
BEGIN;
DELETE FROM moz_historyvisits;
DELETE FROM moz_inputhistory;
COMMIT;
VACUUM;
'@
 
        $SqlOutput = & $SqliteCommand.Source -batch -bail `
            $NormalizedDatabase $Sql 2>&1
 
        if ($LASTEXITCODE -ne 0) {
            Add-Error "Firefox history database could not be updated: $NormalizedDatabase"
            continue
        }
 
        $AfterSize = [int64](Get-Item -LiteralPath $NormalizedDatabase).Length
 
        if ($BeforeSize -gt $AfterSize) {
            $Stats.RemovedBytes += ($BeforeSize - $AfterSize)
        }
    }
    catch {
        Add-Error "Firefox history cleanup failed: $NormalizedDatabase"
    }
}
 
# Recycle Bin cleanup. This uses the current user's permissions and does not
# enumerate or delete arbitrary files.
Add-Category 'Current-user Recycle Bin'
 
if ($DryRun) {
    Add-Skipped 'Recycle Bin size was not estimated in dry-run mode'
}
else {
    try {
        if (Get-Command 'Clear-RecycleBin' -ErrorAction SilentlyContinue) {
            Clear-RecycleBin -Force -ErrorAction Stop
        }
        else {
            Add-Skipped 'Clear-RecycleBin is unavailable on this PowerShell version'
        }
    }
    catch {
        Add-Skipped 'Recycle Bin could not be emptied with current-user permissions'
    }
}
 
# Windows Update and Delivery Optimization data are intentionally not
# accessed because they are normally protected and require administrator
# privileges.
$UnavailableCategories = @(
    'System-wide Windows temporary files (C:\Windows\Temp)',
    'Delivery Optimization files',
    'Windows installation cleanup (WinSxS)',
    'Windows.old (Previous Installations)',
    'System Restore points',
    'Hibernation files',
    'System memory dump (C:\Windows\MEMORY.DMP)',
    'Device driver packages (DriverStore)',
    'Windows Defender definition backups',
    'BranchCache',
    'Language packs',
    'Windows Prefetch'
)
 
Relaunch-ClosedBrowsers
 
# ---------------------------------------------------------------------------
# Temporary console summary
# ---------------------------------------------------------------------------
 
Write-Host ''
Write-Host '================ CLEANUP SUMMARY ================' `
    -ForegroundColor Cyan
 
if ($DryRun) {
    Write-Host ('Potential files:  {0}' -f $Stats.Candidates)
    Write-Host ('Potential space:  {0}' -f (Format-Size $Stats.CandidateBytes))
}
else {
    Write-Host ('Files removed:    {0}' -f $Stats.RemovedFiles)
    Write-Host ('Folders removed:  {0}' -f $Stats.RemovedFolders)
    Write-Host ('Space recovered:  {0}' -f (Format-Size $Stats.RemovedBytes))
}
 
Write-Host ('Items skipped:    {0}' -f $Stats.SkippedCount)
Write-Host ('Errors:           {0}' -f $Stats.ErrorCount)
 
Write-Host ''
Write-Host 'Categories processed:'
foreach ($Category in $Categories) {
    Write-Host "  - $Category"
}
 
if ($Stats.ClosedProcesses.Count -gt 0) {
    Write-Host ''
    Write-Host 'Applications closed by the script:'
    foreach ($ProcessDescription in $Stats.ClosedProcesses) {
        Write-Host "  - $ProcessDescription"
    }
}
 
if ($Stats.RelaunchedApps.Count -gt 0) {
    Write-Host ''
    Write-Host 'Browsers relaunched by the script:'
    foreach ($Application in $Stats.RelaunchedApps) {
        Write-Host "  - $Application"
    }
}
 
if ($Stats.SkippedExamples.Count -gt 0) {
    Write-Host ''
    Write-Host 'Examples of skipped items:'
    foreach ($Message in $Stats.SkippedExamples) {
        Write-Host "  - $Message"
    }
}
 
if ($Stats.ErrorExamples.Count -gt 0) {
    Write-Host ''
    Write-Host 'Examples of errors:'
    foreach ($Message in $Stats.ErrorExamples) {
        Write-Host "  - $Message"
    }
}
 
Write-Host ''
Write-Host 'Not processed because administrator privileges are unavailable:'
foreach ($Unavailable in $UnavailableCategories) {
    Write-Host "  - $Unavailable"
}
 
Write-Host ''
if ($DryRun) {
    Write-Host 'Preview complete. Run without -DryRun to perform cleanup.' `
        -ForegroundColor Yellow
}
else {
    Write-Host 'Cleanup complete. No persistent log file was created.' `
        -ForegroundColor Green
}
