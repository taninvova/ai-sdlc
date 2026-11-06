#!/usr/bin/env node
// The listing behind /fc:current (spec ASD-006): only the plans in progress under
// <repo-root>/ai-factory/plans/, never done/, each with its progress and the next step to pick up.
//   node current.js <repo-root> [--spec <id>]
// Prints a tab-separated header, `id state path progress next detail`, then one row per plan that
// is in progress or unreadable, sorted by path in byte order. With nothing to list, no plans
// directory, or an argument other than `--spec <id>`, it prints one line instead, never a table.
// `--spec <id>` keeps the plans whose **Spec:** line names that spec. It reads plan files only: it writes
// nothing, starts nothing, reads no mtime, and never looks under ai-factory/runs/.
// Exit 0 whatever it finds; exit 2 when <repo-root> is missing or not a directory.
//
// The step grammar and the runnable rule are the plugin's own: contracts.js's parsePlanSteps and
// loop.js's validatePlan, required from this plugin's templates (never from the inspected repo),
// so the listing needs no adopted ai-factory/make/ and cannot drift from /fc:loop.
"use strict";
const fs = require("node:fs");
const path = require("node:path");

const MAKE = path.join(__dirname, "..", "templates", "ai-factory", "make");
const { parsePlanSteps, unfenced } = require(path.join(MAKE, "contracts.js"));
const { validatePlan } = require(path.join(MAKE, "loop.js"));

const PLANS = "ai-factory/plans";
const HEADER = ["id", "state", "path", "progress", "next", "detail"];
const MARKS = [" ", "x", "X", "~"];
// A step line with any marker. The title is found as contracts.js's parsePlanSteps finds it (the
// first bold group, or the rest of the line), so a bad marker before `note **Step 2 — …**` is
// caught too, not silently dropped.
const ANY_MARKER = /^- \[([^\]]*)\](.*)$/;
function badMarker(line) {
	const match = line.match(ANY_MARKER);
	if (!match || MARKS.includes(match[1])) return false;
	const bold = match[2].match(/^[^*]*\*\*([^*]*)\*\*/);
	const title = (bold ? bold[1] : match[2]).trim();
	return /^Step\s+0*\d+(?![0-9])/.test(title);
}

const byteCompare = (a, b) => Buffer.compare(Buffer.from(a), Buffer.from(b));
// One field, one line: control characters (tabs and newlines included) become a space (R-B).
const field = (text) =>
	String(text)
		.replace(/[\u0000-\u001f\u007f-\u009f\u2028\u2029]/g, " ")
		.replace(/ +/g, " ")
		.trim();

// state.sh's id_of: the ID a basename starts with, uppercased, or "-".
function idOf(name) {
	const legacy = name.match(/^([0-9]{4})/);
	if (legacy) return legacy[1];
	const prefixed = name.match(/^([A-Za-z]{2,5}-[0-9]{3,})(?:[-.].*)?$/);
	if (prefixed) return prefixed[1].toUpperCase();
	const letters = name.match(/^([A-Za-z]{3}[0-9]{3})(?:[-.].*)?$/);
	if (letters) return letters[1].toUpperCase();
	return "-";
}

// The step's title after `Step N — ` (or ` – `, ` - `), bold stripped.
function detailOf(step) {
	const rest = step.text.split("\n")[0];
	const bold = rest.match(/^[^*]*\*\*([^*]*)\*\*/);
	const title = field((bold ? bold[1] : rest).replace(/\*\*/g, ""));
	const split = title.match(/^Step\s+[0-9]+(?: — | – | - )(.*)$/);
	return split ? split[1] : title.replace(/^Step\s+[0-9]+\s*/, "");
}

// What a step waits for under loop.js: its dependencies, plus every earlier step that has no
// `Depends on:` line (loop.js's barrier, its unexported waitsFor, recomputed from `explicit`).
function waitsFor(steps, index) {
	const barriers = steps.slice(0, index).filter((other) => !other.explicit).map((other) => other.number);
	return [...new Set([...steps[index].depends, ...barriers])];
}

// An ID in the one form plans are compared in: uppercased, digits zero-padded as loop.js's
// matchPlans pads them (prefixed IDs to 3 digits, legacy ones to 4). null when it is no ID.
const stripZeros = (digits) => digits.replace(/^0*([0-9])/, "$1");
function normId(text) {
	const prefixed = text.match(/^([A-Za-z]{2,5})-([0-9]+)$/);
	if (prefixed) return `${prefixed[1].toUpperCase()}-${stripZeros(prefixed[2]).padStart(3, "0")}`;
	if (/^[A-Za-z]{3}[0-9]{3}$/.test(text)) return text.toUpperCase();
	if (/^[0-9]+$/.test(text)) return stripZeros(text).padStart(4, "0");
	return null;
}
// The leading ID of a file name, normalised, or null.
function leadingId(name) {
	const match = name.match(/^(?:[A-Za-z]{2,5}-[0-9]+|[A-Za-z]{3}[0-9]{3}|[0-9]+)(?=$|[^A-Za-z0-9])/);
	return match ? normId(match[0]) : null;
}

// The spec a plan belongs to, as state.sh's spec_ref_of reads it: on the first **Spec:** line, the
// first backticked token, else the markdown link target, else the first word; with no such line,
// the plan's own ID. Normalised, or null.
function specOf(name, text) {
	const line = text === null ? undefined : text.split(/\r?\n/).find((each) => each.includes("**Spec:**"));
	if (line === undefined) return leadingId(name);
	const rest = line.slice(line.indexOf("**Spec:**") + "**Spec:**".length);
	const ref = (rest.match(/^[^`]*`([^`]*)`/) || rest.match(/^[^\]]*\]\(([^)]*)\)/) || [null, rest.trim().split(/\s+/)[0]])[1];
	return ref ? leadingId(path.posix.basename(ref)) : null;
}

// One plan: null when it is not listed, else its row. `text` is null when the file cannot be read.
function rowOf(rel, text) {
	const id = idOf(path.basename(rel));
	const unreadable = (reason) => [id, "unreadable", rel, "-", "-", reason];
	if (text === null) return unreadable("the file could not be read — check its permissions");
	const bad = unfenced(text).filter(badMarker).length;
	if (bad) return unreadable(`${bad} step line(s) carry a marker no rule covers — expected - [ ], - [x] or - [~]`);
	// Plan-level problems (cycles, missing references, duplicates) are ignored: only a malformed
	// `Depends on:` line makes the plan unreadable.
	const { steps, problems } = validatePlan(text);
	const malformed = problems.find((problem) => problem.kind === "malformed-depends");
	if (malformed) return unreadable(malformed.message);
	const parsed = parsePlanSteps(text);

	const ticked = new Map();
	for (const step of steps) if (!ticked.has(step.number)) ticked.set(step.number, step.done);
	const open = (index) => !steps[index].done && !steps[index].withdrawn;
	const indices = steps.map((_, index) => index);
	const openSteps = indices.filter(open);
	const begun = parsed.some((step) => step.done || step.mark === "~");
	if (!begun || !openSteps.length) return null;

	const counted = steps.filter((step) => !step.withdrawn);
	const progress = `${counted.filter((step) => step.done).length}/${counted.length}`;
	const runnable = openSteps.find((index) => waitsFor(steps, index).every((number) => ticked.get(number) === true));
	const next = runnable === undefined ? openSteps[0] : runnable;
	return [id, "in progress", rel, progress, `Step ${steps[next].number}`, detailOf(parsed[next])];
}

function main(argv) {
	const root = argv[0];
	if (!root) {
		process.stderr.write("current: usage: current.js <repo-root> [--spec <id>]\n");
		return 2;
	}
	try {
		fs.readdirSync(root);
	} catch {
		process.stderr.write(`current: ${root} is not a directory\n`);
		return 2;
	}
	const say = (line) => {
		process.stdout.write(`${field(line)}\n`);
		return 0;
	};
	// The only accepted argument is `--spec <id>`, once. Anything else is refused in one line, and
	// the words are never handed to a shell (R-A).
	const refuse = (word) => say(`current: "${word}" is not accepted — the only accepted argument is --spec <id>.`);
	const args = argv.slice(1);
	let wanted = null;
	for (let index = 0; index < args.length; index++) {
		if (args[index] !== "--spec" || wanted !== null || index + 1 >= args.length) return refuse(args[index]);
		const id = args[index + 1];
		if (!/^([A-Za-z]{2,5}-[0-9]+|[A-Za-z]{3}[0-9]{3}|[0-9]+)$/.test(id)) return refuse(id);
		wanted = normId(id);
		index++;
	}

	const dir = path.join(root, PLANS);
	let names;
	try {
		names = fs.readdirSync(dir);
	} catch {
		return say("There is no ai-factory/plans/ directory in this repo, so no plan is in progress.");
	}
	const rows = [];
	let belonging = 0;
	for (const name of names) {
		if (!name.endsWith(".md")) continue;
		const file = path.join(dir, name);
		let entry;
		try {
			entry = fs.lstatSync(file);
		} catch {
			continue;
		}
		// A symbolic link is never followed (risk file R3); done/ and other directories are skipped.
		if (entry.isSymbolicLink() || !entry.isFile()) continue;
		let text = null;
		try {
			text = fs.readFileSync(file, "utf8");
		} catch {
			text = null;
		}
		if (wanted !== null) {
			if (specOf(name, text) !== wanted) continue;
			belonging++;
		}
		const row = rowOf(`${PLANS}/${name}`, text);
		if (row) rows.push(row.map(field));
	}
	if (!rows.length) {
		if (wanted === null) return say("No plan is in progress in ai-factory/plans/.");
		if (!belonging) return say(`No plan belongs to ${wanted}: no plan's Spec: line names it.`);
		return say(`No plan for ${wanted} is in progress.`);
	}
	rows.sort((a, b) => byteCompare(a[2], b[2]));
	process.stdout.write([HEADER, ...rows].map((row) => row.join("\t")).join("\n") + "\n");
	return 0;
}

if (require.main === module) process.exitCode = main(process.argv.slice(2));

module.exports = { main };
