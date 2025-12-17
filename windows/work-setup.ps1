# Work Machine Setup Script
# Installs work-related applications for a fresh Windows machine
# Run as Administrator recommended

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Work Machine Setup Script" -ForegroundColor Cyan
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
$totalSteps = 7

# ============================================
# Google Chrome
# ============================================
Write-Host "[$stepNum/$totalSteps] Installing Google Chrome..." -ForegroundColor Yellow
winget install -e --id Google.Chrome --accept-package-agreements --accept-source-agreements
if ($LASTEXITCODE -eq 0) {
    Write-Host "Google Chrome installed successfully!" -ForegroundColor Green
}
else {
    Write-Host "Google Chrome installation may have failed or was already installed" -ForegroundColor Yellow
}
Write-Host ""
$stepNum++

# ============================================
# Google Drive
# ============================================
Write-Host "[$stepNum/$totalSteps] Installing Google Drive..." -ForegroundColor Yellow
winget install -e --id Google.GoogleDrive --accept-package-agreements --accept-source-agreements
if ($LASTEXITCODE -eq 0) {
    Write-Host "Google Drive installed successfully!" -ForegroundColor Green
}
else {
    Write-Host "Google Drive installation may have failed or was already installed" -ForegroundColor Yellow
}
Write-Host ""
$stepNum++

# ============================================
# 7-Zip
# ============================================
Write-Host "[$stepNum/$totalSteps] Installing 7-Zip..." -ForegroundColor Yellow
winget install -e --id 7zip.7zip --accept-package-agreements --accept-source-agreements
if ($LASTEXITCODE -eq 0) {
    Write-Host "7-Zip installed successfully!" -ForegroundColor Green
}
else {
    Write-Host "7-Zip installation may have failed or was already installed" -ForegroundColor Yellow
}
Write-Host ""
$stepNum++

# ============================================
# WireGuard VPN
# ============================================
Write-Host "[$stepNum/$totalSteps] Installing WireGuard..." -ForegroundColor Yellow
winget install -e --id WireGuard.WireGuard --accept-package-agreements --accept-source-agreements
if ($LASTEXITCODE -eq 0) {
    Write-Host "WireGuard installed successfully!" -ForegroundColor Green
}
else {
    Write-Host "WireGuard installation may have failed or was already installed" -ForegroundColor Yellow
}
Write-Host ""
$stepNum++

# ============================================
# ENERCALC
# ============================================
Write-Host "[$stepNum/$totalSteps] Installing ENERCALC..." -ForegroundColor Yellow
winget install -e --id ENERCALC.ENERCALC --accept-package-agreements --accept-source-agreements
if ($LASTEXITCODE -eq 0) {
    Write-Host "ENERCALC installed successfully!" -ForegroundColor Green
}
else {
    Write-Host "ENERCALC installation may have failed or was already installed" -ForegroundColor Yellow
}
Write-Host ""
$stepNum++

# ============================================
# PDF-XChange Editor
# ============================================
Write-Host "[$stepNum/$totalSteps] Installing PDF-XChange Editor..." -ForegroundColor Yellow
winget install -e --id TrackerSoftware.PDF-XChangeEditor --accept-package-agreements --accept-source-agreements
if ($LASTEXITCODE -eq 0) {
    Write-Host "PDF-XChange Editor installed successfully!" -ForegroundColor Green
}
else {
    Write-Host "PDF-XChange Editor installation may have failed or was already installed" -ForegroundColor Yellow
}
Write-Host ""
$stepNum++

# ============================================
# ArchiCAD (Manual Installation Required)
# ============================================
Write-Host "[$stepNum/$totalSteps] ArchiCAD..." -ForegroundColor Yellow
Write-Host "NOTE: ArchiCAD is NOT available via winget." -ForegroundColor Magenta
Write-Host "Please download and install manually from:" -ForegroundColor Magenta
Write-Host "  https://graphisoft.com/downloads" -ForegroundColor Cyan
Write-Host ""

# ============================================
# Summary
# ============================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Installation Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Installed via winget:" -ForegroundColor Green
Write-Host "  - Google Chrome" -ForegroundColor White
Write-Host "  - Google Drive" -ForegroundColor White
Write-Host "  - 7-Zip" -ForegroundColor White
Write-Host "  - WireGuard" -ForegroundColor White
Write-Host "  - ENERCALC" -ForegroundColor White
Write-Host "  - PDF-XChange Editor" -ForegroundColor White
Write-Host ""
Write-Host "Manual installation required:" -ForegroundColor Yellow
Write-Host "  - ArchiCAD (https://graphisoft.com/downloads)" -ForegroundColor White
Write-Host ""
Write-Host "You may need to restart your terminal or computer" -ForegroundColor Yellow
Write-Host "for PATH changes to take effect." -ForegroundColor Yellow
