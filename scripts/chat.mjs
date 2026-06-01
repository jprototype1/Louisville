#!/usr/bin/env node
// Friendly local CLI for OpenACP — chat with / multiplex the same agent sessions
// you'd use over Telegram, right from the terminal.
//
//   chat                 pick a session from a menu (or start a new one)
//   chat new             start a fresh session and chat
//   chat ls              list sessions and exit
//   chat <id|partial|#>  open a session directly (by id, prefix, or list number)
//   chat --help          this help
//
// In a chat:  type a prompt → the reply streams in. Slash commands:
//   /new   /switch   /status   /model <name>   /bypass on|off   /cancel   /clear   /help   /exit

import fs from "node:fs";
import path from "node:path";
import readline from "node:readline";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const HIST = path.join(ROOT, ".openacp", "history");
const TTY = process.stdout.isTTY;
const C = TTY
	? { r: "\x1b[0m", d: "\x1b[2m", b: "\x1b[1m", blue: "\x1b[34m", grn: "\x1b[32m", yel: "\x1b[33m", cyn: "\x1b[36m", mag: "\x1b[35m", red: "\x1b[31m", gry: "\x1b[90m" }
	: new Proxy({}, { get: () => "" });

// ── openacp plumbing ─────────────────────────────────────────────────────────
import { execSync } from "node:child_process";
const OPENACP = (() => {
	const candidates = [];
	try { const base = `${process.env.HOME}/.nvm/versions/node`; for (const v of fs.readdirSync(base)) candidates.push(path.join(base, v, "bin", "openacp")); } catch {}
	candidates.push(`${process.env.HOME}/.local/bin/openacp`, "/usr/local/bin/openacp", "/opt/homebrew/bin/openacp");
	for (const c of candidates) if (fs.existsSync(c)) return c;
	try { const p = execSync("command -v openacp", { shell: "/bin/bash", encoding: "utf8" }).trim(); if (p) return p; } catch {}
	console.error(`${C.red}openacp not found — is it installed? (npm i -g @openacp/cli)${C.r}`); process.exit(1);
})();
// stdio stdin = "ignore" so these subprocess calls never touch the terminal's
// stdin (otherwise the interactive menu/prompt can't read your keystrokes).
const api = (...a) => execFileSync(OPENACP, ["api", ...a], { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
const apiQuiet = (...a) => { try { return api(...a); } catch (e) { return String(e.stderr || e.message || e); } };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ── session data ─────────────────────────────────────────────────────────────
function sessions() {
	// parse `openacp api status`:  "  <id>  claude  <status>  \"<name>\""
	const out = apiQuiet("status");
	const rows = [];
	for (const line of out.split("\n")) {
		const m = line.match(/^\s+([A-Za-z0-9_-]{6,})\s+\S+\s+(\w+)\s*(?:"(.*)")?\s*$/);
		if (m) rows.push({ id: m[1], status: m[2], name: m[3] || "(untitled)" });
	}
	return rows;
}
function turnsOf(id) { try { return JSON.parse(fs.readFileSync(path.join(HIST, `${id}.json`), "utf8")).turns || []; } catch { return []; } }
function promptActive(id) { try { return /Prompt active\s*:\s*true/i.test(api("session", id)); } catch { return false; } }
function modelOf(id) { const m = apiQuiet("session-config", id).match(/current:\s*(\S+)/); return m ? m[1] : "?"; }
function createSession() { const id = (apiQuiet("new", "claude").match(/ID\s*:\s*([A-Za-z0-9_-]+)/) || [])[1]; return id; }

// Menu/list view: hide dead (cancelled) sessions, active first. Numbers here
// match resolveTarget(number) so picking "2" always means the 2nd row shown.
const RANK = { active: 0, initializing: 1, finished: 2 };
function visible() {
	return sessions()
		.filter((s) => s.status !== "cancelled")
		.sort((a, b) => (RANK[a.status] ?? 3) - (RANK[b.status] ?? 3));
}
function resolveTarget(arg) {
	if (/^\d+$/.test(arg)) { return visible()[+arg - 1]?.id; }
	if (fs.existsSync(path.join(HIST, `${arg}.json`))) return arg;
	return fs.readdirSync(HIST).map((f) => f.replace(/\.json$/, "")).find((x) => x.startsWith(arg)) || arg;
}

// ── rendering ────────────────────────────────────────────────────────────────
const badge = (s) => (s === "active" ? `${C.grn}● active  ${C.r}` : s === "initializing" ? `${C.yel}◌ init    ${C.r}` : `${C.gry}○ ${s.padEnd(8)}${C.r}`);
function printList(rows) {
	if (!rows.length) return console.log(`${C.gry}  (no sessions yet — 'chat new' to start one)${C.r}`);
	console.log(`\n${C.b}Sessions${C.r}`);
	rows.forEach((r, i) => console.log(`  ${C.cyn}${String(i + 1).padStart(2)}${C.r}  ${badge(r.status)}  ${C.d}${r.id}${C.r}  ${r.name}`));
}
function printAssistant(t) {
	for (const s of t.steps || []) {
		if (s.type === "text" && s.content?.trim()) console.log(`${C.grn}🤖${C.r} ${s.content.trim()}`);
		else if (s.type === "tool_call") {
			const name = s.toolName || s.name || s.type;
			const d = s.filePath || s.input?.file_path || s.input?.command || s.command || "";
			console.log(`   ${C.gry}🔧 ${name}${d ? `: ${String(d).slice(0, 80)}` : ""}${C.r}`);
		}
	}
}
function spinner(label) {
	if (!TTY) return { stop() {} };
	const f = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏".split(""); let i = 0;
	const t = setInterval(() => process.stdout.write(`\r${C.gry}${f[i++ % f.length]} ${label}${C.r}`), 80);
	return { stop() { clearInterval(t); process.stdout.write("\r\x1b[K"); } };
}

async function streamReply(id, before) {
	const spin = spinner("thinking…");
	let printed = before, stable = 0, first = true;
	const start = Date.now();
	while (Date.now() - start < 180000) {
		await sleep(600);
		const turns = turnsOf(id);
		if (turns.length > printed) {
			if (first) { spin.stop(); first = false; }
			for (let i = printed; i < turns.length; i++) if (turns[i].role === "assistant") printAssistant(turns[i]);
			printed = turns.length; stable = 0;
		} else stable += 600;
		if (printed > before && stable >= 1400 && !promptActive(id)) break;
	}
	spin.stop();
}

const HELP_IN = `${C.b}commands${C.r}
  /new            start a fresh session    /switch   back to the menu
  /status         session details          /model <name>   e.g. sonnet | haiku | default
  /bypass on|off  skip permission prompts  /cancel   end this session
  /clear          clear the screen         /help     this list      /exit`;

// ── chat REPL (resolves with: another id to switch to, "menu", or null to quit) ─
function chat(id) {
	return new Promise((resolve) => {
		console.log(`\n${C.b}💬 ${sessions().find((s) => s.id === id)?.name || id}${C.r}  ${C.d}${id} · ${modelOf(id)}${C.r}`);
		for (const t of turnsOf(id).slice(-2)) if (t.role === "assistant") printAssistant(t);
		console.log(`${C.gry}(type a message, or /help)${C.r}`);
		const rl = readline.createInterface({ input: process.stdin, output: process.stdout, prompt: `${C.blue}you ▸${C.r} ` });
		let settled = false;
		const finish = (v) => { if (settled) return; settled = true; try { rl.close(); } catch {} resolve(v); };
		const resume = () => { if (!settled) { try { rl.resume(); rl.prompt(); } catch {} } };
		rl.prompt();
		rl.on("line", async (raw) => {
			const line = raw.trim();
			if (line === "/exit" || line === "/quit") return finish(null);
			if (line === "/switch" || line === "/menu" || line === "/sessions") return finish("menu");
			if (line === "/new") return finish(createSession());
			if (line === "/cancel") { apiQuiet("cancel", id); console.log(`${C.gry}session ended${C.r}`); return finish("menu"); }
			if (line === "/help") { console.log(HELP_IN); return rl.prompt(); }
			if (line === "/clear") { console.clear(); return rl.prompt(); }
			if (line === "/status") { console.log(C.d + apiQuiet("session", id).trim() + C.r); return rl.prompt(); }
			if (line.startsWith("/model ")) { console.log(C.gry + apiQuiet("session-config", id, "set", "model", line.slice(7).trim()).trim() + C.r); return rl.prompt(); }
			if (line.startsWith("/bypass ")) { console.log(C.gry + apiQuiet("bypass", id, line.slice(8).trim()).trim() + C.r); return rl.prompt(); }
			if (!line) return rl.prompt();
			const before = turnsOf(id).length;
			rl.pause();
			const sent = apiQuiet("send", id, line);
			if (/error|not found/i.test(sent)) { console.log(`${C.red}${sent.trim()}${C.r}`); return resume(); }
			await streamReply(id, before);
			resume();
		});
		rl.on("close", () => finish(null));
		rl.on("SIGINT", () => finish(null));
	});
}

function ask(q) {
	return new Promise((resolve) => {
		const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
		rl.question(q, (a) => { rl.close(); resolve(a.trim()); });
	});
}
async function menu() {
	const rows = visible();
	printList(rows);
	const a = await ask(`\n${C.b}Pick #${C.r}, ${C.cyn}n${C.r}ew, or ${C.cyn}q${C.r}uit: `);
	if (a === "" || a === "q") return null;
	if (a === "n") return createSession();
	const i = parseInt(a, 10);
	if (i >= 1 && i <= rows.length) return rows[i - 1].id;
	console.log(`${C.red}?${C.r}`); return menu();
}

// ── dispatch ──────────────────────────────────────────────────────────────────
const [cmd, ...rest] = process.argv.slice(2);
function printHelp() {
	console.log(`${C.b}chat${C.r} — friendly local CLI for OpenACP sessions
  ${C.cyn}chat${C.r}                 pick a session from a menu (or start new)
  ${C.cyn}chat new${C.r}             start a fresh session and chat
  ${C.cyn}chat ls${C.r}              list sessions and exit
  ${C.cyn}chat <id|partial|#>${C.r}  open a session directly
  ${C.cyn}chat --help${C.r}          this help
${HELP_IN}`);
}

let current;
if (cmd === "--help" || cmd === "-h") { printHelp(); process.exit(0); }
else if (cmd === "ls" || cmd === "list") { printList(rest[0] === "all" ? sessions() : visible()); process.exit(0); }
else if (cmd === "new") current = createSession();
else if (cmd) current = resolveTarget(cmd);
else current = await menu();

// main loop: chat → (switch → menu / new → id / exit → quit)
for (;;) {
	if (!current) break; // null/undefined = quit
	current = await chat(current); // returns: id (switch/new), "menu", or null (exit)
	if (current === "menu") current = await menu();
}
console.log(`${C.gry}bye 👋${C.r}`);
process.exit(0);
