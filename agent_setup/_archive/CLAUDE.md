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

When making commits, update the `version` in `build.zig.zon` following [Semantic Versioning](https://semver.org/):

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

## Philosophy

This codebase will outlive you. Every shortcut becomes someone else's burden. Patterns you establish will be copied. Corners you cut will be cut again.

Fight entropy. Leave the codebase better than you found it.

---

## Beads (bd) - Task Management

Beads is a git-backed graph issue tracker. Use `--json` flags for all programmatic operations.

### Session Workflow

```
1. bd prime              # Auto-injected via SessionStart hook
2. bd ready --json       # Find unblocked work
3. bd update <id> --status in_progress --json   # Claim task
4. (do the work)
5. bd close <id> --reason "Done" --json         # Complete task
6. bd sync && git push   # End session - REQUIRED
```

### Key Commands

| Action | Command |
|--------|---------|
| Find ready work | `bd ready --json` |
| Find stale work | `bd stale --days 30 --json` |
| Create issue | `bd create "Title" --description="Context" -t bug\|feature\|task -p 0-4 --json` |
| Create discovered work | `bd create "Found bug" -t bug -p 1 --deps discovered-from:<parent-id> --json` |
| Claim task | `bd update <id> --status in_progress --json` |
| Complete task | `bd close <id> --reason "Done" --json` |
| Find duplicates | `bd duplicates` |
| Merge duplicates | `bd merge <id1> <id2> --into <canonical> --json` |

### Critical Rules

- Always include `--description` when creating issues - context prevents rework
- Use `discovered-from` links to connect work found during implementation
- Run `bd sync` at session end before pushing to git
- **Work is incomplete until `git push` succeeds**
- `.beads/` is authoritative state and **must always be committed** with code changes

### Dependency Thinking

Use requirement language, not temporal language:
```bash
bd dep add rendering layout      # rendering NEEDS layout (correct)
# NOT: bd dep add phase1 phase2   (temporal - inverts direction)
```

### After bd Upgrades

```bash
bd info --whats-new              # Check workflow-impacting changes
bd hooks install                 # Update git hooks
bd daemons killall               # Restart daemons
```

### Context Preservation During Debugging

Long debugging sessions can lose context during compaction. **Commit frequently to preserve investigation state.**

```bash
# During debugging - commit investigation findings periodically
git add -A && git commit -m "WIP: investigating X, found Y"
bd create "Discovered: Z needs fixing" -t bug -p 2 --description="Found while debugging X"
bd sync

# At natural breakpoints (every 30-60 min of active debugging)
bd sync  # Capture bead state changes
git push  # Push to remote
```

**Why this matters:**
- Compaction events lose conversational context but git history persists
- Beads issues survive across sessions - use them to capture findings
- "WIP" commits are fine - squash later when the fix is complete
- A partially-documented investigation beats starting over

---

## Session Completion Checklist

```
[ ] File issues for remaining work (bd create)
[ ] Run quality gates (tests, linters)
[ ] Update issue statuses (bd update/close)
[ ] Run bd sync
[ ] Run git push and verify success
[ ] Confirm git status shows "up to date"
```

**Work is not complete until `git push` succeeds.**

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
| build-verifier | sonnet | Pre-merge validation for all 4 kernel variants |
| regression-detector | haiku | Smoke token comparison against baseline |
| dtb-analyzer | sonnet | Device tree analysis for driver development |

### Disabling Agents

To disable specific agents in `settings.json` or `--disallowedTools`:
```json
{
  "disallowedTools": ["Task(build-verifier)", "Task(gemini-analyzer)"]
}
```

---

## Claude Skills

Skills are invoked via `/skill-name`. Available in `.claude/skills/`.

### Skill Frontmatter (v2.1+)

Skills now support YAML frontmatter with advanced options:

```yaml
---
name: skill-name
description: What this skill does
# Run in forked sub-agent context (isolated from main conversation)
context: fork
# Specify which agent executes this skill
agent: coder-sonnet
---
```

| Field | Description |
|-------|-------------|
| `context: fork` | Run skill in isolated sub-agent context |
| `agent: <name>` | Execute skill using specified agent type |

### Built-in Commands

| Command | Purpose |
|---------|---------|
| `/plan` | Enter plan mode for implementation design |
| `/context` | Manage context files and imports |
| `/help` | Show available commands |

### Project Skills

| Skill | Purpose |
|-------|---------|
| `/test` | Run test_all.zig with smart variant selection |
| `/verify` | Build all variants and check for regressions |
| `/symbolize <addr>` | Resolve kernel address to function name |
| `/syscall` | Guided syscall addition workflow |
| `/stack-check` | Analyze kernel stack usage patterns |

### Skill Hot-Reload

Skills in `.claude/skills/` are automatically discovered without restart. Edit or add skills and they become immediately available.

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

### 2. Error Handling Patterns

Show the project's preferred error handling style with examples:

- How to propagate errors (try/catch, Result types, error unions)
- When to use explicit error types vs. generic errors
- Panic/assert policies - when it's acceptable vs. forbidden

### 3. Memory & Resource Management

Document allocation patterns:

- Manual vs. automatic memory management
- Resource cleanup idioms (defer, RAII, context managers)
- Ownership and borrowing conventions if applicable

### 4. Type System Conventions

- Preferred null/optional handling patterns
- Type annotation requirements
- Generic/comptime usage guidelines
- Struct/class organization preferences

### 5. Build System Details

- Build configurations/variants (debug, release, etc.)
- Build options and flags
- Multi-target or cross-compilation setup

### 6. Language-Specific Bug Severity

Categorize bugs by severity for this language:

**Critical** - Bugs that crash, corrupt data, or cause undefined behavior
- Example for Rust: "Use of `unsafe` without safety comments"
- Example for Python: "Mutable default arguments"
- Example for Zig: "`.?` on null in kernel code"

**Important** - Bugs that should be fixed before merge
- Ignoring returned errors
- Resource leaks
- Incorrect type coercions

**Contextual** - Address when convenient
- TODO comments
- Unused imports
- Suboptimal patterns

### 6. Code Examples

Provide **annotated code examples** showing correct patterns:

```
// GOOD: Shows the preferred way
code_example_showing_correct_pattern();

// BAD: Shows common mistakes to avoid
code_example_showing_antipattern();
```

Cover commonly needed patterns:
- File/resource handling
- Concurrency primitives
- External API calls
- Logging/debugging output

---

## Example: If Your Project Uses Python

```markdown
## Python Toolchain (3.12+)

- **Version**: Python 3.12.x
- **Package Manager**: uv (`uv sync` to install dependencies)
- **Format**: `ruff format .` (run before commits)
- **Lint**: `ruff check .` and `mypy .`
- **Test**: `pytest tests/`

### Error Handling

# Use explicit exception types at API boundaries
class ConfigError(Exception):
    pass

def load_config(path: Path) -> Config:
    if not path.exists():
        raise ConfigError(f"Config not found: {path}")
    return parse_config(path.read_text())

### Type Annotations

All public functions require full type annotations.
Use `TypedDict` for structured dictionaries, not bare `dict`.
```

---

## Example: If Your Project Uses TypeScript

```markdown
## TypeScript Toolchain

- **Version**: TypeScript 5.3+, Node 20 LTS
- **Package Manager**: pnpm
- **Build**: `pnpm build`
- **Format**: `pnpm prettier --write .`
- **Lint**: `pnpm eslint .`
- **Test**: `pnpm vitest`

### Null Handling

// Prefer nullish coalescing over ||
const value = config.timeout ?? 5000;

// Use optional chaining for deep access
const name = user?.profile?.displayName;

// Never use `any` - use `unknown` and narrow
function processInput(data: unknown): Result {
    if (!isValidInput(data)) throw new ValidationError();
    // data is now narrowed to ValidInput
}
```

---

# PROJECT-SPECIFIC SECTION

> **Template Section**: Replace this entire section with project-specific details when copying to a new project. Delete this notice after customizing.

This section documents **your specific project's architecture, workflows, and domain knowledge**. This is where you teach the AI about your codebase's unique structure and conventions.

---

## What to Include Here

### 1. Project Overview

A 2-3 sentence description of what this project is:

- What problem does it solve?
- What is the core architectural philosophy?
- What are we explicitly NOT trying to do?

Example:
> "Laminae is a container-native research kernel for ARM64. Containers are first-class OS citizens. We are NOT recreating Linux - this is a clean-slate exploration."

### 2. Directory Structure

Document your key directories and their purposes. Include the **source of truth** for different concerns:

```
src/
  core/           - Core business logic
  api/            - External API handlers
  models/         - Data models and schemas
  utils/          - Shared utilities (avoid dumping ground)
tests/
  unit/           - Fast, isolated tests
  integration/    - Tests requiring external services
docs/
  api/            - Generated API documentation
  architecture/   - Design decisions and ADRs
```

Highlight any **generated files** that should not be manually edited:
> **Never manually edit** `src/generated/client.ts` - it is regenerated from the OpenAPI spec.

### 3. Key Architectural Patterns

Document the patterns that are fundamental to understanding the codebase:

- **Table-driven design**: "All routes are defined in `src/routes/table.ts`"
- **Code generation**: "Run `make gen` to regenerate types from schema"
- **Service boundaries**: "Services communicate only via message queue, never direct calls"
- **Plugin architecture**: "Extensions go in `plugins/` and are auto-discovered"

### 4. Common Development Workflows

Document step-by-step workflows for common tasks:

#### Adding a New API Endpoint
1. Add route definition to `src/routes/table.ts`
2. Implement handler in `src/handlers/<domain>.ts`
3. Run `make gen` to regenerate client types
4. Add tests in `tests/integration/api/`
5. Verify with `make test`

#### Adding a New Database Migration
1. Create migration: `make migration name=add_users_table`
2. Edit generated file in `migrations/`
3. Apply locally: `make db-migrate`
4. Test rollback: `make db-rollback`

### 5. Testing Guidelines

- How to run tests
- Test file organization conventions
- Required test coverage for different code areas
- CI/CD expectations

### 6. Debugging Tools & Techniques

Document project-specific debugging:

- Log aggregation commands
- Common debug flags/environment variables
- How to inspect internal state
- Profiling commands

### 7. Domain-Specific Knowledge

Things that are unique to your problem domain:

- Important business rules
- Regulatory or compliance constraints
- Integration points with external systems
- Performance budgets or SLAs

### 8. "Inspiration vs. Recreation" Guidance (if applicable)

If your project draws from established systems while diverging intentionally:

| Industry Standard | Our Approach | Rationale |
|-------------------|--------------|-----------|
| REST API | GraphQL | Reduce over-fetching for mobile clients |
| Relational DB | Event sourcing | Audit trail requirements |

**When to reference [Industry Standard]:**
- DO: Study their auth patterns
- DON'T: Copy their data model verbatim

---

## Example: For a Web API Project

```markdown
## Project Overview

A REST API for the XYZ platform. Built on FastAPI with PostgreSQL.
Key principle: All business logic in service layer, handlers are thin.

## Key Directories

- `src/api/routes/` - Route definitions (FastAPI routers)
- `src/services/` - Business logic (one file per domain)
- `src/repositories/` - Database access layer
- `src/models/` - Pydantic models and SQLAlchemy ORM
- `src/core/config.py` - **Source of truth** for all config

## Common Workflows

### Adding a New Endpoint

1. Add route to appropriate router in `src/api/routes/`
2. Add service method in `src/services/<domain>.py`
3. Add repository method if DB access needed
4. Add request/response models to `src/models/schemas/`
5. Run `make test` and `make lint`
```

---

## Example: For a CLI Tool Project

```markdown
## Project Overview

A CLI tool for managing cloud infrastructure. Written in Go.
Key principle: Subcommands are self-contained, share only through pkg/.

## Key Directories

- `cmd/` - Main entry points (one per subcommand)
- `pkg/` - Shared packages (auth, api client, config)
- `internal/` - Private implementation details
- `configs/` - Default configuration files

## Common Workflows

### Adding a New Subcommand

1. Create new package under `cmd/<name>/`
2. Implement `Run()` function matching cobra.Command format
3. Register in `cmd/root.go`
4. Add tests in `cmd/<name>/<name>_test.go`
5. Update `README.md` with usage examples
```

---

we love you, Claude! do your best today