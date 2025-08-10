#enter hardlock.py and protect.py path
cd ../..
# Check if running as admin
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Please run this script as Administrator." -ForegroundColor Red
    exit
}

# Paths
$programFilesDir = Join-Path $env:ProgramFiles "Hardlock"
$appDataDir      = Join-Path $env:APPDATA "Hardlock"
$vaultPath       = Join-Path $appDataDir ".managervault"
$globalExe       = Join-Path $env:SystemRoot "System32\hardlock.exe"

# Create Program Files\Hardlock directory
New-Item -ItemType Directory -Path $programFilesDir -Force | Out-Null

# Create AppData\Hardlock directory for vault
New-Item -ItemType Directory -Path $appDataDir -Force | Out-Null

# Restrict Program Files\Hardlock to Admins only
$aclProgramFiles = Get-Acl $programFilesDir
$aclProgramFiles.SetAccessRuleProtection($true, $false)  # Disable inheritance
$ruleAdmins = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
$aclProgramFiles.SetAccessRule($ruleAdmins)
Set-Acl -Path $programFilesDir -AclObject $aclProgramFiles

# Temp build folder
$tempBuildDir = Join-Path $env:TEMP "HardlockBuild"
if (Test-Path $tempBuildDir) { Remove-Item $tempBuildDir -Recurse -Force }
New-Item -ItemType Directory -Path $tempBuildDir | Out-Null
Copy-Item ".\hardlock.py" $tempBuildDir -Force
Copy-Item ".\protect.py"  $tempBuildDir -Force

# Move into temp build dir
Set-Location $tempBuildDir

# Create venv
python -m venv venv
& .\venv\Scripts\Activate.ps1

# Install dependencies
pip install --upgrade pip
pip install rich argon2-cffi pycryptodome pyinstaller

# Build with PyInstaller — bundle protect.py inside binary
pyinstaller --onefile --add-data "protect.py;." hardlock.py

# Deactivate venv
deactivate

# Move compiled binary to Program Files\Hardlock
$distDir = Join-Path $tempBuildDir "dist"
Move-Item (Join-Path $distDir "hardlock.exe") $programFilesDir -Force

# Clean up build dir and PyInstaller leftovers
Set-Location $HOME
Remove-Item $tempBuildDir -Recurse -Force

# Make executable accessible globally by copying to System32
Copy-Item (Join-Path $programFilesDir "hardlock.exe") $globalExe -Force

# --------------------
# Vault file protection step (in %APPDATA%\Hardlock)
# --------------------
if (-Not (Test-Path $vaultPath)) {
    # Create empty vault file so we can set permissions now
    New-Item -Path $vaultPath -ItemType File | Out-Null
}

# Get current user name (domain\username)
$currentUser = "$env:USERDOMAIN\$env:USERNAME"

# Set ACL: allow only Admins + current user full control
$vaultAcl = Get-Acl $vaultPath
$vaultAcl.SetAccessRuleProtection($true, $false)  # Disable inheritance
$ruleAdmins = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators", "FullControl", "None", "None", "Allow")
$ruleUser   = New-Object System.Security.AccessControl.FileSystemAccessRule($currentUser, "FullControl", "None", "None", "Allow")
$vaultAcl.SetAccessRule($ruleAdmins)
$vaultAcl.AddAccessRule($ruleUser)
Set-Acl -Path $vaultPath -AclObject $vaultAcl

Write-Host "Hardlock installed securely with vault protection in AppData!" -ForegroundColor Green

