// Assurance policy: the presets and the pure rules over them, plus reading the selection
// (ai-factory/assurance.json). A leaf module: it requires only Node built-ins and safe-files.js,
// never contracts.js, gate.js or delivery-report.js, so every one of them may import it without a
// require() cycle. make/assurance.js is the command line over this module and re-exports it.
// resolve() is pure: callers pass validated existing settings (contracts.readConfig output and
// the environment).
const fs = require("node:fs");
const path = require("node:path");
const { boundary } = require("./safe-files.js");

const SCHEMA = "fc-assurance";
const POLICY_SCHEMA = "fc-assurance-policy";
const SETUP_SCHEMA = "fc-assurance-setup";
const VERSION = 1;
const SELECTION = "ai-factory/assurance.json";
const CONFIG = "ai-factory/contracts/config.json";
const NOTE =
	"Project rules in ai-factory/ still apply; a preset only adds requirements and never weakens them or risk routing.";
// Requirements each preset sets as a minimum. Order of keys is the display order.
const PRESETS = {
	light: {
		contracts: false,
		final_verification: false,
		review_required: false,
		review_required_quick: false,
		review_independence: "self",
		gate: "advisory",
		completion: "summary",
		blocking_severities: [],
	},
	standard: {
		contracts: true,
		final_verification: true,
		review_required: true,
		review_required_quick: true,
		review_independence: "independent",
		gate: "advisory",
		completion: "recorded_checks",
		blocking_severities: ["blocker"],
	},
	strict: {
		contracts: true,
		final_verification: true,
		review_required: true,
		review_required_quick: true,
		review_independence: "independent",
		gate: "enforced",
		completion: "fresh_ready_report",
		blocking_severities: ["blocker"],
	},
};
const NAMES = Object.keys(PRESETS);
const RANKS = {
	review_independence: ["unspecified", "self", "independent"],
	gate: ["advisory", "enforced"],
	completion: ["summary", "recorded_checks", "fresh_ready_report"],
};
const SEVERITIES = ["blocker", "major", "minor"];
const ORDER = [
	"contracts",
	"final_verification",
	"review_required",
	"review_required_quick",
	"review_independence",
	"gate",
	"completion",
	"blocking_severities",
	"allow_attestation",
	"code_scope",
];

class AssuranceError extends Error {
	constructor(message, code = 2) {
		super(message);
		this.exitCode = code;
	}
}
function unknownPreset(name) {
	return new AssuranceError(
		`assurance: unknown preset '${name}' (expected ${NAMES.join(", ")})`,
	);
}

// What the repository already enforces, before any preset. Values from a missing contracts
// configuration are labelled `default`: they are not in force and never outrank a preset.
function existing(contracts, env) {
	const adopted = Boolean(contracts && contracts.adopted);
	const policy = (contracts && contracts.completion) || {};
	const from = adopted ? CONFIG : "default";
	const enforce = env.GATE_ENFORCE;
	const gateSource =
		enforce === "0" || enforce === "1" ? "GATE_ENFORCE" : "default";
	return {
		contracts: { value: adopted, source: from },
		final_verification: { value: adopted, source: from },
		review_required: { value: adopted && policy.require_review === true, source: from },
		review_required_quick: { value: adopted && policy.require_review_quick === true, source: from },
		review_independence: { value: "unspecified", source: "default" },
		gate: { value: enforce === "1" ? "enforced" : "advisory", source: gateSource },
		completion: { value: adopted ? "recorded_checks" : "summary", source: from },
		blocking_severities: {
			value: adopted && Array.isArray(policy.blocking_severities) ? policy.blocking_severities : ["blocker"],
			source: from,
		},
		allow_attestation: { value: adopted && policy.allow_attestation === true, source: from },
		code_scope: {
			value: (contracts && contracts.code_scope) || { include: ["**"], exclude: [] },
			source: from,
		},
	};
}
const sorted = (list) =>
	SEVERITIES.filter((item) => list.includes(item));
// Stronger of the preset minimum and the existing control; ties are attributed to the preset.
function combine(key, minimum, current, name) {
	const preset = { value: minimum, source: `preset:${name}`, retained: false };
	if (current.source === "default") return preset;
	const above = { ...current, retained: true };
	if (key === "blocking_severities") {
		const union = sorted([...minimum, ...current.value]);
		return union.length > minimum.length
			? { value: union, source: current.source, retained: true }
			: preset;
	}
	if (RANKS[key])
		return RANKS[key].indexOf(current.value) > RANKS[key].indexOf(minimum) ? above : preset;
	return current.value === true && minimum === false ? above : preset;
}

// The review gate's mode, shared by resolve(), gate.js and runner.js so every caller applies the
// same rule. Without a preset GATE_ENFORCE keeps its existing meaning; strict enforces the gate,
// a stricter GATE_ENFORCE=1 is always allowed, and GATE_ENFORCE=0 under strict is a conflict.
function enforcement({ preset = null, env = {} } = {}) {
	if (preset !== null && !Object.hasOwn(PRESETS, preset)) throw unknownPreset(preset);
	const value = env.GATE_ENFORCE;
	const conflicts = [];
	if (value !== undefined && value !== "" && value !== "0" && value !== "1")
		conflicts.push({
			code: "E_GATE_INVALID",
			message: `GATE_ENFORCE=${JSON.stringify(value)} is not 0, 1, or unset`,
			hint: "Unset GATE_ENFORCE or set it to 0 or 1.",
		});
	const presetEnforced = preset !== null && PRESETS[preset].gate === "enforced";
	if (presetEnforced && value === "0")
		conflicts.push({
			code: "E_GATE_CONFLICT",
			message: `GATE_ENFORCE=0 conflicts with preset ${preset}, which enforces the review gate`,
			hint: `Unset GATE_ENFORCE (or set it to 1), or select a preset with an advisory gate: assurance.js set standard --apply.`,
		});
	const explicit = value === "0" || value === "1";
	// Attributed as resolve() does: a tie with the preset's own requirement belongs to the preset.
	const source =
		preset === null
			? explicit ? "GATE_ENFORCE" : "default"
			: value === "1" && !presetEnforced ? "GATE_ENFORCE" : `preset:${preset}`;
	return { preset, mode: presetEnforced || value === "1" ? "enforced" : "advisory", source, conflicts };
}

// Pure resolution. `preset` is a preset name or null (no selection); `contracts` is the
// validated contracts.readConfig() result; `env` carries GATE_ENFORCE.
function resolve({ preset = null, contracts, env = {} } = {}) {
	if (preset !== null && !Object.hasOwn(PRESETS, preset)) throw unknownPreset(preset);
	const base = existing(contracts, env);
	const settings = {};
	const gate = enforcement({ preset, env });
	const conflicts = gate.conflicts.filter((item) => item.code === "E_GATE_INVALID");
	const unmet = [];
	if (preset === null) {
		for (const key of ORDER) settings[key] = { ...base[key], retained: false };
	} else {
		const minimum = PRESETS[preset];
		for (const key of ORDER) {
			if (!Object.hasOwn(minimum, key)) {
				// Preserved as configured: presets neither require nor change these.
				settings[key] = { ...base[key], retained: false };
				continue;
			}
			settings[key] = combine(key, minimum[key], base[key], preset);
		}
		// Contracts are reported as they actually are; a requirement is never shown as met.
		if (minimum.contracts && !base.contracts.value) {
			settings.contracts = { value: false, source: base.contracts.source, retained: false };
			unmet.push({
				code: "U_CONTRACTS_NOT_ENABLED",
				message: `preset ${preset} requires artifact contracts, but ${CONFIG} does not exist`,
				hint: `Run assurance.js set ${preset} --apply (or contracts.js enable) to enable them.`,
			});
		}
		conflicts.push(...gate.conflicts.filter((item) => item.code === "E_GATE_CONFLICT"));
	}
	const status = conflicts.length
		? "conflict"
		: unmet.length
			? "incomplete"
			: preset === null
				? "legacy"
				: "active";
	return {
		schema: POLICY_SCHEMA,
		version: VERSION,
		mode: preset === null ? "legacy" : "preset",
		preset,
		status,
		settings,
		conflicts,
		unmet,
		note: NOTE,
	};
}

// --- reading the selection and existing configuration (read-only) -----------------------------
function context(root) {
	const workspace = path.join(root, "ai-factory");
	return { root, workspace, safe: boundary(workspace), file: path.join(workspace, "assurance.json") };
}
function readSelection(root) {
	const ctx = context(root);
	try {
		ctx.safe.assertPath(ctx.file, { allowMissing: false });
	} catch (error) {
		if (error.code === "ENOENT") return { selected: false, preset: null };
		const reason = String(error.message).replace(/: \/.*$/, "");
		throw new AssuranceError(`assurance: ${SELECTION}: ${reason}`);
	}
	let value;
	try {
		value = JSON.parse(fs.readFileSync(ctx.file, "utf8"));
	} catch (error) {
		throw new AssuranceError(
			`assurance: ${SELECTION}: ${error instanceof SyntaxError ? "not valid JSON" : error.code || error.message}`,
		);
	}
	const malformed = (message) =>
		new AssuranceError(`assurance: ${SELECTION}: ${message}; fix it or rerun assurance.js set <preset> after removing it`);
	if (!value || typeof value !== "object" || Array.isArray(value)) throw malformed("must be an object");
	if (value.schema !== SCHEMA) throw malformed(`schema must be ${SCHEMA}`);
	if (value.version !== VERSION) throw malformed(`version must be ${VERSION}`);
	const extra = Object.keys(value).filter((key) => !["schema", "version", "preset"].includes(key));
	if (extra.length) throw malformed(`holds only schema, version and preset (unexpected: ${extra.join(", ")})`);
	if (typeof value.preset !== "string" || !Object.hasOwn(PRESETS, value.preset))
		throw malformed(`unknown preset ${JSON.stringify(value.preset)} (expected ${NAMES.join(", ")})`);
	return { selected: true, preset: value.preset };
}

module.exports = {
	SCHEMA,
	POLICY_SCHEMA,
	SETUP_SCHEMA,
	VERSION,
	SELECTION,
	CONFIG,
	PRESETS,
	NAMES,
	ORDER,
	AssuranceError,
	unknownPreset,
	enforcement,
	resolve,
	context,
	readSelection,
};
