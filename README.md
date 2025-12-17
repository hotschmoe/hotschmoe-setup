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

---

## Linux

### Developer Machine (`linux/dev-setup.sh`)

**Auto-detects distro** and uses the appropriate package manager:
- **Ubuntu/Debian** → `apt`
- **Arch/Omarchy** → `pacman` + `yay` (installs yay if missing)

| Application | Ubuntu/Debian | Arch/Omarchy |
|-------------|---------------|--------------|
| Git | apt | pacman |
| Build essentials | apt | pacman |
| tmux | apt | pacman |
| htop | apt | pacman |
| Ghostty | **Manual** | AUR (yay) |
| Node.js | NodeSource | pacman |
| Bun | curl installer | curl installer |
| Go | official tarball | pacman |
| Python 3 | apt | pacman |
| Zig | official tarball | pacman |
| ZLS | GitHub release | pacman |
| ARM GNU Toolchain | apt | pacman |
| Docker | get.docker.com | pacman |
| QEMU | apt | pacman |
| LazyGit | GitHub release | pacman |
| Claude Code | curl installer | curl installer |
| Gemini CLI | bun | bun |
| Beads (bd/bv) | curl installer | curl installer |
| Cursor | **Manual** | AUR (yay) |
| Antigravity IDE | **Manual** | **Manual** |

**Usage:**
```bash
chmod +x linux/dev-setup.sh
./linux/dev-setup.sh
```

**Post-Installation:**
1. Log out and back in for docker group to take effect
2. Restart terminal or `source ~/.bashrc`
3. Verify: `git --version`, `zig version`, `docker --version`, etc.

---

## Notes

- **WSL2 + Ubuntu** (Windows) is installed for Docker backend and general Linux development
- **Why native Zig on Windows?** Zig v0.15.0+ fails to build on WSL
- **Why Bun?** Faster than npm for global package installation
- **winget required** (Windows) - Install via Microsoft Store if not present
- **Docker** uses WSL2 backend on Windows, native on Linux
