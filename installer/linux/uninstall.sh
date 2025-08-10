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
LINK_PATH="/usr/local/bin/hardlock"

# ========== SUDO CHECK ==========
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}⚠️  This script must be run with sudo!${RESET}"
  echo -e "${YELLOW}    Please run: sudo ./uninstall.sh${RESET}"
  exit 1
fi

# ========== WARNING ==========
echo -e "${RED}⚠️  WARNING: This will permanently delete the entire Hardlock installation directory:${RESET}"
echo -e "${YELLOW}   ${INSTALL_DIR}${RESET}"
echo -e "${YELLOW}   This includes the binary and any runtime or user-generated files.${RESET}"
echo -e "${RED}⚠️  THIS ACTION CANNOT BE UNDONE.${RESET}"

read -p "$(echo -e ${YELLOW}Are you absolutely sure you want to continue? [y/N]:${RESET} )" confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo -e "${RED}Uninstallation cancelled.${RESET}"
  exit 0
fi

# ========== UNINSTALLING ==========
echo -e "${BLUE}Removing Hardlock files and symlink...${RESET}"

if [ -L "$LINK_PATH" ] || [ -f "$LINK_PATH" ]; then
  rm -f "$LINK_PATH" && \
  echo -e "${GREEN}✔ Removed symlink: $LINK_PATH${RESET}" || \
  echo -e "${RED}✖ Failed to remove symlink: $LINK_PATH${RESET}"
else
  echo -e "${YELLOW}⚠️  Symlink not found: $LINK_PATH${RESET}"
fi

if [ -d "$INSTALL_DIR" ]; then
  # Reset permissions to ensure it can be deleted
  chmod -R u+rwX "$INSTALL_DIR"
  rm -rf "$INSTALL_DIR" && \
  echo -e "${GREEN}✔ Removed directory: $INSTALL_DIR${RESET}" || \
  echo -e "${RED}✖ Failed to remove directory: $INSTALL_DIR${RESET}"
else
  echo -e "${YELLOW}⚠️  Install directory not found: $INSTALL_DIR${RESET}"
fi

echo -e "${GREEN}✅ Uninstallation complete.${RESET}"

