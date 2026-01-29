#!/bin/bash
# One-liner: curl -fsSL https://raw.githubusercontent.com/.../install-ralph.sh | bash
set -e
mkdir -p ~/.local/bin && cp -f "$(dirname "$0")/ralph_beads.sh" ~/.local/bin/hot_ralph && chmod +x ~/.local/bin/hot_ralph && echo "Installed: ~/.local/bin/hot_ralph ($(date +%Y-%m-%d))"
