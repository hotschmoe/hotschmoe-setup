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

### Comparison of Options

| Feature | Option A (Basic) | Option B (Multi-Platform) | Option C (Comprehensive) |
|---------|------------------|---------------------------|--------------------------|
| Version bump check | ✓ | ✓ | ✓ |
| Build verification | ✓ | ✓ | ✓ |
| Unit tests | ✓ | ✓ | ✓ |
| Multi-platform | - | ✓ (3 platforms) | ✓ (3 platforms) |
| Multi-optimization | - | - | ✓ (4 levels) |
| Fuzz testing | - | - | ✓ |
| Format checking | - | - | ✓ |
| Package validation | - | - | ✓ |
| **Use Case** | Prototypes | Cross-platform apps | Production libraries |
| **CI Time** | ~2 min | ~5 min | ~10 min |

### Option A: Basic CI (Single Platform)

Use this for quick prototypes or when comprehensive testing isn't needed yet.

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

Use this when you need basic cross-platform verification but not full optimization testing.

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

### Option C: Comprehensive Testing (Recommended)

Use this for production libraries and applications. Provides thorough validation across platforms, optimization levels, formatting, and package integration.

```yaml
name: CI

on:
  pull_request:
    branches: [ "master" ]

jobs:
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

  test:
    needs: version-check
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
        optimize: [Debug, ReleaseSafe]
        include:
          - os: ubuntu-latest
            optimize: ReleaseFast
          - os: ubuntu-latest
            optimize: ReleaseSmall
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4

      - name: Setup Zig
        uses: mlugg/setup-zig@v1
        with:
          version: 0.15.2

      - name: Build
        run: zig build -Doptimize=${{ matrix.optimize }}

      - name: Test
        run: zig build test -Doptimize=${{ matrix.optimize }}

  fuzz:
    needs: version-check
    runs-on: ubuntu-latest
    continue-on-error: true
    steps:
      - uses: actions/checkout@v4

      - name: Setup Zig
        uses: mlugg/setup-zig@v1
        with:
          version: 0.15.2

      - name: Fuzz Test
        timeout-minutes: 1
        run: zig build fuzz

  format:
    needs: version-check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Zig
        uses: mlugg/setup-zig@v1
        with:
          version: 0.15.2

      - name: Check Format
        run: zig fmt --check src/

  package:
    needs: version-check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          path: source

      - name: Setup Zig
        uses: mlugg/setup-zig@v1
        with:
          version: 0.15.2

      - name: Create Test Consumer
        run: |
          mkdir test-consumer
          cd test-consumer
          cat > build.zig.zon << 'EOF'
          .{
              .name = "test-consumer",
              .version = "0.0.0",
              .dependencies = .{
                  .package = .{ .path = "../source" },
              },
              .paths = .{""},
          }
          EOF

          cat > build.zig << 'EOF'
          const std = @import("std");
          pub fn build(b: *std.Build) void {
              const target = b.standardTargetOptions(.{});
              const optimize = b.standardOptimizeOption(.{});
              const package = b.dependency("package", .{
                  .target = target,
                  .optimize = optimize,
              });
              _ = package;
          }
          EOF

      - name: Build Consumer
        working-directory: test-consumer
        run: zig build
```

**What this provides:**
- Multi-platform testing (Ubuntu, macOS, Windows)
- All optimization levels (Debug, ReleaseSafe, ReleaseFast, ReleaseSmall)
- Fuzz testing with timeout
- Format checking enforcement
- Package validation (ensures library can be consumed as dependency)

**Requirements for Option C:**

1. **Fuzz Testing**: Add a fuzz step to your `build.zig`
   ```zig
   const fuzz_step = b.step("fuzz", "Run fuzz tests");
   const fuzz_exe = b.addExecutable(.{
       .name = "fuzz",
       .root_source_file = b.path("src/fuzz.zig"),
       .target = target,
       .optimize = optimize,
   });
   const fuzz_run = b.addRunArtifact(fuzz_exe);
   fuzz_step.dependOn(&fuzz_run.step);
   ```
   Create `src/fuzz.zig` with your fuzz tests, or use a simple stub if not needed yet:
   ```zig
   pub fn main() !void {}
   ```

2. **Format Checking**: Ensure all source files are formatted
   ```bash
   zig fmt src/
   ```

3. **Package Exports**: If building a library, ensure your root file exposes the public API properly
   ```zig
   // In your main library file
   pub const MyType = @import("types.zig").MyType;
   pub const myFunction = @import("functions.zig").myFunction;
   ```

### Optional Enhancements

Add these jobs to Option C for even more thorough validation:

**Documentation Generation:**
```yaml
  docs:
    needs: version-check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Zig
        uses: mlugg/setup-zig@v1
        with:
          version: 0.15.2

      - name: Generate Docs
        run: zig build-lib src/main.zig -femit-docs -fno-emit-bin
```

**Conformance Testing** (for projects with spec compliance):
```yaml
  conformance:
    needs: version-check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive  # If spec is a submodule

      - name: Setup Zig
        uses: mlugg/setup-zig@v1
        with:
          version: 0.15.2

      - name: Conformance Tests
        run: zig build test-conformance
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

### Base Settings (All Options)

| Setting                          | Value            | Purpose                              |
| :------------------------------- | :--------------- | :----------------------------------- |
| Branch name pattern              | `master`         | Target branch                        |
| Require a pull request           | Checked          | Ensures CI runs before merge         |
| Require status checks            | Checked          | Prevents broken code on master       |
| Do not allow bypassing           | Checked          | Enforces rules for admins too        |

### Required Status Checks by CI Option

**Option A (Basic):**
- `build-and-test`

**Option B (Multi-Platform):**
- `version-check`
- `build-and-test`

**Option C (Comprehensive) - Recommended:**
- `version-check`
- `test`
- `format`
- `package`

**Note:**
- The `fuzz` job is not required (has `continue-on-error: true`)
- Status checks won't appear until you've pushed the workflow file once
- You can add all checks or just critical ones depending on your team's workflow

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
7. # Wait for CI (see below for what runs)
8. # Merge when green
9. # Release auto-created!
```

**What runs in CI depends on your chosen option:**
- **Option A:** Version check + build + test
- **Option B:** Version check + multi-platform build + test
- **Option C:** Version check + multi-platform tests + all optimization levels + fuzz + format + package validation

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

---

## Appendix: Conformance Testing

Some projects implement specifications or standards and need to validate against official conformance test suites. This is common for:

- Protocol implementations (HTTP, WebSocket, etc.)
- File format parsers (JSON, TOML, etc.)
- Language implementations (interpreters, compilers)
- Specification-driven libraries

### Example: toon_zig

The `toon_zig` project implements the TOML spec and validates against the official TOML conformance tests using a git submodule.

**Repository Structure:**
```
toon_zig/
  .gitmodules              # Defines conformance test submodule
  conformance/
    toml-test/             # Git submodule with official tests
  src/
  build.zig                # Includes test-conformance step
```

**CI Workflow Addition:**

```yaml
conformance:
  needs: version-check
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
      with:
        submodules: recursive  # Critical: checkout conformance tests

    - name: Setup Zig
      uses: mlugg/setup-zig@v1
      with:
        version: 0.15.2

    - name: Run Conformance Tests
      run: zig build test-conformance
```

**build.zig Setup:**

```zig
const conformance_tests = b.step("test-conformance", "Run conformance tests");

const conformance_exe = b.addExecutable(.{
    .name = "conformance",
    .root_source_file = b.path("src/conformance_runner.zig"),
    .target = target,
    .optimize = optimize,
});

const conformance_run = b.addRunArtifact(conformance_exe);
conformance_run.addArg("--test-dir");
conformance_run.addArg("conformance/toml-test/tests");
conformance_tests.dependOn(&conformance_run.step);
```

### Setting Up Conformance Testing

1. **Add the conformance test suite as a submodule:**
   ```bash
   git submodule add https://github.com/org/official-tests conformance/official-tests
   git commit -m "Add conformance test suite"
   ```

2. **Update `.gitmodules`:**
   ```ini
   [submodule "conformance/official-tests"]
       path = conformance/official-tests
       url = https://github.com/org/official-tests
   ```

3. **Add conformance step to `build.zig`** (see example above)

4. **Add conformance job to CI** (see workflow example above)

5. **Add to branch protection** (optional):
   - If conformance is critical, add `conformance` to required status checks
   - If tests are flaky or optional, use `continue-on-error: true`

### When to Make Conformance Required

**Required (blocks merge):**
- Stable specifications with reliable test suites
- Projects where spec compliance is the primary value proposition
- When all conformance tests consistently pass

**Optional (informational):**
- Incomplete spec implementations (partial compliance expected)
- Flaky or environment-dependent tests
- Experimental features not yet in official spec

**Example with optional conformance:**
```yaml
conformance:
  needs: version-check
  runs-on: ubuntu-latest
  continue-on-error: true  # Don't block merge on conformance failures
  steps:
    # ... same as above
```

### Best Practices

1. **Pin conformance test versions** - Use specific commits/tags in submodules to prevent surprise breakage
2. **Document compliance level** - Note which parts of the spec are implemented in README
3. **Separate unit and conformance** - Keep fast unit tests separate from slower conformance suites
4. **Update conformance regularly** - Periodically update submodule to catch new test cases

### Updating Conformance Tests

```bash
# Update to latest conformance tests
cd conformance/official-tests
git pull origin main
cd ../..
git add conformance/official-tests
git commit -m "Update conformance tests to latest"
```
