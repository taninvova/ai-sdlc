#!/usr/bin/env node
// Artefact IDs: the one place that owns the `<PREFIX>-<NNN>` format. Every new spec, plan,
// exploration, analysis, design, ADR and risk assessment is created here, so no prompt ever
// picks or counts an ID itself.
//   ids.js init --name "<Project>" [--prefix <ABC>]
//                                                 write ai-factory/project.json once
//   ids.js suggest "<Project>"                    print the prefix init would choose
//   ids.js new <kind> <slug> [--id <ID>] [--title "<Title>"]
//                                                 create ai-factory/<kind dir>/<ID>-<slug>.md
//   ids.js check                                  the clash check across clones (make ids-check)
// Exit 0: done, the repository-relative path (or the prefix) on stdout. Exit 2: refused (usage,
// bad slug, title, name or prefix, missing parent, reuse not allowed for this kind, or project
// already configured), one line on stderr. Exit 3: this kind already has a file with the ID, its
// path on stdout. Exit 4: no project prefix is configured yet; run `init`. Exit 1: runtime failure.
// The project's name and prefix live in ai-factory/project.json, chosen at adoption. A new ID is
// the prefix, a dash and the next free number, zero-padded to three digits (PMB-001, PMB-002…):
// one past the highest number that prefix already uses across all seven kind directories (one ID
// space). The number is reserved under ai-factory/runs/tmp/ids/ while it is rechecked and the
// file is created exclusively, so two sessions in one tree end with two different IDs. Separate
// clones or branches can still take the same number; `check` finds that after a merge.
// `--id` reuses a parent's ID instead: a spec takes an exploration's or analysis's, a plan or
// risk assessment its spec's (a four-digit legacy spec number or a legacy random ID too). One
// file per kind per ID; the reservation key is `<kind>-<ID>`, so two sessions reusing one ID end
// with one file.
// `check` reads the `.md` files of the seven kinds after a merge: a prefixed (or legacy random)
// ID may be shared only by one spec with at most one exploration or analysis, one plan and one
// risk assessment; a four-digit legacy number only must not repeat within a kind. Exit 0: pass.
// Exit 1: every clash on stdout with every path involved. A prefixed or legacy random file
// without a valid line-2 `Created:` is warned about on stderr, and a warning alone never fails.
const fs = require("node:fs");
const path = require("node:path");
const { boundary } = require("./safe-files.js");
// Preserve the invoked workspace when its entry point is a source-repo symlink (see runner.js).
const ENTRY_DIRECTORY =
	require.main === module ? path.dirname(process.argv[1]) : __dirname;
const ROOT = fs.realpathSync(path.resolve(ENTRY_DIRECTORY, "../.."));

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
const PROJECT_FILE = "ai-factory/project.json";
const ADR_TEMPLATE = "ai-factory/adr/0000-template.md";
const SLUG = /^[a-z0-9]+(-[a-z0-9]+)*$/;
// Two to five letters. AC and QC would read as criterion and quick-check IDs (AC1, QC1).
const PREFIX = /^[A-Z]{2,5}$/;
const RESERVED_PREFIXES = new Set(["AC", "QC"]);
const DIGITS = 3;
// The ID an entry name starts with: prefixed (PMB-001) or legacy random (DHW631, spec 0024).
const ENTRY_ID = /^([A-Za-z]{2,5}-[0-9]{3,}|[A-Za-z]{3}[0-9]{3})(?=[-.]|$)/;
const PREFIXED_ID = /^([A-Za-z]{2,5})-([0-9]+)$/;
const RANDOM_ID = /^[A-Za-z]{3}[0-9]{3}$/;
const LEGACY_ID = /^[0-9]{4}$/;
const ATTEMPTS = 1000;
// Which kinds may reuse an ID, and the kinds whose artefact must already hold it.
const PARENTS = {
	spec: { dirs: ["explorations", "analyses"], name: "exploration or analysis" },
	plan: { dirs: ["specs"], name: "spec" },
	risk: { dirs: ["specs"], name: "spec" },
};
// A reuse waits this long for another session's reservation, polling, before it refuses; a
// reservation older than STALE_MS was left by a crash and is reclaimed.
const WAIT_MS = 2000;
const POLL_MS = 20;
const STALE_MS = 60_000;

class Refusal extends Error {}
// This kind already has a file with the ID: exit 3, its path on stdout.
class Existing extends Error {
	constructor(message, file) {
		super(message);
		this.path = file;
	}
}
// No ai-factory/project.json yet: exit 4, so a prompt knows to ask for a name and a prefix.
class Unconfigured extends Error {}
const refuse = (message) => {
	throw new Refusal(message);
};
const relative = (root, file) =>
	path.relative(root, file).split(path.sep).join("/");

const format = (prefix, number) => `${prefix}-${String(number).padStart(DIGITS, "0")}`;

// A prefixed ID in its one written form: uppercase, the number padded to three digits, so
// `pmb-1`, `PMB-01` and `PMB-001` are one ID. Anything else is returned uppercase as it stands.
function normalise(id) {
	const match = PREFIXED_ID.exec(id);
	if (!match) return id.toUpperCase();
	return format(match[1].toUpperCase(), Number(match[2]));
}

function validPrefix(prefix) {
	if (typeof prefix !== "string" || !PREFIX.test(prefix))
		refuse(`prefix '${prefix}' must be two to five uppercase letters, such as PMB`);
	if (RESERVED_PREFIXES.has(prefix))
		refuse(`prefix '${prefix}' would read as a criterion or quick-check ID; choose another`);
	return prefix;
}

// The prefix a project name suggests: its first letter, then its consonants in order, then its
// remaining letters, three in all with no letter twice in a row. Pembina → PMB, Acme → ACM.
function suggest(name) {
	const letters = String(name ?? "").toUpperCase().replace(/[^A-Z]/g, "");
	if (letters.length < 2) refuse(`the project name '${name}' has fewer than two letters to make a prefix from`);
	const picked = [0];
	const take = (test) => {
		for (let i = 1; i < letters.length && picked.length < 3; i++)
			if (!picked.includes(i) && test(letters[i]) && letters[i] !== letters[picked[picked.length - 1]])
				picked.push(i);
	};
	take((ch) => !"AEIOUY".includes(ch));
	take(() => true);
	for (let i = 1; i < letters.length && picked.length < 3; i++) if (!picked.includes(i)) picked.push(i);
	let prefix = picked.sort((a, b) => a - b).map((i) => letters[i]).join("");
	if (RESERVED_PREFIXES.has(prefix)) prefix = `${prefix}X`;
	return prefix;
}

// The configured { name, prefix }, or undefined when the project has none yet.
function project(root = ROOT) {
	let text;
	try {
		text = fs.readFileSync(path.join(root, PROJECT_FILE), "utf8");
	} catch (error) {
		if (error.code === "ENOENT") return undefined;
		throw error;
	}
	let data;
	try {
		data = JSON.parse(text);
	} catch {
		refuse(`${PROJECT_FILE} is not valid JSON`);
	}
	if (!data || typeof data.name !== "string" || !data.name.trim())
		refuse(`${PROJECT_FILE} has no project name`);
	try {
		validPrefix(data.prefix);
	} catch (error) {
		refuse(`${PROJECT_FILE}: ${error.message}`);
	}
	return { name: data.name, prefix: data.prefix };
}

// Write ai-factory/project.json once; returns { name, prefix, path }. It never replaces one.
function init({ root = ROOT, name, prefix } = {}) {
	if (typeof name !== "string" || !name.trim() || /[\r\n]/.test(name))
		refuse("the project name must be a single non-empty line");
	const existing = project(root);
	if (existing)
		refuse(`${PROJECT_FILE} already names ${existing.name} with the prefix ${existing.prefix}; nothing changed`);
	const chosen = validPrefix(prefix === undefined ? suggest(name) : String(prefix).toUpperCase());
	const ai = path.join(root, "ai-factory");
	const safe = boundary(ai);
	const target = path.join(ai, "project.json");
	try {
		safe.write(target, `${JSON.stringify({ name: name.trim(), prefix: chosen }, null, "\t")}\n`, { exclusive: true });
	} catch (error) {
		if (error.code === "EEXIST") refuse(`${PROJECT_FILE} already exists; nothing changed`);
		throw error;
	}
	return { name: name.trim(), prefix: chosen, path: relative(root, target) };
}

const readNames = (root, dir) => {
	try {
		return fs.readdirSync(path.join(root, "ai-factory", dir));
	} catch (error) {
		if (error.code === "ENOENT" || error.code === "ENOTDIR") return [];
		throw error;
	}
};

// Every ID an entry name already uses, in its written form. Legacy four-digit names use none.
function usedIds(root) {
	const used = new Set();
	for (const dir of SCANNED)
		for (const name of readNames(root, dir)) {
			const match = ENTRY_ID.exec(name);
			if (match) used.add(normalise(match[1]));
		}
	return used;
}

// The number after the highest one `prefix` uses anywhere in the ID space.
function nextNumber(used, prefix) {
	let highest = 0;
	for (const id of used) {
		const match = PREFIXED_ID.exec(id);
		if (match && match[1] === prefix) highest = Math.max(highest, Number(match[2]));
	}
	return highest + 1;
}

// The next free ID over the tree at `root`. It is not reserved: create() does that.
function next({ root = ROOT } = {}) {
	const configured = project(root);
	if (!configured) throw unconfigured();
	return format(configured.prefix, nextNumber(usedIds(root), configured.prefix));
}

const unconfigured = () =>
	new Unconfigured(
		`no project prefix is configured; ask for the project name and prefix, then run node ai-factory/make/ids.js init --name "<Project>" --prefix <ABC>`,
	);

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

// The ID a file name starts with, in its written form, or undefined. Four-digit names included.
function idOfName(name) {
	const match = ENTRY_ID.exec(name);
	if (match) return normalise(match[1]);
	const legacy = /^([0-9]{4})(?=[-.]|$)/.exec(name);
	return legacy ? legacy[1] : undefined;
}

// The `.md` files under ai-factory/<dir> whose name carries `id` (case-insensitive), sorted.
function holders(root, dirs, id) {
	const found = [];
	for (const dir of dirs)
		for (const name of readNames(root, dir).sort())
			if (name.endsWith(".md") && idOfName(name) === id) found.push(`ai-factory/${dir}/${name}`);
	return found;
}
const kindDirs = (kind) => (kind === "plan" ? ["plans", "plans/done"] : [KINDS[kind]]);

// Validate a reused ID before anything is created; returns it in its written form.
function reusable(kind, raw) {
	if (!Object.hasOwn(PARENTS, kind))
		refuse(`a ${kind} never reuses an ID (--id is for spec, plan and risk)`);
	if (typeof raw !== "string" || !(PREFIXED_ID.test(raw) || RANDOM_ID.test(raw) || LEGACY_ID.test(raw)))
		refuse(`--id '${raw}' is neither an ID like PMB-001 nor a legacy ID such as DHW631 or 0024`);
	if (LEGACY_ID.test(raw) && kind === "spec")
		refuse(`a spec never takes the legacy number ${raw}; let it take the next ID and cite the parent`);
	return normalise(raw);
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

// Create one artefact with the next free ID; returns { id, path } (path repository-relative).
// `beforeReserve(id)` runs after the scan and before the reservation, `beforeOpen(target, id)`
// just before the exclusive create: test seams for the two races.
function create({
	root = ROOT,
	kind,
	slug,
	title,
	id,
	now = () => new Date(),
	beforeReserve,
	beforeOpen,
} = {}) {
	if (!Object.hasOwn(KINDS, kind))
		refuse(
			`unknown kind '${kind}' (expected: ${Object.keys(KINDS).join(", ")})`,
		);
	const reused = id === undefined ? undefined : reusable(kind, id);
	if (kind === "plan" && reused === undefined)
		refuse("a plan reuses its spec's ID (--id <spec ID>); it never takes a new one");
	if (typeof slug !== "string" || !SLUG.test(slug))
		refuse(`slug '${slug}' must match ${SLUG.source}`);
	const heading = titleFrom(slug, title);
	const configured = reused === undefined ? project(root) : undefined;
	if (reused === undefined && !configured) throw unconfigured();
	const ai = path.join(root, "ai-factory");
	const safe = boundary(ai);
	// The template is only read, and in the source repo it is a symlink into skills/.
	const template =
		kind === "adr" ? fs.readFileSync(path.join(root, ADR_TEMPLATE), "utf8") : "";
	const directory = safe.mkdir(path.join(ai, KINDS[kind]));
	const reservations = safe.mkdir(path.join(ai, "runs", "tmp", "ids"));
	if (reused !== undefined)
		return reuse({ root, safe, kind, slug, id: reused, heading, now, beforeOpen, directory, reservations });
	const { prefix } = configured;
	let number = nextNumber(usedIds(root), prefix);
	for (let attempt = 0; attempt < ATTEMPTS; attempt++, number++) {
		const used = usedIds(root);
		number = Math.max(number, nextNumber(used, prefix));
		const taken = format(prefix, number);
		const reservation = path.join(reservations, taken);
		if (beforeReserve) beforeReserve(taken);
		try {
			safe.write(reservation, `${process.pid}\n`, { exclusive: true });
		} catch (error) {
			if (error.code === "EEXIST") continue; // another session holds this number: take the next
			throw error;
		}
		try {
			if (usedIds(root).has(taken)) continue; // created meanwhile: take the next
			const target = path.join(directory, `${taken}-${slug}.md`);
			if (beforeOpen) beforeOpen(target, taken);
			const content = contentFor(kind, taken, heading, now().toISOString(), template);
			try {
				safe.write(target, content, { exclusive: true });
			} catch (error) {
				if (error.code === "EEXIST") continue; // never overwrite: take the next
				throw error;
			}
			return { id: taken, path: relative(root, target) };
		} finally {
			safe.unlink(reservation);
		}
	}
	throw new Error(`no ID could be reserved after ${ATTEMPTS} attempts`);
}

// The kind of each scanned directory; done plans are plans.
const KIND_OF = { ...Object.fromEntries(Object.entries(KINDS).map(([k, d]) => [d, k])), "plans/done": "plan" };
const ARTEFACT = /^(?:([A-Za-z]{2,5}-[0-9]{3,}|[A-Za-z]{3}[0-9]{3})|([0-9]{4}))-.*\.md$/;
// The one valid line 2: the UTC form create() writes.
const CREATED = /^Created: \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{3})?Z\r?$/;

// Why a group of files sharing one ID is not allowed, or undefined when it is.
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
function check({ root = ROOT, warn = (line) => process.stderr.write(`ids.js: ${line}\n`) } = {}) {
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
			const id = match[1] ? normalise(match[1]) : match[2];
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

const USAGE =
	'usage: ids.js init --name "<Project>" [--prefix <ABC>] | ids.js suggest "<Project>" | ids.js new <kind> <slug> [--id <ID>] [--title "<Title>"] | ids.js check';

// Options as { values, positional }; `names` are the options this command takes, each with a value.
function parse(args, names) {
	const positional = [];
	const values = {};
	for (let i = 0; i < args.length; i++) {
		const arg = args[i];
		if (arg.startsWith("-")) {
			const name = arg.slice(2);
			if (!arg.startsWith("--") || !names.includes(name)) refuse(`unknown option '${arg}'`);
			if (i + 1 >= args.length) refuse(`${arg} needs a value`);
			values[name] = args[++i];
		} else positional.push(arg);
	}
	return { values, positional };
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
	if (command === "suggest") {
		if (rest.length !== 1) refuse(USAGE);
		process.stdout.write(`${suggest(rest[0])}\n`);
		return;
	}
	if (command === "init") {
		const { values, positional } = parse(rest, ["name", "prefix"]);
		if (positional.length || values.name === undefined) refuse(USAGE);
		const made = init({ root: ROOT, name: values.name, prefix: values.prefix });
		process.stdout.write(`${made.path}\n`);
		return;
	}
	if (command !== "new") refuse(USAGE);
	const { values, positional } = parse(rest, ["id", "title"]);
	if (positional.length !== 2) refuse(USAGE);
	const made = create({ root: ROOT, kind: positional[0], slug: positional[1], title: values.title, id: values.id });
	process.stdout.write(`${made.path}\n`);
}

if (require.main === module) {
	try {
		main(process.argv.slice(2));
	} catch (error) {
		const message = String(error.message || error).split("\n")[0];
		if (error instanceof Existing) process.stdout.write(`${error.path}\n`);
		process.stderr.write(`ids.js: ${message}\n`);
		process.exitCode =
			error instanceof Existing ? 3 : error instanceof Unconfigured ? 4 : error instanceof Refusal ? 2 : 1;
	}
}

module.exports = { next, create, check, init, project, suggest, normalise };
