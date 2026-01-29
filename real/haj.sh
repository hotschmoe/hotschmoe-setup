#!/bin/bash
# haj.sh - Hotschmoe Agent Injections
# Updates all marked sections in CLAUDE.md from single source of truth
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/Hotschmoe/hotschmoe-setup/master/real/haj.sh | bash
#   curl -sL https://raw.githubusercontent.com/Hotschmoe/hotschmoe-setup/master/real/haj.sh | bash -s -- ./path/to/CLAUDE.md
#
# The script fetches the source from GitHub and updates ONLY marked sections,
# preserving all project-specific content.

set -e

SOURCE_URL="https://raw.githubusercontent.com/Hotschmoe/hotschmoe-setup/master/real/hotschmoe_agent_injections.md"
TARGET="${1:-./CLAUDE.md}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}haj.sh - Hotschmoe Agent Injections${NC}"
echo ""

# Check target exists
if [ ! -f "$TARGET" ]; then
    echo -e "${RED}Error: Target file not found: $TARGET${NC}"
    echo ""
    echo "To initialize a new CLAUDE.md, create it with section markers first."
    echo "See: https://github.com/Hotschmoe/hotschmoe-setup/blob/master/real/how_to_inject.md"
    exit 1
fi

# Fetch source from GitHub
echo -e "Fetching source from GitHub..."
SOURCE_CONTENT=$(curl -sL "$SOURCE_URL")

if [ -z "$SOURCE_CONTENT" ]; then
    echo -e "${RED}Error: Failed to fetch source from GitHub${NC}"
    exit 1
fi

# Find all sections in target file
SECTIONS=$(grep -oP '(?<=<!-- BEGIN:)[^> ]+(?= -->)' "$TARGET" 2>/dev/null || true)

if [ -z "$SECTIONS" ]; then
    echo -e "${YELLOW}No marked sections found in $TARGET${NC}"
    echo ""
    echo "Sections use markers like: <!-- BEGIN:section-name --> ... <!-- END:section-name -->"
    echo "See: https://github.com/Hotschmoe/hotschmoe-setup/blob/master/real/how_to_inject.md"
    exit 0
fi

echo -e "Target: ${BLUE}$TARGET${NC}"
echo -e "Found sections: $(echo $SECTIONS | tr '\n' ' ')"
echo ""

# Update each section
updated=0
skipped=0

for section in $SECTIONS; do
    # Check if section exists in source
    if ! echo "$SOURCE_CONTENT" | grep -q "<!-- BEGIN:$section -->"; then
        echo -e "${YELLOW}Skipped: $section (not in source)${NC}"
        ((skipped++))
        continue
    fi

    # Extract section from source (with markers)
    new_content=$(echo "$SOURCE_CONTENT" | sed -n "/<!-- BEGIN:$section -->/,/<!-- END:$section -->/p")

    # Replace section in target using temp file
    temp_file=$(mktemp)

    awk -v section="$section" -v new_content="$new_content" '
        BEGIN { in_section = 0 }
        $0 ~ "<!-- BEGIN:" section " -->" {
            in_section = 1
            print new_content
            next
        }
        $0 ~ "<!-- END:" section " -->" {
            in_section = 0
            next
        }
        !in_section { print }
    ' "$TARGET" > "$temp_file"

    mv "$temp_file" "$TARGET"
    echo -e "${GREEN}Updated: $section${NC}"
    ((updated++))
done

echo ""
echo -e "${GREEN}Done.${NC} Updated: $updated, Skipped: $skipped"
