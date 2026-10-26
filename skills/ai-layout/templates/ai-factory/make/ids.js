#!/usr/bin/env node
// Artefact IDs: the one place that owns the `[A-Z]{3}[0-9]{3}` format. Every new spec, plan,
// exploration, analysis, design, ADR and risk assessment is created here, so no prompt ever
// picks or counts an ID itself.
//   ids.js new <kind> <slug> [--id <ID>] [--title "<Title>"]
//                                                 create ai-factory/<kind dir>/<ID>-<slug>.md
//   ids.js check                                  the clash check across clones (make ids-check)
// Exit 0: created, the repository-relative path on stdout. Exit 2: refused (usage, bad slug or
// title, missing parent, or reuse not allowed for this kind), one line on stderr. Exit 3: this
// kind already has a file with the ID, its path on stdout. Exit 1: runtime failure.
// An ID is drawn at random (never counted), checked against one ID space shared by all seven
// kind directories, reserved under ai-factory/runs/tmp/ids/ while it is rechecked, and the file
// is created exclusively. Two sessions drawing the same ID at the same moment therefore end
// with two different IDs, even when their slugs differ.
// `--id` reuses a parent's ID instead of drawing: a spec takes an exploration's or analysis's,
// a plan or risk assessment its spec's (a legacy four-digit spec number too). One file per kind
// per ID; the reservation key is `<kind>-<ID>`, so two sessions reusing one ID end with one file.
// `check` reads the `.md` files of the seven kinds after a merge: a new-style ID may be shared
// only by one spec with at most one exploration or analysis, one plan and one risk assessment;
// a legacy number only must not repeat within a kind. Exit 0: pass. Exit 1: every clash on
// stdout with every path involved. A new-style file without a valid line-2 `Created:` is
// warned about on stderr, and a warning alone never fails the check.
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const { boundary } = require("./safe-files.js");
// Preserve the invoked workspace when its entry point is a source-repo symlink (see runner.js).
const ENTRY_DIRECTORY =
	require.main === module ? path.dirname(process.argv[1]) : __dirname;
const ROOT = fs.realpathSync(path.resolve(ENTRY_DIRECTORY, "../.."));

// No I or O: they read as 1 and 0.
const LETTERS = "ABCDEFGHJKLMNPQRSTUVWXYZ";
const DIGITS = "0123456789";
const KINDS = {
	spec: "specs",
	plan: "plans",
	exploration: "explorations",
	analysis: "analyses",
	design: "designs",
	adr: "adr",
	risk: "risks",
};
// The one ID space: every entry name here uses its ID, sidecars and done plans included.
const SCANNED = [...Object.values(KINDS), "plans/done"];
const DENY_FILE = "ai-factory/ids-deny.txt";
const ADR_TEMPLATE = "ai-factory/adr/0000-template.md";
const SLUG = /^[a-z0-9]+(-[a-z0-9]+)*$/;
const ENTRY_ID = /^([A-Za-z]{3}[0-9]{3})(?=[-.]|$)/;
const ATTEMPTS = 1000;
// Which kinds may reuse an ID, and the kinds whose artefact must already hold it.
const PARENTS = {
	spec: { dirs: ["explorations", "analyses"], name: "exploration or analysis" },
	plan: { dirs: ["specs"], name: "spec" },
	risk: { dirs: ["specs"], name: "spec" },
};
const NEW_ID = /^[A-Za-z]{3}[0-9]{3}$/;
const LEGACY_ID = /^[0-9]{4}$/;
// A reuse waits this long for another session's reservation, polling, before it refuses; a
// reservation older than STALE_MS was left by a crash and is reclaimed.
const WAIT_MS = 2000;
const POLL_MS = 20;
const STALE_MS = 60_000;
// Offensive or loaded letter triples never drawn. ai-factory/ids-deny.txt adds to this list.
const BUILTIN_DENY = Object.freeze(
	[
		"ASS", "BUM", "CNT", "CUM", "DCK", "DMN", "FAG", "FCK", "FKU", "FUC", "FUK", "FUX",
		"GAY", "GDM", "HOR", "JEW", "JZZ", "KKK", "KYS", "NAZ", "NGA", "NGR", "NIG", "PCP",
		"PEE", "PMS", "PNS", "POO", "PRN", "PUS", "PSY", "RAP", "SAD", "SEX", "SHT", "SLT",
		"STD", "SUK", "SUX", "TIT", "TWT", "VAG", "WAP", "WTF", "XXX", "ZEX",
	].sort(),
);

class Refusal extends Error {}
// This kind already has a file with the ID: exit 3, its path on stdout.
class Existing extends Error {
	constructor(message, file) {
		super(message);
		this.path = file;
	}
}
const refuse = (message) => {
	throw new Refusal(message);
};
const defaultWarn = (line) => process.stderr.write(`ids.js: ${line}\n`);
const relative = (root, file) =>
	path.relative(root, file).split(path.sep).join("/");

// Built-in triples plus the repo's own, matched case-insensitively. Blank and `#` lines are
// silent; any other line that is not exactly three letters is named in a warning and skipped.
function denylist(root, warn) {
	const deny = new Set(BUILTIN_DENY);
	let text;
	try {
		text = fs.readFileSync(path.join(root, DENY_FILE), "utf8");
	} catch (error) {
		if (error.code === "ENOENT") return deny;
		throw error;
	}
	for (const [index, raw] of text.split(/\r?\n/).entries()) {
		const line = raw.trim();
		if (!line || line.startsWith("#")) continue;
		if (/^[A-Za-z]{3}$/.test(line)) deny.add(line.toUpperCase());
		else
			warn(
				`${DENY_FILE} line ${index + 1}: '${line}' is not three letters; skipped`,
			);
	}
	return deny;
}

// Every ID an entry name already uses, uppercase. Legacy four-digit names use none.
function usedIds(root) {
	const used = new Set();
	for (const dir of SCANNED) {
		let names;
		try {
			names = fs.readdirSync(path.join(root, "ai-factory", dir));
		} catch (error) {
			if (error.code === "ENOENT" || error.code === "ENOTDIR") continue;
			throw error;
		}
		for (const name of names) {
			const match = ENTRY_ID.exec(name);
			if (match) used.add(match[1].toUpperCase());
		}
	}
	return used;
}

// An ID must never read as a criterion (AC1), quick-check (QC1) or step (S1) ID.
function rejected(id, deny, used) {
	return (
		/^(AC|QC)/.test(id) ||
		/^S[0-9]+$/.test(id) ||
		/\bAC[0-9]+\b/.test(id) ||
		/\bQC[0-9]+\b/.test(id) ||
		deny.has(id.slice(0, 3)) ||
		used.has(id)
	);
}

function candidate(random) {
	let id = "";
	for (let i = 0; i < 3; i++) id += LETTERS[random(LETTERS.length)];
	for (let i = 0; i < 3; i++) id += DIGITS[random(DIGITS.length)];
	return id;
}

function drawFrom({ random, deny, used, tried }) {
	for (let attempt = 0; attempt < ATTEMPTS * 10; attempt++) {
		const id = candidate(random);
		if (!rejected(id, deny, used) && !tried.has(id)) return id;
	}
	throw new Error("no free ID found; the random source keeps returning used IDs");
}

// Draw one free ID over the tree at `root`. It is not reserved: create() does that.
function draw({
	root = ROOT,
	random = crypto.randomInt,
	warn = defaultWarn,
} = {}) {
	return drawFrom({
		random,
		deny: denylist(root, warn),
		used: usedIds(root),
		tried: new Set(),
	});
}

function titleFrom(slug, title) {
	if (title === undefined) {
		const words = slug.replace(/-/g, " ");
		return words.charAt(0).toUpperCase() + words.slice(1);
	}
	if (typeof title !== "string" || /[\r\n]/.test(title))
		refuse("the title must be a single line");
	if (!title.trim()) refuse("the title must not be empty");
	return title;
}

// The helper writes the first two lines; the agent writes everything below them. An ADR is
// the template with its heading replaced and Created: inserted after it, the rest byte for byte.
function contentFor(kind, id, title, created, template) {
	const heading = `# ${id} — ${title}`;
	const stamp = `Created: ${created}`;
	if (kind !== "adr") return `${heading}\n${stamp}\n`;
	const lines = template.split("\n");
	const at = lines.findIndex((line) => line.startsWith("# "));
	if (at < 0) throw new Error(`${ADR_TEMPLATE} has no '# ' heading line`);
	const cr = lines[at].endsWith("\r") ? "\r" : "";
	lines.splice(at, 1, `${heading}${cr}`, `${stamp}${cr}`);
	return lines.join("\n");
}

const sleep = (ms) =>
	Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);

// The `.md` files under ai-factory/<dir> whose name carries `id` (case-insensitive), sorted.
function holders(root, dirs, id) {
	const found = [];
	for (const dir of dirs) {
		let names;
		try {
			names = fs.readdirSync(path.join(root, "ai-factory", dir));
		} catch (error) {
			if (error.code === "ENOENT" || error.code === "ENOTDIR") continue;
			throw error;
		}
		for (const name of names.sort()) {
			const dash = name.indexOf("-");
			if (dash < 0 || !name.endsWith(".md")) continue;
			if (name.slice(0, dash).toUpperCase() === id)
				found.push(`ai-factory/${dir}/${name}`);
		}
	}
	return found;
}
const kindDirs = (kind) => (kind === "plan" ? ["plans", "plans/done"] : [KINDS[kind]]);

// Validate a reused ID before anything is created; returns it uppercase.
function reusable(kind, raw) {
	if (!Object.hasOwn(PARENTS, kind))
		refuse(`a ${kind} never reuses an ID (--id is for spec, plan and risk)`);
	if (typeof raw !== "string" || !(NEW_ID.test(raw) || LEGACY_ID.test(raw)))
		refuse(`--id '${raw}' is neither an ID like DHW631 nor a four-digit legacy number`);
	if (LEGACY_ID.test(raw) && kind === "spec")
		refuse(`a spec never takes the legacy number ${raw}; draw a fresh ID and cite the parent`);
	return raw.toUpperCase();
}

// Refuse unless a permitted parent holds the ID; exit 3 when this kind already holds it.
function admit(root, kind, id) {
	const own = holders(root, kindDirs(kind), id);
	if (own.length)
		throw new Existing(`${own[0]} already has the ID ${id}; nothing created`, own[0]);
	const parent = PARENTS[kind];
	if (!holders(root, parent.dirs, id).length)
		refuse(`no ${parent.name} has the ID ${id}; a ${kind} reuses only its parent's ID`);
}

// Take the `<kind>-<ID>` reservation: wait for another session, reclaim a stale one, or fail.
function reserve(safe, reservation, id, now) {
	const deadline = Date.now() + WAIT_MS;
	for (;;) {
		try {
			safe.write(reservation, `${process.pid}\n`, { exclusive: true });
			return;
		} catch (error) {
			if (error.code !== "EEXIST") throw error;
		}
		let stat;
		try {
			stat = fs.lstatSync(reservation);
		} catch (error) {
			if (error.code === "ENOENT") continue; // released meanwhile: retry at once
			throw error;
		}
		if (now().getTime() - stat.mtimeMs > STALE_MS) {
			safe.unlink(reservation); // left by a crashed session
			continue;
		}
		if (Date.now() >= deadline)
			throw new Error(
				`another session is creating this ${path.basename(reservation)} file for ${id}; retry`,
			);
		sleep(POLL_MS);
	}
}

// Create the artefact for a reused ID; returns { id, path }.
function reuse({ root, safe, kind, slug, id, heading, now, beforeOpen, directory, reservations }) {
	admit(root, kind, id);
	const reservation = path.join(reservations, `${kind}-${id}`);
	reserve(safe, reservation, id, now);
	try {
		admit(root, kind, id); // another session may have finished while we waited
		const target = path.join(directory, `${id}-${slug}.md`);
		if (beforeOpen) beforeOpen(target, id);
		const content = contentFor(kind, id, heading, now().toISOString(), "");
		try {
			safe.write(target, content, { exclusive: true });
		} catch (error) {
			if (error.code !== "EEXIST") throw error;
			const rel = relative(root, target);
			throw new Existing(`${rel} already has the ID ${id}; nothing created`, rel);
		}
		return { id, path: relative(root, target) };
	} finally {
		safe.unlink(reservation);
	}
}

// Create one artefact with a freshly drawn ID; returns { id, path } (path repository-relative).
// `beforeOpen(target, id)` runs just before the exclusive create: a test seam for the race.
function create({
	root = ROOT,
	kind,
	slug,
	title,
	id,
	random = crypto.randomInt,
	now = () => new Date(),
	beforeOpen,
	warn = defaultWarn,
} = {}) {
	if (!Object.hasOwn(KINDS, kind))
		refuse(
			`unknown kind '${kind}' (expected: ${Object.keys(KINDS).join(", ")})`,
		);
	const reused = id === undefined ? undefined : reusable(kind, id);
	if (kind === "plan" && reused === undefined)
		refuse("a plan reuses its spec's ID (--id <spec ID>); it is never drawn fresh");
	if (typeof slug !== "string" || !SLUG.test(slug))
		refuse(`slug '${slug}' must match ${SLUG.source}`);
	const heading = titleFrom(slug, title);
	const ai = path.join(root, "ai-factory");
	const safe = boundary(ai);
	// The template is only read, and in the source repo it is a symlink into skills/.
	const template =
		kind === "adr" ? fs.readFileSync(path.join(root, ADR_TEMPLATE), "utf8") : "";
	const deny = denylist(root, warn);
	const directory = safe.mkdir(path.join(ai, KINDS[kind]));
	const reservations = safe.mkdir(path.join(ai, "runs", "tmp", "ids"));
	if (reused !== undefined)
		return reuse({ root, safe, kind, slug, id: reused, heading, now, beforeOpen, directory, reservations });
	const tried = new Set();
	for (let attempt = 0; attempt < ATTEMPTS; attempt++) {
		const drawn = drawFrom({ random, deny, used: usedIds(root), tried });
		tried.add(drawn);
		const reservation = path.join(reservations, drawn);
		try {
			safe.write(reservation, `${process.pid}\n`, { exclusive: true });
		} catch (error) {
			if (error.code === "EEXIST") continue; // another session holds this ID: redraw
			throw error;
		}
		try {
			if (usedIds(root).has(drawn)) continue; // created while we drew: redraw
			const target = path.join(directory, `${drawn}-${slug}.md`);
			if (beforeOpen) beforeOpen(target, drawn);
			const content = contentFor(kind, drawn, heading, now().toISOString(), template);
			try {
				safe.write(target, content, { exclusive: true });
			} catch (error) {
				if (error.code === "EEXIST") continue; // never overwrite: redraw
				throw error;
			}
			return { id: drawn, path: relative(root, target) };
		} finally {
			safe.unlink(reservation);
		}
	}
	throw new Error(`no ID could be reserved after ${ATTEMPTS} attempts`);
}

// The kind of each scanned directory; done plans are plans.
const KIND_OF = { ...Object.fromEntries(Object.entries(KINDS).map(([k, d]) => [d, k])), "plans/done": "plan" };
const ARTEFACT = /^(?:([A-Za-z]{3}[0-9]{3})|([0-9]{4}))-.*\.md$/;
// The one valid line 2: the UTC form create() writes.
const CREATED = /^Created: \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{3})?Z\r?$/;

// Why a group of new-style files sharing one ID is not allowed, or undefined when it is.
function clash(byKind) {
	const kinds = Object.keys(byKind);
	const doubled = kinds.filter((kind) => byKind[kind].length > 1);
	if (doubled.length) return `more than one ${doubled.join(", more than one ")} has the ID`;
	if (kinds.length < 2) return undefined;
	const alone = kinds.filter((kind) => kind === "design" || kind === "adr");
	if (alone.length) return `a ${alone.join(" and an ")} never shares its ID`;
	if (byKind.exploration && byKind.analysis)
		return "an exploration and an analysis never share an ID";
	if (!byKind.spec) return "only a spec's exploration or analysis, plan and risk share its ID, and no spec has it";
	return undefined;
}

// The clash check over the tree at `root`: { failures: [{ id, reason, paths }], warnings, count }.
function check({ root = ROOT, warn = defaultWarn } = {}) {
	const fresh = new Map();
	const legacy = new Map();
	const warnings = [];
	let count = 0;
	for (const dir of SCANNED) {
		let names;
		try {
			names = fs.readdirSync(path.join(root, "ai-factory", dir), { withFileTypes: true });
		} catch (error) {
			if (error.code === "ENOENT" || error.code === "ENOTDIR") continue;
			throw error;
		}
		for (const entry of names.sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0))) {
			const match = ARTEFACT.exec(entry.name);
			if (!match || entry.isDirectory()) continue;
			count++;
			const rel = `ai-factory/${dir}/${entry.name}`;
			const kind = KIND_OF[dir];
			const groups = match[1] ? fresh : legacy;
			const id = (match[1] || match[2]).toUpperCase();
			if (!groups.has(id)) groups.set(id, {});
			(groups.get(id)[kind] ||= []).push(rel);
			if (!match[1]) continue;
			const line = fs.readFileSync(path.join(root, rel), "utf8").split("\n")[1];
			if (line === undefined || !CREATED.test(line)) {
				const message = `${rel} has no valid 'Created:' line 2; it sorts as undated`;
				warnings.push(message);
				warn(`warning: ${message}`);
			}
		}
	}
	const failures = [];
	const all = (byKind) => Object.values(byKind).flat().sort();
	for (const [id, byKind] of [...fresh].sort()) {
		const reason = clash(byKind);
		if (reason) failures.push({ id, reason, paths: all(byKind) });
	}
	for (const [id, byKind] of [...legacy].sort())
		for (const [kind, paths] of Object.entries(byKind))
			if (paths.length > 1)
				failures.push({ id, reason: `more than one ${kind} has the legacy number`, paths: [...paths].sort() });
	return { failures, warnings, count };
}

const USAGE = 'usage: ids.js new <kind> <slug> [--id <ID>] [--title "<Title>"] | ids.js check';

function parseNew(args) {
	const positional = [];
	let title;
	let id;
	for (let i = 0; i < args.length; i++) {
		const arg = args[i];
		if (arg === "--id") {
			if (i + 1 >= args.length) refuse("--id needs a value");
			id = args[++i];
		} else if (arg === "--title") {
			if (i + 1 >= args.length) refuse("--title needs a value");
			title = args[++i];
		} else if (arg.startsWith("-")) refuse(`unknown option '${arg}'`);
		else positional.push(arg);
	}
	if (positional.length !== 2)
		refuse(USAGE);
	return { kind: positional[0], slug: positional[1], title, id };
}

function main(argv) {
	const [command, ...rest] = argv;
	if (command === "check") {
		if (rest.length) refuse(`check takes no arguments; ${USAGE}`);
		const result = check({ root: ROOT });
		for (const { id, reason, paths } of result.failures)
			process.stdout.write(`ID clash ${id}: ${reason}: ${paths.join(", ")}\n`);
		if (result.failures.length) {
			process.exitCode = 1;
			return;
		}
		process.stdout.write(`ids ok — ${result.count} artefacts, no clash\n`);
		return;
	}
	if (command !== "new") refuse(USAGE);
	const made = create({ root: ROOT, ...parseNew(rest) });
	process.stdout.write(`${made.path}\n`);
}

if (require.main === module) {
	try {
		main(process.argv.slice(2));
	} catch (error) {
		const message = String(error.message || error).split("\n")[0];
		if (error instanceof Existing) process.stdout.write(`${error.path}\n`);
		process.stderr.write(`ids.js: ${message}\n`);
		process.exitCode = error instanceof Existing ? 3 : error instanceof Refusal ? 2 : 1;
	}
}

module.exports = { draw, create, check, BUILTIN_DENY };
