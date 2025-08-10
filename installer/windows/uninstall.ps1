# Check if running as admin
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Please run this script as Administrator." -ForegroundColor Red
    exit
}

$targetDir = Join-Path $env:ProgramFiles "Hardlock"
$globalExe = Join-Path $env:SystemRoot "System32\hardlock.exe"

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

# Remove Hardlock directory and all contents including .managervault
if (Test-Path $targetDir) {
    try {
        Remove-Item $targetDir -Recurse -Force
        Write-Host "Removed Hardlock directory at $targetDir"
    }
    catch {
        Write-Warning "Failed to remove Hardlock directory at $targetDir. Check permissions and close any running programs using files there."
    }
} else {
    Write-Host "Hardlock directory not found at $targetDir"
}

Write-Host "Uninstallation complete." -ForegroundColor Green

