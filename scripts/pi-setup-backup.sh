#!/usr/bin/env bash
#
# pi-setup-backup.sh — đóng gói phần "setup" của pi để mang sang máy khác
#
# Mặc định chỉ lấy SETUP (không lấy state/secret/lịch sử):
#   settings.json (manifest toàn bộ extension), APPEND_SYSTEM.md,
#   models-store.json, extensions/, model-fallback/config.json
#
# Các phần còn lại phải opt-in từng cái:
#   --auth       auth.json      ⚠ CHỨA CREDENTIAL (API key + OAuth token)
#   --skills     skills/        (dereference symlink → backup tự chứa)
#   --hooks      các thư mục hooks trong ~/.pi/agent
#   --memory     memory/
#   --missions   missions/      state của pi-goal-x (có thể chứa tên khách hàng)
#   --sessions   sessions/      lịch sử chat (thường vài chục MB)
#   --with-state = --skills --memory --missions
#
# KHÔNG bao giờ lấy: npm/ (cache, pi tự cài lại)
#
# Dùng:
#   ./pi-setup-backup.sh                              # → <repo>/pi-setup-portable.tar.gz
#   ./pi-setup-backup.sh --config-dir config          # → ghi plain file vào config/ (để commit)
#   ./pi-setup-backup.sh --skills --hooks -o ~/pi.tar.gz
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$(basename "$SCRIPT_DIR")" = "scripts" ]; then
	ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
else
	ROOT="$SCRIPT_DIR"
fi

AGENT_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"

# Setup: đủ để dựng lại y hệt bộ extension.
# advisor.json nằm ở GỐC config dir (không phải trong extensions/), do pi-advisor-flow
# dùng làm config toàn cục → phải liệt kê riêng, nếu không sẽ không được backup.
# advisor.json và 99extensions.json nằm ở GỐC config dir (không trong extensions/)
# → phải liệt kê riêng, nếu không sẽ không được backup.
# model-fallback/config.json của pi-model-fallback cũng nằm ngoài extensions/ (trong
# thư mục model-fallback/) → liệt kê riêng. CHỈ lấy file config, KHÔNG lấy cả thư mục:
# state.json cùng thư mục là state theo máy (entry + mốc cooldown), không phải setup.
ITEMS_SETUP=(settings.json APPEND_SYSTEM.md models-store.json advisor.json 99extensions.json model-fallback/config.json extensions)

OUT="$ROOT/pi-setup-portable.tar.gz"
CONFIG_DIR=""
EXCLUDE_FILE=""
CLEANUP_DIRS=()
QUIET=0
DRY_RUN=0

FLAG_AUTH=0
FLAG_SKILLS=0
FLAG_HOOKS=0
FLAG_MEMORY=0
FLAG_MISSIONS=0
FLAG_SESSIONS=0
FLAG_NO_STATUSLINE=0

# File cấu hình statusline. Mặc định ĐƯỢC backup (nằm trong extensions/).
# --no-statusline loại chúng ra. Danh sách đầy đủ ở CONFIG_CANDIDATES bên dưới.

# Pattern nhạy cảm — chặn trường hợp vô tình đưa secret vào artifact.
SECRET_RE='((^|[^A-Za-z0-9])sk-[A-Za-z0-9_-]{32,}|ghp_[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|"?(api[_-]?key|access[_-]?token|refresh[_-]?token|client[_-]?secret|password)"?[[:space:]]*[:=][[:space:]]*"[^"]{12,}")'

# Cấu hình của các extension: phần lớn nằm trong extensions/ nên MẬC ĐỊNH đã được
# backup; riêng advisor.json, 99extensions.json và model-fallback/config.json được
# liệt kê thêm ở ITEMS_SETUP. Script báo cáo tường minh để bạn biết cái nào có/không;
# --no-statusline loại nhóm statusline.
# định dạng: <đường dẫn tương đối trong AGENT_DIR>|<nhãn>|<có bị --no-statusline loại không>
CONFIG_CANDIDATES=(
	"extensions/pi-footer.json|statusline (pi-footer)|yes"
	"extensions/powerline-footer/theme.json|statusline (pi-powerline-footer)|yes"
	"model-fallback/config.json|fallback (pi-model-fallback)|no"
	"advisor.json|advisor flow (pi-advisor-flow)|no"
	"99extensions.json|todo (pi-todo)|no"
)

CONFIG_FOUND=()
STATUSLINE_FOUND=()
SKIP=()
# Config của vài extension nằm NGOÀI config dir của pi, nên không thể lấy theo
# đường dẫn tương đối. Định dạng: <đường dẫn>:<tên file trong artifact>.
# Ghi bằng ~ (không dùng /Users/...) để artifact không lộ path của máy.
# ⚠ KHÔNG thêm ~/.unipi/config/notify/config.json vào danh sách này: file đó chứa
# token Gotify và botToken/chatId Telegram → đưa vào artifact là lộ credential lên
# repo public. Config đó phải thiết lập lại trên máy mới bằng
# /unipi:notify-set-gotify và /unipi:notify-set-tg.
# ⚠ Tên file trong artifact KHÔNG được trùng basename config của pi-lens:
#   `pi-lens.json` (legacy, undotted), `pi-lsp.json`, `.pi-lens.json`.
# pi-lens walk ngược lên từ MỖI thư mục nó resolve config và khớp ĐÚNG basename,
# nên một artifact tên `pi-lens.json` nằm trong config/ bị đọc như project config
# deprecated → warning PILENS_CFG_0003/0001 mỗi lần làm việc trong repo (và
# `format`/`autofix` của nó bị áp như project setting). Vì thế đặt tên khác đi.
# Tilde trong danh sách dưới là DỮ LIỆU (không phải path cần expand) — `${src/#\~/$HOME}`
# trong ext_collect mới expand. shellcheck SC2088 báo nhầm nên tắt riêng cho statement này.
# shellcheck disable=SC2088
EXTERNAL_CONFIGS=(
	"~/.pi-lens/config.json:pi-lens-config.json"
)
# Guard: cảnh báo nếu ai đó thêm artifact trùng basename reserved của pi-lens.
pi_lens_reserved_name() {
	case "$1" in
		pi-lens.json | pi-lsp.json | .pi-lens.json) return 0 ;;
	esac
	return 1
}
# Tên file manifest đi kèm artifact, cho restore biết file ngoài nào cần đặt ở đâu.
EXTERNAL_MANIFEST="external-configs.txt"

ext_collect() {
	EXT_SRC=()
	EXT_NAME=()
	EXT_TILDE=()
	local entry src name expanded
	for entry in "${EXTERNAL_CONFIGS[@]}"; do
		src="${entry%%:*}"
		name="${entry##*:}"
		expanded="${src/#\~/$HOME}"
		if pi_lens_reserved_name "$name"; then
			warn "tên artifact '$name' trùng basename config của pi-lens — nó sẽ bị đọc như project config (đổi tên, VD pi-lens-config.json)"
		fi
		if [ -f "$expanded" ]; then
			EXT_SRC+=("$expanded")
			EXT_NAME+=("$name")
			EXT_TILDE+=("$src")
		fi
	done
}

# Pattern loại trừ (từ --exclude-file và/hoặc <config-dir>/.pi-setup-exclude).
# Khai báo Ở ĐÂY, không khai báo lại ở chỗ prune_excluded (sẽ reset mất giá trị).
EXCLUDES=()

# Các đường dẫn được --hooks yêu cầu rõ → không bị .pi-setup-exclude xoá.
# Khai báo Ở ĐÂY (không khai báo lại ở chỗ prune_excluded, sẽ reset mất giá trị).
PROTECT=()
info() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
emit() { printf '%s\n' "$*"; }
warn() { printf '⚠  %s\n' "$*" >&2; }
die() { printf '✗  %s\n' "$*" >&2; exit 1; }

usage() {
	cat <<'EOF'
Dùng: pi-setup-backup.sh [tùy chọn]

  -o, --output FILE     File tarball đầu ra (mặc định: <repo>/pi-setup-portable.tar.gz)
      --config-dir DIR  Ghi plain file vào DIR (dùng cho thư mục config/ được git track)
                        Tôn trọng <DIR>/.pi-setup-exclude (glob loại trừ, mỗi dòng 1 mục)
      --exclude-file F  File glob loại trừ cho cả 2 chế độ (mỗi dòng 1 pattern, # = comment)
                        VD: --exclude-file config/.pi-setup-exclude để bundle không chứa
                        state của máy (path tuyệt đối, log, code do công cụ khác sinh)

Opt-in thêm (mặc định KHÔNG lấy):
      --auth            auth.json      ⚠ chứa credential — không đưa lên nơi công khai
      --skills          skills/        dereference symlink → backup tự chứa (24 MB)
      --hooks           thư mục hooks trong ~/.pi/agent (không đụng ~/.claude)
      --memory          memory/
      --missions        missions/      state pi-goal-x (có thể chứa tên khách hàng)
      --sessions        sessions/      lịch sử chat (~56 MB)
      --with-state      = --skills --memory --missions
      --no-statusline   KHÔNG backup cấu hình statusline (mặc định LẤY)
                        (extensions/pi-footer.json, powerline-footer/theme.json)

      --dry-run         Chỉ in ra sẽ làm gì
  -q, --quiet           Chỉ in 1 dòng tóm tắt
  -h, --help            In hướng dẫn này

Biến môi trường:
  PI_CODING_AGENT_DIR   Thư mục config của pi (mặc định ~/.pi/agent)
EOF
}

while [ $# -gt 0 ]; do
	case "$1" in
		-o | --output) [ $# -ge 2 ] || die "-o cần tham số FILE"; OUT="$2"; shift 2 ;;
		--config-dir) [ $# -ge 2 ] || die "--config-dir cần tham số DIR"; CONFIG_DIR="$2"; shift 2 ;;
		--exclude-file) [ $# -ge 2 ] || die "--exclude-file cần tham số FILE"; EXCLUDE_FILE="$2"; shift 2 ;;
		--auth) FLAG_AUTH=1; shift ;;
		--skills) FLAG_SKILLS=1; shift ;;
		--hooks) FLAG_HOOKS=1; shift ;;
		--memory) FLAG_MEMORY=1; shift ;;
		--missions) FLAG_MISSIONS=1; shift ;;
		--sessions) FLAG_SESSIONS=1; shift ;;
		--with-state) FLAG_SKILLS=1; FLAG_MEMORY=1; FLAG_MISSIONS=1; shift ;;
		--no-statusline) FLAG_NO_STATUSLINE=1; shift ;;
		--dry-run) DRY_RUN=1; shift ;;
		-q | --quiet) QUIET=1; shift ;;
		-h | --help) usage; exit 0 ;;
		*) usage >&2; die "tham số không hợp lệ: $1" ;;
	esac
done

command -v tar >/dev/null 2>&1 || die "thiếu lệnh 'tar'"
[ -d "$AGENT_DIR" ] || die "không thấy thư mục config: $AGENT_DIR"

# --- Dựng danh sách mục cần lấy ---
# Quét config extension phải làm SAU khi parse tham số: --no-statusline quyết định SKIP
# (đặt block này trước vòng parse là bug — flag lúc đó vẫn = 0).
for entry in "${CONFIG_CANDIDATES[@]}"; do
	path="${entry%%|*}"
	rest="${entry#*|}"
	label="${rest%%|*}"
	is_statusline="${rest##*|}"
	if [ -e "$AGENT_DIR/$path" ]; then
		CONFIG_FOUND+=("$label: $path")
		if [ "$is_statusline" = "yes" ]; then
			STATUSLINE_FOUND+=("$path")
			[ "$FLAG_NO_STATUSLINE" -eq 1 ] && SKIP+=("$path")
		fi
	else
		CONFIG_FOUND+=("$label: (chưa có file $path)")
	fi
done

# Pattern loại trừ từ --exclude-file (áp cho cả tarball lẫn --config-dir).
if [ -n "$EXCLUDE_FILE" ]; then
	[ -f "$EXCLUDE_FILE" ] || die "không thấy exclude file: $EXCLUDE_FILE"
	while IFS= read -r line || [ -n "$line" ]; do
		line="${line%%#*}"
		line="$(printf '%s' "$line" | tr -d '[:space:]')"
		[ -n "$line" ] && EXCLUDES+=("$line")
	done <"$EXCLUDE_FILE"
fi

WANT=("${ITEMS_SETUP[@]}")
[ "$FLAG_AUTH" -eq 1 ] && WANT+=(auth.json)
[ "$FLAG_SKILLS" -eq 1 ] && WANT+=(skills)
[ "$FLAG_MEMORY" -eq 1 ] && WANT+=(memory)
[ "$FLAG_MISSIONS" -eq 1 ] && WANT+=(missions)
[ "$FLAG_SESSIONS" -eq 1 ] && WANT+=(sessions)

# Hooks: pi không có thư mục hooks riêng — hook nằm trong các thư mục tên 'hooks'
# bên trong config dir (hiện tại: extensions/agentkit-hooks-engineer/hooks).
# Chỉ quét trong $AGENT_DIR, KHÔNG đụng ~/.claude/hooks (ở đó có .env).
if [ "$FLAG_HOOKS" -eq 1 ]; then
	HOOK_PATHS=()
	while IFS= read -r h; do
		[ -n "$h" ] || continue
		HOOK_PATHS+=("${h#"$AGENT_DIR"/}")
	done < <(find "$AGENT_DIR" -type d -name hooks 2>/dev/null | sort)
	if [ "${#HOOK_PATHS[@]}" -eq 0 ]; then
		warn "--hooks: không tìm thấy thư mục 'hooks' nào trong $AGENT_DIR"
	else
		PROTECT+=("${HOOK_PATHS[@]}")
	fi
fi

INCLUDE=()
for item in "${WANT[@]}"; do
	if [ -e "$AGENT_DIR/$item" ]; then
		INCLUDE+=("$item")
	else
		case "$item" in
			skills | memory | missions | sessions | auth.json) warn "$item: không tồn tại, bỏ qua" ;;
		esac
	fi
done

# Hook chỉ được thêm như mục riêng khi nó KHÔNG nằm trong mục nào đã lấy
# (VD hooks ở gốc config dir). Nếu đã nằm trong extensions/ thì không thêm nữa
# để tránh archive trùng; lúc đó --hooks chỉ còn tác dụng bảo vệ khỏi .pi-setup-exclude.
if [ "$FLAG_HOOKS" -eq 1 ] && [ "${#HOOK_PATHS[@]}" -gt 0 ]; then
	for h in "${HOOK_PATHS[@]}"; do
		covered=0
		for item in "${INCLUDE[@]}"; do
			case "$h" in
				"$item" | "$item"/*) covered=1; break ;;
			esac
		done
		if [ "$covered" -eq 0 ]; then
			INCLUDE+=("$h")
		fi
	done
fi

[ "${#INCLUDE[@]}" -gt 0 ] || die "không có gì để backup trong $AGENT_DIR"
[ -f "$AGENT_DIR/settings.json" ] || warn "không thấy settings.json — artifact sẽ không có danh sách extension!"

# --- Cảnh báo về những gì được lấy thêm ---
[ "$FLAG_AUTH" -eq 1 ] && warn "--auth: artifact sẽ CHỨA CREDENTIAL (auth.json). KHÔNG đưa lên nơi công khai."
[ "$FLAG_MISSIONS" -eq 1 ] && warn "--missions: artifact sẽ chứa state mission (có thể có tên project/khách hàng)."
[ "$FLAG_SESSIONS" -eq 1 ] && warn "--sessions: artifact sẽ chứa lịch sử chat."
if [ "$FLAG_NO_STATUSLINE" -eq 1 ] && [ "${#STATUSLINE_FOUND[@]}" -gt 0 ]; then
	warn "--no-statusline: loại ${STATUSLINE_FOUND[*]} — máy mới sẽ dùng layout statusline mặc định"
fi

# --- Symlink: dereference khi lấy skills, để backup tự chứa ---
DEREF=0
[ "$FLAG_SKILLS" -eq 1 ] && DEREF=1

EXT_LINKS=""
if [ "$DEREF" -eq 0 ]; then
	# Cảnh báo symlink trỏ RA NGOÀI config dir (VD skills -> ~/.agents/skills của AgentKit).
	for item in "${INCLUDE[@]}"; do
		while IFS= read -r link; do
			[ -n "$link" ] || continue
			real="$(cd "$(dirname "$link")" && realpath "$(readlink "$link")" 2>/dev/null || true)"
			case "$real" in
				"$AGENT_DIR"/*) : ;;
				*) EXT_LINKS="$EXT_LINKS  ${link#"$AGENT_DIR"/} -> $(readlink "$link")
" ;;
			esac
		done < <(find "$AGENT_DIR/$item" -type l 2>/dev/null)
	done
	if [ -n "$EXT_LINKS" ]; then
		warn "có symlink trỏ ra ngoài config dir — máy mới phải có sẵn đích:"
		printf '%s' "$EXT_LINKS" >&2
		warn "(dùng --skills để dereference thành nội dung thật)"
	fi
else
	info "→ --skills: dereference symlink (backup tự chứa)"
fi

# Giá trị trông như placeholder trong tài liệu, không phải secret thật.
# Dùng để giảm cảnh báo giả (skill doc hay có `password: "securePassword123"`,
# `"client_secret": "{CLIENT_SECRET}"`) — nhờ vậy cảnh báo còn lại mới đáng đọc.
PLACEHOLDER_RE='\{|\}|<|>|your|example|placeholder|changeme|dummy|redacted|xxx|secure|sample|foobar|_test|test_|dummy'

# Heuristic phụ: giá trị chỉ gồm CHỮ CÁI (VD `currentPassword`, `userPassword`)
# là ví dụ trong tài liệu, không phải secret thật. Secret thật gần như luôn có
# số/ký tự đặc biệt (base64, hex, `sk-…`) nên lọc theo "thuần chữ" là an toàn.
is_placeholder() { # $1 = chuỗi khớp regex
	local s="$1" val uniq
	val="$(printf '%s' "$s" | grep -oE '"[^"]*"$' | tr -d '"')"
	[ -n "$val" ] || val="$s"
	# Entropy thấp: ≤ 8 ký tự khác nhau (VD fixture `ghp_aaaa…`, `test-test-test`).
	uniq="$(printf '%s' "$val" | fold -w1 | sort -u | wc -l | tr -d ' ')"
	[ "$uniq" -le 8 ] && return 0
	# Giá trị thuần chữ cái (camelCase như `currentPassword`) → ví dụ tài liệu.
	case "$val" in
		*[0-9]* | *[+/=_%$@!.:~-]*) return 1 ;;
	esac
	printf '%s' "$val" | grep -qE '^[A-Za-z]{4,40}$'
}

# PEM header trần (VD trong tài liệu dạy cách nhận biết secret) KHÔNG phải key thật:
# chỉ tính khi có thân base64 thật theo sau.
has_pem_block() { # $1 = file
	awk '/-----BEGIN [A-Z ]*PRIVATE KEY-----/ { getline; if ($0 ~ /^[A-Za-z0-9+\/]{20,}={0,2}$/) { found=1; exit } } END { exit found ? 0 : 1 }' "$1"
}

# --- Quét secret trên nội dung sẽ đóng gói ---
scan_secrets() { # $1 = thư mục chứa nội dung
	local found=0 skipped=0 f hits kept h
	while IFS= read -r f; do
		case "$f" in */auth.json) continue ;; esac # có chủ ý khi dùng --auth
		hits="$(grep -oE "$SECRET_RE" "$f" 2>/dev/null | grep -vEi "$PLACEHOLDER_RE" || true)"
		if [ -n "$hits" ] && ! has_pem_block "$f"; then
			hits="$(printf '%s\n' "$hits" | grep -v -- '-----BEGIN' || true)"
		fi
		kept=""
		while IFS= read -r h; do
			[ -n "$h" ] || continue
			is_placeholder "$h" || kept="$kept$h"$'\n'
		done <<<"$hits"
		if [ -z "$kept" ]; then
			skipped=$((skipped + 1))
			continue
		fi
		found=$((found + 1))
		warn "chuỗi giống secret trong: ${f#"$1"/}"
		printf '     %s\n' "$(printf '%s' "$kept" | head -2 | cut -c1-100)" >&2
	done < <(grep -rEIl "$SECRET_RE" "$1" 2>/dev/null)
	if [ "$found" -gt 0 ]; then
		warn "$found file có chuỗi giống secret — KIỂM TRA trước khi đưa artifact lên nơi không tin cậy."
		return 1
	fi
	if [ "$skipped" -gt 0 ]; then
		info "→ quét secret: sạch ($skipped file chỉ khớp placeholder trong tài liệu)"
	else
		info "→ quét secret: sạch"
	fi
	return 0
}

# Đếm package bằng NODE, không dùng python3 — xem chú thích cùng chỗ trong
# pi-setup-restore.sh (Windows thường không có python3).
pkg_count() {
	if [ -f "$AGENT_DIR/settings.json" ] && command -v node >/dev/null 2>&1; then
		node -e 'try{process.stdout.write(String((JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).packages||[]).length))}catch(e){process.exit(1)}' "$AGENT_DIR/settings.json" 2>/dev/null || echo '?'
	else
		echo '?'
	fi
}

item_size() {
	if SIZE="$(du -sh "$AGENT_DIR/$1" 2>/dev/null | cut -f1)"; then :; else SIZE="?"; fi
	emit "    $(printf '%-46s' "$1") $SIZE"
}

# Danh sách loại trừ cho chế độ --config-dir: đọc <CONFIG_DIR>/.pi-setup-exclude
# (mỗi dòng 1 glob đường dẫn tương đối trong CONFIG_DIR; '#' bắt đầu comment).
# Nhờ file này, artifact công khai không bị script tự thêm lại file nhạy cảm.
load_excludes() {
	local f="$CONFIG_DIR/.pi-setup-exclude"
	[ -f "$f" ] || return 0
	local line
	while IFS= read -r line || [ -n "$line" ]; do
		line="${line%%#*}"
		line="$(printf '%s' "$line" | tr -d '[:space:]')"
		[ -n "$line" ] && EXCLUDES+=("$line")
	done <"$f"
}

# Ở chế độ --config-dir, .pi-setup-exclude thường xoá extensions/agentkit-* — nhưng
# nếu người dùng yêu cầu rõ bằng --hooks thì tôn trọng yêu cầu đó (không xoá).
# Ở chế độ --config-dir, .pi-setup-exclude thường xoá extensions/agentkit-* — nhưng
# nếu người dùng yêu cầu rõ bằng --hooks thì tôn trọng yêu cầu đó (không xoá).
# (PROTECT được khai báo + fill ở phía trên, cạnh phần parse --hooks.)

protected_path() { # $1 = đường dẫn tương đối trong CONFIG_DIR
	local p
	for p in "${PROTECT[@]:-}"; do
		[ -n "$p" ] || continue
		case "$1" in
			"$p" | "$p"/*) return 0 ;;
		esac
	done
	return 1
}

# Xoá những file khớp EXCLUDES trong $CONFIG_DIR. Trả về số file đã loại.
prune_excluded() {
	[ "${#EXCLUDES[@]}" -gt 0 ] || {
		printf '0\n'
		return 0
	}
	local removed=0 rel pat f
	while IFS= read -r -d '' f; do
		rel="${f#"$CONFIG_DIR"/}"
		for pat in "${EXCLUDES[@]}"; do
			# shellcheck disable=SC2254
			case "$rel" in
				$pat)
					protected_path "$rel" && break
					rm -f "$f"
					removed=$((removed + 1))
					break
					;;
			esac
		done
	done < <(find "$CONFIG_DIR" -type f -print0 2>/dev/null)

	# Dọn thư mục rỗng còn sót sau khi xoá file (nếu không, mirror sẽ có cây thư mục rỗng).
	EMPTY_DIRS="$(find "$CONFIG_DIR" -type d -empty 2>/dev/null | wc -l | tr -d ' ')"
	if [ "$EMPTY_DIRS" -gt 0 ]; then
		find "$CONFIG_DIR" -type d -empty -delete 2>/dev/null || true
	fi

	printf '%s\n' "$removed"
}

# =====================================================================
# Chế độ 1: ghi plain file vào --config-dir (mirror để git track)
# =====================================================================
if [ -n "$CONFIG_DIR" ]; then
	case "$CONFIG_DIR" in
		"$HOME" | / | "$AGENT_DIR") die "từ chối ghi vào '$CONFIG_DIR' — chọn thư mục riêng, ví dụ ./config" ;;
	esac

	STAGE="$(mktemp -d)"
	trap 'rm -rf "$STAGE"' EXIT
	for item in "${INCLUDE[@]}"; do
		mkdir -p "$STAGE/$(dirname "$item")"
		if [ -d "$AGENT_DIR/$item" ]; then
			cp -RL "$AGENT_DIR/$item" "$STAGE/$item" # -L: dereference symlink (dùng với --skills)
		else
			cp "$AGENT_DIR/$item" "$STAGE/$item"
		fi
	done
	scan_secrets "$STAGE" || true

	if [ "$DRY_RUN" -eq 1 ]; then
		info ""
		info "[dry-run] sẽ mirror vào: $CONFIG_DIR"
		for item in "${INCLUDE[@]}"; do
			info "  $item ($(du -sh "$AGENT_DIR/$item" 2>/dev/null | cut -f1))"
		done
		exit 0
	fi

	mkdir -p "$CONFIG_DIR"
	for item in "${INCLUDE[@]}"; do
		rm -rf "${CONFIG_DIR:?}/$item" # mirror: xoá bản cũ của CHÍNH mục này rồi copy lại
		mkdir -p "$CONFIG_DIR/$(dirname "$item")"
		if [ -d "$AGENT_DIR/$item" ]; then
			cp -RL "$AGENT_DIR/$item" "$CONFIG_DIR/$item"
		else
			cp "$AGENT_DIR/$item" "$CONFIG_DIR/$item"
		fi
	done

	# config nằm ngoài config dir: copy vào mirror + ghi manifest
	ext_collect
	for i in "${!EXT_NAME[@]}"; do
		cp -p "${EXT_SRC[$i]}" "$CONFIG_DIR/${EXT_NAME[$i]}"
	done
	if [ "${#EXT_NAME[@]}" -gt 0 ]; then
		: >"$CONFIG_DIR/$EXTERNAL_MANIFEST"
		for i in "${!EXT_NAME[@]}"; do
			printf '%s=%s\n' "${EXT_NAME[$i]}" "${EXT_TILDE[$i]}" >>"$CONFIG_DIR/$EXTERNAL_MANIFEST"
		done
		# mtime cố định: manifest sinh mới mỗi lần nên nếu để mtime hiện tại thì
		# bundle sẽ khác nhau giữa 2 lần chạy (tar lưu mtime).
		touch -t 200001010000 "$CONFIG_DIR/$EXTERNAL_MANIFEST"
	elif [ -f "$CONFIG_DIR/$EXTERNAL_MANIFEST" ]; then
		rm -f "$CONFIG_DIR/$EXTERNAL_MANIFEST"
	fi

	load_excludes
	EXCLUDED="$(prune_excluded)"

	# --no-statusline: xoá file statusline sau khi mirror.
	for p in "${SKIP[@]:-}"; do
		[ -n "$p" ] || continue
		[ -e "$CONFIG_DIR/$p" ] && rm -f "$CONFIG_DIR/$p"
	done

	# Báo rõ nếu .pi-setup-exclude bị ghi đè bởi một flag opt-in (VD --hooks).
	if [ "${#PROTECT[@]}" -gt 0 ] && [ "${#EXCLUDES[@]}" -gt 0 ]; then
		warn ".pi-setup-exclude bị ghi đè cho: ${PROTECT[*]}"
	fi

	# Cảnh báo file lạ còn sót ở cấp cao nhất (không tự xoá). Bỏ qua dotfile.
	STALE=()
	while IFS= read -r entry; do
		name="$(basename "$entry")"
		[ -z "$name" ] && continue
		case "$name" in .* | "$EXTERNAL_MANIFEST") continue ;; esac
		found=0
		for item in "${INCLUDE[@]}"; do
			# Khớp chính mục đó, hoặc là thư mục cha của một mục lồng bên trong
			# (VD 'model-fallback' chứa mục 'model-fallback/config.json').
			case "$item" in
				"$name" | "$name"/*) found=1 ;;
			esac
		done
		[ "$found" -eq 0 ] && STALE+=("$name")
	done < <(find "$CONFIG_DIR" -maxdepth 1 -mindepth 1 2>/dev/null)
	if [ "${#STALE[@]}" -gt 0 ]; then
		warn "trong $CONFIG_DIR còn mục không thuộc phạm vi backup (không tự xoá): ${STALE[*]}"
	fi

	info ""
	info "✓ đã ghi config: $CONFIG_DIR"
	info "  mục:"
	for item in "${INCLUDE[@]}"; do item_size "$item"; done
	if [ "${#EXCLUDES[@]}" -gt 0 ]; then
		info "  loại trừ: $EXCLUDED file khớp .pi-setup-exclude (${EXCLUDES[*]})"
	fi
	info "  packages: $(pkg_count)"
	if [ "$FLAG_NO_STATUSLINE" -eq 1 ]; then
		info "  statusline: BỬ QUA (--no-statusline)${STATUSLINE_FOUND:+ — đã bỏ ${STATUSLINE_FOUND[*]}}"
	fi
	info "  config extension:"
	for c in "${CONFIG_FOUND[@]}"; do
		info "    $c"
	done
	for i in "${!EXT_NAME[@]}"; do
		info "    ngoài config dir: ${EXT_TILDE[$i]} → ${EXT_NAME[$i]}"
	done
	exit 0
fi

# =====================================================================
# Chế độ 2 (mặc định): đóng gói thành tarball
# =====================================================================
mkdir -p "$(dirname "$OUT")"
TMP="$OUT.tmp.$$"
SCAN_DIR="$(mktemp -d)"
cleanup() {
	trap - ERR
	rm -f "$TMP"
	rm -rf "$SCAN_DIR"
	for d in "${CLEANUP_DIRS[@]:-}"; do
		[ -n "$d" ] && rm -rf "$d"
	done
	return 0
}
trap cleanup EXIT

# Ghi ra file tạm rồi mv → không để lại artifact hỏng nếu bị ngắt giữa chừng.
# 'gzip -n' bỏ timestamp → cùng nội dung thì cùng sha256 (kiểm tra được giữa 2 máy).
TAR_OPTS=(-cf -)
[ "$DEREF" -eq 1 ] && TAR_OPTS=(-hcf -) # -h: dereference symlink (dùng với --skills)

# Config ngoài config dir: stage vào 1 thư mục tạm (dùng -p để giữ mtime → bundle vẫn
# tất định), kèm manifest cho restore biết đích.
ext_collect
EXT_STAGE="$(mktemp -d)"
CLEANUP_DIRS+=("$EXT_STAGE")
TAR_EXTRA=()
if [ "${#EXT_NAME[@]}" -gt 0 ]; then
	for i in "${!EXT_NAME[@]}"; do
		cp -p "${EXT_SRC[$i]}" "$EXT_STAGE/${EXT_NAME[$i]}"
	done
	: >"$EXT_STAGE/$EXTERNAL_MANIFEST"
	for i in "${!EXT_NAME[@]}"; do
		printf '%s=%s\n' "${EXT_NAME[$i]}" "${EXT_TILDE[$i]}" >>"$EXT_STAGE/$EXTERNAL_MANIFEST"
	done
	touch -t 200001010000 "$EXT_STAGE/$EXTERNAL_MANIFEST" # giữ bundle tất định
	TAR_EXTRA=(-C "$EXT_STAGE" "${EXT_NAME[@]}" "$EXTERNAL_MANIFEST")
fi
EXCLUDE_OPTS=()
for p in "${SKIP[@]:-}"; do
	[ -n "$p" ] || continue
	EXCLUDE_OPTS+=("--exclude=$p")
done
# Pattern từ --exclude-file (bỏ qua pattern đã được --hooks yêu cầu rõ)
for pat in "${EXCLUDES[@]:-}"; do
	[ -n "$pat" ] || continue
	skip_pat=0
	for prot in "${PROTECT[@]:-}"; do
		[ -n "$prot" ] || continue
		# shellcheck disable=SC2254
		case "$prot" in
			$pat) skip_pat=1; break ;;
		esac
	done
	if [ "$skip_pat" -eq 1 ]; then
		warn "--hooks ghi đè pattern loại trừ: $pat"
		continue
	fi
	EXCLUDE_OPTS+=("--exclude=$pat")
done

# Lưu ý: không dùng "${EXCLUDE_OPTS[@]:-}" — array rỗng sẽ thành 1 phần tử '' và tar báo lỗi.
if [ "${#EXCLUDE_OPTS[@]}" -gt 0 ]; then
	tar "${TAR_OPTS[@]}" "${EXCLUDE_OPTS[@]}" -C "$AGENT_DIR" "${INCLUDE[@]}" "${TAR_EXTRA[@]}" | gzip -n >"$TMP"
else
	tar "${TAR_OPTS[@]}" -C "$AGENT_DIR" "${INCLUDE[@]}" "${TAR_EXTRA[@]}" | gzip -n >"$TMP"
fi
tar -xzf "$TMP" -C "$SCAN_DIR"
scan_secrets "$SCAN_DIR" || true

if [ "$DRY_RUN" -eq 1 ]; then
	info ""
	info "[dry-run] sẽ ghi bundle: $OUT"
	for item in "${INCLUDE[@]}"; do item_size "$item"; done
	exit 0
fi

mv "$TMP" "$OUT"

# --- Tóm tắt ---
FILE_COUNT="$(tar -tzf "$OUT" | grep -vc '/$' || true)"
if SIZE_BYTES="$(stat -f%z "$OUT" 2>/dev/null)"; then :; else SIZE_BYTES="$(stat -c%s "$OUT" 2>/dev/null || echo 0)"; fi
SIZE="$(awk -v b="$SIZE_BYTES" 'BEGIN { if (b >= 1048576) printf "%.1f MB", b / 1048576; else printf "%.1f KB", b / 1024 }')"
if command -v shasum >/dev/null 2>&1; then
	SHA="$(shasum -a 256 "$OUT" | cut -d' ' -f1)"
else
	SHA="$(sha256sum "$OUT" | cut -d' ' -f1)"
fi

if [ "$QUIET" -eq 1 ]; then
	emit "$OUT  $SHA"
else
	emit ""
	emit "✓ bundle:  $OUT"
	emit "  size:    $SIZE ($SIZE_BYTES byte, $FILE_COUNT file)"
	emit "  mục:"
	for item in "${INCLUDE[@]}"; do item_size "$item"; done
	if [ "${#EXCLUDES[@]}" -gt 0 ]; then
		emit "  loại trừ: ${EXCLUDES[*]}"
	fi
	emit "  packages: $(pkg_count) (từ settings.json)"
	if [ "$FLAG_NO_STATUSLINE" -eq 1 ]; then
		emit "  statusline: BỬ QUA (--no-statusline)${STATUSLINE_FOUND:+ — đã bỏ ${STATUSLINE_FOUND[*]}}"
	fi
	for i in "${!EXT_NAME[@]}"; do
		emit "    ngoài config dir: ${EXT_TILDE[$i]} → ${EXT_NAME[$i]}"
	done
	emit "  config extension:"
	for c in "${CONFIG_FOUND[@]}"; do
		emit "    $c"
	done
	emit "  sha256:  $SHA"
if [ "$FLAG_AUTH" -eq 1 ]; then
	emit "  ⚠ bundle chứa auth.json (credential) — KHÔNG đưa lên nơi công khai"
fi
if [ "$FLAG_MISSIONS" -eq 1 ] || [ "$FLAG_SESSIONS" -eq 1 ]; then
	emit "  ⚠ bundle chứa dữ liệu nhạy cảm (missions/sessions) — KHÔNG đưa lên nơi công khai"
fi
fi
