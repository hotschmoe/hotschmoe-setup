#!/bin/bash
# haj.sh - Hotschmoe Agent Injections
# Updates marked sections in CLAUDE.md or creates one if missing
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/Hotschmoe/hotschmoe-setup/master/real/haj.sh | bash
#   curl -sL https://raw.githubusercontent.com/Hotschmoe/hotschmoe-setup/master/real/haj.sh | bash -s -- ./path/to/CLAUDE.md
#
# If CLAUDE.md doesn't exist, creates one with standard sections.
# If it exists, updates only marked sections (preserves project-specific content).

set -e

SOURCE_URL="https://raw.githubusercontent.com/Hotschmoe/hotschmoe-setup/master/real/hotschmoe_agent_injections.md"
TARGET="${1:-./CLAUDE.md}"

# Default sections for new files
DEFAULT_SECTIONS="header rule-1-no-delete irreversible-actions code-discipline no-legacy dev-philosophy testing-philosophy footer"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}haj.sh - Hotschmoe Agent Injections${NC}"
echo ""

# Fetch source from GitHub
echo -e "Fetching source from GitHub..."
SOURCE_CONTENT=$(curl -sL "$SOURCE_URL")

if [ -z "$SOURCE_CONTENT" ]; then
    echo -e "${RED}Error: Failed to fetch source from GitHub${NC}"
    exit 1
fi

# If target doesn't exist, create it with default sections
if [ ! -f "$TARGET" ]; then
    echo -e "${YELLOW}$TARGET not found - creating with standard sections${NC}"
    echo ""

    # Create file with default sections
    > "$TARGET"

    for section in $DEFAULT_SECTIONS; do
        # Extract section from source (with markers)
        section_content=$(echo "$SOURCE_CONTENT" | sed -n "/<!-- BEGIN:$section -->/,/<!-- END:$section -->/p")

        if [ -n "$section_content" ]; then
            echo "$section_content" >> "$TARGET"
            echo "" >> "$TARGET"
            echo -e "${GREEN}Added: $section${NC}"
        else
            echo -e "${YELLOW}Skipped: $section (not found in source)${NC}"
        fi
    done

    # Add placeholder for project-specific content
    cat >> "$TARGET" << 'TEMPLATE'

---

## Project-Specific Content

<!-- Add your project's toolchain, architecture, workflows here -->
<!-- This section will not be touched by haj.sh -->

TEMPLATE

    echo ""
    echo -e "${GREEN}Created: $TARGET${NC}"
    echo -e "Edit the file to add project-specific content, then run again to update sections."
    exit 0
fi

# File exists - update marked sections
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
    
    # Build the exact marker strings
    begin_marker="<!-- BEGIN:$section -->"
    end_marker="<!-- END:$section -->"

    awk -v begin_marker="$begin_marker" -v end_marker="$end_marker" -v new_content="$new_content" '
        BEGIN { in_section = 0 }
        {
            # Check for begin marker (exact match or contains)
            if (index($0, begin_marker) > 0) {
                in_section = 1
                print new_content
                next
            }
            # Check for end marker
            if (index($0, end_marker) > 0) {
                in_section = 0
                next
            }
            # Print lines outside of section
            if (!in_section) { print }
        }
    ' "$TARGET" > "$temp_file"

    mv "$temp_file" "$TARGET"
    echo -e "${GREEN}Updated: $section${NC}"
    ((updated++))
done

echo ""
echo -e "${GREEN}Done.${NC} Updated: $updated, Skipped: $skipped"
