#!/bin/bash
# ralph_c.sh - Beads-integrated development loop
# Uses beads (br) for atomic task tracking instead of tasks.md
set -e

PROJECT_DIR="${1:-.}"

# jq filters for streaming JSON output
STREAM_TEXT='select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text // empty'

# ═══════════════════════════════════════════════════════════════════
#  UTILITIES
# ═══════════════════════════════════════════════════════════════════

log() {
    echo "[$(date '+%H:%M:%S')] $*"
}

check_requirements() {
    for file in SPEC.md VISION.md TESTING.md; do
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

    if ! command -v br &> /dev/null; then
        echo "ERROR: beads (br) is required but not installed"
        echo "Install from: https://github.com/Dicklesworthstone/beads_rust"
        exit 1
    fi
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

    echo ""
}

run_claude_capture() {
    local prompt="$1"
    claude --print "$prompt" 2>/dev/null
}

# ═══════════════════════════════════════════════════════════════════
#  BEADS INTEGRATION
# ═══════════════════════════════════════════════════════════════════

beads_init() {
    if [[ ! -d "$PROJECT_DIR/.beads" ]]; then
        log "Initializing beads..."
        br init
    fi
}

beads_ready_count() {
    br ready --json 2>/dev/null | jq -s 'length' 2>/dev/null || echo "0"
}

beads_get_next() {
    # Returns JSON of next ready task (highest priority, oldest first)
    br ready --json 2>/dev/null | jq -s 'sort_by(.priority, .created_at) | .[0] // empty' 2>/dev/null
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

beads_create_task() {
    local title="$1"
    local description="$2"
    local priority="${3:-2}"
    local sprint="${4:-}"

    local sprint_flag=""
    if [[ -n "$sprint" ]]; then
        sprint_flag="--tags sprint:$sprint"
    fi

    br create "$title" \
        --type task \
        --priority "$priority" \
        --description "$description" \
        $sprint_flag \
        --json 2>/dev/null | jq -r '.id // empty'
}

beads_sync() {
    br sync >/dev/null 2>&1
    log "Beads synced"
}

beads_has_tasks() {
    local count=$(br list --json 2>/dev/null | jq -s 'length' 2>/dev/null || echo "0")
    [[ "$count" -gt 0 ]]
}

# ═══════════════════════════════════════════════════════════════════
#  BOOTSTRAP - Generate tasks from SPEC and create beads
# ═══════════════════════════════════════════════════════════════════

bootstrap_beads() {
    beads_init

    if beads_has_tasks; then
        local ready_count=$(beads_ready_count)
        log "Beads already has tasks ($ready_count ready)"
        return
    fi

    log "Bootstrapping: Generating tasks from spec..."

    # Generate structured task list
    local tasks_json=$(run_claude_capture "Read @SPEC.md @VISION.md @TESTING.md carefully.

Break this project into atomic tasks. Output as JSON array:

\`\`\`json
{
  \"sprints\": [
    {
      \"number\": 1,
      \"name\": \"Sprint Name\",
      \"goal\": \"What this sprint delivers\",
      \"demo\": \"command to verify sprint works\",
      \"tasks\": [
        {
          \"id\": \"T1.1\",
          \"title\": \"Short task title\",
          \"description\": \"Detailed implementation steps and validation criteria\",
          \"priority\": 2
        }
      ]
    }
  ]
}
\`\`\`

Rules:
- Each task is atomic (one commit, one focused change)
- Each task has clear validation criteria in description
- Priority: 0=critical, 1=high, 2=normal, 3=low
- Order tasks within sprint by dependency
- Be exhaustive and technical

Output ONLY valid JSON, no markdown fences or commentary.")

    # Clean up potential markdown fences
    tasks_json=$(echo "$tasks_json" | sed 's/^```json//; s/^```//' | tr -d '\r')

    # Validate JSON
    if ! echo "$tasks_json" | jq empty 2>/dev/null; then
        log "ERROR: Invalid JSON from task generation"
        echo "$tasks_json" > "$PROJECT_DIR/.ralph-debug-tasks.json"
        log "Debug output saved to .ralph-debug-tasks.json"
        exit 1
    fi

    # Create beads from JSON
    log "Creating beads from generated tasks..."

    local sprint_count=$(echo "$tasks_json" | jq '.sprints | length')
    local task_count=0

    for ((s=0; s<sprint_count; s++)); do
        local sprint_num=$(echo "$tasks_json" | jq -r ".sprints[$s].number")
        local sprint_name=$(echo "$tasks_json" | jq -r ".sprints[$s].name")

        log "Sprint $sprint_num: $sprint_name"

        local sprint_tasks=$(echo "$tasks_json" | jq ".sprints[$s].tasks | length")

        for ((t=0; t<sprint_tasks; t++)); do
            local task_id=$(echo "$tasks_json" | jq -r ".sprints[$s].tasks[$t].id")
            local title=$(echo "$tasks_json" | jq -r ".sprints[$s].tasks[$t].title")
            local desc=$(echo "$tasks_json" | jq -r ".sprints[$s].tasks[$t].description")
            local priority=$(echo "$tasks_json" | jq -r ".sprints[$s].tasks[$t].priority")

            # Prepend task ID to title for tracking
            local full_title="[$task_id] $title"

            local bead_id=$(beads_create_task "$full_title" "$desc" "$priority" "$sprint_num")

            if [[ -n "$bead_id" ]]; then
                log "  Created: $task_id -> $bead_id"
                ((task_count++))
            else
                log "  FAILED: $task_id"
            fi
        done
    done

    beads_sync
    log "Bootstrap complete: $task_count tasks created"

    # Show summary
    echo ""
    echo "=== TASK SUMMARY ==="
    br list --json | jq -r '.[] | "[\(.priority)] \(.title)"' | head -20
    echo ""
}

# ═══════════════════════════════════════════════════════════════════
#  MAIN LOOP
# ═══════════════════════════════════════════════════════════════════

cd "$PROJECT_DIR"
check_requirements
bootstrap_beads

log "Starting ralph_c (beads mode)"
log "Project: $PROJECT_DIR"

while true; do
    # Get next ready task
    task_json=$(beads_get_next)

    if [[ -z "$task_json" || "$task_json" == "null" ]]; then
        echo ""
        echo "==============================================================="
        echo "  ALL TASKS COMPLETE!"
        echo "==============================================================="

        beads_sync
        git add .beads/ && git commit -m "beads: final sync" --no-verify 2>/dev/null || true
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

            # Sync and commit beads state
            beads_sync
            if ! git diff --quiet .beads/ 2>/dev/null; then
                git add .beads/
                git commit -m "beads: complete $task_id" --no-verify 2>/dev/null || true
            fi
            ;;
    esac

    # Periodic push
    if (( RANDOM % 5 == 0 )); then
        log "Pushing to remote..."
        git push 2>/dev/null || log "Push failed (will retry later)"
    fi
done
