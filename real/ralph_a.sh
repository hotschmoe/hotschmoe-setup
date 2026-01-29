#!/bin/bash
# ralph_a.sh - Session-persistent development loop
# Uses --resume to maintain context between PLAN and EXECUTE phases
set -e

PROJECT_DIR="${1:-.}"
MAX_ITERATIONS="${2:-100}"

# Session management
SESSION_FILE="$PROJECT_DIR/.ralph-session"

# jq filters for streaming JSON output
STREAM_TEXT='select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text // empty'
EXTRACT_SESSION='select(.type == "result") | .session_id // empty'

# ═══════════════════════════════════════════════════════════════════
#  UTILITIES
# ═══════════════════════════════════════════════════════════════════

log() {
    echo "[$(date '+%H:%M:%S')] $*"
}

check_requirements() {
    for file in SPEC.md VISION.md testing.md; do
        if [[ ! -f "$PROJECT_DIR/$file" ]]; then
            echo "ERROR: Missing $file"
            exit 1
        fi
    done

    if ! command -v jq &> /dev/null; then
        echo "ERROR: jq is required but not installed"
        exit 1
    fi

    if ! command -v claude &> /dev/null; then
        echo "ERROR: claude CLI is required but not installed"
        exit 1
    fi
}

check_spec_complete() {
    local unchecked=$(grep -c '\[ \]' "$PROJECT_DIR/SPEC.md" 2>/dev/null || echo "0")
    [[ "$unchecked" -eq 0 ]]
}

# ═══════════════════════════════════════════════════════════════════
#  SESSION MANAGEMENT
# ═══════════════════════════════════════════════════════════════════

get_session_id() {
    cat "$SESSION_FILE" 2>/dev/null || echo ""
}

save_session_id() {
    local new_id="$1"
    if [[ -n "$new_id" ]]; then
        echo "$new_id" > "$SESSION_FILE"
        log "Session ID saved: ${new_id:0:12}..."
    fi
}

clear_session() {
    rm -f "$SESSION_FILE"
    log "Session cleared"
}

# ═══════════════════════════════════════════════════════════════════
#  CLAUDE INTERACTION
# ═══════════════════════════════════════════════════════════════════

run_claude() {
    local prompt="$1"
    local tmpfile=$(mktemp)
    trap "rm -f '$tmpfile'" RETURN

    local session_id=$(get_session_id)
    local resume_flag=""

    if [[ -n "$session_id" ]]; then
        resume_flag="--resume $session_id"
        log "Resuming session: ${session_id:0:12}..."
    else
        log "Starting new session"
    fi

    # Run claude, stream text output, capture full response
    claude \
        $resume_flag \
        --print \
        --output-format stream-json \
        --dangerously-skip-permissions \
        "$prompt" \
    | tee "$tmpfile" \
    | jq --unbuffered -rj "$STREAM_TEXT"

    # Extract and save new session ID
    local new_session=$(jq -r "$EXTRACT_SESSION" "$tmpfile" | tail -1)
    save_session_id "$new_session"

    echo ""  # newline after streamed output
}

run_claude_fresh() {
    # Force a new session (clear existing)
    clear_session
    run_claude "$1"
}

# ═══════════════════════════════════════════════════════════════════
#  MAIN LOOP
# ═══════════════════════════════════════════════════════════════════

cd "$PROJECT_DIR"
check_requirements

log "Starting ralph_a (session-persistent mode)"
log "Project: $PROJECT_DIR"
log "Max iterations: $MAX_ITERATIONS"

for ((i=1; i<=MAX_ITERATIONS; i++)); do
    echo ""
    echo "==============================================================="
    echo "  ITERATION $i"
    echo "==============================================================="

    # ─────────────────────────────────────────────────────────────────
    # (a) PLAN - Claude creates plan, session is preserved
    # ─────────────────────────────────────────────────────────────────
    log "[PLAN] Analyzing spec and creating plan..."

    run_claude "Read @SPEC.md and @testing.md and @VISION.md.

Identify the next 3-5 uncompleted features (marked [ ]).
Create a detailed implementation plan for these features.
Consider the testing regime - all changes must be testable.

Output your plan clearly, then wait for my approval before executing."

    # ─────────────────────────────────────────────────────────────────
    # (b) APPROVE - User reviews plan
    # ─────────────────────────────────────────────────────────────────
    echo ""
    log "[APPROVE] Plan review required"
    read -p "Accept plan? [Y/n/q] " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Qq]$ ]]; then
        log "Exiting at user request"
        exit 0
    elif [[ $REPLY =~ ^[Nn]$ ]]; then
        log "Plan rejected, starting fresh iteration..."
        clear_session
        continue
    fi

    # ─────────────────────────────────────────────────────────────────
    # (c) EXECUTE - Claude implements (remembers the plan!)
    # ─────────────────────────────────────────────────────────────────
    log "[EXECUTE] Implementing plan..."

    run_claude "Execute the plan you just created.

For each feature:
1. Implement the code changes
2. Add or update tests per @testing.md
3. Run tests to verify
4. Mark completed items in SPEC.md as [x]
5. Git commit with descriptive message
6. Git push

Report progress as you go."

    # ─────────────────────────────────────────────────────────────────
    # (d) CHECK - Are we done?
    # ─────────────────────────────────────────────────────────────────
    log "[CHECK] Verifying completion status..."

    if check_spec_complete; then
        echo ""
        echo "==============================================================="
        echo "  SPEC COMPLETE after $i iterations!"
        echo "==============================================================="

        run_claude "All SPEC.md items are complete.
Review @VISION.md - does the current codebase embody the vision?
Summarize what was built and identify any gaps."

        log "Done! Run interview phase for next spec."
        exit 0
    fi

    # ─────────────────────────────────────────────────────────────────
    # (e) RESET - Clear context for next iteration
    # ─────────────────────────────────────────────────────────────────
    log "[RESET] Clearing session for next iteration"
    clear_session
    sleep 2
done

log "WARNING: Hit max iterations ($MAX_ITERATIONS) without completing SPEC"
exit 1
