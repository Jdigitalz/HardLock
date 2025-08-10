If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Please run this script as Administrator." -ForegroundColor Red
    exit
}

# Change to directory where hardlock.py and protect.py live
Set-Location -Path (Resolve-Path "../..")

# Create Program Files\Hardlock directory
$targetDir = Join-Path $env:ProgramFiles "Hardlock"
New-Item -ItemType Directory -Path $targetDir -Force | Out-Null

# Restrict Program Files\Hardlock to Admins only
$acl = Get-Acl $targetDir
$acl.SetAccessRuleProtection($true, $false)  # Disable inheritance
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.SetAccessRule($rule)
Set-Acl -Path $targetDir -AclObject $acl

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
Move-Item (Join-Path $distDir "hardlock.exe") $targetDir -Force

# Clean up build dir and PyInstaller leftovers
Remove-Item $tempBuildDir -Recurse -Force

# Make executable accessible globally by copying to System32
$shortcutPath = Join-Path "$env:SystemRoot\System32" "hardlock.exe"
Copy-Item (Join-Path $targetDir "hardlock.exe") $shortcutPath -Force

# --------------------
# Vault file protection step
# --------------------
$vaultPath = Join-Path $targetDir ".managervault"
if (-Not (Test-Path $vaultPath)) {
    # Create empty vault so we can set permissions now
    New-Item -Path $vaultPath -ItemType File | Out-Null
}

# Get current user name
$currentUser = "$env:USERDOMAIN\$env:USERNAME"

# Set ACL: allow only Admins + current user
$vaultAcl = Get-Acl $vaultPath
$vaultAcl.SetAccessRuleProtection($true, $false)  # Disable inheritance
$ruleAdmins = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators", "FullControl", "None", "None", "Allow")
$ruleUser   = New-Object System.Security.AccessControl.FileSystemAccessRule($currentUser, "FullControl", "None", "None", "Allow")
$vaultAcl.SetAccessRule($ruleAdmins)
$vaultAcl.AddAccessRule($ruleUser)
Set-Acl -Path $vaultPath -AclObject $vaultAcl

Write-Host "Hardlock installed securely with vault protection!" -ForegroundColor Green

