#!/usr/bin/env node
// Deliver complete procedures; project additions remain an explicit section.
const fs = require("node:fs");
const path = require("node:path");
const root = path.resolve(__dirname, "../../..");
let changed = false;
for (const name of fs
	.readdirSync(path.join(root, "agents"))
	.filter((n) => n.endsWith(".md"))) {
	const source = fs
		.readFileSync(path.join(root, "agents", name), "utf8")
		.trimEnd();
	const additions = fs
		.readFileSync(
			path.join(root, "skills/ai-layout/agent-additions", name),
			"utf8",
		)
		.trim();
	const expected = `${source}\n\n## Project additions\n\n${additions}\n`;
	const target = path.join(
		root,
		"skills/ai-layout/templates/ai-factory/agents",
		name,
	);
	if (fs.readFileSync(target, "utf8") === expected) continue;
	changed = true;
	if (process.argv.includes("--check"))
		console.error(`Agent payload is stale: ${name}`);
	else fs.writeFileSync(target, expected);
}
if (changed && process.argv.includes("--check")) process.exitCode = 1;
