#!/bin/bash
# ralph_b.sh - Task manifest development loop
# Front-loads planning into tasks.md, then executes atomically
set -e

PROJECT_DIR="${1:-.}"
TASKS_FILE="$PROJECT_DIR/tasks.md"

# jq filters for streaming JSON output
STREAM_TEXT='select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text // empty'

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

    echo ""  # newline after streamed output
}

run_claude_capture() {
    # Run claude and capture output (no streaming display)
    local prompt="$1"
    claude --print "$prompt" 2>/dev/null
}

# ═══════════════════════════════════════════════════════════════════
#  TASK MANIFEST PARSING
# ═══════════════════════════════════════════════════════════════════

get_next_task_line() {
    # Returns line number of first unchecked task, empty if none
    grep -n '^\- \[ \] \*\*T[0-9]' "$TASKS_FILE" 2>/dev/null | head -1 | cut -d: -f1
}

get_task_id() {
    local line_num=$1
    sed -n "${line_num}p" "$TASKS_FILE" | grep -oP '\*\*T[0-9]+\.[0-9]+\*\*' | tr -d '*'
}

get_task_block() {
    local line_num=$1
    # Extract from task line until next task or section header
    local end_pattern='^\- \[.\] \*\*T[0-9]|^## |^---'
    awk -v start="$line_num" '
        NR >= start {
            if (NR > start && /^- \[.\] \*\*T[0-9]|^## |^---/) exit
            print
        }
    ' "$TASKS_FILE"
}

get_current_sprint() {
    local task_line=$1
    head -n "$task_line" "$TASKS_FILE" | grep -oP '## Sprint [0-9]+:.*' | tail -1
}

mark_task_complete() {
    local line_num=$1
    # Replace [ ] with [x] on the specific line
    sed -i "${line_num}s/\- \[ \]/- [x]/" "$TASKS_FILE"
    log "Marked task complete at line $line_num"
}

count_remaining_tasks() {
    grep -c '^\- \[ \] \*\*T[0-9]' "$TASKS_FILE" 2>/dev/null || echo "0"
}

is_sprint_complete() {
    local sprint_name="$1"
    # Check if all tasks in current sprint are done
    local in_sprint=false
    while IFS= read -r line; do
        if [[ "$line" =~ ^##\ Sprint ]]; then
            if [[ "$line" == *"$sprint_name"* ]]; then
                in_sprint=true
            elif $in_sprint; then
                break  # Moved to next sprint
            fi
        elif $in_sprint && [[ "$line" =~ ^\-\ \[\ \]\ \*\*T ]]; then
            return 1  # Found unchecked task
        fi
    done < "$TASKS_FILE"
    return 0  # All tasks in sprint are checked
}

# ═══════════════════════════════════════════════════════════════════
#  BOOTSTRAP - Generate tasks.md
# ═══════════════════════════════════════════════════════════════════

bootstrap_tasks() {
    if [[ -f "$TASKS_FILE" ]]; then
        log "tasks.md exists ($(count_remaining_tasks) tasks remaining)"
        return
    fi

    log "Bootstrapping: Generating task manifest..."

    # Phase 1: Initial generation
    run_claude_capture "Read @SPEC.md @VISION.md @testing.md carefully.

Break this project into sprints and tasks following these rules:

## Sprints
- Each sprint produces a demoable, runnable piece of software
- Sprints build on each other incrementally
- Sprint goal should be achievable in 5-10 atomic tasks
- Include a concrete demo/validation command for the sprint

## Tasks
- Every task is atomic - one commit, one focused change
- Every task has explicit validation criteria (test command, expected output)
- Tasks within a sprint should be ordered by dependency
- No task depends on uncommitted work from another task
- Include file paths and function names where relevant
- Task IDs follow pattern T{sprint}.{sequence} (T1.1, T1.2, T2.1, etc.)

## Format (use exactly):

\`\`\`markdown
# Project Tasks

Generated from: SPEC.md, VISION.md
Generated at: $(date -Iseconds)

## Sprint 1: [Sprint Name]

**Goal**: [What this sprint delivers]
**Demo**: \`[command to verify sprint works]\`

### Tasks

- [ ] **T1.1**: [Task title]
  - [Implementation details]
  - [More details if needed]
  - **Validation**: \`[command]\` [expected result]

- [ ] **T1.2**: [Task title]
  - [Implementation details]
  - **Validation**: \`[command]\` [expected result]

---

## Sprint 2: [Sprint Name]
...
\`\`\`

Be exhaustive. Be technical. Small atomic tasks that compose into sprint goals.
Output ONLY the markdown content, no preamble." > "$TASKS_FILE.draft"

    log "Initial draft generated, running review..."

    # Phase 2: Subagent review
    run_claude_capture "Review @tasks.md.draft for quality issues:

1. Tasks too large (should be split into smaller atoms)
2. Missing or vague validation criteria
3. Unclear implementation descriptions
4. Dependency problems (task needs something not yet done)
5. Sprint goals not achievable with listed tasks

Output a REVISED tasks.md with improvements applied.
Output ONLY the markdown content, no commentary." > "$TASKS_FILE"

    rm -f "$TASKS_FILE.draft"

    local task_count=$(count_remaining_tasks)
    log "Task manifest generated: $task_count tasks"

    # Show summary
    echo ""
    echo "=== TASK MANIFEST SUMMARY ==="
    grep -E '^## Sprint|^\*\*Goal\*\*' "$TASKS_FILE" | head -20
    echo ""
}

# ═══════════════════════════════════════════════════════════════════
#  MAIN LOOP
# ═══════════════════════════════════════════════════════════════════

cd "$PROJECT_DIR"
check_requirements
bootstrap_tasks

log "Starting ralph_b (task manifest mode)"
log "Project: $PROJECT_DIR"

last_sprint=""

while true; do
    task_line=$(get_next_task_line)

    if [[ -z "$task_line" ]]; then
        echo ""
        echo "==============================================================="
        echo "  ALL TASKS COMPLETE!"
        echo "==============================================================="

        run_claude "All tasks in @tasks.md are complete.
Review @VISION.md - does the codebase embody the vision?
Summarize what was built and identify any remaining gaps."

        exit 0
    fi

    task_id=$(get_task_id "$task_line")
    task_block=$(get_task_block "$task_line")
    current_sprint=$(get_current_sprint "$task_line")
    remaining=$(count_remaining_tasks)

    # Sprint transition announcement
    if [[ "$current_sprint" != "$last_sprint" ]]; then
        echo ""
        echo "==============================================================="
        echo "  $current_sprint"
        echo "==============================================================="
        last_sprint="$current_sprint"
    fi

    echo ""
    echo "---------------------------------------------------------------"
    echo "  Task $task_id ($remaining remaining)"
    echo "---------------------------------------------------------------"
    echo "$task_block"
    echo "---------------------------------------------------------------"

    read -p "Execute? [Y/n/s(kip)/e(dit)/q] " -n 1 -r
    echo ""

    case "$REPLY" in
        [Qq])
            log "Exiting at user request"
            exit 0
            ;;
        [Ss])
            log "Skipping task $task_id"
            mark_task_complete "$task_line"
            continue
            ;;
        [Ee])
            log "Opening tasks.md for editing..."
            ${EDITOR:-vim} "$TASKS_FILE"
            continue
            ;;
        [Nn])
            log "Skipping without marking complete"
            continue
            ;;
    esac

    # Execute the task
    log "Executing task $task_id..."

    run_claude "You are implementing a single atomic task.

## Current Task
$task_block

## Context Files
- @SPEC.md - Project specification
- @VISION.md - Project vision
- @testing.md - Testing requirements

## Instructions
1. Implement ONLY what this task specifies - no more, no less
2. Run the validation criteria specified in the task
3. If validation passes, commit with message: \"$task_id: [description]\"
4. Report success or failure clearly

This is an ATOMIC task. Stay focused."

    echo ""
    read -p "Task $task_id successful? Mark complete? [Y/n] " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        mark_task_complete "$task_line"

        # Commit tasks.md update with the task
        if git diff --quiet "$TASKS_FILE" 2>/dev/null; then
            log "tasks.md unchanged"
        else
            git add "$TASKS_FILE"
            git commit -m "tasks: mark $task_id complete" --no-verify 2>/dev/null || true
        fi

        # Check for sprint completion
        sprint_name=$(echo "$current_sprint" | grep -oP 'Sprint [0-9]+' || echo "")
        if [[ -n "$sprint_name" ]] && is_sprint_complete "$sprint_name"; then
            echo ""
            echo "==============================================================="
            echo "  SPRINT COMPLETE: $current_sprint"
            echo "==============================================================="

            run_claude "Sprint '$current_sprint' is complete!

Run the sprint demo/validation from @tasks.md.
Report results and any issues found.
Confirm ready to proceed to next sprint."

            read -p "Continue to next sprint? [Y/n] " -n 1 -r
            echo ""
            [[ $REPLY =~ ^[Nn]$ ]] && exit 0
        fi
    else
        log "Task $task_id not marked complete - will retry next iteration"
    fi
done
