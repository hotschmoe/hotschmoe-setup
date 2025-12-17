# hotschmoe-setup

Scripts to commission new machines with all required software.

## Windows

### Work Machine (`windows/work-setup.ps1`)

Installs applications for work/engineering:

| Application | Installation Method |
|-------------|---------------------|
| Google Chrome | winget |
| Google Drive | winget |
| 7-Zip | winget |
| WireGuard | winget |
| ENERCALC | winget |
| PDF-XChange Editor | winget |
| ArchiCAD | **Manual** ([download](https://graphisoft.com/downloads)) |

**Usage:**
```powershell
# Run as Administrator (recommended)
.\windows\work-setup.ps1
```

---

### Developer Machine (`windows/dev-setup.ps1`)

Installs development tools and AI coding assistants:

| Application | Installation Method |
|-------------|---------------------|
| WSL2 + Ubuntu | `wsl --install -d Ubuntu` |
| Git | winget |
| Bun | winget |
| Node.js LTS | winget |
| Go | winget |
| Python 3.12 | winget |
| Zig | winget |
| ZLS (Zig Language Server) | winget |
| ARM GNU Toolchain | winget |
| Docker Desktop | winget |
| QEMU | winget |
| Cursor | winget |
| GitHub Desktop | winget |
| LazyGit | winget |
| Claude Code | native (`irm https://claude.ai/install.ps1 \| iex`) |
| Beads (bd/bv) | native (`irm .../install.ps1 \| iex`) |
| Gemini CLI | bun |
| Antigravity IDE | **Manual** ([download](https://antigravity.google)) |

**Usage:**
```powershell
# Run as Administrator (recommended)
.\windows\dev-setup.ps1
```

**Post-Installation:**
1. **REBOOT** if WSL2 was just installed (required to complete setup)
   - After reboot, Ubuntu will prompt for username/password creation
   - Docker will automatically use WSL2 backend
2. Restart your terminal for PATH changes to take effect
3. If Claude Code or Beads failed during install, run manually:
   ```powershell
   irm https://claude.ai/install.ps1 | iex
   irm https://raw.githubusercontent.com/steveyegge/beads/main/install.ps1 | iex
   ```
4. Run verification commands:
   ```powershell
   wsl --version
   wsl --list
   git --version
   bun --version
   node --version
   go version
   python --version
   zig version
   zls --version
   arm-none-eabi-gcc --version
   docker --version
   qemu-system-aarch64 --version
   claude --version
   lazygit --version
   bd version
   ```

---

## Notes

- **WSL2 + Ubuntu** is installed for Docker backend and general Linux development
- **Why native Zig?** Zig v0.15.0+ fails to build on WSL, so Zig development stays on native Windows
- **Why Bun?** Bun is faster than npm for package installation and is used for global packages like Gemini CLI
- **winget required** - These scripts require Windows Package Manager (winget). Install via Microsoft Store if not present
- **Docker** uses WSL2 backend by default (installs its own lightweight distro alongside Ubuntu)
