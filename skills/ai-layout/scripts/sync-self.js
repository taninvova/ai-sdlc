#!/usr/bin/env node
// Regenerate this plugin's own workspace links; never replace local regular files.
const fs = require("node:fs");
const path = require("node:path");
const root = path.resolve(__dirname, "../../..");
const workspace = path.join(root, "ai-factory");
for (const [kind, source] of Object.entries({
	tasks: "skills/ai-layout/templates/ai-factory/tasks",
	make: "skills/ai-layout/templates/ai-factory/make",
	agents: "agents",
})) {
	const destination = path.join(workspace, kind);
	if (
		!fs.statSync(destination).isDirectory() ||
		fs.lstatSync(destination).isSymbolicLink()
	) {
		throw new Error(`Refusing redirected workspace directory: ${destination}`);
	}
	for (const item of fs.readdirSync(path.join(root, source), {
		withFileTypes: true,
	})) {
		if (!item.isFile() || item.name.startsWith(".")) continue;
		const link = path.join(destination, item.name);
		const target = path.relative(
			destination,
			path.join(root, source, item.name),
		);
		try {
			const stat = fs.lstatSync(link);
			if (!stat.isSymbolicLink())
				throw new Error(`Preserving regular workspace file: ${link}`);
			if (fs.readlinkSync(link) !== target)
				throw new Error(`Preserving unexpected link: ${link}`);
		} catch (error) {
			if (error.code !== "ENOENT") throw error;
			fs.symlinkSync(target, link);
		}
	}
}
console.log(
	"Source workspace links synchronized; local regular files preserved.",
);
