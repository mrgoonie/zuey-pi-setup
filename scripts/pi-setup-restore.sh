#!/usr/bin/env bash
#
# pi-setup-restore.sh — dựng lại setup pi trên máy mới
#
#   ./pi-setup-restore.sh --scratch                    # test vào thư mục tạm, không đụng config thật
#   ./pi-setup-restore.sh --from-config ./config --install --verify
#   ./pi-setup-restore.sh --install --verify           # tự tìm bundle hoặc config/ cùng repo
#
# Mặc định: copy đè vào ~/.pi/agent. settings.json cũ được snapshot trước khi đè.
# Không hỏi xác nhận — rủi ro được xử lý bằng snapshot + cảnh báo ra stderr.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$(basename "$SCRIPT_DIR")" = "scripts" ]; then
	ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
else
	ROOT="$SCRIPT_DIR"
fi

TARGET="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
SOURCE=""
BUNDLE=""
DO_INSTALL=0
DO_VERIFY=0
WITH_TRUST=0
DRY_RUN=0
SCRATCH=0

# Manifest đi kèm artifact liệt kê config extension nằm NGOÀI config dir của pi
# (do pi-setup-backup.sh ghi). Mỗi dòng: <tên file trong artifact>=<đường dẫn dạng ~>
EXTERNAL_MANIFEST="external-configs.txt"

# Nội dung được phép restore. Có gì trong nguồn thì copy cái đó.
# 'hooks' không cần liệt kê riêng: chúng nằm trong cây extensions/.
# 'model-fallback/config.json' là file lồng trong thư mục riêng (pi-model-fallback); chỉ
# restore file config, KHÔNG restore model-fallback/state.json (state theo máy).
ITEMS=(settings.json APPEND_SYSTEM.md models-store.json advisor.json 99extensions.json model-fallback/config.json extensions skills memory missions sessions auth.json)

info() { printf '%s\n' "$*"; }
warn() { printf '⚠  %s\n' "$*" >&2; }
die() { printf '✗  %s\n' "$*" >&2; exit 1; }

# Báo rõ chỗ chết thay vì thoát im lặng khi set -e kích hoạt.
trap 'printf "✗  lỗi không mong đợi tại %s dòng %s\n" "${BASH_SOURCE[0]##*/}" "$LINENO" >&2' ERR

usage() {
	cat <<'EOF'
Dùng: pi-setup-restore.sh [tùy chọn]

  --from-config DIR  Restore từ thư mục config/ (plain file, không cần tarball)
  --bundle FILE      Restore từ file .tar.gz (mặc định: <repo>/pi-setup-portable.tar.gz)
  --target DIR       Thư mục config đích (mặc định: $PI_CODING_AGENT_DIR hoặc ~/.pi/agent)
  --scratch          Test vào thư mục tạm — KHÔNG đụng config thật
  --install          Sau khi restore, chạy pi 1 lần để tự cài toàn bộ extension (~150s)
  --verify           So số extension đã cài với số package trong settings.json
  --with-trust       Copy cả trust.json (mặc định bỏ — chứa path của máy cũ)
  --dry-run          Chỉ in ra sẽ làm gì, không ghi gì
  -h, --help         In hướng dẫn này

Nếu không chỉ định nguồn, script tự dùng theo thứ tự:
  1) <repo>/pi-setup-portable.tar.gz   2) <repo>/config

Biến môi trường:
  PI_CODING_AGENT_DIR   Thư mục config của pi (mặc định ~/.pi/agent)
EOF
}

while [ $# -gt 0 ]; do
	case "$1" in
		--from-config) [ $# -ge 2 ] || die "--from-config cần tham số DIR"; SOURCE="$2"; shift 2 ;;
		--bundle) [ $# -ge 2 ] || die "--bundle cần tham số FILE"; BUNDLE="$2"; shift 2 ;;
		--target) [ $# -ge 2 ] || die "--target cần tham số DIR"; TARGET="$2"; shift 2 ;;
		--scratch) SCRATCH=1; shift ;;
		--install) DO_INSTALL=1; shift ;;
		--verify) DO_VERIFY=1; shift ;;
		--with-trust) WITH_TRUST=1; shift ;;
		--dry-run) DRY_RUN=1; shift ;;
		-h | --help) usage; exit 0 ;;
		*) usage >&2; die "tham số không hợp lệ: $1" ;;
	esac
done

# --- Xác định nguồn ---
if [ -z "$SOURCE" ] && [ -z "$BUNDLE" ]; then
	if [ -f "$ROOT/pi-setup-portable.tar.gz" ]; then
		BUNDLE="$ROOT/pi-setup-portable.tar.gz"
	elif [ -d "$ROOT/config" ]; then
		SOURCE="$ROOT/config"
	else
		die "không tìm thấy nguồn nào.

Đã thử: $ROOT/pi-setup-portable.tar.gz và $ROOT/config
Tạo bundle trên máy cũ trước:  ./pi-setup-backup.sh"
	fi
fi

# --- Xác định đích ---
if [ "$SCRATCH" -eq 1 ]; then
	TARGET="$(mktemp -d)/pi-agent"
	info "→ chế độ scratch (không đụng config thật): $TARGET"
else
	info "→ đích: $TARGET"
fi
[ "$DRY_RUN" -eq 1 ] || mkdir -p "$TARGET"

CLEANUP=()
cleanup() {
	trap - ERR # cleanup không được báo lỗi (test '[ -n ]' sai sẽ kích ERR → exit != 0 giả)
	[ "${#CLEANUP[@]}" -gt 0 ] || return 0
	for p in "${CLEANUP[@]}"; do
		[ -n "$p" ] && rm -rf "$p"
	done
	return 0
}
trap cleanup EXIT

# --- Chuẩn bị nguồn (giải nén nếu là tarball) ---
if [ -n "$BUNDLE" ]; then
	command -v tar >/dev/null 2>&1 || die "thiếu lệnh 'tar'"
	[ -f "$BUNDLE" ] || die "không thấy bundle: $BUNDLE"
	SRC="$(mktemp -d)"
	CLEANUP+=("$SRC")
	tar -xzf "$BUNDLE" -C "$SRC"
	info "→ nguồn: bundle $BUNDLE"
else
	[ -d "$SOURCE" ] || die "không thấy thư mục config: $SOURCE"
	SRC="$(cd "$SOURCE" && pwd)"
	info "→ nguồn: $SRC"
fi

[ -f "$SRC/settings.json" ] || warn "nguồn không có settings.json — sẽ KHÔNG có extension nào được cài!"

# --- Snapshot config cũ trước khi ghi đè ---
if [ "$DRY_RUN" -eq 0 ]; then
	STAMP="$(date +%Y%m%d-%H%M%S)"
	if [ -f "$TARGET/settings.json" ]; then
		cp "$TARGET/settings.json" "$TARGET/settings.json.bak.$STAMP"
		warn "đã snapshot settings.json cũ → settings.json.bak.$STAMP"
	fi
	# auth.json là credential: ghi đè mà không sao lưu là không thể khôi phục.
	if [ -f "$TARGET/auth.json" ] && [ -f "$SRC/auth.json" ]; then
		cp "$TARGET/auth.json" "$TARGET/auth.json.bak.$STAMP"
		warn "đã snapshot auth.json cũ → auth.json.bak.$STAMP"
	fi
fi

# --- Copy ---
RESTORED=()
for item in "${ITEMS[@]}"; do
	src_path="$SRC/$item"
	[ -e "$src_path" ] || continue
	if [ "$DRY_RUN" -eq 1 ]; then
		info "  [dry-run] $item"
		continue
	fi
	if [ -d "$src_path" ]; then
		mkdir -p "$TARGET/$item"
		cp -R "$src_path/." "$TARGET/$item/"
	else
		mkdir -p "$(dirname "$TARGET/$item")" # mục lồng nhau, VD model-fallback/config.json
		cp "$src_path" "$TARGET/$item"
	fi
	RESTORED+=("$item")
done

if [ "$WITH_TRUST" -eq 1 ]; then
	if [ -f "$SRC/trust.json" ] && [ "$DRY_RUN" -eq 0 ]; then
		cp "$SRC/trust.json" "$TARGET/trust.json"
		RESTORED+=("trust.json")
	fi
else
	warn "bỏ qua trust.json (dùng --with-trust nếu path trên máy mới giống máy cũ)"
fi

# --- Config extension nằm ngoài config dir (theo manifest trong nguồn) ---
if [ -f "$SRC/$EXTERNAL_MANIFEST" ]; then
	while IFS='=' read -r ext_name ext_dest; do
		[ -n "$ext_name" ] || continue
		if [ ! -f "$SRC/$ext_name" ]; then
			warn "$ext_name có trong $EXTERNAL_MANIFEST nhưng thiếu trong nguồn — bỏ qua"
			continue
		fi
		ext_target="${ext_dest/#\~/$HOME}"
		if [ "$DRY_RUN" -eq 1 ]; then
			info "  [dry-run] (ngoài config dir) $ext_name → $ext_target"
			continue
		fi
		mkdir -p "$(dirname "$ext_target")"
		if [ -f "$ext_target" ] && [ "$DRY_RUN" -eq 0 ]; then
			cp -p "$ext_target" "$ext_target.bak.$(date +%Y%m%d-%H%M%S)"
			warn "đã snapshot $ext_target cũ"
		fi
		cp -p "$SRC/$ext_name" "$ext_target"
		RESTORED+=("$ext_target")
	done <"$SRC/$EXTERNAL_MANIFEST"
fi

[ "$DRY_RUN" -eq 1 ] && {
	info ""
	info "dry-run xong — không ghi gì."
	exit 0
}

# Đếm package bằng NODE, không dùng python3: pi chắc chắn có Node, còn python3 thì không
# (Windows thường thiếu, hoặc gặp stub Microsoft Store báo lỗi) — '?' ở đây sẽ làm
# --verify luôn cảnh báo sai dù extension đã cài đủ.
PKG_COUNT="?"
if command -v node >/dev/null 2>&1; then
	PKG_COUNT="$(node -e 'try{process.stdout.write(String((JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).packages||[]).length))}catch(e){process.exit(1)}' "$TARGET/settings.json" 2>/dev/null || echo '?')"
fi

info ""
info "✓ đã restore: ${RESTORED[*]:-không có gì}"
info "  đích:     $TARGET"
if [ -f "$TARGET/auth.json" ] && [ -f "$SRC/auth.json" ]; then
	warn "auth.json đã bị ghi đè từ nguồn — chạy 'pi auth check' để xác nhận credential còn dùng được"
fi
info "  packages: $PKG_COUNT (sẽ được pi tự cài ở lần chạy đầu)"

# --- Tự cài extension (chạy pi 1 lần, headless) ---
# Không dùng 'ls | wc -l' trực tiếp: với 'set -o pipefail', thư mục npm/node_modules
# chưa tồn tại (máy mới tinh) làm pipeline fail → set -e giết script im lặng.
installed_count() {
	if [ -d "$1/npm/node_modules" ]; then
		ls -1 "$1/npm/node_modules" 2>/dev/null | wc -l | tr -d ' '
	else
		printf '0\n'
	fi
}

if [ "$DO_INSTALL" -eq 1 ]; then
	command -v pi >/dev/null 2>&1 || die "chưa có lệnh 'pi'. Cài trước:  npm i -g @earendil-works/pi-coding-agent"
	before="$(installed_count "$TARGET")"
	LOG="$TARGET/pi-setup-install.log"
	info ""
	info "→ đang cài $PKG_COUNT extension (chờ ~150s)..."
	start="$(date +%s)"
	if printf '' | PI_CODING_AGENT_DIR="$TARGET" pi --mode rpc --no-session >"$LOG" 2>&1; then
		:
	else
		warn "pi thoát với lỗi — xem log: $LOG"
	fi
	elapsed="$(( $(date +%s) - start ))"
	after="$(installed_count "$TARGET")"
	info "  xong sau ${elapsed}s · module dirs: $before → $after"
	if grep -qiE 'npm err|ERR!' "$LOG" 2>/dev/null; then
		warn "có lỗi npm trong log: $LOG"
	fi
fi

# --- Kiểm tra ---
if [ "$DO_VERIFY" -eq 1 ]; then
	command -v pi >/dev/null 2>&1 || die "chưa có lệnh 'pi' để verify"
	have="$(PI_CODING_AGENT_DIR="$TARGET" pi list 2>/dev/null | grep -c '^  npm:' || true)"
	info ""
	if [ "$have" = "$PKG_COUNT" ]; then
		info "✓ verify: $have/$PKG_COUNT extension khớp"
	else
		warn "verify: có $have/$PKG_COUNT extension — chạy lại với --install, hoặc 'pi update --all'"
	fi
fi

info ""
info "Bước tiếp theo:"
info "  1. mở pi rồi /login cho từng provider   (opencode-go, deepseek, openai-codex)"
info "  2. pi auth check --provider opencode-go"
info "  3. thử 1 extension, ví dụ /btw <câu hỏi>"
[ "$SCRATCH" -eq 1 ] && info "  (scratch) kiểm tra tay:  PI_CODING_AGENT_DIR=$TARGET pi list"
exit 0
