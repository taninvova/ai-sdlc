#!/usr/bin/env node
// Reads a review run JSON (claude -p --output-format json) and exits 1 on any blocker.
const fs = require("fs");
const file = process.argv[2];
if (!file) { console.error("usage: gate.js <run.json>"); process.exit(2); }
// claude puts the final message in `result`; codex exec writes it to <run>.last.txt via -o.
let text;
if (fs.existsSync(file + ".last.txt")) text = fs.readFileSync(file + ".last.txt", "utf8");
else {
  const run = JSON.parse(fs.readFileSync(file, "utf8"));
  text = typeof run.result === "string" ? run.result : JSON.stringify(run);
}
const m = text.match(/\{[\s\S]*"verdict"[\s\S]*\}/);
if (!m) { console.error("gate: no verdict JSON found in run output"); process.exit(process.env.GATE_ENFORCE ? 1 : 0); }
const v = JSON.parse(m[0]);
for (const f of v.findings ?? []) console.log(`[${f.severity}] ${f.file}:${f.line} ${f.issue}\n    → ${f.suggestion}`);
console.log(`\nverdict: ${v.verdict} — ${v.summary}`);
const blockers = (v.findings ?? []).filter(f => f.severity === "blocker").length;
if (blockers && process.env.GATE_ENFORCE) process.exit(1);
if (blockers) console.log(`(${blockers} blocker(s); advisory mode — set GATE_ENFORCE=1 to block)`);
