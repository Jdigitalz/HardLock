<#
.SYNOPSIS
  Uninstall script to reverse the actions of the install.ps1 provided earlier.

.DESCRIPTION
  - Removes symlink (if created) from System32
  - Removes wrapper .cmd (if created) from System32 (only if it points to the installed exe)
  - Removes installed binary from Program Files (or a custom path)
  - Removes install directory if empty or if -RemoveDirContents is supplied
  - Optionally removes local build/venv artifacts in the current working directory (if -CleanLocalBuilds is used)

.PARAMETER InstallDir
  Path where hardlock was installed. Defaults to "$env:ProgramFiles\hardlock".

.PARAMETER Force
  Skip interactive confirmations.

.PARAMETER RemoveDirContents
  If provided, will remove the install directory and its contents without additional interactive confirmation.

.PARAMETER CleanLocalBuilds
  Remove common build artifacts from the current script directory (e.g. .venv, hardlock.build). Confirmed interactively unless -Force.

.EXAMPLE
  .\uninstall.ps1
  Interactive uninstall.

  .\uninstall.ps1 -Force -RemoveDirContents
  Fully non-interactive uninstall (destructive).
#>
param(
    [string]$InstallDir = (Join-Path $env:ProgramFiles "hardlock"),
    [switch]$Force,
    [switch]$RemoveDirContents,
    [switch]$CleanLocalBuilds
)

function Info([string]$m){ Write-Host "[INFO]  $m" -ForegroundColor Cyan }
function Step([string]$m){ Write-Host "[STEP]  $m" -ForegroundColor Blue }
function Warn([string]$m){ Write-Host "[WARN]  $m" -ForegroundColor Yellow }
function Err([string]$m){ Write-Host "[ERROR] $m" -ForegroundColor Red }
function Ok([string]$m){ Write-Host "[OK]    $m" -ForegroundColor Green }

# Derived paths (same as install script)
$InstallPath = Join-Path $InstallDir "hardlock.exe"
$Sys32       = Join-Path $env:windir "System32"
$SymlinkPath = Join-Path $Sys32 "hardlock.exe"
$WrapperPath = Join-Path $Sys32 "hardlock.cmd"
$ScriptRoot  = (Get-Location).Path

# Admin check
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Err "This script must be run as Administrator. Re-run PowerShell as Administrator and try again."
    exit 1
}

# Confirmation helper
function Confirm-Or-Exit([string]$message) {
    if ($Force) { return $true }
    $answer = Read-Host "$message  (Y/N)"
    return ($answer -match '^[Yy]')
}

Step "Planned targets:"
Info "InstallDir: $InstallDir"
Info "InstallPath: $InstallPath"
Info "SymlinkPath (possible): $SymlinkPath"
Info "WrapperPath (possible): $WrapperPath"
Write-Host ""

if (-not (Confirm-Or-Exit "Proceed with uninstall?")) {
    Warn "Aborted by user."
    exit 0
}

# ---------- 1) Remove System32 symlink if present ----------
if (Test-Path -LiteralPath $SymlinkPath -PathType Leaf) {
    try {
        $item = Get-Item -LiteralPath $SymlinkPath -Force
    } catch {
        $item = $null
    }

    $isReparse = $false
    if ($item) {
        try {
            $isReparse = (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)
        } catch {}
    }

    if ($isReparse) {
        # Try to get its target (PowerShell 6+ exposes .Target)
        $target = $null
        try { $target = $item.Target } catch {}

        if ($target) {
            if ([IO.Path]::GetFullPath($target).TrimEnd('\') -ieq [IO.Path]::GetFullPath($InstallPath).TrimEnd('\')) {
                Step "Removing symlink at $SymlinkPath (points to $target)"
                try { Remove-Item -LiteralPath $SymlinkPath -Force; Ok "Removed symlink." } catch { Err "Failed to remove symlink: $_" }
            } else {
                Warn "Symlink at $SymlinkPath points to '$target', not to expected '$InstallPath'."
                if (Confirm-Or-Exit "Remove it anyway?") {
                    try { Remove-Item -LiteralPath $SymlinkPath -Force; Ok "Removed symlink." } catch { Err "Failed to remove symlink: $_" }
                } else { Warn "Left symlink in place." }
            }
        } else {
            # Can't determine target; be cautious
            Warn "Found a reparse point (symlink) at $SymlinkPath but could not read its target."
            if (Confirm-Or-Exit "Remove the symlink anyway?") {
                try { Remove-Item -LiteralPath $SymlinkPath -Force; Ok "Removed symlink." } catch { Err "Failed to remove symlink: $_" }
            } else { Warn "Left symlink in place." }
        }

    } else {
        # It's a file in System32 named hardlock.exe — don't remove blindly
        Warn "There is a file at $SymlinkPath but it is not a symlink."
        if (Test-Path -LiteralPath $SymlinkPath) {
            if (Confirm-Or-Exit "Remove file $SymlinkPath? (ensure this is the wrapper/symlink you created)") {
                try { Remove-Item -LiteralPath $SymlinkPath -Force; Ok "Removed file at $SymlinkPath." } catch { Err "Failed to remove file: $_" }
            } else { Warn "Left file in place." }
        }
    }
} else {
    Info "No symlink found at $SymlinkPath."
}

# ---------- 2) Remove wrapper .cmd if it looks like ours ----------
if (Test-Path -LiteralPath $WrapperPath -PathType Leaf) {
    $content = $null
    try { $content = Get-Content -LiteralPath $WrapperPath -Raw -ErrorAction Stop } catch {}
    $isLikelyOurs = $false
    if ($content) {
        # check if wrapper references the install path (case-insensitive)
        if ($content -match [regex]::Escape($InstallPath)) { $isLikelyOurs = $true }
        # also allow references that only include the folder name
        if (-not $isLikelyOurs -and $content -match 'hardlock') { $isLikelyOurs = $true }
    }

    if ($isLikelyOurs) {
        Step "Removing wrapper $WrapperPath (content references install path)."
        try { Remove-Item -LiteralPath $WrapperPath -Force; Ok "Removed wrapper." } catch { Err "Failed to remove wrapper: $_" }
    } else {
        Warn "Found $WrapperPath but its contents don't clearly match the installed binary."
        if (Confirm-Or-Exit "Remove it anyway?") {
            try { Remove-Item -LiteralPath $WrapperPath -Force; Ok "Removed wrapper." } catch { Err "Failed to remove wrapper: $_" }
        } else { Warn "Left wrapper in place." }
    }
} else {
    Info "No wrapper found at $WrapperPath."
}

# ---------- 3) Remove the installed binary ----------
if (Test-Path -LiteralPath $InstallPath -PathType Leaf) {
    Step "Found installed binary at $InstallPath."
    if (Confirm-Or-Exit "Delete installed binary $InstallPath?") {
        try { Remove-Item -LiteralPath $InstallPath -Force; Ok "Removed installed binary." } catch { Err "Failed to remove installed binary: $_" }
    } else { Warn "Left installed binary in place." }
} else {
    Info "No installed binary found at $InstallPath."
}

# ---------- 4) Remove install directory (if empty or requested) ----------
if (Test-Path -LiteralPath $InstallDir -PathType Container) {
    $children = Get-ChildItem -LiteralPath $InstallDir -Force -ErrorAction SilentlyContinue
    if (($children | Measure-Object).Count -eq 0) {
        Step "Removing empty install directory $InstallDir"
        try { Remove-Item -LiteralPath $InstallDir -Force; Ok "Removed directory." } catch { Err "Failed to remove directory: $_" }
    } else {
        Warn "Install directory $InstallDir is not empty. It contains:"
        $children | ForEach-Object { Write-Host "  - $($_.Name)" }
        if ($RemoveDirContents) {
            Step "Removing directory and all contents (requested via -RemoveDirContents)."
            try { Remove-Item -LiteralPath $InstallDir -Recurse -Force; Ok "Removed directory and contents." } catch { Err "Failed to remove directory recursively: $_" }
        } else {
            if (Confirm-Or-Exit "Remove the directory and all of its contents now?") {
                try { Remove-Item -LiteralPath $InstallDir -Recurse -Force; Ok "Removed directory and contents." } catch { Err "Failed to remove directory recursively: $_" }
            } else {
                Warn "Left install directory in place. Use -RemoveDirContents to remove non-empty directory non-interactively."
            }
        }
    }
} else {
    Info "Install directory $InstallDir does not exist."
}

# ---------- 5) Optional: clean local build artifacts in current directory ----------
if ($CleanLocalBuilds) {
    $buildCandidates = @(".venv", "hardlock.build", "hardlock.dist", "hardlock.onefile-build", "hardlock.*.c", "hardlock.*.bin.cache", "__pycache__")
    Write-Host ""
    Step "Cleaning local build artifacts in folder: $ScriptRoot"
    foreach ($pattern in $buildCandidates) {
        $found = Get-ChildItem -Path $ScriptRoot -Filter $pattern -Recurse -Force -ErrorAction SilentlyContinue
        foreach ($f in $found) {
            $full = $f.FullName
            if ($Force -or Confirm-Or-Exit "Delete local artifact: $full?") {
                try { Remove-Item -LiteralPath $full -Recurse -Force; Ok "Deleted $full" } catch { Warn "Failed to delete $full: $_" }
            } else {
                Warn "Skipped $full"
            }
        }
    }
}

Ok "Uninstall sequence completed."
Write-Host ""
Info "Summary:"
if (-not (Test-Path $InstallPath)) { Info " - Installed binary removed." } else { Warn " - Installed binary still present at $InstallPath." }
if (-not (Test-Path $SymlinkPath)) { Info " - Symlink (if any) removed." } else { Warn " - Symlink still present at $SymlinkPath." }
if (-not (Test-Path $WrapperPath)) { Info " - Wrapper removed." } else { Warn " - Wrapper still present at $WrapperPath." }
if (-not (Test-Path $InstallDir)) { Info " - Install directory removed." } else { Warn " - Install directory still present: $InstallDir" }

Write-Host ""
Ok "Done."

