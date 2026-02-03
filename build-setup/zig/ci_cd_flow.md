# Zig CI/CD Flow

This project uses a fully automated CI/CD pipeline where releases are driven by the version declared in `build.zig.zon`.

```
+------------------+     +------------------+     +------------------+
|  Feature Branch  | --> |   Pull Request   | --> |      Master      |
+------------------+     +------------------+     +------------------+
        |                        |                        |
        v                        v                        v
   Development              CI Workflow              Auto Release
   - Write code             - Build                  - Parse version
   - Bump version           - Test                   - Create tag
                            - Version check          - GitHub Release
```

---

## Workflow Overview

1. **Development**: Create a feature branch, make changes, bump version in `build.zig.zon`
2. **Pull Request**: Open PR to `master`, CI runs tests and validates version bump
3. **Merge**: Blocked until CI passes (requires branch protection)
4. **Release**: Auto-creates GitHub Release with version from `build.zig.zon`

---

## 1. Continuous Integration (CI)

**File:** `.github/workflows/ci.yml`

Runs on every Pull Request to `master`. Choose the option that fits your needs.

### Option A: Basic CI (Single Platform)

Use this for libraries or when cross-platform testing isn't critical.

```yaml
name: CI

on:
  pull_request:
    branches: [ "master" ]

jobs:
  build-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Needed for version comparison

      - name: Setup Zig
        uses: mlugg/setup-zig@v1
        with:
          version: 0.15.2

      - name: Check Version Bump
        run: |
          PR_VERSION=$(sed -n 's/.*\.version = "\([^"]*\)".*/\1/p' build.zig.zon)
          git fetch origin master
          MASTER_VERSION=$(git show origin/master:build.zig.zon | sed -n 's/.*\.version = "\([^"]*\)".*/\1/p')
          echo "PR version: $PR_VERSION"
          echo "Master version: $MASTER_VERSION"
          if [ "$PR_VERSION" = "$MASTER_VERSION" ]; then
            echo "::error::Version not bumped! Update .version in build.zig.zon"
            exit 1
          fi
          echo "Version bump verified: $MASTER_VERSION -> $PR_VERSION"

      - name: Build
        run: zig build

      - name: Test
        run: zig build test
```

### Option B: Multi-Platform CI

Use this for applications where you need to verify builds across Linux, macOS, and Windows.

```yaml
name: CI

on:
  pull_request:
    branches: [ "master" ]

jobs:
  # Version check runs once
  version-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Check Version Bump
        run: |
          PR_VERSION=$(sed -n 's/.*\.version = "\([^"]*\)".*/\1/p' build.zig.zon)
          git fetch origin master
          MASTER_VERSION=$(git show origin/master:build.zig.zon | sed -n 's/.*\.version = "\([^"]*\)".*/\1/p')
          echo "PR version: $PR_VERSION"
          echo "Master version: $MASTER_VERSION"
          if [ "$PR_VERSION" = "$MASTER_VERSION" ]; then
            echo "::error::Version not bumped! Update .version in build.zig.zon"
            exit 1
          fi
          echo "Version bump verified: $MASTER_VERSION -> $PR_VERSION"

  # Build and test on multiple platforms
  build-and-test:
    needs: version-check
    strategy:
      matrix:
        include:
          - target: x86_64-linux
            os: ubuntu-latest
          - target: x86_64-windows
            os: ubuntu-latest
          - target: aarch64-macos
            os: macos-latest
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4

      - name: Setup Zig
        uses: mlugg/setup-zig@v1
        with:
          version: 0.15.2

      - name: Build
        run: zig build -Dtarget=${{ matrix.target }}

      - name: Test
        if: matrix.target == 'x86_64-linux'
        run: zig build test
```

---

## 2. Automated Release

**File:** `.github/workflows/release.yml`

Runs when code is pushed to `master`. Parses version from `build.zig.zon` and creates a release.

### Option A: Libraries (Source Only)

Use this for libraries consumed via `zig fetch`. No pre-built binaries needed.

```yaml
name: Auto Release

on:
  push:
    branches: [ "master" ]

permissions:
  contents: write

jobs:
  create-release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Get Version from build.zig.zon
        id: get_version
        run: |
          VERSION=$(sed -n 's/.*\.version = "\([^"]*\)".*/\1/p' build.zig.zon)
          echo "Detected version: $VERSION"
          echo "version=$VERSION" >> $GITHUB_OUTPUT

      - name: Check if Tag Exists
        run: |
          TAG_NAME="v${{ steps.get_version.outputs.version }}"
          if git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
            echo "::error::Tag $TAG_NAME already exists! Version was not bumped in build.zig.zon."
            exit 1
          fi
          echo "Tag $TAG_NAME does not exist. Creating release."

      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          tag_name: v${{ steps.get_version.outputs.version }}
          name: Release v${{ steps.get_version.outputs.version }}
          generate_release_notes: true
          draft: false
          prerelease: false
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Option B: Applications (With Binaries)

Use this for CLI tools or games where you want to attach executables to the release.

```yaml
name: Auto Release

on:
  push:
    branches: [ "master" ]

permissions:
  contents: write

jobs:
  create-release:
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.get_version.outputs.version }}
      created: ${{ steps.check_tag.outputs.created }}
    steps:
      - uses: actions/checkout@v4

      - name: Get Version
        id: get_version
        run: |
          VERSION=$(sed -n 's/.*\.version = "\([^"]*\)".*/\1/p' build.zig.zon)
          echo "version=$VERSION" >> $GITHUB_OUTPUT

      - name: Check Tag
        id: check_tag
        run: |
          TAG="v${{ steps.get_version.outputs.version }}"
          if git rev-parse "$TAG" >/dev/null 2>&1; then
            echo "::error::Tag $TAG already exists! Version was not bumped."
            echo "created=false" >> $GITHUB_OUTPUT
            exit 1
          else
            echo "created=true" >> $GITHUB_OUTPUT
          fi

      - name: Create Release
        if: steps.check_tag.outputs.created == 'true'
        uses: softprops/action-gh-release@v1
        with:
          tag_name: v${{ steps.get_version.outputs.version }}
          name: Release v${{ steps.get_version.outputs.version }}
          generate_release_notes: true

  upload-assets:
    needs: create-release
    if: needs.create-release.outputs.created == 'true'
    strategy:
      matrix:
        include:
          - target: x86_64-linux
            os: ubuntu-latest
          - target: x86_64-windows
            os: ubuntu-latest
          - target: aarch64-macos
            os: macos-latest
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4

      - uses: mlugg/setup-zig@v1
        with:
          version: 0.15.2

      - name: Build
        run: zig build -Dtarget=${{ matrix.target }} -Doptimize=ReleaseFast

      - name: Prepare Artifact
        run: |
          cd zig-out/bin
          for f in *; do mv "$f" "$f-${{ matrix.target }}"; done

      - name: Upload to Release
        uses: softprops/action-gh-release@v1
        with:
          tag_name: v${{ needs.create-release.outputs.version }}
          files: zig-out/bin/*
```

---

## 3. GitHub Repository Settings

Configure **Branch Protection Rules** for `master` to enforce the workflow.

**Path:** `Settings` > `Branches` > `Add branch protection rule`

| Setting                          | Value            | Purpose                              |
| :------------------------------- | :--------------- | :----------------------------------- |
| Branch name pattern              | `master`         | Target branch                        |
| Require a pull request           | Checked          | Ensures CI runs before merge         |
| Require status checks            | Checked          | Prevents broken code on master       |
| Status checks to require         | `build-and-test` | Job name from `ci.yml`               |
| Do not allow bypassing           | Checked          | Enforces rules for admins too        |

**Note:** The status check option may not appear until you've pushed the workflow file once.

---

## 4. Usage Guide

### Daily Workflow

```
1. git checkout -b feature/my-change
2. # Make your changes
3. # Edit build.zig.zon: .version = "X.Y.Z"
4. git commit -am "feat: my change"
5. git push -u origin feature/my-change
6. # Open PR on GitHub
7. # Wait for CI (version check + build + test)
8. # Merge when green
9. # Release auto-created!
```

### Version Bump Rules

- **Patch** (0.1.0 -> 0.1.1): Bug fixes, minor tweaks
- **Minor** (0.1.0 -> 0.2.0): New features, backwards compatible
- **Major** (0.1.0 -> 1.0.0): Breaking changes

### What Happens When

| Action                    | CI Result         | Release Result        |
| :------------------------ | :---------------- | :-------------------- |
| PR without version bump   | FAIL              | N/A                   |
| PR with version bump      | PASS (if tests ok)| N/A                   |
| Merge to master           | N/A               | Creates vX.Y.Z release|
| Push same version again   | N/A               | FAIL (tag exists)     |
