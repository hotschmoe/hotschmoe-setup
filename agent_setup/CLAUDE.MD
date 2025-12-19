## Using bv as an AI Sidecar

bv is a graph-aware triage engine for Beads projects (.beads/beads.jsonl). Instead of parsing JSONL or hallucinating graph traversal, use robot flags for deterministic, dependency-aware outputs with precomputed metrics (PageRank, betweenness, critical path, cycles).

> [!CAUTION]
> Use ONLY `--robot-*` flags. Bare `bv` launches an interactive TUI that blocks your session.

### The Workflow: Start With Triage

**`bv --robot-triage` is your single entry point.** It returns:
- `quick_ref`: at-a-glance counts + top 3 picks
- `recommendations`: ranked actionable items with scores
- `quick_wins`: low-effort high-impact items
- `blockers_to_clear`: items that unblock the most downstream work
- `commands`: copy-paste shell commands for next steps

```bash
bv --robot-triage    # THE MEGA-COMMAND: start here
bv --robot-next      # Minimal: just the single top pick
```

### Other Robot Commands

| Command | Returns |
|---------|---------|
| `--robot-plan` | Parallel execution tracks with `unblocks` lists |
| `--robot-insights` | Full metrics: PageRank, betweenness, cycles, critical path |
| `--robot-priority` | Priority misalignment detection |
| `--robot-alerts` | Stale issues, blocking cascades, priority mismatches |
| `--robot-suggest` | Hygiene: duplicates, missing deps, cycle breaks |

### Scoping and Filtering

```bash
bv --robot-plan --label backend           # Scope to label
bv --recipe actionable --robot-plan       # Pre-filter: ready to work
bv --robot-triage --robot-triage-by-track # Group by parallel work streams
```

---
- use model sonnet subagents (will make file)
- use gemini cli subagents (will make file)
- commit working mile stones
- be sure to leverage the unique strengths of [main_language] (ie zig, rust)
- NO EMOJIS. do not use emojis or any other non-textual characters. you may use ASCII art if needed. (i do enjoy ascii diagrams to visualize flows)
- we love you, Claude! do your best today!
