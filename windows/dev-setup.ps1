# Developer Machine Setup Script
# Installs development tools for a fresh Windows machine
# Run as Administrator recommended
# 
# Note: WSL2 is installed with Ubuntu for Docker and general Linux dev,
# but Zig v0.15.0+ fails to build on WSL, so Zig dev stays on native Windows

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Developer Machine Setup Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if winget is available
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: winget is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install App Installer from Microsoft Store" -ForegroundColor Yellow
    exit 1
}

Write-Host "winget found. Starting installations..." -ForegroundColor Green
Write-Host ""

$stepNum = 1
$totalSteps = 18

# ============================================
# WSL2 with Ubuntu (needed for Docker, general Linux dev)
# ============================================
Write-Host "[$stepNum/$totalSteps] Installing WSL2 with Ubuntu..." -ForegroundColor Yellow
Write-Host "This enables Windows Subsystem for Linux 2 and installs Ubuntu (latest LTS)" -ForegroundColor Magenta

# Check if WSL is already installed
$wslInstalled = $false
try {
    $wslStatus = wsl --status 2>&1
    if ($LASTEXITCODE -eq 0) {
        $wslInstalled = $true
        Write-Host "WSL is already installed." -ForegroundColor Green
    }
}
catch {
    # WSL not installed
}

if (-not $wslInstalled) {
    Write-Host "Installing WSL2 (this may require a reboot)..." -ForegroundColor Yellow
    wsl --install -d Ubuntu
    if ($LASTEXITCODE -eq 0) {
        Write-Host "WSL2 with Ubuntu installation initiated!" -ForegroundColor Green
        Write-Host "NOTE: You may need to REBOOT and run this script again to complete setup." -ForegroundColor Magenta
        Write-Host "After reboot, Ubuntu will prompt you to create a username/password." -ForegroundColor Magenta
    }
    else {
        Write-Host "WSL installation may have failed. Try manually:" -ForegroundColor Yellow
        Write-Host "  wsl --install -d Ubuntu" -ForegroundColor Cyan
    }
}
else {
    # Check if Ubuntu is installed
    $distros = wsl --list --quiet 2>&1
    if ($distros -match "Ubuntu") {
        Write-Host "Ubuntu is already installed in WSL." -ForegroundColor Green
    }
    else {
        Write-Host "Installing Ubuntu distribution..." -ForegroundColor Yellow
        wsl --install -d Ubuntu
        Write-Host "Ubuntu installation initiated." -ForegroundColor Green
    }
}
Write-Host ""
$stepNum++

# ============================================
# Prerequisites: Git (needed for many tools)
# ============================================
Write-Host "[$stepNum/$totalSteps] Installing Git..." -ForegroundColor Yellow
winget install -e --id Git.Git --accept-package-agreements --accept-source-agreements
if ($LASTEXITCODE -eq 0) {
    Write-Host "Git installed successfully!" -ForegroundColor Green
}
else {
    Write-Host "Git installation may have failed or was already installed" -ForegroundColor Yellow
}
Write-Host ""
$stepNum++

# ============================================
# Bun (fast JavaScript runtime, replaces npm)
# ============================================
Write-Host "[$stepNum/$totalSteps] Installing Bun..." -ForegroundColor Yellow
winget install -e --id Oven-sh.Bun --accept-package-agreements --accept-source-agreements
if ($LASTEXITCODE -eq 0) {
    Write-Host "Bun installed successfully!" -ForegroundColor Green
}
else {
    Write-Host "Bun installation may have failed or was already installed" -ForegroundColor Yellow
}
Write-Host ""
$stepNum++

# ============================================
# Node.js LTS (still useful for compatibility)
# ============================================
Write-Host "[$stepNum/$totalSteps] Installing Node.js LTS..." -ForegroundColor Yellow
winget install -e --id OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements
if ($LASTEXITCODE -eq 0) {
    Write-Host "Node.js LTS installed successfully!" -ForegroundColor Green
}
else {
    Write-Host "Node.js installation may have failed or was already installed" -ForegroundColor Yellow
}
Write-Host ""
$stepNum++

# ============================================
# Go (required for Beads language if native install fails)
# ============================================
Write-Host "[$stepNum/$totalSteps] Installing Go..." -ForegroundColor Yellow
winget install -e --id GoLang.Go --accept-package-agreements --accept-source-agreements
if ($LASTEXITCODE -eq 0) {
    Write-Host "Go installed successfully!" -ForegroundColor Green
}
else {
    Write-Host "Go installation may have failed or was already installed" -ForegroundColor Yellow
}
Write-Host ""
$stepNum++

# ============================================
# Python (latest, >= 3.12)
# ============================================
Write-Host "[$stepNum/$totalSteps] Installing Python (latest)..." -ForegroundColor Yellow
winget install -e --id Python.Python.3.12 --accept-package-agreements --accept-source-agreements
if ($LASTEXITCODE -eq 0) {
    Write-Host "Python 3.12 installed successfully!" -ForegroundColor Green
}
else {
    Write-Host "Python installation may have failed or was already installed" -ForegroundColor Yellow
}
Write-Host ""
$stepNum++

# ============================================
# Zig (latest)
# ============================================
Write-Host "[$stepNum/$totalSteps] Installing Zig..." -ForegroundColor Yellow
winget install -e --id zig.zig --accept-package-agreements --accept-source-agreements
if ($LASTEXITCODE -eq 0) {
    Write-Host "Zig installed successfully!" -ForegroundColor Green
}
else {
    Write-Host "Zig installation may have failed or was already installed" -ForegroundColor Yellow
}
Write-Host ""
$stepNum++

# ============================================
# ZLS (Zig Language Server)
# ============================================
Write-Host "[$stepNum/$totalSteps] Installing ZLS (Zig Language Server)..." -ForegroundColor Yellow
winget install -e --id zigtools.zls --accept-package-agreements --accept-source-agreements
if ($LASTEXITCODE -eq 0) {
    Write-Host "ZLS installed successfully!" -ForegroundColor Green
}
else {
    Write-Host "ZLS installation may have failed or was already installed" -ForegroundColor Yellow
}
Write-Host ""
$stepNum++

# ============================================
# ARM GNU Toolchain
# ============================================
Write-Host "[$stepNum/$totalSteps] Installing ARM GNU Toolchain..." -ForegroundColor Yellow
winget install -e --id Arm.ArmGnuToolchain --accept-package-agreements --accept-source-agreements
if ($LASTEXITCODE -eq 0) {
    Write-Host "ARM GNU Toolchain installed successfully!" -ForegroundColor Green
}
else {
    Write-Host "ARM GNU Toolchain installation may have failed or was already installed" -ForegroundColor Yellow
}
Write-Host ""
$stepNum++

# ============================================
# Docker Desktop (uses WSL2 backend)
# ============================================
Write-Host "[$stepNum/$totalSteps] Installing Docker Desktop..." -ForegroundColor Yellow
winget install -e --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements
if ($LASTEXITCODE -eq 0) {
    Write-Host "Docker Desktop installed successfully!" -ForegroundColor Green
    Write-Host "Docker will use WSL2 backend (installed above)" -ForegroundColor Magenta
}
else {
    Write-Host "Docker Desktop installation may have failed or was already installed" -ForegroundColor Yellow
}
Write-Host ""
$stepNum++

# ============================================
# QEMU
# ============================================
Write-Host "[$stepNum/$totalSteps] Installing QEMU..." -ForegroundColor Yellow
winget install -e --id SoftwareFreedomConservancy.QEMU --accept-package-agreements --accept-source-agreements
if ($LASTEXITCODE -eq 0) {
    Write-Host "QEMU installed successfully!" -ForegroundColor Green
}
else {
    Write-Host "QEMU installation may have failed or was already installed" -ForegroundColor Yellow
}
Write-Host ""
$stepNum++

# ============================================
# Cursor (AI Code Editor)
# ============================================
Write-Host "[$stepNum/$totalSteps] Installing Cursor..." -ForegroundColor Yellow
winget install -e --id Anysphere.Cursor --accept-package-agreements --accept-source-agreements
if ($LASTEXITCODE -eq 0) {
    Write-Host "Cursor installed successfully!" -ForegroundColor Green
}
else {
    Write-Host "Cursor installation may have failed or was already installed" -ForegroundColor Yellow
}
Write-Host ""
$stepNum++

# ============================================
# GitHub Desktop
# ============================================
Write-Host "[$stepNum/$totalSteps] Installing GitHub Desktop..." -ForegroundColor Yellow
winget install -e --id GitHub.GitHubDesktop --accept-package-agreements --accept-source-agreements
if ($LASTEXITCODE -eq 0) {
    Write-Host "GitHub Desktop installed successfully!" -ForegroundColor Green
}
else {
    Write-Host "GitHub Desktop installation may have failed or was already installed" -ForegroundColor Yellow
}
Write-Host ""

# Also install LazyGit as an alternative
Write-Host "[$stepNum/$totalSteps] Installing LazyGit (alternative)..." -ForegroundColor Yellow
winget install -e --id JesseDuffield.lazygit --accept-package-agreements --accept-source-agreements
if ($LASTEXITCODE -eq 0) {
    Write-Host "LazyGit installed successfully!" -ForegroundColor Green
}
else {
    Write-Host "LazyGit installation may have failed or was already installed" -ForegroundColor Yellow
}
Write-Host ""
$stepNum++

# ============================================
# Claude Code (native PowerShell installer)
# ============================================
Write-Host "[$stepNum/$totalSteps] Installing Claude Code (native installer)..." -ForegroundColor Yellow
try {
    Invoke-Expression ((Invoke-WebRequest -Uri "https://claude.ai/install.ps1" -UseBasicParsing).Content)
    Write-Host "Claude Code installed successfully!" -ForegroundColor Green
}
catch {
    Write-Host "Claude Code installation failed. Manual install:" -ForegroundColor Yellow
    Write-Host "  irm https://claude.ai/install.ps1 | iex" -ForegroundColor Cyan
}
Write-Host ""
$stepNum++

# ============================================
# Refresh PATH for bun installations
# ============================================
Write-Host "Refreshing environment variables..." -ForegroundColor Yellow
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
Write-Host ""

# ============================================
# Gemini CLI (via bun - faster than npm)
# ============================================
Write-Host "[$stepNum/$totalSteps] Installing Gemini CLI (via bun)..." -ForegroundColor Yellow
if (Get-Command bun -ErrorAction SilentlyContinue) {
    bun install -g @google/generative-ai-cli 2>$null
    Write-Host "Gemini CLI installation attempted." -ForegroundColor Green
}
else {
    Write-Host "bun not found - you may need to restart terminal and run:" -ForegroundColor Magenta
    Write-Host "  bun install -g @google/generative-ai-cli" -ForegroundColor Cyan
}
Write-Host ""
$stepNum++

# ============================================
# Beads (bd) - Native PowerShell installer
# ============================================
Write-Host "[$stepNum/$totalSteps] Installing Beads (bd) via native installer..." -ForegroundColor Yellow
try {
    Invoke-Expression ((Invoke-WebRequest -Uri "https://raw.githubusercontent.com/steveyegge/beads/main/install.ps1" -UseBasicParsing).Content)
    Write-Host "Beads (bd) installed successfully!" -ForegroundColor Green
}
catch {
    Write-Host "Beads installer failed. Manual install after restart:" -ForegroundColor Yellow
    Write-Host "  irm https://raw.githubusercontent.com/steveyegge/beads/main/install.ps1 | iex" -ForegroundColor Cyan
    Write-Host "  or: go install github.com/steveyegge/beads/cmd/bd@latest" -ForegroundColor Cyan
}
Write-Host ""
$stepNum++

# ============================================
# Beads Viewer (bv) - included in Beads installer
# ============================================
Write-Host "[$stepNum/$totalSteps] Beads Viewer (bv)..." -ForegroundColor Yellow
Write-Host "bv should be included with the Beads installation above." -ForegroundColor Green
Write-Host "If not available, run after restart:" -ForegroundColor Magenta
Write-Host "  go install github.com/steveyegge/beads/cmd/bv@latest" -ForegroundColor Cyan
Write-Host ""
$stepNum++

# ============================================
# Antigravity (Google's Agent-first IDE)
# ============================================
Write-Host "[$stepNum/$totalSteps] Antigravity IDE..." -ForegroundColor Yellow
Write-Host "NOTE: Antigravity requires manual download from:" -ForegroundColor Magenta
Write-Host "  https://antigravity.google" -ForegroundColor Cyan
Write-Host "Download the Windows installer (.exe) and run it." -ForegroundColor Magenta
Write-Host ""

# ============================================
# Summary
# ============================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Installation Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Installed via wsl --install:" -ForegroundColor Green
Write-Host "  - WSL2 with Ubuntu (latest LTS)" -ForegroundColor White
Write-Host ""
Write-Host "Installed via winget:" -ForegroundColor Green
Write-Host "  - Git" -ForegroundColor White
Write-Host "  - Bun" -ForegroundColor White
Write-Host "  - Node.js LTS" -ForegroundColor White
Write-Host "  - Go" -ForegroundColor White
Write-Host "  - Python 3.12" -ForegroundColor White
Write-Host "  - Zig" -ForegroundColor White
Write-Host "  - ZLS (Zig Language Server)" -ForegroundColor White
Write-Host "  - ARM GNU Toolchain" -ForegroundColor White
Write-Host "  - Docker Desktop" -ForegroundColor White
Write-Host "  - QEMU" -ForegroundColor White
Write-Host "  - Cursor" -ForegroundColor White
Write-Host "  - GitHub Desktop" -ForegroundColor White
Write-Host "  - LazyGit" -ForegroundColor White
Write-Host ""
Write-Host "Installed via native PowerShell installers:" -ForegroundColor Green
Write-Host "  - Claude Code (irm https://claude.ai/install.ps1 | iex)" -ForegroundColor White
Write-Host "  - Beads (bd/bv)" -ForegroundColor White
Write-Host ""
Write-Host "Installed via bun:" -ForegroundColor Green
Write-Host "  - Gemini CLI" -ForegroundColor White
Write-Host ""
Write-Host "Manual installation required:" -ForegroundColor Yellow
Write-Host "  - Antigravity IDE (https://antigravity.google)" -ForegroundColor White
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Post-Installation Steps" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. REBOOT if WSL2 was just installed (required to complete WSL setup)" -ForegroundColor Yellow
Write-Host "   After reboot, Ubuntu will prompt you to create a username/password." -ForegroundColor Cyan
Write-Host ""
Write-Host "2. RESTART YOUR TERMINAL for PATH changes to take effect" -ForegroundColor Yellow
Write-Host ""
Write-Host "3. If Claude Code failed, run after restart:" -ForegroundColor Yellow
Write-Host "   irm https://claude.ai/install.ps1 | iex" -ForegroundColor Cyan
Write-Host ""
Write-Host "4. If Beads failed, run after restart:" -ForegroundColor Yellow
Write-Host "   irm https://raw.githubusercontent.com/steveyegge/beads/main/install.ps1 | iex" -ForegroundColor Cyan
Write-Host ""
Write-Host "5. Download Antigravity from:" -ForegroundColor Yellow
Write-Host "   https://antigravity.google" -ForegroundColor Cyan
Write-Host ""
Write-Host "6. Verify installations:" -ForegroundColor Yellow
Write-Host "   wsl --version" -ForegroundColor Cyan
Write-Host "   wsl --list" -ForegroundColor Cyan
Write-Host "   git --version" -ForegroundColor Cyan
Write-Host "   bun --version" -ForegroundColor Cyan
Write-Host "   node --version" -ForegroundColor Cyan
Write-Host "   go version" -ForegroundColor Cyan
Write-Host "   python --version" -ForegroundColor Cyan
Write-Host "   zig version" -ForegroundColor Cyan
Write-Host "   zls --version" -ForegroundColor Cyan
Write-Host "   arm-none-eabi-gcc --version" -ForegroundColor Cyan
Write-Host "   docker --version" -ForegroundColor Cyan
Write-Host "   qemu-system-aarch64 --version" -ForegroundColor Cyan
Write-Host "   claude --version" -ForegroundColor Cyan
Write-Host "   lazygit --version" -ForegroundColor Cyan
Write-Host "   bd version" -ForegroundColor Cyan
