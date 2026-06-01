#!/usr/bin/env node
// ai-progress-relay — turns an OpenACP session's live transcript into something the
// Roblox game can POLL (Roblox's HttpService can't consume OpenACP's SSE stream).
//
// It reads the session history file that OpenACP updates step-by-step
// (.openacp/history/<sessionId>.json) and serves friendly progress lines as JSON.
//
//   GET /progress?session=<id>&since=<n>
//     -> { cursor: <total lines so far>, lines: [ "🔧 editing WorldBuilder", ... ] }
//   Auth: Authorization: Bearer <api-secret>  (same token the game already uses)
//
// Run:  node scripts/ai-progress-relay.mjs        (port 21422)
// Expose:  cloudflared tunnel --url http://localhost:21422   (then use that URL)

import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const HISTORY_DIR = path.join(ROOT, ".openacp", "history");
const PORT = Number(process.env.RELAY_PORT || 21422);

let TOKEN = "";
try {
	TOKEN = fs.readFileSync(path.join(ROOT, ".openacp", "api-secret"), "utf8").trim();
} catch {
	console.error("[relay] WARNING: could not read .openacp/api-secret — auth disabled");
}

function base(p) {
	return p ? String(p).split("/").pop() : "";
}

// Turn one transcript step into a short, kid-friendly progress line (or null to skip).
function lineFor(step) {
	const type = step.type || "";
	const text = (step.content || step.text || "").toString().trim();
	if (type === "text") return text ? "💬 " + text.slice(0, 160) : null;
	if (type === "thinking") return "💭 thinking…";
	if (type === "tool_use" || type === "tool_call") {
		const name = step.name || "";
		const input = step.input || step.args || {};
		const cmd = (input.command || "").toString();
		if (name === "Edit" || name === "Write") return "🔧 editing " + base(input.file_path);
		if (name === "Read File" || name === "Read") return "📖 reading " + base(input.file_path);
		if (name === "grep" || name === "Grep" || name === "Glob") return "🔎 searching the code";
		if (name === "Terminal" || name === "Bash") {
			if (cmd.includes("check.sh")) return "🧪 checking the build";
			if (cmd.includes("publish.sh")) return "🚀 publishing it live";
			return "⌨️ " + cmd.slice(0, 40);
		}
		return "🔧 " + name;
	}
	return null;
}

// Flatten all assistant steps across the session into ordered progress lines,
// collapsing repeated "thinking…" so the feed stays readable.
function linesForSession(id) {
	const file = path.join(HISTORY_DIR, path.basename(id) + ".json");
	let data;
	try {
		data = JSON.parse(fs.readFileSync(file, "utf8"));
	} catch {
		return [];
	}
	const out = [];
	for (const turn of data.turns || []) {
		if (turn.role !== "assistant") continue;
		for (const step of turn.steps || []) {
			const line = lineFor(step);
			if (!line) continue;
			if (line === "💭 thinking…" && out[out.length - 1] === "💭 thinking…") continue;
			out.push(line);
		}
	}
	return out;
}

const server = http.createServer((req, res) => {
	const url = new URL(req.url, "http://localhost");
	if (url.pathname !== "/progress") {
		res.writeHead(404, { "Content-Type": "application/json" });
		return res.end(JSON.stringify({ error: "not found" }));
	}
	if (TOKEN) {
		const auth = req.headers.authorization || "";
		if (auth !== "Bearer " + TOKEN) {
			res.writeHead(401, { "Content-Type": "application/json" });
			return res.end(JSON.stringify({ error: "unauthorized" }));
		}
	}
	const session = url.searchParams.get("session") || "";
	const since = Math.max(0, parseInt(url.searchParams.get("since") || "0", 10) || 0);
	const all = session ? linesForSession(session) : [];
	res.writeHead(200, { "Content-Type": "application/json" });
	res.end(JSON.stringify({ cursor: all.length, lines: all.slice(since) }));
});

server.listen(PORT, () => console.log(`[relay] progress relay listening on :${PORT}`));
