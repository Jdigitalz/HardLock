# Check if running as admin
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Please run this script as Administrator." -ForegroundColor Red
    exit
}

Write-Host "WARNING: This will delete ALL passwords and data stored by HardLock." -ForegroundColor Yellow
Write-Host "Are you sure you want to proceed? (Y/N)"
$response = Read-Host

if ($response.ToUpper() -ne "Y") {
    Write-Host "Uninstallation cancelled." -ForegroundColor Cyan
    exit
}

$programFilesDir = Join-Path $env:ProgramFiles "Hardlock"
$appDataDir      = Join-Path $env:APPDATA "Hardlock"
$vaultPath       = Join-Path $appDataDir ".managervault"
$globalExe       = Join-Path $env:SystemRoot "System32\hardlock.exe"

# Remove global executable if it exists
if (Test-Path $globalExe) {
    try {
        Remove-Item $globalExe -Force
        Write-Host "Removed global executable at $globalExe"
    }
    catch {
        Write-Warning "Failed to remove global executable at $globalExe. Try closing any running instances and run again as Administrator."
    }
} else {
    Write-Host "Global executable not found at $globalExe"
}

# Remove Hardlock directory and all contents including executable in Program Files
if (Test-Path $programFilesDir) {
    try {
        Remove-Item $programFilesDir -Recurse -Force
        Write-Host "Removed Hardlock directory at $programFilesDir"
    }
    catch {
        Write-Warning "Failed to remove Hardlock directory at $programFilesDir. Check permissions and close any running programs using files there."
    }
} else {
    Write-Host "Hardlock directory not found at $programFilesDir"
}

# Remove AppData Hardlock directory and vault file
if (Test-Path $appDataDir) {
    try {
        Remove-Item $appDataDir -Recurse -Force
        Write-Host "Removed Hardlock data directory at $appDataDir (including vault file)"
    }
    catch {
        Write-Warning "Failed to remove Hardlock data directory at $appDataDir. Check permissions and close any running programs using files there."
    }
} else {
    Write-Host "Hardlock data directory not found at $appDataDir"
}

Write-Host "Uninstallation complete. All HardLock data and executables have been removed." -ForegroundColor Green

