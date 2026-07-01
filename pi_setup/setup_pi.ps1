<#
.SYNOPSIS
    Installs pi.dev and configures a custom SGLang/OpenAI-compatible provider.
.DESCRIPTION
    1. Ensures a JS package manager (npm or bun) is available
    2. Installs pi (@earendil-works/pi-coding-agent), skips if present
    3. Prompts for a server URL (scheme + /v1 auto-normalized).
       Provider name is derived from the URL host.
    4. Prompts for an API key (quote-tolerant)
    5. Discovers models from <baseUrl>/models
    6. Writes auth.json and models.json to ~/.pi/agent/
.EXAMPLE
    .\setup_pi.ps1
.EXAMPLE
    powershell -c "irm https://raw.githubusercontent.com/hotschmoe/hotschmoe-setup/main/setup_pi.ps1 | iex"
#>

#Requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ═════════════════════════════════════════════════════════════
#  Defaults (all overridable at the prompt)
# ═════════════════════════════════════════════════════════════

$DEFAULT_URL        = "llm.hotschmoe.com"
$DEFAULT_CTX_WINDOW = 131072
$DEFAULT_MAX_TOKENS = 64000

$PI_PKG = "@earendil-works/pi-coding-agent"

# ═════════════════════════════════════════════════════════════
#  Helpers
# ═════════════════════════════════════════════════════════════

function ConvertFrom-Secure([System.Security.SecureString]$s) {
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)
    try   { [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) }
    finally { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

# Trim whitespace and strip one layer of surrounding single/double quotes.
function Format-Input([string]$s) {
    if ($null -eq $s) { return "" }
    $s = $s.Trim()
    if ($s.Length -ge 2) {
        if (($s.StartsWith('"') -and $s.EndsWith('"')) -or
            ($s.StartsWith("'") -and $s.EndsWith("'"))) {
            $s = $s.Substring(1, $s.Length - 2)
        }
    }
    return $s
}

# Normalize a user-supplied URL into a clean base URL ending in /v1.
#   llm.hotschmoe.com        -> http://llm.hotschmoe.com/v1
#   https://x.com/v1/        -> https://x.com/v1
#   https://x.com/v1/models  -> https://x.com/v1
function Format-BaseUrl([string]$u) {
    $u = Format-Input $u

    if ($u -notmatch '^https?://') {
        $u = "http://$u"
    }
    $u = $u.TrimEnd('/')
    if ($u -match '/models$') {
        $u = $u -replace '/models$', ''
        $u = $u.TrimEnd('/')
    }
    if ($u -notmatch '/v1$') {
        $u = "$u/v1"
    }
    return $u
}

# Derive provider name from the host: llm.hotschmoe.com -> hotschmoe
function Get-ProviderFromUrl([string]$u) {
    $hostname = $u -replace '^https?://', ''
    $hostname = ($hostname -split '/')[0]     # strip path
    $hostname = ($hostname -split ':')[0]     # strip port
    $parts = $hostname -split '\.'
    if ($parts.Count -ge 2) {
        return $parts[$parts.Count - 2]
    }
    return $hostname
}

function Get-Models {
    param(
        [string]$Url,
        [string]$ApiKey,
        [string]$Provider
    )
    try {
        $headers = @{ Authorization = "Bearer $ApiKey" }
        $resp = Invoke-RestMethod -Uri "$Url/models" `
            -Headers $headers -TimeoutSec 10 -ErrorAction Stop

        if ($resp.data -and $resp.data.Count -gt 0) {
            $models = @()
            foreach ($m in $resp.data) {
                $models += [ordered]@{
                    id            = $m.id
                    name          = "$($m.id) ($Provider SGLang)"
                    contextWindow = $DEFAULT_CTX_WINDOW
                    maxTokens     = $DEFAULT_MAX_TOKENS
                    input         = @("text")
                }
            }
            return $models
        }
    }
    catch {
        Write-Host "  Could not reach server: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    return $null
}

function Build-ModelsJson {
    param(
        [string]$Provider,
        [string]$BaseUrl,
        [string]$ApiKey,
        [array]$Models
    )
    $modelsJson = @()
    foreach ($m in $Models) {
        $inputArr = ($m.input | ForEach-Object { "`"$_`"" }) -join ", "
        $modelsJson += @"
        {
          "id": "$($m.id)",
          "name": "$($m.name)",
          "contextWindow": $($m.contextWindow),
          "maxTokens": $($m.maxTokens),
          "input": [$inputArr]
        }
"@
    }
    $modelsBlock = $modelsJson -join ",`n"

    return @"
{
  "providers": {
    "$Provider": {
      "baseUrl": "$BaseUrl",
      "api": "openai-completions",
      "apiKey": "$ApiKey",
      "models": [
$modelsBlock
      ]
    }
  }
}
"@
}

function Build-AuthJson {
    param([string]$Provider, [string]$ApiKey)
    return @"
{
  "$Provider": {
    "apiKey": "$ApiKey"
  }
}
"@
}

function Install-Pi {
    $piCmd = Get-Command pi -ErrorAction SilentlyContinue
    if ($piCmd) {
        $ver = (& pi --version 2>$null) -replace '\s+', ' '
        Write-Host "  Already installed ($ver) — skipping." -ForegroundColor Yellow
        return
    }

    $bun = Get-Command bun -ErrorAction SilentlyContinue
    $npm = Get-Command npm -ErrorAction SilentlyContinue

    try {
        if ($bun) {
            Write-Host "  Installing via bun..."
            & bun install -g $PI_PKG
        }
        elseif ($npm) {
            Write-Host "  Installing via npm..."
            & npm install -g --ignore-scripts $PI_PKG
        }
        else {
            Write-Host "  Neither 'bun' nor 'npm' found." -ForegroundColor Red
            Write-Host "  pi needs a JavaScript package manager. Install one, then re-run:" -ForegroundColor Red
            Write-Host "    bun : powershell -c `"irm bun.sh/install.ps1 | iex`"" -ForegroundColor DarkGray
            Write-Host "    node/npm : https://nodejs.org" -ForegroundColor DarkGray
            exit 1
        }
    }
    catch {
        Write-Host "  ERROR: Installation failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }

    # Refresh PATH so we can find pi in this session
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")

    if (Get-Command pi -ErrorAction SilentlyContinue) {
        Write-Host "  Installed!" -ForegroundColor Green
    }
    else {
        Write-Host "  Installed, but 'pi' isn't on PATH yet." -ForegroundColor Yellow
        Write-Host "  Restart your terminal after setup to use it." -ForegroundColor Yellow
    }
}

# ═════════════════════════════════════════════════════════════
#  Main
# ═════════════════════════════════════════════════════════════

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Pi.dev Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ── Step 1: Install pi ──────────────────────────────────────
Write-Host "[1/5] Checking pi installation..." -ForegroundColor Green
Install-Pi

# ── Step 2: Prompt for URL, derive provider ─────────────────
Write-Host ""
Write-Host "[2/5] Server configuration..." -ForegroundColor Green

$rawUrl = Read-Host "  Server URL [$DEFAULT_URL]"
if ([string]::IsNullOrWhiteSpace($rawUrl)) { $rawUrl = $DEFAULT_URL }
$baseUrl      = Format-BaseUrl $rawUrl
$providerName = Get-ProviderFromUrl $baseUrl

if ([string]::IsNullOrWhiteSpace($providerName)) {
    Write-Host "  ERROR: Could not derive a provider name from the URL." -ForegroundColor Red
    exit 1
}

$apiKeySecure = Read-Host "  API key" -AsSecureString
$apiKey = Format-Input (ConvertFrom-Secure $apiKeySecure)

if ([string]::IsNullOrWhiteSpace($apiKey)) {
    Write-Host "  ERROR: API key cannot be empty." -ForegroundColor Red
    exit 1
}

$preview = $apiKey.Substring(0, [Math]::Min(12, $apiKey.Length))
Write-Host "  Provider : $providerName" -ForegroundColor DarkGray
Write-Host "  URL      : $baseUrl" -ForegroundColor DarkGray
Write-Host "  Key      : $preview..." -ForegroundColor DarkGray

# ── Step 3: Discover models ─────────────────────────────────
Write-Host ""
Write-Host "[3/5] Discovering models from $baseUrl ..." -ForegroundColor Green

$models = Get-Models -Url $baseUrl -ApiKey $apiKey -Provider $providerName

if ($models) {
    Write-Host "  Discovered $($models.Count) model(s):" -ForegroundColor Green
}
else {
    Write-Host "  ERROR: Could not discover models from $baseUrl" -ForegroundColor Red
    Write-Host "  Make sure the server is running and the URL/API key are correct." -ForegroundColor Red
    exit 1
}

foreach ($m in $models) {
    Write-Host "    * $($m.id)" -ForegroundColor Cyan
}

# Confirm before writing
Write-Host ""
$confirm = Read-Host "  Write config for provider '$providerName' at $baseUrl? [Y/n]"
if ($confirm -match '^(n|no)$') {
    Write-Host "  Aborted. No files written." -ForegroundColor Yellow
    exit 0
}

# ── Step 4: Write config ────────────────────────────────────
Write-Host ""
Write-Host "[4/5] Writing pi configuration..." -ForegroundColor Green

$piDir = Join-Path $env:USERPROFILE ".pi\agent"
if (-not (Test-Path $piDir)) {
    New-Item -ItemType Directory -Path $piDir -Force | Out-Null
    Write-Host "  Created $piDir" -ForegroundColor DarkGray
}

$authPath   = Join-Path $piDir "auth.json"
$modelsPath = Join-Path $piDir "models.json"

# Back up any existing config before overwriting
$ts = Get-Date -Format "yyyyMMdd-HHmmss"
foreach ($f in @($authPath, $modelsPath)) {
    if (Test-Path $f) {
        Copy-Item $f "$f.bak-$ts" -Force
        Write-Host "  backed up $(Split-Path $f -Leaf) -> $(Split-Path $f -Leaf).bak-$ts" -ForegroundColor DarkGray
    }
}

$authJson   = Build-AuthJson   -Provider $providerName -ApiKey $apiKey
$modelsJson = Build-ModelsJson -Provider $providerName -BaseUrl $baseUrl -ApiKey $apiKey -Models $models

Set-Content -Path $authPath   -Value $authJson   -Encoding UTF8 -Force
Set-Content -Path $modelsPath -Value $modelsJson -Encoding UTF8 -Force

Write-Host "  $authPath" -ForegroundColor DarkGray
Write-Host "  $modelsPath" -ForegroundColor DarkGray

# ── Step 5: Verify ──────────────────────────────────────────
Write-Host ""
Write-Host "[5/5] Verifying..." -ForegroundColor Green

if (Get-Command pi -ErrorAction SilentlyContinue) {
    Write-Host ""
    & pi --list-models
}
else {
    Write-Host "  'pi' not found in PATH." -ForegroundColor Yellow
    Write-Host "  Restart your terminal, then run:  pi --list-models" -ForegroundColor Yellow
}

# ── Done ─────────────────────────────────────────────────────
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Setup complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Provider : $providerName" -ForegroundColor White
Write-Host "  Base URL : $baseUrl" -ForegroundColor White
Write-Host "  Models   : $($models.Count) configured" -ForegroundColor White
Write-Host ""
Write-Host "  Run 'pi' to start." -ForegroundColor Cyan
Write-Host ""

# Clear sensitive state
$apiKey = $null
