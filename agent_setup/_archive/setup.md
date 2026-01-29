# Agent Setup Guide

Instructions for setting up AI coding agents and their supporting tools.

---

## Beads Installation (Windows)

### 1. Install Beads CLI

```powershell
irm https://raw.githubusercontent.com/steveyegge/beads/main/install.ps1 | iex
```

### 2. Install Beads Viewer

```powershell
go install github.com/Dicklesworthstone/beads_viewer/cmd/bv@latest
```

> **Important**: Ensure your Go bin directory is in your PATH.
> ```powershell
> # Quick set for current session:
> $env:PATH += ";$env:USERPROFILE\go\bin"
>
> # Permanent (User PATH):
> [System.Environment]::SetEnvironmentVariable("Path", $env:Path + ";$env:USERPROFILE\go\bin", "User")
> ```

### 3. Install Additional Grep tools (TODO: add this to setup scripts)

```powershell
winget install ripgrep ast-grep
```

### 4. Install LLVM

```powershell
winget install LLVM.LLVM
```

## Installation (Linux)

### Install LLVM

```bash
sudo apt-get install llvm
```

---

## Complete Beads Workflow

### Step 1: Initialize Project

```powershell
cd your-project
bd init              # Creates .beads/ directory with database
bd setup claude      # Installs Claude Code hooks (auto-injects context)
```

Verify setup:
```powershell
bd doctor            # Diagnose and fix issues (run daily)
bd version           # Confirm installation
```

### Step 2: Create Initial Beads

After `bd init`, you need beads for `bv` to display. Two approaches:

#### Option A: Manual Creation (Quick Start)

```powershell
# Create a single bead to test
bd create "Initial project setup" -t task -p 1 --description="First bead to verify workflow"

# Create beads with dependencies
bd create "Build authentication system" -t feature -p 1 --description="User login/logout"
bd create "Write auth tests" -t task -p 2 --deps "blocks:bd-xxxx" --description="Unit tests for auth"
```

**Bead Types**: `feature`, `bug`, `task`, `chore`, `epic`
**Priority**: 1 (highest) to 5 (lowest)

#### Option B: Agent-Driven Creation (Recommended)

Have Claude analyze your project and create beads:

```
You: "Review this codebase and create beads for:
     - Outstanding TODOs in the code
     - Missing tests
     - Potential improvements
     - Any bugs you identify"
```

Claude will run `bd create` commands to populate your bead graph. Example agent output:
```powershell
bd create "Add input validation to user form" -t bug -p 2 --description="Found in src/forms.py:42 - no sanitization"
bd create "Implement caching layer" -t feature -p 3 --description="Database queries are repeated; add Redis cache"
```

### Step 3: View and Triage Beads

Once beads exist, use `bv` for visualization and triage:

```powershell
bv                      # Interactive TUI (for humans)
bv --robot-triage       # JSON mega-command for agents (start here)
bv --robot-next         # Just the single top priority pick
bv --robot-plan         # Parallel execution tracks
bv --robot-insights     # Full metrics: PageRank, critical path, cycles
```

> **Warning**: Never use bare `bv` in agent context - it launches interactive TUI and blocks the session. Always use `--robot-*` flags for agents.

**TUI shortcuts (human use):**
- `?` - Help
- `j/k` - Navigate up/down
- `Enter` - View bead details
- `g` - Graph visualization
- `q` - Quit

### Step 4: Agent Work Loop

This is how agents interact with beads during a session:

```
+------------------+     +------------------+     +------------------+
|  1. Find Work    |---->|  2. Claim Task   |---->|  3. Do Work      |
|  bd ready --json |     |  bd update <id>  |     |  (implement)     |
|  bv --robot-next |     |  --status        |     |                  |
+------------------+     |  in_progress     |     +--------+---------+
                         +------------------+              |
                                                           v
+------------------+     +------------------+     +------------------+
|  6. Sync         |<----|  5. Close Task   |<----|  4. Discover     |
|  bd sync         |     |  bd close <id>   |     |  New Issues      |
|  (commit/push)   |     |  --reason "Done" |     |  bd create ...   |
+------------------+     +------------------+     +------------------+
```

**Agent Commands Reference:**

| Action | Command |
|--------|---------|
| Find ready work | `bd ready --json` |
| Claim a task | `bd update <id> --status in_progress --json` |
| Create discovered issue | `bd create "title" --description="context" -t bug -p 2 --deps discovered-from:<parent-id> --json` |
| Close completed work | `bd close <id> --reason "Done" --json` |
| Sync at session end | `bd sync` |
| Show specific bead | `bd show <id> --json` |
| List filtered beads | `bd list --status open --priority 1 --json` |

### Step 5: Daily Maintenance

```powershell
bd doctor              # Run daily - diagnoses issues, handles migrations
bd stale --days 30     # Find forgotten beads
bv --robot-alerts      # Check for blocking cascades, priority mismatches
```

---

## Optional: Claude Code Plugin

```bash
# In Claude Code
/plugin marketplace add steveyegge/beads
/plugin install beads
# Restart Claude Code
```

---

## Claude Code Subagents

Subagents are defined in `.claude/agents/` using Markdown files with YAML frontmatter.

install gemini-cli
```npm install -g @google/gemini-cli@latest```

### Directory Structure

```
.claude/
  agents/
    coder-sonnet.md
    gemini-analyzer.md
```

### File Format

Each subagent file uses this structure:

```markdown
---
name: agent-name
description: Brief description of the agent's purpose.
model: sonnet
tools:
  - Bash
  - Read
  - Write
  - Edit
---

System prompt and instructions for the agent go here.
```

### Example Files

See the example subagent definitions in `.claude/agents/`:

- **coder-sonnet.md** - Fast code implementation agent
- **gemini-analyzer.md** - Large-context analysis via Gemini CLI

---

## Quick Reference: Install to First Completed Bead

```
1. irm https://raw.githubusercontent.com/steveyegge/beads/main/install.ps1 | iex
2. go install github.com/Dicklesworthstone/beads_viewer/cmd/bv@latest
3. cd your-project
4. bd init
5. bd setup claude
6. bd create "My first task" -t task -p 1 --description="Testing the workflow"
7. bv                           # Human: see your bead in TUI
   bv --robot-triage            # Agent: get JSON triage data
8. bd update bd-xxxx --status in_progress
9. (do the work)
10. bd close bd-xxxx --reason "Completed successfully"
11. bd sync
```

---

## Notes

- Primary Claude (Opus if selected) spawns subagents as needed
- Project-specific agents (`.claude/agents/`) take precedence over user-level agents (`~/.claude/agents/`)
- Always use `--json` flag when agents interact with beads
- Run `bd doctor` daily to maintain database health

## Sources

- [Beads GitHub Repository](https://github.com/steveyegge/beads)
- [Beads Installation Docs](https://github.com/steveyegge/beads/blob/main/docs/INSTALLING.md)
- [Beads AGENTS.md](https://github.com/steveyegge/beads/blob/main/AGENTS.md)
- [Beads Viewer](https://github.com/Dicklesworthstone/beads_viewer)
- [Introducing Beads (Steve Yegge)](https://steve-yegge.medium.com/introducing-beads-a-coding-agent-memory-system-637d7d92514a)
