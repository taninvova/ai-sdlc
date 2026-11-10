#!/usr/bin/env node
// Loads ai-factory/docs/ponytail.md into the session. That file is the Ponytail
// instruction (MIT, DietrichGebert/ponytail). SessionStart and SubagentStart only.
// No layout, or no file: print nothing and exit 0. Writes no file.
const fs = require("fs");
const path = require("path");
const { readEvent, aiDir } = require("./_common");

const FENCE =
	"Where a task procedure, a plan step or a recorded check requires a test, that check stays. This file does not remove it.";

function instruction(text) {
	return String(text)
		.replace(/<!--[\s\S]*?-->\s*/, "")
		.replace(/^---[\s\S]*?---\s*/, "")
		.trim();
}

function emit(event, host, context) {
	const json = host === "codex" || event === "SubagentStart";
	const text = json
		? JSON.stringify({
				hookSpecificOutput: {
					hookEventName: event || "SessionStart",
					additionalContext: context,
				},
			})
		: context;
	fs.writeSync(1, text);
}

function readInstruction(ai) {
	const shipped = path.join(
		__dirname,
		"..",
		"..",
		"ai-layout",
		"templates",
		"ai-factory",
		"docs",
		"ponytail.md",
	);
	const own = ai ? path.join(ai, "docs", "ponytail.md") : "";
	for (const file of [own, shipped]) {
		if (!file) continue;
		try {
			return fs.readFileSync(file, "utf8");
		} catch {
			/* the workspace copy is optional; the shipped file is the fallback */
		}
	}
	return "";
}

const ev = readEvent();
const ai = aiDir(ev);
if (!ai) process.exit(0);

const raw = readInstruction(ai);
const body = instruction(raw);
if (!body) process.exit(0);

emit(
	ev.hook_event_name,
	ev.host,
	"PONYTAIL MODE ACTIVE — level: full\n\n" + body + "\n\n" + FENCE + "\n",
);
