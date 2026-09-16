<div align="center">

# zuey-pi-setup

**Portable snapshot của setup [`pi`](https://github.com/earendil-works/pi) — clone về là dựng lại nguyên bộ 22 extensions trên máy mới.**

pi `0.85.1` · Node `24` · macOS · Linux · Windows (Git Bash) · cập nhật 2026-09-16

**Tiếng Việt** · [English](./README.en.md)

</div>

---

## Vì sao có repo này

`pi` không có tính năng export/import config. Repo này là cách mang **toàn bộ setup** sang máy khác một cách xác định (deterministic) và không cần copy cache:

- `~/.pi/agent/npm/` (~250 MB) — **không cần**, pi tự cài lại từ `settings.json`
- `~/.pi/agent/auth.json` — **không đưa vào repo** (chứa API key + OAuth token), login lại ở máy mới
- `~/.pi/agent/sessions/` (~56 MB) và `missions/` — **không đưa vào repo** (history/state, và có thể chứa dữ liệu nội bộ)

Cơ chế: `settings.json` chứa mảng `packages`; pi đọc nó lúc khởi động và `npm install` mọi package còn thiếu. Nên mang được manifest = mang được cả bộ extension.

---

## Quickstart (máy mới)

```bash
# 1) cài pi, đúng version
npm i -g @earendil-works/pi-coding-agent@0.85.1

# 2) clone
git clone https://github.com/mrgoonie/zuey-pi-setup.git
cd zuey-pi-setup

# 3) thử an toàn vào thư mục tạm (không đụng config thật)
./scripts/pi-setup-restore.sh --from-config config --scratch --install --verify

# 4) làm thật
./scripts/pi-setup-restore.sh --install --verify
```

Sau đó login lại provider (auth không nằm trong repo):

```bash
pi auth check --provider opencode-go    # và /login trong pi cho từng provider
```

Thêm 1 bước tay: `@injaneity/pi-computer-use` cần cấp **Accessibility** và **Screen Recording** cho `~/Applications/pi-computer-use.app` (helper được cài tự động). Mở pi ở chế độ tương tác 1 lần và làm hết prompt setup — ở chế độ print, extension không hoạt động.

Chi tiết đầy đủ, bảng copy/không-copy, xử lý sự cố: **[`docs/pi-setup-migration.md`](./docs/pi-setup-migration.md)**.

> **Windows:** script là **bash** → chạy trong **Git Bash** (hoặc WSL), **không** chạy bằng PowerShell/cmd. Xem [Windows (Git Bash)](#windows-git-bash).

---

## Windows (Git Bash)

Đã chạy thật end-to-end trên **Windows 11 + Git Bash (MSYS2, bash 5.3)**: restore → `--install` → `--verify` → backup → tạo lại bundle. Không cần sửa gì thêm ngoài các lệnh ở Quickstart.

| Khác biệt trên Windows | Trạng thái |
|---|---|
| Shell | Bắt buộc **Git Bash** (hoặc WSL). Script dùng POSIX bash + `tar`/`gzip`/`find`/`awk`… của MSYS |
| Cài Node | Thường qua [`fnm`](https://github.com/Schniz/fnm) thay vì `nvm`. `pi` cài global **theo từng Node version** → `pi` chỉ có trong shell đã `fnm use` (đường dẫn kiểu `.../fnm_multishells/<id>/pi`) |
| Đếm package (`--verify`) | Dùng **`node`** (từ bản này), không dùng `python3` — Windows hay thiếu `python3` hoặc gặp stub Microsoft Store |
| `shasum` | Git Bash không có → script tự fallback sang `sha256sum` |
| Đường dẫn truyền cho `pi` con | MSYS tự convert (`/c/Users/...` và `/tmp/...` → `C:/Users/...`) — đã kiểm chứng với `PI_CODING_AGENT_DIR` |
| `--scratch` | Chạy được: `mktemp -d` + convert path cho tiến trình `pi` con |
| CRLF | bash của Git Bash **chịu được CRLF** (đã test bằng bản copy CRLF). `.gitattributes` vẫn có `*.sh text eol=lf` để chắc ăn |
| Symlink | Tạo symlink cần Developer Mode, nhưng repo chỉ **đọc/backup** symlink có sẵn nên không cần |
| `tar` | Trong Git Bash dùng GNU tar (`/usr/bin/tar`), không phải `C:\Windows\System32\tar.exe` |
| Font terminal | **Cần Nerd Font** nếu để `iconMode: "nerd"` — xem [Font terminal](#font-terminal-bắt-buộc-nerd-font) |

Ví dụ đầy đủ trên Windows:

```bash
# trong Git Bash
fnm use 24
npm i -g @earendil-works/pi-coding-agent@0.85.1
git clone https://github.com/mrgoonie/zuey-pi-setup.git && cd zuey-pi-setup
./scripts/pi-setup-restore.sh --from-config config --scratch --install --verify   # thử an toàn
./scripts/pi-setup-restore.sh --install --verify                                 # làm thật
```

---

## Screenshots

Statusline được xếp đúng 3 hàng — context bar theo context window của model, tốc độ token, git, chi phí, và status của các extension khác được đưa vào cùng hàng:

**Theme sáng** (thinking `high`) — lúc này `cache-hit-rate` và `cache_ttl` bằng 0 nên tự ẩn:

![pi trong worktree zuey-pi với statusline 3 hàng, theme sáng](./screenshots/pi-statusline-3-rows-light.webp)

**Theme tối** (thinking `off`) — đủ 5 widget hàng 2, gồm `cache-hit-rate` 79.8% và `cache_ttl` ~1s:

![pi với statusline 3 hàng, theme tối](./screenshots/pi-statusline-3-rows-dark.webp)

<sub>Ảnh crop từ CleanShot rồi nén **WebP q90**: 1078×626 / 40 KB và 1076×624 / 38 KB — giảm **94%** so với PNG gốc (696 KB). Bản gốc chưa xử lý để ở `screenshots/originals/` (đã gitignore).</sub>

---

## Repo có gì

```
zuey-pi-setup/
├── README.md                        ← bạn đang đọc
├── docs/
│   └── pi-setup-migration.md        hướng dẫn chi tiết + số liệu kiểm chứng
├── fonts/                           JetBrains Mono 1.0.2 (font terminal, OFL-1.1)
│   ├── README.md                    nguồn gốc, cách cài, cảnh báo Nerd Font
│   ├── LICENSE.txt                  SIL Open Font License 1.1
│   └── JetBrainsMono-1.0.2/         ttf/ (1 MB, dùng cho terminal) + web/ (2 MB, cho web)
├── screenshots/                     ảnh statusline dùng trong README (WebP, ~40 KB/ảnh)
│   └── originals/                   bản gốc CleanShot chưa xử lý (gitignore)
├── scripts/
│   ├── pi-setup-backup.sh           đóng gói setup hiện tại của máy đang chạy
│   ├── pi-setup-restore.sh          dựng lại setup trên máy mới
│   ├── pi-setup-verify-advisor.mjs  kiểm tra advisor.json theo schema thật của pi-advisor-flow
│   └── pi-lens-compact-lsp-status.mjs  vá pi-lens: dòng status LSP gọn (`LSP ✓` / `LSP ✗`)
├── backups/
│   └── pi-setup-portable.tar.gz     bundle sẵn để tải (đã lọc — xem bên dưới)
└── config/                          snapshot setup (plain file, diff được bằng git)
    ├── .pi-setup-exclude           glob loại trừ — backup tôn trọng file này
    ├── settings.json               manifest 22 packages + model/theme/compaction
    ├── advisor.json                config pi-advisor-flow (ở gốc config dir)
    ├── 99extensions.json           config họ 99percentpeople (namespace todo)
    ├── pi-lens-config.json          config pi-lens — nằm ở ~/.pi-lens/ NGOÀI config dir
    ├── external-configs.txt        manifest: file nào đặt về đâu khi restore
    ├── APPEND_SYSTEM.md            system prompt phụ
    ├── models-store.json           catalog model (khỏi chờ refresh 4h)
    ├── model-fallback/
    │   └── config.json            rule fallback của pi-model-fallback (state.json không lấy)
    └── extensions/                 extension tự viết, không có trên npm
        ├── pi-footer-cache-tps.ts  đẩy cache-TTL + tốc độ token (t/s) vào pi-footer
        └── pi-footer.json          layout statusline (gồm context bar)
```

`config/` là **mirror** của phần setup trong `~/.pi/agent`. Mọi thứ khác (cache, secret, history) **không** được đưa vào.

### Không nằm trong repo (do công cụ khác sinh, tự cài lại được)

| Bị loại | Do ai sinh | Vì sao loại |
|---|---|---|
| `extensions/orca-*.ts` (3 file, 1 239 dòng) | Orca (`@orca-managed-pi-extension`) | glue code tích hợp Orca; Orca tự sinh lại khi quản lý pi |
| `extensions/agentkit-agent/`, `extensions/agentkit-hooks-engineer/` | AgentKit (`ak`) | 1.2 MB hook đã sinh + cache chứa **path tuyệt đối** (`native-skill-paths.json` 157 KB); `ak` tự cài lại |
| `missions/`, `memory/`, `skills/` | pi / AgentKit | state theo máy, không phải setup |

### `.pi-setup-exclude`

`scripts/pi-setup-backup.sh --config-dir config` đọc file này (mỗi dòng 1 glob, `#` = comment) và xoá mọi file khớp sau khi mirror. Nhờ vậy chạy backup lại cũng không tự thêm `orca-*`/`agentkit-*` trở lại repo:

```bash
./scripts/pi-setup-backup.sh --config-dir config   # → "loại trừ: 82 file khớp .pi-setup-exclude"
```

Từ bản hiện tại, cùng file đó cũng dùng được cho **chế độ tarball** qua `--exclude-file`:

```bash
./scripts/pi-setup-backup.sh -o backups/pi-setup-portable.tar.gz \
  --exclude-file config/.pi-setup-exclude
```

### Config KHÔNG backup được: `@pi-unipi/notify`

`~/.unipi/config/notify/config.json` chứa **token Gotify** và **botToken + chatId Telegram**, nên **cố ý không nằm** trong `EXTERNAL_CONFIGS` — đưa vào là lộ credential lên repo public. Trên máy mới phải thiết lập lại:

```bash
/unipi:notify-set-gotify     # cấu hình server Gotify
/unipi:notify-set-tg         # cấu hình bot Telegram
/unipi:notify-settings       # các tuỳ chọn còn lại
```

Cảnh báo này cũng ghi thẳng trong `scripts/pi-setup-backup.sh` để lần sau không vô tình thêm vào.

### Config nằm ngoài config dir

Vài extension để config **bên ngoài** `~/.pi/agent/`, nên không thể lấy theo đường dẫn tương đối. Script có danh sách riêng cho nhóm này:

```bash
# trong scripts/pi-setup-backup.sh
EXTERNAL_CONFIGS=(
	"~/.pi-lens/config.json:pi-lens-config.json"
)
```

- Backup copy mỗi file còn tồn tại vào artifact dưới tên `<tên>` (`pi-lens-config.json`), kèm **`external-configs.txt`** — manifest ghi `<tên>=<đường dẫn dạng ~>`.
- Restore đọc manifest đó rồi đặt file về đúng chỗ (tự `mkdir -p`, tự snapshot bản cũ thành `*.bak.<timestamp>`).
- Manifest dùng dạng `~` chứ không phải `/Users/...` nên artifact vẫn không lộ path của máy.
- Thêm config ngoài mới = thêm 1 dòng vào `EXTERNAL_CONFIGS`; không phải sửa restore.

> ⚠️ **Tên artifact không được trùng basename config của `pi-lens`:** `pi-lens.json`,
> `pi-lsp.json`, `.pi-lens.json`. pi-lens walk ngược lên từ **mỗi** thư mục nó resolve
> config và khớp **đúng basename**, nên artifact `config/pi-lens.json` từng bị đọc như
> project config deprecated → 4 warning `PILENS_CFG_0003` + 2 `PILENS_CFG_0001` mỗi lần
> làm việc trong repo (và `format`/`autofix` của nó bị áp như project setting). Đổi tên
> thành `pi-lens-config.json` là hết; script có guard `pi_lens_reserved_name` cảnh báo nếu
> sau này ai thêm lại tên cũ.

### `backups/pi-setup-portable.tar.gz`

Bundle sẵn để tải, khỏi phải clone rồi tự tạo: **9 file** — `settings.json` (22 package), `APPEND_SYSTEM.md`, `models-store.json`, `advisor.json`, `pi-lens-config.json`, `external-configs.txt`, `extensions/pi-footer.json`, `extensions/pi-footer-cache-tps.ts` và `model-fallback/config.json`.

Đây là bundle đầy đủ theo mặc định của script, **đã lọc** qua `.pi-setup-exclude` để không mang lên repo public những thứ chỉ thuộc về máy:

| Bị loại | Vì sao |
|---|---|
| `extensions/orca-*.ts` (3 file, 1 239 dòng) | code do Orca sinh — bạn đã chọn không đưa lên public |
| `extensions/agentkit-*` (95 file) | chứa `native-skill-paths.json` + `native-skill-hashes.json` (**path tuyệt đối**, danh sách 107 skill) và `hooks/.logs/hook-log.jsonl` (log hoạt động) |

Restore bundle này cho cùng bộ file như `config/` — đủ 22 extension + statusline. Đây là snapshot của máy, nên `settings.json` trong bundle có thể khác `config/settings.json` ở những key bạn đổi sau đó (ví dụ model mặc định, TUI mode). Muốn bundle không lọc (giữ cả state của máy) thì bỏ `--exclude-file`.

---

## 22 extensions trong snapshot

| # | Package | Version | Làm gì |
|---|---|---|---|
| 1 | `pi-web-access` | 0.29.0 | web search, fetch URL, clone GitHub repo, đọc PDF, hiểu YouTube + video local |
| 2 | `pi-mcp-adapter` | 2.34.0 | adapter MCP (Model Context Protocol) |
| 3 | `pi-subagents` | 0.68.0 | delegate cho subagent + workflow multi-agent bằng script |
| 4 | `pi-goal-x` | 0.31.4 | `/goal`: lập kế hoạch mục tiêu, tiến độ bền, auditor kiểm tra hoàn thành |
| 5 | `pi-background-tasks` | 2.5.0 | task shell chạy nền, delegated agent read-only, attested run, Fusion workflow |
| 6 | `pi-model-fallback` | 0.4.0 | chuyển sang model fallback theo **rule** (provider/model + HTTP status 429/5xx) khi provider lỗi; state bền có cooldown; config bằng tool `model_fallback_config` |
| 7 | `@narumitw/pi-usage` | 0.60.8 | hiển thị usage của account + số dư DeepSeek API |
| 8 | `pi-simplify` | 0.2.3 | review code vừa đổi theo hướng rõ ràng / nhất quán / dễ bảo trì |
| 9 | `pi-footer` | 0.5.1 | statusline nhiều dòng, tuỳ biến được (dùng trong repo này) |
| 10 | `pi-powerline-footer` | 0.17.1 | status bar kiểu powerline (đang **tắt** bằng `"extensions": []`) |
| 11 | `pi-memory` | 0.4.2 | memory + semantic search (qmd) trên daily log / long-term / scratchpad |
| 12 | `pi-worktree` | 1.3.3 | quản lý git worktree, tạo workspace cách ly bằng 1 lệnh |
| 13 | `@99percentpeople/pi-todo` | 1.2.7 | todo tối giản, atomic: xoá bằng omission, state sống qua compaction, có dependencies, widget read-only |
| 14 | `@juicesharp/rpiv-ask-user-question` | 2.10.1 | hỏi bạn bằng questionnaire có lựa chọn thay vì đoán |
| 15 | `@juicesharp/rpiv-btw` | 2.10.1 | `/btw`: hỏi nhanh 1 câu bằng chính model chính, không làm bẩn conversation |
| 16 | `@pi-unipi/notify` | 2.17.0 | thông báo khi agent xong/lỗi: native OS, Gotify, Telegram, ntfy, định tuyến theo từng loại event (⚠ config chứa credential — không backup) |
| 17 | `pi-smart-fetch` | 0.3.17 **(pinned)** | `web_fetch` giả TLS desktop browser + trích nội dung bằng defuddle |
| 18 | `pi-advisor-flow` | 0.6.0 | flow Executor/Advisor: ý kiến thứ hai từ model mạnh hơn, có cổng review trước plan / sau lỗi lặp / trước khi kết thúc |
| 19 | `@tmustier/pi-session-recap` | 0.5.0 | recap “while you were away”: soạn sẵn bản tóm tắt khi bạn rời session, hiện ở cuối transcript / trên editor lúc quay lại. Cho workflow nhiều agent chạy song song |
| 20 | `pi-lens` | 4.1.6 | LSP diagnostics + navigation, linters/type-checker, formatter, ast-grep/tree-sitter, `symbol_search`, read-guard, `/lens-map`. Trong setup này đã tắt widget + autoformat + autofix (xem mục riêng) |
| 21 | `pi-browser-use` | 0.11.7 | trình duyệt cho agent qua `chrome-devtools-mcp` (không phải Playwright): Chrome headless riêng của pi với profile `~/.pi/browser-profile` (login 1 lần bằng `browser_setup`), chế độ `fresh` cách ly, tool `browser_*` + skill `browser-policy`. Cần Node ≥ 24 và Chrome stable. `browser_doctor` để tự chẩn đoán |
| 22 | `@injaneity/pi-computer-use` | 0.5.1 | cho agent điều khiển app desktop trên macOS, Windows và Linux qua accessibility API của hệ điều hành: `find_roots`, `observe_ui`, `search_ui`, `expand_ui`, `inspect_ui`, `act_ui`, `read_text`, `wait_for`. Cài helper riêng cho user ở `~/Applications/pi-computer-use.app`; macOS cần cấp **Accessibility** + **Screen Recording** cho helper, và bước setup chỉ chạy trong session pi tương tác → ở chế độ `-p` (print) extension chưa làm được gì cho tới khi bạn cấp quyền |

> Version là **tham khảo tại thời điểm snapshot**; nguồn sự thật là `config/settings.json`. Chỉ `pi-smart-fetch` được pin cứng, phần còn lại floating → máy mới sẽ lấy bản mới nhất. Muốn khớp chính xác, pin lại trong `config/settings.json`.

Provider mặc định: `opencode-go/deepseek-v4.1-flash` (thinking `high`). Model đang bật: xem `enabledModels` trong `config/settings.json`.

---

## Statusline: context bar (0–100%)

Statusline là `pi-footer`, cấu hình ở `config/extensions/pi-footer.json`. Repo này bật sẵn widget **`context-bar`** — thanh tiến độ context theo **context window của từng model** (không phải số cố định):

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

Kết quả render thật (gọi trực tiếp `render()` của widget, context window 200k):

```
   0%  [░░░░░░░░░░░░░░░░] 0/200k (0%)        fg=blue
  25%  [████░░░░░░░░░░░░] 50k/200k (25%)      fg=blue
  71%  [███████████░░░░░] 142k/200k (71%)     fg=yellow   ← ≥ 70%
  92%  [███████████████░] 184k/200k (92%)     fg=red      ← ≥ 90%
```

Model khác thì thang chia khác — context 1M ở 25% ra `[████░░░░░░░░░░░░] 250k/1m (25%)`. Khi chưa biết context length thì hiện `?`.

| Muốn đổi | Sửa gì trong `pi-footer.json` |
|---|---|
| Độ rộng / kiểu bar | `contextBarMode`: `default` (32 ô, có ngoặc) · `medium` (16 ô, đang dùng) · `short` (10 ô) · `short-only` (10 ô, không hiện số) |
| Bật/tắt đổi màu theo % | `contextConditionalColors` (ngưỡng `contextWarningPercent` 70, `contextDangerPercent` 90) |
| Hiện token thô thay vì bar | đổi `"type": "context-bar"` → `"context-length"`, hoặc dùng `"context-remaining"` / `"context-window"` |

Dòng 2 của statusline hiện tại: `context-bar` → `cache-hit-rate` → 2 event widget (`cache_ttl`, `tps` do `pi-footer-cache-tps.ts` đẩy vào).

### Layout 3 hàng

Statusline được xếp **đúng 3 hàng**, không bỏ widget nào:

| Hàng | Nội dung | Width |
|---|---|---|
| 1 | `cwd` · `model-provider` · `thinking-level` | 71 |
| 2 | `context-bar` · `cache-hit-rate` · `cache_ttl` · `tps` · `total-time` | 80 |
| 3 | `git-branch` · `git-diff` · `cost` · `mcp` · `background-tasks` · `goal` · `usage` | 84 |

**Vì sao trước đây là 4 hàng:** pi-footer render số hàng trong `lines` **cộng thêm 1 hàng** (`extensionStatusRow`) chứa status do các extension khác công bố qua `ctx.ui.setStatus` (`mcp`, `goal`, `background-tasks`, `usage`). Ẩn hàng đó bằng `extensionStatusRow.hiddenKeys` và đưa chúng vào hàng 3 dưới dạng widget `external-status`.

> ⚠️ `hiddenKeys` là danh sách key **chính xác**, không có wildcard. Nếu sau này một extension khác công bố status mới, hàng thứ 4 sẽ quay lại — thêm key đó vào `hiddenKeys` (hoặc dùng `/footer`). Các key đang được phủ (13): `advisor-scout`, `advisor-usage`, `background-tasks`, `goal`, `mcp`, `mcp-auth`, `pi-lens-lsp`, `session-recap`, `stash`, `subagent-slash`, `subagent-slash-text`, `usage`, `worktree`.

**Giới hạn độ rộng:** tổng nội dung là **243 ký tự** (201 của widget + 42 của separator) → 3 hàng thì hàng dài nhất **buộc phải ≥ 81**. Layout hiện tại cần terminal **≥ 85 cột**, hẹp hơn sẽ bị cắt đuôi bằng `…`. Muốn vừa terminal 80 cột, giảm độ rộng: `cwd` → `segments: 2` (−8) và `model-provider` → `model` (−11) ⇒ hàng dài nhất còn ~65.

> ⚠️ Config dùng `"iconMode": "nerd"` nên terminal cần **Nerd Font** (bản patch) mới hiện đủ icon. Trong `fonts/` có JetBrains Mono **gốc** (không patch) — cài bản gốc rồi trỏ terminal vào đó là **icon vỡ**: xem [Font terminal](#font-terminal-bắt-buộc-nerd-font).

Ảnh thật của layout này: xem [Screenshots](#screenshots).

### Font terminal: bắt buộc Nerd Font

**Đây không phải chi tiết nhỏ.** Mọi icon của statusline là codepoint **Private Use Area** của Nerd Fonts:

| Widget | Codepoint | JetBrains Mono (gốc) | DankMono Nerd Font Mono | FantasqueSansMono NF Mono |
|---|---|---|---|---|
| `cwd` | U+F07C | ❌ thiếu | ✅ | ✅ |
| `model-provider` | U+F06A9 | ❌ thiếu | ✅ | ❌ thiếu |
| `thinking-level` | U+F0208 | ❌ thiếu | ✅ | ❌ thiếu |
| `context-bar` | U+F035B | ❌ thiếu | ✅ | ❌ thiếu |
| `cache-hit-rate` | U+F04CE | ❌ thiếu | ✅ | ❌ thiếu |
| `total-time` | U+F13AB | ❌ thiếu | ✅ | ❌ thiếu |
| `git-branch` | U+E725 | ❌ thiếu | ✅ | ✅ |
| `git-diff` | U+E702 | ❌ thiếu | ✅ | ✅ |
| `cost` | U+F04A3 | ❌ thiếu | ✅ | ❌ thiếu |
| `cache_ttl`, `tps` (event) | U+F01BC, U+EAF3 | ❌ thiếu | ✅ | ❌ thiếu |

JetBrains Mono **gốc** (bản trong `fonts/`) thiếu **11/11** icon. Khi thiếu, terminal **không** để trống ô — nó fallback sang font khác có codepoint đó, nên icon hiện ra thành **hình vô nghĩa** (kim cương ◆, ngôi sao ✦, hay dấu `?`), chứ không phải lỗi config.

**Sửa — chọn 1 trong 2:**

**A. Dùng Nerd Font cho terminal** (giữ nguyên icon đẹp, khuyến nghị). Bản **Mono** (single-width) là bắt buộc cho TUI, không dùng bản non-Mono vì icon sẽ rộng 2 ô và lệch cột.

```bash
# macOS
brew install --cask font-jetbrains-mono-nerd-font     # hoặc font-dank-mono-nerd-font
```

```powershell
# Windows: cài font theo user (copy + đăng ký registry), hoặc bôi đen .otf/.ttf → chuột phải → Install
$dst = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
Copy-Item .\DankMonoNerdFontMono-Regular.otf $dst
New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts" `
  -Name "DankMono Nerd Font Mono (TrueType)" -Value "$dst\DankMonoNerdFontMono-Regular.otf" -PropertyType String -Force
```

Rồi trỏ terminal vào font đó. Với Windows Terminal — sửa `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`, đặt ở `profiles.defaults` để áp cho **mọi** profile (profile có `font` riêng sẽ **ghi đè** defaults, nên phải sửa cả profile đó):

```json
"profiles": {
  "defaults": {
    "font": { "face": "DankMono Nerd Font Mono", "size": 12 }
  }
}
```

> Profile nào đã có `font` riêng thì sửa `face` của chính profile đó (Windows Terminal tự hot-reload file `settings.json`; nên backup file này trước khi sửa).

**B. Không muốn cài font patch:** đổi `"iconMode": "nerd"` → `"emoji"` (dùng 📁… render bằng Segoe UI Emoji trên Windows / Apple Color Emoji trên macOS) hoặc `"text"` (chữ thuần, không icon). Đổi lại: icon to hơn và statusline kém gọn.

---

## pi-model-fallback

Extension fallback model theo **rule**: khi provider trả về HTTP status khớp rule (mặc định `429`, `500`, `502`, `503`, `504`), pi chuyển sang model fallback của rule đó và ghi **state bền** để các session sau vẫn dùng model mới cho tới khi hết cooldown (`429` → 72 giờ, `5xx` → 10 phút; header `Retry-After` / `x-ratelimit-reset*` ghi đè khi có). Rule khớp theo thứ tự, rule đầu tiên thắng — nên rule `matchModels` cụ thể phải đặt trước rule `matchProviders` rộng.

```bash
/model-fallback:status   # đang bật hay không, entry bền nào active, path config/state
/model-fallback:reset    # xoá state bền + quay về model trước fallback
```

`autoRetry` (mặc định bật) đưa lại prompt lỗi thành follow-up sau khi đã đổi model; bản thân request lỗi không được gửi lại.

Config ở `~/.pi/agent/model-fallback/config.json`, do tool `model_fallback_config` của extension đọc/validate/ghi — **không có TUI** như `pi-provider-fallback` (đã gỡ khỏi snapshot này). Mặc định của package là `zai/*` → `deepseek/deepseek-v4-flash`; snapshot này thay bằng rule cho provider `deepseek`:

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

> Điểm khác đáng chú ý so với extension cũ: config **không** nằm trong `extensions/` mà cùng thư mục với `state.json`. Vì vậy `scripts/pi-setup-backup.sh` liệt kê riêng `model-fallback/config.json` và **chỉ lấy file config** — `state.json` là state theo máy nên không được đưa vào artifact; restore cũng chỉ ghi `config.json`.

---

## `pi-advisor-flow`

Flow **Executor / Advisor**: model đang chạy việc (Executor) có thể xin ý kiến thứ hai từ một model mạnh hơn (Advisor). Có các **cổng review tự động** — trước khi lập plan, sau khi lỗi lặp lại nhiều lần, và trước khi tuyên bố hoàn thành — và có thể dừng hành động theo policy bạn cấu hình. Tham khảo paper *Steering Black-Box LLMs with Advisor Models*.

```bash
/advisor            # xin ý kiến Advisor (mở model picker nếu chưa cấu hình)
/advisor-models     # chọn model Executor + Advisor
/advisor-settings   # cấu hình behavior, context, privacy, limits
```

Config toàn cục ở **`~/.pi/agent/advisor.json`** — nằm ở **gốc** config dir, **không** trong `extensions/`, nên backup phải liệt kê riêng (đã làm). Project có thể override bằng `<project>/.pi/advisor.json`.

Extension này còn công bố 2 status key (`advisor-scout`, `advisor-usage`) — đã được đưa vào `hiddenKeys` + widget inline như 9 key kia, để hàng status không quay lại khi Advisor đang chạy.

State riêng của nó (`advisor-outcomes.jsonl`, `advisor-outcomes-salt`) là log/salt theo máy → đã cho vào `.pi-setup-exclude`, không lên repo.

---

## `@tmustier/pi-session-recap`

Recap **“while you were away”** (theo mẫu away-summary của Claude Code): khi bạn thật sự rời session một lúc, extension soạn sẵn một bản tóm tắt ngắn — việc lớn đang làm trước, rồi bước tiếp theo cụ thể — và đặt ở cuối transcript (TUI thường thì nằm trên editor) để bạn đọc ngay khi quay lại. Làm cho workflow nhiều agent chạy song song ở nhiều tab.

**Không có file config hay state nào** — extension thuần stateless, không đọc/ghi gì trong `~/.pi/agent/`, nên không cần thêm gì vào danh sách backup.

Nó vẫn công bố 1 status key (`session-recap`, hiện `✦ drafting recap…` lúc đang soạn) → đã vào `hiddenKeys` + có widget inline, để statusline không nhảy lên hàng 4 trong lúc recap đang soạn.

> Nếu dùng tmux, cần `set -g focus-events on` trong `~/.tmux.conf` rồi `tmux source-file ~/.tmux.conf` để extension biết bạn đã quay lại.

---

## `pi-lens` (LSP)

Bật LSP cho pi. `pi` không có LSP built-in — không có setting, không có docs — nên đây phải là extension. `pi-lens` được chọn vì nhiều tính năng hơn và phổ biến hơn hẳn (`@narumitw/pi-lsp` chỉ có LSP, ít dùng hơn ~9 lần), **và** lý do bạn gỡ nó hôm trước — nó hiện danh sách file trên màn hình — tắt được bằng **một dòng config**.

Phần gây khó chịu là **widget** (`setWidget("pi-lens", …)`, hiện findings theo từng file phía trên editor), không phải statusline. Nó có setting `widget.visible`:

```json
// ~/.pi-lens/config.json  —  LƯU Ý: nằm ở ~/.pi-lens/, KHÔNG phải ~/.pi/agent/
{
  "lsp": { "enabled": true },
  "widget": { "visible": false },
  "format": { "enabled": false },
  "autofix": { "enabled": false }
}
```

`format` và `autofix` tôi để **false** vì bạn chỉ xin LSP — mặc định của package là `true`, tức nó tự format và tự apply quickfix vào code bạn sửa. Muốn bật lại thì đổi thành `true` (hoặc dùng CLI flag `--no-autofix` / `--no-autoformat` để tắt, `--lens-actionable-warnings --lens-actionable-warning-autofix` để bật thêm cảnh báo).

Statusline: extension này công bố key `pi-lens-lsp` (giá trị kiểu `LSP Active: ts` / `LSP Inactive`) → đã vào `hiddenKeys` + có widget inline, nên bạn **thấy được LSP có chạy hay không** mà statusline vẫn 3 hàng.

Mặc định giá trị đó liệt kê tên server (`LSP Active: typescript, jsonc, …`) và pi-lens **không có** config nào cho dòng này, nên repo này rút gọn nó bằng một **bản vá bundle**: `LSP ✓` (xanh) khi có server, `LSP ✗` (đỏ) khi có server lỗi, `LSP ✗` (mờ) khi không có — khi vừa có server chạy vừa có server lỗi thì hiện `LSP ✓ · LSP ✗` (giữ nguyên ngữ nghĩa của bản gốc). Chạy lại sau mỗi lần `pi update`:

```bash
node scripts/pi-lens-compact-lsp-status.mjs           # vá (no-op nếu đã vá)
node scripts/pi-lens-compact-lsp-status.mjs --check   # chỉ báo trạng thái
node scripts/pi-lens-compact-lsp-status.mjs --revert  # trả về nguyên bản
```

Config của nó nằm **ngoài** config dir của pi, nên `scripts/pi-setup-backup.sh` có cơ chế riêng cho nhóm này: xem mục *Config nằm ngoài config dir* bên dưới.

---

## Scripts

Hai script setup **không hỏi xác nhận** — chạy được trong script/CI. Rủi ro xử lý bằng snapshot + cảnh báo ra `stderr`. Script thứ ba chỉ **đọc**; script thứ tư sửa **một file** trong bundle pi-lens đã cài (rút gọn dòng status LSP).

### `pi-setup-verify-advisor.mjs`

`pi-advisor-flow` không báo lỗi khi gặp key lạ trong `advisor.json`: nó giữ nguyên key đó rồi chỉ notify `contains unrecognized key(s) ... They were preserved but ignored` — và giá trị của key đó **không có hiệu lực**. Một key viết sai tên vì thế trông như đã cấu hình mà thật ra không làm gì.

Script này trích `CONFIG_SCHEMA` từ chính bundle đang cài rồi mô phỏng hai kiểm tra mà extension chạy lúc load: `unknownConfigKeys()` (key lạ → bị ignore) và `validate*Values()` (sai type / ngoài enum).

```bash
node scripts/pi-setup-verify-advisor.mjs            # file trong repo (config/advisor.json)
node scripts/pi-setup-verify-advisor.mjs --live     # + file đang chạy ~/.pi/agent/advisor.json, và so 2 file
node scripts/pi-setup-verify-advisor.mjs --file <path>
```

| Exit | Nghĩa |
|---|---|
| `0` | sạch |
| `1` | config sai: key lạ, sai type, ngoài enum, JSON hỏng, thiếu file, snapshot lệch bản đang chạy |
| `2` | lỗi môi trường: không thấy bundle `pi-advisor-flow`, bundle đổi định dạng, tham số sai |

> Vì sao cần: tôi từng viết `advisorFailureMode` (lấy từ tên biến nội bộ trong bundle) trong khi key thật là `gateFailureMode` — file trông đúng, **không** có tác dụng, và mãi sau mới thấy warning. Script này bắt đúng lớp lỗi đó (xem bảng Kiểm chứng).

### `pi-lens-compact-lsp-status.mjs`

pi-lens hardcode dòng status LSP trong bundle (`updateLspStatus`): `` `LSP Active: ${activeIds.join(", ")}` ``, `` `LSP Failed: ${failedIds.join(", ")}` ``, `"LSP Inactive"`. Không có key config nào cho dòng này (`~/.pi-lens/config.json` chỉ có `lsp.enabled`, `widget.visible`, `format.enabled`, `autofix.enabled`, `ui.compactToolLine`, `actionableWarnings.*`), và extension khác cũng không sửa hộ được: `ctx.ui` chỉ có `setStatus` (ghi), còn `footerData.getExtensionStatuses()` chỉ tồn tại **bên trong** footer renderer — mà footer đang do `pi-footer` nắm (`setFooter` last-wins), nên widget `Pi Extension Status` chỉ render nguyên văn (option `trimValue` của nó cắt phần **đầu**, không đụng được danh sách server ở đuôi).

Script vá đúng 3 chuỗi đó, mỗi chuỗi phải khớp **đúng 1 lần**:

```bash
node scripts/pi-lens-compact-lsp-status.mjs           # vá (no-op nếu đã vá)
node scripts/pi-lens-compact-lsp-status.mjs --check   # chỉ báo trạng thái, không ghi
node scripts/pi-lens-compact-lsp-status.mjs --revert  # trả bundle về nguyên bản
```

| Exit | Nghĩa |
|---|---|
| `0` | đã vá / vừa vá xong / vừa revert xong |
| `1` | chưa vá (khi `--check`) hoặc bundle khác định dạng → **không** tự sửa |
| `2` | lỗi môi trường (không thấy bundle pi-lens, tham số sai) |

> ⚠ npm ghi đè `pi-lens/dist/index.js` mỗi lần `pi update` hoặc cài lại pi-lens → **chạy lại script này**. Đó là lý do một script vá nằm trong repo snapshot. Đã gửi đề xuất upstream xin option chính thức cho dòng status này.

### `pi-setup-backup.sh`

Mặc định chỉ lấy **setup**: `settings.json`, `APPEND_SYSTEM.md`, `models-store.json`, `model-fallback/config.json`, `extensions/` — và **luôn lấy cả statusline** (`extensions/pi-footer.json` nằm trong `extensions/`).

```bash
./scripts/pi-setup-backup.sh                       # → ./pi-setup-portable.tar.gz (chỉ setup)
./scripts/pi-setup-backup.sh --config-dir config    # → cập nhật config/ trong repo này
./scripts/pi-setup-backup.sh --skills --hooks       # thêm skills + hooks
./scripts/pi-setup-backup.sh -o ~/Desktop/pi.tar.gz
./scripts/pi-setup-backup.sh --dry-run
```

| Opt-in (mặc định **không** lấy) | Lấy gì | Ghi chú |
|---|---|---|
| `--auth` | `auth.json` | ⚠ **chứa credential** → không đưa lên nơi công khai |
| `--skills` | `skills/` | **dereference symlink** → backup tự chứa (~24 MB, 108 skill) |
| `--hooks` | thư mục `hooks/` trong `~/.pi/agent` | hiện tại: 544 KB. **Không** đụng `~/.claude/hooks` (ở đó có `.env`). Ghi đè `.pi-setup-exclude` cho đường dẫn hooks |
| `--memory` | `memory/` | |
| `--missions` | `missions/` | ⚠ state pi-goal-x, có thể chứa tên project/khách hàng |
| `--sessions` | `sessions/` | lịch sử chat (~56 MB) |
| `--with-state` | `--skills --memory --missions` | |

| Opt-out | Tác dụng |
|---|---|
| `--no-statusline` | **Không** backup cấu hình statusline (`pi-footer.json`, `powerline-footer/theme.json`) — máy mới sẽ dùng layout mặc định |

Script tự: ghi file tạm rồi `mv` (không để lại artifact hỏng khi bị ngắt) · **quét secret** (`sk-*`, `ghp_*`, `xox*`, `BEGIN PRIVATE KEY` có thân base64, `api_key=…`) · **cảnh báo symlink trỏ ra ngoài** · **báo cáo config extension** (statusline / model-fallback có được backup hay không) · nén deterministic (`gzip -n` → cùng nội dung cho cùng SHA-256) · từ chối ghi `--config-dir` vào `$HOME`, `/`, hoặc chính config dir của pi.

> Về quét secret: script bỏ qua placeholder phổ biến (giá trị thuần chữ như `currentPassword`, dạng `{CLIENT_SECRET}`, PEM header không có thân, entropy thấp như `ghp_aaaa…`). Vẫn có thể báo **fixture trong test của chính package** (VD một chuỗi kiểu Slack token trong test của chính AgentKit) và **chuỗi test bạn từng dán vào chat** (khi dùng `--sessions`, vì transcript nằm trong `sessions/`) — đọc tên file trước khi kết luận.

### `pi-setup-restore.sh`

| Tùy chọn | Tác dụng |
|---|---|
| `--from-config DIR` | restore từ `config/` (plain file) |
| `--bundle FILE` | restore từ `.tar.gz` |
| `--target DIR` | đích khác `~/.pi/agent` |
| `--scratch` | đích là thư mục tạm — **an toàn để thử** |
| `--install` | chạy pi headless 1 lần để tự cài extension (~150–190 s) |
| `--verify` | so số extension đã cài với `settings.json` |
| `--with-trust` | copy cả `trust.json` |
| `--dry-run` | chỉ in ra, không ghi |

Trước khi ghi đè, `settings.json` **và** `auth.json` (nếu nguồn có) được snapshot thành `*.bak.<timestamp>`. Script có `trap ERR` nên không bao giờ thoát im lặng — luôn in số dòng khi gặp lỗi ngoài dự kiến. Sau khi restore, script in thêm **bước 4**: trạng thái vá dòng status LSP của pi-lens ở đích vừa restore (chỉ báo, không tự sửa package bên thứ ba).

---

## Kiểm chứng

Test bằng cách restore vào một config dir **hoàn toàn mới** qua `PI_CODING_AGENT_DIR`, không đụng setup thật.

> ⚠️ Mọi số đo dưới đây lấy trên payload **20 package**. Snapshot hiện tại là **22 package** (thêm `pi-browser-use`, `@injaneity/pi-computer-use`) nên **chưa được đo lại**.

| Kiểm tra | Kết quả |
|---|---|
| Thời gian cài lần đầu | **136–246 s** qua các lần chạy thật (tuỳ tốc độ npm; 335 s khi npm cache nguội) |
| Module dirs trong `npm/node_modules` | **0 → 203** (snapshot 20 package) |
| `--verify` | **20/20** ở lần chạy gần nhất (pi-lens + pi-todo + notify), **19/19 · 18/18 · 17/17 · 16/16** ở các snapshot trước |
| Extension **thực sự chạy** (không chỉ cài) | ✅ 18 `extension_ui_request`, 0 lỗi load, đủ surface `subagent-async`, `mcp`, `goal`, `background-tasks`, `usage`, `pi-footer`, `advisor-scout`, `advisor-usage`, `pi-lens-lsp` |
| Config **ngoài** config dir được restore | ✅ ghi đúng `~/.pi-lens/config.json` (snapshot bản cũ trước khi ghi đè) |
| Restore từ **bundle mới** vào `HOME` giả | ✅ 9 file, config ngoài ghi đúng `<HOME>/.pi-lens/config.json`, nội dung khớp `config/pi-lens-config.json` |
| Artifact trùng basename legacy của pi-lens | ✅ đổi `config/pi-lens.json` → `pi-lens-config.json`: repro với cwd=`config/` **6 → 12** warning `PILENS_CFG_0003/0001` trước khi sửa, **delta 0** sau khi sửa, resolution `documents=1 legacy=0 records=0` |
| Clone repo public rồi restore | ✅ 11 file, 0 file bị loại, 153 s, verify khớp, 0 lỗi |
| `auth.json` trong dir mới | `{}` → không rò secret |
| Chạy lần 2 | log rỗng → idempotent |
| Backup 2 lần liên tiếp | **byte-identical** (deterministic) |
| `context-bar` render | ✅ gọi trực tiếp `render()`: 0/25/**71%→vàng**/**92%→đỏ**/100%, scale đúng theo 200k và 1m |
| `--no-statusline` | ✅ `pi-footer.json` biến mất khỏi bundle (SHA khác bản mặc định) |
| `--hooks` + `.pi-setup-exclude` | ✅ hooks sống sót, in cảnh báo "ghi đè", 54 file còn lại |
| `--auth` khi restore | ✅ có `auth.json.bak.<ts>` giữ credential cũ trước khi ghi đè |

### Windows 11 + Git Bash (MSYS2, bash 5.3) — đo trên payload 20 package

| Kiểm tra | Kết quả |
|---|---|
| Restore thật (`--from-config config --install --verify`) | ✅ **20/20**, cài **88 s**, module dirs `0 → 203` |
| `pi list` trong bản restore | ✅ 20 package |
| Config **ngoài** config dir | ✅ ghi đúng `%USERPROFILE%\.pi-lens\config.json`, nội dung khớp `config/pi-lens-config.json` |
| Restore từ bundle vào `HOME` giả | ✅ 9 file, config ngoài ghi đúng |
| MSYS convert path cho `pi` con | ✅ `PI_CODING_AGENT_DIR=/tmp/...` → `C:/Users/.../Temp/...` |
| Tạo lại bundle trên Windows | ✅ 9 file, 7.9 KB, sạch (không còn `._*` AppleDouble như bản tạo trên macOS) |
| Đếm package không cần `python3` | ✅ `node -e` → `20` |
| CRLF trong script | ✅ bash 5.3.15 chịu CRLF (test bằng bản copy CRLF, exit 0) |

### Script verify (`advisor.json`)

| Kiểm tra | Kết quả |
|---|---|
| Ma trận config (chạy thật, so exit code) | ✅ **6/6**: config sạch `0` · key lạ `1` · ngoài enum `1` · sai type `1` · ref thiếu `provider/model` `1` · thiếu `gateFailureMode` vẫn `0` |
| Nhánh môi trường | ✅ **7/7**: `--live` so 2 file `0` · `--pkg` không tồn tại `2` · bundle không có `CONFIG_SCHEMA` `2` · `--help` `0` · tham số sai `2` · JSON hỏng `1` · file thiếu `1` |
| Trích schema | ✅ **31 key** từ `CONFIG_SCHEMA` của bundle 0.6.0; bắt đúng `advisorFailureMode` — key mà extension từng cảnh báo (harness khớp output thật) |

---

## Giới hạn đã biết

- **`auth.json` không nằm trong repo** (secret) → `/login` lại ở máy mới.
- **`sessions/` và `missions/` không nằm trong repo** → không migrate lịch sử chat/mission. Dùng `--sessions` / `--missions` để tự backup riêng.
- **2 skill là symlink sang AgentKit** (`skills/orchestration`, `skills/orca-per-workspace-env`) → chỉ chạy nếu máy mới cài [AgentKit](https://github.com/bestagentkits). Gãy 2 symlink này **không** ảnh hưởng extension nào khác (đã test). Dùng `--skills` để backup kèm nội dung thật.
- **3 extension `orca-*.ts`** và **2 thư mục `agentkit-*`** không nằm trong repo → Orca/AgentKit tự sinh lại.
- **`pi-model-fallback` config** ở `~/.pi/agent/model-fallback/config.json` — **cùng thư mục** với `state.json`, mà `state.json` là state theo máy (entry + mốc cooldown) nên **không** được backup. Script liệt kê riêng đúng file config. Chưa có file thì extension chạy bằng default của package (`zai` → `deepseek/deepseek-v4-flash`).
- **`pi-advisor-flow` config** (`~/.pi/agent/advisor.json`, nằm ở **gốc** config dir chứ không trong `extensions/`) chỉ tồn tại sau khi chạy `/advisor` hoặc `/advisor-settings`. Backup đã liệt kê riêng file này nên sẽ tự kèm khi nó xuất hiện.
- **Script cần shell POSIX** → trên Windows phải chạy trong **Git Bash** hoặc **WSL**; PowerShell/cmd không chạy được script này.
- **Icon statusline cần Nerd Font** → dùng JetBrains Mono **gốc** trong `fonts/` sẽ làm icon vỡ thành ◆/✦/`?`; xem [Font terminal](#font-terminal-bắt-buộc-nerd-font).
- **`pi` cài global theo từng Node version** → `nvm use` / `fnm use` sang version khác có thể làm mất lệnh `pi`; cài lại global cho version đó.
- **Dòng status LSP của `pi-lens` là bản vá bundle**, không phải config → `pi update` ghi đè mất; chạy lại `node scripts/pi-lens-compact-lsp-status.mjs` (script tự dừng với exit `1` nếu pi-lens đổi định dạng hàm, không sửa mù).

---

## Repo cá nhân

Đây là bản chụp setup của máy cá nhân tại một thời điểm, **không phải sản phẩm chính thức** của pi hay của bất kỳ package nào được liệt kê. Không kèm giấy phép — mọi quyền thuộc về tác giả; các extension bên thứ ba thuộc giấy phép của chúng.
