#!/usr/bin/env node
// Local CLI to drive / multiplex OpenACP conversations from the terminal — an
// alternative (or companion) to Telegram. Talk to the same agent + sessions, no
// phone needed.
//
//   node scripts/chat.mjs                 list sessions
//   node scripts/chat.mjs new             create a new session (claude, this repo)
//   node scripts/chat.mjs <id|partial>    open an interactive chat with a session
//
// In the chat REPL: type a prompt and press Enter; replies stream inline.
// Commands: /bypass on|off, /model <name>, /exit.
//
// Built on `openacp api new/send/session` + tailing .openacp/history.

import fs from "node:fs";
import path from "node:path";
import readline from "node:readline";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const HIST = path.join(ROOT, ".openacp", "history");

// Resolve the openacp binary (PATH first, then the nvm location).
const OPENACP = (() => {
	for (const c of ["openacp", `${process.env.HOME}/.nvm/versions/node/${process.version}/bin/openacp`]) {
		try {
			execFileSync(c, ["version"], { stdio: "ignore" });
			return c;
		} catch {}
	}
	// last resort: glob the nvm dir
	try {
		const base = `${process.env.HOME}/.nvm/versions/node`;
		for (const v of fs.readdirSync(base)) {
			const p = path.join(base, v, "bin", "openacp");
			if (fs.existsSync(p)) return p;
		}
	} catch {}
	console.error("openacp not found on PATH"); process.exit(1);
})();

const api = (...a) => execFileSync(OPENACP, ["api", ...a], { encoding: "utf8" });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const turnsOf = (id) => {
	try {
		return JSON.parse(fs.readFileSync(path.join(HIST, `${id}.json`), "utf8")).turns || [];
	} catch {
		return [];
	}
};
const promptActive = (id) => {
	try {
		return /Prompt active\s*:\s*true/i.test(api("session", id));
	} catch {
		return false;
	}
};
const resolveId = (partial) => {
	if (fs.existsSync(path.join(HIST, `${partial}.json`))) return partial;
	const m = fs
		.readdirSync(HIST)
		.filter((f) => f.endsWith(".json"))
		.map((f) => f.replace(/\.json$/, ""))
		.find((x) => x.startsWith(partial));
	return m || partial;
};

function printAssistant(turn) {
	for (const s of turn.steps || []) {
		if (s.type === "text" && s.content?.trim()) console.log(`🤖 ${s.content.trim()}`);
		else if (s.type === "tool_call") {
			const name = s.toolName || s.name || s.type;
			const d = s.filePath || s.input?.file_path || s.input?.command || s.command || "";
			console.log(`   🔧 ${name}${d ? `: ${String(d).slice(0, 80)}` : ""}`);
		}
	}
}

async function streamReply(id, before) {
	let printed = before;
	let stable = 0;
	const start = Date.now();
	while (Date.now() - start < 180000) {
		await sleep(700);
		const turns = turnsOf(id);
		if (turns.length > printed) {
			for (let i = printed; i < turns.length; i++) if (turns[i].role === "assistant") printAssistant(turns[i]);
			printed = turns.length;
			stable = 0;
		} else {
			stable += 700;
		}
		if (printed > before && stable >= 1400 && !promptActive(id)) break;
	}
}

async function chat(idArg) {
	const id = resolveId(idArg);
	console.log(`\n💬 chatting with session ${id} (Ctrl+C or /exit to quit)`);
	for (const t of turnsOf(id).slice(-2)) if (t.role === "assistant") printAssistant(t);
	const rl = readline.createInterface({ input: process.stdin, output: process.stdout, prompt: "\nyou ▸ " });
	rl.prompt();
	rl.on("line", async (raw) => {
		const line = raw.trim();
		if (!line) return rl.prompt();
		if (line === "/exit" || line === "/quit") return rl.close();
		if (line.startsWith("/bypass ")) { try { api("bypass", id, line.split(" ")[1]); console.log("ok"); } catch (e) { console.log(String(e)); } return rl.prompt(); }
		if (line.startsWith("/model ")) { try { api("session-config", id, "set", "model", line.split(" ")[1]); console.log("ok"); } catch (e) { console.log(String(e)); } return rl.prompt(); }
		const before = turnsOf(id).length;
		rl.pause(); // queue further input until the reply finishes (robust for piped input)
		try { api("send", id, line); } catch (e) { console.log(String(e)); rl.resume(); return rl.prompt(); }
		await streamReply(id, before);
		rl.resume();
		rl.prompt();
	});
	rl.on("close", () => process.exit(0));
}

// ── dispatch ──────────────────────────────────────────────────────────────
const [cmd, ...rest] = process.argv.slice(2);
if (!cmd || cmd === "ls" || cmd === "list") {
	console.log(api("status").trim());
	console.log("\nChat:  node scripts/chat.mjs <id>     New:  node scripts/chat.mjs new");
} else if (cmd === "new") {
	const out = api("new", "claude");
	console.log(out.trim());
	const id = (out.match(/ID\s*:\s*([A-Za-z0-9_-]+)/) || [])[1];
	if (id) { console.log(`\nOpening chat...`); await chat(id); }
} else {
	await chat(cmd);
}
