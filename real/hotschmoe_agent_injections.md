# CLAUDE.md - Laminae

## RULE 1 – ABSOLUTE (DO NOT EVER VIOLATE THIS)

You may NOT delete any file or directory unless I explicitly give the exact command **in this session**.

- This includes files you just created (tests, tmp files, scripts, etc.).
- You do not get to decide that something is "safe" to remove.
- If you think something should be removed, stop and ask. You must receive clear written approval **before** any deletion command is even proposed.

Treat "never delete files without permission" as a hard invariant.

---

### IRREVERSIBLE GIT & FILESYSTEM ACTIONS

Absolutely forbidden unless I give the **exact command and explicit approval** in the same message:

- `git reset --hard`
- `git clean -fd`
- `rm -rf`
- Any command that can delete or overwrite code/data

Rules:

1. If you are not 100% sure what a command will delete, do not propose or run it. Ask first.
2. Prefer safe tools: `git status`, `git diff`, `git stash`, copying to backups, etc.
3. After approval, restate the command verbatim, list what it will affect, and wait for confirmation.
4. When a destructive command is run, record in your response:
   - The exact user text authorizing it
   - The command run
   - When you ran it

If that audit trail is missing, then you must act as if the operation never happened.

### Version Updates (SemVer)

When making commits, update the `version`

- **MAJOR** (X.0.0): Breaking changes or incompatible API modifications
- **MINOR** (0.X.0): New features, backward-compatible additions
- **PATCH** (0.0.X): Bug fixes, small improvements, documentation

---

### Code Editing Discipline

- Do **not** run scripts that bulk-modify code (codemods, invented one-off scripts, giant `sed`/regex refactors).
- Large mechanical changes: break into smaller, explicit edits and review diffs.
- Subtle/complex changes: edit by hand, file-by-file, with careful reasoning.
- **NO EMOJIS** - do not use emojis or non-textual characters.
- ASCII diagrams are encouraged for visualizing flows.
- Keep in-line comments to a minimum. Use external documentation for complex logic.
- In-line commentary should be value-add, concise, and focused on info not easily gleaned from the code.

---

### No Legacy Code - Full Migrations Only

We optimize for clean architecture, not backwards compatibility. **When we refactor, we fully migrate.**

- No "compat shims", "v2" file clones, or deprecation wrappers
- When changing behavior, migrate ALL callers and remove old code **in the same commit**
- No `_legacy` suffixes, no `_old` prefixes, no "will remove later" comments
- New files are only for genuinely new domains that don't fit existing modules
- The bar for adding files is very high

**Rationale**: Legacy compatibility code creates technical debt that compounds. A clean break is always better than a gradual migration that never completes.

---

## Development Philosophy

**Make it work, make it right, make it fast** - in that order.

**This codebase will outlive you** - every shortcut becomes someone else's burden. Patterns you establish will be copied. Corners you cut will be cut again.

**Fight entropy** - leave the codebase better than you found it.

**Inspiration vs. Recreation** - take the opportunity to explore unconventional or new ways to accomplish tasks. Do not be afraid to challenge assumptions or propose new ideas. BUT we also do not want to reinvent the wheel for the sake of it. If there is a well-established pattern or library take inspiration from it and make it your own. (or suggest it for inclusion in the codebase)

---

## Testing Philosophy: Diagnostics, Not Verdicts

**Tests are diagnostic tools, not success criteria.** A passing test suite does not mean the code is good. A failing test does not mean the code is wrong.

**When a test fails, ask three questions in order:**
1. Is the test itself correct and valuable?
2. Does the test align with our current design vision?
3. Is the code actually broken?

Only if all three answers are "yes" should you fix the code.

**Why this matters:**
- Tests encode assumptions. Assumptions can be wrong or outdated.
- Changing code to pass a bad test makes the codebase worse, not better.
- Evolving projects explore new territory - legacy testing assumptions don't always apply.

**What tests ARE good for:**
- **Regression detection**: Did a refactor break dependent modules? Did API changes break integrations?
- **Sanity checks**: Does initialization complete? Do core operations succeed? Does the happy path work?
- **Behavior documentation**: Tests show what the code currently does, not necessarily what it should do.

**What tests are NOT:**
- A definition of correctness
- A measure of code quality
- Something to "make pass" at all costs
- A specification to code against

**The real success metric**: Does the code further our project's vision and goals?
---

### Post-Session Code Cleanup

After long or complex sessions, consider running the code-simplifier agent to clean up recently modified code:

```
Task(code-simplifier) - Simplifies and refines code for clarity, consistency, and maintainability
```

This agent focuses on recently modified files and helps reduce complexity that can accumulate during extended development sessions while preserving all functionality.

---

## Claude Agents

Specialized agents are available in `.claude/agents/`. Agents use YAML frontmatter format:

```yaml
---
name: agent-name
description: What this agent does
model: sonnet|haiku|opus
tools:
  - Bash
  - Read
  - Edit
---
```

### Available Agents

| Agent | Model | Purpose |
|-------|-------|---------|
| coder-sonnet | sonnet | Fast, precise code changes with atomic commits |
| gemini-analyzer | sonnet | Large-context analysis via Gemini CLI (1M+ context) |

(extend agents as created)

---

## Claude Skills

Skills are invoked via `/skill-name`. Available in `.claude/skills/`.

### Skill File Structure

Skills are directories containing a `SKILL.md` file with YAML frontmatter:

```
.claude/skills/my-skill/
  SKILL.md           # Main instructions (required)
  template.md        # Template for output (optional)
  examples/          # Example outputs (optional)
  scripts/           # Helper scripts (optional)
```

### Skill Locations

| Location | Scope |
|----------|-------|
| `~/.claude/skills/<skill-name>/SKILL.md` | User-global (all projects) |
| `.claude/skills/<skill-name>/SKILL.md` | Project-specific (version controlled) |
| `<plugin>/skills/<skill-name>/SKILL.md` | Plugin-provided |

### Frontmatter Reference

```yaml
---
name: my-skill
description: What this skill does
argument-hint: "[filename] [format]"
disable-model-invocation: true
user-invocable: true
allowed-tools: Read, Grep, Bash(gh *)
model: sonnet
context: fork
agent: Explore
hooks:
  # See hooks documentation
---
Your skill instructions here...
```

| Field | Description |
|-------|-------------|
| `name` | Skill name (determines `/slash-command`) |
| `description` | When Claude should invoke this skill |
| `argument-hint` | Placeholder text shown in autocomplete (e.g., `[issue-number]`) |
| `disable-model-invocation` | `true` = only user can invoke via `/name` |
| `user-invocable` | `false` = only Claude can invoke (background knowledge) |
| `allowed-tools` | Restrict which tools the skill can use |
| `model` | Override model for this skill |
| `context: fork` | Run skill in isolated subagent context |
| `agent` | Execute with specified agent (`Explore`, `Plan`, or custom) |
| `hooks` | Lifecycle hooks (see Hooks docs) |

### Argument Substitution

| Syntax | Description |
|--------|-------------|
| `$ARGUMENTS` | All arguments passed to skill |
| `$ARGUMENTS[N]` or `$N` | Nth argument (0-indexed) |
| `${CLAUDE_SESSION_ID}` | Current session identifier |

### Dynamic Context Injection

Prefix commands with `!` to inject their output before Claude sees the prompt:

```yaml
---
name: pr-summary
description: Summarize changes in a pull request
context: fork
agent: Explore
---
## Pull request context
- PR diff: !`gh pr diff`
- Changed files: !`gh pr diff --name-only`

## Your task
Summarize this pull request...
```

### Subagent Execution

Use `context: fork` to run skills in an isolated subagent:

```yaml
---
name: deep-research
description: Research a topic thoroughly
context: fork
agent: Explore
---
Research $ARGUMENTS thoroughly...
```

Built-in agents: `Explore` (read-only research), `Plan` (planning mode), or define custom agents in `.claude/agents/`.

### Project Skills

| Skill | Purpose |
|-------|---------|
| `/test` | Run test_all.zig with smart variant selection |
| `/verify` | Build all variants and check for regressions |
| `/symbolize <addr>` | Resolve kernel address to function name |
| `/syscall` | Guided syscall addition workflow |
| `/stack-check` | Analyze kernel stack usage patterns |

### Skill Discovery

Skills in `.claude/skills/` are automatically discovered without restart. Edit or add skills and they become immediately available. Nested directories (e.g., `packages/frontend/.claude/skills/`) are also discovered.

---

# PROJECT-LANGUAGE-SPECIFIC SECTION

> **Template Section**: Replace this entire section with language-specific guidance when copying to a new project. Delete this notice after customizing.

This section documents **language-level patterns, idioms, and gotchas** that apply project-wide. It should be customized for each project's primary language(s).

---

## What to Include Here

### 1. Language Version & Toolchain

Document the exact version and core toolchain commands:

```
- Language version (e.g., "Python 3.12", "Zig 0.15.2", "Rust 1.75")
- Build command (e.g., `npm run build`, `cargo build`, `zig build`)
- Format command (e.g., `black .`, `rustfmt`, `zig fmt`)
- Lint command if separate from build
- Package manager or "no dependencies" policy
```

---

we love you, Claude! do your best today