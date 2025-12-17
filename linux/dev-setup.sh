#!/bin/bash
# Developer Machine Setup Script for Linux
# Supports Ubuntu/Debian (apt) and Arch-based distros (pacman/yay)
# Run with: chmod +x dev-setup.sh && ./dev-setup.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}========================================"
echo -e "  Developer Machine Setup Script"
echo -e "========================================${NC}"
echo ""

# ============================================
# Detect Distribution
# ============================================
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO_ID="$ID"
        DISTRO_ID_LIKE="$ID_LIKE"
        DISTRO_NAME="$NAME"
    else
        echo -e "${RED}ERROR: Cannot detect distribution (/etc/os-release not found)${NC}"
        exit 1
    fi

    # Determine package manager
    if [[ "$DISTRO_ID" == "ubuntu" || "$DISTRO_ID" == "debian" || "$DISTRO_ID_LIKE" == *"debian"* || "$DISTRO_ID_LIKE" == *"ubuntu"* ]]; then
        PKG_MANAGER="apt"
        echo -e "${GREEN}Detected: $DISTRO_NAME (apt-based)${NC}"
    elif [[ "$DISTRO_ID" == "arch" || "$DISTRO_ID_LIKE" == *"arch"* ]]; then
        PKG_MANAGER="pacman"
        echo -e "${GREEN}Detected: $DISTRO_NAME (pacman-based)${NC}"
    else
        echo -e "${RED}ERROR: Unsupported distribution: $DISTRO_NAME${NC}"
        echo -e "${YELLOW}This script supports Ubuntu, Debian, Arch, and Arch-based distros${NC}"
        exit 1
    fi
}

# ============================================
# Package installation functions
# ============================================
install_apt() {
    local pkg="$1"
    echo -e "${YELLOW}Installing $pkg via apt...${NC}"
    sudo apt install -y "$pkg" || echo -e "${YELLOW}$pkg may have failed or is already installed${NC}"
}

install_pacman() {
    local pkg="$1"
    echo -e "${YELLOW}Installing $pkg via pacman...${NC}"
    sudo pacman -S --noconfirm --needed "$pkg" || echo -e "${YELLOW}$pkg may have failed or is already installed${NC}"
}

install_yay() {
    local pkg="$1"
    echo -e "${YELLOW}Installing $pkg via yay (AUR)...${NC}"
    yay -S --noconfirm --needed "$pkg" || echo -e "${YELLOW}$pkg may have failed or is already installed${NC}"
}

install_pkg() {
    local apt_pkg="$1"
    local arch_pkg="${2:-$1}"  # Use apt name if arch name not specified
    
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        install_apt "$apt_pkg"
    else
        install_pacman "$arch_pkg"
    fi
}

install_aur() {
    local pkg="$1"
    if [[ "$PKG_MANAGER" == "pacman" ]]; then
        install_yay "$pkg"
    else
        echo -e "${YELLOW}Skipping AUR package $pkg (not on Arch)${NC}"
    fi
}

# ============================================
# Ensure yay is installed (Arch only)
# ============================================
ensure_yay() {
    if [[ "$PKG_MANAGER" != "pacman" ]]; then
        return
    fi
    
    if command -v yay &> /dev/null; then
        echo -e "${GREEN}yay is already installed${NC}"
        return
    fi
    
    echo -e "${YELLOW}Installing yay (AUR helper)...${NC}"
    sudo pacman -S --noconfirm --needed git base-devel
    
    local tmpdir=$(mktemp -d)
    cd "$tmpdir"
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ~
    rm -rf "$tmpdir"
    echo -e "${GREEN}yay installed successfully!${NC}"
}

# ============================================
# Main Installation
# ============================================
detect_distro
echo ""

# Update package manager
echo -e "${CYAN}Updating package manager...${NC}"
if [[ "$PKG_MANAGER" == "apt" ]]; then
    sudo apt update && sudo apt upgrade -y
else
    sudo pacman -Syu --noconfirm
fi
echo ""

# Ensure yay is available on Arch
ensure_yay
echo ""

STEP=1
TOTAL=19

# ============================================
# Git
# ============================================
echo -e "${CYAN}[$STEP/$TOTAL] Installing Git...${NC}"
install_pkg "git" "git"
echo ""
((STEP++))

# ============================================
# Build essentials
# ============================================
echo -e "${CYAN}[$STEP/$TOTAL] Installing build essentials...${NC}"
if [[ "$PKG_MANAGER" == "apt" ]]; then
    install_apt "build-essential"
    install_apt "curl"
    install_apt "wget"
else
    install_pacman "base-devel"
    install_pacman "curl"
    install_pacman "wget"
fi
echo ""
((STEP++))

# ============================================
# tmux
# ============================================
echo -e "${CYAN}[$STEP/$TOTAL] Installing tmux...${NC}"
install_pkg "tmux" "tmux"
echo ""
((STEP++))

# ============================================
# htop
# ============================================
echo -e "${CYAN}[$STEP/$TOTAL] Installing htop...${NC}"
install_pkg "htop" "htop"
echo ""
((STEP++))

# ============================================
# Ghostty terminal
# ============================================
echo -e "${CYAN}[$STEP/$TOTAL] Installing Ghostty...${NC}"
if [[ "$PKG_MANAGER" == "apt" ]]; then
    # Ghostty needs to be built from source on Ubuntu or use a PPA
    echo -e "${YELLOW}Ghostty requires manual installation on Ubuntu${NC}"
    echo -e "${CYAN}See: https://ghostty.org/docs/install${NC}"
else
    # Available in AUR
    install_aur "ghostty"
fi
echo ""
((STEP++))

# ============================================
# Node.js & Bun
# ============================================
echo -e "${CYAN}[$STEP/$TOTAL] Installing Node.js...${NC}"
if [[ "$PKG_MANAGER" == "apt" ]]; then
    # Use NodeSource for latest LTS
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    install_apt "nodejs"
else
    install_pacman "nodejs"
    install_pacman "npm"
fi
echo ""
((STEP++))

echo -e "${CYAN}[$STEP/$TOTAL] Installing Bun...${NC}"
curl -fsSL https://bun.sh/install | bash
echo ""
((STEP++))

# ============================================
# Go
# ============================================
echo -e "${CYAN}[$STEP/$TOTAL] Installing Go...${NC}"
if [[ "$PKG_MANAGER" == "apt" ]]; then
    # apt golang can be outdated, use official installer
    GO_VERSION="1.23.4"
    wget -q "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -O /tmp/go.tar.gz
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf /tmp/go.tar.gz
    rm /tmp/go.tar.gz
    echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> ~/.bashrc
    export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
    echo -e "${GREEN}Go $GO_VERSION installed${NC}"
else
    install_pacman "go"
fi
echo ""
((STEP++))

# ============================================
# Python 3.12+
# ============================================
echo -e "${CYAN}[$STEP/$TOTAL] Installing Python...${NC}"
if [[ "$PKG_MANAGER" == "apt" ]]; then
    install_apt "python3"
    install_apt "python3-pip"
    install_apt "python3-venv"
else
    install_pacman "python"
    install_pacman "python-pip"
fi
echo ""
((STEP++))

# ============================================
# Zig
# ============================================
echo -e "${CYAN}[$STEP/$TOTAL] Installing Zig...${NC}"
if [[ "$PKG_MANAGER" == "apt" ]]; then
    # Zig via snap or manual download
    ZIG_VERSION="0.14.0"
    wget -q "https://ziglang.org/download/${ZIG_VERSION}/zig-linux-x86_64-${ZIG_VERSION}.tar.xz" -O /tmp/zig.tar.xz
    sudo rm -rf /opt/zig
    sudo mkdir -p /opt/zig
    sudo tar -C /opt/zig --strip-components=1 -xf /tmp/zig.tar.xz
    rm /tmp/zig.tar.xz
    sudo ln -sf /opt/zig/zig /usr/local/bin/zig
    echo -e "${GREEN}Zig $ZIG_VERSION installed${NC}"
else
    install_pacman "zig"
fi
echo ""
((STEP++))

# ============================================
# ZLS (Zig Language Server)
# ============================================
echo -e "${CYAN}[$STEP/$TOTAL] Installing ZLS...${NC}"
if [[ "$PKG_MANAGER" == "apt" ]]; then
    ZLS_VERSION="0.14.0"
    wget -q "https://github.com/zigtools/zls/releases/download/${ZLS_VERSION}/zls-x86_64-linux.tar.xz" -O /tmp/zls.tar.xz
    sudo tar -C /usr/local/bin -xf /tmp/zls.tar.xz
    rm /tmp/zls.tar.xz
    echo -e "${GREEN}ZLS $ZLS_VERSION installed${NC}"
else
    install_pacman "zls"
fi
echo ""
((STEP++))

# ============================================
# ARM GNU Toolchain
# ============================================
echo -e "${CYAN}[$STEP/$TOTAL] Installing ARM GNU Toolchain...${NC}"
if [[ "$PKG_MANAGER" == "apt" ]]; then
    install_apt "gcc-arm-none-eabi"
    install_apt "libnewlib-arm-none-eabi"
else
    install_pacman "arm-none-eabi-gcc"
    install_pacman "arm-none-eabi-newlib"
fi
echo ""
((STEP++))

# ============================================
# Docker
# ============================================
echo -e "${CYAN}[$STEP/$TOTAL] Installing Docker...${NC}"
if [[ "$PKG_MANAGER" == "apt" ]]; then
    # Docker official install
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker $USER
    echo -e "${YELLOW}NOTE: Log out and back in for docker group to take effect${NC}"
else
    install_pacman "docker"
    install_pacman "docker-compose"
    sudo systemctl enable docker
    sudo usermod -aG docker $USER
    echo -e "${YELLOW}NOTE: Log out and back in for docker group to take effect${NC}"
fi
echo ""
((STEP++))

# ============================================
# QEMU
# ============================================
echo -e "${CYAN}[$STEP/$TOTAL] Installing QEMU...${NC}"
if [[ "$PKG_MANAGER" == "apt" ]]; then
    install_apt "qemu-system"
    install_apt "qemu-user"
else
    install_pacman "qemu-full"
fi
echo ""
((STEP++))

# ============================================
# LazyGit
# ============================================
echo -e "${CYAN}[$STEP/$TOTAL] Installing LazyGit...${NC}"
if [[ "$PKG_MANAGER" == "apt" ]]; then
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
    sudo tar -C /usr/local/bin -xf /tmp/lazygit.tar.gz lazygit
    rm /tmp/lazygit.tar.gz
else
    install_pacman "lazygit"
fi
echo ""
((STEP++))

# ============================================
# Claude Code (native installer)
# ============================================
echo -e "${CYAN}[$STEP/$TOTAL] Installing Claude Code...${NC}"
curl -fsSL https://claude.ai/install.sh | sh
echo ""
((STEP++))

# ============================================
# Gemini CLI (via bun)
# ============================================
echo -e "${CYAN}[$STEP/$TOTAL] Installing Gemini CLI...${NC}"
# Source bun to make it available
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
if command -v bun &> /dev/null; then
    bun install -g @google/generative-ai-cli || echo -e "${YELLOW}Gemini CLI may need manual install${NC}"
else
    echo -e "${YELLOW}Bun not found in PATH yet. After restart run:${NC}"
    echo -e "${CYAN}  bun install -g @google/generative-ai-cli${NC}"
fi
echo ""
((STEP++))

# ============================================
# Beads (bd/bv)
# ============================================
echo -e "${CYAN}[$STEP/$TOTAL] Installing Beads (bd)...${NC}"
curl -fsSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash
echo ""
((STEP++))

# ============================================
# Cursor
# ============================================
echo -e "${CYAN}[$STEP/$TOTAL] Installing Cursor...${NC}"
if [[ "$PKG_MANAGER" == "apt" ]]; then
    echo -e "${YELLOW}Cursor requires manual download from:${NC}"
    echo -e "${CYAN}  https://www.cursor.com/download${NC}"
else
    install_aur "cursor-bin"
fi
echo ""
((STEP++))

# ============================================
# Summary
# ============================================
echo -e "${CYAN}========================================"
echo -e "  Installation Summary"
echo -e "========================================${NC}"
echo ""
echo -e "${GREEN}Installed:${NC}"
echo "  - Git"
echo "  - Build essentials"
echo "  - tmux"
echo "  - htop"
echo "  - Ghostty (Arch) / manual (Ubuntu)"
echo "  - Node.js"
echo "  - Bun"
echo "  - Go"
echo "  - Python 3"
echo "  - Zig"
echo "  - ZLS"
echo "  - ARM GNU Toolchain"
echo "  - Docker"
echo "  - QEMU"
echo "  - LazyGit"
echo "  - Claude Code"
echo "  - Beads (bd/bv)"
echo "  - Cursor (Arch) / manual (Ubuntu)"
echo ""
echo -e "${YELLOW}Manual installation may be required:${NC}"
echo "  - Antigravity IDE (https://antigravity.google)"
if [[ "$PKG_MANAGER" == "apt" ]]; then
    echo "  - Ghostty (https://ghostty.org/docs/install)"
    echo "  - Cursor (https://www.cursor.com/download)"
fi
echo ""
echo -e "${CYAN}========================================"
echo -e "  Post-Installation Steps"
echo -e "========================================${NC}"
echo ""
echo -e "${YELLOW}1. LOG OUT AND BACK IN for docker group to take effect${NC}"
echo ""
echo -e "${YELLOW}2. Restart terminal or run:${NC}"
echo -e "${CYAN}   source ~/.bashrc${NC}"
echo ""
echo -e "${YELLOW}3. Verify installations:${NC}"
echo "   git --version"
echo "   tmux -V"
echo "   node --version"
echo "   bun --version"
echo "   go version"
echo "   python3 --version"
echo "   zig version"
echo "   zls --version"
echo "   arm-none-eabi-gcc --version"
echo "   docker --version"
echo "   qemu-system-aarch64 --version"
echo "   lazygit --version"
echo "   claude --version"
echo "   bd version"
