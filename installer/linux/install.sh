#!/bin/bash

# ========== PATH ============
cd ../..
# ========== COLORS ==========
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
BLUE="\033[1;34m"
RESET="\033[0m"

INSTALL_DIR="/opt/hardlock"
INSTALL_PATH="$INSTALL_DIR/hardlock"
BIN_NAME="hardlock.bin"
SYMLINK_PATH="/usr/local/bin/hardlock"

# ========== SUDO CHECK ==========
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}⚠️  This script must be run with sudo!${RESET}"
  echo -e "${YELLOW}    Please run: sudo ./install.sh${RESET}"
  exit 1
fi

# ========== 1. CREATE VENV ==========
echo -e "${BLUE}[1/6] Creating virtual environment...${RESET}"
python3 -m venv .venv || { echo -e "${RED}Failed to create virtualenv.${RESET}"; exit 1; }

# ========== 2. INSTALL DEPS ==========
echo -e "${BLUE}[2/6] Activating and installing dependencies...${RESET}"
source .venv/bin/activate
pip install --upgrade pip >/dev/null
pip install rich nuitka argon2-cffi pycryptodome >/dev/null

# ========== 3. COMPILE ==========
echo -e "${BLUE}[3/6] Compiling hardlock.py with Nuitka (including argon2)...${RESET}"
nuitka --standalone --onefile --include-module=argon2 hardlock.py || { echo -e "${RED}Compilation failed.${RESET}"; deactivate; exit 1; }

if [ ! -f "$BIN_NAME" ]; then
    echo -e "${RED}Error: Compiled binary not found: ${BIN_NAME}${RESET}"
    deactivate
    exit 1
fi

# ========== 4. INSTALL ==========
echo -e "${BLUE}[4/6] Installing binary to: ${INSTALL_DIR}${RESET}"

mkdir -p "$INSTALL_DIR"
cp "$BIN_NAME" "$INSTALL_PATH"

# Ensure root-only access to binary and directory
chown root:root "$INSTALL_PATH"
chmod 500 "$INSTALL_PATH"

chown root:root "$INSTALL_DIR"
chmod 500 "$INSTALL_DIR"

# ========== 5. CREATE SYMLINK ==========
echo -e "${BLUE}[5/6] Creating symlink at ${SYMLINK_PATH}${RESET}"
ln -sf "$INSTALL_PATH" "$SYMLINK_PATH"

# ========== 6. CLEANUP ==========
echo -e "${BLUE}[6/6] Cleaning up build files and virtual environment...${RESET}"
deactivate
rm -rf .venv
rm -rf hardlock.build hardlock.bin hardlock.dist hardlock.onefile-build __pycache__ hardlock.*.c hardlock.*.bin.cache

# ========== DONE ==========
echo -e "${GREEN}✅ Installation complete!${RESET}"
echo -e "${YELLOW}➡️  You can now run: ${RESET}${GREEN}hardlock${RESET}"
echo -e "${YELLOW}📦 Installed in: ${RESET}${GREEN}${INSTALL_DIR}${RESET}"

