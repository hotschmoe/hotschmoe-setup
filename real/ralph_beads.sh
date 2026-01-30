#!/bin/bash
# hot_ralph - Beads-integrated development loop
# Requires: .beads directory with ready tasks already created
# Uses beads (br) for atomic task tracking
set -e

PROJECT_DIR="${1:-.}"

# jq filter for streaming JSON output
JQ_STREAM='select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text // empty'

# ═══════════════════════════════════════════════════════════════════
#  UTILITIES
# ═══════════════════════════════════════════════════════════════════

log() {
    echo "[$(date '+%H:%M:%S')] $*"
}

require_file() {
    if [[ ! -f "$PROJECT_DIR/$1" ]]; then
        echo "ERROR: Missing $1"
        exit 1
    fi
}

require_command() {
    local cmd="$1"
    local msg="$2"
    if ! command -v "$cmd" &> /dev/null; then
        echo "ERROR: $cmd is required but not installed"
        [[ -n "$msg" ]] && echo "$msg"
        exit 1
    fi
}

check_requirements() {
    require_file SPEC.md
    require_file VISION.md
    require_file TESTING.md

    require_command jq
    require_command claude
    require_command br "Install from: https://github.com/Dicklesworthstone/beads_rust"

    if [[ ! -d "$PROJECT_DIR/.beads" ]]; then
        echo "ERROR: .beads directory not found"
        echo "Initialize beads and create tasks before running hot_ralph:"
        echo "  br init"
        echo "  br create \"Task title\" --type task --description \"...\""
        exit 1
    fi
}

run_claude() {
    local prompt="$1"
    claude \
        --print \
        --output-format stream-json \
        --dangerously-skip-permissions \
        "$prompt" \
    | jq --unbuffered -rj "$JQ_STREAM"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════
#  BEADS INTEGRATION
# ═══════════════════════════════════════════════════════════════════

beads_ready_count() {
    br ready --json 2>/dev/null | jq 'length' 2>/dev/null || echo "0"
}

beads_get_next() {
    # Returns JSON of next ready task (highest priority, oldest first)
    br ready --json 2>/dev/null | jq 'sort_by(.priority, .created_at) | .[0] // empty' 2>/dev/null
}

beads_claim() {
    local id="$1"
    br update "$id" --status in_progress --json >/dev/null 2>&1
    log "Claimed task: $id"
}

beads_complete() {
    local id="$1"
    local reason="${2:-Completed}"
    br close "$id" --reason "$reason" --json >/dev/null 2>&1
    log "Completed task: $id"
}

beads_sync() {
    br sync >/dev/null 2>&1
    log "Beads synced"
}

commit_beads() {
    local msg="$1"
    beads_sync
    if ! git diff --quiet .beads/ 2>/dev/null; then
        git add .beads/
        git commit -m "$msg" --no-verify 2>/dev/null || true
    fi
}

# ═══════════════════════════════════════════════════════════════════
#  MAIN LOOP
# ═══════════════════════════════════════════════════════════════════

cd "$PROJECT_DIR"
check_requirements

# Verify there are ready tasks
ready_count=$(beads_ready_count)
if [[ "$ready_count" -eq 0 ]]; then
    echo "ERROR: No ready tasks in beads"
    echo "Create tasks before running hot_ralph:"
    echo "  br create \"Task title\" --type task --description \"...\""
    exit 1
fi

log "Starting hot_ralph (beads mode)"
log "Project: $PROJECT_DIR"

while true; do
    # Get next ready task
    task_json=$(beads_get_next)

    if [[ -z "$task_json" || "$task_json" == "null" ]]; then
        echo ""
        echo "==============================================================="
        echo "  ALL TASKS COMPLETE!"
        echo "==============================================================="

        commit_beads "beads: final sync"
        git push 2>/dev/null || true

        run_claude "All beads tasks are complete.
Review @VISION.md - does the codebase embody the vision?
Summarize what was built and identify any remaining gaps."

        exit 0
    fi

    # Extract task details
    task_id=$(echo "$task_json" | jq -r '.id')
    task_title=$(echo "$task_json" | jq -r '.title')
    task_desc=$(echo "$task_json" | jq -r '.description // "No description"')
    task_priority=$(echo "$task_json" | jq -r '.priority')
    task_tags=$(echo "$task_json" | jq -r '.tags // [] | join(", ")')

    ready_count=$(beads_ready_count)

    echo ""
    echo "---------------------------------------------------------------"
    echo "  TASK: $task_title"
    echo "  ID: $task_id | Priority: $task_priority | Ready: $ready_count"
    if [[ -n "$task_tags" ]]; then
        echo "  Tags: $task_tags"
    fi
    echo "---------------------------------------------------------------"
    echo "$task_desc"
    echo "---------------------------------------------------------------"

    read -p "Execute? [Y/n/s(kip)/v(iew all)/q] " -n 1 -r
    echo ""

    case "$REPLY" in
        [Qq])
            log "Exiting - syncing beads..."
            beads_sync
            exit 0
            ;;
        [Ss])
            log "Skipping task (marking complete without execution)"
            beads_complete "$task_id" "Skipped by user"
            continue
            ;;
        [Vv])
            log "Ready tasks:"
            br ready
            continue
            ;;
        [Nn])
            log "Skipping task (remains in queue)"
            continue
            ;;
    esac

    # Claim the task
    beads_claim "$task_id"

    # Execute the task
    log "Executing task..."

    run_claude "You are implementing a single atomic task.

## Task
**$task_title**

$task_desc

## Context Files
- @SPEC.md - Project specification
- @VISION.md - Project vision
- @TESTING.md - Testing requirements

## Instructions
1. Implement ONLY what this task specifies - no more, no less
2. Run any validation criteria specified in the description
3. If validation passes, commit with message based on task title
4. Report success or failure clearly

This is an ATOMIC task. Stay focused."

    echo ""
    read -p "Task successful? [Y/n/r(etry)] " -n 1 -r
    echo ""

    case "$REPLY" in
        [Nn])
            log "Task not complete - keeping in progress"
            # Leave as in_progress for manual handling
            ;;
        [Rr])
            log "Retrying task..."
            br update "$task_id" --status open --json >/dev/null 2>&1
            continue
            ;;
        *)
            beads_complete "$task_id" "Completed successfully"
            commit_beads "beads: complete $task_id"
            ;;
    esac

    # Periodic push
    if (( RANDOM % 5 == 0 )); then
        log "Pushing to remote..."
        git push 2>/dev/null || log "Push failed (will retry later)"
    fi
done
