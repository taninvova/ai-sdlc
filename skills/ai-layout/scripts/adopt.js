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

// `name` and `prefix` go to ai-factory/project.json, which ids.js reads for every new artefact ID
// (PMB-001). Without them the folder's name stands in and the prefix is suggested from it.
function adopt(root, pluginRoot, owner, { name, prefix } = {}) {
	root = fs.realpathSync(root);
	const ids = require(path.join(pluginRoot, "skills/ai-layout/templates/ai-factory/make/ids.js"));
	const projectName = name || path.basename(root);
	// Refuse a bad name or prefix before anything is copied.
	const projectPrefix = prefix === undefined ? ids.suggest(projectName) : String(prefix).toUpperCase();
	if (!/^[A-Z]{2,5}$/.test(projectPrefix) || ["AC", "QC"].includes(projectPrefix))
		throw new Error(`prefix '${prefix}' must be two to five letters, not AC or QC, such as PMB`);
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
		app: projectName,
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
	ids.init({ root, name: projectName, prefix: projectPrefix });
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
		// adopt.js [root] [owner] [--name "<Project>"] [--prefix <ABC>]
		const positional = [];
		const options = {};
		const args = process.argv.slice(2);
		for (let i = 0; i < args.length; i++) {
			if (args[i] === "--name" || args[i] === "--prefix") {
				if (i + 1 >= args.length) throw new Error(`${args[i]} needs a value`);
				options[args[i].slice(2)] = args[++i];
			} else positional.push(args[i]);
		}
		const [root = ".", owner] = positional;
		const pluginRoot = path.resolve(__dirname, "../../..");
		const target = adopt(root, pluginRoot, owner, options);
		const { name, prefix } = JSON.parse(fs.readFileSync(path.join(target, "project.json"), "utf8"));
		console.log(
			`Created ${target} for ${name}, artefact IDs ${prefix}-001, ${prefix}-002…; existing root files and host configuration preserved.`,
		);
	} catch (error) {
		console.error(`adopt: ${error.message}`);
		process.exitCode = 1;
	}
}
module.exports = { adopt, detect };
