#!/usr/bin/env node
// Assurance presets: one opt-in selection (ai-factory/assurance.json) resolved as minimums
// over the controls a repository already has. Absent selection means legacy behavior.
//   assurance.js show [--json]                       read-only effective settings
//   assurance.js set light|standard|strict [--json]  preview the changes; writes nothing
//   assurance.js set <preset> --apply [--json]       explicitly write them
//   assurance.js complete <delivery> [--json]        may completion be claimed? Evaluated from
//                                                    current evidence; strict also saves the
//                                                    freshly generated report. Exit 0 only if so.
// The presets and their pure rules live in assurance-policy.js, which contracts.js and gate.js
// import; this file is the command line over them and composes the inputs (contracts.readConfig
// output, the environment, the delivery report). It never weakens project rules.
const fs = require("node:fs");
const path = require("node:path");
// assurance.js and assurance-policy.js ship together; a partial copy holding only this file says
// what to do rather than failing with MODULE_NOT_FOUND.
const POLICY_MISSING = "assurance: make/assurance-policy.js is missing; run /fc:sync-sdlc to receive it";
if (!fs.existsSync(path.join(__dirname, "assurance-policy.js"))) {
	if (require.main !== module) throw new Error(POLICY_MISSING);
	process.stderr.write(`${POLICY_MISSING}\n`);
	process.exit(2);
}
const policy = require("./assurance-policy.js");
// Preserve the invoked workspace when its entry point is a source-repo symlink (see runner.js).
const ENTRY_DIRECTORY =
	require.main === module ? path.dirname(process.argv[1]) : __dirname;
const ROOT = fs.realpathSync(path.resolve(ENTRY_DIRECTORY, "../.."));
const { SCHEMA, POLICY_SCHEMA, SETUP_SCHEMA, VERSION, SELECTION, CONFIG, PRESETS, NAMES, ORDER, AssuranceError, unknownPreset, enforcement, resolve } =
	policy;
const context = (root = ROOT) => policy.context(root);
const readSelection = (root = ROOT) => policy.readSelection(root);

function readContracts(root) {
	const contracts = require("./contracts.js");
	const ctx = contracts.context(root);
	try {
		return { contracts, ctx, config: contracts.readConfig(ctx) };
	} catch (error) {
		throw new AssuranceError(
			String(error.message).startsWith("contracts:") ? error.message : `contracts: ${error.message}`,
		);
	}
}
function show({ root = ROOT, env = process.env } = {}) {
	const selection = readSelection(root);
	const { config } = readContracts(root);
	return {
		...resolve({ preset: selection.preset, contracts: config, env }),
		selection: { file: SELECTION, selected: selection.selected },
	};
}

// --- explicit setup ---------------------------------------------------------------------------
// Validates everything before the first write. Contracts are enabled before the selection is
// written, so a failure never leaves a preset that claims requirements it cannot meet.
function setup({ root = ROOT, preset, apply = false, env = process.env } = {}) {
	if (typeof preset !== "string" || !Object.hasOwn(PRESETS, preset)) throw unknownPreset(preset);
	const ctx = context(root);
	if (!fs.existsSync(ctx.workspace))
		throw new AssuranceError("assurance: no ai-factory/ here; adopt the layout first");
	const current = readSelection(root);
	const loaded = readContracts(root);
	const requirement = PRESETS[preset];
	// Applied in this order: enable first, so a failure leaves no selection behind.
	const changes = [];
	if (requirement.contracts && !loaded.config.adopted)
		changes.push({ action: "enable_contracts", path: CONFIG });
	if (current.preset !== preset)
		changes.push({ action: "select", path: SELECTION, from: current.preset, to: preset });
	const retained = [];
	if (!requirement.contracts && loaded.config.adopted)
		retained.push(`contracts configuration (${CONFIG}) and recorded evidence are kept; light never disables them`);
	const predicted = requirement.contracts && !loaded.config.adopted
		? { ...loaded.config, adopted: true }
		: loaded.config;
	const policy = resolve({ preset, contracts: predicted, env });
	const result = {
		schema: SETUP_SCHEMA,
		version: VERSION,
		preset,
		from: current.preset,
		apply,
		changes,
		retained,
		blocked: policy.conflicts.length > 0,
		applied: false,
		partial: [],
		failed: null,
		policy,
	};
	if (!apply || result.blocked) return result;
	for (const change of changes) {
		try {
			if (change.action === "enable_contracts") loaded.contracts.enable({ ctx: loaded.ctx });
			else ctx.safe.write(ctx.file, `${JSON.stringify({ schema: SCHEMA, version: VERSION, preset })}\n`);
			result.partial.push(change.action);
		} catch (error) {
			// Diagnostics name workspace-relative paths, never the absolute checkout.
			result.failed = { step: change.action, message: String(error.message).split(`${root}${path.sep}`).join("") };
			return result;
		}
	}
	result.applied = true;
	result.policy = { ...resolve({ preset, contracts: readContracts(root).config, env }) };
	return result;
}

// --- command line -----------------------------------------------------------------------------
function text(value) {
	if (Array.isArray(value)) return value.length ? value.join(",") : "none";
	if (value && typeof value === "object")
		return `include=${text(value.include)} exclude=${text(value.exclude)}`;
	return String(value);
}
function table(policy) {
	return ORDER.map((key) => {
		const item = policy.settings[key];
		const value = text(item.value);
		return `  ${key.padEnd(22)} ${value.padEnd(18)} (${item.source}${item.retained ? ", retained above preset" : ""})`;
	});
}
function headline(policy) {
	if (policy.preset === null)
		return `assurance: no preset selected — legacy behavior; existing configuration unchanged${policy.status === "conflict" ? " (conflict)" : ""}`;
	return `assurance: preset ${policy.preset} — ${policy.status}`;
}
function problems(policy) {
	return [
		...policy.conflicts.map((item) => `conflict ${item.code}: ${item.message}\n  ${item.hint}`),
		...policy.unmet.map((item) => `unmet ${item.code}: ${item.message}\n  ${item.hint}`),
	];
}
// One line for runners and gates: the preset, its status and the requirements it applies.
function describe(policy) {
	const shown = ORDER.filter((key) => !["allow_attestation", "code_scope"].includes(key))
		.map((key) => `${key}=${text(policy.settings[key].value)}`)
		.join(" ");
	return `assurance: preset ${policy.preset} — ${policy.status}: ${shown}`;
}
function parseArgs(argv) {
	const [command, ...rest] = argv;
	if (!["show", "set", "complete"].includes(command))
		throw new AssuranceError("usage: assurance.js show [--json] | set light|standard|strict [--apply] [--json] | complete <delivery> [--json]");
	const options = { command, json: false, apply: false, positional: [] };
	for (const arg of rest) {
		if (arg === "--json" && !options.json) options.json = true;
		else if (arg === "--apply" && command === "set" && !options.apply) options.apply = true;
		else if (arg.startsWith("--")) throw new AssuranceError(`assurance: invalid argument ${arg}`);
		else options.positional.push(arg);
	}
	if (command === "show" && options.positional.length)
		throw new AssuranceError("assurance: show takes no arguments");
	if (command === "set" && options.positional.length !== 1)
		throw new AssuranceError(`assurance: set takes one preset (${NAMES.join(", ")})`);
	if (command === "complete" && options.positional.length !== 1)
		throw new AssuranceError("assurance: complete takes one delivery ID (d-YYYYMMDD-xxxxxx)");
	return options;
}
// Completion is judged by delivery-report.js from current evidence; loaded lazily (it imports
// contracts.js, which imports this module).
function complete({ root = ROOT, delivery, env = process.env } = {}) {
	const reports = require("./delivery-report.js");
	try {
		return reports.completion({ root, delivery, env });
	} catch (error) {
		if (error instanceof AssuranceError) throw error;
		throw new AssuranceError(String(error.message).replace(/^(?!assurance:|contracts:|delivery-report:)/, "assurance: "));
	}
}
// Command handlers: each prints its own output and returns the exit code.
function showCommand(options, { root, env, out, err }) {
	const policy = show({ root, env });
	const ok = policy.status === "active" || policy.status === "legacy";
	if (options.json) out(JSON.stringify(policy, null, 2));
	else {
		out(headline(policy));
		for (const line of table(policy)) out(line);
		for (const line of problems(policy)) err(line);
		out(policy.note);
	}
	return ok ? 0 : 1;
}
function completeCommand(options, { root, env, out, err }) {
	const result = complete({ root, delivery: options.positional[0], env });
	if (options.json) out(JSON.stringify(result, null, 2));
	else {
		out(`assurance: completion ${result.claimable ? "may be claimed" : "may NOT be claimed"} — ${result.delivery} (${result.preset ? `preset ${result.preset}` : "no preset"}, requires ${result.requirement})`);
		out(`  report status: ${result.report_status}${result.written.length ? ` (freshly generated: ${result.written.join(", ")})` : " (evaluated now from current evidence; nothing written)"}`);
		for (const item of result.open) err(`  [${item.state}] ${item.code}: ${item.message}${item.evidence_ref ? ` — ${item.evidence_ref}` : ""}`);
		out(`  ${result.note}`);
	}
	return result.claimable ? 0 : 1;
}
function setCommand(options, { root, env, out, err }) {
	const result = setup({ root, preset: options.positional[0], apply: options.apply, env });
	const ok = !result.blocked && (!result.apply || result.applied);
	if (options.json) {
		out(JSON.stringify(result, null, 2));
		if (result.failed) err(`assurance: setup failed at ${result.failed.step}: ${result.failed.message}`);
		return ok ? 0 : 1;
	}
	setChanges(result, { out, err });
	if (result.failed) {
		err(`assurance: setup failed at ${result.failed.step}: ${result.failed.message}`);
		err(`assurance: completed before the failure: ${result.partial.length ? result.partial.join(", ") : "nothing"}; preset ${result.preset} is not active`);
		return 1;
	}
	if (result.applied) out(headline(result.policy));
	else out("  effective settings after applying:");
	for (const line of table(result.policy)) out(line);
	if (!result.apply && !result.blocked) out(`Preview only; rerun with --apply to write these changes: assurance.js set ${result.preset} --apply`);
	out(result.policy.note);
	return ok ? 0 : 1;
}
// The set report's head: what was (or would be) changed, kept, and what blocks it.
function setChanges(result, { out, err }) {
	const verb = result.applied ? "applied" : result.apply ? "not applied" : "preview";
	out(`assurance: ${verb} — select ${result.preset} (from ${result.from || "no preset"})`);
	if (!result.changes.length) out(`  nothing to change; preset ${result.preset} is already selected`);
	for (const change of result.changes)
		out(`  ${change.action.padEnd(17)} ${change.path}${change.action === "select" ? `: ${change.from || "none"} → ${change.to}` : ""}`);
	for (const note of result.retained) out(`retained: ${note}`);
	for (const line of problems(result.policy)) err(line);
	if (result.blocked) err(`assurance: preset ${result.preset} was not selected; resolve the conflict first`);
}
const COMMANDS = { show: showCommand, complete: completeCommand, set: setCommand };
function main(argv = process.argv.slice(2), env = process.env, root = ROOT) {
	const out = (line) => process.stdout.write(`${line}\n`);
	const err = (line) => process.stderr.write(`${line}\n`);
	try {
		// parseArgs admits only the commands listed in COMMANDS.
		const options = parseArgs(argv);
		return COMMANDS[options.command](options, { root, env, out, err });
	} catch (error) {
		err(error instanceof AssuranceError ? error.message : `assurance: ${error.message}`);
		return error instanceof AssuranceError ? error.exitCode : 2;
	}
}
module.exports = {
	PRESETS,
	SCHEMA,
	POLICY_SCHEMA,
	VERSION,
	SELECTION,
	AssuranceError,
	enforcement,
	resolve,
	readSelection,
	show,
	setup,
	complete,
	describe,
	main,
};
if (require.main === module) process.exitCode = main();
