#!/usr/bin/env node
// /fc:loop's helper (spec 0022, plan 0022). It owns every deterministic decision of the loop;
// tasks/loop.md only orchestrates. Each subcommand prints one JSON object on stdout, and the
// module exports are the test seam.
//   loop.js start [<plan>] [--max-parallel N] [--step-timeout M] [--host claude|codex|headless]
//     Parses the options, selects the plan, validates it, then creates the loop state under
//     ai-factory/runs/tmp/loop/<loop-id>/state.json.
//     Exit 0: started ({"action":"started"}) or a candidate listing ({"action":"list"}, no state).
//     Exit 2: usage ({"action":"usage"}), decided before any plan is read.
//     Exit 3: validation ({"action":"invalid"}), and no state is created.
//   loop.js next <loop-id>
//     The steps to start now, each with its mode ({"action":"start","steps":[{number,mode}]}), or
//     {"action":"wait"} (a running step must finish first), {"action":"review"} (every step is
//     ticked: run /fc:review) or {"action":"stop"} (a stop cause, and nothing is running).
//   loop.js prepare <loop-id> <step>
//     Creates a running worktree step's worktree under ai-factory/runs/tmp/worktrees/ on the
//     temporary branch fc-loop/<loop-id>/S<N> from HEAD, then copies the main tree's snapshot in
//     ({"action":"prepared"}). A failure records a `snapshot` cause and the step does not start
//     ({"action":"snapshot-failed"}, exit 0: the answer, not the status, carries it).
//   loop.js finish <loop-id> <step> --result met|failed|timeout [--dry]
//     Records a step's result. A main-tree step counts as done only when its implementer ticked
//     it. A worktree step that met its phase gets two commits on its temporary branch (a baseline
//     holding the snapshot, then the step's work) and, in plan order, its delta comes back to the
//     main tree uncommitted: plain `git apply` when `git apply --check` passes, else
//     `git apply --3way` (which changes staging). A clean apply ticks the step and removes its
//     worktree and branch; a conflict or a refused apply is a stop cause and keeps them.
//     --dry simulates the apply-back as clean, with no git (the scheduler's test seam).
//     --output-file names the implementer's output, relayed unchanged if the step stops the loop.
//     A main-tree step that times out keeps its partial changes; the files it changed are listed.
//     On Codex, --result timeout is a usage error: the step timeout is not enforced there.
//     --delivery <id> [--phase red|step|final], worktree steps only, with artifact contracts on:
//     after a clean apply the step's contract evidence is recorded in the main tree with
//     `make -f ai-factory/make/ai.mk verify DELIVERY=<id> STEP=S<N>` (PHASE=red for a red step;
//     a final step also records PHASE=final), and the step is ticked only when each exits 0.
//     Otherwise it is a `failed` cause: its delta stays applied, unticked, and its worktree is kept.
//   loop.js verdict <loop-id>
//     Reads the reviewer's JSON on stdin with gate.js parseVerdict: only a valid approve with no
//     blocker is approval. Kept unchanged for the report; a non-approval is a `verdict` cause only
//     while the review gate is enforced (GATE_ENFORCE=1 or an enforcing assurance preset).
//   loop.js end <loop-id>
//     Prints the report and writes the outcome record ({"action":"ended","code":N,…}) to
//     $FC_LOOP_RESULT (absolute) or ai-factory/runs/tmp/loop/<loop-id>/outcome.json. Causes are
//     listed in the order they happened; the code is 4 (conflict, refused, snapshot), else 1
//     (failed, timeout), else 5 (verdict), else 0. The subcommand itself exits 0.
// Every subcommand but start holds an exclusive lock beside the loop's state (state.lock) from its
// read to its write, git apply and ticking included; run them one at a time all the same.
// A plan is selected by its ID in any spelling state.sh --spec accepts (a legacy number as 22 or
// 0022, a prefixed ID as PMB-1 or pmb-001, a letter-and-digit ID as dhw631), by its basename, or
// by its path, from ai-factory/plans/ and ai-factory/plans/done/.
"use strict";
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const { boundary } = require("./safe-files.js");
const { parsePlanSteps } = require("./contracts.js");
// Preserve the invoked workspace when its entry point is a source-repo symlink (see runner.js).
const ENTRY_DIRECTORY =
	require.main === module ? path.dirname(process.argv[1]) : __dirname;

const STATE_SCHEMA = "fc-loop-state";
const OUTCOME_SCHEMA = "fc-loop-outcome";
const VERSION = 1;
const PLANS = "ai-factory/plans";
const LOOP_DIR = "ai-factory/runs/tmp/loop";
const HOSTS = ["claude", "codex", "headless"];
const DEFAULTS = { max_parallel: 3, step_timeout: 30, host: "claude" };
const USAGE = [
	"usage: loop.js start [<plan ID or path>] [--max-parallel 1-8] [--step-timeout 1-240] [--host claude|codex|headless]",
	"       loop.js next <loop-id>",
	"       loop.js prepare <loop-id> <step>",
	"       loop.js finish <loop-id> <step> --result met|failed|timeout [--output-file <file>] [--delivery <id> [--phase red|step|final]] [--dry]",
	"       loop.js verdict <loop-id>   (the reviewer's JSON on stdin)",
	"       loop.js end <loop-id>",
].join("\n");
const NOTES = {
	codexSequential: "parallel steps run sequentially on Codex",
	codexTimeout: "--step-timeout is not enforced on Codex",
};

const toPosix = (file) => file.split(path.sep).join("/");
const byteCompare = (a, b) => Buffer.compare(Buffer.from(a), Buffer.from(b));

// --- options -------------------------------------------------------------------------------
class UsageError extends Error {}
const OPTIONS = {
	"--max-parallel": { key: "max_parallel", min: 1, max: 8, what: "an integer from 1 to 8" },
	"--step-timeout": { key: "step_timeout", min: 1, max: 240, what: "an integer number of minutes from 1 to 240" },
	"--host": { key: "host", values: HOSTS, what: "claude, codex or headless" },
};
// Pure: argv after `start`. Throws UsageError; never reads a file, so a usage error is always
// decided before the plan is (AC5, AC6).
function parseOptions(argv) {
	const options = { ...DEFAULTS };
	const seen = new Set();
	let plan = null;
	for (let index = 0; index < argv.length; index++) {
		const arg = argv[index];
		if (!arg.startsWith("--")) {
			if (plan !== null) throw new UsageError(`more than one plan given ('${plan}' and '${arg}') — name one plan`);
			plan = arg;
			continue;
		}
		const eq = arg.indexOf("=");
		const name = eq === -1 ? arg : arg.slice(0, eq);
		const spec = OPTIONS[name];
		if (!spec) throw new UsageError(`'${name}' is not an option /fc:loop takes`);
		if (seen.has(name)) throw new UsageError(`${name} was given more than once`);
		seen.add(name);
		let value;
		if (eq !== -1) value = arg.slice(eq + 1);
		else if (index + 1 < argv.length && !argv[index + 1].startsWith("--")) value = argv[++index];
		else throw new UsageError(`${name} needs a value: ${spec.what}`);
		if (spec.values) {
			if (!spec.values.includes(value)) throw new UsageError(`${name} '${value}' is not one of ${spec.what}`);
			options[spec.key] = value;
			continue;
		}
		const number = /^[0-9]+$/.test(value) ? Number(value) : NaN;
		if (!(number >= spec.min && number <= spec.max))
			throw new UsageError(`${name} '${value}' is not ${spec.what}`);
		options[spec.key] = number;
	}
	return { plan, options };
}

// --- the candidate listing: state.sh --plans, rebuilt -------------------------------------
// A workspace helper cannot assume where the plugin lives in a headless run, so these rows are
// built here with state.sh's own rules (skills/ai-layout/scripts/state.sh, sections 1 and 3).
// check-loop.sh's select-parity-with-state compares the bytes against the live script.
const HEADER = "kind\tid\tstate\tpath\tstep\tdetail";
const clean = (text) => text.replace(/\*\*/g, "").replace(/[ \t\n\v\f\r]+/g, " ").replace(/^ /, "").replace(/ $/, "");
const stripZeros = (digits) => digits.replace(/^0*([0-9])/, "$1");

function idOf(file) {
	const base = path.posix.basename(file);
	const legacy = base.match(/^([0-9]{4})/);
	if (legacy) return legacy[1];
	const id = base.match(/^([A-Za-z]{2,5}-[0-9]{3,}|[A-Za-z]{3}[0-9]{3})(?:[-.].*)?$/s);
	return id ? id[1].toUpperCase() : "-";
}
function createdOf(text) {
	const line = (text.split("\n")[1] || "").replace(/\r/g, "");
	const match = line.match(/^Created: ([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2})(\.[0-9]{3})?Z$/);
	return match ? `${match[1]}${match[2] || ".000"}` : "";
}
function orderOf(file, id, text) {
	if (!/^(?:[A-Z]{3}[0-9]{3}|[A-Z]+-[0-9]{3,})$/.test(id)) return ["0", path.posix.basename(file)];
	const created = text === null ? "" : createdOf(text);
	return created ? ["1", `${created} ${id}`] : ["2", id];
}
// state.sh's withdrawn_steps_of: explicit result records outside fences and indented code.
function withdrawnOf(text) {
	const numbers = new Set();
	let fence = 0;
	let fenceChar = "";
	const lines = text.split("\n");
	if (lines[lines.length - 1] === "") lines.pop();
	for (const raw of lines) {
		const line = raw.replace(/^[ \t\n\v\f\r]*/, "");
		const open = line.match(/^`+/) || line.match(/^~+/);
		if (open) {
			const size = open[0].length;
			const char = line[0];
			if (fence) {
				if (char === fenceChar && size >= fence && /^[ \t\n\v\f\r]*$/.test(line.slice(size))) fence = 0;
			} else if (size >= 3) {
				fence = size;
				fenceChar = char;
			}
			continue;
		}
		if (fence || raw.startsWith("    ") || raw.startsWith("\t")) continue;
		const match = line.match(/^\*\*Result — Step ([0-9]+) (?:is )?withdrawn(?:;|\.|\*\*)/);
		if (match) numbers.add(Number(match[1]));
	}
	return numbers;
}
function titleOf(text) {
	for (const line of text.split("\n")) {
		const match = line.match(/^# (.*)$/s);
		if (match) return clean(match[1]);
	}
	return "";
}
// Every row state.sh builds for one plan file, whatever its state, with its sort keys.
function planRows(root, rel) {
	const id = idOf(rel);
	const rows = [];
	const add = (stepNumber, state, step, detail) => {
		const digits = stripZeros(String(stepNumber).replace(/[^0-9]/g, ""));
		const [band, key] = orderOf(rel, id, text);
		const fields = ["plan", id, state, rel, step, detail];
		rows.push({ keys: [path.posix.dirname(rel), band, key, rel, String(digits || "0").padStart(4, "0")], fields, state });
	};
	let text = null;
	try {
		fs.accessSync(path.join(root, rel), fs.constants.R_OK);
		text = fs.readFileSync(path.join(root, rel), "utf8");
	} catch {
		add(0, "unknown", "-", "the file could not be read — check its permissions");
		return rows;
	}
	const withdrawn = withdrawnOf(text);
	let ok = 0;
	let bad = 0;
	let incomplete = 0;
	let withdrawnCount = 0;
	const open = [];
	// `while IFS= read -r line` never sees an unterminated last line.
	const lines = text.split("\n");
	lines.pop();
	for (const line of lines) {
		if (!line.startsWith("- [")) continue;
		const inner = line.slice(3);
		const close = inner.indexOf("]");
		const mark = close === -1 ? inner : inner.slice(0, close);
		const rest = close === -1 ? inner : inner.slice(close + 1);
		if ([...mark].length > 1) continue;
		if (mark === "x" || mark === "X") {
			ok++;
			continue;
		}
		if (mark !== " " && mark !== "~") {
			bad++;
			continue;
		}
		ok++;
		const bold = rest.match(/^[^*]*\*\*([^*]*)\*\*/s);
		const title = clean(bold && bold[1] ? bold[1] : rest);
		let ident = "";
		let detail = title;
		for (const dash of [" — ", " – ", " - "]) {
			const at = title.indexOf(dash);
			if (at === -1) continue;
			const lead = title.slice(0, at);
			if (lead.startsWith("Step ")) {
				ident = lead;
				detail = title.slice(at + dash.length);
			}
			break;
		}
		if (!ident && title.startsWith("Step ")) ident = `Step ${title.split(/[ \t\n]+/).filter(Boolean)[1] || ""}`;
		if (!ident) ident = "(step)";
		const snum = stripZeros(ident.replace(/[^0-9]/g, ""));
		if (/^Step [0-9]+$/.test(ident) && withdrawn.has(Number(snum))) {
			withdrawnCount++;
			continue;
		}
		incomplete++;
		// The step rows pass through `IFS='|' read` in state.sh: a `|` in the step moves the rest
		// of it into the detail.
		const joined = `${ident}|${detail}`;
		const split = joined.indexOf("|");
		open.push([snum || "0", mark === "~" ? "part-done" : "not-started", joined.slice(0, split), joined.slice(split + 1)]);
	}
	if (bad > 0) add(0, "unknown", "-", `${bad} step line(s) carry a marker no rule covers — expected - [ ], - [x] or - [~]`);
	else if (ok === 0) add(0, "unknown", "-", "no step lines were found in this plan");
	else if (incomplete === 0) {
		if (withdrawnCount > 0) add(0, "closed", "-", `${titleOf(text)} — ${withdrawnCount} withdrawn step(s); no pending steps`);
		else add(0, "complete", "-", titleOf(text));
	} else for (const [number, state, step, detail] of open) add(number, state, step, detail);
	return rows;
}
// state.sh globs ai-factory/plans/*.md and ai-factory/plans/*/*.md, sorted in the C locale.
function planFiles(root) {
	const files = [];
	const list = (rel) => {
		try {
			return fs.readdirSync(path.join(root, rel), { withFileTypes: true }).filter((entry) => !entry.name.startsWith("."));
		} catch {
			return [];
		}
	};
	const isFile = (rel) => {
		try {
			return fs.statSync(path.join(root, rel)).isFile();
		} catch {
			return false;
		}
	};
	for (const entry of list(PLANS)) {
		const rel = `${PLANS}/${entry.name}`;
		if (entry.name.endsWith(".md") && isFile(rel)) files.push(rel);
		let directory = entry.isDirectory();
		if (entry.isSymbolicLink()) {
			try {
				directory = fs.statSync(path.join(root, rel)).isDirectory();
			} catch {
				directory = false;
			}
		}
		if (directory)
			for (const inner of list(rel)) if (inner.name.endsWith(".md")) files.push(`${rel}/${inner.name}`);
	}
	return [...new Set(files)].sort(byteCompare);
}
function sortRows(rows) {
	return rows.sort((a, b) => {
		for (let index = 0; index < a.keys.length; index++) {
			const order = byteCompare(a.keys[index], b.keys[index]);
			if (order) return order;
		}
		return byteCompare([...a.keys, ...a.fields].join("\t"), [...b.keys, ...b.fields].join("\t"));
	});
}
// The candidate listing: `state.sh --plans`, byte for byte. With `only`, every row of just those
// plans, whatever their state — the AC4 listing of the plans an argument matched.
function listing(root, only = null) {
	const files = planFiles(root).filter((file) => !only || only.includes(file));
	const rows = sortRows(files.flatMap((file) => planRows(root, file))).filter(
		(row) => only || (row.state !== "complete" && row.state !== "closed"),
	);
	if (!rows.length) {
		const exists = (rel) => {
			try {
				return fs.statSync(path.join(root, rel)).isDirectory();
			} catch {
				return false;
			}
		};
		if (!exists("ai-factory/specs") && !exists(PLANS))
			return "nothing to list — this repo has no ai-factory/specs or ai-factory/plans directory\n";
		return "nothing outstanding — every plan in this repo is complete or closed\n";
	}
	return `${[HEADER, ...rows.map((row) => row.fields.join("\t"))].join("\n")}\n`;
}

// --- selection -----------------------------------------------------------------------------
// The selectable plans: ID-named Markdown files directly under plans/ and plans/done/.
function selectable(root) {
	const out = [];
	for (const dir of [PLANS, `${PLANS}/done`]) {
		let entries = [];
		try {
			entries = fs.readdirSync(path.join(root, dir), { withFileTypes: true });
		} catch {
			continue;
		}
		for (const entry of entries) {
			const rel = `${dir}/${entry.name}`;
			if (!/^(?:[0-9]{4}|[A-Za-z]{2,5}-[0-9]{3,}|[A-Za-z]{3}[0-9]{3})-.*\.md$/s.test(entry.name)) continue;
			try {
				if (fs.statSync(path.join(root, rel)).isFile()) out.push(rel);
			} catch {}
		}
	}
	return out.sort(byteCompare);
}
// The plans an argument names: [] unknown, one selected, more ambiguous.
function matchPlans(root, arg) {
	const plans = selectable(root);
	if (arg.includes("/") || arg.includes(path.sep)) {
		let real;
		try {
			real = fs.realpathSync(path.resolve(root, arg));
		} catch {
			return [];
		}
		const realRoot = fs.realpathSync(root);
		return plans.filter((rel) => {
			try {
				return fs.realpathSync(path.join(realRoot, rel)) === real;
			} catch {
				return false;
			}
		});
	}
	if (/^[0-9]+$/.test(arg)) {
		const number = String(Number(stripZeros(arg))).padStart(4, "0");
		return plans.filter((rel) => idOf(rel) === number);
	}
	if (/^[A-Za-z]{2,5}-[0-9]+$/.test(arg)) {
		const [prefix, digits] = arg.split("-");
		const id = `${prefix.toUpperCase()}-${stripZeros(digits).padStart(3, "0")}`;
		return plans.filter((rel) => idOf(rel) === id);
	}
	if (/^[A-Za-z]{3}[0-9]{3}$/.test(arg)) return plans.filter((rel) => idOf(rel) === arg.toUpperCase());
	if (/^[0-9]+-/.test(arg)) {
		const name = arg.endsWith(".md") ? arg : `${arg}.md`;
		return plans.filter((rel) => path.posix.basename(rel) === name);
	}
	if (/^(?:[A-Za-z]{2,5}-[0-9]{3,}|[A-Za-z]{3}[0-9]{3})-/.test(arg)) {
		const name = (arg.endsWith(".md") ? arg : `${arg}.md`).toUpperCase();
		return plans.filter((rel) => path.posix.basename(rel).toUpperCase() === name);
	}
	return [];
}

// --- validation ----------------------------------------------------------------------------
// `Depends on: N[, M…]` in a step's indented continuation body, optionally as a list item.
const DEPENDS = /^[ \t]+(?:[-*+][ \t]+)?Depends on:(.*)$/;
// Pure: the plan's steps with their effective dependencies, and every problem found (AC8–AC10).
function validatePlan(text) {
	const parsed = parsePlanSteps(text);
	const problems = [];
	const numbers = new Set();
	if (!parsed.length) problems.push({ kind: "no-steps", message: "the plan has no `- [ ] Step N` lines, so there is nothing to run" });
	for (const step of parsed) {
		if (numbers.has(step.number))
			problems.push({ kind: "duplicate-step", step: step.number, message: `Step ${step.number} appears more than once in the plan` });
		numbers.add(step.number);
	}
	const steps = parsed.map((step, index) => {
		let explicit = null;
		for (const line of step.text.split("\n").slice(1)) {
			const match = line.match(DEPENDS);
			if (!match) continue;
			const value = match[1].trim();
			if (!/^[0-9]+(?:[ \t]*,[ \t]*[0-9]+)*$/.test(value)) {
				problems.push({
					kind: "malformed-depends",
					step: step.number,
					message: `Step ${step.number} has 'Depends on:${match[1]}', which is not a comma-separated list of step numbers`,
				});
				continue;
			}
			explicit = explicit || [];
			for (const item of value.split(",")) {
				const ref = Number(item.trim());
				if (!explicit.includes(ref)) explicit.push(ref);
			}
		}
		const earlier = parsed.slice(0, index).map((other) => other.number);
		return {
			number: step.number,
			id: step.id,
			done: step.done,
			withdrawn: step.withdrawn,
			explicit: explicit !== null,
			depends: explicit === null ? [...new Set(earlier)] : explicit,
		};
	});
	for (const step of steps) {
		for (const ref of step.depends)
			if (!numbers.has(ref))
				problems.push({
					kind: "missing-reference",
					step: step.number,
					reference: ref,
					message: `Step ${step.number} depends on Step ${ref}, which does not exist in the plan`,
				});
		if (step.withdrawn && !step.done)
			problems.push({
				kind: "withdrawn-unticked",
				step: step.number,
				message: `Step ${step.number} is unticked but carries a withdrawn record — reconcile the plan: tick it, or remove the record`,
			});
	}
	for (const cycle of cycles(steps)) {
		const names = cycle.map((number) => `Step ${number}`);
		problems.push({
			kind: "cycle",
			steps: cycle,
			message:
				cycle.length === 1
					? `${names[0]} depends on itself`
					: `${names.join(", ")} form a dependency cycle (${[...names, names[0]].join(" → ")})`,
		});
	}
	for (const step of steps) step.depends = [...step.depends].sort((a, b) => a - b);
	return { steps, problems };
}
// What a step waits for: its dependencies, and every earlier step with no Depends on: line, which
// no later step may pass (AC14).
function waitsFor(steps, step) {
	const position = steps.indexOf(step);
	const barriers = steps.slice(0, position).filter((other) => !other.explicit).map((other) => other.number);
	return [...new Set([...step.depends, ...barriers])];
}
// Tarjan's strongly connected components over the existing references, barriers included, so a
// plan that validates can never deadlock the scheduler; each cycle in plan order.
function cycles(steps) {
	const order = new Map(steps.map((step, index) => [step.number, index]));
	const edges = new Map(steps.map((step) => [step.number, waitsFor(steps, step).filter((ref) => order.has(ref))]));
	const index = new Map();
	const low = new Map();
	const stack = [];
	const onStack = new Set();
	const found = [];
	let counter = 0;
	const visit = (node) => {
		index.set(node, counter);
		low.set(node, counter++);
		stack.push(node);
		onStack.add(node);
		for (const next of edges.get(node)) {
			if (!index.has(next)) {
				visit(next);
				low.set(node, Math.min(low.get(node), low.get(next)));
			} else if (onStack.has(next)) low.set(node, Math.min(low.get(node), index.get(next)));
		}
		if (low.get(node) !== index.get(node)) return;
		const component = [];
		let member;
		do {
			member = stack.pop();
			onStack.delete(member);
			component.push(member);
		} while (member !== node);
		if (component.length > 1 || edges.get(node).includes(node))
			found.push(component.sort((a, b) => order.get(a) - order.get(b)));
	};
	for (const step of steps) if (!index.has(step.number)) visit(step.number);
	return found.sort((a, b) => order.get(a[0]) - order.get(b[0]));
}

// --- start ---------------------------------------------------------------------------------
function newLoopId(now = new Date()) {
	const stamp = now.toISOString().replace(/[-:]/g, "").replace(/\.[0-9]+Z$/, "Z");
	return `loop-${stamp}-${crypto.randomBytes(3).toString("hex")}`;
}
// Pure: the loop state for a validated plan. Codex runs one step at a time (AC34).
function createState({ plan, steps, options, loopId, now = new Date() }) {
	const notes = [];
	let effective = options.max_parallel;
	if (options.host === "codex") {
		effective = 1;
		notes.push(NOTES.codexSequential, NOTES.codexTimeout);
	}
	return {
		schema: STATE_SCHEMA,
		version: VERSION,
		loop_id: loopId,
		created_at: now.toISOString(),
		plan,
		host: options.host,
		max_parallel: options.max_parallel,
		effective_parallel: effective,
		step_timeout: options.step_timeout,
		timeout_enforced: options.host !== "codex",
		notes,
		steps: steps.map(({ number, id, done, explicit, depends }) => ({ number, id, done, explicit, depends })),
		running: [],
		pending: [],
		finished: [],
		ran: [],
		causes: [],
	};
}
// start(argv, { root }) → { code, result }. Writes nothing unless the plan starts.
function start(argv, { root, now = new Date() } = {}) {
	let parsed;
	try {
		parsed = parseOptions(argv);
	} catch (error) {
		if (!(error instanceof UsageError)) throw error;
		return { code: 2, result: { action: "usage", message: error.message, usage: USAGE } };
	}
	const { plan: arg, options } = parsed;
	if (arg === null) return { code: 0, result: { action: "list", reason: "no-argument", argument: null, listing: listing(root) } };
	const matches = matchPlans(root, arg);
	if (matches.length === 0)
		return { code: 0, result: { action: "list", reason: "unknown", argument: arg, listing: listing(root) } };
	if (matches.length > 1)
		return { code: 0, result: { action: "list", reason: "ambiguous", argument: arg, matches, listing: listing(root, matches) } };
	const [plan] = matches;
	const { steps, problems } = validatePlan(fs.readFileSync(path.join(root, plan), "utf8"));
	if (problems.length) return { code: 3, result: { action: "invalid", plan, problems } };

	const loopId = newLoopId(now);
	const stateRel = `${LOOP_DIR}/${loopId}/state.json`;
	const state = createState({ plan, steps, options, loopId, now });
	const { effective_parallel: effective, notes } = state;
	const safe = boundary(path.join(root, "ai-factory"));
	safe.mkdir(path.join(root, LOOP_DIR, loopId));
	safe.write(path.join(root, stateRel), `${JSON.stringify(state, null, 2)}\n`, { exclusive: true });
	return {
		code: 0,
		result: {
			action: "started",
			loop_id: loopId,
			state: stateRel,
			plan,
			host: options.host,
			max_parallel: options.max_parallel,
			effective_parallel: effective,
			step_timeout: options.step_timeout,
			notes,
			remaining: steps.filter((step) => !step.done).map((step) => step.number),
		},
	};
}

// --- next and finish: the scheduler --------------------------------------------------------
// Both take the state object and update it in place; the CLI reads and writes state.json around
// them. Neither caps the number of steps or their cost (AC46).
const RESULTS = ["met", "failed", "timeout"];
const stepOf = (state, number) => state.steps.find((step) => step.number === number);
const remaining = (state) => state.steps.filter((step) => !step.done).map((step) => step.number);
const isRunning = (state, number) => state.running.some((entry) => entry.step === number);

// A step is ready when it is unticked, not running or waiting to be applied, and every step it
// waits for is ticked in the main tree (AC14, AC16).
function readySteps(state) {
	const pending = new Set(state.pending || []);
	return state.steps.filter(
		(step) =>
			!step.done &&
			!isRunning(state, step.number) &&
			!pending.has(step.number) &&
			waitsFor(state.steps, step).every((ref) => (stepOf(state, ref) || { done: false }).done),
	);
}
// The steps to start now, up to the effective limit in plan order (AC21–AC23). A step runs in the
// main tree only when it starts alone with nothing else running (AC7, AC15, AC17); otherwise each
// runs in its own worktree. After a stop cause nothing new starts and running steps drain (AC41).
function next(state) {
	if (!state.pending) state.pending = [];
	if (!state.ran) state.ran = [];
	if (state.causes.length) {
		if (state.running.length) return { action: "wait", running: state.running.map((entry) => entry.step) };
		return { action: "stop", causes: state.causes, remaining: remaining(state) };
	}
	// A main-tree step shares the tree with nobody.
	if (state.running.some((entry) => entry.mode === "main"))
		return { action: "wait", running: state.running.map((entry) => entry.step) };
	const room = state.effective_parallel - state.running.length;
	const ready = room > 0 ? readySteps(state).slice(0, room) : [];
	if (ready.length) {
		const mode = ready.length === 1 && state.running.length === 0 ? "main" : "worktree";
		const steps = ready.map((step) => ({ number: step.number, mode }));
		for (const step of steps) {
			state.running.push({ step: step.number, mode: step.mode });
			state.ran.push(step.number);
		}
		return { action: "start", steps };
	}
	if (state.running.length) return { action: "wait", running: state.running.map((entry) => entry.step) };
	const left = remaining(state);
	if (!left.length) return { action: "review", ran: [...state.ran].sort((a, b) => a - b) };
	// Unreachable for a plan that validated; reported rather than looping forever.
	return { action: "stop", causes: state.causes, remaining: left, blocked: true };
}
// Records a step's result. A main-tree step that met its phase was ticked by its implementer, as
// under /fc:run; without --dry its checkbox is read back, and an unticked one is a failure. A
// worktree step that met it gets its two loop commits now, then waits in the apply queue until
// every lower-numbered running step has finished, so deltas come back in plan order (AC30). A
// failure or timeout is a stop cause and keeps the step's worktree; queued steps still come back
// once nothing lower is running (AC41, AC43).
// finish(state, number, result, { dry, root, git }) → { action: "finished", applied, applies,
// ticked, causes, … }. `applied` lists the steps brought back cleanly and ticked; `applies` says
// how each queued step's delta was brought back (plain, 3way, none, conflict or refused).
function finish(state, number, result, { dry = false, root = null, git: run = git, output = null, contract = null, verify = verifyStep } = {}) {
	if (!RESULTS.includes(result)) throw new UsageError(`--result '${result}' is not met, failed or timeout`);
	if (contract) {
		if (!DELIVERY.test(contract.delivery || "")) throw new UsageError(`--delivery '${contract.delivery || ""}' is not a delivery ID (d-YYYYMMDD-xxxxxx)`);
		if (!CONTRACT_PHASES.includes(contract.phase)) throw new UsageError(`--phase '${contract.phase}' is not red, step or final`);
	}
	// AC65: on Codex the step timeout is not enforced, so no step is failed for exceeding it.
	if (result === "timeout" && state.host === "codex")
		throw new UsageError(`--result timeout: ${NOTES.codexTimeout}, so a step is never failed for exceeding it`);
	if (!dry && !root) throw new UsageError("finish without --dry needs the workspace root");
	if (!state.pending) state.pending = [];
	if (!state.notes) state.notes = [];
	const at = state.running.findIndex((entry) => entry.step === number);
	if (at === -1) throw new UsageError(`Step ${number} is not running`);
	const entry = state.running[at];
	if (!dry && entry.mode === "worktree" && !entry.worktree)
		throw new UsageError(`Step ${number} runs in a worktree that was never prepared — run prepare first`);
	// A main-tree step's implementer records its own evidence and ticks, exactly as under /fc:run.
	if (contract && entry.mode !== "worktree")
		throw new UsageError(`--delivery is for worktree steps only: Step ${number} ran in the main tree, where its implementer records its own contract evidence`);
	state.running.splice(at, 1);
	const record = { step: number, mode: entry.mode, result };
	for (const key of ["worktree", "branch", "head", "snapshot"]) if (entry[key]) record[key] = entry[key];
	// The implementer's output, relayed unchanged in the report of a failed step (AC42).
	if (typeof output === "string") record.output = output;
	if (contract) record.contract = { delivery: contract.delivery, phase: contract.phase };
	state.finished.push(record);
	const answer = { action: "finished", step: number, result, mode: entry.mode };
	const ticked = [];
	const failed = (kind, message) => {
		const cause = { kind, step: number, mode: entry.mode };
		if (entry.worktree) cause.worktree = entry.worktree;
		if (message) cause.message = message;
		// A main-tree step that timed out leaves its partial changes in place; they are listed (AC45).
		if (kind === "timeout" && entry.mode === "main" && !dry) Object.assign(cause, partialFiles(root, entry, run));
		state.causes.push(cause);
	};
	if (result !== "met") failed(result);
	else if (entry.mode === "main") {
		if (dry || planTicked(root, state.plan, number)) {
			stepOf(state, number).done = true;
			ticked.push(number);
		} else failed("failed", `Step ${number} reported its phase met, but its checkbox in ${state.plan} is unticked`);
	} else if (dry) state.pending = [...state.pending, number].sort((a, b) => a - b);
	else {
		try {
			Object.assign(record, loopCommits(root, entry, number, run));
			answer.baseline = record.baseline;
			answer.commit = record.commit;
			state.pending = [...state.pending, number].sort((a, b) => a - b);
		} catch (error) {
			failed("failed", `the loop could not commit Step ${number}'s work in its worktree: ${firstLine(error)}`);
		}
	}
	const applied = [];
	const applies = [];
	while (state.pending.length) {
		const first = state.pending[0];
		if (state.running.some((other) => other.step < first)) break;
		state.pending.shift();
		if (dry) {
			// --dry: the apply-back is simulated as clean.
			stepOf(state, first).done = true;
			applied.push(first);
			ticked.push(first);
			continue;
		}
		const done = [...state.finished].reverse().find((other) => other.step === first);
		const outcome = applyBack(root, state, done, run, verify);
		Object.assign(done, { apply: outcome.apply, staging_changed: outcome.staging_changed });
		applies.push({ step: first, apply: outcome.apply, staging_changed: outcome.staging_changed, files: outcome.files });
		if (outcome.cause) {
			state.causes.push(outcome.cause);
			continue;
		}
		if (outcome.staging_changed)
			state.notes.push(`Step ${first}: its delta did not apply cleanly and came back with git apply --3way, which changed staging in the main tree`);
		stepOf(state, first).done = true;
		applied.push(first);
		ticked.push(first);
		const cleanup = removeWorktree(root, done, run);
		if (cleanup) state.notes.push(cleanup);
	}
	return { ...answer, applied, applies, ticked, causes: state.causes };
}

// --- prepare: a worktree and the main tree's snapshot ---------------------------------------
// A worktree step gets its own worktree on a temporary branch from HEAD (AC24), then the main
// tree's snapshot: `git diff --binary HEAD` applied unstaged, and the untracked files that are not
// ignored copied in (AC25). Nothing is committed here, and the main tree's HEAD, refs, index and
// files are never written (AC32, AC33): git runs with optional locks off, so even a diff cannot
// refresh the index, and with no hooks, so the developer's post-checkout hook never runs.
const WORKTREES = "ai-factory/runs/tmp/worktrees";
const SCRATCH = "ai-factory/runs/tmp/";
const GIT_ENV_DROP = ["GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_COMMON_DIR", "GIT_PREFIX", "GIT_OBJECT_DIRECTORY"];
const GIT_CONFIG = ["-c", "core.hooksPath=/dev/null", "-c", "core.fsmonitor=false", "-c", "diff.noprefix=false", "-c", "diff.mnemonicPrefix=false"];
// The default git runner: args without the leading config, { cwd, input, env }; returns stdout as
// a Buffer and throws with git's stderr. `env` adds variables after the inherited git ones are
// dropped (a scratch GIT_INDEX_FILE, the loop's commit identity). prepare() and finish() take
// another runner as their test seam.
function git(args, { cwd, input, env: extra } = {}) {
	const env = { ...process.env, GIT_OPTIONAL_LOCKS: "0", GIT_TERMINAL_PROMPT: "0" };
	for (const name of GIT_ENV_DROP) delete env[name];
	Object.assign(env, extra || {});
	const { spawnSync } = require("node:child_process");
	const run = spawnSync("git", [...GIT_CONFIG, ...args], { cwd, env, input, maxBuffer: 1024 * 1024 * 1024 });
	if (run.error) throw run.error;
	if (run.status !== 0) {
		const message = (run.stderr || Buffer.alloc(0)).toString().trim() || `git ${args[0]} exited ${run.status}`;
		throw new Error(message);
	}
	return run.stdout;
}
const worktreeOf = (loopId, number) => `${WORKTREES}/${loopId}-S${number}`;
const branchOf = (loopId, number) => `fc-loop/${loopId}/S${number}`;

// Copies one untracked path from the main tree into the worktree: a file with its mode, a symlink
// as a link, or a directory git reports whole (an embedded repository). Never follows a link in the
// worktree and never overwrites, so a copy cannot land outside it.
function copyUntracked(top, tree, rel) {
	const safe = boundary(tree);
	const source = path.join(top, rel);
	const target = safe.assertPath(path.join(tree, rel));
	const parts = path.relative(tree, path.dirname(target)).split(path.sep).filter(Boolean);
	let current = tree;
	for (const part of parts) {
		current = path.join(current, part);
		safe.assertPath(current);
		if (!fs.existsSync(current)) fs.mkdirSync(current);
	}
	const stat = fs.lstatSync(source);
	if (stat.isSymbolicLink()) fs.symlinkSync(fs.readlinkSync(source), target);
	else if (stat.isDirectory()) fs.cpSync(source, target, { recursive: true, verbatimSymlinks: true, errorOnExist: true, force: false });
	else {
		fs.copyFileSync(source, target, fs.constants.COPYFILE_EXCL);
		fs.chmodSync(target, stat.mode & 0o777);
	}
}

// The worktree's files as a tree object, through a scratch index in the worktree's own git dir.
function snapshotTree(tree, head, run) {
	const gitDir = run(["rev-parse", "--absolute-git-dir"], { cwd: tree }).toString().replace(/\n$/, "");
	const index = path.join(gitDir, "fc-loop-snapshot.index");
	const env = { GIT_INDEX_FILE: index };
	try {
		run(["read-tree", head], { cwd: tree, env });
		run(["add", "-A", "--", "."], { cwd: tree, env });
		return run(["write-tree"], { cwd: tree, env }).toString().trim();
	} finally {
		fs.rmSync(index, { force: true });
	}
}

// prepare(state, number, { root, git }) → { action: "prepared" | "snapshot-failed", … }. Updates
// the step's running entry with its worktree, branch and HEAD. On any failure the step does not
// start: it leaves the running set and the steps run, a `snapshot` cause is recorded, and next()
// then starts nothing new and lets running steps drain (AC26). The worktree, if created, is kept.
function prepare(state, number, { root, git: run = git } = {}) {
	const entry = state.running.find((running) => running.step === number);
	if (!entry) throw new UsageError(`Step ${number} is not running`);
	if (entry.mode !== "worktree") throw new UsageError(`Step ${number} runs in the main tree; it needs no worktree`);
	if (entry.worktree) throw new UsageError(`Step ${number} already has its worktree at ${entry.worktree}`);
	const rel = worktreeOf(state.loop_id, number);
	const branch = branchOf(state.loop_id, number);
	const tree = path.join(root, rel);
	let stage = "worktree";
	try {
		const top = fs.realpathSync(run(["rev-parse", "--show-toplevel"], { cwd: root }).toString().replace(/\n$/, ""));
		const head = run(["rev-parse", "--verify", "HEAD^{commit}"], { cwd: top }).toString().trim();
		// The loop's scratch, relative to the git top level: never part of a snapshot.
		const scratch = toPosix(path.relative(top, path.join(fs.realpathSync(root), SCRATCH))) + "/";
		boundary(path.join(root, "ai-factory")).mkdir(path.join(root, WORKTREES));
		run(["worktree", "add", "--quiet", "-b", branch, tree, head], { cwd: top });
		entry.worktree = rel;
		entry.branch = branch;
		entry.head = head;
		// The worktree's own git dir (<common dir>/worktrees/<name>): finish() writes through it alone.
		entry.gitdir = fs.realpathSync(run(["rev-parse", "--absolute-git-dir"], { cwd: tree }).toString().replace(/\n$/, ""));
		stage = "diff";
		const patch = run(
			["diff", "--binary", "--no-color", "--no-ext-diff", "--no-textconv", "--no-renames", "--ignore-submodules", "--src-prefix=a/", "--dst-prefix=b/", head, "--"],
			{ cwd: top },
		);
		if (patch.length) {
			stage = "apply";
			run(["apply", "--binary", "--whitespace=nowarn", "-"], { cwd: tree, input: patch });
		}
		stage = "untracked";
		const untracked = run(["ls-files", "--others", "--exclude-standard", "-z"], { cwd: top })
			.toString()
			.split("\0")
			.filter((file) => file && !`${file}/`.startsWith(scratch) && !scratch.startsWith(file.endsWith("/") ? file : `${file}/`));
		for (const file of untracked) copyUntracked(top, tree, file.replace(/\/$/, ""));
		// The snapshot as a tree object, built in a scratch index so nothing is staged in the
		// worktree: finish() commits it as the baseline once the implementer has returned (AC28).
		stage = "baseline";
		entry.snapshot = snapshotTree(tree, head, run);
		return { action: "prepared", step: number, worktree: rel, branch, head, untracked: untracked.sort(byteCompare) };
	} catch (error) {
		if (error instanceof UsageError) throw error;
		const message = `the snapshot of the main tree could not be copied into Step ${number}'s worktree (${stage}): ${String(error.message).trim().split("\n")[0]}`;
		const cause = { kind: "snapshot", step: number, mode: "worktree", stage, message };
		if (fs.existsSync(tree)) cause.worktree = rel;
		state.running = state.running.filter((running) => running.step !== number);
		state.ran = (state.ran || []).filter((step) => step !== number);
		state.causes.push(cause);
		return { action: "snapshot-failed", step: number, worktree: cause.worktree || null, message, causes: state.causes };
	}
}

// --- finish: the two commits, apply-back, ticking and cleanup -------------------------------
// Commits exist only on the loop's temporary branches, inside their worktrees (ADR ETT683). The
// main tree's HEAD, refs and commits are never written; its index changes only when the --3way
// fallback runs (AC62, AC63).
const firstLine = (error) => String(error && error.message).trim().split("\n")[0];
const LOOP_IDENTITY = {
	GIT_AUTHOR_NAME: "fc-loop",
	GIT_AUTHOR_EMAIL: "fc-loop@invalid",
	GIT_COMMITTER_NAME: "fc-loop",
	GIT_COMMITTER_EMAIL: "fc-loop@invalid",
};
// Both commits are plumbing (commit-tree, then update-ref of the step's own branch only), so no hook
// runs (core.hooksPath=/dev/null in every git call, and commit-tree runs none) and nothing is signed;
// an empty step gets its two commits all the same (AC28).
const COMMIT_TREE = ["-c", "commit.gpgsign=false", "commit-tree", "--no-gpg-sign"];
const topOf = (root, run) => fs.realpathSync(run(["rev-parse", "--show-toplevel"], { cwd: root }).toString().replace(/\n$/, ""));

// The `- [ ] Step N` line of a plan, outside fenced code, as an index into text.split("\n").
function stepLine(lines, number) {
	let fence = 0;
	let char = "";
	for (let index = 0; index < lines.length; index++) {
		const line = lines[index].replace(/\r$/, "");
		const open = line.trimStart().match(/^(`{3,}|~{3,})/);
		if (open) {
			if (!fence) {
				fence = open[1].length;
				char = open[1][0];
			} else if (open[1][0] === char && open[1].length >= fence && !line.trimStart().slice(open[1].length).trim()) fence = 0;
			continue;
		}
		if (fence) continue;
		const match = line.match(/^- \[(.?)\](.*)$/);
		if (!match || !" xX~".includes(match[1] || "?")) continue;
		const bold = match[2].match(/^[^*]*\*\*([^*]*)\*\*/);
		const step = (bold ? bold[1] : match[2]).trim().match(/^Step\s+0*(\d+)(?![0-9])/);
		if (step && Number(step[1]) === number) return index;
	}
	return -1;
}
function planTicked(root, plan, number) {
	const step = parsePlanSteps(fs.readFileSync(path.join(root, plan), "utf8")).find((entry) => entry.number === number);
	return Boolean(step && step.done);
}
// Ticks `- [ ] Step N` (or `- [~]`) to `- [x]` in the main tree's plan, changing nothing else.
function tickPlan(root, plan, number) {
	const file = path.join(root, plan);
	const lines = fs.readFileSync(file, "utf8").split("\n");
	const at = stepLine(lines, number);
	if (at === -1) throw new Error(`${plan} has no Step ${number} line to tick`);
	if (/^- \[[xX]\]/.test(lines[at])) return;
	lines[at] = `- [x]${lines[at].slice(5)}`;
	boundary(path.join(root, "ai-factory")).write(file, lines.join("\n"));
}

// The baseline commit (the snapshot prepare() recorded) and the step commit (everything the
// implementer left in the worktree) on the step's temporary branch (ADR ETT683). Nothing here reads
// or writes the worktree's HEAD or index, or the main tree's: the trees are built in a scratch
// index, the commits with commit-tree, and only refs/heads/<entry.branch> moves, by a compare-and-
// swap from the HEAD recorded at prepare. A worktree that left its branch or its own git dir (a
// checkout of another branch, a rewritten .git file) fails the step before anything is written.
function loopCommits(root, entry, number, run) {
	const tree = path.join(root, entry.worktree);
	if (!entry.snapshot) throw new Error("prepare recorded no snapshot for the baseline commit");
	if (!String(entry.branch || "").startsWith("fc-loop/")) throw new Error(`'${entry.branch}' is not one of the loop's branches`);
	const ref = `refs/heads/${entry.branch}`;
	const gitDir = worktreeGitDir(root, entry, run);
	const own = { GIT_DIR: gitDir, GIT_WORK_TREE: tree };
	const found = fs.realpathSync(run(["rev-parse", "--absolute-git-dir"], { cwd: tree }).toString().replace(/\n$/, ""));
	if (found !== gitDir) throw new Error(`its worktree uses the git dir ${found}, not its own ${gitDir}: nothing was committed`);
	let head = "";
	try {
		head = run(["symbolic-ref", "-q", "HEAD"], { cwd: tree, env: own }).toString().trim();
	} catch {}
	if (head !== ref) throw new Error(`its worktree is on ${head || "a detached HEAD"}, not ${ref}: nothing was committed`);
	const now = run(["rev-parse", "--verify", `${ref}^{commit}`], { cwd: tree, env: own }).toString().trim();
	if (now !== entry.head) throw new Error(`its branch moved from ${entry.head} to ${now}: something other than the loop committed there`);
	const env = { ...LOOP_IDENTITY, ...own };
	const commit = (treeId, parent, message) => run([...COMMIT_TREE, treeId, "-p", parent, "-m", message], { cwd: tree, env }).toString().trim();
	const baseline = commit(entry.snapshot, entry.head, `fc-loop: Step ${number} baseline (the main tree's snapshot)`);
	const index = path.join(gitDir, `fc-loop-step-${process.pid}-${crypto.randomBytes(4).toString("hex")}.index`);
	let stepTree;
	try {
		const scratch = { ...env, GIT_INDEX_FILE: index };
		run(["read-tree", baseline], { cwd: tree, env: scratch });
		run(["add", "-A", "--", "."], { cwd: tree, env: scratch });
		stepTree = run(["write-tree"], { cwd: tree, env: scratch }).toString().trim();
	} finally {
		fs.rmSync(index, { force: true });
	}
	const step = commit(stepTree, baseline, `fc-loop: Step ${number}`);
	run(["update-ref", "-m", `fc-loop: Step ${number}`, ref, step, entry.head], { cwd: tree, env });
	// Best effort: the worktree's own index follows its branch, so a kept worktree reads clean.
	try {
		run(["read-tree", step], { cwd: tree, env });
	} catch {}
	return { baseline, commit: step };
}
// The step's worktree git dir: the one prepare recorded, which must sit directly under the
// repository's <common dir>/worktrees/ and name this worktree as its own.
function worktreeGitDir(root, entry, run) {
	const top = topOf(root, run);
	const common = fs.realpathSync(path.resolve(top, run(["rev-parse", "--git-common-dir"], { cwd: top }).toString().replace(/\n$/, "")));
	const tree = path.join(root, entry.worktree);
	const gitDir = entry.gitdir || path.join(common, "worktrees", path.basename(tree));
	if (path.dirname(gitDir) !== path.join(common, "worktrees")) throw new Error(`${gitDir} is not a worktree git dir of this repository`);
	let back;
	try {
		back = fs.realpathSync(path.dirname(fs.readFileSync(path.join(gitDir, "gitdir"), "utf8").replace(/\n$/, "")));
	} catch (error) {
		throw new Error(`${gitDir} is not this worktree's git dir: ${firstLine(error)}`);
	}
	if (back !== fs.realpathSync(tree)) throw new Error(`${gitDir} belongs to ${back}, not ${tree}`);
	return gitDir;
}

// Brings one step's own delta (baseline..step, the plan file excluded: only the loop ticks) back to
// the main tree. `git apply --check`, then plain `git apply`: working files only, the index
// untouched (AC29, AC62). Else `git apply --3way`, which stages (AC63); conflict markers are a
// `conflict` (AC43), and a refusal that wrote nothing is `refused` (AC70). After a clean apply
// the step is ticked.
function applyBack(root, state, done, run, verify = verifyStep) {
	const number = done.step;
	const outcome = { apply: null, staging_changed: false, files: [] };
	const stop = (kind, files, message) =>
		Object.assign(outcome, { apply: kind, files, cause: { kind, step: number, mode: "worktree", worktree: done.worktree, files, message } });
	const APPLY = ["apply", "--binary", "--whitespace=nowarn"];
	let top;
	let patch;
	let touched = [];
	try {
		top = topOf(root, run);
		const plan = toPosix(path.relative(top, path.join(fs.realpathSync(root), state.plan)));
		patch = run(
			["diff", "--binary", "--no-color", "--no-ext-diff", "--no-textconv", "--no-renames", "--ignore-submodules", "--src-prefix=a/", "--dst-prefix=b/", done.baseline, done.commit, "--", ":/", `:(top,exclude,literal)${plan}`],
			{ cwd: top },
		);
		if (patch.length)
			touched = run([...APPLY, "--numstat", "-z", "-"], { cwd: top, input: patch })
				.toString()
				.split("\0")
				.filter(Boolean)
				.map((record) => record.split("\t").slice(2).join("\t"))
				.sort(byteCompare);
	} catch (error) {
		return stop("refused", [], `Step ${number}'s delta could not be taken from its worktree, so nothing was applied: ${firstLine(error)}`);
	}
	outcome.files = touched;
	const unmerged = () =>
		new Set(
			run(["ls-files", "--unmerged", "-z"], { cwd: top })
				.toString()
				.split("\0")
				.filter(Boolean)
				.map((record) => record.slice(record.indexOf("\t") + 1)),
		);
	// A touched path that is already unmerged cannot be told apart from a conflict this apply made,
	// so the delta is refused before anything is applied.
	if (patch.length) {
		let already;
		try {
			const before = unmerged();
			already = touched.filter((file) => before.has(file));
		} catch (error) {
			return stop("refused", touched, `the main tree's unmerged paths could not be read, so nothing of Step ${number}'s delta was applied: ${firstLine(error)}. Its worktree ${done.worktree} is kept.`);
		}
		if (already.length)
			return stop(
				"refused",
				already,
				`Step ${number}'s delta touches ${already.join(", ")}, already unmerged in the main tree, so nothing was applied: resolve ${already.length === 1 ? "it" : "them"} first. Its worktree ${done.worktree} is kept.`,
			);
	}
	if (!patch.length) outcome.apply = "none";
	else {
		let clean = true;
		try {
			run([...APPLY, "--check", "-"], { cwd: top, input: patch });
		} catch {
			clean = false;
		}
		if (clean) {
			try {
				run([...APPLY, "-"], { cwd: top, input: patch });
			} catch (error) {
				return stop("refused", touched, `git apply refused Step ${number}'s delta after its check passed (${firstLine(error)}). Its worktree ${done.worktree} is kept.`);
			}
			outcome.apply = "plain";
		} else {
			const before = unmerged();
			try {
				run([...APPLY, "--3way", "-"], { cwd: top, input: patch });
				Object.assign(outcome, { apply: "3way", staging_changed: true });
			} catch (error) {
				const conflicted = [...unmerged()].filter((file) => !before.has(file)).sort(byteCompare);
				if (conflicted.length) {
					outcome.staging_changed = true;
					return stop(
						"conflict",
						conflicted,
						`Step ${number}'s delta conflicts with the main tree: git apply --3way left conflict markers in ${conflicted.join(", ")}. Its worktree ${done.worktree} is kept.`,
					);
				}
				return stop(
					"refused",
					touched,
					`git apply --3way refused Step ${number}'s delta without writing conflict markers (${firstLine(error)}); the main tree is unchanged by it. It touches ${touched.join(", ")}. Its worktree ${done.worktree} is kept.`,
				);
			}
		}
	}
	// Contract evidence binds to the main tree's code, so it is recorded here, after the apply and
	// before the tick: the step is ticked only when each recording exits 0 (plan 0022, Ambiguity 5).
	if (done.contract) {
		const problem = verify(root, number, done.contract);
		if (problem) {
			outcome.cause = { kind: "failed", step: number, mode: "worktree", worktree: done.worktree, files: touched, contract: true, message: `Step ${number}'s delta was applied to the main tree, but its contract evidence was not recorded (${problem}), so it is not ticked. Its worktree ${done.worktree} is kept.` };
			return outcome;
		}
	}
	try {
		tickPlan(root, state.plan, number);
	} catch (error) {
		outcome.cause = { kind: "failed", step: number, mode: "worktree", worktree: done.worktree, files: touched, message: `Step ${number}'s delta was applied, but its checkbox could not be ticked: ${firstLine(error)}` };
	}
	return outcome;
}

// Removes a cleanly applied step's worktree and deletes its temporary branch (AC31). A failure
// here is a note for the report, not a stop cause: the step's work is already in the main tree.
function removeWorktree(root, done, run) {
	try {
		if (!done.worktree.startsWith(`${WORKTREES}/`) || !done.branch.startsWith("fc-loop/"))
			throw new Error("it is not the loop's own");
		const tree = boundary(path.join(root, WORKTREES)).assertPath(path.join(root, done.worktree));
		const top = topOf(root, run);
		run(["worktree", "remove", "--force", tree], { cwd: top });
		run(["branch", "--quiet", "-D", done.branch], { cwd: top });
		done.removed = true;
		return null;
	} catch (error) {
		return `Step ${done.step}: its worktree ${done.worktree} or branch ${done.branch} could not be removed (${firstLine(error)}); remove them by hand`;
	}
}

// Records a worktree step's contract evidence in the main tree: `make verify` for the step's
// phase, and for a final step the delivery's final verification too. Returns null when every
// recording exited 0, else what went wrong. Make runs with the selections as its own arguments.
const DELIVERY = /^d-[0-9]{8}-[0-9a-f]{6}$/;
const CONTRACT_PHASES = ["red", "step", "final"];
function verifyStep(root, number, { delivery, phase }) {
	const { spawnSync } = require("node:child_process");
	const env = { ...process.env };
	for (const name of ["MAKEFLAGS", "MAKEOVERRIDES", "MFLAGS", "DELIVERY", "STEP", "PHASE"]) delete env[name];
	const runs = [[`DELIVERY=${delivery}`, `STEP=S${number}`, ...(phase === "red" ? ["PHASE=red"] : [])]];
	if (phase === "final") runs.push([`DELIVERY=${delivery}`, "PHASE=final"]);
	for (const vars of runs) {
		const run = spawnSync("make", ["-s", "-f", "ai-factory/make/ai.mk", "verify", ...vars], { cwd: root, env, encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
		if (run.error) return `make verify ${vars.join(" ")} could not run: ${firstLine(run.error)}`;
		if (run.status !== 0) return `make verify ${vars.join(" ")} exited ${run.status}: ${String(run.stderr || run.stdout).trim().split("\n").slice(-1)[0] || "no message"}`;
	}
	return null;
}

// --- a main-tree step's own changes --------------------------------------------------------
// The main tree as a tree object, through a scratch copy of its index, so the real index is never
// written (AC62) and the loop's scratch is left out. Taken when a main-tree step starts, it lets a
// timed-out step's partial files be told apart from the developer's earlier work (AC45).
function mainTreeHash(root, run) {
	const top = topOf(root, run);
	const gitDir = run(["rev-parse", "--absolute-git-dir"], { cwd: top }).toString().replace(/\n$/, "");
	const scratch = toPosix(path.relative(top, path.join(fs.realpathSync(root), SCRATCH))).replace(/\/$/, "");
	const index = path.join(gitDir, `fc-loop-main-${process.pid}-${crypto.randomBytes(4).toString("hex")}.index`);
	const env = { GIT_INDEX_FILE: index };
	try {
		if (fs.existsSync(path.join(gitDir, "index"))) fs.copyFileSync(path.join(gitDir, "index"), index, fs.constants.COPYFILE_EXCL);
		else run(["read-tree", "--empty"], { cwd: top, env });
		// The scratch is left out: by its ignore rule, or, where nothing ignores it, by a pathspec
		// (git refuses an exclude that names an ignored path).
		let ignored = true;
		try {
			run(["check-ignore", "-q", "--no-index", "--", `${scratch}/`], { cwd: top });
		} catch {
			ignored = false;
		}
		run(["add", "-A", "--", ":/", ...(ignored ? [] : [`:(top,exclude,literal)${scratch}`])], { cwd: top, env });
		return run(["write-tree"], { cwd: top, env }).toString().trim();
	} finally {
		fs.rmSync(index, { force: true });
	}
}
// Records the main tree's tree object on a main-tree step that has just started. A failure leaves
// the step without one, and a timeout of that step then says its files could not be listed.
function markMainStart(state, root, run = git) {
	for (const entry of state.running) {
		if (entry.mode !== "main" || entry.before) continue;
		try {
			entry.before = mainTreeHash(root, run);
		} catch {}
	}
}
// The files a main-tree step changed since it started: { partial: true, files } (AC45).
function partialFiles(root, entry, run) {
	if (!entry.before) return { partial: true, files: [], files_unknown: "the main tree was not recorded when the step started" };
	try {
		const after = mainTreeHash(root, run);
		const files = run(["diff-tree", "-r", "-z", "--name-only", "--no-renames", entry.before, after], { cwd: topOf(root, run) })
			.toString()
			.split("\0")
			.filter(Boolean)
			.sort(byteCompare);
		return { partial: true, files };
	} catch (error) {
		return { partial: true, files: [], files_unknown: firstLine(error) };
	}
}

// --- verdict and end: the report, cause order and exit priority -----------------------------
// Exit priority: 4 (conflict, refused, snapshot), then 1 (failed, timeout), then 5 (a verdict that
// is not a valid approval while the review gate is enforced), else 0 (AC67–AC69). Usage (2) and
// validation (3) come only from start, before any step runs.
const PRIORITY = [
	[4, ["conflict", "refused", "snapshot"]],
	[1, ["failed", "timeout"]],
	[5, ["verdict"]],
];
function exitCode(causes) {
	for (const [code, kinds] of PRIORITY) if (causes.some((cause) => kinds.includes(cause.kind))) return code;
	return 0;
}
// Advisory or enforced, by gate.js's own rule: GATE_ENFORCE=1, or a selected assurance preset that
// enforces the gate. An unusable GATE_ENFORCE or selection is a usage error, never approval.
function gateEnforced(root, env) {
	const gate = require("./gate.js");
	let preset = null;
	try {
		preset = root ? gate.selectedPreset(root) : null;
	} catch (error) {
		throw new UsageError(`the review gate cannot be resolved: ${firstLine(error)}`);
	}
	const mode = gate.gateMode(env.GATE_ENFORCE, preset);
	if (mode.error) throw new UsageError(`the review gate cannot be resolved: ${mode.error}`);
	return mode.mode === "enforced";
}
const stopKinds = new Set(["conflict", "refused", "snapshot", "failed", "timeout"]);
const atReviewPoint = (state) => !state.running.length && !remaining(state).length && !state.causes.some((cause) => stopKinds.has(cause.kind));

// verdict(state, text, { root, env }) → { action: "verdict", valid, approved, … }. Reads the
// reviewer's JSON with gate.js parseVerdict: only a valid approve with no blocker is approval.
// The text is kept unchanged for the report (AC18). /fc:review runs once, so a second verdict is
// refused. A non-approving verdict is a stop cause only while the gate is enforced (AC51, AC52).
function verdict(state, text, { root = null, env = process.env } = {}) {
	if (state.running.length) throw new UsageError(`steps ${state.running.map((entry) => entry.step).join(", ")} are still running; /fc:review runs after them`);
	if (state.verdict) throw new UsageError("a /fc:review verdict is already recorded for this loop; /fc:review runs once");
	const enforced = gateEnforced(root, env);
	const record = { raw: text, valid: false, approved: false, verdict: null, blockers: 0, enforced };
	try {
		const value = require("./gate.js").parseVerdict(text);
		record.valid = true;
		record.verdict = value.verdict;
		record.blockers = value.findings.filter((finding) => finding.severity === "blocker").length;
		record.approved = value.verdict === "approve" && record.blockers === 0;
	} catch (error) {
		record.error = `the verdict is not a valid review: ${firstLine(error)}`;
	}
	state.verdict = record;
	if (!record.approved && enforced)
		state.causes.push({ kind: "verdict", step: null, message: verdictMessage(record) });
	return { action: "verdict", valid: record.valid, approved: record.approved, verdict: record.verdict, blockers: record.blockers, enforced, error: record.error || null, causes: state.causes };
}
function verdictMessage(record) {
	if (!record.valid) return `/fc:review returned no valid verdict (${record.error.replace(/^the verdict is not a valid review: /, "")}), so the review gate is not met`;
	if (record.verdict === "approve") return `/fc:review verdict approve carries ${record.blockers} blocker(s), so it is not an approval`;
	return `/fc:review verdict ${record.verdict}, which is not an approval`;
}
const list = (numbers) => (numbers.length ? numbers.join(", ") : "none");
function causeLines(cause, index) {
	const who = cause.kind === "verdict" ? "/fc:review" : `Step ${cause.step}`;
	const what = {
		failed: "failed",
		timeout: cause.mode === "main" ? "timeout (in the main tree)" : "timeout",
		snapshot: "snapshot copy failed",
		conflict: "conflict",
		refused: "apply refused",
		verdict: "verdict not approved",
	}[cause.kind] || cause.kind;
	const lines = [`  ${index + 1}. ${who} — ${what}${cause.message ? `: ${cause.message}` : ""}`];
	if (cause.worktree) lines.push(`     Worktree kept: ${cause.worktree}`);
	if (cause.kind === "conflict") lines.push(`     Files with conflict markers: ${cause.files.join(", ") || "none listed"}`);
	if (cause.kind === "refused") lines.push(`     Files the refused apply touches: ${(cause.files || []).join(", ") || "none listed"}`);
	if (cause.partial) {
		lines.push(`     Partial changes left in the main tree: ${cause.files.join(", ") || "none"}`);
		if (cause.files_unknown) lines.push(`     The partial files could not be listed: ${cause.files_unknown}`);
	}
	if (typeof cause.output === "string") {
		lines.push("     Output:");
		for (const line of cause.output.replace(/\n$/, "").split("\n")) lines.push(`       ${line}`);
	}
	return lines;
}
// The report and the outcome record (pure apart from reading the gate selection). The record is
// what end writes and what the headless runner maps to its exit code.
function outcome(state, { root = null, env = process.env } = {}) {
	const ran = [...new Set(state.ran || [])].sort((a, b) => a - b);
	const left = remaining(state);
	const causes = state.causes.map((cause) => {
		const out = { ...cause };
		const done = [...state.finished].reverse().find((other) => other.step === cause.step);
		if (done && typeof done.output === "string" && cause.kind !== "verdict") out.output = done.output;
		return out;
	});
	const notes = [...(state.notes || [])];
	// No verdict at the review point: no approval when the gate is enforced, and said either way.
	if (!state.verdict && atReviewPoint(state)) {
		if (gateEnforced(root, env))
			causes.push({ kind: "verdict", step: null, message: "no /fc:review verdict was recorded, so the review gate is not met" });
		else notes.push("no /fc:review verdict was recorded");
	}
	const code = exitCode(causes);
	const stopped = causes.some((cause) => stopKinds.has(cause.kind));
	const ticked = ran.filter((number) => (stepOf(state, number) || {}).done);
	const noneRemained = !ran.length && !left.length && !stopped;
	const applies = state.finished
		.filter((done) => done.apply)
		.map((done) => ({ step: done.step, apply: done.apply, staging_changed: Boolean(done.staging_changed) }));
	const report = [`/fc:loop — ${state.plan}`];
	report.push(noneRemained ? "no steps remained: every step of the plan was already ticked" : `Steps run in this invocation: ${list(ran)}`);
	if (!noneRemained) report.push(`Ticked in this invocation: ${list(ticked)}`);
	report.push(`Still unticked: ${list(left)}`);
	report.push(stopped ? "The loop stopped." : "The loop ran to its end.");
	if (causes.length) {
		report.push("Stop causes, in the order they happened:");
		causes.forEach((cause, index) => report.push(...causeLines(cause, index)));
	}
	if (notes.length) {
		report.push("Notes:");
		for (const note of notes) report.push(`  - ${note}`);
	}
	if (state.verdict) {
		report.push(`/fc:review verdict${state.verdict.valid ? "" : " (not a valid review)"}, unchanged:`);
		report.push(state.verdict.raw.replace(/\n$/, ""));
	} else report.push("/fc:review verdict: none recorded");
	report.push(`Exit code: ${code}`);
	return {
		schema: OUTCOME_SCHEMA,
		version: VERSION,
		loop_id: state.loop_id,
		plan: state.plan,
		host: state.host,
		code,
		status: stopped ? "stopped" : "complete",
		no_steps_remained: noneRemained,
		ran,
		ticked,
		remaining: left,
		causes,
		applies,
		notes,
		verdict: state.verdict || null,
		report: `${report.join("\n")}\n`,
	};
}
// end(state, { root, env }) → the outcome record, written to $FC_LOOP_RESULT when the runner set
// it (an absolute path), else to ai-factory/runs/tmp/loop/<loop-id>/outcome.json. The loop must
// have ended: nothing running, and either every step ticked or a stop cause recorded.
function end(state, { root, env = process.env } = {}) {
	if (state.running.length) throw new UsageError(`steps ${state.running.map((entry) => entry.step).join(", ")} are still running; end the loop after they finish`);
	if (remaining(state).length && !state.causes.some((cause) => stopKinds.has(cause.kind)))
		throw new UsageError(`the loop has not ended: steps ${remaining(state).join(", ")} are unticked and no stop cause is recorded — run next`);
	const target = env.FC_LOOP_RESULT;
	if (target && !path.isAbsolute(target)) throw new UsageError(`FC_LOOP_RESULT '${target}' is not an absolute path`);
	const record = outcome(state, { root, env });
	const text = `${JSON.stringify(record, null, 2)}\n`;
	let written;
	if (target) {
		writeOutside(target, text);
		written = target;
	} else {
		written = `${LOOP_DIR}/${state.loop_id}/outcome.json`;
		const safe = boundary(path.join(root, "ai-factory"));
		safe.mkdir(path.join(root, LOOP_DIR, state.loop_id));
		safe.write(path.join(root, written), text);
	}
	state.ended = { at: new Date().toISOString(), code: record.code, record: written };
	return { action: "ended", record: written, ...record };
}
// Writes the runner's record: never through a symbolic link, and whole or not at all.
function writeOutside(target, text) {
	let stat = null;
	try {
		stat = fs.lstatSync(target);
	} catch {}
	if (stat && !stat.isFile()) throw new UsageError(`FC_LOOP_RESULT '${target}' is not a regular file`);
	const temp = `${target}.${process.pid}.${crypto.randomBytes(4).toString("hex")}.tmp`;
	fs.writeFileSync(temp, text, { flag: "wx", mode: 0o600 });
	fs.renameSync(temp, target);
}

// --- CLI -----------------------------------------------------------------------------------
const LOOP_ID = /^loop-[0-9]{8}T[0-9]{6}Z-[0-9a-f]{6}$/;
function stateFile(root, loopId) {
	if (!LOOP_ID.test(loopId || "")) throw new UsageError(`'${loopId || ""}' is not a loop ID`);
	return path.join(root, LOOP_DIR, loopId, "state.json");
}
function readState(root, loopId) {
	const file = stateFile(root, loopId);
	let state;
	try {
		state = JSON.parse(fs.readFileSync(file, "utf8"));
	} catch {
		throw new UsageError(`no loop state for ${loopId}`);
	}
	if (state.schema !== STATE_SCHEMA) throw new UsageError(`${loopId} is not a loop state`);
	return state;
}
function writeState(root, state) {
	const safe = boundary(path.join(root, "ai-factory"));
	safe.write(stateFile(root, state.loop_id), `${JSON.stringify(state, null, 2)}\n`);
}
// One loop.js command at a time per loop: every read → change → write of state.json, with the git
// apply and tick work inside it, runs under an exclusive lock file beside the state. A lock whose
// owner process is gone, or older than LOCK_STALE_MS, is reclaimed; a live one is waited for.
const LOCK_WAIT_MS = 10 * 60 * 1000;
const LOCK_STALE_MS = 2 * 60 * 60 * 1000;
const LOCK_GRACE_MS = 5000;
const pause = (ms) => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
// True when the lock is gone or was reclaimed (try again now), false while it is held.
function reclaimLock(lock) {
	let stat;
	let text;
	try {
		stat = fs.lstatSync(lock);
		text = fs.readFileSync(lock, "utf8");
	} catch (error) {
		if (error.code === "ENOENT") return true;
		throw error;
	}
	if (!stat.isFile()) throw new UsageError(`${lock} is not a lock file; remove it by hand`);
	const age = Date.now() - stat.mtimeMs;
	let owner = null;
	try {
		owner = JSON.parse(text).pid;
	} catch {}
	let stale = age > LOCK_STALE_MS;
	if (!stale && Number.isInteger(owner) && owner > 0) {
		try {
			process.kill(owner, 0);
		} catch (error) {
			stale = error.code === "ESRCH";
		}
	} else if (!stale) stale = age > LOCK_GRACE_MS;
	if (!stale) return false;
	// Moved aside, then checked: only the lock that was judged stale is removed.
	const aside = `${lock}.stale.${process.pid}.${crypto.randomBytes(4).toString("hex")}`;
	try {
		fs.renameSync(lock, aside);
	} catch (error) {
		if (error.code === "ENOENT") return true;
		throw error;
	}
	const moved = fs.lstatSync(aside);
	if (moved.ino !== stat.ino || moved.dev !== stat.dev) {
		try {
			fs.linkSync(aside, lock);
		} catch {}
		fs.rmSync(aside, { force: true });
		return false;
	}
	fs.rmSync(aside, { force: true });
	return true;
}
function withStateLock(root, loopId, action) {
	const safe = boundary(path.join(root, "ai-factory"));
	const lock = path.join(path.dirname(stateFile(root, loopId)), "state.lock");
	const deadline = Date.now() + LOCK_WAIT_MS;
	let mine;
	for (;;) {
		try {
			safe.write(lock, `${JSON.stringify({ pid: process.pid, at: new Date().toISOString() })}\n`, { exclusive: true });
			mine = fs.lstatSync(lock);
			break;
		} catch (error) {
			if (error.code !== "EEXIST" && !fs.existsSync(lock)) throw error;
			if (reclaimLock(lock)) continue;
			if (Date.now() >= deadline)
				throw new UsageError(`loop ${loopId} is busy: another loop.js command holds ${path.relative(root, lock)}; run loop.js commands one at a time`);
			pause(50);
		}
	}
	try {
		return action();
	} finally {
		try {
			const now = fs.lstatSync(lock);
			if (now.ino === mine.ino && now.dev === mine.dev) fs.unlinkSync(lock);
		} catch {}
	}
}
function scheduleCommand(command, rest, root) {
	const [loopId] = rest;
	if (!fs.existsSync(stateFile(root, loopId))) throw new UsageError(`no loop state for ${loopId}`);
	return withStateLock(root, loopId, () => scheduleLocked(command, rest, root));
}
function scheduleLocked(command, rest, root) {
	const [loopId, ...args] = rest;
	const state = readState(root, loopId);
	if (command === "next") {
		const answer = next(state);
		if (answer.action === "start") markMainStart(state, root);
		writeState(root, state);
		return answer;
	}
	if (command === "verdict" || command === "end") {
		if (args.length) throw new UsageError(`'${args[0]}' is not an option ${command} takes`);
		const answer =
			command === "verdict"
				? verdict(state, fs.readFileSync(0, "utf8"), { root, env: process.env })
				: end(state, { root, env: process.env });
		writeState(root, state);
		return answer;
	}
	const [stepArg, ...flags] = args;
	if (!/^[0-9]+$/.test(stepArg || "")) throw new UsageError(`${command} needs a step number`);
	if (command === "prepare") {
		if (flags.length) throw new UsageError(`'${flags[0]}' is not an option prepare takes`);
		const answer = prepare(state, Number(stepArg), { root });
		writeState(root, state);
		return answer;
	}
	let result = null;
	let dry = false;
	let outputFile = null;
	let delivery = null;
	let phase = null;
	for (let index = 0; index < flags.length; index++) {
		if (flags[index] === "--dry") dry = true;
		else if (flags[index] === "--result") result = flags[++index];
		else if (flags[index].startsWith("--result=")) result = flags[index].slice("--result=".length);
		else if (flags[index] === "--output-file") outputFile = flags[++index];
		else if (flags[index].startsWith("--output-file=")) outputFile = flags[index].slice("--output-file=".length);
		else if (flags[index] === "--delivery") delivery = flags[++index];
		else if (flags[index] === "--phase") phase = flags[++index];
		else throw new UsageError(`'${flags[index]}' is not an option finish takes`);
	}
	let output = null;
	if (outputFile !== null) {
		if (!outputFile) throw new UsageError("--output-file needs a file");
		try {
			output = fs.readFileSync(path.resolve(outputFile), "utf8");
		} catch (error) {
			throw new UsageError(`--output-file '${outputFile}' cannot be read: ${firstLine(error)}`);
		}
	}
	if (phase !== null && delivery === null) throw new UsageError("--phase needs --delivery");
	const contract = delivery === null ? null : { delivery, phase: phase === null ? "step" : phase };
	const answer = finish(state, Number(stepArg), result, { dry, root, output, contract });
	writeState(root, state);
	return answer;
}

function main(argv) {
	const [command, ...rest] = argv;
	if (["next", "prepare", "finish", "verdict", "end"].includes(command)) {
		const root = fs.realpathSync(path.resolve(ENTRY_DIRECTORY, "../.."));
		try {
			process.stdout.write(`${JSON.stringify(scheduleCommand(command, rest, root))}\n`);
			return 0;
		} catch (error) {
			if (!(error instanceof UsageError)) throw error;
			process.stdout.write(`${JSON.stringify({ action: "usage", message: error.message, usage: USAGE })}\n`);
			process.stderr.write(`loop: ${error.message}\n`);
			return 2;
		}
	}
	if (command !== "start") {
		process.stdout.write(`${JSON.stringify({ action: "usage", message: `unknown subcommand '${command || ""}'`, usage: USAGE })}\n`);
		process.stderr.write(`loop: unknown subcommand '${command || ""}'\n${USAGE}\n`);
		return 2;
	}
	const root = fs.realpathSync(path.resolve(ENTRY_DIRECTORY, "../.."));
	const { code, result } = start(rest, { root });
	process.stdout.write(`${JSON.stringify(result)}\n`);
	if (result.action === "usage") process.stderr.write(`loop: ${result.message}\n${USAGE}\n`);
	if (result.action === "invalid") {
		process.stderr.write(`loop: ${result.plan} cannot run until the plan is reconciled:\n`);
		for (const problem of result.problems) process.stderr.write(`  - ${problem.message}\n`);
	}
	return code;
}

if (require.main === module) {
	try {
		process.exitCode = main(process.argv.slice(2));
	} catch (error) {
		process.stderr.write(`loop: ${error.message}\n`);
		process.exitCode = 1;
	}
}

module.exports = {
	USAGE,
	DEFAULTS,
	NOTES,
	HEADER,
	UsageError,
	parseOptions,
	listing,
	planRows,
	matchPlans,
	validatePlan,
	createState,
	start,
	next,
	prepare,
	git,
	finish,
	verdict,
	end,
	outcome,
	exitCode,
};
