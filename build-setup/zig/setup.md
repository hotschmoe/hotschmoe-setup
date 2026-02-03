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
| Status checks to require                   | `build-and-test` |
| Do not allow bypassing the above settings  | Checked          |

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
