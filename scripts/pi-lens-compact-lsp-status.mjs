#!/usr/bin/env node
/**
 * pi-lens-compact-lsp-status.mjs — rút gọn dòng status LSP của pi-lens trong
 * statusline của pi: `LSP ✓` / `LSP ✗` thay vì liệt kê tên LSP server đang chạy.
 *
 * Vì sao phải vá chứ không cấu hình được: pi-lens hardcode chuỗi trong bundle
 * (`updateLspStatus`):
 *
 *   parts.push(theme.fg("success", `LSP Active: ${activeIds.join(", ")}`));
 *   parts.push(theme.fg("error",   `LSP Failed: ${failedIds.join(", ")}`));
 *   setStatus("pi-lens-lsp", parts.length > 0 ? parts.join(" · ") : theme.fg("dim", "LSP Inactive"));
 *
 * `~/.pi-lens/config.json` không có key nào cho dòng này (chỉ có lsp.enabled,
 * widget.visible, format.enabled, autofix.enabled, ui.compactToolLine,
 * actionableWarnings.*), và `LENS_FLAGS` cũng không có flag tương ứng — gần nhất là
 * `lens-compact-tool-line` → `ui.compactToolLine`, nhưng nó gộp các hàng tool call +
 * result trong transcript chứ không đụng statusline.
 *
 * Extension khác cũng không sửa hộ được: `ctx.ui` chỉ có `setStatus` (ghi), còn
 * `footerData.getExtensionStatuses()` chỉ tồn tại BÊN TRONG footer renderer — mà
 * footer đang do `pi-footer` nắm (`setFooter` last-wins), nên widget `Pi Extension
 * Status` của pi-footer chỉ render nguyên văn giá trị (option `trimValue` của nó cắt
 * phần ĐẦU chuỗi, không đụng được phần danh sách server ở đuôi).
 *
 * Cách vá: mỗi "anchor" phải xuất hiện ĐÚNG 1 LẦN trong bundle, ở dạng nguyên bản
 * hoặc dạng gọn. Anchor không xuất hiện, hoặc xuất hiện nhiều lần → script DỪNG
 * (exit 1) chứ không đoán: thà không vá còn hơn vá sai. Trạng thái nửa vá (do lần
 * chạy trước bị ngắt) được nhận diện riêng và script hoàn tất nốt phần còn thiếu.
 * Ghi file theo kiểu atomic (ghi file tạm rồi rename) nên không để lại bundle cụt.
 *
 * ⚠ npm ghi đè lại `dist/index.js` mỗi lần `pi update` hoặc cài lại pi-lens → chạy
 * lại script này. Đây là lý do script được để trong repo snapshot này.
 *
 * Dùng:
 *   node scripts/pi-lens-compact-lsp-status.mjs            # vá (no-op nếu đã vá)
 *   node scripts/pi-lens-compact-lsp-status.mjs --check    # chỉ báo trạng thái, không ghi
 *   node scripts/pi-lens-compact-lsp-status.mjs --revert    # trả bundle về nguyên bản
 *   node scripts/pi-lens-compact-lsp-status.mjs --pkg <path tới pi-lens/dist/index.js>
 *
 * Exit code: 0 = đang ở trạng thái mong muốn (đã vá, vừa vá xong, vừa revert xong)
 * · 1 = chưa vá (khi --check) hoặc bundle không nhận dạng được nên không tự sửa
 * · 2 = lỗi môi trường (không thấy bundle pi-lens, tham số sai).
 */
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

/** Version đã kiểm chứng khi viết script. Version khác chỉ cảnh báo, không chặn. */
const VALIDATED_VERSION = "4.1.6";

/**
 * Mỗi mục là 1 anchor: `from` (nguyên bản) → `to` (gọn) + `compact` để in báo cáo.
 * `from`/`to` phải khác nhau và không được là chuỗi con của nhau.
 */
const PATCHES = [
	{
		what: "LSP Active: <danh sách server>",
		compact: '"LSP ✓"',
		from: 'parts.push(theme.fg("success", `LSP Active: ${activeIds.join(", ")}`));',
		to: 'parts.push(theme.fg("success", "LSP ✓"));',
	},
	{
		what: "LSP Failed: <danh sách server>",
		compact: '"LSP ✗"',
		from: 'parts.push(theme.fg("error", `LSP Failed: ${failedIds.join(", ")}`));',
		to: 'parts.push(theme.fg("error", "LSP ✗"));',
	},
	{
		what: "LSP Inactive",
		compact: 'mờ, "LSP ✗"',
		from: 'theme.fg("dim", "LSP Inactive")',
		to: 'theme.fg("dim", "LSP ✗")',
	},
];

const PKG_ENTRY = path.join("npm", "node_modules", "pi-lens", "dist", "index.js");

/** pi cài package vào cây npm riêng của config dir. */
function agentDir() {
	return process.env.PI_CODING_AGENT_DIR || path.join(os.homedir(), ".pi", "agent");
}

function pkgCandidates() {
	return [...new Set([
		path.join(agentDir(), PKG_ENTRY),
		path.join(os.homedir(), ".pi", "agent", PKG_ENTRY),
	])];
}

const say = (line = "") => process.stdout.write(`${line}\n`);
const complain = (line = "") => process.stderr.write(`${line}\n`);

function usage() {
	say(`Dùng: node scripts/pi-lens-compact-lsp-status.mjs [tùy chọn]

  --check       Chỉ báo trạng thái bundle, không ghi gì
  --revert      Trả bundle về nguyên bản (bỏ phần rút gọn)
  --pkg PATH    Đường dẫn pi-lens/dist/index.js (mặc định: tự dò trong ~/.pi/agent/npm)
  -h, --help    In hướng dẫn này

Không tham số = vá. Chạy lại sau mỗi lần \`pi update\` vì npm ghi đè dist/index.js.

Exit code: 0 = đã vá / vừa vá xong / vừa revert xong · 1 = chưa vá (--check) hoặc
bundle không nhận dạng được nên không tự sửa · 2 = lỗi môi trường.`);
}

function countOccurrences(haystack, needle) {
	let count = 0;
	let index = haystack.indexOf(needle);
	while (index !== -1) {
		count += 1;
		index = haystack.indexOf(needle, index + needle.length);
	}
	return count;
}

function lineOf(haystack, needle) {
	const index = haystack.indexOf(needle);
	if (index === -1) return undefined;
	return haystack.slice(0, index).split("\n").length;
}

/**
 * `original` (chưa vá) · `patched` (đã vá) · `mixed` (vá dở, mỗi anchor vẫn đúng 1
 * lần) · `unknown` (anchor thiếu hoặc lặp → không tự sửa).
 */
function bundleState(source) {
	const rows = PATCHES.map((patch) => ({
		patch,
		fromCount: countOccurrences(source, patch.from),
		toCount: countOccurrences(source, patch.to),
	}));
	const wellFormed = rows.every((row) => row.fromCount + row.toCount === 1);
	const patched = rows.filter((row) => row.toCount === 1).length;
	const state = !wellFormed
		? "unknown"
		: patched === 0
			? "original"
			: patched === PATCHES.length
				? "patched"
				: "mixed";
	return { rows, state, patched };
}

const STATE_LABEL = {
	original: "nguyên bản (chưa vá)",
	patched: "đã vá (dòng status gọn)",
	mixed: "VÁ DỞ (một phần anchor đã gọn)",
	unknown: "KHÔNG nhận dạng được",
};

function readVersion(pkgFile) {
	try {
		return JSON.parse(fs.readFileSync(pkgFile, "utf8")).version;
	} catch {
		return undefined;
	}
}

function report(pkgPath, source) {
	say(`=== ${pkgPath}`);
	const version = readVersion(path.join(path.dirname(pkgPath), "..", "package.json"));
	if (version) {
		const drift = version === VALIDATED_VERSION ? "" : `  ⚠ khác version đã kiểm chứng (${VALIDATED_VERSION}) — chỉ chạy vì khớp đủ ${PATCHES.length} anchor`;
		say(`  pi-lens:        ${version}${drift}`);
	}
	const { rows, state } = bundleState(source);
	say(`  trạng thái:     ${STATE_LABEL[state]}`);
	for (const row of rows) {
		const line = lineOf(source, state === "patched" ? row.patch.to : row.patch.from);
		const counts = state === "unknown" ? ` [khớp from×${row.fromCount} to×${row.toCount}]` : "";
		say(`    ${row.patch.what} → ${row.patch.compact}${line ? `  (dòng ${line})` : ""}${counts}`);
	}
	return state;
}

/** Ghi atomic: file tạm cùng thư mục rồi rename — không để lại bundle cụt nếu bị ngắt. */
function writeAtomic(file, content) {
	const tmp = `${file}.compact-lsp-status.tmp`;
	try {
		fs.writeFileSync(tmp, content, "utf8");
		fs.renameSync(tmp, file);
	} catch (error) {
		try {
			fs.rmSync(tmp, { force: true });
		} catch {
			// dọn file tạm là best-effort
		}
		throw error;
	}
}

// --- Tham số ---
let pkgPath;
let mode = "apply";
for (let index = 2; index < process.argv.length; index += 1) {
	const arg = process.argv[index];
	if (arg === "-h" || arg === "--help") {
		usage();
		process.exit(0);
	} else if (arg === "--check" || arg === "--dry-run") {
		mode = "check";
	} else if (arg === "--revert") {
		mode = "revert";
	} else if (arg === "--pkg") {
		pkgPath = process.argv[index + 1];
		if (!pkgPath) {
			usage();
			complain("\n✗ --pkg cần tham số PATH");
			process.exit(2);
		}
		index += 1;
	} else {
		usage();
		complain(`\n✗ tham số không hợp lệ: ${arg}`);
		process.exit(2);
	}
}

if (!pkgPath) {
	pkgPath = pkgCandidates().find((candidate) => fs.existsSync(candidate));
}
if (!pkgPath) {
	complain("✗ không thấy bundle pi-lens. Đã thử:");
	for (const candidate of pkgCandidates()) complain(`    ${candidate}`);
	complain("  (cài pi-lens trước: pi install npm:pi-lens, hoặc trỏ bằng --pkg)");
	process.exit(2);
}
if (!fs.existsSync(pkgPath)) {
	complain(`✗ không thấy file: ${pkgPath}`);
	process.exit(2);
}

const source = fs.readFileSync(pkgPath, "utf8");
const state = report(pkgPath, source);

if (state === "unknown") {
	complain(`\n✗ bundle không nhận dạng được: mỗi anchor phải khớp đúng 1 lần, đang thiếu hoặc lặp.`);
	complain("  pi-lens có thể đã đổi cách viết `updateLspStatus`, hoặc bundle đã bị sửa tay.");
	complain("  KHÔNG tự sửa. Cách lành nhất: cài lại pi-lens rồi chạy lại script này:");
	complain("    npm install --prefix \"$HOME/.pi/agent/npm\" pi-lens@<version>");
	complain("  Sau đó cập nhật PATCHES trong script này nếu pi-lens đổi định dạng thật.");
	process.exit(1);
}

if (mode === "check") {
	if (state === "patched") {
		say("\n✓ đã vá — dòng status LSP gọn.");
		process.exit(0);
	}
	say(`\n✗ CHƯA vá (${STATE_LABEL[state]}) — dòng status LSP ${state === "mixed" ? "mới gọn một phần" : "vẫn liệt kê tên server"}.`);
	say("  vá: node scripts/pi-lens-compact-lsp-status.mjs");
	process.exit(1);
}

const wantPatched = mode !== "revert";
const anchors = bundleState(source).rows.filter((row) => (wantPatched ? row.fromCount === 1 : row.toCount === 1));
const alreadyDone = state === (wantPatched ? "patched" : "original");

if (alreadyDone) {
	say(`\n✓ không cần làm gì — bundle đang ${STATE_LABEL[state]}.`);
	process.exit(0);
}

let next = source;
for (const row of anchors) {
	const [from, to] = wantPatched ? [row.patch.from, row.patch.to] : [row.patch.to, row.patch.from];
	next = next.replace(from, to);
}
writeAtomic(pkgPath, next);

const verify = bundleState(fs.readFileSync(pkgPath, "utf8")).state;
const expected = wantPatched ? "patched" : "original";
if (verify !== expected) {
	complain(`\n✗ ghi xong nhưng kiểm tra lại thấy trạng thái "${STATE_LABEL[verify] ?? verify}" — kiểm tra tay: ${pkgPath}`);
	process.exit(1);
}

say(`\n✓ ${wantPatched ? `đã vá${state === "mixed" ? " nốt phần còn thiếu" : ""}` : "đã revert về nguyên bản"} — dòng status LSP: ${wantPatched ? '"LSP ✓" / "LSP ✗" (khi vừa có server chạy vừa có server lỗi: "LSP ✓ · LSP ✗")' : "liệt kê tên server"}`);
if (wantPatched) {
	say("  ⚠ npm ghi đè dist/index.js mỗi lần `pi update` → chạy lại script này.");
	say("  ⚠ pi đang chạy phải mở lại session mới thấy thay đổi (extension đã load trong RAM).");
}
process.exit(0);
