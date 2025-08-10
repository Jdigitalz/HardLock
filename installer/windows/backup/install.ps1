<#
.SYNOPSIS
  Windows installer equivalent of the provided install.sh for "hardlock".

.NOTES
  - Run as Administrator.
  - Requires Python on PATH and Visual C++ Build Tools for Nuitka compilation.
  - Usage:
      Open "Windows PowerShell" as Administrator and run:
      Set-ExecutionPolicy Bypass -Scope Process -Force; .\install.ps1
#>
cd ../..
# ========== COLORS (via Write-Host) ==========
function Info($msg)    { Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Step($msg)    { Write-Host "[STEP]  $msg" -ForegroundColor Blue }
function Success($msg) { Write-Host "[DONE]  $msg" -ForegroundColor Green }
function Warn($msg)    { Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Error($msg)   { Write-Host "[ERROR] $msg" -ForegroundColor Red }

# ========== VARIABLES ==========
$InstallDir   = Join-Path $env:ProgramFiles "hardlock"    # default: C:\Program Files\hardlock
$InstallPath  = Join-Path $InstallDir "hardlock.exe"
$BinName      = "hardlock.exe"                            # expected output from Nuitka
$WrapperPath  = Join-Path $env:windir "System32\hardlock.cmd"
$ScriptRoot   = (Get-Location).Path

# ========== ADMIN CHECK ==========
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Error "This script must be run as Administrator. Re-run PowerShell as Administrator and try again."
    exit 1
}

# Helper: run a command and throw on non-zero
function RunOrFail($exe, $args) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exe
    $psi.Arguments = $args
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute = $false
    $proc = [System.Diagnostics.Process]::Start($psi)
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    if ($proc.ExitCode -ne 0) {
        Error "Command failed: $exe $args"
        if ($stdout) { Write-Host $stdout }
        if ($stderr) { Write-Host $stderr -ForegroundColor Red }
        throw "Process exited with code $($proc.ExitCode)"
    }
    return $stdout
}

try {
    # ========== 1. CREATE VENV ==========
    Step "[1/6] Creating virtual environment..."
    # detect python binary (try python, then python3)
    $pythonExe = "python"
    try {
        RunOrFail $pythonExe "--version" | Out-Null
    } catch {
        $pythonExe = "python3"
        try {
            RunOrFail $pythonExe "--version" | Out-Null
        } catch {
            Error "Python not found on PATH. Install Python and ensure 'python' is on PATH."
            exit 1
        }
    }

    $venvPath = Join-Path $ScriptRoot ".venv"
    & $pythonExe -m venv $venvPath
    if (-not (Test-Path $venvPath)) {
        Error "Failed to create virtual environment at $venvPath"
        exit 1
    }

    # venv python path
    $venvPython = Join-Path $venvPath "Scripts\python.exe"

    # ========== 2. INSTALL DEPS ==========
    Step "[2/6] Installing dependencies into venv (pip, rich, nuitka, argon2-cffi, pycryptodome)..."
    & $venvPython -m pip install --upgrade pip
    & $venvPython -m pip install rich nuitka argon2-cffi pycryptodome

    # ========== 3. COMPILE ==========
    Step "[3/6] Compiling hardlock.py with Nuitka (including argon2)..."
    $nuitkaArgs = "--standalone --onefile --include-module=argon2 --output-dir=. $ScriptRoot\hardlock.py"
    try {
        # Use python -m nuitka to ensure we run the venv-installed nuitka
        RunOrFail $venvPython ("-m nuitka " + $nuitkaArgs) | Out-Null
    } catch {
        Error "Compilation failed. Ensure you have the Visual C++ build tools (MSVC) installed and try again."
        throw $_
    }

    # Nuitka on Windows with --onefile will typically produce hardlock.exe in current dir (or output dir)
    if (-not (Test-Path (Join-Path $ScriptRoot $BinName))) {
        # try to find any matching exe from build dirs
        $found = Get-ChildItem -Path $ScriptRoot -Filter "$($BinName)" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            $compiledPath = $found.FullName
        } else {
            Error "Compiled binary not found: $BinName"
            exit 1
        }
    } else {
        $compiledPath = Join-Path $ScriptRoot $BinName
    }

    Info "Compiled binary located at: $compiledPath"

    # ========== 4. INSTALL ==========
    Step "[4/6] Installing binary to: $InstallDir"
    if (-not (Test-Path $InstallDir)) {
        New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
    }

    Copy-Item -Path $compiledPath -Destination $InstallPath -Force

    # Remove inherited ACLs and grant only Administrators & SYSTEM (closest approximation to chmod 500)
    Step "Setting restrictive ACLs on the install directory and binary..."
    try {
        # remove inheritance on file and dir
        icacls $InstallPath /inheritance:r | Out-Null
        icacls $InstallPath /grant "Administrators:(RX)" "SYSTEM:(RX)" | Out-Null

        icacls $InstallDir /inheritance:r | Out-Null
        icacls $InstallDir /grant "Administrators:(OI)(CI)(RX)" "SYSTEM:(OI)(CI)(RX)" | Out-Null
    } catch {
        Warn "Failed to fully adjust ACLs. You may need to adjust permissions manually."
    }

    # ========== 5. CREATE GLOBAL COMMAND ==========
    Step "[5/6] Creating global command wrapper (attempting symlink, fallback to .cmd wrapper)..."
    $symlinkPath = Join-Path $env:windir "System32\hardlock.exe"
    $created = $false

    # Try creating an actual symlink (requires admin; should succeed because we checked)
    try {
        if (Test-Path $symlinkPath) { Remove-Item -Path $symlinkPath -Force -ErrorAction SilentlyContinue }
        New-Item -Path $symlinkPath -ItemType SymbolicLink -Value $InstallPath -Force -ErrorAction Stop | Out-Null
        $created = $true
        Info "Created symlink at $symlinkPath -> $InstallPath"
    } catch {
        Warn "Could not create an exe symlink in System32 (this is OK). Creating a wrapper .cmd instead..."
        # create a wrapper .cmd in System32 that forwards args to the installed exe
        $cmdText = "@echo off`n`"" + $InstallPath + "`" %*"
        try {
            Set-Content -LiteralPath $WrapperPath -Value $cmdText -Encoding ASCII -Force
            # ensure wrapper is writable/overwritable by admins only
            icacls $WrapperPath /inheritance:r | Out-Null
            icacls $WrapperPath /grant "Administrators:(RX)" "SYSTEM:(RX)" | Out-Null
            $created = $true
            Info "Created wrapper at $WrapperPath -> $InstallPath"
        } catch {
            Error "Failed to create wrapper in System32. You can still run the binary directly from $InstallPath"
        }
    }

    # ========== 6. CLEANUP ==========
    Step "[6/6] Cleaning up build files and virtual environment..."
    try {
        # deactivate not required (we didn't 'activate' the venv in PowerShell)
        # Remove .venv and typical Nuitka build folders
        Remove-Item -Path $venvPath -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path (Join-Path $ScriptRoot "hardlock.build") -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path (Join-Path $ScriptRoot "hardlock.dist") -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path (Join-Path $ScriptRoot "hardlock.onefile-build") -Recurse -Force -ErrorAction SilentlyContinue
        # remove temp exe in source dir if created and not our installed one
        $possibleBin = Join-Path $ScriptRoot $BinName
        if (Test-Path $possibleBin) {
            if ($possibleBin -ne $InstallPath) { Remove-Item -Path $possibleBin -Force -ErrorAction SilentlyContinue }
        }
    } catch {
        Warn "Cleanup encountered errors; some temporary files may remain."
    }

    Success "Installation complete!"
    Write-Host ""
    Write-Host "You can now run: " -NoNewline; Write-Host "hardlock" -ForegroundColor Green
    Write-Host "Installed in: " -NoNewline; Write-Host $InstallDir -ForegroundColor Green

} catch {
    Error "Installer failed: $_"
    exit 1
}

