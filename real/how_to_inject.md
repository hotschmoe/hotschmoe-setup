# Hotschmoe Agent Injections - Usage Guide

## One-Liner Update

Update all marked sections in your CLAUDE.md:

```bash
curl -sL https://raw.githubusercontent.com/Hotschmoe/hotschmoe-setup/master/real/haj.sh | bash
```

Or specify a different target file:

```bash
curl -sL https://raw.githubusercontent.com/Hotschmoe/hotschmoe-setup/master/real/haj.sh | bash -s -- ./path/to/CLAUDE.md
```

## How It Works

1. Script fetches source of truth from GitHub (`hotschmoe_agent_injections.md`)
2. Finds all `<!-- BEGIN:section-name -->` markers in your target file
3. Updates only those sections from source
4. Project-specific content (anything outside markers) is preserved

```
Your CLAUDE.md:
+------------------------------------------+
| <!-- BEGIN:rule-1-no-delete -->          |  <-- Updated from source
| (content)                                |
| <!-- END:rule-1-no-delete -->            |
|                                          |
| ## My Project-Specific Stuff             |  <-- Untouched
| (your custom content here)               |
|                                          |
| <!-- BEGIN:dev-philosophy -->            |  <-- Updated from source
| (content)                                |
| <!-- END:dev-philosophy -->              |
+------------------------------------------+
```

## Setting Up a New Project

1. Create `CLAUDE.md` with the sections you want (copy markers from examples below)
2. Add your project-specific content outside the markers
3. Run the one-liner anytime to sync with latest philosophies

### Starter Template (copy this)

```markdown
<!-- BEGIN:header -->
<!-- END:header -->

<!-- BEGIN:rule-1-no-delete -->
<!-- END:rule-1-no-delete -->

<!-- BEGIN:irreversible-actions -->
<!-- END:irreversible-actions -->

<!-- BEGIN:code-discipline -->
<!-- END:code-discipline -->

<!-- BEGIN:dev-philosophy -->
<!-- END:dev-philosophy -->

<!-- BEGIN:testing-philosophy -->
<!-- END:testing-philosophy -->

---

## Project-Specific Content

(Add your toolchain, architecture, workflows here - this won't be touched by haj.sh)

<!-- BEGIN:footer -->
<!-- END:footer -->
```

Then run the one-liner to populate the sections.

## Available Sections

| Section | Description |
|---------|-------------|
| `header` | CLAUDE.md title + love message |
| `rule-1-no-delete` | Absolute no-delete rule |
| `irreversible-actions` | Git/filesystem safety rules |
| `semver` | Version update guidelines |
| `code-discipline` | Editing discipline (no bulk mods, no emojis) |
| `no-legacy` | Full migrations only policy |
| `dev-philosophy` | Make it work/right/fast |
| `testing-philosophy` | Tests as diagnostics, not verdicts |
| `code-simplifier` | Post-session cleanup agent |
| `claude-agents` | Agent documentation template |
| `claude-skills` | Skills documentation template |
| `project-language-template` | Placeholder for language-specific content |
| `footer` | Closing message |

## Section Bundles

**Minimal (safety only):**
```markdown
<!-- BEGIN:rule-1-no-delete -->
<!-- END:rule-1-no-delete -->

<!-- BEGIN:irreversible-actions -->
<!-- END:irreversible-actions -->
```

**Standard (recommended):**
```markdown
<!-- BEGIN:header -->
<!-- END:header -->

<!-- BEGIN:rule-1-no-delete -->
<!-- END:rule-1-no-delete -->

<!-- BEGIN:irreversible-actions -->
<!-- END:irreversible-actions -->

<!-- BEGIN:code-discipline -->
<!-- END:code-discipline -->

<!-- BEGIN:no-legacy -->
<!-- END:no-legacy -->

<!-- BEGIN:dev-philosophy -->
<!-- END:dev-philosophy -->

<!-- BEGIN:testing-philosophy -->
<!-- END:testing-philosophy -->

<!-- BEGIN:footer -->
<!-- END:footer -->
```

## Tips

- Only sections with markers in your file get updated
- Add/remove sections by adding/removing marker pairs
- Project-specific content goes outside markers (or replaces `project-language-template`)
- Run the one-liner periodically to pick up philosophy updates
