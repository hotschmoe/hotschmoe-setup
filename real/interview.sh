#!/bin/bash
# interview.sh - Generate project docs through user interview

set -e
PROJECT_DIR="${1:-.}"

echo "═══════════════════════════════════════════════════════════"
echo "  PROJECT INTERVIEW"
echo "═══════════════════════════════════════════════════════════"

claude --print "You are interviewing me to create project documentation.
Ask me questions one at a time to build:

1. SPEC.md - Detailed feature list with [ ] checkboxes for each item
2. VISION.md - Concise north-star document (1 page max)  
3. testing.md - Testing regime (MUST be deterministic for automation)
4. releasing.md - When/how to push to master, tag releases, trigger CI

Start the interview now. Be thorough but efficient."

echo ""
echo "Interview complete. Files created in $PROJECT_DIR"
echo "Run: ./ralph.sh $PROJECT_DIR"