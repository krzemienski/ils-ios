#!/bin/bash

# ILS Remote Access - Interactive Setup
# Choose between Cloudflare Tunnel or Tailscale

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Clear screen
clear

# Display header
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}      ILS Backend - Remote Access Setup           ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""

# Display options
echo -e "${CYAN}Choose your remote access method:${NC}"
echo ""
echo -e "  ${BLUE}1)${NC} ${GREEN}Cloudflare Tunnel${NC} ${YELLOW}(Quick Setup)${NC}"
echo -e "     ✓ No configuration needed"
echo -e "     ✓ Public HTTPS URL"
echo -e "     ✓ Ready in 2 minutes"
echo -e "     ✗ URL changes on restart"
echo ""
echo -e "  ${BLUE}2)${NC} ${GREEN}Tailscale${NC} ${YELLOW}(Recommended)${NC}"
echo -e "     ✓ Permanent IP address"
echo -e "     ✓ End-to-end encrypted"
echo -e "     ✓ Private network only"
echo -e "     ✓ Better performance"
echo ""
echo -e "  ${BLUE}3)${NC} View documentation"
echo ""
echo -e "  ${BLUE}4)${NC} Exit"
echo ""

# Read choice
echo -ne "${CYAN}Enter your choice [1-4]:${NC} "
read -r choice

echo ""

case $choice in
    1)
        echo -e "${GREEN}Starting Cloudflare Tunnel setup...${NC}"
        echo ""
        sleep 1
        exec "${SCRIPT_DIR}/setup-cloudflare-tunnel.sh"
        ;;
    2)
        echo -e "${GREEN}Starting Tailscale setup...${NC}"
        echo ""
        sleep 1
        exec "${SCRIPT_DIR}/setup-tailscale.sh"
        ;;
    3)
        echo -e "${BLUE}Opening documentation...${NC}"
        echo ""

        DOC_FILE="${SCRIPT_DIR}/../../REMOTE_ACCESS.md"

        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS - open in default markdown viewer or text editor
            if command -v marked &> /dev/null; then
                marked "$DOC_FILE"
            else
                open "$DOC_FILE"
            fi
        else
            # Linux - try common markdown viewers
            if command -v mdless &> /dev/null; then
                mdless "$DOC_FILE"
            elif command -v glow &> /dev/null; then
                glow "$DOC_FILE"
            else
                less "$DOC_FILE"
            fi
        fi
        ;;
    4)
        echo -e "${YELLOW}Goodbye!${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid choice. Please run the script again.${NC}"
        exit 1
        ;;
esac
