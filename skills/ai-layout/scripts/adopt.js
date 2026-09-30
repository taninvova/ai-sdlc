#!/usr/bin/env node
const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

function detect(root) {
	const pkg = path.join(root, "package.json");
	if (fs.existsSync(pkg)) {
		const data = JSON.parse(fs.readFileSync(pkg, "utf8"));
		const declared = String(data.packageManager || "npm").split("@")[0];
		const manager = ["npm", "pnpm", "yarn", "bun"].includes(declared)
			? declared
			: "npm";
		const commands = ["build", "lint", "typecheck", "type-check", "test", "e2e"]
			.filter((key) => Object.hasOwn(data.scripts || {}, key))
			.map((key) => `- ${key}: \`${manager} run ${key}\``);
		return {
			stack: "JavaScript/TypeScript",
			commands:
				commands.join("\n") ||
				"No verification commands declared; configure them before implementation.",
		};
	}
	const stacks = [
		["pyproject.toml", "Python"],
		["go.mod", "Go"],
		["Cargo.toml", "Rust"],
	];
	return {
		stack:
			stacks.find(([file]) => fs.existsSync(path.join(root, file)))?.[1] ||
			"Project tooling",
		commands:
			"No verification commands detected. Record the project's actual commands before implementation; do not invent successful checks.",
	};
}

function adopt(root, pluginRoot, owner) {
	root = fs.realpathSync(root);
	const target = path.join(root, "ai-factory");
	try {
		fs.lstatSync(target);
		throw new Error(
			"ai-factory already exists; use sync to inspect drift. Nothing overwritten.",
		);
	} catch (error) {
		if (error.code !== "ENOENT") throw error;
	}
	const values = {
		...detect(root),
		app: path.basename(root),
		owner: owner || "TBD",
		backup: "TBD",
		date: new Date().toISOString().slice(0, 10),
		plugin_version: JSON.parse(
			fs.readFileSync(
				path.join(pluginRoot, ".claude-plugin/plugin.json"),
				"utf8",
			),
		).version,
	};
	const source = path.join(pluginRoot, "skills/ai-layout/templates/ai-factory");
	fs.cpSync(source, target, {
		recursive: true,
		force: false,
		errorOnExist: true,
		dereference: false,
	});
	function fill(dir) {
		for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
			const file = path.join(dir, entry.name);
			if (entry.isSymbolicLink())
				throw new Error(`Unexpected symlink in delivered workspace: ${file}`);
			if (entry.isDirectory()) fill(file);
			else if (entry.name.endsWith(".md")) {
				const body = fs
					.readFileSync(file, "utf8")
					.replace(/\{\{([a-z_]+)\}\}/g, (_, key) => {
						if (Object.hasOwn(values, key)) return values[key];
						if (key.endsWith("_extra") || key === "overlay_note") return "";
						throw new Error(`Unresolved template placeholder: ${key}`);
					});
				fs.writeFileSync(file, body);
			}
		}
	}
	fill(target);
	execFileSync(
		process.execPath,
		[
			path.join(pluginRoot, "skills/ai-layout/scripts/manifest.js"),
			"write",
			root,
			pluginRoot,
		],
		{ stdio: "pipe" },
	);
	return target;
}
if (require.main === module) {
	try {
		const [root = ".", owner] = process.argv.slice(2);
		console.log(
			`Created ${adopt(root, path.resolve(__dirname, "../../.."), owner)}; existing root files and host configuration preserved.`,
		);
	} catch (error) {
		console.error(`adopt: ${error.message}`);
		process.exitCode = 1;
	}
}
module.exports = { adopt, detect };
