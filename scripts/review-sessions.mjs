#!/usr/bin/env node
// Review OpenACP session transcripts (e.g. to see what your nephew has been building).
//
// Usage:
//   node scripts/review-sessions.mjs                # list all sessions
//   node scripts/review-sessions.mjs <id|latest>    # print one transcript (id or partial id)
//   node scripts/review-sessions.mjs --all          # print every transcript
//   ...add --thinking to include the agent's internal reasoning
//   ...add --full to not truncate long messages
//
// Reads from .openacp/history/*.json (gitignored, local only).

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const HIST_DIR = path.join(ROOT, ".openacp", "history");
const SESSIONS_FILE = path.join(ROOT, ".openacp", "sessions.json");

const args = process.argv.slice(2);
const showThinking = args.includes("--thinking");
const full = args.includes("--full");
const target = args.find((a) => !a.startsWith("--"));

if (!fs.existsSync(HIST_DIR)) {
	console.error(`No history found at ${HIST_DIR}. Is OpenACP set up in this repo?`);
	process.exit(1);
}

const sessionsMeta = (() => {
	try {
		const j = JSON.parse(fs.readFileSync(SESSIONS_FILE, "utf8"));
		return j.sessions || {};
	} catch {
		return {};
	}
})();

const time = (iso) => {
	try {
		return new Date(iso).toLocaleTimeString("en-US", { hour: "2-digit", minute: "2-digit", hour12: false });
	} catch {
		return "--:--";
	}
};
const clip = (s, n = 500) => (full || !s ? s : s.length > n ? s.slice(0, n) + " …" : s);

function loadHistory(id) {
	const f = path.join(HIST_DIR, `${id}.json`);
	if (!fs.existsSync(f)) return null;
	return JSON.parse(fs.readFileSync(f, "utf8"));
}

function listFiles() {
	return fs
		.readdirSync(HIST_DIR)
		.filter((f) => f.endsWith(".json"))
		.map((f) => f.replace(/\.json$/, ""));
}

function titleFor(id, hist) {
	const meta = sessionsMeta[id] || {};
	if (meta.name || meta.title) return meta.name || meta.title;
	const firstUser = (hist.turns || []).find((t) => t.role === "user");
	return firstUser ? clip(String(firstUser.content || ""), 50) : "(untitled)";
}

function toolSummary(step) {
	const name = step.toolName || step.name || step.type;
	const detail =
		step.filePath ||
		step.path ||
		step.input?.file_path ||
		step.input?.path ||
		step.input?.command ||
		step.command ||
		step.title ||
		(typeof step.content === "string" ? step.content.split("\n")[0] : "");
	return `${name}${detail ? `: ${clip(String(detail), 120)}` : ""}`;
}

function printTranscript(id) {
	const hist = loadHistory(id);
	if (!hist) {
		console.error(`No transcript for session ${id}`);
		return;
	}
	const meta = sessionsMeta[id] || {};
	const turns = hist.turns || [];
	const first = turns[0]?.timestamp,
		last = turns[turns.length - 1]?.timestamp;
	console.log("\n" + "═".repeat(72));
	console.log(`  ${titleFor(id, hist)}   [${id}]`);
	console.log(
		`  ${meta.channelId || "?"} · ${meta.status || "?"} · ${turns.length} turns · ${time(first)}–${time(last)}`
	);
	console.log("═".repeat(72));
	for (const t of turns) {
		if (t.role === "user") {
			const who = t.meta?.channelUser?.displayName || "user";
			console.log(`\n[${time(t.timestamp)}] 👤 ${who}: ${clip(String(t.content || ""))}`);
		} else if (t.role === "assistant") {
			for (const s of t.steps || []) {
				if (s.type === "text" && s.content?.trim()) {
					console.log(`[${time(t.timestamp)}] 🤖 ${clip(s.content.trim())}`);
				} else if (s.type === "thinking" && showThinking) {
					console.log(`           💭 ${clip(s.content || "", 200)}`);
				} else if (s.type === "tool_call") {
					console.log(`           ↳ 🔧 ${toolSummary(s)}`);
				}
			}
		}
	}
	console.log("");
}

function listSessions() {
	const rows = listFiles()
		.map((id) => {
			const hist = loadHistory(id);
			const meta = sessionsMeta[id] || {};
			return {
				id,
				name: titleFor(id, hist),
				status: meta.status || "?",
				channel: meta.channelId || "?",
				turns: (hist.turns || []).length,
				last: meta.lastActiveAt || hist.turns?.[hist.turns.length - 1]?.timestamp,
			};
		})
		.sort((a, b) => String(b.last).localeCompare(String(a.last)));

	console.log("\nSESSIONS (newest first):\n");
	for (const r of rows) {
		console.log(
			`  ${r.id.padEnd(14)} ${String(r.status).padEnd(11)} ${String(r.channel).padEnd(9)} ` +
				`${String(r.turns).padStart(3)} turns  ${time(r.last)}  "${r.name}"`
		);
	}
	console.log(`\nRead one:  node scripts/review-sessions.mjs <id|latest>`);
	console.log(`All:       node scripts/review-sessions.mjs --all   (add --thinking / --full)\n`);
}

// ── live watch ───────────────────────────────────────────────────────────────
// A short, fixed-width tag per session so interleaved lines are attributable.
const TAGS = {};
const EMOJIS = ["🟦", "🟩", "🟨", "🟧", "🟪", "🟥", "⬜", "🟫"];
function sessionTag(id, hist) {
	if (!TAGS[id]) {
		const name = titleFor(id, hist).replace(/[^a-zA-Z0-9 ]/g, "");
		const short = (name.split(/\s+/)[0] || id).slice(0, 8).padEnd(8);
		TAGS[id] = `${EMOJIS[Object.keys(TAGS).length % EMOJIS.length]} ${short}`;
	}
	return TAGS[id];
}

function printTurnLive(id, hist, t) {
	const tag = sessionTag(id, hist);
	const stamp = `[${time(t.timestamp)}] ${tag}`;
	if (t.role === "user") {
		const who = t.meta?.channelUser?.displayName || "user";
		console.log(`${stamp} 👤 ${who}: ${clip(String(t.content || ""), 200)}`);
	} else if (t.role === "assistant") {
		for (const s of t.steps || []) {
			if (s.type === "text" && s.content?.trim()) console.log(`${stamp} 🤖 ${clip(s.content.trim(), 240)}`);
			else if (s.type === "thinking" && showThinking) console.log(`${stamp}    💭 ${clip(s.content || "", 160)}`);
			else if (s.type === "tool_call") console.log(`${stamp}    🔧 ${clip(toolSummary(s), 90)}`);
		}
	}
}

function watch() {
	const seen = {};
	console.log("👀 Watching all sessions live — interleaved, newest at the bottom. Ctrl+C to stop.\n");
	// Seed: show the last 2 turns of each session for context, then only stream new ones.
	for (const id of listFiles()) {
		const h = loadHistory(id);
		if (!h) continue;
		const turns = h.turns || [];
		for (const t of turns.slice(-2)) printTurnLive(id, h, t);
		seen[id] = turns.length;
	}
	console.log("\n── live ──────────────────────────────────────────────────────────────────\n");
	setInterval(() => {
		for (const id of listFiles()) {
			const h = loadHistory(id);
			if (!h) continue;
			const turns = h.turns || [];
			for (let i = seen[id] ?? turns.length; i < turns.length; i++) printTurnLive(id, h, turns[i]);
			seen[id] = turns.length;
		}
	}, 1200);
}

// ── dispatch ────────────────────────────────────────────────────────────────
if (args.includes("--watch")) {
	watch();
} else if (args.includes("--all")) {
	listFiles()
		.map((id) => ({ id, last: sessionsMeta[id]?.lastActiveAt || "" }))
		.sort((a, b) => String(a.last).localeCompare(String(b.last)))
		.forEach((r) => printTranscript(r.id));
} else if (target) {
	let id = target;
	if (target === "latest") {
		id = listFiles()
			.map((x) => ({ x, last: sessionsMeta[x]?.lastActiveAt || "" }))
			.sort((a, b) => String(b.last).localeCompare(String(a.last)))[0]?.x;
	} else if (!fs.existsSync(path.join(HIST_DIR, `${target}.json`))) {
		id = listFiles().find((x) => x.startsWith(target)) || target; // partial id
	}
	printTranscript(id);
} else {
	listSessions();
}
