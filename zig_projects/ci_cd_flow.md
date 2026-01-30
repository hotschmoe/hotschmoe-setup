Libraries (zig fetch --save)

  Users fetch source and compile it themselves. You don't need to ship binaries.

  name: CI

  on:
    pull_request:
      branches: [master]
    push:
      tags: ['v*']

  jobs:
    test:
      strategy:
        matrix:
          os: [ubuntu-latest, macos-latest, windows-latest]
      runs-on: ${{ matrix.os }}
      steps:
        - uses: actions/checkout@v4
        - uses: mlugg/setup-zig@v2
          with:
            version: "0.15.2"
        - run: zig build test

    release:
      needs: [test]
      if: startsWith(github.ref, 'refs/tags/')
      runs-on: ubuntu-latest
      permissions:
        contents: write
      steps:
        - uses: actions/checkout@v4
        - uses: softprops/action-gh-release@v1
          with:
            generate_release_notes: true

  Workflow: PR -> merge -> git tag v1.0.2 && git push --tags -> CI tests -> release created

  ---
  Binaries (curl install)

  Users download pre-built executables. You need cross-compilation + upload artifacts.

  name: Release

  on:
    push:
      tags: ['v*']

  jobs:
    build:
      strategy:
        matrix:
          include:
            - target: x86_64-linux
              os: ubuntu-latest
            - target: aarch64-linux
              os: ubuntu-latest
            - target: x86_64-macos
              os: macos-latest
            - target: aarch64-macos
              os: macos-latest
            - target: x86_64-windows
              os: windows-latest
      runs-on: ${{ matrix.os }}
      steps:
        - uses: actions/checkout@v4
        - uses: mlugg/setup-zig@v2
          with:
            version: "0.15.2"
        - run: zig build -Doptimize=ReleaseSafe -Dtarget=${{ matrix.target }}
        - uses: actions/upload-artifact@v4
          with:
            name: binary-${{ matrix.target }}
            path: zig-out/bin/*

    release:
      needs: [build]
      runs-on: ubuntu-latest
      permissions:
        contents: write
      steps:
        - uses: actions/download-artifact@v4
        - uses: softprops/action-gh-release@v1
          with:
            files: binary-*/*
            generate_release_notes: true

  Then provide an install script:
  #!/bin/sh
  REPO="user/tool"
  VERSION="${1:-latest}"
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  ARCH=$(uname -m)
  curl -L "https://github.com/$REPO/releases/download/$VERSION/tool-$ARCH-$OS" -o tool
  chmod +x tool

  ---
  Summary
  ┌─────────────────┬─────────────────────┬───────────────────────────┐
  │     Aspect      │       Library       │          Binary           │
  ├─────────────────┼─────────────────────┼───────────────────────────┤
  │ Trigger         │ Tags only           │ Tags only                 │
  ├─────────────────┼─────────────────────┼───────────────────────────┤
  │ Test on         │ PR + tags           │ PR + tags                 │
  ├─────────────────┼─────────────────────┼───────────────────────────┤
  │ Build artifacts │ None needed         │ Cross-compile all targets │
  ├─────────────────┼─────────────────────┼───────────────────────────┤
  │ Release assets  │ Just source tarball │ Binaries + checksums      │
  ├─────────────────┼─────────────────────┼───────────────────────────┤
  │ User gets       │ Source via URL      │ Pre-built executable      │
  └─────────────────┴─────────────────────┴───────────────────────────┘



  GitHub Settings You Need

  1. Protect master branch

  Go to: Settings > Branches > Add branch protection rule
  ┌───────────────────────────────────────┬───────────────────────────────────────────────────────────────┐
  │                Setting                │                             Value                             │
  ├───────────────────────────────────────┼───────────────────────────────────────────────────────────────┤
  │ Branch name pattern                   │ master                                                        │
  ├───────────────────────────────────────┼───────────────────────────────────────────────────────────────┤
  │ Require a pull request before merging │ Yes (recommended)                                             │
  ├───────────────────────────────────────┼───────────────────────────────────────────────────────────────┤
  │ Require status checks to pass         │ Yes                                                           │
  ├───────────────────────────────────────┼───────────────────────────────────────────────────────────────┤
  │ Required checks                       │ Test (ubuntu-latest, Debug), Format Check, Package Validation │
  ├───────────────────────────────────────┼───────────────────────────────────────────────────────────────┤
  │ Require branches to be up to date     │ Optional                                                      │
  └───────────────────────────────────────┴───────────────────────────────────────────────────────────────┘
  2. Tag permissions

  By default, anyone with write access can push tags. No special settings needed for v* tags to trigger workflows.

  If you want to restrict who can create release tags:
  - Settings > Tags > Add rule
  - Pattern: v*
  - Restrict to: specific roles/users

  ---
  Next Steps

  1. Commit these changes to your current branch
  2. Merge to master (or push directly if not protected yet)
  3. Create the tag: git tag v1.0.1 && git push origin v1.0.1
  4. CI will run and create the release