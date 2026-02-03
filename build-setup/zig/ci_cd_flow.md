# Zig CI/CD Flow

This project uses a fully automated CI/CD pipeline where releases are driven by the version declared in `build.zig.zon`.

## Workflow Overview

1.  **Development**:
    *   Create a feature branch.
    *   Make code changes.
    *   **Bump the version** in `build.zig.zon` if this is a release-worthy change.
2.  **Pull Request**:
    *   Open a PR to `master`.
    *   **CI Workflow** runs tests automatically.
    *   Merge is blocked until tests pass (if branch protection is configured).
3.  **Merge & Release**:
    *   Merge the PR to `master`.
    *   **Auto Release Workflow** runs on the commit to `master`.
    *   It checks the version in `build.zig.zon`.
    *   If that version has not been tagged yet, it creates a `vX.Y.Z` tag and a GitHub Release.
    *   If the version already exists (you didn't bump it), the release job will fail/skip to prevent duplicate tags.

---

## 1. Continuous Integration (CI)

**File:** `.github/workflows/ci.yml`

Runs on every Pull Request to `master` to ensure code quality.

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

      - name: Setup Zig
        uses: mlugg/setup-zig@v1
        with:
          version: 0.15.2 # Set your preferred Zig version here

      - name: Build
        run: zig build

      - name: Test
        run: zig build test
```

## 2. Automated Release

**File:** `.github/workflows/release.yml`

This workflow runs when code is pushed to `master`. It parses the version from `build.zig.zon` and acts accordingly. Choose the option below that fits your project.

### Option A: Libraries (Source Only)

Use this if you are building a library that users will consume via `zig fetch`. You don't need pre-built binaries.

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

      # 1. Parse version from build.zig.zon
      - name: Get Version from build.zig.zon
        id: get_version
        run: |
          VERSION=$(sed -n 's/.*\.version = "\([^"]*\)".*/\1/p' build.zig.zon)
          echo "Detected version: $VERSION"
          echo "version=$VERSION" >> $GITHUB_OUTPUT

      # 2. Check if a git tag for this version already exists
      - name: Check if Tag Exists
        id: check_tag
        run: |
          TAG_NAME="v${{ steps.get_version.outputs.version }}"
          if git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
            echo "::error::Tag $TAG_NAME already exists! You likely forgot to bump the version in build.zig.zon."
            exit 1
          fi
          echo "Tag $TAG_NAME does not exist. Creating release."

      # 3. Create Release (Only if tag didn't exist)
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

Use this if you are building a CLI tool or game and want to attach executable binaries (Linux, macOS, Windows) to the release.

```yaml
name: Auto Release

on:
  push:
    branches: [ "master" ]

permissions:
  contents: write

jobs:
  # 1. Create the Release first
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
             echo "created=false" >> $GITHUB_OUTPUT
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

  # 2. Build & Upload Artifacts (Only if a new release was created)
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

      # Rename binary to include target name (e.g., myapp-x86_64-linux)
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

## 3. GitHub Repository Settings

To ensure this flow works safely, configure **Branch Protection Rules** for `master`.

**Go to:** `Settings` > `Branches` > `Add branch protection rule`

| Setting | Value | Reason |
| :--- | :--- | :--- |
| **Branch name pattern** | `master` | Target branch |
| **Require a pull request** | Checked | Ensures CI runs before merge |
| **Require status checks** | Checked | Prevents broken code on master |
| **Status checks to require** | `build-and-test` | The job name from `ci.yml` |
| **Do not allow bypassing** | Checked | Enforces the rules for admins too |

---

## 4. Usage Guide

### Day-to-Day Development
1.  **Work**: Create a branch `feature/new-thing`.
2.  **Commit**: Push changes.
3.  **PR**: Open a PR to `master`. Verify `build-and-test` passes.
4.  **Merge**: Merge the PR.

### Creating a Release
1.  **Bump Version**: In your PR, update `build.zig.zon`:
    ```zig
    .version = "0.2.0", // Change this!
    ```
2.  **Merge**: When you merge this PR, the `Auto Release` workflow will see the new version string.
3.  **Result**: A new Release `v0.2.0` is created on GitHub automatically.