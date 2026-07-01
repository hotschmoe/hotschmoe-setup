# hotschmoe-setup

Bootstrap [pi](https://pi.dev) (the terminal coding agent) and point it at a
self-hosted OpenAI-compatible endpoint (e.g. SGLang) in one command.

Each script:

1. Ensures a JS package manager is present (`bun` or `npm`) and installs
   `@earendil-works/pi-coding-agent` (skips if already installed).
2. Prompts for a **server URL** — bare host or full URL both work. The scheme
   and `/v1` suffix are added automatically, and the **provider name is derived
   from the host** (`llm.hotschmoe.com` → `hotschmoe`).
3. Prompts for an **API key** (surrounding quotes are stripped automatically).
4. Discovers models from `<baseUrl>/models`.
5. Shows what it found and asks for confirmation, backs up any existing
   config, then writes `~/.pi/agent/auth.json` and `~/.pi/agent/models.json`
   (the bash version also `chmod 600`s them since they hold your API key).

Verify at the end with `pi --list-models`.

## Quick start

### Windows (PowerShell)

```powershell
powershell -c "irm https://raw.githubusercontent.com/hotschmoe/hotschmoe-setup/main/setup_pi.ps1 | iex"
```

### macOS / Linux (bash)

```bash
curl -fsSL https://raw.githubusercontent.com/hotschmoe/hotschmoe-setup/main/setup_pi.sh | bash
```

> Use the **raw.githubusercontent.com** URL, not the github.com page URL — the
> pipe needs the script text, not the rendered HTML. If your default branch
> isn't `main`, swap it in the path.

## URL input examples

All of these resolve to base URL `http://llm.hotschmoe.com/v1`, provider
`hotschmoe`:

| You type                          | Base URL used                     | Provider  |
|-----------------------------------|-----------------------------------|-----------|
| `llm.hotschmoe.com`               | `http://llm.hotschmoe.com/v1`     | hotschmoe |
| `http://llm.hotschmoe.com`        | `http://llm.hotschmoe.com/v1`     | hotschmoe |
| `https://llm.hotschmoe.com/v1`    | `https://llm.hotschmoe.com/v1`    | hotschmoe |
| `https://llm.hotschmoe.com/v1/`   | `https://llm.hotschmoe.com/v1`    | hotschmoe |
| `https://api.example.com/v1/models` | `https://api.example.com/v1`    | example   |

Bare hostnames default to `http://`. Type the full `https://...` if you need TLS.

## Requirements

- `curl` (bash version) / PowerShell 5.1+ (Windows version)
- A JS package manager: **bun** or **npm/Node**. If neither is present, the
  script tells you how to install one and exits. Pi is distributed on npm and
  is not a standalone binary, so a runtime is required.

## Run manually

```bash
# bash
chmod +x setup_pi.sh
./setup_pi.sh
```

```powershell
# PowerShell — may need to allow the script for this session
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\setup_pi.ps1
```

## What gets written

`~/.pi/agent/auth.json`:

```json
{ "hotschmoe": { "apiKey": "..." } }
```

`~/.pi/agent/models.json`: a `providers.<name>` block with `baseUrl`,
`api: "openai-completions"`, and one entry per discovered model.

Then just run `pi`.
