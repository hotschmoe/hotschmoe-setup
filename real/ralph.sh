#!/bin/bash
set -e

PROJECT_DIR="${1:-.}"
MAX_ITERATIONS="${2:-100}"

# jq filters for streaming JSON output
STREAM_TEXT='select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text // empty'
FINAL_RESULT='select(.type == "result") | .result // empty'

# Check required files exist
for file in SPEC.md VISION.md testing.md; do
    if [[ ! -f "$PROJECT_DIR/$file" ]]; then
        echo "ERROR: Missing $file - run interview phase first"
        exit 1
    fi
done

check_spec_complete() {
    # Returns 0 if all items checked, 1 if work remains
    # Counts unchecked boxes [ ] vs checked [x]
    local unchecked=$(grep -c '\[ \]' "$PROJECT_DIR/SPEC.md" 2>/dev/null || echo "0")
    [[ "$unchecked" -eq 0 ]]
}

run_claude() {
    local prompt="$1"
    local tmpfile=$(mktemp)
    trap "rm -f '$tmpfile'" RETURN
    
    claude \
        --print \
        --output-format stream-json \
        --dangerously-skip-permissions \
        "$prompt" \
    | tee "$tmpfile" \
    | jq --unbuffered -rj "$STREAM_TEXT"
    
    jq -r "$FINAL_RESULT" "$tmpfile"
}

# ═══════════════════════════════════════════════════════════════════
#  MAIN LOOP
# ═══════════════════════════════════════════════════════════════════

cd "$PROJECT_DIR"

for ((i=1; i<=MAX_ITERATIONS; i++)); do
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  ITERATION $i"
    echo "═══════════════════════════════════════════════════════════"
    
    # ─────────────────────────────────────────────────────────────
    # (a) PLAN - analyze spec and plan next features
    # ─────────────────────────────────────────────────────────────
    echo "[STEP A] Entering plan mode..."
    
    run_claude "Read @SPEC.md and @testing.md and @VISION.md. 
        Enter plan mode. Identify the next 5 uncompleted features (marked [ ]) 
        and create a detailed implementation plan. 
        Consider the testing regime - all changes must be deterministic and testable.
        Output your plan, then wait for approval."
    
    # ─────────────────────────────────────────────────────────────
    # (b) ACCEPT - auto-accept or prompt user
    # ─────────────────────────────────────────────────────────────
    echo ""
    echo "[STEP B] Plan review..."
    read -p "Accept plan? [Y/n/q] " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Qq]$ ]]; then
        echo "Exiting at user request."
        exit 0
    elif [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "Plan rejected, restarting iteration..."
        continue
    fi
    
    # ─────────────────────────────────────────────────────────────
    # (c) EXECUTE - implement, commit, simplify
    # ─────────────────────────────────────────────────────────────
    echo "[STEP C] Executing plan..."
    
    run_claude "Execute the plan you just created.
        Implement each feature with deterministic tests per @testing.md.
        After implementation:
        1. Run all tests to verify
        2. Mark completed items in SPEC.md as [x]
        3. Git commit with descriptive message
        4. Git push
        5. Run codesimplifier to review and simplify the code
        6. If simplifications made, commit and push again"
    
    # ─────────────────────────────────────────────────────────────
    # (d) CHECK - are we done?
    # ─────────────────────────────────────────────────────────────
    echo "[STEP D] Checking completion status..."
    
    if check_spec_complete; then
        echo ""
        echo "═══════════════════════════════════════════════════════════"
        echo "  ✓ SPEC COMPLETE after $i iterations!"
        echo "═══════════════════════════════════════════════════════════"
        
        # Final vision check
        run_claude "All SPEC.md items are complete. 
            Review @VISION.md - does the current codebase embody the vision?
            Summarize what was built and any remaining gaps."
        
        echo ""
        echo "Ready for next interview phase? Run: ./interview.sh"
        exit 0
    fi
    
    # ─────────────────────────────────────────────────────────────
    # (async) SELF-IMPROVEMENT - randomly update tooling
    # ─────────────────────────────────────────────────────────────
    if (( RANDOM % 5 == 0 )); then
        echo "[ASYNC] Self-improvement cycle..."
        run_claude "Review your recent work. Update:
            - CLAUDE.md with any learnings or project insights
            - .claude/ agents or commands if you've found better patterns
            - Add any new skills or tooling discoveries
            Keep updates minimal and high-value."
    fi
    
    # ─────────────────────────────────────────────────────────────
    # Context clear happens naturally (new claude invocation)
    # ─────────────────────────────────────────────────────────────
    echo "[RESET] Context cleared for next iteration."
    sleep 2
done

echo "WARNING: Hit max iterations ($MAX_ITERATIONS) without completing SPEC"
exit 1