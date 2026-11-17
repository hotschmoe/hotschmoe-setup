# Engineering conventions

These rules apply to every project and every agent (Claude Code, Codex, pi, Protectorate
sleeves). Where a repo's own CLAUDE.md or AGENTS.md disagrees on testing or comments, this
file wins until that repo is brought in line.

## Stack

- **Default: Zig, TigerStyle, zero dependencies, with deterministic simulation testing (DST).**
- **Projects with outside contributors** (friends or strangers): Rust. Every third-party crate is
  pinned exactly and listed with its reason.
- **UI:** native where practical; Flutter is acceptable when it saves real time.
- **Own the toolchain and infra.** Prefer a few hundred lines of our own code over a dependency.
  Fork a project rather than depend on its roadmap.

## Toolchains

- One shared toolchain set across all projects and machines, always the current release. When a
  new release lands, bring every project up to it in one wave instead of pinning old versions
  per repo.
- Exception: a version that is the *subject* of the work is pinned as data in that repo, not used
  as its build toolchain. Examples: telchar's double-compile target, a Zig compiler built as a
  laminae cell.

## Testing

- **Zero unit tests.** A test that calls a function with crafted inputs and checks its return
  value is a unit test, wherever it lives.
- **At most 10 blocking end-to-end tests per project.** They cover the build and the main
  end-to-end paths, run our real binaries, and finish in a few minutes. They are the only gate
  that blocks work.
- **Delete tests that:**
  - change whenever the code does (golden output, snapshots, tests that mirror the structure);
  - check that deleted features are gone;
  - can never fail (tautologies, asserts on constants, tests of mocks, always-skipped tests).
- **Everything else goes to the background major gate**, or is deleted. Fuzz seed replay and long
  DST runs belong there too, unless a short run is one of the ten.
- **Past 10 blocking tests:** prune stale ones, or move them to the background gate.
- **Background major gate:** runs every 10-20 commits (or nightly) and never blocks anyone. When it
  fails, an agent finds the regressing commit by rerunning only the failing tests on earlier
  commits (step back one or two, then bisect), and then commits a fix to head or opens a PR.
- Removing tests under this policy is pre-approved. Remove them by editing; move whole test files
  to `.archive/` (gitignored) so nothing is lost.

## Comments

- Remove narration, history, "what this does" and TODO chatter from code. A comment stays only
  for a non-obvious invariant or a reference (spec section, issue link), in one line.
- Anything important the code cannot say goes in `SRC.md` at the repo root (or beside a large
  subsystem), one section per module. Design decisions go in SPEC.md or DESIGN.md as before.

## Deletion

- Agents never delete files or run destructive git commands. Move deprecated files to `.archive/`
  (gitignored) and say so. Only the owner runs real deletes.
