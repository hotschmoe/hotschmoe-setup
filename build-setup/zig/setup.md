# Zig Project Setup Guide

Quick setup for the automated CI/CD workflow.

---

## Step 1: GitHub Repository Settings

Configure branch protection to enforce the PR workflow.

**Path:** Repository > `Settings` > `Branches` > `Add branch protection rule`

### Required Settings

| Setting                                    | Value            |
| :----------------------------------------- | :--------------- |
| Branch name pattern                        | `master`         |
| Require a pull request before merging      | Checked          |
| Require status checks to pass before merge | Checked          |
| Status checks to require (see below)       | See CI option    |
| Do not allow bypassing the above settings  | Checked          |

**Status checks by CI option:**
- **Option A (Basic):** `build-and-test`
- **Option B (Multi-Platform):** `version-check`, `build-and-test`
- **Option C (Comprehensive):** `version-check`, `test`, `format`, `package`

### Optional Settings

| Setting            | When to Use                                      |
| :----------------- | :----------------------------------------------- |
| Require approvals  | Multi-person teams (skip for solo repos)         |

**Note:** Status checks won't appear in the search until you've pushed the workflow file at least once.

---

## Step 2: Add Workflow Files

Copy the appropriate YAML from `ci_cd_flow.md` to your repository:

```
your-repo/
  .github/
    workflows/
      ci.yml       # From ci_cd_flow.md Section 1
      release.yml  # From ci_cd_flow.md Section 2
  build.zig.zon    # Must contain .version = "X.Y.Z"
  build.zig
  src/
```

### Choosing Your CI Strategy

**Option A - Basic CI**: Quick prototypes, learning projects
**Option B - Multi-Platform**: Cross-platform apps needing basic verification
**Option C - Comprehensive (Recommended)**: Production libraries and applications

For most projects, **use Option C** to get:
- Multi-platform testing (Ubuntu, macOS, Windows)
- All optimization levels (Debug, ReleaseSafe, ReleaseFast, ReleaseSmall)
- Fuzz testing
- Format checking
- Package validation

---

## Step 3: Verify Setup

1. Create a test branch: `git checkout -b test/ci-check`
2. Make a small change and bump version in `build.zig.zon`
3. Push and open a PR to `master`
4. Verify CI runs and passes
5. Merge the PR
6. Check that a GitHub Release was created

---

## Daily Workflow

```
1. Create branch    git checkout -b feature/thing
2. Make changes     # code, code, code
3. Bump version     # edit build.zig.zon
4. Commit & push    git commit -am "feat: thing" && git push -u origin HEAD
5. Open PR          # GitHub UI
6. Wait for CI      # Must pass version check + tests
7. Merge            # Release auto-created
```

---

## Troubleshooting

### CI fails with "Version not bumped"

You forgot to update `.version` in `build.zig.zon`. Every PR must bump the version.

### Release fails with "Tag already exists"

The version in `build.zig.zon` matches an existing release. Bump to a new version.

### Status check not appearing

Push the workflow files first, then return to branch protection settings.

### Tests pass locally but fail in CI

Check that your Zig version matches the one in the workflow (`version: 0.15.2`).

### Format check fails

Run `zig fmt src/` locally to fix formatting, then commit the changes.

### Fuzz test fails

If using Option C (Comprehensive), ensure you have a `fuzz` step in `build.zig` or add a stub `src/fuzz.zig` file. The fuzz job has `continue-on-error: true` so it won't block merges.

### Package validation fails

Your library's public API may not be properly exported. Check that your root source file exports all public types and functions that consumers need.

### Build fails on specific optimization level

Test locally with that optimization level:
```bash
zig build -Doptimize=ReleaseFast
zig build test -Doptimize=ReleaseSafe
```
