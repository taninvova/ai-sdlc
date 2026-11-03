#!/usr/bin/env bash
# Effort rubric and risk-trigger triage (spec ASD-001, plan ASD-001): the shared rubric in the
# explorer, specifier and planner, the explorer's per-option effort and its `Effort and risk`
# subsection, the specifier's `Effort and risk` section and triage, and later the specifier's
# re-run, the planner's step line, the readers of the new spec section and the docs.
#
# Groups: rubric, explorer, specifier, rerun, planner, readers, docs (default: every group).
# Each case reports a missing file or section as its own failure, never as a crash, so the red
# run of a group names every case it holds. A group that a later step of plan ASD-001 fills
# fails with "no cases yet" until that step lands.
#
# These are static reads of the procedures: they prove what each prompt tells its agent. That
# the agent obeys is proved by the host runs of plan ASD-001 Step 7, not here.
set -euo pipefail
cd "$(dirname "$0")/../../.."
group="${1:-all}"
groups="rubric, explorer, specifier, rerun, planner, readers, docs"
case "$group" in
	all | rubric | explorer | specifier | rerun | planner | readers | docs) ;;
	*) echo "check-effort: unknown group '$group' (expected: $groups)" >&2; exit 2 ;;
esac
EFFORT_GROUP="$group" node <<'NODE'
const assert = require("node:assert/strict");
const fs = require("node:fs");

const selected = process.env.EFFORT_GROUP;
const want = (name) => selected === "all" || selected === name;
const failures = [];
let passed = 0;

const cases = [];
const test = (group, name, fn) => cases.push({ group, name, fn });

// The commit before plan ASD-001. Every "unchanged" comparison (AC15, AC31) is made against it,
// never against HEAD, so that committing this delivery does not turn a check into a
// self-comparison that passes whatever the file now says.
// The full SHA, as check-risk.sh's BASELINE: an abbreviation can turn ambiguous as history grows.
const PRE_ASD001 = "1111ef8f0b422bf5d87f0bd9ffc75a554c1a39f5";
function showAt(rev, rel) {
	const { spawnSync } = require("node:child_process");
	const present = spawnSync("git", ["cat-file", "-e", `${rev}^{commit}`], { encoding: "utf8" });
	assert.equal(present.status, 0, `commit ${rev} (the commit before plan ASD-001) is not in this clone; a shallow clone lacks it, so fetch it (git fetch --unshallow) and run again`);
	const shown = spawnSync("git", ["show", `${rev}:${rel}`], { encoding: "utf8" });
	assert.equal(shown.status, 0, `git show ${rev}:${rel} failed: ${(shown.stderr || "").trim()}`);
	return shown.stdout;
}
const TEMPLATE_AGENTS = "skills/ai-layout/templates/ai-factory/agents";
const RUBRIC_AGENTS = ["explorer", "specifier", "planner"];
// Prose wraps at any space, so phrase matches run on the text with whitespace collapsed.
const flatten = (text) => text.replace(/\s+/g, " ");
function read(rel) {
	if (!fs.existsSync(rel)) throw new Error(`${rel} does not exist`);
	return fs.readFileSync(rel, "utf8");
}
// The canonical procedure, then the adopted copy materialize-agents.js delivers.
const agentCopies = (name) => [`agents/${name}.md`, `${TEMPLATE_AGENTS}/${name}.md`].map((rel) => [rel, read(rel)]);
// The section that runs from `heading` (a whole line) to the next heading of its level.
function section(rel, text, heading) {
	const lines = text.split("\n");
	const at = lines.indexOf(heading);
	assert.ok(at >= 0, `${rel} has no '${heading}' section`);
	const level = /^#+ /.exec(heading)[0];
	const end = lines.findIndex((line, i) => i > at && line.startsWith(level));
	return lines.slice(at, end < 0 ? lines.length : end).join("\n");
}
// One item of a numbered list: from `N. **Name**` to the next item or the end of the list.
function item(rel, text, name) {
	const lines = text.split("\n");
	const at = lines.findIndex((line) => new RegExp(`^\\d+\\. \\*\\*${name}\\*\\*`).test(line));
	assert.ok(at >= 0, `${rel} has no '**${name}**' item`);
	const end = lines.findIndex((line, i) => i > at && (/^\d+\. /.test(line) || line.trim() === ""));
	return flatten(lines.slice(at, end < 0 ? lines.length : end).join("\n"));
}

// ---- rubric (plan ASD-001 Step 1: AC1–AC5) ------------------------------------------------
const RUBRIC = "## Effort rubric";
const rubric = (rel, text) => section(rel, text, RUBRIC);
// The rows of a two-column table under a `| <name> |` header, keyed by rating.
function table(rel, text, name) {
	const lines = text.split("\n");
	const at = lines.findIndex((line) => line.startsWith(`| ${name} |`));
	assert.ok(at >= 0, `${rel}: the rubric has no '${name}' table`);
	const rows = {};
	for (const line of lines.slice(at + 2)) {
		if (!line.startsWith("|")) break;
		const [rating, definition] = line.split("|").slice(1, 3).map((cell) => cell.trim());
		rows[rating] = definition;
	}
	assert.deepEqual(Object.keys(rows), ["S", "M", "L", "XL"], `${rel}: the '${name}' table does not rate S, M, L and XL in order`);
	return rows;
}
// Every copy whose rubric differs from the first one's, byte for byte.
function rubricDrift(copies) {
	const [[, first], ...rest] = copies;
	return rest.filter(([, text]) => text !== first).map(([rel]) => rel);
}
const allRubrics = () => RUBRIC_AGENTS.flatMap(agentCopies).map(([rel, text]) => [rel, rubric(rel, text)]);

test("rubric", "rubric-present", () => {
	// AC1: two dimensions, each rated S–XL, and the final effort is the higher of the two.
	for (const name of RUBRIC_AGENTS)
		for (const [rel, text] of agentCopies(name)) {
			const body = rubric(rel, text);
			const flat = flatten(body);
			assert.match(flat, /two dimensions, size and uncertainty/, `${rel}: the rubric does not name its two dimensions`);
			assert.match(flat, /each rated S, M, L or XL/, `${rel}: the rubric does not rate each dimension S, M, L or XL`);
			assert.match(flat, /final effort is the higher of the two/, `${rel}: the rubric does not take the higher of the two`);
			table(rel, body, "Size");
			table(rel, body, "Uncertainty");
		}
});
test("rubric", "rubric-size", () => {
	// AC2.
	const expected = {
		S: "1 file, under 50 lines, no new tests",
		M: "2–5 files, with tests",
		L: "more than 5 files, or a new artefact or check",
		XL: "cross-cutting work, or work that needs an ADR or a migration",
	};
	for (const name of RUBRIC_AGENTS)
		for (const [rel, text] of agentCopies(name))
			assert.deepEqual(table(rel, rubric(rel, text), "Size"), expected, `${rel}: the size dimension`);
});
test("rubric", "rubric-uncertainty", () => {
	// AC3.
	const expected = {
		S: "a known pattern with no unknowns",
		M: "a known pattern with minor unknowns",
		L: "a new pattern or several unknowns",
		XL: "unknowns that need an exploration or a spike",
	};
	for (const name of RUBRIC_AGENTS)
		for (const [rel, text] of agentCopies(name))
			assert.deepEqual(table(rel, rubric(rel, text), "Uncertainty"), expected, `${rel}: the uncertainty dimension`);
});
test("rubric", "rubric-identical", () => {
	// AC4: the six copies (three agents, each canonical and materialized) are byte-equal.
	const copies = allRubrics();
	assert.equal(copies.length, 6, "expected six rubric copies");
	const drift = rubricDrift(copies);
	assert.deepEqual(drift, [], `the rubric differs from ${copies[0][0]}'s in: ${drift.join(", ")}`);
	// The comparator itself: one character changed in any one copy must be caught.
	for (let i = 0; i < copies.length; i++) {
		const mutated = copies.map(([rel, text], j) => {
			if (j !== i) return [rel, text];
			const at = text.indexOf("higher");
			return [rel, `${text.slice(0, at)}H${text.slice(at + 1)}`];
		});
		const caught = rubricDrift(mutated);
		assert.ok(caught.length > 0, `the comparator missed a one-character change in ${copies[i][0]}`);
	}
});
test("rubric", "effort-named", () => {
	// AC5 for the three agents (tasks/plan.md is Step 4's effort-named-plan-task).
	for (const name of RUBRIC_AGENTS)
		for (const [rel, text] of agentCopies(name)) {
			assert.match(text, /\beffort\b/i, `${rel} does not call the rating effort`);
			assert.doesNotMatch(text, /S\/M\/L(?!\/XL)/, `${rel} still says S/M/L without XL`);
		}
});

// ---- explorer (plan ASD-001 Step 1: AC6–AC8) ----------------------------------------------
const EXPLORATION = "## The exploration";
const TRIGGERS = ["uncertain requirements", "authorization", "public contracts", "migrations", "dependencies", "service ownership"];

test("explorer", "explorer-option-effort", () => {
	// AC6: each option's effort is S, M, L or XL, rated against the rubric, with a reason.
	for (const [rel, text] of agentCopies("explorer")) {
		const options = item(rel, section(rel, text, EXPLORATION), "Options");
		assert.match(options, /effort \(S, M, L or XL, rated against the Effort rubric[^)]*, with a reason\)/, `${rel}: an option's effort is not S, M, L or XL against the rubric with a reason`);
	}
});
test("explorer", "explorer-effort-and-risk", () => {
	// AC7: an `Effort and risk` subsection for the recommended option, with its rating, a
	// risk-trigger triage and no time figure.
	for (const [rel, text] of agentCopies("explorer")) {
		const block = item(rel, section(rel, text, EXPLORATION), "Effort and risk");
		assert.match(block, /`### Effort and risk` subsection/, `${rel}: Effort and risk is not a subsection`);
		assert.match(block, /recommended option/, `${rel}: Effort and risk is not about the recommended option`);
		assert.match(block, /its effort \(S, M, L or XL\) against the Effort rubric/, `${rel}: Effort and risk holds no effort rating`);
		assert.match(block, /risk-trigger triage/, `${rel}: Effort and risk holds no risk-trigger triage`);
		for (const trigger of TRIGGERS) assert.ok(block.includes(trigger), `${rel}: the triage does not name the trigger '${trigger}'`);
		assert.match(block, /`present` or `absent`, with one line of evidence each/, `${rel}: the triage does not mark each trigger present or absent with evidence`);
		assert.match(block, /No time figure/, `${rel}: Effort and risk does not forbid a time figure`);
		assert.match(block, /no hours, minutes or dates/, `${rel}: the time-figure prohibition does not name hours, minutes and dates`);
	}
});
test("explorer", "explorer-present-triggers", () => {
	// AC8: a present trigger is named, /fc:risk is recommended once the spec exists, and Open
	// questions say nothing about /fc:risk or the triage.
	for (const [rel, text] of agentCopies("explorer")) {
		const body = section(rel, text, EXPLORATION);
		const block = item(rel, body, "Effort and risk");
		assert.match(block, /When any trigger is `present`, name each present trigger/, `${rel}: present triggers are not named`);
		assert.match(block, /recommend running `\/fc:risk` once the spec exists/, `${rel}: /fc:risk is not recommended once the spec exists`);
		assert.match(block, /add nothing about `\/fc:risk` or the triage to Open questions/, `${rel}: /fc:risk and the triage are not kept out of Open questions`);
		const open = item(rel, body, "Open questions");
		assert.doesNotMatch(open, /\/fc:risk|triage/, `${rel}: the Open questions item mentions /fc:risk or the triage`);
		// The subsection follows the recommendation it belongs to and precedes Open questions.
		const order = ["Recommendation", "Effort and risk", "Open questions"].map((name) => body.indexOf(`**${name}**`));
		assert.ok(order[0] < order[1] && order[1] < order[2], `${rel}: Effort and risk does not sit between Recommendation and Open questions`);
	}
});

// ---- specifier (plan ASD-001 Step 2: AC9–AC15, the section half of AC24) -------------------
const SPEC = "## The spec";
const CATEGORIES = ["authorization", "data exposure", "secrets", "injection", "dependency/supply chain", "migrations", "rollback", "blast radius"];
const RISK_DIR = "ai-factory/risks/";
const SPEC_TASK = "skills/ai-layout/templates/ai-factory/tasks/spec.md";
// One top-level bullet of a list: from `- <name>` to the next top-level bullet or blank line.
function bullet(rel, text, name) {
	const lines = text.split("\n");
	const at = lines.findIndex((line) => line.startsWith(`- ${name}`));
	assert.ok(at >= 0, `${rel} has no '- ${name}' bullet`);
	const end = lines.findIndex((line, i) => i > at && (line.startsWith("- ") || line.trim() === ""));
	return flatten(lines.slice(at, end < 0 ? lines.length : end).join("\n"));
}
// The blocks check-risk.sh riskPassage() splits a procedure into: paragraphs and list items.
const blocks = (text) => text.split(/\n(?=\s*\n|\s*(?:[-*+]|\d+\.) )/).map((block) => block.trim()).filter(Boolean);
// The one block naming ai-factory/risks/ (the risk passage) and the block right after it.
function riskNeighbourhood(rel, text) {
	const all = blocks(text);
	const at = all.map((block, i) => (block.includes(RISK_DIR) ? i : -1)).filter((i) => i >= 0);
	assert.equal(at.length, 1, `${rel} names ${RISK_DIR} in ${at.length} blocks; the risk passage must stay one block`);
	return { passage: all[at[0]], next: all[at[0] + 1] ?? "" };
}
// The triage: the block right after the risk passage, opened by "Triage".
function triage(rel, text) {
	const { next } = riskNeighbourhood(rel, text);
	assert.ok(next.startsWith("Triage "), `${rel}: the block after the risk passage is not the triage`);
	return flatten(next);
}

test("specifier", "spec-section", () => {
	// AC9: an `Effort and risk` section immediately before Open questions, one rating for the
	// feature, and dev-hours and /fc:run ranges, each labelled as an assumption.
	for (const [rel, text] of agentCopies("specifier")) {
		const body = section(rel, text, SPEC);
		const effort = bullet(rel, body, "Effort and risk");
		assert.match(effort, /`## Effort and risk` section, placed immediately before Open questions/, `${rel}: Effort and risk is not a section placed immediately before Open questions`);
		const order = ["- Effort and risk", "- Open questions"].map((name) => body.indexOf(`\n${name}`));
		assert.ok(order[0] >= 0 && order[0] < order[1], `${rel}: the Effort and risk bullet does not precede Open questions`);
		assert.doesNotMatch(body.slice(order[0] + 1, order[1]), /\n- /, `${rel}: another section sits between Effort and risk and Open questions`);
		assert.match(effort, /one effort rating \(S, M, L or XL\) for the whole feature against the Effort rubric/, `${rel}: no single feature effort rating against the rubric`);
		assert.match(effort, /never one per acceptance criterion/, `${rel}: the rating is not kept to one for the feature`);
		assert.match(effort, /developer hours/, `${rel}: no developer-hours range`);
		assert.match(effort, /`\/fc:run` time/, `${rel}: no /fc:run time range`);
		assert.match(effort, /each a range labelled as an assumption/, `${rel}: the time figures are not ranges labelled as assumptions`);
		assert.match(effort, /`dev <low>–<high> h \(assumption: <what it rests on>\)`/, `${rel}: no labelled dev-hours range form`);
		assert.match(effort, /`\/fc:run ~<low>–<high> min \(assumption: <what it rests on>\)`/, `${rel}: no labelled /fc:run range form`);
		assert.match(effort, /never a date/, `${rel}: the time range is not kept from becoming a date`);
	}
});
test("specifier", "spec-range-independent", () => {
	// AC10.
	for (const [rel, text] of agentCopies("specifier"))
		assert.match(bullet(rel, section(rel, text, SPEC), "Effort and risk"), /independent estimate of the feature, not a sum of plan steps/, `${rel}: the range is not an independent estimate`);
});
test("specifier", "spec-triage-items", () => {
	// AC11: all eight categories and six start triggers, present/absent, one line of evidence.
	for (const [rel, text] of agentCopies("specifier")) {
		const block = triage(rel, text);
		const categories = /eight risk categories \(([^)]*)\)/.exec(block);
		assert.ok(categories, `${rel}: the triage does not list the eight risk categories`);
		for (const name of CATEGORIES) assert.ok(categories[1].includes(name), `${rel}: the triage does not name the category '${name}'`);
		const triggers = /`\/fc:start` risk trigger \(([^)]*)\)/.exec(block);
		assert.ok(triggers, `${rel}: the triage does not list the /fc:start risk triggers`);
		for (const name of TRIGGERS) assert.ok(triggers[1].includes(name), `${rel}: the triage does not name the trigger '${name}'`);
		assert.match(block, /`present` or `absent`, with one line of evidence each/, `${rel}: the triage does not mark each item present or absent with evidence`);
		assert.match(block, /starts with the item's name, never with an AC ID/, `${rel}: an evidence line may start with an AC ID (plan Ambiguity 8)`);
		assert.match(block, /`Effort and risk` section/, `${rel}: the triage is not placed in the Effort and risk section`);
	}
});
test("specifier", "spec-triage-no-severity", () => {
	// AC12.
	for (const [rel, text] of agentCopies("specifier"))
		assert.match(triage(rel, text), /carries no severity, no status and no mitigation/, `${rel}: the triage may carry a severity, status or mitigation`);
});
test("specifier", "spec-run-risk-question", () => {
	// AC13: the exact open question, only with a present item and no risk file.
	for (const [rel, text] of agentCopies("specifier"))
		assert.match(triage(rel, text), /When any item is `present` and no risk file the rule above names exists, Open questions contain "Run `\/fc:risk <spec path>`"/, `${rel}: no conditional "Run \`/fc:risk <spec path>\`" open question`);
});
test("specifier", "spec-no-run-risk-when-absent", () => {
	// AC14.
	for (const [rel, text] of agentCopies("specifier"))
		assert.match(triage(rel, text), /When every item is `absent`, Open questions contain no "Run `\/fc:risk`" line/, `${rel}: an all-absent triage may still ask to run /fc:risk`);
});
test("specifier", "spec-triage-beside-risk-rule", () => {
	// AC15: the triage is the block right after the risk passage, names no ai-factory/risks/ of
	// its own, and the risk passage is byte-identical to the one before this delivery.
	for (const [rel, text] of agentCopies("specifier")) {
		const { passage, next } = riskNeighbourhood(rel, text);
		assert.ok(next.startsWith("Triage "), `${rel}: the block after the risk passage is not the triage`);
		assert.ok(!next.includes(RISK_DIR), `${rel}: the triage repeats ${RISK_DIR}`);
		const before = riskNeighbourhood(`${PRE_ASD001}:${rel}`, showAt(PRE_ASD001, rel)).passage;
		assert.equal(passage, before, `${rel}: the risk passage differs from ${PRE_ASD001}'s`);
		// The control: one word changed in the passage must be caught by the same comparison.
		const changed = text.replace(passage, passage.replace("No applicable assessment", "No relevant assessment"));
		assert.notEqual(changed, text, `${rel}: the control could not change the risk passage`);
		assert.notEqual(riskNeighbourhood(rel, changed).passage, before, `${rel}: the control: a changed risk passage still equals ${PRE_ASD001}'s`);
	}
});
test("specifier", "spec-task-names-section", () => {
	// AC24, first half: the delegation instruction names `Effort and risk` among the sections,
	// before open questions.
	const text = read(SPEC_TASK);
	const delegation = flatten(text.split("\n\n").find((block) => block.startsWith("Delegate to the `specifier` subagent")) || "");
	assert.ok(delegation, `${SPEC_TASK} has no delegation instruction`);
	assert.match(delegation, /out of scope, an `Effort and risk` section[^.;]*, open questions/, `${SPEC_TASK}: the delegation does not name the Effort and risk section before open questions`);
});

// ---- rerun (plan ASD-001 Step 3: AC16–AC23, the re-run half of AC24) -----------------------
// Each case asserts the procedure's wording first, so a red run fails on the missing rule, and
// then the fixture it rests on (AC23): skills/ai-layout/fixtures/effort/rerun/cases.json.
const RERUN = "## Re-run on an existing spec";
const WRITE = "## What you may write";
const RERUN_FIXTURES = "skills/ai-layout/fixtures/effort/rerun";
const RUN_RISK_LINE = /^- Run `\/fc:risk [^`]*`$/;
const rerunSection = (rel, text) => flatten(section(rel, text, RERUN));
// The exit-3 bullet of `What you may write`.
const exit3 = (rel, text) => bullet(rel, section(rel, text, WRITE), "When the helper exits 3");
function rerunCases() {
	const doc = JSON.parse(read(`${RERUN_FIXTURES}/cases.json`));
	const fixture = (name) => (name ? read(`${RERUN_FIXTURES}/${name}`) : null);
	return {
		...doc,
		cases: doc.cases.map((c) => ({ ...c, specText: fixture(c.spec), riskText: fixture(c.risk), expectedText: fixture(c.expected) })),
	};
}
const rerunCase = (name) => {
	const doc = rerunCases();
	const found = doc.cases.find((c) => c.name === name);
	assert.ok(found, `${RERUN_FIXTURES}/cases.json has no '${name}' case`);
	return { doc, c: found };
};
// A request names the spec only when it carries the spec's path.
const names = (request, specPath) => request.includes(specPath);
// Every spec path a request carries, whatever it carries it for.
const specPaths = (request) => request.match(/ai-factory\/specs\/[\w.-]+\.md/g) || [];
// The re-run rule the fixtures model (review fix 1): a named spec is revised only when the
// request asks to revise or re-run it, or it is the spec the helper's exit 3 reports as holding
// the parent's ID. A spec path cited only as context makes no re-run.
const escapeRe = (text) => text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
const asksToRevise = (request, specPath) => new RegExp(`\\b(?:[Rr]evise|[Rr]e-run)\\s+${escapeRe(specPath)}`).test(request);
const isRerun = (c) => specPaths(c.request).some((p) => asksToRevise(c.request, p) || (c.helper_exit === 3 && c.helper_path === p));
// The Open questions section's lines, and the spec with that section's body cut out.
function openQuestions(rel, text) {
	const body = section(rel, text, "## Open questions");
	return { lines: body.split("\n").slice(1).filter((line) => line.startsWith("- ")), outside: text.replace(body, "## Open questions") };
}
// The risk file's latest section (the last `## Reassessment`, else the body above the first),
// and the ids of its `open` findings of severity `blocker` or `major`.
function latestOpenSevere(riskText) {
	const parts = riskText.split(/^(?=## Reassessment )/m);
	const latest = parts[parts.length - 1];
	const rows = latest.split("\n").filter((line) => /^\| R\d+ \|/.test(line)).map((line) => line.split("|").slice(1, -1).map((cell) => cell.trim()));
	assert.ok(rows.length > 0, "the risk fixture's latest section has no findings");
	return { all: rows.map(([id]) => id), picked: rows.filter(([, , severity, status]) => status === "open" && ["blocker", "major"].includes(severity)).map(([id]) => id) };
}

test("rerun", "rerun-only-when-named", () => {
	// AC16: exit 3 makes a re-run only when the request names the spec's path; otherwise the
	// helper runs again without --id, takes the next free ID and the parent is cited.
	for (const [rel, text] of agentCopies("specifier")) {
		const rule = exit3(rel, text);
		assert.match(rule, /re-run only when the request names the existing spec's path/, `${rel}: exit 3 does not say a re-run needs the spec's path in the request`);
		assert.match(rule, /Otherwise exit 3 keeps today's behaviour: run the helper again without `--id`, take the next free ID and cite the parent's path/, `${rel}: exit 3 without a named spec path does not keep today's behaviour`);
		assert.match(rerunSection(rel, text), /A run is a re-run only when the request names an existing spec's path/, `${rel}: the re-run section does not say when a run is a re-run`);
	}
	const doc = rerunCases();
	for (const c of doc.cases)
		assert.equal(isRerun(c), c.outcome !== "new-id", `fixture ${c.name}: whether the request revises a named spec does not match its outcome`);
});
test("rerun", "rerun-cited-spec-new-id", () => {
	// Review fix 1: naming a spec's path is not enough. A run is a re-run only when the named spec
	// is the one being revised; a spec path cited as context still gets a new spec, by the exit-3
	// rule.
	for (const [rel, text] of agentCopies("specifier")) {
		const rule = exit3(rel, text);
		assert.match(rule, /re-run only when the request names the existing spec's path and that spec is the one being revised/, `${rel}: exit 3 makes any named spec path a re-run`);
		assert.match(rule, /When the printed path is the spec the request names, this run is a re-run of it/, `${rel}: exit 3 does not say when the spec holding the parent's ID is the one being revised`);
		assert.match(rule, /A spec path the request cites only as context, for another spec, never makes a re-run/, `${rel}: exit 3 may treat a spec cited as context as a re-run`);
		const body = rerunSection(rel, text);
		assert.match(body, /A run is a re-run only when the request names an existing spec's path and that spec is the one being revised: the request asks to revise or re-run that spec, or that spec holds the ID the helper reports as taken \(exit 3 for the parent's ID/, `${rel}: the re-run section makes any named spec path a re-run`);
		assert.match(body, /A spec path the request cites only as context[^.]*never makes a re-run: write a new spec, and when the helper exits 3, follow the exit-3 rule under What you may write/, `${rel}: the re-run section may revise a spec cited as context`);
	}
	const text = flatten(read(SPEC_TASK));
	assert.match(text, /A run is a re-run only when the argument names an existing spec's path and that spec is the one being revised: the argument asks to revise or re-run that spec, or it is the spec that already holds the parent's ID/, `${SPEC_TASK}: any named spec path makes a re-run`);
	assert.match(text, /A spec path cited only as context makes no re-run/, `${SPEC_TASK}: a spec cited as context may make a re-run`);
	const { doc, c } = rerunCase("cites-other-spec-new-id");
	const cited = specPaths(c.request);
	assert.ok(cited.length > 0 && !cited.includes(doc.spec_path), `fixture ${c.name}: the request must cite another spec's path, not ${doc.spec_path}`);
	assert.ok(!cited.some((p) => asksToRevise(c.request, p)), `fixture ${c.name}: the request asks to revise the spec it cites`);
	assert.equal(c.helper_exit, 3, `fixture ${c.name}: the helper must exit 3`);
	assert.equal(c.helper_path, doc.spec_path, `fixture ${c.name}: the helper must report ${doc.spec_path} as holding the parent's ID`);
	assert.equal(c.outcome, "new-id", `fixture ${c.name}: a spec cited as context must lead to a new ID`);
	// The control: under the old rule (any spec path named) this request would be a re-run.
	assert.ok(cited.length > 0 && !isRerun(c), `fixture ${c.name}: the model does not tell context from revision`);
});
test("rerun", "rerun-unnamed-new-id", () => {
	// AC17: no spec path in the request, exit 3 → a new spec under the next free ID; the
	// existing one stays unchanged.
	for (const [rel, text] of agentCopies("specifier"))
		assert.match(exit3(rel, text), /take the next free ID[^]*The existing spec stays unchanged/, `${rel}: exit 3 without a named spec does not leave the existing spec unchanged`);
	const { doc, c } = rerunCase("unnamed-new-id");
	assert.equal(c.helper_exit, 3, "fixture unnamed-new-id: the helper must exit 3");
	assert.ok(!names(c.request, doc.spec_path), "fixture unnamed-new-id: the request names the spec");
	assert.match(c.specText, /^# ASD-901 — /, "fixture unnamed-new-id: the existing spec does not hold the parent's ID");
});
test("rerun", "rerun-no-risk-file-unchanged", () => {
	// AC18: named, no risk file → byte-for-byte unchanged, no new spec, report /fc:risk.
	for (const [rel, text] of agentCopies("specifier")) {
		const body = rerunSection(rel, text);
		assert.match(body, /does not run the ID helper/, `${rel}: a re-run may still run the ID helper`);
		// Review fix 2: the /fc:risk report applies only when the Run /fc:risk line is there.
		assert.match(body, /No such risk file and Open questions contain "Run `\/fc:risk <spec path>`": leave the spec byte-for-byte unchanged and create no new spec\. Report that `\/fc:risk <spec path>` still has to be run/, `${rel}: a re-run without a risk file reports /fc:risk whether or not the spec asks for it`);
	}
	const { doc, c } = rerunCase("named-no-risk-file");
	assert.ok(names(c.request, doc.spec_path) && c.risk === null && c.outcome === "unchanged", "fixture named-no-risk-file: a named spec with no risk file must stay unchanged");
	assert.ok(openQuestions(c.spec, c.specText).lines.some((line) => RUN_RISK_LINE.test(line)), "fixture named-no-risk-file: the spec has no Run /fc:risk line to keep");
	assert.equal(c.report, "run-risk", "fixture named-no-risk-file: the report must say /fc:risk still has to be run");
});
test("rerun", "rerun-no-risk-file-nothing-to-revise", () => {
	// Review fix 2: named, no risk file and no Run /fc:risk line (an all-absent triage) →
	// unchanged, and the report says there is nothing to revise, never that /fc:risk is due.
	for (const [rel, text] of agentCopies("specifier"))
		assert.match(rerunSection(rel, text), /No such risk file and Open questions hold no "Run `\/fc:risk`" line[^:]*: leave the spec byte-for-byte unchanged, create no new spec and report that there is nothing to revise/, `${rel}: a re-run without a risk file or a Run /fc:risk line does not report that there is nothing to revise`);
	const { doc, c } = rerunCase("named-no-risk-file-all-absent");
	assert.ok(names(c.request, doc.spec_path) && c.risk === null && c.outcome === "unchanged", `fixture ${c.name}: a named spec with no risk file must stay unchanged`);
	assert.ok(!openQuestions(c.spec, c.specText).lines.some((line) => RUN_RISK_LINE.test(line)), `fixture ${c.name}: the spec has a Run /fc:risk line`);
	const triage = section(c.spec, c.specText, "## Effort and risk").split("\n").filter((line) => /^- [^:]+: (present|absent) — /.test(line));
	assert.equal(triage.length, 12, `fixture ${c.name}: the triage does not mark all twelve items`);
	assert.ok(triage.every((line) => /: absent — /.test(line)), `fixture ${c.name}: the triage is not all absent`);
	assert.equal(c.report, "nothing-to-revise", `fixture ${c.name}: the report must say there is nothing to revise`);
	// Every unchanged case's report follows from its spec and risk file.
	for (const u of rerunCases().cases.filter((u) => u.outcome === "unchanged")) {
		const due = u.risk === null && openQuestions(u.spec, u.specText).lines.some((line) => RUN_RISK_LINE.test(line));
		assert.equal(u.report, due ? "run-risk" : "nothing-to-revise", `fixture ${u.name}: the report does not follow from its spec and risk file`);
	}
});
test("rerun", "rerun-removes-line", () => {
	// AC19: named, a risk file and a Run /fc:risk line → edited in place, the line removed.
	for (const [rel, text] of agentCopies("specifier"))
		assert.match(rerunSection(rel, text), /A risk file exists and Open questions contain "Run `\/fc:risk <spec path>`": edit that spec in place and create no new spec\. Remove the "Run `\/fc:risk`" line/, `${rel}: a re-run with a risk file does not remove the Run /fc:risk line in place`);
	for (const c of rerunCases().cases.filter((c) => c.outcome === "revised")) {
		assert.ok(openQuestions(c.spec, c.specText).lines.some((line) => RUN_RISK_LINE.test(line)), `fixture ${c.name}: the spec has no Run /fc:risk line`);
		assert.ok(!openQuestions(c.expected, c.expectedText).lines.some((line) => RUN_RISK_LINE.test(line)), `fixture ${c.name}: the revised spec keeps the Run /fc:risk line`);
		assert.equal(c.expectedText.split("\n")[0], c.specText.split("\n")[0], `fixture ${c.name}: the revised spec is a different spec`);
	}
	// Ambiguity 5: a risk file but no line to remove leaves the spec unchanged.
	for (const [rel, text] of agentCopies("specifier"))
		assert.match(rerunSection(rel, text), /A risk file exists but Open questions hold no "Run `\/fc:risk`" line: leave the spec unchanged/, `${rel}: a re-run with nothing to revise may change the spec`);
	const { c } = rerunCase("named-no-run-risk-line");
	assert.ok(c.risk && !openQuestions(c.spec, c.specText).lines.some((line) => RUN_RISK_LINE.test(line)), "fixture named-no-run-risk-line: needs a risk file and no Run /fc:risk line");
});
test("rerun", "rerun-adds-open-findings", () => {
	// AC20: only the latest section's open blocker/major findings are added, with the risk
	// file's path; mitigated, accepted and minor ones are not.
	for (const [rel, text] of agentCopies("specifier")) {
		const body = rerunSection(rel, text);
		assert.match(body, /Add to Open questions each `open` finding of severity `blocker` or `major` from the risk file's latest `## Reassessment` section, or from the body above the first one when it has none/, `${rel}: the re-run does not add the latest section's open blocker and major findings`);
		assert.match(body, /citing the risk file's path/, `${rel}: the re-run does not cite the risk file's path`);
		assert.match(body, /A finding that is `mitigated`, `accepted` or `minor` is not added/, `${rel}: the re-run may add mitigated, accepted or minor findings`);
		assert.ok(!body.includes(RISK_DIR), `${rel}: the re-run section repeats ${RISK_DIR}, splitting the risk passage`);
	}
	const doc = rerunCases();
	const { cases } = doc;
	const revised = cases.filter((c) => c.outcome === "revised");
	assert.ok(revised.some((c) => /^## Reassessment /m.test(c.riskText)) && revised.some((c) => !/^## Reassessment /m.test(c.riskText)), "the fixtures must cover a risk file with and without a Reassessment");
	for (const c of revised) {
		const { all, picked } = latestOpenSevere(c.riskText);
		assert.deepEqual(picked, c.added, `fixture ${c.name}: 'added' is not the latest section's open blocker/major findings`);
		const before = new Set(openQuestions(c.spec, c.specText).lines);
		const added = openQuestions(c.expected, c.expectedText).lines.filter((line) => !before.has(line));
		const named = (id) => added.some((line) => new RegExp(`\\b${id}\\b`).test(line));
		for (const id of picked) assert.ok(named(id), `fixture ${c.name}: ${id} is not added to Open questions`);
		for (const id of all.filter((id) => !picked.includes(id))) assert.ok(!named(id), `fixture ${c.name}: ${id} is added although it is not an open blocker or major`);
		// Earlier sections hold ids that were open there: the latest section alone decides.
		for (const line of added) assert.ok(line.includes(doc.risk_path), `fixture ${c.name}: an added finding does not cite ${doc.risk_path}`);
	}
	const reassessed = revised.find((c) => /^## Reassessment /m.test(c.riskText));
	const initial = latestOpenSevere(reassessed.riskText.split(/^(?=## Reassessment )/m)[0]).picked;
	assert.notDeepEqual(initial, reassessed.added, `fixture ${reassessed.name}: the initial body picks the same findings, so it cannot tell the latest section apart`);
});
test("rerun", "rerun-rest-unchanged", () => {
	// AC21: only the Run /fc:risk line and the added findings change; heading, Created: line,
	// triage and every other open question stay byte-for-byte.
	for (const [rel, text] of agentCopies("specifier")) {
		const body = rerunSection(rel, text);
		assert.match(body, /Everything else stays byte-for-byte unchanged: the heading and the `Created:` line/, `${rel}: the re-run does not keep the rest of the spec byte-for-byte`);
		assert.match(body, /the `Effort and risk` section and its triage, which a re-run never re-evaluates/, `${rel}: the re-run may re-evaluate the triage`);
		assert.match(body, /every other open question/, `${rel}: the re-run may change other open questions`);
	}
	for (const c of rerunCases().cases.filter((c) => c.outcome === "revised")) {
		const before = openQuestions(c.spec, c.specText);
		const after = openQuestions(c.expected, c.expectedText);
		assert.equal(after.outside, before.outside, `fixture ${c.name}: the revised spec differs outside Open questions`);
		const kept = before.lines.filter((line) => !RUN_RISK_LINE.test(line));
		assert.deepEqual(after.lines.slice(0, kept.length), kept, `fixture ${c.name}: the other open questions are not kept in order`);
		assert.equal(after.lines.length, kept.length + c.added.length, `fixture ${c.name}: the revised Open questions add more than the findings`);
	}
});
test("rerun", "rerun-contracts-digest", () => {
	// AC22: with contracts enabled, the edited spec gets `contracts.js init spec` again. In a
	// scratch repo the sidecar goes stale on the edit and is valid, with the edited digest and
	// the same delivery ID, after init runs again.
	for (const [rel, text] of agentCopies("specifier"))
		assert.match(rerunSection(rel, text), /Only when `ai-factory\/contracts\/config\.json` exists and the spec was edited, run `node ai-factory\/make\/contracts\.js init spec <spec path>` again so the sidecar's digest matches the edited spec/, `${rel}: an edited spec does not get contracts.js init spec again`);
	const { spawnSync } = require("node:child_process");
	const path = require("node:path");
	const os = require("node:os");
	const { doc, c } = rerunCase("named-reassessed");
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), "effort-rerun-"));
	try {
		const make = path.join(dir, "ai-factory/make");
		fs.mkdirSync(make, { recursive: true });
		for (const file of ["contracts.js", "gate.js", "safe-files.js"])
			fs.copyFileSync(`skills/ai-layout/templates/ai-factory/make/${file}`, path.join(make, file));
		const spec = path.join(dir, doc.spec_path);
		fs.mkdirSync(path.dirname(spec), { recursive: true });
		fs.writeFileSync(spec, c.specText);
		const git = (...args) => spawnSync("git", ["-c", "user.name=fixture", "-c", "user.email=fixture@example.invalid", "-c", "commit.gpgsign=false", ...args], { cwd: dir, encoding: "utf8" });
		git("init", "-q");
		git("add", "-A");
		git("commit", "-q", "-m", "fixture");
		const env = { ...process.env };
		for (const key of ["JSON", "DELIVERY", "STEP", "PHASE", "REQUIRE"]) delete env[key];
		const contracts = (...args) => spawnSync(process.execPath, [path.join(make, "contracts.js"), ...args], { cwd: dir, env, encoding: "utf8" });
		const ok = (result, what) => assert.equal(result.status, 0, `${what}: ${result.stdout}${result.stderr}`);
		ok(contracts("enable"), "contracts.js enable");
		ok(contracts("init", "spec", doc.spec_path), "contracts.js init spec (first run)");
		const sidecar = spec.replace(/\.md$/, ".contract.json");
		const first = JSON.parse(fs.readFileSync(sidecar, "utf8"));
		fs.writeFileSync(spec, c.expectedText);
		assert.notEqual(contracts("validate", "--all").status, 0, "the edited spec still validates against the old sidecar, so the re-run's init proves nothing");
		ok(contracts("init", "spec", doc.spec_path), "contracts.js init spec (re-run)");
		const second = JSON.parse(fs.readFileSync(sidecar, "utf8"));
		assert.equal(second.delivery_id, first.delivery_id, "the re-run's init changed the delivery ID");
		assert.notEqual(second.sha256, first.sha256, "the re-run's init left the old digest in the sidecar");
		ok(contracts("validate", "--all"), "contracts.js validate after the re-run's init");
	} finally {
		fs.rmSync(dir, { recursive: true, force: true });
	}
});
test("rerun", "rerun-task-rule", () => {
	// AC24, second half: tasks/spec.md describes the AC16 rule.
	const text = flatten(read(SPEC_TASK));
	assert.match(text, /A run is a re-run only when the argument names an existing spec's path/, `${SPEC_TASK}: no re-run rule`);
	assert.match(text, /revises that spec in place[^.]*creates no new spec/, `${SPEC_TASK}: a re-run is not an in-place revision`);
	assert.match(text, /exits 3[^.]*keeps today's behaviour: it runs the helper again without `--id`, takes the next free ID and cites the parent's path/, `${SPEC_TASK}: exit 3 without a named spec path does not keep today's behaviour`);
});

// ---- planner (plan ASD-001 Step 4: AC25–AC29, AC31, AC5 for tasks/plan.md) ----------------
// The planner (both copies) and tasks/plan.md define the step line; the parsers that read a plan
// give the same answer with and without it (AC28), and the analyst's rule stays as it was (AC31).
const PLAN_TASK = "skills/ai-layout/templates/ai-factory/tasks/plan.md";
const STEP_LINE = "`Effort: <S|M|L|XL> · Estimate: dev <range> h, /fc:run ~<range> min (assumption: <what it rests on>)`";
const PLAN_FIXTURES = "skills/ai-layout/fixtures/effort";
// The planner's step-line rule (the bullet of `## The plan` that defines it), and the
// delegation instruction of tasks/plan.md that carries the same rule.
const plannerRule = (rel, text) => bullet(rel, section(rel, text, "## The plan"), "Every step's indented body carries one");
function planTaskRule() {
	const text = read(PLAN_TASK);
	// The frontmatter runs straight into the instruction, so it is cut from its first words.
	const at = text.indexOf("Delegate to the `planner` subagent");
	assert.ok(at >= 0, `${PLAN_TASK} has no delegation instruction`);
	return [PLAN_TASK, flatten(text.slice(at).split("\n\n")[0])];
}
const stepLineRules = () => [...agentCopies("planner").map(([rel, text]) => [rel, plannerRule(rel, text)]), planTaskRule()];

test("planner", "planner-step-line", () => {
	// AC25: every step's indented body carries one line in the exact format.
	for (const [rel, rule] of stepLineRules()) {
		assert.ok(rule.includes(STEP_LINE), `${rel}: the step line is not defined in the form ${STEP_LINE}`);
		assert.match(rule, /[Ee]very step's indented body carries one /, `${rel}: the line is not required in every step's indented body`);
	}
});
test("planner", "planner-same-rubric", () => {
	// AC26: the step is rated with the feature's rubric, on the step's own scope.
	for (const [rel, text] of agentCopies("planner")) {
		assert.match(plannerRule(rel, text), /rated with the same Effort rubric as the feature, applied to the step's own scope/, `${rel}: a step's effort is not rated with the feature's rubric on the step's own scope`);
		section(rel, text, RUBRIC);
	}
});
test("planner", "planner-line-placement", () => {
	// AC27: the line never goes in the title line and never holds an AC ID or a Verify command.
	for (const [rel, rule] of stepLineRules()) {
		assert.match(rule, /never in the `- \[ \] Step N` title line/, `${rel}: the line may go in the step's title line`);
		assert.match(rule, /never contains `AC<n>` or `Verify`/, `${rel}: the line may carry an AC ID or a Verify command`);
	}
});
test("planner", "planner-ranges-never-summed", () => {
	// AC29: both figures are ranges, labelled as assumptions, never summed or dated.
	for (const [rel, rule] of stepLineRules()) {
		assert.match(rule, /[Bb]oth estimates are ranges, labelled as assumptions/, `${rel}: the estimates are not ranges labelled as assumptions`);
		assert.match(rule, /never summed into a feature total or turned into a date/, `${rel}: the estimates may be summed into a total or turned into a date`);
	}
});
test("planner", "analyst-rule-unchanged", () => {
	// AC31: the analyst's rule is still there (the file says it lowercase, mid-sentence), and both
	// copies are byte-equal to the commit before this delivery.
	for (const rel of ["agents/analyst.md", `${TEMPLATE_AGENTS}/analyst.md`]) {
		const text = read(rel);
		assert.ok(flatten(text).includes("no invented effort, cost, ROI, dates or story points"), `${rel} lost the rule against invented effort, cost, ROI, dates or story points`);
		assert.equal(text, showAt(PRE_ASD001, rel), `${rel} differs from ${PRE_ASD001}`);
	}
});
test("planner", "effort-named-plan-task", () => {
	// AC5 for tasks/plan.md.
	const text = read(PLAN_TASK);
	assert.match(text, /\b[Ee]ffort\b/, `${PLAN_TASK} does not call the rating effort`);
	assert.doesNotMatch(text, /S\/M\/L(?!\/XL)/, `${PLAN_TASK} says S/M/L without XL`);
});
test("planner", "parse-invariant", () => {
	// AC28: the plan with the step lines and its twin without them read the same through
	// parsePlanSteps/draftVerify (contracts.js), validatePlan (loop.js) and state.sh.
	const path = require("node:path");
	const os = require("node:os");
	const { spawnSync } = require("node:child_process");
	const MAKE = path.resolve("skills/ai-layout/templates/ai-factory/make");
	const { parsePlanSteps, draftVerify } = require(`${MAKE}/contracts.js`);
	const { validatePlan } = require(`${MAKE}/loop.js`);
	const withLines = read(`${PLAN_FIXTURES}/plan-with-effort.md`);
	const without = read(`${PLAN_FIXTURES}/plan-without-effort.md`);
	// The fixtures are twins: the only difference is the step lines, one in every step.
	const effortLine = /^\s+(?:- )?Effort: (?:S|M|L|XL) · Estimate: dev \d+–\d+ h, \/fc:run ~\d+–\d+ min \(assumption: [^)]+\)$/;
	assert.equal(withLines.split("\n").filter((line) => !effortLine.test(line)).join("\n"), without, "plan-without-effort.md is not plan-with-effort.md minus its step lines");
	const stepsWith = parsePlanSteps(withLines);
	assert.ok(stepsWith.length >= 3, "the fixture plan has too few steps to prove anything");
	for (const step of stepsWith) {
		const lines = step.text.split("\n");
		assert.ok(effortLine.test(lines[1] || ""), `fixture Step ${step.number}: the step line is not the first line of its body`);
		assert.ok(!effortLine.test(lines[0]) && !/Effort:/.test(lines[0]), `fixture Step ${step.number}: the step line is in the title`);
	}
	const shape = (text) =>
		parsePlanSteps(text).map((step) => ({
			id: step.id,
			mark: step.mark,
			withdrawn: step.withdrawn,
			title: step.text.split("\n")[0],
			dependsOn: step.text.split("\n").filter((line) => /^\s+(?:[-*+]\s+)?Depends on:/.test(line)).map((line) => line.trim()),
			verify: draftVerify(step.text),
			criteria: [...new Set(step.text.match(/\bAC\d+\b/g) || [])],
		}));
	const [a, b] = [shape(withLines), shape(without)];
	assert.ok(a.some((step) => step.dependsOn.length) && a.some((step) => step.verify.verify.length) && a.some((step) => step.criteria.length), "the fixture plan exercises no Depends on:, Verify or AC ID");
	assert.deepEqual(a, b, "parsePlanSteps/draftVerify read the plan differently with the step lines");
	const schedule = validatePlan(withLines);
	assert.deepEqual(schedule.problems, [], `validatePlan finds problems in the fixture plan: ${schedule.problems.map((p) => p.message).join("; ")}`);
	assert.deepEqual(schedule, validatePlan(without), "loop.js validatePlan schedules the plan differently with the step lines");
	// state.sh over a scratch repo holding the plan, once with each twin.
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), "effort-plan-"));
	try {
		const plan = path.join(dir, "ai-factory/plans/ASD-902-csv-export.md");
		fs.mkdirSync(path.dirname(plan), { recursive: true });
		fs.mkdirSync(path.join(dir, "ai-factory/specs"), { recursive: true });
		fs.writeFileSync(path.join(dir, "ai-factory/specs/ASD-902-csv-export.md"), "# ASD-902 — CSV export of invoices\nCreated: 2026-10-02T09:00:00.000Z\n");
		spawnSync("git", ["init", "-q"], { cwd: dir });
		const state = (text, flags) => {
			fs.writeFileSync(plan, text);
			const run = spawnSync("bash", [path.resolve("skills/ai-layout/scripts/state.sh"), ".", process.cwd(), ...flags], { cwd: dir, encoding: "utf8" });
			assert.equal(run.status, 0, `state.sh ${flags.join(" ")} failed: ${run.stderr}`);
			return run.stdout;
		};
		for (const flags of [[], ["--plans"], ["--next"]]) {
			const rows = state(withLines, flags);
			assert.match(rows, /ai-factory\/plans\/ASD-902-csv-export\.md\tStep \d+\t/, `state.sh ${flags.join(" ")} lists no step of the fixture plan`);
			assert.equal(rows, state(without, flags), `state.sh ${flags.join(" ")} lists the plan differently with the step lines`);
		}
	} finally {
		fs.rmSync(dir, { recursive: true, force: true });
	}
});

// ---- readers (plan ASD-001 Step 6: AC41) --------------------------------------------------
// The spec's `Effort and risk` section is read by contracts.js (AC IDs, digest), delivery-report.js
// (source IDs, Open questions) and continue.js (the spec-drift stop). A spec with the section and
// the same spec without it give the same answers, and an edit to the section is drift like any edit.
const READERS_FIXTURE = "skills/ai-layout/fixtures/effort/readers/spec-with-effort.md";
const PLANNED = "skills/ai-layout/fixtures/contracts/planned";
const PLANNED_SPEC = "ai-factory/specs/0001-csv-export.md";
const PLANNED_PLAN = "ai-factory/plans/0001-csv-export.md";
const EFFORT_SECTION = "## Effort and risk";
// The fixture spec and its twin: the same text with the `## Effort and risk` section dropped.
function readerTwins() {
	const withSection = read(READERS_FIXTURE);
	const body = section(READERS_FIXTURE, withSection, EFFORT_SECTION);
	assert.match(body, /^- authorization: present — /m, `${READERS_FIXTURE}: no '- authorization: present — …' triage line`);
	assert.match(body, /^- [a-z][^\n]*\bAC\d+\b/m, `${READERS_FIXTURE}: no triage line mentions an AC ID inside a list item`);
	const without = withSection.replace(`${body}\n`, "");
	assert.notEqual(without, withSection, `${READERS_FIXTURE}: the twin without the section equals the fixture`);
	assert.ok(!without.includes(EFFORT_SECTION), `${READERS_FIXTURE}: the twin still holds the section`);
	return { withSection, without };
}
// A contracts-enabled scratch copy of the planned fixture with `specText` as its spec, spec and
// plan sidecars written by contracts.js, as /fc:spec and /fc:plan leave them.
function readersRepo(specText, label) {
	const path = require("node:path");
	const os = require("node:os");
	const { spawnSync } = require("node:child_process");
	const contracts = require(path.resolve("skills/ai-layout/templates/ai-factory/make/contracts.js"));
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), `effort-readers-${label}-`));
	fs.cpSync(PLANNED, dir, { recursive: true });
	fs.writeFileSync(path.join(dir, PLANNED_SPEC), specText);
	const make = path.join(dir, "ai-factory/make");
	fs.mkdirSync(make, { recursive: true });
	for (const file of ["contracts.js", "delivery-report.js", "safe-files.js", "gate.js"])
		fs.copyFileSync(`skills/ai-layout/templates/ai-factory/make/${file}`, path.join(make, file));
	fs.mkdirSync(path.join(dir, "ai-factory/contracts"), { recursive: true });
	fs.writeFileSync(path.join(dir, "ai-factory/contracts/config.json"), JSON.stringify({ schema: "fc-contracts-config", version: 1, code_scope: { include: ["**"], exclude: [] } }));
	const git = spawnSync("git", ["init", "-q"], { cwd: dir, encoding: "utf8" });
	assert.equal(git.status, 0, `git init: ${git.stderr}`);
	const ctx = contracts.context(dir);
	contracts.init("spec", PLANNED_SPEC, { ctx });
	contracts.init("plan", PLANNED_PLAN, { ctx, spec: PLANNED_SPEC });
	const sidecar = JSON.parse(fs.readFileSync(path.join(dir, PLANNED_SPEC.replace(/\.md$/, ".contract.json")), "utf8"));
	return { dir, id: sidecar.delivery_id, sidecar };
}
function withReaderRepos(fn) {
	const { withSection, without } = readerTwins();
	const repos = [];
	try {
		repos.push(readersRepo(withSection, "with"), readersRepo(without, "without"));
		fn(repos[0], repos[1]);
	} finally {
		for (const { dir } of repos) fs.rmSync(dir, { recursive: true, force: true });
	}
}
// What a reader says about a delivery, without the per-repo delivery ID and digests.
const diagnosticsOf = (artifacts) => artifacts.map((item) => ({ path: item.path, kind: item.kind, state: item.state, codes: item.diagnostics.map((d) => d.code) }));
function continuation(repo) {
	const value = require(require("node:path").resolve("skills/ai-layout/templates/ai-factory/make/continue.js")).inspect({ root: repo.dir, delivery: repo.id });
	return { outcome: value.outcome, reason: value.reason, task: value.task, args: value.args, evidence: diagnosticsOf(value.evidence) };
}

test("readers", "readers-ac-ids", () => {
	// AC41: contracts.js reads the same AC IDs, with no new diagnostic, from the spec with the
	// section as from the spec without it; delivery-report.js reads the same source IDs and Open
	// questions.
	const path = require("node:path");
	const contracts = require(path.resolve("skills/ai-layout/templates/ai-factory/make/contracts.js"));
	const reports = require(path.resolve("skills/ai-layout/templates/ai-factory/make/delivery-report.js"));
	const { withSection, without } = readerTwins();
	const expected = { ids: ["AC1", "AC2", "AC3"], duplicates: [] };
	assert.deepEqual(contracts.parseCriteria(without), expected, "parseCriteria: the twin without the section");
	assert.deepEqual(contracts.parseCriteria(withSection), expected, "parseCriteria reads AC IDs from the Effort and risk section");
	// The control: a triage line whose first token is an AC ID would be a declaration. The
	// specifier's rule that evidence lines start with the item's name is what keeps the IDs equal.
	const leading = withSection.replace(/^- injection: present — /m, "- AC7 injection: present — ");
	assert.deepEqual(contracts.parseCriteria(leading).ids, ["AC1", "AC2", "AC3", "AC7"], "the control: a triage line led by an AC ID is not read as a declaration, so this case proves nothing");
	for (const [rel, text] of agentCopies("specifier"))
		assert.match(flatten(text), /Each evidence line starts with the item's name, never with an AC ID\./, `${rel}: triage evidence lines may start with an AC ID`);
	withReaderRepos((a, b) => {
		assert.deepEqual(a.sidecar.criteria, ["AC1", "AC2", "AC3"], "contracts.js init spec: the spec sidecar's criteria with the section");
		assert.deepEqual(a.sidecar.criteria, b.sidecar.criteria, "contracts.js init spec: the criteria differ with the section");
		const validated = [a, b].map((repo) => {
			const ctx = contracts.context(repo.dir);
			ctx.config = contracts.readConfig(ctx);
			return diagnosticsOf(contracts.validate({ ctx, target: repo.id }).artifacts);
		});
		assert.ok(validated[0].some((item) => item.kind === "spec") && validated[0].some((item) => item.kind === "plan"), "contracts.js validate lists no spec and plan");
		assert.deepEqual(validated[0].flatMap((item) => item.codes), [], `contracts.js validate reports diagnostics for the spec with the section: ${JSON.stringify(validated[0])}`);
		assert.deepEqual(validated[0], validated[1], "contracts.js validate reports differently with the section");
		const [ra, rb] = [a, b].map((repo) => reports.collect({ root: repo.dir, delivery: repo.id }));
		assert.deepEqual(ra.sourceIds, rb.sourceIds, "delivery-report.js reads other source IDs with the section");
		assert.equal(ra.limitations.open_questions, rb.limitations.open_questions, "delivery-report.js reads other Open questions with the section");
		assert.ok(!/Effort|Triage/.test(ra.limitations.open_questions || ""), "delivery-report.js folds the Effort and risk section into Open questions");
	});
});
test("readers", "readers-drift", () => {
	// AC41: continue.js gives the same result for an unchanged spec with the section as without
	// it, and stops on S_SPEC_CHANGED after the section is edited, as after any other edit.
	const path = require("node:path");
	withReaderRepos((a, b) => {
		const [ca, cb] = [a, b].map(continuation);
		assert.equal(ca.outcome, "action", `continue.js does not pick an action for the unchanged spec with the section: ${ca.reason}`);
		assert.deepEqual(ca.evidence.flatMap((item) => item.codes).filter((code) => code === "S_SPEC_CHANGED"), [], "continue.js reports drift on an unchanged spec with the section");
		assert.deepEqual(ca, cb, "continue.js reads the unchanged spec differently with the section");
		const specA = path.join(a.dir, PLANNED_SPEC);
		const original = fs.readFileSync(specA, "utf8");
		const edits = [
			["the rating", (text) => text.replace("Effort: M (size M", "Effort: L (size L")],
			["a triage line", (text) => text.replace("- secrets: absent — no credential is read or written.", "- secrets: present — the export signs its URL.")],
		];
		for (const [what, edit] of edits) {
			const edited = edit(original);
			assert.notEqual(edited, original, `the fixture has no ${what} to edit`);
			fs.writeFileSync(specA, edited);
			const drifted = continuation(a);
			assert.equal(drifted.outcome, "blocked", `continue.js does not stop after an edit to ${what} of the section`);
			assert.ok(drifted.evidence.some((item) => item.codes.includes("S_SPEC_CHANGED")), `continue.js reports no S_SPEC_CHANGED after an edit to ${what} of the section`);
			fs.writeFileSync(specA, original);
			assert.deepEqual(continuation(a), ca, `continue.js does not return to its first result once ${what} is restored`);
		}
		// Any other edit to the spec, on the twin, stops the same way.
		fs.appendFileSync(path.join(b.dir, PLANNED_SPEC), "- Changed after plan.\n");
		const other = continuation(b);
		fs.writeFileSync(specA, edits[0][1](original));
		const inSection = continuation(a);
		assert.equal(other.outcome, "blocked", "continue.js does not stop after an edit outside the section");
		assert.deepEqual(inSection, other, "an edit to the section stops continue.js differently from any other spec edit");
	});
});

// ---- docs (plan ASD-001 Step 7: AC42, and the docs that describe start's result and a step) --
// The CHANGELOG block for this change sits inside a `## <version>` entry, never under a bare
// `## Unreleased` heading: check-release-docs.sh needs the top `## ` entry to be the version
// plugin.json ships. While unreleased it sat in the top entry; released, it sits under 5.0.0 and
// drifts down as later releases land, so it is found in whichever entry holds it.
const CHANGELOG = "CHANGELOG.md";
const ENTRY_TITLE = /^\*\*(?:Unreleased — effort|Effort) rubric and risk-trigger triage \(spec ASD-001(?:, no version bump)?\)\*\*$/;
// The `## <version>` entry holding this change's block, and the block itself: from its bold title
// to the next bold title line or the end of the entry.
function changelogEntry(text) {
	const lines = text.split("\n");
	const heads = lines.flatMap((line, i) => (line.startsWith("## ") ? [i] : []));
	assert.ok(heads.length >= 1, `${CHANGELOG} has no versioned entry`);
	const top = heads.find((h, k) => lines.slice(h, heads[k + 1] ?? lines.length).some((line) => ENTRY_TITLE.test(line)));
	assert.ok(top !== undefined, `${CHANGELOG} has no release entry with the ASD-001 block`);
	assert.match(lines[top], /^## \d+\.\d+\.\d+ /, `${CHANGELOG}: the entry holding the block is not a version (${lines[top]})`);
	const end = lines.findIndex((line, i) => i > top && line.startsWith("## "));
	const entry = lines.slice(top, end < 0 ? lines.length : end);
	const at = entry.findIndex((line) => ENTRY_TITLE.test(line));
	const next = entry.findIndex((line, i) => i > at && /^\*\*[^*]+\*\*$/.test(line));
	return flatten(entry.slice(at, next < 0 ? entry.length : next).join("\n"));
}
// The paragraph of a document that holds `needle`.
function paragraph(rel, text, needle) {
	const found = text.split(/\n\s*\n/).find((block) => block.includes(needle));
	assert.ok(found, `${rel} has no paragraph naming ${needle}`);
	return flatten(found);
}

test("docs", "changelog-breaking", () => {
	// AC42: the block exists in a release entry, says breaking for adopted repos, and names the
	// rubric, the spec section and its re-run, the plan step line and start's optional effort.
	const block = changelogEntry(read(CHANGELOG));
	assert.match(block, /Breaking for adopted repos\./, `${CHANGELOG}: the entry is not marked breaking for adopted repos`);
	assert.match(block, /\/fc:sync-sdlc/, `${CHANGELOG}: the entry does not say how an adopted repo takes the change`);
	assert.match(block, /`## Effort rubric`/, `${CHANGELOG}: the entry does not name the Effort rubric`);
	assert.match(block, /`## Effort and risk` section/, `${CHANGELOG}: the entry does not name the spec's Effort and risk section`);
	assert.match(block, /re-run/, `${CHANGELOG}: the entry does not name the specifier's re-run`);
	assert.ok(block.includes(STEP_LINE), `${CHANGELOG}: the entry does not name the plan step line ${STEP_LINE}`);
	assert.match(block, /optional `effort` field/, `${CHANGELOG}: the entry does not name start's optional effort field`);
	// The control: the same file without the block must fail, so the lookup cannot pass over nothing.
	assert.throws(() => changelogEntry(read(CHANGELOG).split("\n").map((line) => (ENTRY_TITLE.test(line) ? "**Something else**" : line)).join("\n")), /has no/, "the control: a CHANGELOG without the block still yields an entry");
});
test("docs", "docs-start-effort", () => {
	// Where the docs describe /fc:start's result, they name the optional effort field and the
	// rule behind it; where they describe a plan step's body, they name the step line.
	const workflow = "ai-factory/docs/workflow.md";
	const readme = "README.md";
	for (const [rel, needle] of [[workflow, "Use `/fc:start <request>`"], [readme, "Use `/fc:start Change the setup heading"]]) {
		const start = paragraph(rel, read(rel), needle);
		assert.match(start, /optional `effort` field/, `${rel}: the /fc:start passage does not name the optional effort field`);
		assert.match(start, /spec or exploration whose path the request names/, `${rel}: the /fc:start passage does not say where the rating is read from`);
		assert.match(start, /L or XL never routes to quick or chore/, `${rel}: the /fc:start passage does not say what L or XL rules out`);
		assert.match(start, /S or M changes nothing/, `${rel}: the /fc:start passage does not keep S and M neutral`);
	}
	const steps = bullet(workflow, read(workflow).split("\n").map((line) => line.replace(/^  /, "")).join("\n"), "**Steps and dependencies.**");
	assert.ok(steps.includes(STEP_LINE), `${workflow}: the plan step body is not described with the line ${STEP_LINE}`);
	assert.match(steps, /never in the title line/, `${workflow}: the step line may go in the title line`);
	assert.match(steps, /never summed or turned into a date/, `${workflow}: the step estimates may be summed or dated`);
});

// ---- groups that later steps of plan ASD-001 fill -----------------------------------------
const later = {};

for (const c of cases) {
	if (!want(c.group)) continue;
	try {
		c.fn();
		passed++;
		if (process.env.VERBOSE) console.log(`ok: ${c.group}/${c.name}`);
	} catch (error) {
		failures.push(`${c.group}/${c.name}: ${error.message.split("\n")[0]}`);
	}
}
for (const [name, step] of Object.entries(later))
	if (want(name) && !cases.some((c) => c.group === name))
		failures.push(`${name}: no cases yet (plan ASD-001 Step ${step} adds them)`);
for (const line of failures) console.error(`FAIL ${line}`);
if (failures.length) process.exitCode = 1;
else console.log(`effort ok — ${passed} cases (${selected})`);
NODE
