#!/usr/bin/env bash
# User docs (ASD-003): pins skills/ai-layout/scripts/sync-docs.js, the generator of docs/commands.md
# and docs/commands/<name>.md, and _frontmatter.js, the shared frontmatter reader it uses. Every
# case builds a disposable tree under ai-factory/runs/tmp/, copies the scripts into it and runs
# them there, so the generator resolves its root to the scratch tree and never sees the real docs/.
#
# Groups: reader, generate, prune, check, notes, links, versions (default: every group).
# Each case reports a missing script or a missing export as its own failure, never as a crash,
# so the red run of a group names every case it holds.
set -euo pipefail
cd "$(dirname "$0")/../../.."
group="${1:-all}"
case "$group" in
	all | reader | generate | prune | check | notes | links | versions) ;;
	*) echo "check-sync-docs: unknown group '$group' (expected: reader, generate, prune, check, notes, links, versions)" >&2; exit 2 ;;
esac
SYNC_DOCS_GROUP="$group" node <<'NODE'
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { builtinModules } = require("node:module");
const { spawnSync } = require("node:child_process");
const { boundary } = require("./skills/ai-layout/templates/ai-factory/make/safe-files.js");

const SCRIPTS_REL = "skills/ai-layout/scripts";
const SYNC = path.resolve(SCRIPTS_REL, "sync-docs.js");
const READER = path.resolve(SCRIPTS_REL, "_frontmatter.js");
const TASKS_REL = "skills/ai-layout/templates/ai-factory/tasks";
// The commit before plan ASD-004 (main at the ASD-003 merge, release 5.0.1). The deprecated entry
// points are compared with it, never with `main` or HEAD, so the check needs no local `main` ref and
// committing the delivery does not turn the comparison into one of the file with itself. The full
// SHA, as check-start-routing.sh's PRE_ASD001: an abbreviation can turn ambiguous as history grows.
const PRE_ASD004 = "84ea88b258766994c200d0bd6b24c6bc8b4b8a10";
const scratch = boundary(path.resolve("ai-factory")).scratch(path.resolve("ai-factory/runs/tmp"));
const selected = process.env.SYNC_DOCS_GROUP;
const want = (name) => selected === "all" || selected === name;
const failures = [];
let passed = 0;

// ---- the scripts under test, located so a missing one fails its case alone ----------------
function needReader() {
	if (!fs.existsSync(READER)) throw new Error(`${SCRIPTS_REL}/_frontmatter.js does not exist`);
}
function needSync() {
	if (!fs.existsSync(SYNC)) throw new Error(`${SCRIPTS_REL}/sync-docs.js does not exist`);
	needReader();
}
// The reader exports one function: the module itself, or the single function on its exports.
function readerOf(file) {
	const mod = require(file);
	if (typeof mod === "function") return mod;
	const fns = Object.values(mod || {}).filter((value) => typeof value === "function");
	if (fns.length !== 1) throw new Error(`_frontmatter.js exports ${fns.length} functions; expected one frontmatter reader`);
	return fns[0];
}

// ---- fixture tree -------------------------------------------------------------------------
let fixtures = 0;
const touch = (root, rel, text = "") => {
	fs.mkdirSync(path.dirname(path.join(root, rel)), { recursive: true });
	fs.writeFileSync(path.join(root, rel), text);
};
const read = (root, rel) => fs.readFileSync(path.join(root, rel), "utf8");
const exists = (root, rel) => fs.existsSync(path.join(root, rel));
const command = ({ description, hint }) =>
	`---\ndescription: ${description}\n${hint ? `argument-hint: ${hint}\n` : ""}---\nBody of the command.\ndescription: not the frontmatter\n`;
const task = ({ description, hint }) =>
	`---\ndescription: ${description}\n${hint ? `argument-hint: ${hint}\n` : ""}---\nTask body.\n`;
const notes = (name, extra = "") =>
	[
		`## Usage`,
		``,
		`Usage text for ${name} NOTE-${name}-USAGE.${extra}`,
		``,
		`## Examples`,
		``,
		"```",
		`/fc:${name} NOTE-${name}-EXAMPLE`,
		"```",
		``,
		`## Writes`,
		``,
		`NOTE-${name}-WRITES: nothing outside ai-factory/.`,
		``,
		`## Refuses or asks`,
		``,
		`NOTE-${name}-REFUSES when the input is missing.`,
		``,
	].join("\n");

// Six commands: three project tasks (run, review, quick), the deprecated alias check (of review),
// the shortcut ba (of run) and one plugin-level command (doctor). An alias or shortcut has no task
// file of its own; its kind comes from its target's (ASD-004 AC27). quick's command has no
// argument-hint, so its arguments come from the task frontmatter; ba's come from run's task;
// doctor has neither and its page says "none". ghost has a task template but no command, so no page.
const COMMANDS = {
	run: { description: "Implement one step of a plan", hint: "<plan path> <step>" },
	review: { description: "Review the change against the spec and the definition of done", hint: "[working tree or branch]" },
	quick: { description: "Complete a small well-understood change" },
	check: { description: "Deprecated — use /fc:review. Runs the review task under its old name", hint: "[working tree or branch]" },
	doctor: { description: "Report what is wrong with this setup" },
	ba: { description: "Shortcut for /fc:run — Implement one step of a plan" },
};
const TASKS = {
	run: { description: "Implement one step of a plan", hint: "<plan path> <step>" },
	review: { description: "Review the change against the spec and the definition of done", hint: "[working tree or branch]" },
	quick: { description: "Complete a small well-understood change", hint: "<change and expected result>" },
	ghost: { description: "A task with no command", hint: "<ghost input>" },
};
const GROUPS = [
	"<!-- Group table for docs/commands.md. Links in _notes/<name>.md are written relative to docs/commands/<name>.md. -->",
	"| Group | Commands |",
	"|---|---|",
	"| [Setup and maintenance](#setup-and-maintenance) | `doctor` |",
	"| [Build and verify](#build-and-verify) | `run`, `quick`, `ba` |",
	"| [Review and hand off](#review-and-hand-off) | `review`, `check` (deprecated) |",
	"",
].join("\n");
const WORKFLOW_LINK = "[the main loop](../../ai-factory/docs/workflow.md#4-the-main-loop)";

// A disposable plugin repo with the scripts copied to the same relative place, so sync-docs.js
// resolves its root to this tree.
function fixture({ copy = true } = {}) {
	const root = path.join(scratch, `repo-${++fixtures}`);
	fs.mkdirSync(root, { recursive: true });
	touch(root, ".claude-plugin/plugin.json", `${JSON.stringify({ name: "fc", version: "9.8.7" }, null, 2)}\n`);
	for (const [name, spec] of Object.entries(COMMANDS)) touch(root, `commands/${name}.md`, command(spec));
	for (const [name, spec] of Object.entries(TASKS)) touch(root, `${TASKS_REL}/${name}.md`, task(spec));
	touch(root, "ai-factory/docs/workflow.md", "# Workflow\n\n## 4. The main loop\n\nText.\n");
	touch(root, "CHANGELOG.md", "# Changelog\n\n## 9.8.7\n\n- Fixture.\n");
	touch(root, "README.md", "# Fixture\n\nSee [the docs](docs/README.md).\n");
	touch(root, "docs/README.md", "# fc docs\n\n> For fc ai-sdlc 9.8.7.\n\nSee [commands](commands.md).\n");
	touch(root, "docs/commands/_notes/_groups.md", GROUPS);
	for (const name of Object.keys(COMMANDS))
		touch(root, `docs/commands/_notes/${name}.md`, name === "run" ? notes(name, ` See ${WORKFLOW_LINK}.`) : notes(name));
	if (copy) {
		for (const file of ["sync-docs.js", "_frontmatter.js"])
			if (fs.existsSync(path.resolve(SCRIPTS_REL, file)))
				touch(root, `${SCRIPTS_REL}/${file}`, fs.readFileSync(path.resolve(SCRIPTS_REL, file)));
	}
	return root;
}
const sync = (root, ...args) =>
	spawnSync(process.execPath, [path.join(root, SCRIPTS_REL, "sync-docs.js"), ...args], { cwd: root, encoding: "utf8" });
function generate(root) {
	const run = sync(root);
	assert.equal(run.status, 0, `sync-docs.js exited ${run.status}: ${(run.stderr || "").trim().split("\n")[0]}`);
	return run;
}
// Every file under `dir` of `root`, relative path to bytes.
function snapshot(root, dir) {
	const out = new Map();
	const walk = (abs) => {
		if (!fs.existsSync(abs)) return;
		for (const entry of fs.readdirSync(abs, { withFileTypes: true })) {
			const file = path.join(abs, entry.name);
			if (entry.isDirectory()) walk(file);
			else out.set(path.relative(root, file).split(path.sep).join("/"), fs.readFileSync(file).toString("base64"));
		}
	};
	walk(path.join(root, dir));
	return out;
}
// Page text with HTML-escaped angle brackets folded back, so `<plan path>` matches either form.
const page = (root, name) => read(root, `docs/commands/${name}.md`).replace(/&lt;/g, "<").replace(/&gt;/g, ">");
const line = (text, label, rel) => {
	const found = text.split("\n").find((l) => label.test(l));
	assert.ok(found, `${rel} has no ${label} line`);
	return found;
};
// Every require() in a source: literal specifiers, and a count of non-literal calls.
function requires(source) {
	const literal = [...source.matchAll(/\brequire\(\s*(['"`])([^'"`]+)\1\s*\)/g)].map((m) => m[2]);
	const all = (source.match(/\brequire\s*\(/g) || []).length;
	return { literal, dynamic: all - literal.length };
}
const isBuiltin = (spec) => spec.startsWith("node:") ? builtinModules.includes(spec.slice(5)) || builtinModules.includes(spec) : builtinModules.includes(spec);

const cases = [];
const test = (group, name, fn) => cases.push({ group, name, fn });

// ---- reader (AC9, AC10, AC11) -------------------------------------------------------------
test("reader", "AC9-builtins-only", () => {
	needSync();
	for (const [file, allowed] of [
		[READER, []],
		[SYNC, ["./_frontmatter.js", "./_frontmatter"]],
	]) {
		const rel = path.relative(process.cwd(), file);
		const { literal, dynamic } = requires(fs.readFileSync(file, "utf8"));
		assert.equal(dynamic, 0, `${rel} has a require() with a non-literal argument`);
		for (const spec of literal)
			assert.ok(isBuiltin(spec) || allowed.includes(spec), `${rel} requires ${spec}, which is not a Node built-in`);
		assert.doesNotMatch(fs.readFileSync(file, "utf8"), /^\s*import\s/m, `${rel} uses an ES import`);
	}
});
test("reader", "AC10-require-no-side-effect", () => {
	needReader();
	const root = fixture();
	const before = snapshot(root, ".");
	const probe = spawnSync(
		process.execPath,
		["-e", `const m = require(${JSON.stringify(path.join(root, SCRIPTS_REL, "_frontmatter.js"))}); process.stdout.write(typeof m === "function" ? "function" : Object.values(m || {}).filter((v) => typeof v === "function").length === 1 ? "function" : "other");`],
		{ cwd: root, encoding: "utf8" },
	);
	assert.equal(probe.status, 0, `requiring _frontmatter.js exited ${probe.status}: ${(probe.stderr || "").trim().split("\n")[0]}`);
	assert.equal(probe.stdout, "function", "requiring _frontmatter.js returns the frontmatter reader");
	assert.ok(!exists(root, "docs/commands.md"), "requiring the reader ran the generator (docs/commands.md was written)");
	assert.deepEqual([...snapshot(root, ".").entries()].sort(), [...before.entries()].sort(), "requiring the reader wrote or changed a file");
});
test("reader", "AC10-frontmatter-only", () => {
	needReader();
	const parse = readerOf(READER);
	const fm = parse("---\ndescription: real one\nargument-hint: <x> [y]\n---\nBody.\ndescription: fake\n\n---\ndescription: also fake\n---\n");
	assert.equal(fm.description, "real one", "description comes from the frontmatter block, not the body");
	assert.equal(fm["argument-hint"], "<x> [y]", "argument-hint is returned as its string");
	const colon = parse("---\ndescription: Deprecated — use /fc:review. Runs the review task\nargument-hint: [a|b|c]\n---\n");
	assert.equal(colon.description, "Deprecated — use /fc:review. Runs the review task", "a value keeps everything after the first ': '");
	assert.equal(colon["argument-hint"], "[a|b|c]", "a bracketed value stays a string");
	const none = parse("# No frontmatter\n\ndescription: body only\n") || {};
	assert.notEqual(none.description, "body only", "a file with no frontmatter block yields no description from its body");
	const real = parse(fs.readFileSync("commands/run.md", "utf8"));
	assert.equal(real.description, "Implement one step of a plan", "reads commands/run.md");
});
test("reader", "AC10-sync-uses-reader", () => {
	needSync();
	const { literal } = requires(fs.readFileSync(SYNC, "utf8"));
	assert.ok(literal.some((s) => s === "./_frontmatter.js" || s === "./_frontmatter"), "sync-docs.js does not require ./_frontmatter.js");
	// Behaviour: a reader that tags every description must show up in the generated pages.
	const root = fixture();
	const dir = path.join(root, SCRIPTS_REL);
	fs.renameSync(path.join(dir, "_frontmatter.js"), path.join(dir, "_frontmatter.real.js"));
	fs.writeFileSync(
		path.join(dir, "_frontmatter.js"),
		[
			'const real = require("./_frontmatter.real.js");',
			'const wrap = (fn) => (...args) => { const r = fn(...args); if (r && typeof r.description === "string") r.description += " VIA-READER"; return r; };',
			"if (typeof real === 'function') module.exports = wrap(real);",
			"else { module.exports = {}; for (const [k, v] of Object.entries(real)) module.exports[k] = typeof v === 'function' ? wrap(v) : v; }",
			"",
		].join("\n"),
	);
	generate(root);
	assert.match(page(root, "run"), /Implement one step of a plan VIA-READER/, "docs/commands/run.md: the description did not come through _frontmatter.js");
});
test("reader", "AC11-sync-scripts-untouched", () => {
	// ASD-004 (AC4, AC7) changes both generators to add shortcut entry points, so they are no longer
	// compared with ASD-003's baseline. What must hold: each one's output is current, and the
	// deprecated entry points it already wrote stay byte-identical to PRE_ASD004 (ASD-004 AC6).
	for (const script of ["sync-claude-commands.js", "sync-codex-skills.js"]) {
		const rel = `${SCRIPTS_REL}/${script}`;
		const check = spawnSync(process.execPath, [rel, "--check"], { encoding: "utf8" });
		assert.equal(check.status, 0, `${rel} --check exited ${check.status}: ${(check.stderr || check.stdout || "").trim().split("\n")[0]}`);
	}
	const present = spawnSync("git", ["cat-file", "-e", `${PRE_ASD004}^{commit}`], { encoding: "utf8" });
	assert.equal(present.status, 0, `commit ${PRE_ASD004} (the commit before plan ASD-004) is not in this clone; a shallow clone lacks it, so fetch it (git fetch --unshallow) and run again`);
	for (const rel of ["commands/check.md", "codex-skills/fc-check/SKILL.md"]) {
		const diff = spawnSync("git", ["diff", "--quiet", PRE_ASD004, "--", rel], { encoding: "utf8" });
		assert.equal(diff.status, 0, `${rel} differs from ${PRE_ASD004} (status ${diff.status}): ${(diff.stderr || "").trim().split("\n")[0]}`);
	}
});

// ---- generate (AC12, AC13, AC14, AC16, AC18, AC19) ----------------------------------------
test("generate", "AC12-one-page-per-command", () => {
	needSync();
	const root = fixture();
	generate(root);
	assert.ok(exists(root, "docs/commands.md"), "docs/commands.md was not written");
	const pages = fs
		.readdirSync(path.join(root, "docs/commands"), { withFileTypes: true })
		.filter((e) => e.isFile() && e.name.endsWith(".md"))
		.map((e) => e.name.slice(0, -3))
		.sort();
	assert.deepEqual(pages, Object.keys(COMMANDS).sort(), "docs/commands/ holds exactly one page per commands/<name>.md");
	assert.ok(!exists(root, "docs/commands/ghost.md"), "a page was written for ghost, which has a task but no command");
	const index = read(root, "docs/commands.md");
	for (const name of Object.keys(COMMANDS)) {
		assert.match(index, new RegExp(`/fc:${name}\\b`), `docs/commands.md does not list /fc:${name}`);
		assert.match(index, new RegExp(`\\]\\((\\./)?commands/${name}\\.md\\)`), `docs/commands.md does not link commands/${name}.md`);
	}
	assert.doesNotMatch(index, /\/fc:ghost\b/, "docs/commands.md lists ghost, which has no command");
});
test("generate", "AC12-index-from-groups", () => {
	needSync();
	const root = fixture();
	generate(root);
	const index = read(root, "docs/commands.md");
	const order = ["Setup and maintenance", "Build and verify", "Review and hand off"].map((group) => {
		const at = index.indexOf(group);
		assert.ok(at >= 0, `docs/commands.md does not carry the group "${group}" from _notes/_groups.md`);
		return at;
	});
	assert.deepEqual([...order].sort((a, b) => a - b), order, "docs/commands.md keeps the group order of _notes/_groups.md");
});
test("generate", "AC13-page-fields", () => {
	needSync();
	const root = fixture();
	generate(root);
	const expect = {
		run: { kind: /project task/i, args: "<plan path> <step>" },
		review: { kind: /project task/i, args: "[working tree or branch]" },
		quick: { kind: /project task/i, args: "<change and expected result>" }, // from the task frontmatter
		check: { kind: /project task/i, args: "[working tree or branch]" }, // kind from review (ASD-004 AC27)
		doctor: { kind: /plugin-level/i, args: null }, // no hint anywhere: "none"
		ba: { kind: /project task/i, args: "<plan path> <step>" }, // kind and arguments from run's task
	};
	for (const [name, want] of Object.entries(expect)) {
		const rel = `docs/commands/${name}.md`;
		const text = page(root, name);
		assert.match(text, new RegExp(`/fc:${name}\\b`), `${rel} does not state /fc:${name}`);
		assert.ok(text.includes(`$fc-${name}`), `${rel} does not state the Codex name $fc-${name}`);
		assert.ok(text.includes(COMMANDS[name].description), `${rel} does not state the description from commands/${name}.md`);
		const kind = line(text, /\bkind\b/i, rel);
		assert.match(kind, want.kind, `${rel}: kind line "${kind.trim()}"`);
		assert.doesNotMatch(kind, want.kind.source.includes("project") ? /plugin-level/i : /project task/i, `${rel}: kind line "${kind.trim()}" names both kinds`);
		const args = line(text, /argument/i, rel);
		if (want.args) assert.ok(args.includes(want.args), `${rel}: arguments line "${args.trim()}" lacks ${want.args}`);
		else assert.match(args, /\bnone\b/i, `${rel}: arguments line "${args.trim()}" does not say none`);
	}
});
test("generate", "AC14-notes-merged", () => {
	needSync();
	const root = fixture();
	generate(root);
	for (const name of Object.keys(COMMANDS)) {
		const rel = `docs/commands/${name}.md`;
		const body = read(root, `docs/commands/_notes/${name}.md`).trim();
		assert.ok(read(root, rel).includes(body), `${rel} does not hold docs/commands/_notes/${name}.md verbatim`);
	}
	assert.doesNotMatch(read(root, "docs/commands/doctor.md"), /NOTE-run-/, "docs/commands/doctor.md holds another command's notes");
});
test("generate", "AC16-check-deprecated", () => {
	needSync();
	const root = fixture();
	generate(root);
	const text = page(root, "check");
	assert.match(text, /deprecated/i, "docs/commands/check.md does not mark /fc:check as deprecated");
	assert.match(text, /\]\((\.\/)?review\.md(#[^)]*)?\)/, "docs/commands/check.md does not link the /fc:review page (review.md)");
	assert.doesNotMatch(text, /\*\*Shortcut\.\*\*/, "docs/commands/check.md is marked as a shortcut; it is deprecated");
});
// ASD-004 AC27: a shortcut page is marked as one, links its target, and takes its kind from the
// target's task file; so does the index row, and the index sentence counts it apart from both the
// project tasks and the plugin-level commands.
test("generate", "AC27-shortcut-page", () => {
	needSync();
	const root = fixture();
	generate(root);
	const rel = "docs/commands/ba.md";
	const text = page(root, "ba");
	assert.match(text, /^> \*\*Shortcut\.\*\* Runs \[`\/fc:run`\]\(run\.md\) under a shorter name\.$/m, `${rel} does not mark /fc:ba as a shortcut of /fc:run with a link to run.md`);
	assert.doesNotMatch(text, /deprecated/i, `${rel} calls the shortcut deprecated`);
	const kind = line(text, /\bkind\b/i, rel);
	assert.match(kind, /project task/i, `${rel}: kind line "${kind.trim()}" is not taken from run (a project task)`);
	assert.doesNotMatch(kind, /plugin-level/i, `${rel}: kind line "${kind.trim()}" says plugin-level`);
	assert.ok(kind.includes("`ai-factory/tasks/run.md`"), `${rel}: kind line "${kind.trim()}" does not name the target's task file`);
	assert.ok(!kind.includes("tasks/ba.md"), `${rel}: kind line "${kind.trim()}" names a ba task file, which does not exist`);
	const index = read(root, "docs/commands.md");
	const row = line(index, /\[`\/fc:ba`\]/, "docs/commands.md");
	assert.match(row, /\| Project task \|/, `docs/commands.md: the /fc:ba row "${row}" is not a project task`);
	const summary = line(index, /The plugin ships/, "docs/commands.md");
	for (const want of ["**6**", "The 3 project tasks", "2 more are shortcut or deprecated names that run one of them; the other 1 are plugin-level"])
		assert.ok(summary.includes(want), `docs/commands.md: summary "${summary}" lacks "${want}"`);
});
test("generate", "AC27-deprecated-kind-from-target", () => {
	needSync();
	const root = fixture();
	generate(root);
	const rel = "docs/commands/check.md";
	const kind = line(page(root, "check"), /\bkind\b/i, rel);
	assert.match(kind, /project task/i, `${rel}: kind line "${kind.trim()}" is not taken from review (a project task)`);
	assert.doesNotMatch(kind, /plugin-level/i, `${rel}: kind line "${kind.trim()}" says plugin-level`);
	assert.ok(kind.includes("`ai-factory/tasks/review.md`"), `${rel}: kind line "${kind.trim()}" does not name review's task file`);
	const row = line(read(root, "docs/commands.md"), /\[`\/fc:check`\]/, "docs/commands.md");
	assert.match(row, /\| Project task \|/, `docs/commands.md: the /fc:check row "${row}" is not a project task`);
});
test("generate", "AC18-workflow-link-kept", () => {
	needSync();
	const root = fixture();
	generate(root);
	assert.ok(read(root, "docs/commands/run.md").includes(WORKFLOW_LINK), `docs/commands/run.md does not carry ${WORKFLOW_LINK} from its notes`);
});
test("generate", "AC19-idempotent", () => {
	needSync();
	const root = fixture();
	generate(root);
	const first = snapshot(root, "docs");
	generate(root);
	const second = snapshot(root, "docs");
	assert.deepEqual([...second.keys()].sort(), [...first.keys()].sort(), "a second run added or removed a file under docs/");
	for (const [rel, bytes] of first) assert.equal(second.get(rel), bytes, `a second run changed ${rel}`);
});

// ---- shared by prune, check and notes -----------------------------------------------------
const checkRun = (root) => sync(root, "--check");
const outputOf = (run) => `${run.stderr || ""}${run.stdout || ""}`;
// --check failed, and for each group of patterns one output line matches all of them.
function failsNaming(run, ...wanted) {
	const out = outputOf(run);
	assert.notEqual(run.status, 0, `--check exited 0; expected a failure naming ${wanted.map((w) => [].concat(w).map(String).join(" + ")).join("; ")}`);
	const lines = out.split("\n");
	for (const want of wanted) {
		const all = [].concat(want);
		assert.ok(
			lines.some((l) => all.every((p) => (p instanceof RegExp ? p.test(l) : l.includes(p)))),
			`--check output has no line naming ${all.map(String).join(" + ")}; got: ${out.trim().split("\n").slice(0, 4).join(" | ")}`,
		);
	}
	return lines;
}
function passesCheck(run) {
	assert.equal(run.status, 0, `--check exited ${run.status}: ${outputOf(run).trim().split("\n").slice(0, 3).join(" | ")}`);
}
// Every file under `dir` of `root`, relative path to size and mtime.
function stamps(root, dir) {
	const out = new Map();
	for (const rel of snapshot(root, dir).keys()) {
		const st = fs.statSync(path.join(root, rel));
		out.set(rel, `${st.size}:${st.mtimeMs}`);
	}
	return out;
}
const sameTree = (after, before, what) => {
	assert.deepEqual([...after.keys()].sort(), [...before.keys()].sort(), `${what}: a file was added or removed`);
	for (const [rel, value] of before) assert.equal(after.get(rel), value, `${what}: ${rel} changed`);
};
const ORPHAN = "docs/commands/ghost.md"; // ghost has a task template but no command

// ---- prune (AC20, R3) ---------------------------------------------------------------------
test("prune", "AC20-orphan-deleted", () => {
	needSync();
	const root = fixture();
	generate(root);
	touch(root, ORPHAN, "# /fc:ghost\n\nAn old page.\n");
	touch(root, "docs/commands/retired.md", "# /fc:retired\n");
	generate(root);
	assert.ok(!exists(root, ORPHAN), `${ORPHAN} has no commands/ghost.md and survived the write run`);
	assert.ok(!exists(root, "docs/commands/retired.md"), "docs/commands/retired.md has no commands/retired.md and survived the write run");
	for (const name of Object.keys(COMMANDS)) assert.ok(exists(root, `docs/commands/${name}.md`), `prune deleted docs/commands/${name}.md, which has a command`);
});
test("prune", "AC20-non-md-kept", () => {
	needSync();
	const root = fixture();
	generate(root);
	touch(root, ORPHAN, "# orphan\n");
	const kept = { "docs/commands/ghost.txt": "not a page\n", "docs/commands/diagram.png": "\x89PNG fake\n", "docs/commands/ghost.md.bak": "backup\n" };
	for (const [rel, text] of Object.entries(kept)) touch(root, rel, text);
	generate(root);
	assert.ok(!exists(root, ORPHAN), `${ORPHAN} survived, so this case proves nothing about what prune keeps`);
	for (const [rel, text] of Object.entries(kept)) {
		assert.ok(exists(root, rel), `prune deleted ${rel}, which is not a .md file`);
		assert.equal(read(root, rel), text, `prune changed ${rel}`);
	}
});
test("prune", "AC20-notes-byte-identical", () => {
	needSync();
	const root = fixture();
	// Notes that look like orphans: a notes file with no command, a stray file and a nested dir.
	touch(root, "docs/commands/_notes/ghost.md", "## Usage\n\nNo command for this one.\n");
	touch(root, "docs/commands/_notes/draft.txt", "draft\n");
	touch(root, "docs/commands/_notes/old/ghost.md", "## Usage\n\nOlder.\n");
	generate(root);
	touch(root, ORPHAN, "# orphan\n");
	const before = snapshot(root, "docs/commands/_notes");
	generate(root);
	assert.ok(!exists(root, ORPHAN), `${ORPHAN} survived, so this case proves nothing about what prune keeps`);
	sameTree(snapshot(root, "docs/commands/_notes"), before, "docs/commands/_notes/ after a write run with an orphan");
});
test("prune", "AC20-nothing-outside-top-level-deleted", () => {
	needSync();
	const root = fixture();
	generate(root);
	touch(root, ORPHAN, "# orphan\n");
	// Orphan-looking .md files below the top level of docs/commands/ and elsewhere under docs/.
	touch(root, "docs/commands/archive/ghost.md", "# archived ghost\n");
	touch(root, "docs/commands/archive/deep/retired.md", "# deeper\n");
	touch(root, "docs/commands/dir.md/inside.md", "# a directory named like a page\n");
	touch(root, "docs/ghost.md", "# not in docs/commands\n");
	touch(root, "docs/workflows/ghost.md", "# workflow page\n"); // path-scan-ok: the user docs' workflows/ dir, not the old layout
	const before = snapshot(root, ".");
	generate(root);
	const after = snapshot(root, ".");
	const deleted = [...before.keys()].filter((rel) => !after.has(rel)).sort();
	assert.deepEqual(deleted, [ORPHAN], `the write run deleted ${deleted.join(", ") || "nothing"}; expected only ${ORPHAN}`);
	for (const [rel, bytes] of after) if (before.has(rel)) assert.equal(bytes, before.get(rel), `the write run changed ${rel}`);
});

// ---- check (AC21, AC22, AC23, orphans) ----------------------------------------------------
test("check", "AC21-current-exit0-no-write", () => {
	needSync();
	const root = fixture();
	generate(root);
	const bytes = snapshot(root, ".");
	const times = stamps(root, ".");
	passesCheck(checkRun(root));
	sameTree(snapshot(root, "."), bytes, "--check on current output (bytes)");
	sameTree(stamps(root, "."), times, "--check on current output (size and mtime)");
});
test("check", "AC22-stale-page-named", () => {
	needSync();
	const root = fixture();
	generate(root);
	fs.appendFileSync(path.join(root, "docs/commands/run.md"), "A hand edit.\n");
	fs.appendFileSync(path.join(root, "docs/commands.md"), "A hand edit.\n");
	fs.rmSync(path.join(root, "docs/commands/doctor.md"));
	const before = snapshot(root, ".");
	const lines = failsNaming(checkRun(root), ["docs/commands/run.md", /stale/i], ["docs/commands.md", /stale/i], ["docs/commands/doctor.md", /missing/i]);
	for (const name of ["review", "quick", "check"])
		assert.ok(!lines.some((l) => l.includes(`docs/commands/${name}.md`)), `--check names docs/commands/${name}.md, which is current`);
	sameTree(snapshot(root, "."), before, "--check with stale and missing pages");
});
test("check", "AC22-description-change-named", () => {
	needSync();
	const root = fixture();
	generate(root);
	touch(root, "commands/review.md", command({ ...COMMANDS.review, description: "Review the change, now described differently" }));
	const before = snapshot(root, ".");
	const lines = failsNaming(checkRun(root), ["docs/commands/review.md", /stale/i], ["docs/commands.md", /stale/i]);
	for (const name of ["run", "quick", "check", "doctor"])
		assert.ok(!lines.some((l) => l.includes(`docs/commands/${name}.md`)), `--check names docs/commands/${name}.md, whose command did not change`);
	sameTree(snapshot(root, "."), before, "--check after a description change");
});
test("check", "AC23-missing-notes-named", () => {
	needSync();
	const root = fixture();
	fs.rmSync(path.join(root, "docs/commands/_notes/doctor.md"));
	generate(root); // pages current, so only the missing notes can fail
	const before = snapshot(root, ".");
	failsNaming(checkRun(root), [/\bdoctor\b/, /notes/i]);
	sameTree(snapshot(root, "."), before, "--check with a missing notes file");
	assert.ok(!exists(root, "docs/commands/_notes/doctor.md"), "--check created docs/commands/_notes/doctor.md");
});
test("check", "orphan-reported-not-deleted", () => {
	needSync();
	const root = fixture();
	generate(root);
	touch(root, ORPHAN, "# orphan\n");
	const before = snapshot(root, ".");
	failsNaming(checkRun(root), [ORPHAN, /orphan/i]);
	assert.ok(exists(root, ORPHAN), `--check deleted ${ORPHAN}; it must only report it`);
	sameTree(snapshot(root, "."), before, "--check with an orphan page");
});
test("check", "ungrouped-command-named", () => {
	needSync();
	const root = fixture();
	edit(root, "docs/commands/_notes/_groups.md", (t) => t.replace("| `doctor` |", "| `quick` |").replace("`run`, `quick`", "`run`"));
	generate(root); // pages current, so only the missing group can fail
	failsNaming(checkRun(root), [/\bdoctor\b/, /group/i, "_groups.md"]);
});

// ---- notes (AC18, AC24, AC25) -------------------------------------------------------------
// Edit notes, then generate, so the pages are current and only the notes structure can fail.
const dropSection = (text, heading) => text.replace(new RegExp(`## ${heading}\\n[\\s\\S]*?(?=\\n## |$)`), "");
const emptySection = (text, heading, filler) => text.replace(new RegExp(`(## ${heading}\\n)[\\s\\S]*?(?=\\n## |$)`), `$1${filler}`);
const notesRel = (name) => `docs/commands/_notes/${name}.md`;
const edit = (root, rel, fn) => touch(root, rel, fn(read(root, rel)));
function notesFailures(root) {
	const run = checkRun(root);
	return { run, lines: outputOf(run).split("\n").filter((l) => l.includes("_notes/")) };
}
test("notes", "AC24-missing-heading-named", () => {
	needSync();
	const root = fixture();
	edit(root, notesRel("review"), (t) => dropSection(t, "Examples")); // a heading with another H2 after it
	edit(root, notesRel("doctor"), (t) => dropSection(t, "Refuses or asks")); // the last heading
	assert.doesNotMatch(read(root, notesRel("review")), /## Examples/, "fixture: review notes still have ## Examples");
	assert.doesNotMatch(read(root, notesRel("doctor")), /## Refuses or asks/, "fixture: doctor notes still have ## Refuses or asks");
	generate(root);
	const { run, lines } = notesFailures(root);
	failsNaming(run, [notesRel("review"), "## Examples"], [notesRel("doctor"), "## Refuses or asks"]);
	assert.equal(lines.length, 2, `expected exactly the two notes failures; got: ${lines.join(" | ")}`);
});
test("notes", "AC24-empty-heading-named", () => {
	needSync();
	const root = fixture();
	// Only whitespace before the next H2, and only whitespace before the end of the file.
	edit(root, notesRel("review"), (t) => emptySection(t, "Examples", "\n  \n\t\n"));
	edit(root, notesRel("doctor"), (t) => emptySection(t, "Refuses or asks", "\n   \n\n"));
	edit(root, notesRel("quick"), (t) => emptySection(t, "Usage", ""));
	assert.match(read(root, notesRel("doctor")), /## Refuses or asks\n\s*$/, "fixture: doctor notes do not end in an empty section");
	generate(root);
	const { run, lines } = notesFailures(root);
	failsNaming(run, [notesRel("review"), "## Examples"], [notesRel("doctor"), "## Refuses or asks"], [notesRel("quick"), "## Usage"]);
	assert.equal(lines.length, 3, `expected exactly the three notes failures; got: ${lines.join(" | ")}`);
});
test("notes", "AC25-check-usage-only-ok", () => {
	needSync();
	const root = fixture();
	touch(root, notesRel("check"), "## Usage\n\nDeprecated: run [`/fc:review`](review.md) instead.\n");
	generate(root);
	passesCheck(checkRun(root));
	// The exemption is for the other three headings only: an empty Usage still fails.
	touch(root, notesRel("check"), "## Usage\n\n  \n");
	generate(root);
	failsNaming(checkRun(root), [notesRel("check"), "## Usage"]);
});
// ASD-004 AC29: a shortcut, like a deprecated alias, needs only a non-empty ## Usage.
test("notes", "AC29-shortcut-usage-only-ok", () => {
	needSync();
	const root = fixture();
	touch(root, notesRel("ba"), "## Usage\n\nThe same task as [`/fc:run`](run.md), under a shorter name.\n");
	generate(root);
	passesCheck(checkRun(root));
	touch(root, notesRel("ba"), "## Usage\n\n  \n");
	generate(root);
	const { run, lines } = notesFailures(root);
	failsNaming(run, [notesRel("ba"), "## Usage"]);
	assert.equal(lines.length, 1, `expected only the empty ## Usage of ba; got: ${lines.join(" | ")}`);
});
test("notes", "AC29-non-shortcut-still-needs-four", () => {
	needSync();
	const root = fixture();
	touch(root, notesRel("ba"), "## Usage\n\nThe same task as [`/fc:run`](run.md).\n");
	touch(root, notesRel("check"), "## Usage\n\nDeprecated: run [`/fc:review`](review.md) instead.\n");
	edit(root, notesRel("review"), (t) => dropSection(t, "Examples"));
	generate(root);
	const { run, lines } = notesFailures(root);
	failsNaming(run, [notesRel("review"), "## Examples"]);
	assert.equal(lines.length, 1, `expected only review's missing ## Examples; got: ${lines.join(" | ")}`);
});
test("notes", "AC18-no-workflow-link-ok", () => {
	needSync();
	const root = fixture();
	touch(root, notesRel("run"), notes("run"));
	for (const name of Object.keys(COMMANDS))
		assert.doesNotMatch(read(root, notesRel(name)), /workflow\.md/, `fixture: ${notesRel(name)} links workflow.md`);
	generate(root);
	passesCheck(checkRun(root));
});

// ---- links (AC26, AC27, AC28, AC29, AC30, AC31, R1, R8) -----------------------------------
// Each case generates first, so the pages are current and only the link or version line it
// breaks can fail. A hand-written page under docs/ carries the links under test.
const GUIDE = "docs/guide.md";
function linksRun(root) {
	generate(root);
	return checkRun(root);
}
// --check output lines that name `text`.
const naming = (run, text) => outputOf(run).split("\n").filter((l) => l.includes(text));
const notNamed = (run, text, why) => assert.equal(naming(run, text).length, 0, `--check names ${text}, ${why}: ${naming(run, text).join(" | ")}`);
const mermaid = (...clicks) => ["```mermaid", "flowchart TD", "  A[Start] --> B[Run]", ...clicks, "```"].join("\n");

test("links", "AC26-broken-relative-named", () => {
	needSync();
	const root = fixture();
	fs.rmSync(path.join(root, "CHANGELOG.md"));
	touch(
		root,
		GUIDE,
		[
			"# Guide",
			"",
			"See [the changelog](../CHANGELOG.md), [a missing page](missing-page.md) and [a workflow](workflows/none.md).",
			"Fine: [the index](README.md), [run](commands/run.md), [the web](https://example.com/nope.md), [mail](mailto:a@b.c).",
			"Code, not links: `[inline](inline-missing.md)`.",
			"",
			"```",
			"[fenced](fenced-missing.md)",
			"```",
			"",
		].join("\n"),
	);
	const run = linksRun(root);
	failsNaming(
		run,
		[GUIDE, "../CHANGELOG.md", /does not exist/],
		[GUIDE, "missing-page.md", /does not exist/],
		[GUIDE, "workflows/none.md", /does not exist/],
	);
	for (const ok of ["(README.md)", "commands/run.md", "example.com", "mailto:"]) notNamed(run, ok, "which is not a broken link");
	notNamed(run, "inline-missing.md", "which is inside an inline code span");
	notNamed(run, "fenced-missing.md", "which is inside a fenced code block");
});
test("links", "AC27-outside-repo-named-existing", () => {
	needSync();
	const root = fixture();
	// ../../outside.md from docs/ is the fixture root's parent: it exists, but outside the repo.
	touch(path.dirname(root), "outside.md", "# Outside\n");
	assert.ok(fs.existsSync(path.resolve(root, "docs", "../../outside.md")), "fixture: the outside target does not exist");
	touch(root, GUIDE, "# Guide\n\nSee [outside](../../outside.md).\n");
	failsNaming(linksRun(root), [GUIDE, "../../outside.md", /outside the repository/]);
});
test("links", "AC27-outside-repo-named-missing", () => {
	needSync();
	const root = fixture();
	assert.ok(!fs.existsSync(path.resolve(root, "docs", "../../nowhere-outside.md")), "fixture: the outside target exists");
	touch(root, GUIDE, "# Guide\n\nSee [nowhere](../../nowhere-outside.md).\n");
	failsNaming(linksRun(root), [GUIDE, "../../nowhere-outside.md", /outside the repository/]);
});
test("links", "AC28-bad-fragment-same-page", () => {
	needSync();
	const root = fixture();
	touch(root, GUIDE, "# Guide\n\n## Real heading\n\nGood: [here](#real-heading). Bad: [there](#not-a-heading).\n");
	const run = linksRun(root);
	failsNaming(run, [GUIDE, "#not-a-heading"]);
	notNamed(run, "#real-heading", "which matches ## Real heading");
});
test("links", "AC28-bad-fragment-other-page", () => {
	needSync();
	const root = fixture();
	touch(
		root,
		GUIDE,
		"# Guide\n\nBad: [index](README.md#no-such-section), [run](commands/run.md#no-such-usage).\nGood: [usage](commands/run.md#usage).\n",
	);
	const run = linksRun(root);
	failsNaming(run, [GUIDE, "README.md#no-such-section", "docs/README.md"], [GUIDE, "commands/run.md#no-such-usage", "docs/commands/run.md"]);
	notNamed(run, "link commands/run.md#usage ", "which matches ## Usage on the generated page");
});
test("links", "AC28-good-fragment-refuses-or-asks", () => {
	needSync();
	const root = fixture();
	// Pins the slug rule: lowercase; drop all but letters, digits, space, - and _; spaces to -;
	// a repeated slug gets -1, -2. _groups.md already links #review-and-hand-off in docs/commands.md.
	touch(
		root,
		GUIDE,
		[
			"# Guide",
			"",
			"## Refuses or asks",
			"## What's /fc:run? (v2)",
			"## Snake_case and-dash",
			"## Usage",
			"## Usage",
			"",
			"[a](commands/run.md#refuses-or-asks) [b](#refuses-or-asks) [c](#whats-fcrun-v2) [d](#snake_case-and-dash)",
			"[e](#usage) [f](#usage-1) [g](commands.md#review-and-hand-off) [h](../ai-factory/docs/workflow.md#4-the-main-loop)",
			"",
		].join("\n"),
	);
	passesCheck(linksRun(root));
});
test("links", "AC29-click-missing-target", () => {
	needSync();
	const root = fixture();
	touch(root, GUIDE, `# Guide\n\n${mermaid('  click A "workflows/none.md"', '  click B "commands/run.md"')}\n`);
	const run = linksRun(root);
	failsNaming(run, [GUIDE, "workflows/none.md", /click/i]);
	notNamed(run, "target commands/run.md ", "an existing click target");
});
test("links", "AC29-click-bad-fragment", () => {
	needSync();
	const root = fixture();
	touch(root, GUIDE, `# Guide\n\n${mermaid('  click A "commands/run.md#no-such-heading"', '  click B "commands/run.md#usage"')}\n`);
	const run = linksRun(root);
	failsNaming(run, [GUIDE, "commands/run.md#no-such-heading", /click/i]);
	notNamed(run, "target commands/run.md#usage ", "a click target whose fragment matches ## Usage");
});
test("links", "AC30-root-readme-docs-link-missing", () => {
	needSync();
	const root = fixture();
	touch(root, "README.md", "# Fixture\n\nSee [the docs](docs/README.md), [gone](docs/gone.md) and [not docs](not-in-docs-missing.md).\n");
	const run = linksRun(root);
	failsNaming(run, [/--check: README\.md:\d/, "docs/gone.md", /does not exist/]);
	notNamed(run, "not-in-docs-missing.md", "a root README link whose target is not under docs/");
});
test("links", "AC31-version-line-missing", () => {
	needSync();
	const root = fixture();
	for (const text of ["# fc docs\n", "# fc docs\n\n"]) {
		touch(root, "docs/README.md", text);
		failsNaming(linksRun(root), ["docs/README.md", /line 3/, "9.8.7", ".claude-plugin/plugin.json"]);
	}
});
test("links", "AC31-version-line-malformed", () => {
	needSync();
	const root = fixture();
	for (const found of ["> Version: 9.8.7", "> For fc ai-sdlc 9.8.7", "For fc ai-sdlc 9.8.7."]) {
		touch(root, "docs/README.md", `# fc docs\n\n${found}\n\nSee [commands](commands.md).\n`);
		failsNaming(linksRun(root), ["docs/README.md", `"${found}"`, "> For fc ai-sdlc 9.8.7.", ".claude-plugin/plugin.json"]);
	}
});
test("links", "AC31-version-line-wrong-version", () => {
	needSync();
	const root = fixture();
	touch(root, "docs/README.md", "# fc docs\n\n> For fc ai-sdlc 1.2.3.\n\nSee [commands](commands.md).\n");
	failsNaming(linksRun(root), ["docs/README.md", "1.2.3", "9.8.7", ".claude-plugin/plugin.json"]);
});
test("links", "notes-link-resolved-from-generated-page", () => {
	needSync();
	const root = fixture();
	// From docs/commands/doctor.md these resolve; from docs/commands/_notes/ only the last does.
	edit(root, notesRel("doctor"), (t) => `${t}\nSee [the index](../commands.md#build-and-verify), [run](run.md#writes), [usage](#usage) and [groups](_groups.md).\n`);
	const run = linksRun(root);
	failsNaming(run, [notesRel("doctor"), "rendered in docs/commands/doctor.md", "_groups.md", "docs/commands/_groups.md", /does not exist/]);
	assert.equal(naming(run, "link _groups.md ").length, 1, `the notes link is reported once: ${naming(run, "_groups.md").join(" | ")}`);
	for (const ok of ["../commands.md", "run.md#writes", "#usage"]) notNamed(run, ok, "which resolves from the generated page");
	// And the pages are otherwise clean: without the bad link, --check passes.
	edit(root, notesRel("doctor"), (t) => t.replace(" and [groups](_groups.md)", ""));
	passesCheck(linksRun(root));
});

// ---- versions (AC34, R5) ------------------------------------------------------------------
// check-versions.sh reads docs/README.md line 3 as one more version. Each case is a scratch root
// holding a copy of check-versions.sh, the manifests it reads, all at 9.8.7, and a docs/README.md.
const VERSIONS = path.resolve(SCRIPTS_REL, "check-versions.sh");
function versionsFixture(readmeLine3) {
	if (!fs.existsSync(VERSIONS)) throw new Error(`${SCRIPTS_REL}/check-versions.sh does not exist`);
	const root = path.join(scratch, `repo-${++fixtures}`);
	const json = (value) => `${JSON.stringify(value, null, 2)}\n`;
	touch(root, ".claude-plugin/plugin.json", json({ name: "fc", version: "9.8.7" }));
	touch(root, ".codex-plugin/plugin.json", json({ name: "fc", version: "9.8.7" }));
	touch(root, ".claude-plugin/marketplace.json", json({ name: "fc", plugins: [{ name: "fc", source: "./", version: "9.8.7" }] }));
	touch(root, ".agents/plugins/marketplace.json", json({ name: "fc", plugins: [{ name: "fc", source: "./" }] }));
	touch(root, "docs/README.md", `# fc docs\n\n${readmeLine3}\n\nSee [commands](commands.md).\n`);
	touch(root, `${SCRIPTS_REL}/check-versions.sh`, fs.readFileSync(VERSIONS));
	return root;
}
const versionsRun = (root) => spawnSync("bash", [path.join(root, SCRIPTS_REL, "check-versions.sh")], { cwd: root, encoding: "utf8" });
// check-versions.sh failed, and one output line names docs/README.md together with `found`.
function versionsFailNaming(run, found) {
	const out = outputOf(run);
	assert.notEqual(run.status, 0, `check-versions.sh exited 0; expected a failure listing docs/README.md with ${found}: ${out.trim().split("\n")[0]}`);
	assert.ok(
		out.split("\n").some((l) => l.includes("docs/README.md") && l.includes(found)),
		`check-versions.sh output has no line naming docs/README.md + ${found}; got: ${out.trim().split("\n").slice(0, 6).join(" | ")}`,
	);
}
test("versions", "AC34-readme-version-disagrees", () => {
	const run = versionsRun(versionsFixture("> For fc ai-sdlc 1.2.3."));
	versionsFailNaming(run, "1.2.3");
	// The manifests are listed too, so the reader sees what the docs line disagrees with.
	assert.ok(outputOf(run).split("\n").some((l) => l.includes("9.8.7") && l.includes(".claude-plugin/plugin.json")), "the manifest version is not listed beside the docs line");
});
test("versions", "readme-version-agrees", () => {
	const run = versionsRun(versionsFixture("> For fc ai-sdlc 9.8.7."));
	assert.equal(run.status, 0, `check-versions.sh exited ${run.status}: ${outputOf(run).trim().split("\n").slice(0, 3).join(" | ")}`);
});
test("versions", "readme-line-malformed", () => {
	for (const found of ["> Version: 9.8.7", "> For fc ai-sdlc 9.8.7", "For fc ai-sdlc 9.8.7.", ""])
		versionsFailNaming(versionsRun(versionsFixture(found)), `"${found}"`);
});

// ---- groups that later steps of plan ASD-003 fill -----------------------------------------
const later = { prune: 3, check: 3, notes: 3, links: 4, versions: 10 };

async function main() {
	for (const c of cases) {
		if (!want(c.group)) continue;
		try {
			await c.fn();
			passed++;
			if (process.env.VERBOSE) console.log(`ok: ${c.group}/${c.name}`);
		} catch (error) {
			failures.push(`${c.group}/${c.name}: ${error.message.split("\n")[0]}`);
		}
	}
	for (const [name, step] of Object.entries(later))
		if (want(name) && !cases.some((c) => c.group === name))
			failures.push(`${name}: no cases yet (plan ASD-003 Step ${step} adds them)`);
}
main()
	.catch((error) => failures.push(`harness: ${error.stack}`))
	.finally(() => {
		fs.rmSync(scratch, { recursive: true, force: true });
		for (const line of failures) console.error(`FAIL ${line}`);
		if (failures.length) process.exitCode = 1;
		else console.log(`sync-docs ok — ${passed} cases (${selected})`);
	});
NODE
