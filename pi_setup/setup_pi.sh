#!/usr/bin/env bash
# ═════════════════════════════════════════════════════════════
#  setup_pi.sh — Install pi.dev & configure a custom provider
#
#  1. Ensures a JS package manager (npm or bun) is available
#  2. Installs pi (@earendil-works/pi-coding-agent), skips if present
#  3. Prompts for a server URL (scheme + /v1 auto-normalized)
#     Provider name is derived from the URL host
#  4. Prompts for an API key (quote-tolerant)
#  5. Discovers models from <baseUrl>/models
#  6. Writes ~/.pi/agent/auth.json and models.json
#
#  Usage:  ./setup_pi.sh
#  Remote: curl -fsSL https://raw.githubusercontent.com/hotschmoe/hotschmoe-setup/main/setup_pi.sh | bash
#
#  Requires: curl, and one of {npm, bun}
# ═════════════════════════════════════════════════════════════
set -euo pipefail

# ─────────────────────────────────────────────────────────────
#  Defaults (all overridable at the prompt)
# ─────────────────────────────────────────────────────────────

DEFAULT_URL="llm.hotschmoe.com"
DEFAULT_CTX_WINDOW=131072
DEFAULT_MAX_TOKENS=64000

PI_PKG="@earendil-works/pi-coding-agent"
PI_CONFIG_DIR="${HOME}/.pi/agent"

# ─────────────────────────────────────────────────────────────
#  Helpers
# ─────────────────────────────────────────────────────────────

info()   { printf '\033[0;32m%s\033[0m\n' "$*"; }
warn()   { printf '\033[0;33m%s\033[0m\n' "$*"; }
err()    { printf '\033[0;31m%s\033[0m\n' "$*" >&2; }
detail() { printf '\033[0;90m  %s\033[0m\n' "$*"; }
accent() { printf '\033[0;36m  • %s\033[0m\n' "$*"; }

require_curl() {
    if ! command -v curl &>/dev/null; then
        err "curl is required but not found."
        exit 1
    fi
}

# Trim whitespace and strip one layer of surrounding single/double quotes.
sanitize() {
    local s="$1"
    # strip leading/trailing whitespace
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    # strip matching surrounding quotes
    if [[ ${#s} -ge 2 ]]; then
        if [[ "${s:0:1}" == '"' && "${s: -1}" == '"' ]]; then
            s="${s:1:${#s}-2}"
        elif [[ "${s:0:1}" == "'" && "${s: -1}" == "'" ]]; then
            s="${s:1:${#s}-2}"
        fi
    fi
    printf '%s' "$s"
}

# Normalize a user-supplied URL into a clean base URL ending in /v1.
#   llm.hotschmoe.com            -> http://llm.hotschmoe.com/v1
#   http://llm.hotschmoe.com     -> http://llm.hotschmoe.com/v1
#   https://x.com/v1/            -> https://x.com/v1
#   https://x.com/v1/models      -> https://x.com/v1
normalize_url() {
    local u
    u="$(sanitize "$1")"

    # Add scheme if missing. Bare hostnames default to http://.
    if [[ "$u" != http://* && "$u" != https://* ]]; then
        u="http://${u}"
    fi

    # Drop trailing slash(es)
    u="${u%/}"

    # Drop a trailing /models if the user pasted the full endpoint
    u="${u%/models}"
    u="${u%/}"

    # Ensure it ends in /v1 (don't double it up)
    if [[ "$u" != */v1 ]]; then
        u="${u}/v1"
    fi

    printf '%s' "$u"
}

# Derive provider name from the host: llm.hotschmoe.com -> hotschmoe
provider_from_url() {
    local u host
    u="$1"
    host="${u#http://}"
    host="${host#https://}"
    host="${host%%/*}"       # strip path
    host="${host%%:*}"       # strip port

    # Split host into dot-parts, pick the registrable label.
    # Simple heuristic: for a.b.c(.d) take the second-to-last label,
    # which turns llm.hotschmoe.com -> hotschmoe and hotschmoe.com -> hotschmoe.
    local IFS='.'
    read -r -a parts <<< "$host"
    local n=${#parts[@]}
    if (( n >= 2 )); then
        printf '%s' "${parts[n-2]}"
    else
        printf '%s' "$host"
    fi
}

# Extract model IDs from /v1/models JSON. Tries jq -> python3 -> python.
parse_model_ids() {
    local json="$1"

    if command -v jq &>/dev/null; then
        echo "$json" | jq -r '.data[].id' 2>/dev/null && return 0
    fi
    if command -v python3 &>/dev/null; then
        echo "$json" | python3 -c "
import json,sys
for m in json.load(sys.stdin).get('data',[]): print(m['id'])
" 2>/dev/null && return 0
    fi
    if command -v python &>/dev/null; then
        echo "$json" | python -c "
import json,sys
for m in json.load(sys.stdin).get('data',[]): print(m['id'])
" 2>/dev/null && return 0
    fi
    return 1
}

build_models_json() {
    local provider="$1" base_url="$2" api_key="$3"
    shift 3
    local model_ids=("$@")
    local models_block="" first=true

    for mid in "${model_ids[@]}"; do
        if [ "$first" = true ]; then first=false; else models_block+=","; fi
        models_block+="
        {
          \"id\": \"${mid}\",
          \"name\": \"${mid} (${provider} SGLang)\",
          \"contextWindow\": ${DEFAULT_CTX_WINDOW},
          \"maxTokens\": ${DEFAULT_MAX_TOKENS},
          \"input\": [\"text\"]
        }"
    done

    cat <<EOF
{
  "providers": {
    "${provider}": {
      "baseUrl": "${base_url}",
      "api": "openai-completions",
      "apiKey": "${api_key}",
      "models": [${models_block}
      ]
    }
  }
}
EOF
}

build_auth_json() {
    local provider="$1" api_key="$2"
    cat <<EOF
{
  "${provider}": {
    "apiKey": "${api_key}"
  }
}
EOF
}

# Pick a package manager and install pi. Prefers an existing global pi,
# then bun, then npm. If neither runtime exists, guides the user.
install_pi() {
    if command -v pi &>/dev/null; then
        local v; v="$(pi --version 2>/dev/null || echo unknown)"
        warn "  Already installed ($v) — skipping."
        return 0
    fi

    if command -v bun &>/dev/null; then
        echo "  Installing via bun..."
        bun install -g "$PI_PKG"
    elif command -v npm &>/dev/null; then
        echo "  Installing via npm..."
        npm install -g --ignore-scripts "$PI_PKG"
    else
        err "  Neither 'bun' nor 'npm' found."
        err "  pi needs a JavaScript package manager. Install one, then re-run:"
        detail "bun : curl -fsSL https://bun.com/install | bash"
        detail "node/npm : https://nodejs.org  (or use nvm)"
        exit 1
    fi

    # Make freshly-installed global bins visible in this session.
    export PATH="${HOME}/.bun/bin:${HOME}/.local/bin:${HOME}/.npm-global/bin:${PATH}"

    if command -v pi &>/dev/null; then
        info "  Installed!"
    else
        warn "  Installed, but 'pi' isn't on PATH yet."
        warn "  Restart your shell (or source your profile) and re-run to verify."
    fi
}

# ─────────────────────────────────────────────────────────────
#  Main
# ─────────────────────────────────────────────────────────────

echo ""
echo "========================================"
info "  Pi.dev Setup"
echo "========================================"
echo ""

require_curl

# ── Step 1: Install pi ──────────────────────────────────────
info "[1/5] Checking pi installation..."
install_pi

# ── Step 2: Prompt for URL, derive provider ─────────────────
echo ""
info "[2/5] Server configuration..."

read -r -p "  Server URL [${DEFAULT_URL}]: " RAW_URL
RAW_URL="${RAW_URL:-$DEFAULT_URL}"
BASE_URL="$(normalize_url "$RAW_URL")"
PROVIDER_NAME="$(provider_from_url "$BASE_URL")"

if [ -z "$PROVIDER_NAME" ]; then
    err "  Could not derive a provider name from the URL."
    exit 1
fi

read -r -s -p "  API key: " RAW_KEY
echo ""
API_KEY="$(sanitize "$RAW_KEY")"

if [ -z "$API_KEY" ]; then
    err "  API key cannot be empty."
    exit 1
fi

detail "Provider : ${PROVIDER_NAME}"
detail "URL      : ${BASE_URL}"
detail "Key      : ${API_KEY:0:12}..."

# ── Step 3: Discover models ─────────────────────────────────
echo ""
info "[3/5] Discovering models from ${BASE_URL} ..."

MODEL_IDS=()
response=$(curl -s --connect-timeout 10 \
    -H "Authorization: Bearer ${API_KEY}" \
    "${BASE_URL}/models" 2>/dev/null) || true

if [ -n "$response" ]; then
    mapfile -t MODEL_IDS < <(parse_model_ids "$response") || true
fi

if [ ${#MODEL_IDS[@]} -eq 0 ]; then
    err "  Could not discover models from ${BASE_URL}"
    err "  Make sure the server is running and the URL/API key are correct."
    exit 1
fi

info "  Discovered ${#MODEL_IDS[@]} model(s):"
for mid in "${MODEL_IDS[@]}"; do accent "$mid"; done

# ── Step 4: Write config ────────────────────────────────────
echo ""
info "[4/5] Writing pi configuration..."
mkdir -p "$PI_CONFIG_DIR"

auth_file="${PI_CONFIG_DIR}/auth.json"
models_file="${PI_CONFIG_DIR}/models.json"

build_auth_json "$PROVIDER_NAME" "$API_KEY" > "$auth_file"
detail "$auth_file"
build_models_json "$PROVIDER_NAME" "$BASE_URL" "$API_KEY" "${MODEL_IDS[@]}" > "$models_file"
detail "$models_file"

# ── Step 5: Verify ──────────────────────────────────────────
echo ""
info "[5/5] Verifying..."
if command -v pi &>/dev/null; then
    pi --version || true
else
    warn "  'pi' not found in PATH. Restart your terminal, then run:  pi"
fi

# ── Done ─────────────────────────────────────────────────────
echo ""
echo "========================================"
info "  Setup complete!"
echo "========================================"
echo ""
echo "  Provider : ${PROVIDER_NAME}"
echo "  Base URL : ${BASE_URL}"
echo "  Models   : ${#MODEL_IDS[@]} configured"
echo ""
info "  Run 'pi' to start."
echo ""

# Clear sensitive state
API_KEY=""; RAW_KEY=""
unset API_KEY RAW_KEY
