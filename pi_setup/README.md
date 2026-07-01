# hotschmoe-setup — pi_setup

Bootstrap [pi](https://pi.dev) (the terminal coding agent) and point it at a
self-hosted OpenAI-compatible endpoint (e.g. SGLang) in one command.

Repo path: <https://github.com/hotschmoe/hotschmoe-setup/tree/master/pi_setup>

Each script:

1. Ensures a JS package manager is present (`bun` or `npm`) and installs
   `@earendil-works/pi-coding-agent` (skips if already installed).
2. Prompts for a **server URL** — bare host or full URL both work. The scheme
   and `/v1` suffix are added automatically, and the **provider name is derived
   from the host** (`llm.hotschmoe.com` → `hotschmoe`).
3. Prompts for an **API key** (surrounding quotes are stripped automatically).
4. Prompts for **max output tokens** (defaults to 32768), clamped per-model.
5. Discovers models from `<baseUrl>/models`. Each model's **context window is
   read from the server's `max_model_len`**.
6. For each discovered model, asks **Vision (image input)?** and
   **Thinking (reasoning)?** — both default to yes — and writes the matching
   `input` / `reasoning` fields.
7. Shows what it found, asks for confirmation, backs up any existing config,
   then writes `~/.pi/agent/auth.json` and `~/.pi/agent/models.json` (the bash
   version also `chmod 600`s them since they hold your API key).

Verify at the end with `pi --list-models` — you should see `thinking` and
`images` set to `yes` for models you enabled them on.

## Quick start

### Windows (PowerShell)

```powershell
powershell -c "irm https://raw.githubusercontent.com/hotschmoe/hotschmoe-setup/master/pi_setup/setup_pi.ps1 | iex"
```

### macOS / Linux (bash)

```bash
curl -fsSL https://raw.githubusercontent.com/hotschmoe/hotschmoe-setup/master/pi_setup/setup_pi.sh | bash
```

> Use the **raw.githubusercontent.com** URL, not the github.com page URL — the
> pipe needs the script text, not the rendered HTML. The scripts live in
> `pi_setup/` on the `master` branch.

## URL input handling

The server is TLS-only behind the reverse proxy, so **bare hostnames default to
`https://`**; the discovery call also follows redirects and forces HTTP/1.1 to
dodge an HTTP/2 framing bug in the proxy. Type an explicit `http://` to override
the scheme. All of these resolve to provider `hotschmoe`:

| You type                            | Base URL used                  | Provider  |
|-------------------------------------|--------------------------------|-----------|
| `llm.hotschmoe.com`                 | `https://llm.hotschmoe.com/v1` | hotschmoe |
| `http://llm.hotschmoe.com`          | `http://llm.hotschmoe.com/v1`  | hotschmoe |
| `https://llm.hotschmoe.com/v1`      | `https://llm.hotschmoe.com/v1` | hotschmoe |
| `https://llm.hotschmoe.com/v1/`     | `https://llm.hotschmoe.com/v1` | hotschmoe |
| `https://api.example.com/v1/models` | `https://api.example.com/v1`   | example   |

## Requirements

- `curl` (bash) / PowerShell 5.1+ (Windows)
- A JS package manager: **bun** or **npm/Node**. If neither is present, the
  script tells you how to install one and exits. Pi is distributed on npm and is
  not a standalone binary, so a runtime is required.

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
`api: "openai-completions"`, a `compat` block tuned for SGLang
(`supportsDeveloperRole: false`, `thinkingFormat: "qwen-chat-template"`), and one
entry per discovered model carrying `contextWindow`, `maxTokens`, `reasoning`,
and `input`.

Then just run `pi`.

## Notes

- **compat is server-level.** `supportsDeveloperRole: false` and
  `thinkingFormat: "qwen-chat-template"` describe how SGLang wants thinking
  params sent, so they sit on the provider and apply to every model.
- If the thinking toggle errors on your server, the alternate `thinkingFormat`
  value is `qwen` (top-level `enable_thinking`) instead of `qwen-chat-template`
  (`chat_template_kwargs.enable_thinking`); which one depends on how SGLang was
  launched.
- Vision only works end-to-end if SGLang was started with the multimodal
  projector loaded. The script writes `input: ["text","image"]` when you answer
  yes, but a text-only server launch will still reject images.
