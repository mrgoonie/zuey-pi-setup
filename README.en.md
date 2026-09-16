<div align="center">

# zuey-pi-setup

**A portable snapshot of my [`pi`](https://github.com/earendil-works/pi) setup — clone it and rebuild the full set of 22 extensions on a new machine.**

pi `0.85.1` · Node `24` · macOS · Linux · Windows (Git Bash) · updated 2026-09-16

[Tiếng Việt](./README.md) · **English**

</div>

---

## Why this repo exists

`pi` has no config export/import. This repo is a deterministic way to carry the **entire setup** to another machine without copying caches:

- `~/.pi/agent/npm/` (~250 MB) — **not needed**, pi reinstalls it from `settings.json`
- `~/.pi/agent/auth.json` — **not committed** (API keys + OAuth tokens), log in again on the new machine
- `~/.pi/agent/sessions/` (~56 MB) and `missions/` — **not committed** (history/state, may contain internal data)

The mechanism: `settings.json` holds a `packages` array; pi reads it on startup and `npm install`s anything missing. So if you can carry the manifest, you carry the whole extension set.

---

## Quickstart (new machine)

```bash
# 1) install pi, exact version
npm i -g @earendil-works/pi-coding-agent@0.85.1

# 2) clone
git clone https://github.com/mrgoonie/zuey-pi-setup.git
cd zuey-pi-setup

# 3) safe rehearsal into a temp dir (touches nothing real)
./scripts/pi-setup-restore.sh --from-config config --scratch --install --verify

# 4) the real thing
./scripts/pi-setup-restore.sh --install --verify
```

Then log the providers back in (auth is not in the repo):

```bash
pi auth check --provider opencode-go    # and /login inside pi for each provider
```

One more manual step: `@injaneity/pi-computer-use` needs macOS **Accessibility** and **Screen Recording** granted to `~/Applications/pi-computer-use.app` (it installs the helper itself). Run pi interactively once and finish the setup prompt — in print mode the extension stays inert.

Full details, copy/do-not-copy table, troubleshooting: **[`docs/pi-setup-migration.md`](./docs/pi-setup-migration.md)** (Vietnamese only).

> **Windows:** the scripts are **bash** → run them in **Git Bash** (or WSL), **not** PowerShell/cmd. See [Windows (Git Bash)](#windows-git-bash).

---

## Windows (Git Bash)

Verified end-to-end on **Windows 11 + Git Bash (MSYS2, bash 5.3)**: restore → `--install` → `--verify` → backup → bundle rebuild. No extra steps beyond the Quickstart commands.

| Windows difference | Status |
|---|---|
| Shell | **Git Bash** (or WSL) is required. The scripts use POSIX bash plus MSYS `tar`/`gzip`/`find`/`awk` |
| Installing Node | Usually via [`fnm`](https://github.com/Schniz/fnm) instead of `nvm`. `pi` installs globally **per Node version** → `pi` only exists in a shell that ran `fnm use` (path looks like `.../fnm_multishells/<id>/pi`) |
| Counting packages (`--verify`) | Uses **`node`** (as of this revision), not `python3` — Windows often lacks `python3`, or hits the Microsoft Store stub |
| `shasum` | Absent in Git Bash → the script falls back to `sha256sum` |
| Paths passed to the child `pi` | MSYS converts `PI_CODING_AGENT_DIR` automatically (`/c/Users/...`, `/tmp/...` → `C:/Users/...`) — verified |
| `--scratch` | Works: `mktemp -d` plus path conversion for the child `pi` process |
| CRLF | Git Bash's bash **tolerates CRLF** (tested with a CRLF copy). `.gitattributes` still pins `*.sh text eol=lf` for safety |
| Symlinks | Creating them needs Developer Mode, but the repo only **reads/backs up** existing symlinks, so it does not matter |
| `tar` | Inside Git Bash this is GNU tar (`/usr/bin/tar`), not `C:\Windows\System32\tar.exe` |
| Terminal font | A **Nerd Font** is required while `iconMode: "nerd"` — see [Terminal font](#terminal-font-nerd-font-required) |

The full Windows sequence:

```bash
# inside Git Bash
fnm use 24
npm i -g @earendil-works/pi-coding-agent@0.85.1
git clone https://github.com/mrgoonie/zuey-pi-setup.git && cd zuey-pi-setup
./scripts/pi-setup-restore.sh --from-config config --scratch --install --verify   # rehearsal
./scripts/pi-setup-restore.sh --install --verify                                 # for real
```

---

## Screenshots

The statusline is laid out in exactly three rows — context bar scaled to the model's context window, token speed, git, cost, and other extensions' statuses pulled onto the same rows:

**Light theme** (thinking `high`) — `cache-hit-rate` and `cache_ttl` are 0 here, so they hide themselves:

![pi inside the zuey-pi worktree, 3-row statusline, light theme](./screenshots/pi-statusline-3-rows-light.webp)

**Dark theme** (thinking `off`) — all five widgets on row 2, including `cache-hit-rate` 79.8% and `cache_ttl` ~1s:

![pi with the 3-row statusline, dark theme](./screenshots/pi-statusline-3-rows-dark.webp)

<sub>Cropped from CleanShot and compressed as **WebP q90**: 1078×626 / 40 KB and 1076×624 / 38 KB — **94%** smaller than the original PNGs (696 KB). Unprocessed originals live in `screenshots/originals/` (gitignored).</sub>

---

## What's in the repo

```
zuey-pi-setup/
├── README.md                        Vietnamese README
├── README.en.md                     ← you are reading this
├── .gitattributes                   keeps *.sh at LF (Windows-friendly)
├── docs/
│   └── pi-setup-migration.md        detailed guide + verification data (Vietnamese)
├── fonts/                           JetBrains Mono 1.0.2 (terminal font, OFL-1.1)
│   ├── README.md                    provenance, install steps, Nerd Font warning
│   ├── LICENSE.txt                  SIL Open Font License 1.1
│   └── JetBrainsMono-1.0.2/         ttf/ (1 MB, for terminals) + web/ (2 MB, for the web)
├── screenshots/                     statusline images used in the README (WebP, ~40 KB each)
│   └── originals/                   unprocessed CleanShot originals (gitignored)
├── scripts/
│   ├── pi-setup-backup.sh           packages the current machine's setup
│   ├── pi-setup-restore.sh          rebuilds that setup on a new machine
│   └── pi-setup-verify-advisor.mjs  validates advisor.json against pi-advisor-flow's real schema
├── backups/
│   └── pi-setup-portable.tar.gz     ready-to-download bundle (filtered — see below)
└── config/                          setup snapshot (plain files, git-diffable)
    ├── .pi-setup-exclude           exclusion globs — backup honours this file
    ├── settings.json               manifest of 22 packages + model/theme/compaction
    ├── advisor.json                pi-advisor-flow config (at the config-dir root)
    ├── 99extensions.json           99percentpeople family config (todo namespace)
    ├── pi-lens-config.json          pi-lens config — lives in ~/.pi-lens/, OUTSIDE the config dir
    ├── external-configs.txt        manifest: which file goes where on restore
    ├── APPEND_SYSTEM.md            extra system prompt
    ├── models-store.json           model catalog (saves the 4h refresh wait)
    ├── model-fallback/
    │   └── config.json            pi-model-fallback rules (state.json is not taken)
    └── extensions/                 locally written extensions, not on npm
        ├── pi-footer-cache-tps.ts  pushes cache-TTL + token speed (t/s) into pi-footer
        └── pi-footer.json          statusline layout (includes the context bar)
```

`config/` is a **mirror** of the setup portion of `~/.pi/agent`. Everything else (cache, secrets, history) is **not** included.

### Not in the repo (generated by other tools, reinstallable)

| Excluded | Generated by | Why |
|---|---|---|
| `extensions/orca-*.ts` (3 files, 1,239 lines) | Orca (`@orca-managed-pi-extension`) | Orca integration glue; Orca regenerates it when it manages pi |
| `extensions/agentkit-agent/`, `extensions/agentkit-hooks-engineer/` | AgentKit (`ak`) | 1.2 MB of generated hooks plus caches holding **absolute paths** (`native-skill-paths.json`, 157 KB); `ak` reinstalls them |
| `missions/`, `memory/`, `skills/` | pi / AgentKit | machine-specific state, not setup |

### `.pi-setup-exclude`

`scripts/pi-setup-backup.sh --config-dir config` reads this file (one glob per line, `#` for comments) and deletes every match after mirroring. That is why re-running the backup never drags `orca-*`/`agentkit-*` back into the repo:

```bash
./scripts/pi-setup-backup.sh --config-dir config   # → "excluded: 82 files matched .pi-setup-exclude"
```

The same file also works for **tarball mode** via `--exclude-file`:

```bash
./scripts/pi-setup-backup.sh -o backups/pi-setup-portable.tar.gz \
  --exclude-file config/.pi-setup-exclude
```

### A config that cannot be backed up: `@pi-unipi/notify`

`~/.unipi/config/notify/config.json` contains a **Gotify token** and **Telegram botToken + chatId**, so it is **deliberately absent** from `EXTERNAL_CONFIGS` — committing it would leak credentials to a public repo. Set it up again on the new machine:

```bash
/unipi:notify-set-gotify     # configure the Gotify server
/unipi:notify-set-tg         # configure the Telegram bot
/unipi:notify-settings       # everything else
```

The same warning is written directly in `scripts/pi-setup-backup.sh` so it is not accidentally added later.

### Config that lives outside the config dir

A few extensions keep config **outside** `~/.pi/agent/`, so it cannot be collected by relative path. The script has a separate list for them:

```bash
# in scripts/pi-setup-backup.sh
EXTERNAL_CONFIGS=(
	"~/.pi-lens/config.json:pi-lens-config.json"
)
```

- Backup copies each existing file into the artifact under `<name>` (`pi-lens-config.json`), plus **`external-configs.txt`** — a manifest of `<name>=<~-style path>`.
- Restore reads that manifest and puts the file back where it belongs (`mkdir -p` as needed, snapshotting the old file as `*.bak.<timestamp>`).
- The manifest uses `~` rather than `/Users/...`, so the artifact never leaks machine paths.
- Adding another external config means adding one line to `EXTERNAL_CONFIGS`; restore needs no change.

> ⚠️ **Artifact names must not collide with pi-lens' config basenames:** `pi-lens.json`,
> `pi-lsp.json`, `.pi-lens.json`. pi-lens walks upward from **every** directory it resolves
> config for and matches the **exact basename**, so an artifact named `config/pi-lens.json`
> used to be read as a deprecated project config → 4 `PILENS_CFG_0003` warnings plus
> 2 `PILENS_CFG_0001` on every session inside this repo (and its `format`/`autofix` were
> applied as project settings). Renaming it to `pi-lens-config.json` fixed that; the script
> now has a `pi_lens_reserved_name` guard that warns if the old name ever comes back.

### `backups/pi-setup-portable.tar.gz`

A ready-made bundle so you don't have to clone and run the backup yourself: **9 files** — `settings.json` (22 packages), `APPEND_SYSTEM.md`, `models-store.json`, `advisor.json`, `pi-lens-config.json`, `external-configs.txt`, `extensions/pi-footer.json`, `extensions/pi-footer-cache-tps.ts`, and `model-fallback/config.json`.

It is the script's full default bundle, **filtered** through `.pi-setup-exclude` so machine-only material never reaches this public repo:

| Excluded | Why |
|---|---|
| `extensions/orca-*.ts` (3 files, 1,239 lines) | Orca-generated code — deliberately kept out of the public repo |
| `extensions/agentkit-*` (95 files) | Contains `native-skill-paths.json` + `native-skill-hashes.json` (**absolute paths**, a list of 107 skills) and `hooks/.logs/hook-log.jsonl` (activity log) |

Restoring this bundle yields the same file set as `config/` — all 22 extensions plus the statusline. It is a snapshot of this machine, so its `settings.json` can differ from `config/settings.json` in keys changed afterwards (e.g. default model, TUI mode). For an unfiltered bundle (keeping machine state) drop `--exclude-file`.

---

## The 22 extensions in this snapshot

| # | Package | Version | What it does |
|---|---|---|---|
| 1 | `pi-web-access` | 0.29.0 | web search, URL fetch, GitHub repo cloning, PDF reading, YouTube + local video understanding |
| 2 | `pi-mcp-adapter` | 2.34.0 | MCP (Model Context Protocol) adapter |
| 3 | `pi-subagents` | 0.68.0 | subagent delegation + scripted multi-agent workflows |
| 4 | `pi-goal-x` | 0.31.4 | `/goal`: goal planning, durable progress, an auditor that checks completion |
| 5 | `pi-background-tasks` | 2.5.0 | background shell tasks, read-only delegated agents, attested runs, Fusion workflows |
| 6 | `pi-model-fallback` | 0.4.0 | switches to a fallback model by **rule** (provider/model + HTTP status 429/5xx) on provider failure; durable state with cooldowns; configured through the `model_fallback_config` tool |
| 7 | `@narumitw/pi-usage` | 0.60.8 | account usage display + DeepSeek API balance |
| 8 | `pi-simplify` | 0.2.3 | reviews just-changed code for clarity, consistency, maintainability |
| 9 | `pi-footer` | 0.5.1 | multi-row, customisable statusline (used by this repo) |
| 10 | `pi-powerline-footer` | 0.17.1 | powerline-style status bar (currently **off** via `"extensions": []`) |
| 11 | `pi-memory` | 0.4.2 | memory + semantic search (qmd) over daily log / long-term / scratchpad |
| 12 | `pi-worktree` | 1.3.3 | git worktree management, isolated workspaces in one command |
| 13 | `@99percentpeople/pi-todo` | 1.2.7 | minimal atomic todo: removal by omission, state survives compaction, dependencies, read-only widget |
| 14 | `@juicesharp/rpiv-ask-user-question` | 2.10.1 | asks you through multiple-choice questionnaires instead of guessing |
| 15 | `@juicesharp/rpiv-btw` | 2.10.1 | `/btw`: quick one-off question answered by the main model without polluting the conversation |
| 16 | `@pi-unipi/notify` | 2.17.0 | notifications when an agent finishes or fails: native OS, Gotify, Telegram, ntfy, routed per event type (⚠ config holds credentials — never backed up) |
| 17 | `pi-smart-fetch` | 0.3.17 **(pinned)** | `web_fetch` with a desktop-browser TLS fingerprint + defuddle content extraction |
| 18 | `pi-advisor-flow` | 0.6.0 | Executor/Advisor flow: a second opinion from a stronger model, with review gates before planning / after repeated failures / before declaring done |
| 19 | `@tmustier/pi-session-recap` | 0.5.0 | "while you were away" recap: drafts a short summary when you leave a session and shows it at the end of the transcript / above the editor when you return. Built for many parallel agents |
| 20 | `pi-lens` | 4.1.6 | LSP diagnostics + navigation, linters/type-checkers, formatter, ast-grep/tree-sitter, `symbol_search`, read-guard, `/lens-map`. In this setup the widget, autoformat and autofix are disabled (see its section) |
| 21 | `pi-browser-use` | 0.11.7 | agent browser via `chrome-devtools-mcp` (not Playwright): Pi's own headless Chrome on a dedicated `~/.pi/browser-profile` (log in once with `browser_setup`), isolated `fresh` mode, `browser_*` tools plus the bundled `browser-policy` skill. Needs Node ≥ 24 and Chrome stable. Run `browser_doctor` for self-diagnostics |
| 22 | `@injaneity/pi-computer-use` | 0.5.1 | lets an agent drive desktop apps on macOS, Windows and Linux through the platform accessibility APIs: `find_roots`, `observe_ui`, `search_ui`, `expand_ui`, `inspect_ui`, `act_ui`, `read_text`, `wait_for`. Ships a per-user helper at `~/Applications/pi-computer-use.app`; macOS needs **Accessibility** + **Screen Recording** granted to it, and the one-time setup flow requires an interactive Pi session, so nothing works in `-p` print mode until you grant them |

> Versions are **for reference at snapshot time**; the source of truth is `config/settings.json`. Only `pi-smart-fetch` is hard-pinned, the rest float → a new machine pulls the latest. Pin them in `config/settings.json` if you need an exact match.

Default provider: `opencode-go/deepseek-v4.1-flash` (thinking `high`). Enabled models: see `enabledModels` in `config/settings.json`.

---

## Statusline: context bar (0–100%)

The statusline is `pi-footer`, configured in `config/extensions/pi-footer.json`. This repo enables the **`context-bar`** widget — a progress bar scaled to **each model's own context window** (not a fixed number):

```json
{
  "type": "context-bar",
  "options": {
    "contextBarMode": "medium",
    "contextConditionalColors": true,
    "hideWhenZero": true
  }
}
```

Real output (calling the widget's `render()` directly, 200k context window):

```
   0%  [░░░░░░░░░░░░░░░░] 0/200k (0%)        fg=blue
  25%  [████░░░░░░░░░░░░] 50k/200k (25%)      fg=blue
  71%  [███████████░░░░░] 142k/200k (71%)     fg=yellow   ← ≥ 70%
  92%  [███████████████░] 184k/200k (92%)     fg=red      ← ≥ 90%
```

Other models scale differently — a 1M context at 25% renders `[████░░░░░░░░░░░░] 250k/1m (25%)`. When the context length is unknown it prints `?`.

| Want to change | Edit in `pi-footer.json` |
|---|---|
| Bar width / style | `contextBarMode`: `default` (32 cells, bracketed) · `medium` (16 cells, used here) · `short` (10 cells) · `short-only` (10 cells, no numbers) |
| Percentage-based colours | `contextConditionalColors` (thresholds `contextWarningPercent` 70, `contextDangerPercent` 90) |
| Raw tokens instead of a bar | change `"type": "context-bar"` → `"context-length"`, or use `"context-remaining"` / `"context-window"` |

Today's row 2: `context-bar` → `cache-hit-rate` → 2 event widgets (`cache_ttl`, `tps`, pushed in by `pi-footer-cache-tps.ts`).

### 3-row layout

The statusline is arranged in **exactly three rows**, dropping no widget:

| Row | Content | Width |
|---|---|---|
| 1 | `cwd` · `model-provider` · `thinking-level` | 71 |
| 2 | `context-bar` · `cache-hit-rate` · `cache_ttl` · `tps` · `total-time` | 80 |
| 3 | `git-branch` · `git-diff` · `cost` · `mcp` · `background-tasks` · `goal` · `usage` | 84 |

**Why it used to be four rows:** pi-footer renders the `lines` you configured **plus one extra row** (`extensionStatusRow`) holding statuses published by other extensions through `ctx.ui.setStatus` (`mcp`, `goal`, `background-tasks`, `usage`). That row is hidden with `extensionStatusRow.hiddenKeys` and the statuses move onto row 3 as `external-status` widgets.

> ⚠️ `hiddenKeys` is an **exact** key list, no wildcards. If another extension publishes a new status later, the fourth row comes back — add that key to `hiddenKeys` (or use `/footer`). Keys currently covered (13): `advisor-scout`, `advisor-usage`, `background-tasks`, `goal`, `mcp`, `mcp-auth`, `pi-lens-lsp`, `session-recap`, `stash`, `subagent-slash`, `subagent-slash-text`, `usage`, `worktree`.

**Width budget:** total content is **243 characters** (201 of widgets + 42 of separators) → across 3 rows the longest row **must be ≥ 81**. The current layout needs a terminal **≥ 85 columns**; narrower and the tail is truncated with `…`. To fit an 80-column terminal, shrink it: `cwd` → `segments: 2` (−8) and `model-provider` → `model` (−11) ⇒ longest row drops to ~65.

> ⚠️ The config uses `"iconMode": "nerd"`, so the terminal needs a **Nerd Font** (patched build) for the icons to render. `fonts/` ships **unpatched** JetBrains Mono — installing that one and pointing your terminal at it is exactly how you get **broken icons**: see [Terminal font](#terminal-font-nerd-font-required).

Real screenshot of this layout: see [Screenshots](#screenshots).

### Terminal font: Nerd Font required

**This is not a minor detail.** Every statusline icon is a Nerd Fonts **Private Use Area** codepoint:

| Widget | Codepoint | JetBrains Mono (unpatched) | DankMono Nerd Font Mono | FantasqueSansMono NF Mono |
|---|---|---|---|---|
| `cwd` | U+F07C | ❌ missing | ✅ | ✅ |
| `model-provider` | U+F06A9 | ❌ missing | ✅ | ❌ missing |
| `thinking-level` | U+F0208 | ❌ missing | ✅ | ❌ missing |
| `context-bar` | U+F035B | ❌ missing | ✅ | ❌ missing |
| `cache-hit-rate` | U+F04CE | ❌ missing | ✅ | ❌ missing |
| `total-time` | U+F13AB | ❌ missing | ✅ | ❌ missing |
| `git-branch` | U+E725 | ❌ missing | ✅ | ✅ |
| `git-diff` | U+E702 | ❌ missing | ✅ | ✅ |
| `cost` | U+F04A3 | ❌ missing | ✅ | ❌ missing |
| `cache_ttl`, `tps` (events) | U+F01BC, U+EAF3 | ❌ missing | ✅ | ❌ missing |

Unpatched JetBrains Mono (the build in `fonts/`) is missing **11/11**. When a glyph is missing the terminal does **not** leave the cell blank — it falls back to another font that has that codepoint, so icons render as **meaningless shapes** (a diamond ◆, a star ✦, or a `?`) rather than a config error.

**Fix — pick one:**

**A. Give the terminal a Nerd Font** (keeps the proper icons; recommended). The **Mono** (single-width) variant is required for TUIs — non-Mono builds draw two-cell-wide icons and break column alignment.

```bash
# macOS
brew install --cask font-jetbrains-mono-nerd-font     # or font-dank-mono-nerd-font
```

```powershell
# Windows: install per-user (copy the file AND register it), or select the .otf/.ttf → right-click → Install
$dst = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
Copy-Item .\DankMonoNerdFontMono-Regular.otf $dst
New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts" `
  -Name "DankMono Nerd Font Mono (TrueType)" -Value "$dst\DankMonoNerdFontMono-Regular.otf" -PropertyType String -Force
```

Then point the terminal at it. For Windows Terminal, edit `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json` and set it under `profiles.defaults` so **every** profile inherits it (a profile with its own `font` **overrides** defaults, so that profile must be edited too):

```json
"profiles": {
  "defaults": {
    "font": { "face": "DankMono Nerd Font Mono", "size": 12 }
  }
}
```

> Any profile that already defines `font` must have its own `face` changed. Windows Terminal hot-reloads `settings.json`, so back the file up before editing.

More on the bundled font — provenance, install steps for both platforms, license: [`fonts/README.md`](./fonts/README.md).

**B. Skip patched fonts entirely:** change `"iconMode": "nerd"` → `"emoji"` (renders 📁… via Segoe UI Emoji on Windows / Apple Color Emoji on macOS) or `"text"` (plain words, no icons). Trade-off: larger icons and a less compact statusline.

---

## pi-model-fallback

A rule-based model-fallback extension: when a provider returns an HTTP status matching a rule (by default `429`, `500`, `502`, `503`, `504`), pi switches to that rule's fallback model and persists **durable state** so later sessions keep using the new model until the cooldown expires (`429` → 72 hours, `5xx` → 10 minutes; `Retry-After` / `x-ratelimit-reset*` headers override when present). Rules match in order and the first match wins — so specific `matchModels` rules must come before broad `matchProviders` rules.

```bash
/model-fallback:status   # whether it is enabled, which durable entry is active, config/state paths
/model-fallback:reset    # clear durable state and return to the pre-fallback model
```

`autoRetry` (on by default) re-queues the failed prompt as a follow-up after the model switch; the failed request itself is not replayed.

Config lives at `~/.pi/agent/model-fallback/config.json` and is read/validated/written by the extension's `model_fallback_config` tool — there is **no TUI**, unlike `pi-provider-fallback` (removed from this snapshot). The package default is `zai/*` → `deepseek/deepseek-v4-flash`; this snapshot replaces it with a rule for the `deepseek` provider:

```json
{
  "version": 1,
  "enabled": true,
  "autoRetry": true,
  "rules": [
    {
      "name": "deepseek-to-deepseek-v4-flash",
      "matchProviders": ["deepseek"],
      "statuses": [429, 500, 502, 503, 504],
      "fallback": { "provider": "deepseek", "model": "deepseek-v4-flash" }
    }
  ]
}
```

> The notable difference from the previous extension: the config is **not** inside `extensions/` but in the same directory as `state.json`. So `scripts/pi-setup-backup.sh` lists `model-fallback/config.json` explicitly and **takes only the config file** — `state.json` is machine state and never ships; restore also writes only `config.json`.

---

## `pi-advisor-flow`

An **Executor / Advisor** flow: the model doing the work (Executor) can ask a stronger model (Advisor) for a second opinion. It has **automatic review gates** — before planning, after repeated failures, and before declaring completion — and can halt actions according to the policy you configure. Based on the paper *Steering Black-Box LLMs with Advisor Models*.

```bash
/advisor            # consult the Advisor (opens a model picker if unconfigured)
/advisor-models     # choose the Executor + Advisor models
/advisor-settings   # behaviour, context, privacy, limits
```

Global config is **`~/.pi/agent/advisor.json`** — at the **root** of the config dir, **not** inside `extensions/`, so backup has to list it separately (it does). A project can override it with `<project>/.pi/advisor.json`.

The extension also publishes 2 status keys (`advisor-scout`, `advisor-usage`) — both are in `hiddenKeys` and have inline widgets like the other 9, so the status row does not come back while the Advisor runs.

Its own state (`advisor-outcomes.jsonl`, `advisor-outcomes-salt`) is a per-machine log/salt → excluded via `.pi-setup-exclude`, never committed.

---

## `@tmustier/pi-session-recap`

A **“while you were away”** recap (in the spirit of Claude Code's away-summary): when you have genuinely stepped away from a session, the extension drafts a short summary — the main thing in flight first, then the concrete next step — and places it at the end of the transcript (in the TUI, above the editor) so you can read it the moment you return. Built for workflows with many agents across many tabs.

**No config or state files** — a purely stateless extension that reads/writes nothing under `~/.pi/agent/`, so nothing extra needs backing up.

It still publishes 1 status key (`session-recap`, showing `✦ drafting recap…` while drafting) → included in `hiddenKeys` with an inline widget, so the statusline does not jump to 4 rows while a recap is being written.

> With tmux you need `set -g focus-events on` in `~/.tmux.conf` followed by `tmux source-file ~/.tmux.conf` so the extension knows you came back.

---

## `pi-lens` (LSP)

LSP for pi. pi has no built-in LSP — no setting, no docs — so it has to be an extension. `pi-lens` was chosen because it has more features and is far more widely used (`@narumitw/pi-lsp` is LSP-only and ~9× less used), **and** because the thing that made me remove it earlier — it lists files on screen — can be switched off with **one config line**.

The annoying part is the **widget** (`setWidget("pi-lens", …)`, showing per-file findings above the editor), not the statusline. It has a `widget.visible` setting:

```json
// ~/.pi-lens/config.json  —  NOTE: lives in ~/.pi-lens/, NOT ~/.pi/agent/
{
  "lsp": { "enabled": true },
  "widget": { "visible": false },
  "format": { "enabled": false },
  "autofix": { "enabled": false }
}
```

`format` and `autofix` are set to **false** here because only LSP was requested — the package defaults them to `true`, meaning it formats and applies quickfixes to the code you edit. Set them back to `true` to re-enable (or use the CLI flags `--no-autofix` / `--no-autoformat` to disable, and `--lens-actionable-warnings --lens-actionable-warning-autofix` to enable extra warnings).

Statusline: the extension publishes the key `pi-lens-lsp` (values like `LSP Active: ts` / `LSP Inactive`) → in `hiddenKeys` with an inline widget, so you **can see whether LSP is running** while the statusline stays 3 rows.

Its config lives **outside** pi's config dir, which is why `scripts/pi-setup-backup.sh` has a dedicated mechanism for that group: see *Config that lives outside the config dir* above.

---

## Scripts

The two setup scripts **never ask for confirmation** — they are safe to run from scripts/CI. Risk is handled with snapshots plus warnings on `stderr`. The third script only **reads**.

### `pi-setup-verify-advisor.mjs`

`pi-advisor-flow` does not error on an unknown key in `advisor.json`: it keeps the key and only notifies `contains unrecognized key(s) ... They were preserved but ignored` — and that key has **no effect**. A misspelled key therefore looks configured while doing nothing.

This script extracts `CONFIG_SCHEMA` from the installed bundle and replays the two checks the extension runs while loading: `unknownConfigKeys()` (unknown key → ignored) and `validate*Values()` (wrong type / outside an enum).

```bash
node scripts/pi-setup-verify-advisor.mjs            # the file in this repo (config/advisor.json)
node scripts/pi-setup-verify-advisor.mjs --live     # + the live ~/.pi/agent/advisor.json, and compares the two
node scripts/pi-setup-verify-advisor.mjs --file <path>
```

| Exit | Meaning |
|---|---|
| `0` | clean |
| `1` | bad config: unknown key, wrong type, outside enum, unparsable JSON, missing file, repo snapshot diverged from the live file |
| `2` | environment problem: no `pi-advisor-flow` bundle, bundle changed format, bad arguments |

> Why it exists: I once wrote `advisorFailureMode` (taken from an internal variable name in the bundle) when the real key is `gateFailureMode` — the file looked right, did **nothing**, and the warning showed up much later. This script catches exactly that class of mistake.

### `pi-setup-backup.sh`

By default it takes only **setup**: `settings.json`, `APPEND_SYSTEM.md`, `models-store.json`, `model-fallback/config.json`, `extensions/` — and it **always includes the statusline** (`extensions/pi-footer.json` lives inside `extensions/`).

```bash
./scripts/pi-setup-backup.sh                       # → ./pi-setup-portable.tar.gz (setup only)
./scripts/pi-setup-backup.sh --config-dir config    # → update config/ inside this repo
./scripts/pi-setup-backup.sh --skills --hooks       # add skills + hooks
./scripts/pi-setup-backup.sh -o ~/Desktop/pi.tar.gz
./scripts/pi-setup-backup.sh --dry-run
```

| Opt-in (NOT included by default) | What it takes | Notes |
|---|---|---|
| `--auth` | `auth.json` | ⚠ **contains credentials** → never publish the artifact |
| `--skills` | `skills/` | **dereferences symlinks** → self-contained backup (~24 MB, 108 skills) |
| `--hooks` | `hooks/` dirs under `~/.pi/agent` | currently 544 KB. Does **not** touch `~/.claude/hooks` (that one holds `.env`). Overrides `.pi-setup-exclude` for hook paths |
| `--memory` | `memory/` | |
| `--missions` | `missions/` | ⚠ pi-goal-x state, may contain project/customer names |
| `--sessions` | `sessions/` | chat history (~56 MB) |
| `--with-state` | `--skills --memory --missions` | |

| Opt-out | Effect |
|---|---|
| `--no-statusline` | Does **not** back up the statusline config (`pi-footer.json`, `powerline-footer/theme.json`) — a new machine keeps the default layout |

The script also: writes to a temp file then `mv`s it (no corrupt artifact on interruption) · **scans for secrets** (`sk-*`, `ghp_*`, `xox*`, `BEGIN PRIVATE KEY` with a base64 body, `api_key=…`) · **warns about symlinks pointing outside** · **reports extension config** (whether statusline / model-fallback were backed up) · compresses deterministically (`gzip -n` → same content, same SHA-256) · refuses to write `--config-dir` into `$HOME`, `/`, or pi's own config dir.

> On secret scanning: the script ignores common placeholders (word-only values like `currentPassword`, `{CLIENT_SECRET}` forms, bare PEM headers, low-entropy strings like `ghp_aaaa…`). It can still flag **fixtures inside third-party package tests** (e.g. a Slack-token-shaped string in AgentKit's own tests) and **test strings you once pasted into chat** (with `--sessions`, since transcripts live under `sessions/`) — read the filenames before concluding.

### `pi-setup-restore.sh`

| Option | Effect |
|---|---|
| `--from-config DIR` | restore from `config/` (plain files) |
| `--bundle FILE` | restore from a `.tar.gz` |
| `--target DIR` | a target other than `~/.pi/agent` |
| `--scratch` | target a temp dir — **safe to rehearse** |
| `--install` | run pi headless once so it installs the extensions (~150–190 s) |
| `--verify` | compare installed extension count against `settings.json` |
| `--with-trust` | also copy `trust.json` |
| `--dry-run` | print only, write nothing |

Before overwriting, `settings.json` **and** `auth.json` (when present in the source) are snapshotted to `*.bak.<timestamp>`. The script sets `trap ERR`, so it never exits silently — it always prints the line number on unexpected errors.

---

## Verification

Tested by restoring into a **brand-new** config dir via `PI_CODING_AGENT_DIR`, never touching the real setup.

> ⚠️ Every number below was measured on the **20-package** payload. The current snapshot has **22 packages** (added `pi-browser-use` and `@injaneity/pi-computer-use`) and has **not been re-measured**.

| Check | Result |
|---|---|
| First install time | **136–246 s** across real runs (npm-speed dependent; 335 s with a cold npm cache) |
| Module dirs in `npm/node_modules` | **0 → 203** (20-package snapshot) |
| `--verify` | **20/20** on the latest run (pi-lens + pi-todo + notify), **19/19 · 18/18 · 17/17 · 16/16** on earlier snapshots |
| Extensions **actually running** (not just installed) | ✅ 18 `extension_ui_request`, 0 load errors, surfaces for `subagent-async`, `mcp`, `goal`, `background-tasks`, `usage`, `pi-footer`, `advisor-scout`, `advisor-usage`, `pi-lens-lsp` |
| Config **outside** the config dir restored | ✅ written to `~/.pi-lens/config.json` (old file snapshotted first) |
| Restore from the **new bundle** into a fake `HOME` | ✅ 9 files, external config written to the right place, contents match `config/pi-lens-config.json` |
| pi-lens legacy-basename collision | ✅ `config/pi-lens.json` → `pi-lens-config.json`: repro with cwd=`config/` went **6 → 12** `PILENS_CFG_0003/0001` warnings before the fix, **delta 0** after, resolution `documents=1 legacy=0 records=0` |
| Clone the public repo and restore | ✅ 11 files, 0 excluded, 153 s, verify matched, 0 errors |
| `auth.json` in the new dir | `{}` → no secret leakage |
| Second run | empty log → idempotent |
| Two consecutive backups | **byte-identical** (deterministic) |
| `context-bar` rendering | ✅ direct `render()` call: 0/25/**71%→yellow**/**92%→red**/100%, correctly scaled for 200k and 1M |
| `--no-statusline` | ✅ `pi-footer.json` disappears from the bundle (different SHA than the default) |
| `--hooks` + `.pi-setup-exclude` | ✅ hooks survive, "override" warning printed, 54 files remain |
| `--auth` on restore | ✅ `auth.json.bak.<ts>` preserves the old credentials before overwriting |

### Windows 11 + Git Bash (MSYS2, bash 5.3) — measured on the 20-package payload

| Check | Result |
|---|---|
| Real restore (`--from-config config --install --verify`) | ✅ **20/20**, install **88 s**, module dirs `0 → 203` |
| `pi list` in the restored dir | ✅ 20 packages |
| Config **outside** the config dir | ✅ written to `%USERPROFILE%\.pi-lens\config.json`, matching `config/pi-lens-config.json` |
| Restore from a bundle into a fake `HOME` | ✅ 9 files, external config written correctly |
| MSYS path conversion for child `pi` | ✅ `PI_CODING_AGENT_DIR=/tmp/...` → `C:/Users/.../Temp/...` |
| Bundle rebuilt on Windows | ✅ 9 files, 7.9 KB, clean (no `._*` AppleDouble junk like the macOS-built one) |
| Package counting without `python3` | ✅ `node -e` → `20` |
| CRLF in scripts | ✅ bash 5.3.15 tolerates CRLF (tested with a CRLF copy, exit 0) |

### Verify script (`advisor.json`)

| Check | Result |
|---|---|
| Config matrix (real runs, exit codes compared) | ✅ **6/6**: clean config `0` · unknown key `1` · outside enum `1` · wrong type `1` · ref missing `provider/model` `1` · missing `gateFailureMode` still `0` |
| Environment branches | ✅ **7/7**: `--live` compares both files `0` · missing `--pkg` `2` · bundle without `CONFIG_SCHEMA` `2` · `--help` `0` · bad argument `2` · unparsable JSON `1` · missing file `1` |
| Schema extraction | ✅ **31 keys** from the 0.6.0 bundle's `CONFIG_SCHEMA`; reproduces the exact `advisorFailureMode` notice the extension emitted (harness matched real output) |

---

## Known limitations

- **`auth.json` is not in the repo** (secret) → `/login` again on the new machine.
- **`sessions/` and `missions/` are not in the repo** → chat/mission history is not migrated. Use `--sessions` / `--missions` to back them up yourself.
- **2 skills are symlinks into AgentKit** (`skills/orchestration`, `skills/orca-per-workspace-env`) → they only work if the new machine has [AgentKit](https://github.com/bestagentkits) installed. Broken symlinks there affect **no** other extension (tested). Use `--skills` to back up the real content.
- **3 `orca-*.ts` extensions** and **2 `agentkit-*` directories** are not in the repo → Orca/AgentKit regenerate them.
- **`pi-model-fallback` config** lives at `~/.pi/agent/model-fallback/config.json` — the **same directory** as `state.json`, and `state.json` is machine state (entries + cooldown deadlines) so it is **not** backed up. The script lists the config file explicitly. Without that file the extension runs on the package default (`zai` → `deepseek/deepseek-v4-flash`).
- **`pi-advisor-flow` config** (`~/.pi/agent/advisor.json`, at the config-dir **root** rather than inside `extensions/`) only exists after running `/advisor` or `/advisor-settings`. Backup lists that file explicitly, so it is included automatically once it appears.
- **The scripts need a POSIX shell** → on Windows run them in **Git Bash** or **WSL**; PowerShell/cmd cannot run them.
- **Statusline icons need a Nerd Font** → using the unpatched JetBrains Mono from `fonts/` breaks icons into ◆/✦/`?`; see [Terminal font](#terminal-font-nerd-font-required).
- **`pi` installs globally per Node version** → `nvm use` / `fnm use` to a different version can make the `pi` command disappear; reinstall it globally for that version.

---

## Personal repo

This is a snapshot of one person's setup at a point in time — **not an official product** of pi or of any package listed here. No license is included: all rights belong to the author; third-party extensions remain under their own licenses.
