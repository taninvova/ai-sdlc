#!/usr/bin/env node
// Explicit host selection avoids guessing from model names or transcript paths.
const { spawnSync } = require("node:child_process");
const path = require("node:path");
const { readEvent } = require("./_common");
const allowed = new Set([
	"session-start",
	"log-task",
	"guard-paths",
	"log-flush",
	"log-edit",
	"log-cmd",
	"session-stop",
	"subagent-stop",
]);
const script = process.argv[2];
if (!allowed.has(script)) {
	process.stderr.write("Unknown Codex hook handler\n");
	process.exit(2);
}
const result = spawnSync(
	process.execPath,
	[path.join(__dirname, script + ".js")],
	{
		input: JSON.stringify({ ...readEvent(), host: "codex" }),
		encoding: "utf8",
	},
);
if (result.stdout) process.stdout.write(result.stdout);
if (result.stderr) process.stderr.write(result.stderr);
if (result.error) process.stderr.write(result.error.message + "\n");
process.exit(result.status ?? 2);
