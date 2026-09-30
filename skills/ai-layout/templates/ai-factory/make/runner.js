#!/usr/bin/env node
// Configuration is data: no user-controlled value is interpolated into a shell.
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const { spawn, execFileSync } = require("node:child_process");
const { boundary, withLogLock } = require("./safe-files.js");
const { digest } = require("./gate.js");
// Preserve the invoked workspace when its entry point is a source-repo symlink.
// Node resolves __dirname to the template's location, but argv[1] retains the entry.
const ENTRY_DIRECTORY =
	require.main === module ? path.dirname(process.argv[1]) : __dirname;
const ROOT = fs.realpathSync(path.resolve(ENTRY_DIRECTORY, "../.."));
const WORKSPACE = path.join(ROOT, "ai-factory");
const RUNS = path.join(WORKSPACE, "runs");
const safe = boundary(WORKSPACE);

function scalar(text, line) {
	const value = text.trim();
	if (!value || value.startsWith("#")) return "";
	if (value.startsWith('"')) {
		const match = value.match(/^("(?:[^"\\]|\\.)*")(?:\s+#.*)?$/);
		if (!match) throw new Error(`Invalid quoted model on line ${line}`);
		return JSON.parse(match[1]);
	}
	if (value.startsWith("'")) {
		const match = value.match(/^'((?:[^']|'')*)'(?:\s+#.*)?$/);
		if (!match) throw new Error(`Invalid quoted model on line ${line}`);
		return match[1].replace(/''/g, "'");
	}
	if (/^[|>{[&*!]/.test(value))
		throw new Error(`Unsupported model syntax on line ${line}`);
	return value.replace(/\s+#.*$/, "").trim();
}

function readModels(file = path.join(WORKSPACE, "models.yaml")) {
	let content;
	try {
		content = fs.readFileSync(file, "utf8");
	} catch (error) {
		if (error.code === "ENOENT") return {};
		throw error;
	}
	const result = {};
	const keys = new Set();
	let pricing = false;
	for (const [index, line] of content.split(/\r?\n/).entries()) {
		if (/^\s*(#.*)?$/.test(line)) continue;
		if (pricing && /^ {2}\S/.test(line)) continue;
		const match = line.match(/^(claude|codex|review|pricing):(?:\s+(.*))?$/);
		if (!match || keys.has(match[1]))
			throw new Error(
				`Invalid or duplicate models.yaml setting on line ${index + 1}`,
			);
		const [, key, raw = ""] = match;
		keys.add(key);
		pricing = key === "pricing";
		if (pricing) {
			if (raw.trim() && !raw.trim().startsWith("#"))
				throw new Error("pricing must be an indented mapping");
		} else {
			result[key] = scalar(raw, index + 1);
			if (/[\r\n\0]/.test(result[key]))
				throw new Error(`Invalid model on line ${index + 1}`);
		}
	}
	return result;
}

function resolveModel(tool, review, env = process.env) {
	if (env.SDLC_MODEL_EXPLICIT === "1" || env.MODEL) {
		if (/[\r\n\0]/.test(env.MODEL))
			throw new Error("MODEL must be a single-line value");
		return env.MODEL || "";
	}
	const models = readModels();
	return (review && models.review) || models[tool] || "";
}

function executable(tool, env) {
	const value = env.CMD || tool;
	if (/^[A-Za-z0-9_.-]+$/.test(value)) return value;
	if (!value.includes(path.sep) || /[\r\n\0]/.test(value)) {
		throw new Error(
			"CMD must be an executable name or path, not a shell command",
		);
	}
	const file = path.resolve(ROOT, value);
	if (!fs.statSync(file).isFile())
		throw new Error("CMD must select a regular executable file");
	fs.accessSync(file, fs.constants.X_OK);
	return file;
}

function launch(command, args, input, output) {
	return new Promise((resolve, reject) => {
		const child = spawn(command, args, {
			cwd: ROOT,
			shell: false,
			stdio: ["pipe", output, "inherit"],
		});
		let interrupted;
		let timer;
		const stop = (signal) => {
			interrupted = signal;
			child.kill(signal);
			timer = setTimeout(() => child.kill("SIGKILL"), 1000);
			timer.unref();
		};
		const interrupt = () => stop("SIGINT");
		const terminate = () => stop("SIGTERM");
		process.on("SIGINT", interrupt);
		process.on("SIGTERM", terminate);
		const cleanup = () => {
			clearTimeout(timer);
			process.removeListener("SIGINT", interrupt);
			process.removeListener("SIGTERM", terminate);
		};
		child.once("error", (error) => {
			cleanup();
			reject(error);
		});
		child.once("close", (code, signal) => {
			cleanup();
			if (interrupted || signal || code !== 0)
				reject(new Error(`CLI failed (${interrupted || signal || code})`));
			else resolve();
		});
		child.stdin.on("error", (error) => {
			if (error.code !== "EPIPE") {
				child.kill();
				reject(error);
			}
		});
		child.stdin.end(input);
	});
}

async function run(options = {}) {
	const env = options.env || process.env;
	const tool = options.tool || env.TOOL || "claude";
	const task = options.task || env.TASK || "chore";
	if (!["claude", "codex"].includes(tool))
		throw new Error(`Unsupported tool: ${tool}`);
	if (!/^[a-z][a-z0-9-]*$/.test(task))
		throw new Error("TASK must name an existing workspace task");
	const taskFile = fs.realpathSync(path.join(WORKSPACE, "tasks", `${task}.md`));
	const relativeTask = path.relative(ROOT, taskFile);
	if (
		relativeTask === ".." ||
		relativeTask.startsWith(`..${path.sep}`) ||
		path.isAbsolute(relativeTask)
	) {
		throw new Error("TASK must resolve inside the current repository");
	}
	if (!fs.statSync(taskFile).isFile())
		throw new Error("TASK must select a regular task file");
	let input = options.input;
	if (input === undefined) {
		if (env.INPUT_FILE) {
			const inputFile = path.resolve(ROOT, env.INPUT_FILE);
			if (!fs.statSync(inputFile).isFile())
				throw new Error("INPUT_FILE must select a regular file");
			input = fs.readFileSync(inputFile);
		} else input = Buffer.from(env.INPUT || "", "utf8");
	}
	const model = resolveModel(tool, options.review || task === "check", env);
	const command = executable(tool, env);
	safe.mkdir(RUNS);
	for (const name of ["log.csv", "log.previous.csv"])
		safe.assertPath(path.join(RUNS, name));
	const scratch = safe.scratch(path.join(RUNS, "tmp"));
	const identity = `${new Date().toISOString().replace(/[:.]/g, "-")}-${crypto.randomUUID()}-${tool}-${task}`;
	const output = path.join(RUNS, `${identity}.json`);
	const sidecar = `${output}.last.txt`;
	let fd;
	try {
		const prompt = Buffer.concat([
			fs.readFileSync(taskFile),
			Buffer.from("\n## Input\n"),
			Buffer.from(input),
		]);
		safe.write(path.join(scratch, "prompt.txt"), prompt, { exclusive: true });
		fd = safe.open(
			output,
			fs.constants.O_WRONLY | fs.constants.O_CREAT | fs.constants.O_EXCL,
		);
		const args =
			tool === "codex" ? ["exec", "--json", "--skip-git-repo-check"] : ["-p"];
		if (model) args.push(tool === "codex" ? "-m" : "--model", model);
		if (tool === "codex") {
			safe.write(sidecar, "", { exclusive: true });
			args.push("-o", sidecar, "-");
		} else args.push("--output-format", "json");
		await launch(command, args, prompt, fd);
		fs.closeSync(fd);
		fd = undefined;
		safe.assertPath(output, { allowMissing: false });
		if (!fs.statSync(output).size)
			throw new Error("CLI produced empty output; no successful run logged");
		if (tool === "codex") safe.assertPath(sidecar, { allowMissing: false });
		const outputHash = digest(fs.readFileSync(output));
		const sidecarHash =
			tool === "codex" ? digest(fs.readFileSync(sidecar)) : undefined;
		if (options.scope)
			safe.write(
				`${output}.scope.json`,
				`${JSON.stringify(options.scope, null, 2)}\n`,
				{ exclusive: true },
			);
		withLogLock(WORKSPACE, () => {
			for (const name of ["log.csv", "log.previous.csv"])
				safe.assertPath(path.join(RUNS, name));
			const row = execFileSync(
				process.execPath,
				[path.join(__dirname, "log.js"), output, task, tool, model],
				{
					cwd: ROOT,
					shell: false,
					encoding: "utf8",
					stdio: ["ignore", "pipe", "inherit"],
				},
			);
			safe.append(path.join(RUNS, "log.csv"), row);
		});
		return {
			output,
			sidecar: tool === "codex" ? sidecar : undefined,
			outputHash,
			sidecarHash,
			model,
			tool,
			task,
			scope: options.scope,
		};
	} finally {
		if (fd !== undefined) fs.closeSync(fd);
		safe.removeScratch(scratch);
	}
}

function git(args, options = {}) {
	return execFileSync("git", args, {
		cwd: ROOT,
		shell: false,
		encoding: "utf8",
		stdio: ["pipe", "pipe", "pipe"],
		env: { ...process.env, GIT_OPTIONAL_LOCKS: "0" },
		...options,
	});
}

function reviewInput(env = process.env) {
	const requested = env.REVIEW_SCOPE || "working-tree";
	if (!["working-tree", "branch", "supplied"].includes(requested))
		throw new Error("REVIEW_SCOPE must be working-tree, branch, or supplied");
	const splitPaths = (text) => text.split("\0").filter(Boolean);
	const diffFlags = [
		"--no-ext-diff",
		"--no-textconv",
		"--no-renames",
		"--binary",
	];
	let input;
	let paths;
	let scope = requested;
	if (env.INPUT_FILE || scope === "supplied") {
		scope = "supplied";
		if (env.INPUT_FILE) {
			const file = path.resolve(ROOT, env.INPUT_FILE);
			if (!fs.statSync(file).isFile())
				throw new Error("INPUT_FILE must select a regular diff file");
			input = fs.readFileSync(file);
		} else input = Buffer.from(env.INPUT || "");
		if (input.length) {
			try {
				paths = splitPaths(
					git(["apply", "--numstat", "-z", "--"], { input }),
				).map((row) => row.split("\t").slice(2).join("\t"));
			} catch {
				throw new Error(
					"Supplied review input must be a unified diff (git apply --numstat could not read it)",
				);
			}
		} else paths = [];
	} else if (scope === "branch") {
		let base;
		try {
			base = git(["merge-base", "HEAD", "main"]).trim();
		} catch {
			base = git(["merge-base", "HEAD", "develop"]).trim();
		}
		const range = `${base}...HEAD`;
		input = git(["diff", ...diffFlags, range, "--"]);
		paths = splitPaths(
			git(["diff", "--no-renames", "--name-only", "-z", range, "--"]),
		);
	} else {
		const staged = git(["diff", ...diffFlags, "--cached", "--"]);
		const unstaged = git(["diff", ...diffFlags, "--"]);
		const untracked = splitPaths(
			git(["ls-files", "--others", "--exclude-standard", "-z", "--"]),
		);
		paths = [
			...new Set([
				...splitPaths(
					git(["diff", "--no-renames", "--name-only", "-z", "--cached", "--"]),
				),
				...splitPaths(git(["diff", "--no-renames", "--name-only", "-z", "--"])),
				...untracked,
			]),
		];
		const additions = untracked.map((file) => {
			try {
				return git([
					"diff",
					...diffFlags,
					"--no-index",
					"--",
					"/dev/null",
					file,
				]);
			} catch (error) {
				if (error.status === 1 && error.stdout) return error.stdout;
				throw error;
			}
		});
		input = `## Staged changes\n${staged}\n## Unstaged changes\n${unstaged}\n## Untracked changes\n${additions.join("\n")}`;
	}
	const selection = { scope, paths: [...new Set(paths)].sort() };
	return { selection, input, empty: selection.paths.length === 0 };
}

async function review() {
	if (![undefined, "", "0", "1"].includes(process.env.GATE_ENFORCE)) {
		throw new Error("GATE_ENFORCE must be 0, 1, or unset");
	}
	const selected = reviewInput();
	const summary = `Review scope: ${selected.selection.scope}\nSelected paths: ${JSON.stringify(selected.selection.paths)}\n`;
	process.stdout.write(summary);
	if (selected.empty) return { empty: true, scope: selected.selection };
	const input = Buffer.concat([
		Buffer.from(`${summary}\n`),
		Buffer.from(selected.input),
	]);
	const result = await run({
		task: "check",
		review: true,
		input,
		scope: selected.selection,
	});
	const args = [
		path.join(__dirname, "gate.js"),
		result.output,
		"--tool",
		result.tool,
		"--output-sha256",
		result.outputHash,
	];
	if (result.sidecar)
		args.push(
			"--sidecar",
			result.sidecar,
			"--sidecar-sha256",
			result.sidecarHash,
		);
	execFileSync(process.execPath, args, {
		cwd: ROOT,
		shell: false,
		stdio: "inherit",
	});
	return result;
}

function flush() {
	return withLogLock(WORKSPACE, flushLocked);
}
function flushLocked() {
	const pending = safe.assertPath(path.join(RUNS, "log.pending.csv"));
	if (!fs.existsSync(pending) || !fs.statSync(pending).size) return;
	const file = safe.assertPath(path.join(RUNS, "log.csv"));
	const contents = fs.readFileSync(pending, "utf8");
	const split = contents.indexOf("\n");
	if (split < 0) throw new Error("log-flush: pending header is incomplete");
	const header = contents.slice(0, split);
	if (!fs.existsSync(file) || !fs.statSync(file).size)
		safe.write(file, `${header}\n`);
	if (fs.readFileSync(file, "utf8").split("\n")[0] !== header)
		throw new Error("log-flush: schema mismatch");
	safe.append(file, contents.slice(split + 1));
	safe.unlink(pending);
}

function clean() {
	return withLogLock(WORKSPACE, cleanLocked);
}
function cleanLocked() {
	safe.assertPath(RUNS);
	if (!fs.existsSync(RUNS)) return;
	const cutoff = Date.now() - 30 * 86400000;
	for (const name of fs.readdirSync(RUNS)) {
		if (!(/\.json$/.test(name) || /^\.(counted|task)\./.test(name))) continue;
		const file = safe.assertPath(path.join(RUNS, name), {
			allowMissing: false,
		});
		const stat = fs.statSync(file);
		if (stat.isFile() && stat.mtimeMs < cutoff) safe.unlink(file);
	}
}

async function main(action = process.argv[2]) {
	if (action === "ai" || action === "review") {
		const result = await (action === "review" ? review() : run());
		process.stdout.write(
			result.empty
				? "No selected changes; no review model invoked.\n"
				: `run saved: ${path.relative(ROOT, result.output)}\n`,
		);
	} else if (action === "log-flush") flush();
	else if (action === "clean-runs") clean();
	else throw new Error(`Unknown runner action: ${action}`);
}

if (require.main === module)
	main().catch((error) => {
		process.stderr.write(`runner: ${error.message}\n`);
		process.exitCode = 1;
	});
module.exports = {
	run,
	review,
	reviewInput,
	readModels,
	resolveModel,
	launch,
	git,
	main,
	ROOT,
	WORKSPACE,
	RUNS,
	safe,
};
