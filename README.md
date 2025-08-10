# HardLock 🔒
----
A basic command line password manager using AES encryption and Argon2 and salting

![version badge](https://img.shields.io/badge/Hardlock-Version%201.0-blue)
---

## Installation

### Linux

1. Clone the repository:
   ```bash
   git clone https://github.com/Jdigitalz/HardLock.git
   cd HardLock
   ```
2. Navigate to the installer directory for Linux:
   ```bash
   cd installer/linux
   ```
3. Make the install script executable and run it with sudo:
   ```bash
   chmod +x install.sh
   sudo ./install.sh
   ```

### Windows (PowerShell)

1. Clone the repository and navigate to it:
   ```powershell
   git clone https://github.com/Jdigitalz/HardLock.git
   cd HardLock
   ```
2. Navigate to the installer directory for Windows:
   ```powershell
   cd installer/windows
   ```
3. Run the install script in an elevated PowerShell (Run as Administrator):
   ```powershell
   .\install.ps1
   ```

## Uninstallation

### Linux

1. Navigate to the installer directory for Linux:
   ```bash
   cd installer/linux
   ```
2. Make the uninstall script executable and run it with sudo:
   ```bash
   chmod +x uninstall.sh
   sudo ./uninstall.sh
   ```

### Windows (PowerShell)

1. Navigate to the installer directory for Windows:
   ```powershell
   cd installer/windows
   ```
2. Run the uninstall script in an elevated PowerShell (Run as Administrator):
   ```powershell
   .\uninstall.ps1
   ```

## Usage
![Usage Image](https://github.com/Jdigitalz/HardLock/blob/main/images/demo.png?raw=true)

## Future planning

 - Create a proper GUI for HardLock 
 - Make HardLock look better in the CLI
 - Add the ability to store files in a feature called 'Vault'
 - Create a way to send HardLock to other instances of HardLock

## Disclaimer
This program is not perfect, but I did try my best to make it as secure as possible for actual use. You should probably use something like KeePass as a password manager instead. This program does, for the most part, encrypt your data and protect it from deletion by requiring sudo permissions to view.

