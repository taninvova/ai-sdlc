#!/usr/bin/env bash
# Letter-and-digit artefact IDs (spec 0024): pins ai-factory/make/ids.js, the one helper that
# draws an ID and creates an artefact, against disposable fixtures under ai-factory/runs/tmp/.
#
# Groups: draw, new, reuse, check, state, procedures, docs, repo (default: every group).
# Each case reports a missing helper or a missing export as its own failure, never as a crash,
# so the red run of a group names every case it holds.
set -euo pipefail
cd "$(dirname "$0")/../../.."
group="${1:-all}"
case "$group" in
	all | draw | new | reuse | check | state | procedures | docs | repo) ;;
	*) echo "check-ids: unknown group '$group' (expected: draw, new, reuse, check, state, procedures, docs, repo)" >&2; exit 2 ;;
esac
IDS_GROUP="$group" node <<'NODE'
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { spawn, spawnSync } = require("node:child_process");
const { boundary } = require("./skills/ai-layout/templates/ai-factory/make/safe-files.js");

const MAKE = path.resolve("skills/ai-layout/templates/ai-factory/make");
const HELPER = path.join(MAKE, "ids.js");
const ADR_TEMPLATE = path.resolve("skills/ai-layout/templates/ai-factory/adr/0000-template.md");
const FORM = /^[A-HJ-NP-Z]{3}[0-9]{3}$/;
const LETTERS = "ABCDEFGHJKLMNPQRSTUVWXYZ";
const DIRS = { spec: "specs", plan: "plans", exploration: "explorations", analysis: "analyses", design: "designs", adr: "adr", risk: "risks" };
const scratch = boundary(path.resolve("ai-factory")).scratch(path.resolve("ai-factory/runs/tmp"));
const selected = process.env.IDS_GROUP;
const want = (name) => selected === "all" || selected === name;
const failures = [];
let passed = 0;

// The helper, loaded once per case so a missing file or export fails that case alone.
function helper(...exports) {
	if (!fs.existsSync(HELPER)) throw new Error("make/ids.js does not exist");
	const mod = require(HELPER);
	for (const name of exports)
		if (typeof mod[name] !== "function") throw new Error(`make/ids.js exports no ${name}()`);
	return mod;
}
// A random source that replays the given IDs (index draws: three letters, three digits), then
// falls back to fresh randomness so a redraw always terminates.
function forced(...ids) {
	const queue = [];
	for (const id of ids)
		for (const [i, ch] of [...id].entries()) queue.push(i < 3 ? LETTERS.indexOf(ch) : Number(ch));
	for (const value of queue) assert.ok(value >= 0, `forced(): '${ids}' is not drawable`);
	return (n) => (queue.length ? queue.shift() : require("node:crypto").randomInt(n));
}
let fixtures = 0;
function fixture({ dirs = Object.values(DIRS), cli = false, adr = true } = {}) {
	const root = path.join(scratch, `repo-${++fixtures}`);
	fs.mkdirSync(path.join(root, "ai-factory/runs"), { recursive: true });
	for (const dir of dirs) fs.mkdirSync(path.join(root, "ai-factory", dir), { recursive: true });
	if (adr && dirs.includes("adr")) fs.copyFileSync(ADR_TEMPLATE, path.join(root, "ai-factory/adr/0000-template.md"));
	if (cli) {
		fs.mkdirSync(path.join(root, "ai-factory/make"), { recursive: true });
		for (const file of ["ids.js", "safe-files.js"]) fs.copyFileSync(path.join(MAKE, file), path.join(root, "ai-factory/make", file));
	}
	return root;
}
const touch = (root, rel, text = "") => {
	fs.mkdirSync(path.dirname(path.join(root, rel)), { recursive: true });
	fs.writeFileSync(path.join(root, rel), text);
};
const read = (root, rel) => fs.readFileSync(path.join(root, rel), "utf8");
const cli = (root, ...args) =>
	spawnSync(process.execPath, [path.join(root, "ai-factory/make/ids.js"), ...args], { cwd: root, encoding: "utf8" });
// Every artefact file under ai-factory/, the helper's own scratch excluded.
function files(root) {
	const out = [];
	const walk = (dir) => {
		for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
			const file = path.join(dir, entry.name);
			const rel = path.relative(root, file).split(path.sep).join("/");
			if (rel === "ai-factory/runs" || rel === "ai-factory/make") continue;
			if (entry.isDirectory()) walk(file);
			else out.push(rel);
		}
	};
	walk(path.join(root, "ai-factory"));
	return out.sort();
}
const idOf = (rel) => /^([A-Z]{3}[0-9]{3})-/.exec(path.basename(rel))?.[1];
const silent = () => {};

const cases = [];
const test = (group, name, fn) => cases.push({ group, name, fn });

// ---- draw ---------------------------------------------------------------------------------
test("draw", "draw-form", () => {
	const { draw } = helper("draw");
	const root = fixture();
	for (let i = 0; i < 500; i++) {
		const id = draw({ root, warn: silent });
		assert.match(id, FORM, `draw() returned '${id}'`);
	}
});
test("draw", "draw-builtin-deny", () => {
	const ids = helper("draw");
	assert.ok(Array.isArray(ids.BUILTIN_DENY) && ids.BUILTIN_DENY.length > 0, "make/ids.js exports no BUILTIN_DENY list");
	const triple = ids.BUILTIN_DENY.find((t) => [...t].every((ch) => LETTERS.includes(ch)));
	assert.ok(triple, "the built-in denylist has no drawable triple to force");
	const root = fixture();
	assert.equal(ids.draw({ root, random: forced(`${triple}123`, "KLM789"), warn: silent }), "KLM789", `drew the built-in triple ${triple}`);
	for (let i = 0; i < 300; i++) assert.ok(!ids.BUILTIN_DENY.includes(ids.draw({ root, warn: silent }).slice(0, 3)));
});
test("draw", "draw-repo-deny", () => {
	const { draw } = helper("draw");
	const root = fixture();
	touch(root, "ai-factory/ids-deny.txt", "  bcd  \n\tXyZ\n");
	const warnings = [];
	const warn = (line) => warnings.push(line);
	assert.equal(draw({ root, random: forced("BCD123", "XYZ456", "KLM789"), warn }), "KLM789");
	assert.deepEqual(warnings, [], "a valid deny file warns about nothing");
	const bare = fixture();
	assert.equal(draw({ root: bare, random: forced("BCD123"), warn }), "BCD123", "without the file only the built-in list applies");
	assert.deepEqual(warnings, [], "an absent deny file is not an error");
});
test("draw", "deny-hygiene", () => {
	const { draw, create } = helper("draw", "create");
	const root = fixture({ cli: true });
	touch(root, "ai-factory/ids-deny.txt", "\n   \n# a comment\n  # indented comment\nAB\nABCD\nA1C\nbcd\n");
	const warnings = [];
	assert.equal(draw({ root, random: forced("BCD123", "KLM789"), warn: (line) => warnings.push(line) }), "KLM789");
	assert.equal(warnings.length, 3, `expected one warning per bad line:\n${warnings.join("\n")}`);
	for (const [bad, text] of [["AB", warnings[0]], ["ABCD", warnings[1]], ["A1C", warnings[2]]])
		assert.match(text, new RegExp(`'${bad}'`), `the warning names ${bad}: ${text}`);
	const made = create({ root, kind: "spec", slug: "still-made", warn: silent });
	assert.ok(fs.existsSync(path.join(root, made.path)));
	const run = cli(root, "new", "spec", "from-cli");
	assert.equal(run.status, 0, run.stderr);
	for (const bad of ["AB", "ABCD", "A1C"]) assert.match(run.stderr, new RegExp(`'${bad}'`));
	assert.doesNotMatch(run.stderr, /comment/, "comment lines are silent");
	assert.ok(fs.existsSync(path.join(root, run.stdout.trim())), "the file is still created");
});
test("draw", "draw-no-criterion-shape", () => {
	const { draw } = helper("draw");
	const root = fixture();
	assert.equal(draw({ root, random: forced("ACD123", "QCD456", "ACB001", "QCK999", "KLM789"), warn: silent }), "KLM789");
	for (let i = 0; i < 2000; i++) {
		const id = draw({ root, warn: silent });
		assert.ok(!/^(AC|QC)/.test(id) && !/^S[0-9]+$/.test(id) && !/\bAC[0-9]+\b/.test(id) && !/\bQC[0-9]+\b/.test(id), id);
	}
});
test("draw", "draw-random", () => {
	const { draw } = helper("draw");
	const empty = fixture();
	const seen = new Set();
	for (let i = 0; i < 20; i++) seen.add(draw({ root: empty, warn: silent }));
	assert.equal(seen.size, 20, "20 draws over an unchanged tree differ");
	const busy = fixture();
	for (let n = 1; n <= 40; n++) touch(busy, `ai-factory/specs/${String(n).padStart(4, "0")}-legacy-${n}.md`, `# ${n}\n`);
	touch(busy, "ai-factory/plans/9999-highest.md");
	touch(busy, "ai-factory/specs/ZZZ999-newest.md");
	const a = draw({ root: empty, random: forced("MNP345"), warn: silent });
	const b = draw({ root: busy, random: forced("MNP345"), warn: silent });
	assert.equal(a, "MNP345");
	assert.equal(b, a, "the same random source gives the same ID whatever the count or highest number");
});
test("draw", "draw-one-id-space", () => {
	const { draw } = helper("draw");
	const places = [...Object.values(DIRS), "plans/done"];
	for (const place of places) {
		const root = fixture();
		touch(root, `ai-factory/${place}/BCD234-taken.md`);
		assert.equal(draw({ root, random: forced("BCD234", "KLM789"), warn: silent }), "KLM789", `an ID used in ${place}/ is redrawn`);
	}
	const lower = fixture();
	touch(lower, "ai-factory/designs/bcd234-lower.md");
	assert.equal(draw({ root: lower, random: forced("BCD234", "KLM789"), warn: silent }), "KLM789", "IDs compare case-insensitively");
	const sidecar = fixture();
	touch(sidecar, "ai-factory/specs/BCD234-only-sidecar.contract.json", "{}");
	assert.equal(draw({ root: sidecar, random: forced("BCD234", "KLM789"), warn: silent }), "KLM789", "a sidecar name uses its ID");
});

// ---- new ----------------------------------------------------------------------------------
test("new", "new-creates", () => {
	helper("create");
	for (const kind of ["spec", "exploration", "analysis", "design", "adr", "risk"]) {
		// risks/ is absent, as in every repo adopted before spec 0023: the helper creates it.
		const root = fixture({ cli: true, dirs: Object.values(DIRS).filter((d) => d !== "risks") });
		const before = files(root);
		const run = cli(root, "new", kind, "csv-export");
		assert.equal(run.status, 0, `${kind}: ${run.stderr}`);
		const printed = run.stdout.replace(/\n$/, "");
		assert.match(printed, new RegExp(`^ai-factory/${DIRS[kind]}/[A-HJ-NP-Z]{3}[0-9]{3}-csv-export\\.md$`), `${kind} printed '${run.stdout}'`);
		assert.equal(run.stdout, `${printed}\n`, "stdout is exactly the path");
		const added = files(root).filter((f) => !before.includes(f));
		assert.deepEqual(added, [printed], `${kind} creates exactly one file`);
	}
	const root = fixture({ cli: true });
	const run = cli(root, "new", "plan", "csv-export");
	assert.equal(run.status, 2, "a plan never draws a fresh ID");
	assert.deepEqual(files(root), ["ai-factory/adr/0000-template.md"]);
});
test("new", "new-content", () => {
	const { create } = helper("create");
	const root = fixture({ cli: true });
	for (const kind of ["spec", "exploration", "analysis", "design", "risk"]) {
		const before = Date.now();
		const run = cli(root, "new", kind, "two-lines");
		const after = Date.now();
		assert.equal(run.status, 0, run.stderr);
		const rel = run.stdout.trim();
		const match = /^# ([A-Z]{3}[0-9]{3}) — Two lines\nCreated: (\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z)\n$/.exec(read(root, rel));
		assert.ok(match, `${kind}: exactly two lines:\n${read(root, rel)}`);
		assert.equal(match[1], idOf(rel), "the heading carries the file's ID");
		const at = Date.parse(match[2]);
		assert.ok(at >= before - 1000 && at <= after + 1000, `Created: ${match[2]} is the time of creation`);
	}
	const now = () => new Date("2026-10-24T09:08:07.006Z");
	const made = create({ root, kind: "spec", slug: "clocked", now, random: forced("RST567"), warn: silent });
	assert.equal(made.path, "ai-factory/specs/RST567-clocked.md");
	assert.equal(made.id, "RST567");
	assert.equal(read(root, made.path), "# RST567 — Clocked\nCreated: 2026-10-24T09:08:07.006Z\n");
});
test("new", "new-title", () => {
	helper("create");
	const root = fixture({ cli: true });
	let run = cli(root, "new", "spec", "x-y", "--title", "Compact delivery status");
	assert.equal(run.status, 0, run.stderr);
	assert.match(read(root, run.stdout.trim()).split("\n")[0], /^# [A-Z]{3}[0-9]{3} — Compact delivery status$/);
	run = cli(root, "new", "design", "compact-delivery-status");
	assert.equal(run.status, 0, run.stderr);
	assert.match(read(root, run.stdout.trim()).split("\n")[0], /^# [A-Z]{3}[0-9]{3} — Compact delivery status$/);
	const before = files(root);
	for (const args of [
		["spec", "ok-slug", "--title", "two\nlines"],
		["spec", "ok-slug", "--title", "carriage\rreturn"],
		["spec", "Upper"],
		["spec", "under_score"],
		["spec", "-leading"],
		["spec", "double--hyphen"],
		["spec", "trailing-"],
		["spec", "../escape"],
		["spec"],
		["nonsense", "slug"],
		["spec", "ok-slug", "--title"],
		["spec", "ok-slug", "--bogus"],
	]) {
		const refused = cli(root, "new", ...args);
		assert.equal(refused.status, 2, `${JSON.stringify(args)} is refused with exit 2: ${refused.stderr}`);
		assert.equal(refused.stdout, "", "a refusal prints nothing on stdout");
		assert.equal(refused.stderr.trim().split("\n").length, 1, `one line on stderr: ${refused.stderr}`);
	}
	assert.deepEqual(files(root), before, "a refusal creates nothing");
});
test("new", "new-adr-template", () => {
	const { create } = helper("create");
	const template = fs.readFileSync(ADR_TEMPLATE, "utf8");
	const lines = template.split("\n");
	const at = lines.findIndex((line) => line.startsWith("# "));
	assert.ok(at >= 0, "the shipped template has a heading");
	const now = () => new Date("2026-10-24T01:02:03.004Z");
	const expected = (id, title) =>
		[...lines.slice(0, at), `# ${id} — ${title}`, "Created: 2026-10-24T01:02:03.004Z", ...lines.slice(at + 1)].join("\n");
	const root = fixture({ cli: true });
	const made = create({ root, kind: "adr", slug: "use-ids", now, random: forced("TUV678"), warn: silent });
	assert.equal(made.path, "ai-factory/adr/TUV678-use-ids.md");
	assert.equal(read(root, made.path), expected("TUV678", "Use ids"));
	assert.equal(fs.readFileSync(path.join(root, "ai-factory/adr/0000-template.md"), "utf8"), template, "the template is untouched");
	// This repository reads its template through a symlink into skills/; the copy must too.
	const linked = fixture({ cli: true, adr: false });
	fs.symlinkSync(ADR_TEMPLATE, path.join(linked, "ai-factory/adr/0000-template.md"));
	const viaLink = create({ root: linked, kind: "adr", slug: "via-link", title: "Via link", now, random: forced("WXY789"), warn: silent });
	assert.equal(read(linked, viaLink.path), expected("WXY789", "Via link"));
	const run = cli(linked, "new", "adr", "from-cli");
	assert.equal(run.status, 0, run.stderr);
	assert.match(read(linked, run.stdout.trim()), /^# [A-Z]{3}[0-9]{3} — From cli\nCreated: \S+Z\n/);
	const missing = fixture({ cli: true, adr: false });
	assert.notEqual(cli(missing, "new", "adr", "no-template").status, 0, "an ADR without its template fails");
	assert.deepEqual(files(missing), [], "and creates nothing");
});
test("new", "new-exclusive", () => {
	const { create } = helper("create");
	const root = fixture();
	let calls = 0;
	let occupied;
	const beforeOpen = (target) => {
		calls++;
		if (calls === 1) {
			occupied = target;
			fs.writeFileSync(target, "written by another session\n");
		}
	};
	const made = create({ root, kind: "spec", slug: "race", random: forced("BCD234", "KLM789"), beforeOpen, warn: silent });
	assert.ok(occupied, "the pre-open callback ran");
	assert.equal(path.relative(root, occupied).split(path.sep).join("/"), "ai-factory/specs/BCD234-race.md");
	assert.equal(fs.readFileSync(occupied, "utf8"), "written by another session\n", "the file is not overwritten");
	assert.equal(made.path, "ai-factory/specs/KLM789-race.md", "the helper redraws and creates a different file");
	assert.match(read(root, made.path), /^# KLM789 — Race\n/);
	assert.ok(calls >= 2);
});
test("new", "new-parallel", async () => {
	const { create } = helper("create");
	// Deterministic window first: another session creates BCD234 with another slug after this
	// one's draw scanned the tree and before it reserved the ID. The recheck must catch it.
	const window = fixture();
	const replay = forced("BCD234", "KLM789");
	let draws = 0;
	const random = (n) => {
		const value = replay(n);
		if (++draws === 6) touch(window, "ai-factory/specs/BCD234-other-session.md", "# BCD234 — Other session\n");
		return value;
	};
	const won = create({ root: window, kind: "spec", slug: "this-session", random, warn: silent });
	assert.equal(won.path, "ai-factory/specs/KLM789-this-session.md", "an ID used between draw and reservation is redrawn");
	const root = fixture();
	const wrapper = path.join(root, "wrapper.js");
	// Each wrapper waits for the same instant, then creates a spec whose first draw is BCD234.
	fs.writeFileSync(wrapper, `
const { create } = require(${JSON.stringify(HELPER)});
const LETTERS = ${JSON.stringify(LETTERS)};
const queue = [..."BCD234"].map((c, i) => (i < 3 ? LETTERS.indexOf(c) : Number(c)));
const random = (n) => (queue.length ? queue.shift() : require("node:crypto").randomInt(n));
const start = Number(process.argv[2]);
while (Date.now() < start);
const made = create({ root: ${JSON.stringify(root)}, kind: "spec", slug: "session-" + process.argv[3], random, warn: () => {} });
process.stdout.write(made.path);
`);
	const start = Date.now() + 1500;
	const runs = await Promise.all(
		Array.from({ length: 8 }, (_, n) =>
			new Promise((resolve) => {
				const child = spawn(process.execPath, [wrapper, String(start), String(n)], { cwd: root });
				let out = "", err = "";
				child.stdout.on("data", (d) => (out += d));
				child.stderr.on("data", (d) => (err += d));
				child.on("close", (status) => resolve({ status, out, err, n }));
			}),
		),
	);
	for (const r of runs) assert.equal(r.status, 0, `session ${r.n}: ${r.err}`);
	const made = files(root).filter((f) => f.startsWith("ai-factory/specs/"));
	assert.equal(made.length, 8, `eight files:\n${made.join("\n")}`);
	assert.equal(new Set(made.map(idOf)).size, 8, `eight distinct IDs:\n${made.join("\n")}`);
	assert.ok(made.some((f) => idOf(f) === "BCD234"), "one session won the shared first draw");
	for (const r of runs) {
		assert.ok(made.includes(r.out), `session ${r.n} printed its own file '${r.out}'`);
		assert.ok(r.out.endsWith(`-session-${r.n}.md`));
		assert.match(read(root, r.out), new RegExp(`^# ${idOf(r.out)} — Session ${r.n}\\nCreated: \\S+\\n$`), "each heading holds its own ID");
	}
	assert.deepEqual(fs.readdirSync(path.join(root, "ai-factory/runs/tmp/ids")), [], "every reservation is released");
});

// ---- reuse --------------------------------------------------------------------------------
// A reuse never draws: a random source that is called fails the case.
const noDraw = () => {
	throw new Error("a reuse drew a fresh ID");
};
test("reuse", "reuse-permitted-parents", () => {
	helper("create");
	for (const [kind, parent] of [["spec", "explorations"], ["spec", "analyses"], ["plan", "specs"], ["risk", "specs"]]) {
		const root = fixture({ cli: true });
		touch(root, `ai-factory/${parent}/KXT204-parent.md`, "# KXT204 — Parent\n");
		const before = files(root);
		const run = cli(root, "new", kind, "child", "--id", "KXT204");
		assert.equal(run.status, 0, `${kind} from ${parent}: ${run.stderr}`);
		const rel = `ai-factory/${DIRS[kind]}/KXT204-child.md`;
		assert.equal(run.stdout, `${rel}\n`, `${kind} from ${parent} prints its path`);
		assert.deepEqual(files(root).filter((f) => !before.includes(f)), [rel], "exactly one file is created");
		assert.match(read(root, rel), /^# KXT204 — Child\nCreated: \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z\n$/);
	}
	const { create } = helper("create");
	const seam = fixture();
	touch(seam, "ai-factory/specs/KXT204-parent.md");
	const made = create({ root: seam, kind: "plan", slug: "seam", id: "KXT204", random: noDraw, warn: silent });
	assert.deepEqual(made, { id: "KXT204", path: "ai-factory/plans/KXT204-seam.md" });
	// No parent, or only a parent of a kind that does not count: nothing, and the parent is named.
	for (const [kind, present, named] of [
		["spec", null, /exploration or analysis/],
		["spec", "designs", /exploration or analysis/],
		["spec", "plans", /exploration or analysis/],
		["plan", null, /\bspec\b/],
		["plan", "explorations", /\bspec\b/],
		["risk", "analyses", /\bspec\b/],
		["risk", "ai-factory/specs/KXT204-only-sidecar.contract.json", /\bspec\b/],
	]) {
		const root = fixture({ cli: true });
		if (present) touch(root, present.endsWith(".json") ? present : `ai-factory/${present}/KXT204-other.md`, "{}");
		const before = files(root);
		const run = cli(root, "new", kind, "orphan", "--id", "KXT204");
		const label = `${kind} with ${present || "no artefact"}`;
		assert.equal(run.status, 2, `${label} is refused with exit 2: ${run.stderr}`);
		assert.equal(run.stdout, "", `${label} prints nothing on stdout`);
		assert.match(run.stderr, /KXT204/, `${label}: the message names the ID`);
		assert.match(run.stderr, named, `${label}: the message names the missing parent: ${run.stderr}`);
		assert.deepEqual(files(root), before, `${label} creates nothing`);
	}
	// A malformed --id is refused before anything is read.
	for (const bad of ["KX204", "KXT2045", "KXT-204", "", "../KXT204", "001", "00010"]) {
		const root = fixture({ cli: true });
		touch(root, "ai-factory/specs/KXT204-parent.md");
		const run = cli(root, "new", "plan", "bad-id", "--id", bad);
		assert.equal(run.status, 2, `--id '${bad}' is refused: ${run.stderr}`);
		assert.deepEqual(files(root), ["ai-factory/adr/0000-template.md", "ai-factory/specs/KXT204-parent.md"]);
	}
	const flag = cli(fixture({ cli: true }), "new", "plan", "no-value", "--id");
	assert.equal(flag.status, 2, "--id needs a value");
});
test("reuse", "reuse-refused-kinds", () => {
	const { create } = helper("create");
	for (const kind of ["design", "adr", "exploration", "analysis"]) {
		const root = fixture({ cli: true });
		// Every kind holds KXT204, so no missing parent can explain the refusal.
		for (const dir of Object.values(DIRS)) touch(root, `ai-factory/${dir}/KXT204-present.md`);
		const before = files(root);
		const run = cli(root, "new", kind, "again", "--id", "KXT204");
		assert.equal(run.status, 2, `${kind} --id is refused with exit 2: ${run.stderr}`);
		assert.equal(run.stdout, "");
		assert.match(run.stderr, new RegExp(kind), `the refusal names the kind: ${run.stderr}`);
		assert.deepEqual(files(root), before, `${kind} --id creates nothing`);
		assert.throws(() => create({ root, kind, slug: "again", id: "KXT204", random: noDraw, warn: silent }), new RegExp(kind));
		assert.deepEqual(files(root), before);
	}
});
test("reuse", "reuse-one-per-kind", () => {
	helper("create");
	for (const [kind, existing] of [
		["plan", "ai-factory/plans/DHW631-foo.md"],
		["plan", "ai-factory/plans/done/DHW631-foo.md"],
		["risk", "ai-factory/risks/DHW631-foo.md"],
		["spec", "ai-factory/specs/DHW631-foo.md"],
	]) {
		const root = fixture({ cli: true });
		touch(root, "ai-factory/specs/DHW631-foo.md", "# DHW631 — Foo\nthe spec\n");
		touch(root, "ai-factory/explorations/DHW631-foo.md", "# DHW631 — Foo\n");
		const body = "# DHW631 — Foo\nCreated: 2026-01-01T00:00:00.000Z\nhand-written body\n";
		touch(root, existing, body);
		const before = files(root);
		const run = cli(root, "new", kind, "other", "--id", "DHW631");
		assert.equal(run.status, 3, `${kind} with ${existing} exits 3: ${run.stderr}`);
		assert.equal(run.stdout, `${existing}\n`, "the existing file's path is printed");
		assert.equal(run.stderr.trim().split("\n").length, 1, `one line on stderr: ${run.stderr}`);
		assert.match(run.stderr, /DHW631/);
		assert.deepEqual(files(root), before, `no ai-factory/${DIRS[kind]}/DHW631-other.md`);
		assert.equal(read(root, existing), body, "the existing file is unchanged");
		const same = cli(root, "new", kind, "foo", "--id", "dhw631");
		assert.equal(same.status, 3, "the same slug, in any case, is the same answer");
		assert.equal(same.stdout, `${existing}\n`);
		assert.equal(read(root, existing), body);
	}
	// A lowercase existing name is still this kind's file for the ID.
	const lower = fixture({ cli: true });
	touch(lower, "ai-factory/specs/DHW631-foo.md");
	touch(lower, "ai-factory/plans/dhw631-old.md", "old\n");
	const run = cli(lower, "new", "plan", "new-one", "--id", "DHW631");
	assert.equal(run.status, 3, run.stderr);
	assert.equal(run.stdout, "ai-factory/plans/dhw631-old.md\n");
	// A sibling kind's file with the ID is not this kind's file: a plan beside a risk is created.
	const sibling = fixture({ cli: true });
	touch(sibling, "ai-factory/specs/DHW631-foo.md");
	touch(sibling, "ai-factory/risks/DHW631-foo.md");
	const plan = cli(sibling, "new", "plan", "foo", "--id", "DHW631");
	assert.equal(plan.status, 0, plan.stderr);
	assert.equal(plan.stdout, "ai-factory/plans/DHW631-foo.md\n");
});
test("reuse", "reuse-case-insensitive", () => {
	helper("create");
	const root = fixture({ cli: true });
	touch(root, "ai-factory/specs/DHW631-foo.md");
	const run = cli(root, "new", "plan", "foo", "--id", "dhw631");
	assert.equal(run.status, 0, run.stderr);
	assert.equal(run.stdout, "ai-factory/plans/DHW631-foo.md\n", "created in uppercase");
	assert.match(read(root, "ai-factory/plans/DHW631-foo.md"), /^# DHW631 — Foo\n/);
	const risk = cli(root, "new", "risk", "foo", "--id", "DhW631");
	assert.equal(risk.status, 0, risk.stderr);
	assert.equal(risk.stdout, "ai-factory/risks/DHW631-foo.md\n");
	// The parent's own name may be lowercase too.
	const lower = fixture({ cli: true });
	touch(lower, "ai-factory/explorations/kxt204-idea.md");
	const spec = cli(lower, "new", "spec", "idea", "--id", "KXT204");
	assert.equal(spec.status, 0, spec.stderr);
	assert.equal(spec.stdout, "ai-factory/specs/KXT204-idea.md\n");
});
test("reuse", "reuse-legacy-plan", () => {
	helper("create");
	for (const kind of ["plan", "risk"]) {
		const root = fixture({ cli: true });
		touch(root, "ai-factory/specs/0010-t4-state.md", "# 0010 — T4 state\n");
		const run = cli(root, "new", kind, "t4-state", "--id", "0010");
		assert.equal(run.status, 0, `${kind} --id 0010: ${run.stderr}`);
		const rel = `ai-factory/${DIRS[kind]}/0010-t4-state.md`;
		assert.equal(run.stdout, `${rel}\n`);
		assert.match(read(root, rel), /^# 0010 — T4 state\nCreated: \S+Z\n$/);
		const again = cli(root, "new", kind, "other", "--id", "0010");
		assert.equal(again.status, 3, "a legacy plan is one per spec too");
		assert.equal(again.stdout, `${rel}\n`);
	}
	const none = fixture({ cli: true });
	touch(none, "ai-factory/specs/0011-other.md");
	const missing = cli(none, "new", "plan", "orphan", "--id", "0010");
	assert.equal(missing.status, 2, "no legacy spec 0010: refused");
	assert.match(missing.stderr, /0010/);
	assert.match(missing.stderr, /\bspec\b/);
	// A spec never takes a legacy number, even from a legacy exploration (Ambiguity 1, AC23).
	const spec = fixture({ cli: true });
	touch(spec, "ai-factory/explorations/0005-idea.md");
	touch(spec, "ai-factory/analyses/0005-idea.md");
	const refused = cli(spec, "new", "spec", "idea", "--id", "0005");
	assert.equal(refused.status, 2, `spec --id 0005 is refused: ${refused.stderr}`);
	assert.equal(files(spec).filter((f) => f.startsWith("ai-factory/specs/")).length, 0);
});
test("reuse", "reuse-reservation", () => {
	const { create } = helper("create");
	// A stale reservation left by a crash is reclaimed; the reuse succeeds and releases it.
	const root = fixture();
	touch(root, "ai-factory/specs/KXT204-parent.md");
	const stale = path.join(root, "ai-factory/runs/tmp/ids/plan-KXT204");
	touch(root, "ai-factory/runs/tmp/ids/plan-KXT204", "99999\n");
	const old = new Date(Date.now() - 24 * 3600 * 1000);
	fs.utimesSync(stale, old, old);
	const made = create({ root, kind: "plan", slug: "after-crash", id: "KXT204", random: noDraw, warn: silent });
	assert.equal(made.path, "ai-factory/plans/KXT204-after-crash.md");
	assert.ok(!fs.existsSync(stale), "the reclaimed reservation is released");
	// A live reservation held by another session is waited on, then refused: nothing is created.
	const busy = fixture();
	touch(busy, "ai-factory/specs/KXT204-parent.md");
	touch(busy, "ai-factory/runs/tmp/ids/plan-KXT204", "1\n");
	const before = files(busy);
	assert.throws(() => create({ root: busy, kind: "plan", slug: "blocked", id: "KXT204", random: noDraw, warn: silent }), /KXT204/);
	assert.deepEqual(files(busy), before, "a busy reuse creates nothing");
	assert.ok(fs.existsSync(path.join(busy, "ai-factory/runs/tmp/ids/plan-KXT204")), "another session's live reservation is left alone");
	// A reuse holds a kind-scoped key: a fresh draw of the same ID by another kind is not blocked
	// by it, and the plan reservation does not block a risk reuse.
	const both = fixture();
	touch(both, "ai-factory/specs/KXT204-parent.md");
	touch(both, "ai-factory/runs/tmp/ids/plan-KXT204", "1\n");
	assert.equal(create({ root: both, kind: "risk", slug: "beside", id: "KXT204", random: noDraw, warn: silent }).path, "ai-factory/risks/KXT204-beside.md");
});
test("reuse", "reuse-parallel", async () => {
	helper("create");
	for (let round = 0; round < 3; round++) {
		const root = fixture({ cli: true });
		touch(root, "ai-factory/specs/KXT204-parent.md");
		const wrapper = path.join(root, "wrapper.js");
		fs.writeFileSync(wrapper, `
const { spawnSync } = require("node:child_process");
const start = Number(process.argv[2]);
while (Date.now() < start);
const run = spawnSync(process.execPath, [${JSON.stringify(path.join(root, "ai-factory/make/ids.js"))}, "new", "plan", process.argv[3], "--id", "KXT204"], { encoding: "utf8" });
process.stdout.write(JSON.stringify({ status: run.status, out: run.stdout, err: run.stderr }));
`);
		const start = Date.now() + 1000;
		const runs = await Promise.all(
			["slug-a", "slug-b"].map((slug) =>
				new Promise((resolve) => {
					const child = spawn(process.execPath, [wrapper, String(start), slug], { cwd: root });
					let out = "";
					child.stdout.on("data", (d) => (out += d));
					child.on("close", () => resolve({ slug, ...JSON.parse(out || '{"status":null,"out":"","err":"no output"}') }));
				}),
			),
		);
		const plans = files(root).filter((f) => f.startsWith("ai-factory/plans/"));
		assert.equal(plans.length, 1, `round ${round}: exactly one plan:\n${plans.join("\n")}`);
		const winner = runs.find((r) => r.status === 0);
		const loser = runs.find((r) => r !== winner);
		assert.ok(winner, `round ${round}: one run created the plan: ${JSON.stringify(runs)}`);
		assert.equal(winner.out, `${plans[0]}\n`);
		assert.equal(plans[0], `ai-factory/plans/KXT204-${winner.slug}.md`);
		assert.equal(loser.status, 3, `round ${round}: the other exits 3: ${JSON.stringify(loser)}`);
		assert.equal(loser.out, `${plans[0]}\n`, "and prints the winner's path");
		assert.deepEqual(fs.readdirSync(path.join(root, "ai-factory/runs/tmp/ids")), [], "every reservation is released");
	}
});

// ---- check --------------------------------------------------------------------------------
const STAMP = "Created: 2026-10-24T09:08:07.006Z\n";
// A tree of artefacts: every name becomes a dated file unless its body is given.
function tree(entries, options = {}) {
	const root = fixture({ cli: true, adr: false, ...options });
	for (const [rel, body] of Object.entries(entries))
		touch(root, rel, body ?? `# ${idOf(rel) || "x"} — Fixture\n${STAMP}`);
	return root;
}
// `ids.js check` over a fixture: { status, out, err, paths } where paths are the artefact paths
// the output names, sorted and deduplicated.
const named = (text) => [...new Set(text.match(/ai-factory\/[^\s,:;'"()]+\.md/g) || [])].sort();
function checked(root) {
	const run = cli(root, "check");
	return { status: run.status, out: run.stdout, err: run.stderr, paths: named(`${run.stdout}\n${run.stderr}`) };
}
// Run the check and require it to pass, or to fail naming exactly `expected`.
function expectCheck(root, label, expected) {
	const r = checked(root);
	if (!expected) {
		assert.equal(r.status, 0, `${label} passes:\n${r.out}${r.err}`);
		return r;
	}
	assert.equal(r.status, 1, `${label} fails with exit 1:\n${r.out}${r.err}`);
	for (const file of expected) assert.ok(r.paths.includes(file), `${label} names ${file}:\n${r.out}${r.err}`);
	return r;
}
test("check", "check-entry-points", () => {
	helper("check");
	const make = (root) => {
		const env = { ...process.env, MAKEFLAGS: "", MAKEOVERRIDES: "", MFLAGS: "" };
		const run = spawnSync("make", ["-s", "-f", "ai-factory/make/ai.mk", "ids-check"], { cwd: root, env, encoding: "utf8" });
		return { status: run.status, out: run.stdout, err: run.stderr, paths: named(`${run.stdout}\n${run.stderr}`) };
	};
	const withMk = (entries) => {
		const root = tree(entries);
		fs.copyFileSync(path.join(MAKE, "ai.mk"), path.join(root, "ai-factory/make/ai.mk"));
		return root;
	};
	const passing = withMk({ "ai-factory/explorations/KXT204-idea.md": null, "ai-factory/specs/KXT204-idea.md": null, "ai-factory/specs/0001-old.md": "# 0001\n" });
	const failing = withMk({
		"ai-factory/specs/DHW631-a.md": null,
		"ai-factory/specs/DHW631-b.md": null,
		"ai-factory/designs/MRB517-look.md": null,
		"ai-factory/specs/MRB517-look.md": null,
		"ai-factory/specs/0007-x.md": "# 0007\n",
	});
	for (const [label, root, fails] of [["passing", passing, false], ["failing", failing, true]]) {
		const direct = checked(root);
		const viaMake = make(root);
		assert.equal(direct.status, fails ? 1 : 0, `${label}: node ids.js check exit:\n${direct.out}${direct.err}`);
		// GNU make reports any failed recipe as exit 2, so the two agree on pass versus fail.
		assert.equal(viaMake.status === 0, direct.status === 0, `${label}: make ids-check agrees:\n${viaMake.out}${viaMake.err}`);
		assert.deepEqual(viaMake.paths, direct.paths, `${label}: both name the same paths`);
		assert.equal(viaMake.out, direct.out, `${label}: both print the same report`);
	}
	assert.deepEqual(checked(failing).paths, [
		"ai-factory/designs/MRB517-look.md",
		"ai-factory/specs/DHW631-a.md",
		"ai-factory/specs/DHW631-b.md",
		"ai-factory/specs/MRB517-look.md",
	]);
	// The target is declared phony, so a file named ids-check never makes it a no-op.
	assert.match(read(passing, "ai-factory/make/ai.mk"), /^\.PHONY:.*\bids-check\b/m, "ids-check is .PHONY");
	touch(failing, "ids-check");
	assert.notEqual(make(failing).status, 0, "a file named ids-check does not skip the check");
	const extra = cli(passing, "check", "--bogus");
	assert.equal(extra.status, 2, `check takes no arguments: ${extra.stderr}`);
});
test("check", "check-same-kind", () => {
	helper("check");
	for (const [label, a, b] of [
		["two specs", "ai-factory/specs/DHW631-a.md", "ai-factory/specs/DHW631-b.md"],
		["two specs, case apart", "ai-factory/specs/DHW631-a.md", "ai-factory/specs/dhw631-b.md"],
		["active and done plans", "ai-factory/plans/DHW631-a.md", "ai-factory/plans/done/DHW631-b.md"],
		["two active plans", "ai-factory/plans/DHW631-a.md", "ai-factory/plans/DHW631-b.md"],
		["two explorations", "ai-factory/explorations/DHW631-a.md", "ai-factory/explorations/DHW631-b.md"],
		["two analyses", "ai-factory/analyses/DHW631-a.md", "ai-factory/analyses/DHW631-b.md"],
		["two designs", "ai-factory/designs/DHW631-a.md", "ai-factory/designs/DHW631-b.md"],
		["two ADRs", "ai-factory/adr/DHW631-a.md", "ai-factory/adr/DHW631-b.md"],
		["two risks", "ai-factory/risks/DHW631-a.md", "ai-factory/risks/DHW631-b.md"],
	]) {
		const entries = { [a]: null, [b]: null, "ai-factory/specs/KLM789-other.md": null };
		if (/\/(plans|risks)\//.test(a)) entries["ai-factory/specs/DHW631-a.md"] = null;
		const r = expectCheck(tree(entries), label, [a, b]);
		assert.ok(!r.paths.includes("ai-factory/specs/KLM789-other.md"), `${label}: an unrelated file is not named`);
	}
	// Sidecars and other non-Markdown names never count.
	expectCheck(tree({ "ai-factory/specs/DHW631-a.md": null, "ai-factory/specs/DHW631-a.contract.json": "{}", "ai-factory/plans/DHW631-a.contract.json": "{}" }), "a spec and sidecars");
});
test("check", "check-permitted", () => {
	helper("check");
	for (const [label, entries] of [
		["exploration and spec", ["ai-factory/explorations/KXT204-idea.md", "ai-factory/specs/KXT204-idea.md"]],
		["analysis and spec", ["ai-factory/analyses/KXT204-idea.md", "ai-factory/specs/KXT204-idea.md"]],
		["spec and plan", ["ai-factory/specs/KXT204-idea.md", "ai-factory/plans/KXT204-idea.md"]],
		["spec and done plan", ["ai-factory/specs/KXT204-idea.md", "ai-factory/plans/done/KXT204-idea.md"]],
		["spec and risk", ["ai-factory/specs/KXT204-idea.md", "ai-factory/risks/KXT204-idea.md"]],
		["exploration, spec, plan and risk", ["ai-factory/explorations/KXT204-idea.md", "ai-factory/specs/KXT204-idea.md", "ai-factory/plans/KXT204-idea.md", "ai-factory/risks/KXT204-idea.md"]],
		["one of each kind alone", ["ai-factory/designs/DHW631-a.md", "ai-factory/adr/BCD234-a.md", "ai-factory/explorations/EFG345-a.md", "ai-factory/analyses/HJK456-a.md", "ai-factory/specs/LMN567-a.md"]],
		["mixed case", ["ai-factory/explorations/kxt204-idea.md", "ai-factory/specs/KXT204-idea.md", "ai-factory/plans/Kxt204-idea.md"]],
	])
		expectCheck(tree(Object.fromEntries(entries.map((e) => [e, null]))), label);
	// AC22: a spec shares its exploration's ID and cites an analysis with another ID.
	const cited = tree({
		"ai-factory/explorations/KXT204-idea.md": null,
		"ai-factory/analyses/MRB517-idea.md": null,
		"ai-factory/specs/KXT204-idea.md": `# KXT204 — Idea\n${STAMP}\nBuilt on ai-factory/explorations/KXT204-idea.md and ai-factory/analyses/MRB517-idea.md.\n`,
		"ai-factory/plans/KXT204-idea.md": null,
	});
	const r = expectCheck(cited, "exploration KXT204, spec KXT204 citing analysis MRB517");
	assert.equal(r.err, "", `a clean pass warns about nothing: ${r.err}`);
	const empty = fixture({ cli: true, dirs: [], adr: false });
	expectCheck(empty, "a tree with no kind directories");
});
test("check", "check-cross-kind", () => {
	helper("check");
	for (const [label, entries] of [
		["design and spec", ["ai-factory/designs/KXT204-a.md", "ai-factory/specs/KXT204-a.md"]],
		["design and exploration", ["ai-factory/designs/KXT204-a.md", "ai-factory/explorations/KXT204-a.md"]],
		["ADR and plan", ["ai-factory/adr/KXT204-a.md", "ai-factory/plans/KXT204-a.md"]],
		["ADR and design", ["ai-factory/adr/KXT204-a.md", "ai-factory/designs/KXT204-a.md"]],
		["ADR and spec beside a plan", ["ai-factory/adr/KXT204-a.md", "ai-factory/specs/KXT204-a.md", "ai-factory/plans/KXT204-a.md"]],
		["exploration and analysis", ["ai-factory/explorations/KXT204-a.md", "ai-factory/analyses/KXT204-a.md"]],
		["exploration, analysis and spec", ["ai-factory/explorations/KXT204-a.md", "ai-factory/analyses/KXT204-a.md", "ai-factory/specs/KXT204-a.md"]],
		["plan and risk with no spec", ["ai-factory/plans/KXT204-a.md", "ai-factory/risks/KXT204-a.md"]],
		["done plan and risk with no spec", ["ai-factory/plans/done/KXT204-a.md", "ai-factory/risks/KXT204-a.md"]],
		["exploration and plan with no spec", ["ai-factory/explorations/KXT204-a.md", "ai-factory/plans/KXT204-a.md"]],
		["analysis and risk with no spec", ["ai-factory/analyses/KXT204-a.md", "ai-factory/risks/KXT204-a.md"]],
	])
		expectCheck(tree(Object.fromEntries(entries.map((e) => [e, null]))), label, entries);
	// Every clash is reported, not only the first.
	const many = tree({ "ai-factory/designs/KXT204-a.md": null, "ai-factory/specs/KXT204-a.md": null, "ai-factory/explorations/MRB517-a.md": null, "ai-factory/analyses/MRB517-a.md": null });
	expectCheck(many, "two clashes", ["ai-factory/designs/KXT204-a.md", "ai-factory/specs/KXT204-a.md", "ai-factory/explorations/MRB517-a.md", "ai-factory/analyses/MRB517-a.md"]);
});
test("check", "check-legacy", () => {
	helper("check");
	const legacy = "# 0005 — Legacy\n";
	expectCheck(tree({ "ai-factory/specs/0005-a.md": legacy, "ai-factory/specs/0005-b.md": legacy }), "two legacy specs", ["ai-factory/specs/0005-a.md", "ai-factory/specs/0005-b.md"]);
	expectCheck(tree({ "ai-factory/plans/0005-a.md": legacy, "ai-factory/plans/done/0005-b.md": legacy, "ai-factory/specs/0005-a.md": legacy }), "active and done legacy plans", ["ai-factory/plans/0005-a.md", "ai-factory/plans/done/0005-b.md"]);
	const r = expectCheck(
		tree({
			"ai-factory/explorations/0005-a.md": legacy,
			"ai-factory/specs/0005-b.md": legacy,
			"ai-factory/analyses/0005-c.md": legacy,
			"ai-factory/designs/0005-d.md": legacy,
			"ai-factory/adr/0005-e.md": legacy,
			"ai-factory/adr/0000-template.md": "# NNNN — Title\n",
			"ai-factory/specs/0000-scaffold.md": legacy,
			"ai-factory/plans/0005-f.md": legacy,
			"ai-factory/risks/0005-g.md": legacy,
		}),
		"one legacy number across every kind",
	);
	assert.equal(r.err, "", `legacy files are never warned about as undated: ${r.err}`);
	expectCheck(tree({ "ai-factory/adr/0000-template.md": "# x\n", "ai-factory/adr/0000-other.md": "# x\n" }), "two legacy 0000 ADRs", ["ai-factory/adr/0000-template.md", "ai-factory/adr/0000-other.md"]);
});
test("check", "check-undated-warn", () => {
	helper("check");
	const bodies = {
		"ai-factory/specs/BCD234-missing.md": "# BCD234 — Missing\n",
		"ai-factory/specs/CDE345-empty.md": "",
		"ai-factory/plans/BCD234-offset.md": "# BCD234 — Offset\nCreated: 2026-10-24T09:08:07+02:00\n",
		"ai-factory/risks/BCD234-date.md": "# BCD234 — Date only\nCreated: 2026-10-24\n",
		"ai-factory/explorations/DEF456-line3.md": "# DEF456 — Line three\n\nCreated: 2026-10-24T09:08:07.006Z\n",
		"ai-factory/analyses/EFG567-word.md": "# EFG567 — Word\nCreated: yesterday\n",
	};
	const dated = { "ai-factory/specs/FGH678-dated.md": null, "ai-factory/specs/GHJ789-seconds.md": "# GHJ789 — Seconds\nCreated: 2026-10-24T09:08:07Z\nbody\n", "ai-factory/specs/0001-legacy.md": "# 0001\n" };
	const root = tree({ ...bodies, ...dated });
	const r = expectCheck(root, "undated files only");
	for (const rel of Object.keys(bodies)) assert.match(r.err, new RegExp(`${rel.replace(/[.]/g, "\\.")}`), `a warning names ${rel}:\n${r.err}`);
	for (const rel of Object.keys(dated)) assert.ok(!r.err.includes(rel), `${rel} is not warned about:\n${r.err}`);
	assert.equal(r.err.trim().split("\n").length, Object.keys(bodies).length, `one warning per undated file:\n${r.err}`);
	assert.ok(!r.out.includes("BCD234-missing"), "a warning is not a clash");
	// A warning beside a real clash: the clash fails, and the warning is still given.
	const both = tree({ "ai-factory/specs/BCD234-missing.md": "# BCD234\n", "ai-factory/specs/BCD234-twin.md": null });
	const f = expectCheck(both, "undated and clashing", ["ai-factory/specs/BCD234-missing.md", "ai-factory/specs/BCD234-twin.md"]);
	assert.match(f.err, /ai-factory\/specs\/BCD234-missing\.md/);
});

// ---- repo ---------------------------------------------------------------------------------
test("repo", "repo-passes", () => {
	helper("check");
	const entry = path.resolve("ai-factory/make/ids.js");
	assert.ok(fs.existsSync(entry), "this repo has ai-factory/make/ids.js (run sync-self.js)");
	const run = spawnSync(process.execPath, [entry, "check"], { encoding: "utf8" });
	assert.equal(run.status, 0, `this repository's ai-factory/ passes the ID check:\n${run.stdout}${run.stderr}`);
	const env = { ...process.env, MAKEFLAGS: "", MAKEOVERRIDES: "", MFLAGS: "" };
	const viaMake = spawnSync("make", ["-s", "-f", "ai-factory/make/ai.mk", "ids-check"], { env, encoding: "utf8" });
	assert.equal(viaMake.status, 0, `make ids-check passes here too:\n${viaMake.stdout}${viaMake.stderr}`);
	assert.equal(viaMake.stdout, run.stdout, "both entry points print the same report");
});

// ---- state --------------------------------------------------------------------------------
// /t4:state reads both ID forms (AC28–AC31, AC34, AC35). Fixtures are plain directories under the
// scratch root; none of these cases asks --next, so no git history is needed.
const STATE = path.resolve("skills/ai-layout/scripts/state.sh");
const HEADER_ID = "kind\tid\tstate\tpath\tstep\tdetail";
function state(root, ...args) {
	const run = spawnSync("bash", [STATE, root, path.resolve("."), ...args], { encoding: "utf8" });
	assert.equal(run.status, 0, `state.sh ${args.join(" ")} exited ${run.status}:\n${run.stdout}${run.stderr}`);
	return run.stdout;
}
const body = (out) => out.replace(/\n$/, "").split("\n").slice(1);
const row = (...fields) => fields.join("\t");
const planText = (title, spec, steps) => `# ${title}\n\n${spec ? `**Spec:** \`${spec}\`\n\n` : ""}## Steps\n\n${steps.join("\n")}\n`;
function stateTree(entries) {
	const root = fixture({ dirs: ["specs", "plans"] });
	for (const [rel, text] of Object.entries(entries)) touch(root, rel, text);
	return root;
}
// One line, exit 0, no table row: the shape every state refusal owes.
function refusal(root, ...args) {
	const out = state(root, ...args);
	assert.equal(out.trim().split("\n").length, 1, `state.sh ${args.join(" ")} answered in more than one line:\n${out}`);
	assert.ok(!out.includes("\t"), `state.sh ${args.join(" ")} printed a table row:\n${out}`);
	return out.trim();
}
// The legacy tree: a spec with no plan, one paired by its **Spec:** line, one paired by number
// from plans/done/, one paired across mismatched numbers, and a plan with no spec at all.
function legacyTree() {
	return stateTree({
		"ai-factory/specs/0001-no-plan.md": "# 0001 — No plan\n",
		"ai-factory/specs/0002-partly.md": "# 0002 — Partly\n",
		"ai-factory/plans/0002-partly.md": planText("Plan 0002 — Partly", "ai-factory/specs/0002-partly.md", ["- [x] Step 1 — the schema.", "- [~] Step 2 — the ledger exported.", "- [ ] Step 3 — the audit trail."]),
		"ai-factory/specs/0003-done.md": "# 0003 — Done\n",
		"ai-factory/plans/done/0003-done.md": planText("Plan 0003 — Done", null, ["- [x] Step 1 — all of it."]),
		"ai-factory/specs/0040-target.md": "# 0040 — Target\n",
		"ai-factory/plans/0099-mismatch.md": planText("Plan 0099 — Mismatch", "ai-factory/specs/0040-target.md", ["- [ ] Step 1 — the far side."]),
		"ai-factory/plans/0050-orphan.md": planText("Plan 0050 — Orphan", null, ["- [ ] Step 1 — nobody's."]),
	});
}
const LEGACY_PLAN_ROWS = [
	row("plan", "0002", "part-done", "ai-factory/plans/0002-partly.md", "Step 2", "the ledger exported."),
	row("plan", "0002", "not-started", "ai-factory/plans/0002-partly.md", "Step 3", "the audit trail."),
	row("plan", "0050", "not-started", "ai-factory/plans/0050-orphan.md", "Step 1", "nobody's."),
	row("plan", "0099", "not-started", "ai-factory/plans/0099-mismatch.md", "Step 1", "the far side."),
];
const LEGACY_SPEC_ROWS = [
	row("spec", "0001", "not-started", "ai-factory/specs/0001-no-plan.md", "-", "0001 — No plan"),
	row("spec", "0002", "part-done", "ai-factory/specs/0002-partly.md", "-", "0002 — Partly"),
	row("spec", "0040", "part-done", "ai-factory/specs/0040-target.md", "-", "0040 — Target"),
];
const LEGACY_DONE_ROWS = [
	row("plan", "0003", "complete", "ai-factory/plans/done/0003-done.md", "-", "Plan 0003 — Done"),
	row("spec", "0003", "complete", "ai-factory/specs/0003-done.md", "-", "0003 — Done"),
];
test("state", "state-legacy-unchanged", () => {
	const root = legacyTree();
	assert.deepEqual(body(state(root)), [...LEGACY_PLAN_ROWS, ...LEGACY_SPEC_ROWS], "the default listing");
	assert.deepEqual(body(state(root, "--done")), LEGACY_DONE_ROWS, "--done");
	assert.deepEqual(body(state(root, "--specs")), LEGACY_SPEC_ROWS, "--specs");
	assert.deepEqual(body(state(root, "--plans")), LEGACY_PLAN_ROWS, "--plans");
	assert.deepEqual(body(state(root, "--specs", "--done")), LEGACY_DONE_ROWS.filter((r) => r.startsWith("spec")), "--specs --done");
	assert.deepEqual(body(state(root, "--plans", "--done")), LEGACY_DONE_ROWS.filter((r) => r.startsWith("plan")), "--plans --done");
});
test("state", "state-legacy-spec-forms", () => {
	const root = stateTree({
		"ai-factory/specs/0010-t4-state.md": "# 0010 — T4 state\n",
		"ai-factory/plans/0010-t4-state.md": planText("Plan 0010 — T4 state", "ai-factory/specs/0010-t4-state.md", ["- [x] Step 1 — the scan.", "- [ ] Step 2 — the prompt."]),
		"ai-factory/plans/done/0010-earlier.md": planText("Plan 0010 — earlier", "ai-factory/specs/0010-t4-state.md", ["- [x] Step 1 — first pass."]),
		"ai-factory/specs/0011-other.md": "# 0011 — Other\n",
		"ai-factory/plans/0011-other.md": planText("Plan 0011 — Other", "ai-factory/specs/0011-other.md", ["- [ ] Step 1 — elsewhere."]),
	});
	const want = [
		row("plan", "0010", "not-started", "ai-factory/plans/0010-t4-state.md", "Step 2", "the prompt."),
		row("plan", "0010", "complete", "ai-factory/plans/done/0010-earlier.md", "-", "Plan 0010 — earlier"),
		row("spec", "0010", "part-done", "ai-factory/specs/0010-t4-state.md", "-", "0010 — T4 state"),
	];
	for (const spelling of ["0010", "10", "0010-t4-state", "ai-factory/specs/0010-t4-state.md"])
		assert.deepEqual(body(state(root, "--spec", spelling)), want, `--spec ${spelling}`);
});
test("state", "state-spec-case-insensitive", () => {
	const root = stateTree({
		"ai-factory/specs/DHW631-foo.md": "# DHW631 — Foo\nCreated: 2026-10-24T09:08:07.006Z\n",
		"ai-factory/plans/DHW631-foo.md": planText("DHW631 — Foo", "ai-factory/specs/DHW631-foo.md", ["- [x] Step 1 — begun.", "- [ ] Step 2 — the rest."]),
		"ai-factory/specs/KXT204-bar.md": "# KXT204 — Bar\nCreated: 2026-10-24T09:08:07.006Z\n",
		"ai-factory/plans/KXT204-bar.md": planText("KXT204 — Bar", "ai-factory/specs/KXT204-bar.md", ["- [ ] Step 1 — not this one."]),
		"ai-factory/specs/0631-legacy.md": "# 0631 — Legacy\n",
	});
	const want = [
		row("plan", "DHW631", "not-started", "ai-factory/plans/DHW631-foo.md", "Step 2", "the rest."),
		row("spec", "DHW631", "part-done", "ai-factory/specs/DHW631-foo.md", "-", "DHW631 — Foo"),
	];
	for (const spelling of ["DHW631", "dhw631", "DHW631-foo", "dhw631-foo", "ai-factory/specs/DHW631-foo.md"])
		assert.deepEqual(body(state(root, "--spec", spelling)), want, `--spec ${spelling}`);
	assert.deepEqual(body(state(root, "--spec", "dhw631", "--specs")), want.filter((r) => r.startsWith("spec")), "--spec dhw631 --specs");
	// A well-formed ID that names nothing is "no such spec", not "not an ID", and names the ID.
	const none = refusal(root, "--spec", "zzz999");
	assert.match(none, /ZZZ999/, `the answer names the ID it looked for: ${none}`);
	assert.doesNotMatch(none, /is not a spec/, `a well-formed ID is not refused as malformed: ${none}`);
});
test("state", "state-pair-by-id", () => {
	const root = stateTree({
		"ai-factory/specs/DHW631-foo.md": "# DHW631 — Foo\nCreated: 2026-10-24T09:08:07.006Z\n",
		"ai-factory/plans/DHW631-foo.md": planText("DHW631 — Foo", null, ["- [ ] Step 1 — paired by ID."]),
		// The fallback is case-insensitive on both sides, and the id field is written uppercase.
		"ai-factory/specs/kxt204-bar.md": "# KXT204 — Bar\n",
		"ai-factory/plans/done/KXT204-bar.md": planText("KXT204 — Bar", null, ["- [x] Step 1 — finished."]),
		// Shares digits only: a legacy number never pairs with a new-style ID.
		"ai-factory/specs/0631-legacy.md": "# 0631 — Legacy\n",
	});
	assert.deepEqual(body(state(root, "--specs")), [
		row("spec", "0631", "not-started", "ai-factory/specs/0631-legacy.md", "-", "0631 — Legacy"),
		row("spec", "DHW631", "part-done", "ai-factory/specs/DHW631-foo.md", "-", "DHW631 — Foo"),
	]);
	assert.deepEqual(body(state(root, "--specs", "--done")), [row("spec", "KXT204", "complete", "ai-factory/specs/kxt204-bar.md", "-", "KXT204 — Bar")]);
	assert.deepEqual(body(state(root, "--spec", "DHW631")), [
		row("plan", "DHW631", "not-started", "ai-factory/plans/DHW631-foo.md", "Step 1", "paired by ID."),
		row("spec", "DHW631", "part-done", "ai-factory/specs/DHW631-foo.md", "-", "DHW631 — Foo"),
	]);
});
test("state", "state-id-field", () => {
	const root = legacyTree();
	for (const args of [[], ["--done"], ["--next"], ["--specs"], ["--plans"], ["--spec", "2"]]) {
		const header = state(root, ...args).split("\n")[0];
		assert.equal(header, HEADER_ID, `state.sh ${args.join(" ")} prints the id header`);
		assert.ok(!header.split("\t").includes("number"), `no field is named number: ${header}`);
	}
	const prompt = read(path.resolve("."), "commands/state.md");
	assert.match(prompt, /`kind`, `id`, `state`, `path`, `step`, `detail`/, "commands/state.md names the six fields with id second");
	assert.doesNotMatch(prompt, /`number`/, "commands/state.md still names a `number` field");
	for (const rel of ["commands/state.md", "codex-skills/t4-state/SKILL.md"]) {
		const text = read(path.resolve("."), rel);
		assert.match(text, /--spec <id>/, `${rel} describes --spec <id>`);
		assert.doesNotMatch(text, /--spec <number>/, `${rel} still describes --spec <number>`);
	}
});
test("state", "state-usage-messages", () => {
	const root = legacyTree();
	for (const [label, args] of [
		["--spec with no argument", ["--spec"]],
		["--spec followed by a flag", ["--spec", "--done"]],
		["--spec with a word", ["--spec", "weir"]],
		["--spec with a malformed ID", ["--spec", "DH631"]],
		["--spec given twice", ["--spec", "DHW631", "--spec", "0002"]],
	]) {
		const line = refusal(root, ...args);
		assert.match(line, /--spec DHW631\b/, `${label}: the message gives a new-style example: ${line}`);
		assert.doesNotMatch(line, /--spec 0010|spec number/, `${label}: the message still speaks of spec numbers: ${line}`);
	}
	assert.match(refusal(root, "--spec", "weir"), /is not a spec ID/, "a non-ID is named as not a spec ID");
	const unknown = refusal(root, "--jam");
	assert.match(unknown, /--spec <id>/, `the unknown-flag answer describes --spec <id>: ${unknown}`);
	assert.doesNotMatch(unknown, /--spec <number>/, `the unknown-flag answer still says --spec <number>: ${unknown}`);
});

// ---- state: ordering and the --next tie-break (AC36–AC41) ---------------------------------
// A new-style artefact as ids.js writes it: the heading, then `Created:` on line 2 (or a line 2
// that is not a valid one). `created === null` leaves line 2 out entirely.
const dated = (heading, created, rest = "") => `# ${heading}\n${created === null ? "" : `${created}\n`}${rest}`;
const stamp = (iso) => `Created: ${iso}`;
const datedPlan = (heading, created, steps) => dated(heading, created, `\n## Steps\n\n${steps.join("\n")}\n`);
const notStarted = (id, rel, title) => row("spec", id, "not-started", rel, "-", title);
// --next's answer: the one row and the reason line, with the header checked on the way.
function next(root, ...args) {
	const lines = state(root, "--next", ...args).replace(/\n$/, "").split("\n");
	assert.equal(lines.length, 3, `--next answered in ${lines.length} lines, not header, row and reason:\n${lines.join("\n")}`);
	assert.equal(lines[0], HEADER_ID);
	assert.match(lines[2], /^next: /);
	return { row: lines[1], why: lines[2] };
}
test("state", "state-listing-order", () => {
	// Created: order is the reverse of the alphabetical order, so path order cannot pass by luck.
	// GHP505 and MKR202 share an instant written two ways: equal, so the ID decides, and a plain
	// string comparison of the two spellings would put MKR202 first. The undated ABC123 and the
	// malformed ADE111 sort first alphabetically and must still come last.
	const root = stateTree({
		"ai-factory/specs/0007-legacy.md": "# 0007 — Legacy\n",
		"ai-factory/specs/0003-older.md": "# 0003 — Older\n",
		"ai-factory/specs/BTN303-third.md": dated("BTN303 — Third", stamp("2026-03-01T00:00:00.000Z")),
		"ai-factory/specs/MKR202-second.md": dated("MKR202 — Second", stamp("2026-02-01T00:00:00.000Z")),
		"ai-factory/specs/GHP505-second-too.md": dated("GHP505 — Second too", stamp("2026-02-01T00:00:00Z")),
		"ai-factory/specs/ZQB101-first.md": dated("ZQB101 — First", stamp("2026-01-01T00:00:00.000Z")),
		"ai-factory/specs/ABC123-undated.md": dated("ABC123 — Undated", null),
		"ai-factory/specs/ADE111-malformed.md": dated("ADE111 — Malformed", "Created: 2026-01-01"),
		// The plans directory is ordered by the same three bands, on its own, ahead of the specs.
		"ai-factory/plans/0009-legacy.md": planText("Plan 0009 — Legacy", null, ["- [ ] Step 1 — old work."]),
		"ai-factory/plans/YTR321-later.md": datedPlan("YTR321 — Later", stamp("2026-05-01T00:00:00.000Z"), ["- [ ] Step 1 — later.", "- [ ] Step 2 — later still."]),
		"ai-factory/plans/CVB654-sooner.md": datedPlan("CVB654 — Sooner", stamp("2026-04-01T00:00:00.000Z"), ["- [ ] Step 1 — sooner."]),
		"ai-factory/plans/BBB222-undated.md": datedPlan("BBB222 — Undated", null, ["- [ ] Step 1 — whenever."]),
	});
	assert.deepEqual(body(state(root)), [
		row("plan", "0009", "not-started", "ai-factory/plans/0009-legacy.md", "Step 1", "old work."),
		row("plan", "CVB654", "not-started", "ai-factory/plans/CVB654-sooner.md", "Step 1", "sooner."),
		row("plan", "YTR321", "not-started", "ai-factory/plans/YTR321-later.md", "Step 1", "later."),
		row("plan", "YTR321", "not-started", "ai-factory/plans/YTR321-later.md", "Step 2", "later still."),
		row("plan", "BBB222", "not-started", "ai-factory/plans/BBB222-undated.md", "Step 1", "whenever."),
		notStarted("0003", "ai-factory/specs/0003-older.md", "0003 — Older"),
		notStarted("0007", "ai-factory/specs/0007-legacy.md", "0007 — Legacy"),
		notStarted("ZQB101", "ai-factory/specs/ZQB101-first.md", "ZQB101 — First"),
		notStarted("GHP505", "ai-factory/specs/GHP505-second-too.md", "GHP505 — Second too"),
		notStarted("MKR202", "ai-factory/specs/MKR202-second.md", "MKR202 — Second"),
		notStarted("BTN303", "ai-factory/specs/BTN303-third.md", "BTN303 — Third"),
		notStarted("ABC123", "ai-factory/specs/ABC123-undated.md", "ABC123 — Undated"),
		notStarted("ADE111", "ai-factory/specs/ADE111-malformed.md", "ADE111 — Malformed"),
	]);
	// A filter narrows the same ordered rows; it never reorders them.
	assert.deepEqual(body(state(root, "--specs")).map((r) => r.split("\t")[1]), ["0003", "0007", "ZQB101", "GHP505", "MKR202", "BTN303", "ABC123", "ADE111"], "--specs");
});
// A fixture that IS a git root, with commits at pinned instants, for the primary key (AC37).
function gitTree(entries) {
	const root = stateTree({});
	// An inherited hook environment must not point these commands at another repository.
	const { GIT_DIR, GIT_WORK_TREE, GIT_INDEX_FILE, ...clean } = process.env;
	const git = (env, ...args) => {
		const run = spawnSync("git", ["-c", "user.name=t4", "-c", "user.email=t4@example.invalid", "-c", "commit.gpgsign=false", ...args], {
			cwd: root,
			encoding: "utf8",
			env: { ...clean, ...env },
		});
		assert.equal(run.status, 0, `git ${args.join(" ")} failed:\n${run.stderr}`);
	};
	git({}, "init", "-q");
	for (const [rel, { text, at }] of Object.entries(entries)) {
		touch(root, rel, text);
		if (!at) continue;
		git({}, "add", "--", rel);
		git({ GIT_AUTHOR_DATE: at, GIT_COMMITTER_DATE: at }, "commit", "-q", "-m", rel);
	}
	return root;
}
test("state", "next-primary-key", () => {
	// Newest commit wins even though its Created: is the latest and its ID sorts last; the legacy
	// file and the earliest-Created one are older commits and lose on the key alone.
	const committed = {
		"ai-factory/specs/0001-legacy.md": { text: "# 0001 — Legacy\n", at: "2020-01-01T00:00:00Z" },
		"ai-factory/specs/ABC123-earliest.md": { text: dated("ABC123 — Earliest", stamp("2001-01-01T00:00:00.000Z")), at: "2021-01-01T00:00:00Z" },
		"ai-factory/specs/ZQB101-newest.md": { text: dated("ZQB101 — Newest", stamp("2099-01-01T00:00:00.000Z")), at: "2022-01-01T00:00:00Z" },
	};
	const root = gitTree(committed);
	const picked = next(root);
	assert.equal(picked.row, notStarted("ZQB101", "ai-factory/specs/ZQB101-newest.md", "ZQB101 — Newest"));
	assert.match(picked.why, /newest commit date/);
	assert.doesNotMatch(picked.why, /decided/, `the commit date alone settled it: ${picked.why}`);
	// An untracked file sorts newest whatever its Created: line says.
	const withUntracked = gitTree({ ...committed, "ai-factory/specs/MKR202-untracked.md": { text: dated("MKR202 — Untracked", stamp("2101-01-01T00:00:00.000Z")) } });
	const untracked = next(withUntracked);
	assert.equal(untracked.row, notStarted("MKR202", "ai-factory/specs/MKR202-untracked.md", "MKR202 — Untracked"));
	assert.match(untracked.why, /uncommitted or untracked/);
});
// The tie cases run where no artefact has a commit date (a scratch directory that is not a git
// root), so every key is equal and only the tie-break decides.
test("state", "next-tie-new-before-legacy", () => {
	for (const [label, text] of [
		["an undated new-style ID", dated("XYZ789 — New", null)],
		["a dated new-style ID", dated("XYZ789 — New", stamp("2026-01-01T00:00:00.000Z"))],
	]) {
		const root = stateTree({ "ai-factory/specs/0001-legacy.md": "# 0001 — Legacy\n", "ai-factory/specs/XYZ789-new.md": text });
		const picked = next(root);
		assert.equal(picked.row, notStarted("XYZ789", "ai-factory/specs/XYZ789-new.md", "XYZ789 — New"), label);
		assert.match(picked.why, /no commit dates were available/);
		assert.match(picked.why, /letter-and-digit ID .*legacy number decided/, `${label}: the reason names the tie-break: ${picked.why}`);
		assert.doesNotMatch(picked.why, /the lower number/, `${label}: ${picked.why}`);
	}
});
test("state", "next-tie-undated-last", () => {
	for (const [label, line2] of [["no line 2", null], ["a malformed Created:", "Created: 2026-01-01"], ["an offset Created:", "Created: 2026-01-01T00:00:00+00:00"]]) {
		const root = stateTree({
			"ai-factory/specs/ABC123-undated.md": dated("ABC123 — Undated", line2),
			"ai-factory/specs/ZQB101-dated.md": dated("ZQB101 — Dated", stamp("2026-06-01T00:00:00.000Z")),
		});
		const picked = next(root);
		assert.equal(picked.row, notStarted("ZQB101", "ai-factory/specs/ZQB101-dated.md", "ZQB101 — Dated"), label);
		assert.match(picked.why, /valid Created: line .*decided/, `${label}: the reason names the tie-break: ${picked.why}`);
	}
});
test("state", "next-tie-earliest-created", () => {
	for (const [label, early, late] of [
		["different days", "2026-01-01T00:00:00.000Z", "2026-03-01T00:00:00.000Z"],
		// Whole seconds against a fraction: 00Z is earlier than 00.500Z, though it sorts later as text.
		["a whole second against a fraction", "2026-01-01T00:00:00Z", "2026-01-01T00:00:00.500Z"],
	]) {
		const root = stateTree({
			"ai-factory/specs/ABC123-later.md": dated("ABC123 — Later", stamp(late)),
			"ai-factory/specs/ZQB101-earlier.md": dated("ZQB101 — Earlier", stamp(early)),
		});
		const picked = next(root);
		assert.equal(picked.row, notStarted("ZQB101", "ai-factory/specs/ZQB101-earlier.md", "ZQB101 — Earlier"), label);
		assert.match(picked.why, /the earlier Created: date decided/, `${label}: ${picked.why}`);
	}
});
test("state", "next-tie-equal-created", () => {
	for (const [label, first, second] of [
		["the same spelling", "2026-02-01T00:00:00.000Z", "2026-02-01T00:00:00.000Z"],
		["one instant spelt two ways", "2026-02-01T00:00:00Z", "2026-02-01T00:00:00.000Z"],
	]) {
		const root = stateTree({
			"ai-factory/specs/MKR202-second.md": dated("MKR202 — Second", stamp(second)),
			"ai-factory/specs/GHP505-first.md": dated("GHP505 — First", stamp(first)),
		});
		const picked = next(root);
		assert.equal(picked.row, notStarted("GHP505", "ai-factory/specs/GHP505-first.md", "GHP505 — First"), label);
	}
});

// ---- procedures ---------------------------------------------------------------------------
// Static reads of the prompts that create artefacts. They prove what each prompt tells its
// agent; that the agent obeys is proved by the host runs of plan 0024 Step 8, not here.
const TEMPLATES = "skills/ai-layout/templates/ai-factory";
// The procedure, then the adopted copy materialize-agents.js delivers: both must say it.
const agentTexts = (name) =>
	[`agents/${name}.md`, `${TEMPLATES}/agents/${name}.md`].map((rel) => [rel, fs.readFileSync(rel, "utf8")]);
const taskText = (name) => fs.readFileSync(`${TEMPLATES}/tasks/${name}.md`, "utf8");
// Which helper kinds each creating agent and task names.
const CREATORS = { specifier: ["spec"], planner: ["plan"], explorer: ["exploration"], analyst: ["analysis"], architect: ["design", "adr"] };
const TASKS = { spec: "spec", plan: "plan", explore: "exploration", analyse: "analysis", design: "design", adr: "adr" };
const helperCall = (kind) => new RegExp("`node ai-factory/make/ids\\.js new " + kind + " <slug>");
// A prompt that picks the number or the ID itself, in any of the spellings it has used.
const COUNTING = [/next free number/i, /next number/i, /same number as/i, /<NNNN>-/, /\bNNNN-/, /\bNNNN\b/];
// The section of an agent procedure that runs from `heading` to the next heading of its level.
function section(text, heading) {
	const at = text.indexOf(heading);
	assert.ok(at >= 0, `no '${heading}' section`);
	const level = /^#+/.exec(heading)[0];
	const rest = text.slice(at + heading.length);
	const end = rest.search(new RegExp(`\\n${level} `));
	return end < 0 ? rest : rest.slice(0, end);
}

test("procedures", "prompts-call-helper", () => {
	for (const [name, kinds] of Object.entries(CREATORS))
		for (const [rel, text] of agentTexts(name)) {
			const write = section(text, "## What you may write");
			for (const kind of kinds) assert.match(write, helperCall(kind), `${rel}: 'What you may write' calls ids.js new ${kind}`);
			assert.match(write, /the path it prints/, `${rel}: writes into the path the helper printed`);
			assert.match(write, /never pick (a|the) number or (an|the) ID yourself/i, `${rel}: forbids picking a number or an ID`);
			for (const pattern of COUNTING) assert.doesNotMatch(text, pattern, `${rel} still counts (${pattern})`);
		}
	for (const [task, kind] of Object.entries(TASKS)) {
		const rel = `${TEMPLATES}/tasks/${task}.md`;
		const text = taskText(task);
		assert.match(text, helperCall(kind), `${rel} names ids.js new ${kind}`);
		assert.match(text, /the path it prints/, `${rel}: the file is the path the helper printed`);
		for (const pattern of COUNTING) assert.doesNotMatch(text, pattern, `${rel} still counts (${pattern})`);
	}
});
test("procedures", "planner-passes-id", () => {
	const reuse = /`node ai-factory\/make\/ids\.js new plan <slug> --id <spec ID>`/;
	for (const [rel, text] of agentTexts("planner")) {
		const write = section(text, "## What you may write");
		assert.match(write, reuse, `${rel} passes the spec's ID`);
		assert.match(write, /exits? 3[^.]*existing plan[^.]*path/i, `${rel}: on exit 3 it reports the existing plan's path`);
		assert.match(write, /exits? 3[^.]*write nothing/i, `${rel}: on exit 3 it writes nothing`);
		assert.match(write, /four-digit/, `${rel}: a legacy spec passes its four-digit number`);
		// AC19: the plan's spec link is the spec it was created against.
		assert.match(section(text, "## The plan"), /`\*\*Spec:\*\*` line naming the spec's path/, `${rel}: the **Spec:** line names the spec`);
	}
	const task = taskText("plan");
	assert.match(task, reuse, "tasks/plan.md passes the spec's ID");
	assert.match(task, /\*\*Spec:\*\*/, "tasks/plan.md asks for the **Spec:** line");
});
test("procedures", "specifier-parent-rules", () => {
	for (const [rel, text] of agentTexts("specifier")) {
		const write = section(text, "## What you may write");
		const rule = (pattern, what) => assert.match(write, pattern, `${rel}: ${what}`);
		rule(/three letters and three digits/, "says what a new-style ID looks like");
		// AC21: one new-style parent lends its ID.
		rule(/new-style exploration[^.]*`--id <exploration ID>`/, "a new-style exploration lends its ID");
		rule(/new-style analysis[^.]*`--id <analysis ID>`/, "a new-style analysis lends its ID");
		// AC22: both — the exploration's ID, the analysis cited.
		rule(/[Bb]oth[^.]*exploration's ID[^.]*cite the analysis's path/, "with both, the exploration's ID and the analysis cited");
		// AC23: a legacy parent — a fresh draw, the parent cited.
		rule(/four-digit[^.]*no `--id`[^.]*cite (its|the parent's) path/, "a legacy parent: no --id, the parent cited");
		// AC52: exit 3 — draw afresh and carry on, never stop on the existing spec.
		rule(/exits? 3[^.]*again without `--id`/, "on exit 3 it reruns without --id");
		rule(/exits? 3[^]*cite the parent's path[^]*do not stop/, "on exit 3 it cites the parent and does not stop");
		assert.doesNotMatch(write, /exits? 3[^.]*(report|write nothing)/, `${rel}: exit 3 is not a stop for the specifier`);
	}
	const task = taskText("spec");
	assert.match(task, /`--id`/, "tasks/spec.md hands the parent rule on");
});
test("procedures", "agents-keep-header", () => {
	for (const name of Object.keys(CREATORS))
		for (const [rel, text] of agentTexts(name))
			assert.match(
				section(text, "## What you may write"),
				/[Kk]eep the helper's two lines — the `# <ID> — <Title>` heading and the `Created:` line — unchanged, and write[^.]*below them/,
				`${rel} keeps lines 1–2 and writes below them`,
			);
	for (const task of Object.keys(TASKS))
		assert.match(taskText(task), /keep(ing)?\s+its\s+first\s+two\s+lines\s+unchanged/, `tasks/${task}.md keeps the helper's two lines`);
});
test("procedures", "adr-template-no-nnnn", () => {
	const template = fs.readFileSync(ADR_TEMPLATE, "utf8");
	assert.doesNotMatch(template, /NNNN/, "the ADR template shows NNNN");
	const heading = template.split("\n").find((line) => line.startsWith("# "));
	assert.equal(heading, "# <ID> — Title", "the template's heading");
	assert.doesNotMatch(heading, /\{\{/, "the heading carries no {{…}} placeholder");
	for (const [rel, text] of agentTexts("architect")) {
		const adr = section(text, "### adr");
		assert.doesNotMatch(adr, /NNNN/, `${rel}: the ADR procedure shows NNNN`);
		assert.match(adr, /`superseded by <ID>`/, `${rel}: supersession names the new ADR's ID`);
		assert.match(adr, /<ID> is (this|the new) ADR's ID/, `${rel}: says whose ID <ID> is`);
		assert.match(adr, /fill in (its|the) `Date:` line/, `${rel}: fills in Date:`);
	}
	assert.doesNotMatch(taskText("adr"), /NNNN/, "tasks/adr.md shows NNNN");
});
test("procedures", "no-number-counting", () => {
	const roots = ["agents", `${TEMPLATES}/tasks`, `${TEMPLATES}/agents`];
	const targets = [
		...roots.flatMap((dir) => fs.readdirSync(dir).filter((n) => n.endsWith(".md")).map((n) => `${dir}/${n}`)),
		"ai-factory/docs/workflow.md",
	];
	const hits = [];
	for (const rel of targets)
		for (const [i, line] of fs.readFileSync(rel, "utf8").split("\n").entries())
			if (/next free number/i.test(line) || /\bNNNN-/.test(line) || /<NNNN>-/.test(line)) hits.push(`${rel}:${i + 1}`);
	assert.deepEqual(hits, [], `counting or NNNN- paths remain: ${hits.join(", ")}`);
});

// ---- docs: the migration note and the --spec <id> flag (AC51, AC34) ----------------------
// The CHANGELOG's top entry must hold a block for this change (Unreleased or released): its bold heading line
// names the IDs, and the block runs to the next bold heading line or version heading.
function idsChangelogBlock() {
	const text = fs.readFileSync("CHANGELOG.md", "utf8");
	const lines = text.split("\n");
	const versions = lines.flatMap((line, i) => (/^## /.test(line) ? [i] : []));
	assert.ok(versions.length >= 1, "CHANGELOG.md has no version entry");
	const top = lines.slice(versions[0], versions[1] ?? lines.length);
	const start = top.findIndex((line) => /^\*\*[^*]*\bIDs?\b[^*]*\*\*$/.test(line));
	assert.ok(start >= 0, "the CHANGELOG's top entry has no IDs block");
	const rest = top.slice(start + 1);
	const end = rest.findIndex((line) => /^\*\*[^*].*\*\*$/.test(line) && !/^\*\*Breaking/.test(line));
	return [top[start], ...(end < 0 ? rest : rest.slice(0, end))].join("\n");
}
test("docs", "changelog-breaking-note", () => {
	const block = idsChangelogBlock();
	// While unreleased the block says it bumps no version; once released, its version heading carries it.
	if (/^\*\*Unreleased\b/.test(block)) assert.match(block, /no version bump/, "the block bumps no version");
	assert.match(block, /[Bb]reaking for adopted repos/, "marks the change breaking for adopted repos");
	assert.match(block, /`\[A-Z\]\{3\}\[0-9\]\{3\}`/, "describes the ID format as [A-Z]{3}[0-9]{3}");
	assert.match(block, /three letters and three digits/, "describes the ID format in words");
	assert.match(block, /[Ll]egacy files stay valid/, "says legacy files stay valid");
	assert.match(block, /not renamed|never renamed|is renamed/, "says no legacy file is renamed");
	assert.match(block, /`\/t4:state`[^\n]*`number` → `id`/, "describes the /t4:state number → id rename");
	assert.match(block, /`make -f ai-factory\/make\/ai\.mk ids-check`/, "names the ids-check make target");
	assert.match(block, /`ai-factory\/ids-deny\.txt`/, "names the optional ai-factory/ids-deny.txt");
	assert.match(block, /[Oo]ptional `ai-factory\/ids-deny\.txt`/, "says ids-deny.txt is optional");
	assert.match(block, /exits 1[^.]*make reports[^.]*exit 2/, "says make reports ids.js check's exit 1 as 2");
});
test("docs", "docs-spec-id", () => {
	for (const rel of ["README.md", "FACTORY.md", "ai-factory/docs/workflow.md"]) {
		const text = fs.readFileSync(rel, "utf8");
		assert.match(text, /--spec <id>/, `${rel} shows --spec <id>`);
		assert.doesNotMatch(text, /--spec <number>/, `${rel} still shows --spec <number>`);
	}
	for (const rel of ["README.md", "FACTORY.md", "skills/ai-layout/SKILL.md", "ai-factory/docs/architecture.md"]) {
		const text = fs.readFileSync(rel, "utf8");
		assert.match(text, /ids\.js/, `${rel} names ids.js`);
		assert.match(text, /ids-check/, `${rel} names ids-check`);
		assert.match(text, /ids-deny\.txt/, `${rel} names the optional ids-deny.txt`);
	}
});

// ---- groups that later steps of plan 0024 fill (none remain) ------------------------------
const later = {};

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
			failures.push(`${name}: no cases yet (plan 0024 Step ${step} adds them)`);
}
main()
	.catch((error) => failures.push(`harness: ${error.stack}`))
	.finally(() => {
		fs.rmSync(scratch, { recursive: true, force: true });
		for (const line of failures) console.error(`FAIL ${line}`);
		if (failures.length) process.exitCode = 1;
		else console.log(`ids ok — ${passed} cases (${selected})`);
	});
NODE
