#!/usr/bin/env bash
# The risk agent and /fc:risk (spec 0023, plan 0023): pins the ADR that records the spec 0012
# AC10 exception, and later the agent, the task, the risks/ directory, the routing entry, the
# knowledge seam, the consumers, /fc:start's suggestion and the docs.
#
# Groups: adr, agent, task, layout, routing, knowledge, consumers, start, docs (default: every
# group). Each case reports a missing file as its own failure, never as a crash, so the red run
# of a group names every case it holds. A group that a later step of plan 0023 fills fails with
# "no cases yet" until that step lands.
set -euo pipefail
cd "$(dirname "$0")/../../.."
group="${1:-all}"
groups="adr, agent, task, layout, routing, knowledge, consumers, start, docs"
case "$group" in
	all | adr | agent | task | layout | routing | knowledge | consumers | start | docs) ;;
	*) echo "check-risk: unknown group '$group' (expected: $groups)" >&2; exit 2 ;;
esac
RISK_GROUP="$group" node <<'NODE'
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const ADR_DIR = "ai-factory/adr";
const selected = process.env.RISK_GROUP;
const want = (name) => selected === "all" || selected === name;
const failures = [];
let passed = 0;

const cases = [];
const test = (group, name, fn) => cases.push({ group, name, fn });

// Every ADR in the repo, the template excluded. The filename's ID is never read: an ADR is a
// legacy `NNNN-` file or one created by `ids.js new adr` with a letter-and-digit ID.
function adrs() {
	if (!fs.existsSync(ADR_DIR)) throw new Error(`${ADR_DIR}/ does not exist`);
	return fs
		.readdirSync(ADR_DIR, { withFileTypes: true })
		.filter((entry) => entry.isFile() && entry.name.endsWith(".md") && entry.name !== "0000-template.md")
		.map((entry) => ({ rel: `${ADR_DIR}/${entry.name}`, text: fs.readFileSync(path.join(ADR_DIR, entry.name), "utf8") }))
		.sort((a, b) => a.rel.localeCompare(b.rel));
}
// Prose wraps at any space, so phrase matches run on the text with whitespace collapsed.
const flatten = (text) => text.replace(/\s+/g, " ");

// ---- adr (plan 0023 Step 1, AC20) ---------------------------------------------------------
// The ADR is found by what it says, never by its number: it names spec 0012 (by number or by
// its file) and that spec's AC10.
const SPEC_0012 = /\bspec 0012\b|specs\/0012-plugin-security\.md/i;
const AC10 = /\bAC10\b/;
const AUDIT_TOOLS = ["npm audit", "pip-audit", "osv-scanner"];
test("adr", "adr-records-audit-exception", () => {
	const naming = adrs().filter((adr) => {
		const flat = flatten(adr.text);
		return SPEC_0012.test(flat) && AC10.test(flat);
	});
	if (naming.length === 0) throw new Error("no ADR names the spec 0012 AC10 exception");
	assert.equal(
		naming.length,
		1,
		`more than one ADR names the spec 0012 AC10 exception: ${naming.map((adr) => adr.rel).join(", ")}`,
	);
	const [{ rel, text }] = naming;
	const flat = flatten(text);
	assert.match(text, /^(?:.*·\s*)?Status:\s*accepted\b/m, `${rel} has no 'Status: accepted' line`);
	assert.match(flat, /`risk` agent|\brisk agent\b|`fc:risk`/i, `${rel} does not name the risk agent`);
	assert.ok(
		AUDIT_TOOLS.some((tool) => flat.includes(tool)),
		`${rel} names none of the audit tools ${AUDIT_TOOLS.join(", ")}`,
	);
	assert.match(
		flat,
		/\bno other agent\b[^.]*\bnetwork\b/i,
		`${rel} does not say no other agent gains network access`,
	);
});

// ---- agent (plan 0023 Step 2: AC1, AC3; the agent side of AC4–AC8, AC10–AC19, AC21, AC30,
// AC36–AC40) -------------------------------------------------------------------------------
// Static reads of the procedure: they prove what agents/risk.md tells the agent. That the agent
// obeys is proved by the host runs of plan 0023 Step 10, not here.
const AGENT = "agents/risk.md";
const SYNC_ADAPTERS = "skills/ai-layout/templates/ai-factory/make/sync-adapters.js";
function agentText() {
	if (!fs.existsSync(AGENT)) throw new Error(`${AGENT} does not exist`);
	return fs.readFileSync(AGENT, "utf8");
}
// The section that runs from `heading` to the next heading of its level.
function section(text, heading) {
	const at = text.indexOf(heading);
	assert.ok(at >= 0, `${AGENT} has no '${heading}' section`);
	const level = /^#+/.exec(heading)[0];
	const rest = text.slice(at + heading.length);
	const end = rest.search(new RegExp(`\\n${level} `));
	return end < 0 ? rest : rest.slice(0, end);
}
// Sentences of flattened prose; a sentence ends at '.', ':' or ';' followed by a space.
const sentences = (text) => flatten(text).split(/(?<=[.;])\s+/);
const says = (text, pattern, what) => assert.match(flatten(text), pattern, `${AGENT} ${what}`);
// The `ids.js` COUNTING patterns of check-ids.sh, plus the file name spec 0023 dropped.
const COUNTING = [/next free number/i, /next number/i, /same number as/i, /<NNNN>-/, /\bNNNN-/, /\bNNNN\b/, /change-<slug>/];
const CATEGORIES = [
	"authorization",
	"data exposure",
	"secrets",
	"injection",
	"dependency/supply chain",
	"migrations",
	"rollback",
	"blast radius",
];
const TARGET_SHAPES = [
	"Target: spec <path>",
	"Target: plan <path>",
	"Target: working-tree <branch>",
	"Target: branch <branch>",
	"Target: detached <head sha>",
	"Target: diff <path>",
	"Target: diff supplied",
];
const ADR_ID = "DJX496";

test("agent", "agent-registered", () => {
	const text = agentText();
	const front = /^---\n([\s\S]*?)\n---\n/.exec(text)?.[1];
	assert.ok(front, `${AGENT} has no frontmatter`);
	assert.match(front, /^name: risk$/m, `${AGENT} frontmatter does not say 'name: risk'`);
	assert.match(front, /^description: \S/m, `${AGENT} frontmatter has no description`);
	assert.match(front, /^tools: Read, Grep, Glob, Bash, Write, Edit$/m, `${AGENT} frontmatter tools differ from the Design`);
	const set = /const nativeClaudeAgents = new Set\(\[([\s\S]*?)\]\)/.exec(fs.readFileSync(SYNC_ADAPTERS, "utf8"))?.[1];
	assert.ok(set, `${SYNC_ADAPTERS} has no nativeClaudeAgents set`);
	assert.ok(/"risk"/.test(set), `nativeClaudeAgents in ${SYNC_ADAPTERS} does not have risk`);
});
test("agent", "agent-under-two-pages", () => {
	const lines = agentText().trimEnd().split("\n").length;
	assert.ok(lines <= 110, `${AGENT} is ${lines} lines; keep it under two pages (110 lines)`);
});
test("agent", "agent-defers-to-repo-copy", () => {
	says(agentText(), /If you are not already reading `ai-factory\/agents\/risk\.md`, read that file/, "never defers to ai-factory/agents/risk.md");
});
test("agent", "agent-calls-helper", () => {
	const text = agentText();
	const write = section(text, "## What you may write");
	assert.ok(write.includes("`node ai-factory/make/ids.js new risk <slug> --id <spec ID>`"), `${AGENT}: 'What you may write' never calls ids.js new risk <slug> --id <spec ID>`);
	assert.ok(write.includes("`node ai-factory/make/ids.js new risk <slug>`"), `${AGENT}: 'What you may write' never calls ids.js new risk <slug> without --id`);
	says(write, /the path it prints/, "never writes into the path the helper prints");
	says(write, /never pick (a|the) number or (an|the) ID yourself/i, "does not forbid picking a number or an ID");
	says(write, /[Kk]eep the helper's two lines — the `# <ID> — <Title>` heading and the `Created:` line — unchanged, and write[^.]*below them/, "does not keep the helper's two lines");
	says(write, /exits? 3[^.]*append[^.]*the path it print/i, "does not append to the printed path on exit 3");
	says(write, /other non-zero exit[^.]*write nothing[^.]*report its message/i, "does not write nothing and report on any other non-zero exit");
	// AC8: the change slug rule, and the slug carries no identity.
	says(write, /lower case[^.]*`\[a-z0-9\]`[^.]*`-`[^.]*trim/i, "does not state the AC8 branch slug rule");
	says(write, /slug carries no identity/i, "does not say the slug carries no identity");
	for (const pattern of COUNTING) assert.doesNotMatch(text, pattern, `${AGENT} still counts (${pattern})`);
});
test("agent", "agent-target-kinds", () => {
	const target = section(agentText(), "## The target");
	for (const kind of ["spec", "plan", "working-tree", "branch", "diff"])
		assert.ok(target.includes(`\`${kind}\``), `${AGENT}: 'The target' does not name the kind \`${kind}\``);
	says(target, /more than one plausible reading, or none[^.]*question[^.]*lists? (every|the) candidate/i, "does not return a question listing the candidates");
	says(target, /question[^.]*write nothing/i, "does not say a question writes nothing");
	says(agentText(), /report[^.]*target kind/i, "does not report the target kind (AC4)");
});
test("agent", "agent-target-line", () => {
	const text = agentText();
	const lines = section(text, "## The target");
	for (const shape of TARGET_SHAPES)
		assert.ok(lines.includes(`\`${shape}\``), `${AGENT}: 'The target' does not show \`${shape}\``);
	// AC16: equal lines match, and working-tree and branch match on the branch name.
	says(lines, /`working-tree <branch>`[^.]*`branch <branch>`[^.]*match[^.]*branch names are equal/i, "does not match working-tree and branch targets by branch name");
	says(lines, /[Oo]ther[^.]*`Target:` lines match only when (they are )?equal/, "does not require other Target: lines to be equal");
	says(lines, /[Bb]ase commits are not compared/, "does not say base commits are not compared");
	says(lines, /do(es)? not call `ids\.js new risk`|without calling `ids\.js new risk`/, "does not skip the helper when a change matches");
	// AC38: a diff at the same path appends; a pasted diff is always new.
	says(lines, /`Target: diff supplied`[^.]*always[^.]*new file[^.]*never matches/i, "does not make a pasted diff always a new file");
	// AC36: a spec and its plan share one file through exit 3.
	says(lines, /plan[^.]*after its spec[^.]*Reassessment[^.]*`Target:`[^.]*plan/i, "does not append a plan after its spec as a Reassessment naming the plan");
});
test("agent", "agent-artefact-shape", () => {
	const text = agentText();
	for (const heading of ["## Categories assessed", "## Findings", "## Residual risks"])
		assert.ok(text.includes(`\`${heading}\``), `${AGENT} does not show the \`${heading}\` heading`);
	assert.ok(text.includes("| id | category | severity | status | evidence path | mitigation |"), `${AGENT} does not show the findings columns in order`);
	for (const category of CATEGORIES) assert.ok(text.includes(category), `${AGENT} does not name the category '${category}'`);
	says(text, /`blocker`, `major` or `minor`/, "does not give the three severities");
	says(text, /`open`, `mitigated` or `accepted`/, "does not give the three statuses");
	says(text, /`accepted`[^.]*who accepted it and why/, "does not record who accepted and why");
	says(text, /category and (the )?mitigation (cells )?are never empty|never (leave|empty)[^.]*category[^.]*mitigation/i, "does not forbid an empty category or mitigation");
});
test("agent", "agent-statuses", () => {
	const text = agentText();
	// AC39: mitigated only with cited evidence; otherwise open.
	says(text, /`mitigated` only[^.]*evidence path[^.]*cites/i, "does not tie `mitigated` to cited evidence");
	says(text, /no evidence[^.]*stays `open`/i, "does not keep an uncited finding `open`");
	// AC40: only the developer sets accepted; carried forward; never asked for.
	says(text, /[Nn]ever set `accepted`/, "does not forbid setting `accepted`");
	says(text, /carr(y|ies) [^.]*forward as `accepted`[^.]*same who and why/i, "does not carry an accepted finding forward with the same who and why");
	says(text, /[Nn]ever ask the developer to accept/, "does not forbid asking the developer to accept");
});
test("agent", "agent-reassessment", () => {
	const text = agentText();
	assert.ok(text.includes("`## Reassessment <ISO date>`"), `${AGENT} does not show the dated \`## Reassessment <ISO date>\` heading`);
	says(text, /restates? every finding still relevant[^.]*current status/i, "does not restate every relevant finding with its current status");
	says(text, /earlier (section|byte)s?[^.]*(unchanged|untouched)/i, "does not keep earlier sections unchanged");
	assert.ok(text.includes("`Base commit:`") && text.includes("`Head commit:`"), `${AGENT} does not record base and head commits`);
	says(text, /`working-tree` or `branch` target[^.]*`Base commit:`/, "does not tie the commit lines to working-tree and branch targets");
});
test("agent", "agent-write-boundary", () => {
	const write = section(agentText(), "## What you may write");
	assert.ok(write.includes("ai-factory/risks/"), `${AGENT}: 'What you may write' does not name ai-factory/risks/`);
	// Any other ai-factory/ path in the section is the helper it runs, the protection list, or
	// one it is told never to touch.
	const allowed = new Set(["ai-factory/risks/", "ai-factory/make/ids.js", "ai-factory/docs/dont-touch.md"]);
	for (const sentence of sentences(write))
		for (const [rel] of sentence.matchAll(/ai-factory\/[A-Za-z0-9_./-]*[A-Za-z0-9_/]/g))
			if (!allowed.has(rel) && !rel.startsWith("ai-factory/risks/"))
				assert.match(sentence, /\b[Nn]ever\b/, `${AGENT}: 'What you may write' names ${rel} as writable`);
	says(write, /[Nn]ever[^.]*code[^.]*specs?[^.]*plans?[^.]*evidence/, "does not forbid editing code, specs, plans or evidence");
});
test("agent", "agent-audit-only-here", () => {
	const text = agentText();
	const tools = /npm audit|pip-audit|osv-scanner/;
	const scanned = ["agents", "skills/ai-layout/templates/ai-factory/tasks", "skills/ai-hooks/scripts"].flatMap((dir) =>
		fs.readdirSync(dir, { withFileTypes: true }).filter((entry) => entry.isFile()).map((entry) => `${dir}/${entry.name}`),
	);
	const naming = scanned.filter((rel) => tools.test(fs.readFileSync(rel, "utf8")));
	assert.deepEqual(naming, [AGENT], `audit tools are named outside ${AGENT}: ${naming.join(", ")}`);
	for (const tool of AUDIT_TOOLS) assert.ok(text.includes(tool), `${AGENT} does not name ${tool}`);
	assert.ok(text.includes("not assessed: <reason>"), `${AGENT} has no 'not assessed: <reason>' fallback`);
	says(text, /inspect[^.]*lockfiles[^.]*locally/i, "does not fall back to local lockfile inspection");
	says(text, new RegExp(`\\b${ADR_ID}\\b`), `does not cite ADR ${ADR_ID}`);
	says(text, /[Nn]ever run an audit tool for any other category/, "does not forbid audit tools outside supply chain");
});
test("agent", "agent-headless-no-question", () => {
	says(agentText(), /headless[^.]*report the question[^.]*write nothing[^.]*change no file/i, "does not report the question and write nothing when headless");
});
test("agent", "no-old-names", () => {
	const { execFileSync } = require("node:child_process");
	const git = (...args) => execFileSync("git", args, { encoding: "utf8" }).split("\n").filter(Boolean);
	const base = "64ad3bcd2c5a8df3d40a3046fc87df6d0278a8a5"; // the commit before plan 0023; merge-base with main is HEAD once merged
	const added = [
		...git("diff", "--name-only", "--diff-filter=A", base),
		...git("ls-files", "--others", "--exclude-standard"),
	];
	const OLD = /(^|[-_/.])(assessor|assess|assessments)([-_/.]|$)/i;
	const bad = added.filter((rel) => OLD.test(rel));
	assert.deepEqual(bad, [], `added paths use an old name: ${bad.join(", ")}`);
	if (fs.existsSync(AGENT)) {
		const text = fs.readFileSync(AGENT, "utf8");
		for (const pattern of [/\bassessor\b/i, /\bassessments\b/i, /\/fc:assess\b/, /`assess`/, /\bfc-assess\b/, /TASK=assess\b/])
			assert.doesNotMatch(text, pattern, `${AGENT} uses an old name (${pattern})`);
	}
});

// ---- task (plan 0023 Step 3: AC2; the task side of AC5 and AC30) --------------------------
// Static reads of the task and of the entries both generators derive from it. That a host runs
// the task as written is proved by the host runs of plan 0023 Step 10, not here.
const TASK = "skills/ai-layout/templates/ai-factory/tasks/risk.md";
const CLAUDE_COMMAND = "commands/risk.md";
const CODEX_SKILL = "codex-skills/fc-risk/SKILL.md";
function taskText() {
	if (!fs.existsSync(TASK)) throw new Error("tasks/risk.md does not exist");
	return fs.readFileSync(TASK, "utf8");
}
// The task body: everything after the frontmatter.
function taskBody(text) {
	const match = /^---\n[\s\S]*?\n---\n/.exec(text);
	assert.ok(match, `${TASK} has no frontmatter`);
	return text.slice(match[0].length);
}
const taskSays = (text, pattern, what) => assert.match(flatten(text), pattern, `${TASK} ${what}`);

test("task", "task-exists-delegates", () => {
	const text = taskText();
	const front = /^---\n([\s\S]*?)\n---\n/.exec(text)?.[1];
	assert.ok(front, `${TASK} has no frontmatter`);
	assert.match(front, /^description: \S/m, `${TASK} frontmatter has no description`);
	assert.match(front, /^argument-hint: \S/m, `${TASK} frontmatter has no argument-hint`);
	const first = taskBody(text).split("\n")[0];
	assert.match(first, /^Delegate to the `risk` subagent\b/, `${TASK}: the first line after the frontmatter does not delegate to the \`risk\` subagent`);
	taskSays(text, /[Rr]eturn its report unchanged/, "does not return the agent's report unchanged");
	taskSays(text, /[Dd]o not assess anything yourself[^.]*do not edit any file yourself/, "does not forbid assessing or editing in the task itself");
	assert.ok(text.includes("$ARGUMENTS"), `${TASK} does not pass the developer's input`);
	for (const pattern of COUNTING) assert.doesNotMatch(text, pattern, `${TASK} counts (${pattern})`);
	assert.doesNotMatch(text, /npm audit|pip-audit|osv-scanner/, `${TASK} names an audit tool; only ${AGENT} may`);
	assert.doesNotMatch(text, /\{\{/, `${TASK} carries a {{…}} placeholder`);
});
test("task", "task-generated-both-hosts", () => {
	taskText();
	for (const rel of [CLAUDE_COMMAND, CODEX_SKILL]) assert.ok(fs.existsSync(rel), `${rel} does not exist`);
	const command = fs.readFileSync(CLAUDE_COMMAND, "utf8");
	assert.ok(command.includes("ai-factory/tasks/risk.md"), `${CLAUDE_COMMAND} does not load ai-factory/tasks/risk.md`);
	assert.ok(command.includes("$ARGUMENTS"), `${CLAUDE_COMMAND} does not pass the developer's input`);
	const skill = fs.readFileSync(CODEX_SKILL, "utf8");
	assert.match(skill, /^name: fc-risk$/m, `${CODEX_SKILL} is not named fc-risk`);
	assert.ok(skill.includes("ai-factory/tasks/risk.md"), `${CODEX_SKILL} does not load ai-factory/tasks/risk.md`);
	assert.ok(skill.includes("ai-factory/agents/risk.md"), `${CODEX_SKILL} does not name ai-factory/agents/risk.md`);
});
test("task", "task-headless-question", () => {
	const text = taskText();
	taskSays(text, /returns a question[^.]*ask the developer that question and stop/i, "does not ask the developer the agent's question");
	taskSays(text, /headless run[^.]*report the question, say nothing was written, and stop/i, "does not report the question, say nothing was written and stop when headless");
});
test("task", "task-empty-input-asks", () => {
	const text = taskText();
	taskSays(text, /If nothing follows the command name, ask[^.]*what to assess[^.]*stop/, "does not ask what to assess when the input is empty");
	taskSays(text, /[Dd]o not guess[^.]*(branch name|last commit)/, "does not forbid guessing the target");
});
test("task", "task-native-command", () => {
	taskText();
	const set = /const nativeClaudeCommands = new Set\(\[([\s\S]*?)\]\)/.exec(fs.readFileSync(SYNC_ADAPTERS, "utf8"))?.[1];
	assert.ok(set, `${SYNC_ADAPTERS} has no nativeClaudeCommands set`);
	assert.ok(/"risk"/.test(set), `nativeClaudeCommands in ${SYNC_ADAPTERS} does not have risk`);
});

// ---- layout (plan 0023 Step 4: AC22, AC23) ------------------------------------------------
// A new adoption gets ai-factory/risks/ from the templates' .gitkeep; an existing adopter gets it
// from ids.js on the first /fc:risk write, because sync is pull-only and the manifest skips
// .gitkeep. Every fixture is a disposable directory under ai-factory/runs/tmp/, and every git
// command runs inside a scratch repo of its own, never against this one.
const { spawnSync } = require("node:child_process");
const TEMPLATES = "skills/ai-layout/templates";
const TEMPLATE_RISKS = `${TEMPLATES}/ai-factory/risks`;
const TEMPLATE_GITIGNORE = `${TEMPLATES}/ai-factory/.gitignore`;
const SCRATCH = "ai-factory/runs/tmp";
// git without any inherited repository pointer, so a scratch command never reaches this repo.
const GIT_ENV = Object.fromEntries(Object.entries(process.env).filter(([key]) => !/^GIT_/.test(key)));
const git = (cwd, ...args) => spawnSync("git", args, { cwd, encoding: "utf8", env: GIT_ENV });
function scratch(prefix, fn) {
	fs.mkdirSync(SCRATCH, { recursive: true });
	const dir = fs.mkdtempSync(path.join(path.resolve(SCRATCH), `risk-${prefix}-`));
	try {
		return fn(dir);
	} finally {
		fs.rmSync(dir, { recursive: true, force: true });
	}
}
function templateRisks() {
	if (!fs.existsSync(`${TEMPLATE_RISKS}/.gitkeep`)) throw new Error("templates carry no risks/");
}
// A repo adopted from this plugin, inside `dir`, with its own git repository.
function adopted(dir, name, gitignore) {
	const repo = path.join(dir, name);
	fs.mkdirSync(repo);
	if (gitignore !== undefined) fs.writeFileSync(path.join(repo, ".gitignore"), gitignore);
	const init = git(repo, "init", "-q");
	assert.equal(init.status, 0, `git init failed in the scratch repo: ${init.stderr}`);
	require("./skills/ai-layout/scripts/adopt").adopt(repo, process.cwd(), "Fixture Owner");
	return repo;
}
// Every path under `dir` with its bytes, or null when `dir` does not exist.
function tree(dir) {
	if (!fs.existsSync(dir)) return null;
	const out = {};
	const walk = (at) => {
		for (const entry of fs.readdirSync(at, { withFileTypes: true })) {
			const full = path.join(at, entry.name);
			if (entry.isDirectory()) walk(full);
			else out[path.relative(dir, full)] = fs.readFileSync(full, "utf8");
		}
	};
	walk(dir);
	return out;
}

test("layout", "template-carries-risks", () => {
	templateRisks();
	// check-entrypoints.sh resolves the repo from its own path, so a copy of it beside a copy of
	// what it reads checks the copy. Intact, the copy passes; without risks/, it must fail.
	scratch("entrypoints", (dir) => {
		for (const rel of ["skills/ai-layout/scripts/check-entrypoints.sh", TEMPLATES, "skills/ai-hooks/SKILL.md", "ai-factory/.gitignore", "ai-factory/.gitattributes"])
			fs.cpSync(rel, path.join(dir, rel), { recursive: true });
		const run = () => spawnSync("bash", [path.join(dir, "skills/ai-layout/scripts/check-entrypoints.sh")], { encoding: "utf8" });
		const intact = run();
		assert.equal(intact.status, 0, `check-entrypoints.sh fails on an intact copy of the templates: ${intact.stderr.trim()}`);
		fs.rmSync(path.join(dir, TEMPLATE_RISKS), { recursive: true });
		const missing = run();
		assert.notEqual(missing.status, 0, "check-entrypoints.sh passes when the templates carry no risks/");
		assert.match(missing.stderr, /\brisks\b/, `check-entrypoints.sh fails without naming risks: ${missing.stderr.trim()}`);
	});
});
test("layout", "adopt-creates-risks", () => {
	templateRisks();
	scratch("adopt", (dir) => {
		const repo = adopted(dir, "repo");
		assert.ok(fs.statSync(path.join(repo, "ai-factory/risks")).isDirectory(), "adoption does not create ai-factory/risks/");
		const ignored = git(repo, "check-ignore", "-q", "ai-factory/risks/x.md");
		assert.equal(ignored.status, 1, `ai-factory/risks/x.md is ignored after adoption (git check-ignore exit ${ignored.status})`);
	});
});
test("layout", "template-gitignore-silent", () => {
	const text = fs.readFileSync(TEMPLATE_GITIGNORE, "utf8");
	const lines = text.split("\n").filter((line) => /risks/.test(line));
	assert.deepEqual(lines, [], `${TEMPLATE_GITIGNORE} ignores risks: ${lines.join(", ")}`);
});
test("layout", "sync-keeps-user-ignore", () => {
	scratch("sync", (dir) => {
		const gitignore = "node_modules/\nai-factory/risks/\n";
		const repo = adopted(dir, "repo", gitignore);
		const risks = path.join(repo, "ai-factory/risks");
		const before = tree(risks);
		for (let i = 0; i < 2; i++) {
			const sync = spawnSync(process.execPath, [path.join(repo, "ai-factory/make/sync-adapters.js")], { cwd: repo, encoding: "utf8" });
			assert.equal(sync.status, 0, `sync-adapters.js run ${i + 1} failed: ${sync.stderr.trim()}`);
		}
		const check = spawnSync(process.execPath, ["skills/ai-layout/scripts/manifest.js", "check", repo, process.cwd()], { encoding: "utf8" });
		assert.equal(check.status, 0, `manifest.js check failed: ${(check.stdout + check.stderr).trim()}`);
		assert.equal(fs.readFileSync(path.join(repo, ".gitignore"), "utf8"), gitignore, "sync changed the repo's .gitignore");
		assert.deepEqual(tree(risks), before, "sync created or changed something under ai-factory/risks/");
		const staged = git(repo, "ls-files", "--cached", "--", "ai-factory/risks");
		assert.equal(staged.stdout, "", `sync staged files under ai-factory/risks/: ${staged.stdout.trim()}`);
		assert.equal(git(repo, "check-ignore", "-q", "ai-factory/risks/x.md").status, 0, "the repo's ignore rule for ai-factory/risks/ no longer applies");
	});
});
test("layout", "ids-creates-risks-dir", () => {
	scratch("ids", (dir) => {
		// An adopter from before this change: its layout has no risks/, and sync does not add one.
		const repo = adopted(dir, "repo");
		const risks = path.join(repo, "ai-factory/risks");
		fs.rmSync(risks, { recursive: true, force: true });
		const sync = spawnSync(process.execPath, [path.join(repo, "ai-factory/make/sync-adapters.js")], { cwd: repo, encoding: "utf8" });
		assert.equal(sync.status, 0, `sync-adapters.js failed: ${sync.stderr.trim()}`);
		assert.ok(!fs.existsSync(risks), "sync created ai-factory/risks/; it is pull-only");
		const ids = (...args) => spawnSync(process.execPath, [path.join(repo, "ai-factory/make/ids.js"), ...args], { cwd: repo, encoding: "utf8" });
		const spec = ids("new", "spec", "probe");
		assert.equal(spec.status, 0, `ids.js new spec failed: ${spec.stderr.trim()}`);
		const id = /^ai-factory\/specs\/([A-Z]{2,5}-[0-9]{3,})-probe\.md$/.exec(spec.stdout.trim())?.[1];
		assert.ok(id, `ids.js new spec printed no spec path: ${spec.stdout.trim()}`);
		const risk = ids("new", "risk", "probe", "--id", id);
		assert.equal(risk.status, 0, `ids.js new risk --id ${id} failed: ${risk.stderr.trim()}`);
		assert.equal(risk.stdout.trim(), `ai-factory/risks/${id}-probe.md`, "ids.js new risk printed an unexpected path");
		assert.ok(fs.existsSync(path.join(repo, risk.stdout.trim())), "ids.js new risk did not create the risk file");
	});
});

// ---- routing (plan 0023 Step 5: AC32, AC33) -----------------------------------------------
// The shipped models.yaml pins risk for Claude and leaves codex blank, under routing that stays
// off. Every run is a disposable payload under ai-factory/runs/tmp/: the real make/ helpers,
// the real risk and plan tasks, and a fake CLI that stands in for a gateway. No model CLI runs.
const TEMPLATE_MODELS = `${TEMPLATES}/ai-factory/models.yaml`;
const RISK_MODEL = "claude-opus-5-5";
function templateModels() {
	return fs.readFileSync(TEMPLATE_MODELS, "utf8");
}
// The template with routing turned on, and nothing else changed.
function enabledTemplate() {
	const text = templateModels();
	assert.match(text, /^  enabled: false$/m, `${TEMPLATE_MODELS} does not ship '  enabled: false'`);
	return text.replace(/^  enabled: false$/m, "  enabled: true");
}
// The template as it was before this change: the risk entry removed.
function withoutRisk(text) {
	return text.replace(/^    risk:\n(?:      .*\n)*/m, "");
}
// A payload with the real helpers and tasks, its models.yaml, and a fake CLI. `fn` gets the
// project root, a models.yaml writer and the helpers loaded from the payload.
function payload(prefix, fn) {
	return scratch(prefix, (dir) => {
		const root = path.join(dir, "project");
		const ai = path.join(root, "ai-factory");
		fs.mkdirSync(path.join(ai, "tasks"), { recursive: true });
		fs.cpSync(`${TEMPLATES}/ai-factory/make`, path.join(ai, "make"), { recursive: true });
		for (const task of ["risk", "plan"]) fs.copyFileSync(`${TEMPLATES}/ai-factory/tasks/${task}.md`, path.join(ai, "tasks", `${task}.md`));
		const configure = (body) => fs.writeFileSync(path.join(ai, "models.yaml"), body);
		const models = require(path.join(ai, "make/models.js"));
		return fn({ root, configure, models });
	});
}
// A gateway that serves no model: it records its argv and exits non-zero naming the model.
function fakeGateway(root) {
	const cli = path.join(root, "fake gateway");
	const capture = path.join(root, "capture.jsonl");
	fs.writeFileSync(
		cli,
		`#!/usr/bin/env node
const fs = require("node:fs");
process.stdin.resume();
process.stdin.on("end", () => {
	const args = process.argv.slice(2);
	fs.appendFileSync(${JSON.stringify(capture)}, JSON.stringify(args) + "\\n");
	const at = args.indexOf("--model");
	process.stderr.write("gateway: model not served: " + (at < 0 ? "<none>" : args[at + 1]) + "\\n");
	process.exitCode = 9;
});
`,
		{ mode: 0o700 },
	);
	const launches = () => (fs.existsSync(capture) ? fs.readFileSync(capture, "utf8").trim().split("\n").filter(Boolean).map(JSON.parse) : []);
	return { cli, launches };
}
const SELECTION_KEYS = ["task", "tool", "model", "source", "fallback", "routing_enabled"];
const pick = (selection) => Object.fromEntries(SELECTION_KEYS.map((key) => [key, selection[key]]));

test("routing", "template-routes-risk", () => {
	payload("parse", ({ models }) => {
		const parsed = models.parseModels(templateModels());
		assert.equal(parsed.routing.enabled, false, `${TEMPLATE_MODELS} must ship routing disabled`);
		if (!Object.hasOwn(parsed.routing.tasks, "risk")) throw new Error("no routing.tasks.risk");
		assert.deepEqual(parsed.routing.tasks.risk, { claude: RISK_MODEL, codex: "" }, "routing.tasks.risk differs from AC32");
		assert.deepEqual(Object.keys(parsed.routing.tasks), ["risk"], "the template ships a routing entry other than risk");
		assert.deepEqual([parsed.claude, parsed.codex, parsed.review], ["", "", ""], "the template pins a tool default");
	});
});
test("routing", "disabled-no-effect", () => {
	payload("disabled", ({ root, configure, models }) => {
		const shipped = templateModels();
		const before = withoutRisk(shipped);
		assert.ok(!/^    risk:/m.test(before), "the risk entry could not be removed for the comparison");
		const select = (tool, env) => pick(models.selectModel({ root, tool, task: "risk", env }));
		// Blank tool defaults (as shipped), and tool defaults set: the entry changes nothing either way.
		const variants = [
			["shipped", (text) => text],
			["tool defaults set", (text) => text.replace(/^claude:$/m, "claude: tool/claude").replace(/^codex:$/m, "codex: tool/codex")],
		];
		for (const [label, vary] of variants)
			for (const tool of ["claude", "codex"]) {
				configure(vary(before));
				const was = select(tool, {});
				configure(vary(shipped));
				const now = select(tool, {});
				assert.deepEqual(now, was, `${label}: ${tool} risk selection changed while routing is disabled`);
				assert.ok(["tool-default", "cli-default"].includes(now.source), `${label}: ${tool} risk is not the tool default (${now.source})`);
				assert.equal(now.routing_enabled, false);
				assert.ok(now.model !== RISK_MODEL, `${label}: ${tool} risk selected the pinned model while routing is disabled`);
			}
		// The interactive entry is the unchanged legacy procedure for both hosts.
		configure(shipped);
		for (const host of ["claude", "codex"]) {
			const run = models.runDispatch({ root, host, task: "risk", env: {} });
			assert.equal(run.status, 0, `dispatch --host ${host} --task risk failed: ${run.text}`);
			assert.equal(run.result.strategy, "legacy", `dispatch --host ${host} --task risk is not legacy while routing is disabled`);
		}
	});
});
test("routing", "enabled-unserved-model-errors", () => {
	payload("unserved", ({ root, configure, models }) => {
		const { cli, launches } = fakeGateway(root);
		// The plan mapping is the reference: an unserved model for plan must fail the same way.
		const enabled = enabledTemplate().replace(/^  tasks:\n/m, `  tasks:\n    plan:\n      claude: ${RISK_MODEL}\n`);
		configure(enabled);
		const env = Object.fromEntries(Object.entries(process.env).filter(([key]) => !/^(GIT_|MAKE|MODEL$|SDLC_|CLAUDE_CODE_SUBAGENT_MODEL$)/.test(key)));
		const headless = (task) =>
			spawnSync("make", ["-f", "ai-factory/make/ai.mk", "ai"], {
				cwd: root,
				env: { ...env, CMD: cli, TOOL: "claude", TASK: task, INPUT: "probe", INPUT_FILE: "", MODEL: "" },
				encoding: "utf8",
			});
		const shape = (result, task) => ({
			status: result.status,
			stderr: result.stderr
				.split("\n")
				.filter((line) => line.startsWith("model:") || line.startsWith("runner:") || line.startsWith("gateway:"))
				.map((line) => line.replaceAll(task, "<task>"))
				.join("\n"),
		});
		const results = {};
		for (const task of ["risk", "plan"]) {
			const before = launches().length;
			const result = headless(task);
			assert.notEqual(result.status, 0, `TASK=${task}: an unserved model unexpectedly succeeded`);
			assert.equal(launches().length, before + 1, `TASK=${task}: the unserved model was retried or never launched`);
			const args = launches().at(-1);
			assert.deepEqual(args.flatMap((arg, i) => (arg === "--model" ? [args[i + 1]] : [])), [RISK_MODEL], `TASK=${task} did not request ${RISK_MODEL}`);
			assert.ok(result.stderr.includes(`model: ${task} / claude: ${RISK_MODEL} (task default)`), `TASK=${task} did not disclose the routed model: ${result.stderr.trim()}`);
			assert.ok(result.stderr.includes(`gateway: model not served: ${RISK_MODEL}`), `TASK=${task} hid the gateway's error: ${result.stderr.trim()}`);
			results[task] = shape(result, task);
		}
		assert.deepEqual(results.risk, results.plan, "an unserved risk model fails differently from an unserved plan model");
		// Interactive: the routed directive for risk has the same shape as plan's.
		const directive = (task) => {
			const run = models.runDispatch({ root, host: "claude", task, env: {} });
			return { status: run.status, strategy: run.result?.strategy, text: run.text.replace(/d-[0-9]{14}-[0-9a-f]{6}/g, "<id>").replace(/fc-route-[a-z]+-[0-9a-f]{10}/g, "<agent>").replaceAll(task, "<task>") };
		};
		const risk = directive("risk");
		assert.equal(risk.strategy, "blocked", "dispatch --task risk did not stop before its routing adapter exists");
		assert.deepEqual(risk, directive("plan"), "dispatch --task risk differs from dispatch --task plan");
	});
});
test("routing", "codex-blank-falls-back", () => {
	payload("codex", ({ root, configure, models }) => {
		configure(enabledTemplate());
		const blank = models.selectModel({ root, tool: "codex", task: "risk", env: {} });
		assert.deepEqual(pick(blank), { task: "risk", tool: "codex", model: "", source: "cli-default", fallback: "no codex model for risk", routing_enabled: true });
		assert.equal(models.describe(blank), "risk / codex: CLI's own configuration (CLI default; routing fallback: no codex model for risk)");
		// The interactive entry says so too, and runs on the session's model.
		const run = models.runDispatch({ root, host: "codex", task: "risk", env: {} });
		assert.equal(run.status, 0, run.text);
		assert.equal(run.result.strategy, "inherit", `dispatch --host codex --task risk is not inherit: ${run.text}`);
		assert.ok(run.text.includes("risk / codex: CLI's own configuration (CLI default; routing fallback: no codex model for risk)"), `dispatch does not say codex fell back: ${run.text}`);
		// With a codex tool default, that default is used, and the fallback is still disclosed.
		configure(enabledTemplate().replace(/^codex:$/m, "codex: tool/codex"));
		const tool = models.selectModel({ root, tool: "codex", task: "risk", env: {} });
		assert.deepEqual([tool.model, tool.source, tool.fallback], ["tool/codex", "tool-default", "no codex model for risk"]);
		assert.equal(models.describe(tool), "risk / codex: tool/codex (tool default; routing fallback: no codex model for risk)");
	});
});

// ---- knowledge (plan 0023 Step 6: AC31) ---------------------------------------------------
// Static reads of the seam and of the agent. That the agent consults a configured source, and
// says nothing in an unconfigured repo, is proved by the host runs of plan 0023 Step 10.
const KNOWLEDGE = ["ai-factory/docs/knowledge.md", "skills/ai-layout/templates/ai-factory/docs/knowledge.md"];
const AGENT_COPIES = [AGENT, "skills/ai-layout/templates/ai-factory/agents/risk.md"];
function knowledgeText(rel) {
	if (!fs.existsSync(rel)) throw new Error(`${rel} does not exist`);
	return fs.readFileSync(rel, "utf8");
}
// The executor sentence: the first paragraph of "Who consults a source", which names the
// agents that may consult a source and the commands that reach one through them.
function executors(rel) {
	const text = knowledgeText(rel);
	const at = text.indexOf("\n## Who consults a source\n");
	assert.ok(at >= 0, `${rel} has no '## Who consults a source' section`);
	const body = text.slice(at).split("\n## ")[1].split("\n").slice(1).join("\n").trim();
	return flatten(body.split(/\n\s*\n/)[0]);
}
test("knowledge", "knowledge-lists-risk", () => {
	for (const rel of KNOWLEDGE) {
		const sentence = executors(rel);
		const [agents, commands] = sentence.split(/ — /);
		assert.ok(commands, `${rel}: the executor sentence has no agents — commands split`);
		assert.ok(agents.includes("`risk`"), `${rel}: knowledge.md does not list risk among the agents`);
		assert.ok(commands.includes("`/fc:risk`"), `${rel}: knowledge.md does not list /fc:risk among the commands`);
		// The executors already listed stay listed.
		for (const name of ["explorer", "specifier", "planner", "analyst", "architect", "reviewer"])
			assert.ok(agents.includes(`\`${name}\``), `${rel}: the executor sentence lost \`${name}\``);
		for (const name of ["explore", "spec", "plan", "analyse", "design", "adr", "review"])
			assert.ok(commands.includes(`\`/fc:${name}\``), `${rel}: the executor sentence lost \`/fc:${name}\``);
	}
});
test("knowledge", "knowledge-copies-equal", () => {
	const [here, template] = KNOWLEDGE.map(knowledgeText);
	assert.ok(here === template, `${KNOWLEDGE[0]} has drifted from ${KNOWLEDGE[1]}`);
});
test("knowledge", "agent-names-only-seam", () => {
	// The source kinds are read from the seam's own Kinds table, so a new kind is covered here
	// without an edit. Providers, servers and addresses are the ones check-adapters.sh sweeps for.
	const seam = knowledgeText(KNOWLEDGE[1]);
	const kindsAt = seam.indexOf("\n## Kinds\n");
	assert.ok(kindsAt >= 0, `${KNOWLEDGE[1]} has no '## Kinds' section`);
	const kinds = [...seam.slice(kindsAt).split("\n## ")[1].matchAll(/^\| `([a-z]+)` \|/gm)].map((m) => m[1]);
	assert.ok(kinds.length > 0, `${KNOWLEDGE[1]}: the Kinds table lists no kind`);
	const banned = [
		[/knowledge_base\.md/, "the knowledge declaration"],
		[/(^|[^A-Za-z])MCP([^A-Za-z]|$)/i, "an MCP server"],
		[/mcp__/, "a server's tool name"],
		[/https?:\/\//, "an address"],
		[/Context7/i, "a provider"],
		...kinds.map((kind) => [new RegExp(`\`${kind}\``), `the source kind \`${kind}\``]),
	];
	for (const rel of AGENT_COPIES) {
		if (rel !== AGENT && !fs.existsSync(rel)) continue;
		const text = rel === AGENT ? agentText() : fs.readFileSync(rel, "utf8");
		assert.ok(text.includes("`ai-factory/docs/knowledge.md`"), `${rel} does not name ai-factory/docs/knowledge.md`);
		for (const [pattern, what] of banned) assert.doesNotMatch(text, pattern, `${rel} names ${what} (${pattern})`);
	}
});

// ---- consumers (plan 0023 Step 7: AC24–AC29) ----------------------------------------------
// Static reads of the specifier, planner and reviewer procedures, each as its source and as the
// adopted copy materialize-agents.js delivers. That the agents act on an assessment is proved
// by the host runs of plan 0023 Step 10, not here. The reviewer's checks 1–7 and its verdict
// schema are compared with `main`, where they predate this feature.
const TEMPLATE_AGENTS = `${TEMPLATES}/ai-factory/agents`;
const CONSUMERS = ["specifier", "planner", "reviewer"];
const consumerCopies = (name) =>
	[`agents/${name}.md`, `${TEMPLATE_AGENTS}/${name}.md`].map((rel) => {
		if (!fs.existsSync(rel)) throw new Error(`${rel} does not exist`);
		return [rel, fs.readFileSync(rel, "utf8")];
	});
// The paragraph or list item (blank line or list marker bounded) that names ai-factory/risks/,
// flattened. Exactly one per procedure: the consumer's whole rule lives there.
function riskPassage(rel, text) {
	const blocks = text.split(/\n(?=\s*\n|\s*(?:[-*+]|\d+\.) )/).filter((block) => block.includes("ai-factory/risks/"));
	if (blocks.length === 0) throw new Error(`${rel} never mentions ai-factory/risks/`);
	assert.equal(blocks.length, 1, `${rel} names ai-factory/risks/ in ${blocks.length} places; keep the rule in one passage`);
	return flatten(blocks[0]).trim();
}
const NO_ASSESSMENT = "No applicable assessment: nothing here changes.";
// The commit before plan 0023 landed. Comparing against `main` stopped working once 0023 merged.
const BASELINE = "64ad3bcd2c5a8df3d40a3046fc87df6d0278a8a5";
const atMain = (rel) => {
	const shown = spawnSync("git", ["show", `${BASELINE}:${rel}`], { encoding: "utf8" });
	assert.equal(shown.status, 0, `git show ${BASELINE}:${rel} failed: ${shown.stderr.trim()}`);
	return shown.stdout;
};
// The reviewer's numbered checks, from "Check, in priority order:" to the first blank line.
function reviewerChecks(rel, text) {
	const at = text.indexOf("Check, in priority order:\n");
	assert.ok(at >= 0, `${rel} has no 'Check, in priority order:' list`);
	return text.slice(at).split("\n\n")[0];
}
// The verdict schema: from "Output exactly one JSON object:" to the closing brace.
function verdictSchema(rel, text) {
	const match = /Output exactly one JSON object:\n\{\n[\s\S]*?\n\}\n?/.exec(text);
	assert.ok(match, `${rel} has no verdict schema block`);
	return match[0].trimEnd();
}

test("consumers", "latest-section-only", () => {
	for (const name of CONSUMERS)
		for (const [rel, text] of consumerCopies(name)) {
			const rule = riskPassage(rel, text);
			assert.match(rule, /read only (its|the) latest `## Reassessment` section/i, `${rel} does not read only the latest Reassessment section`);
			assert.match(rule, /or the body above the first one when it has none/i, `${rel} does not fall back to the initial body when there is no Reassessment`);
		}
});
test("consumers", "specifier-open-questions", () => {
	for (const [rel, text] of consumerCopies("specifier")) {
		const rule = riskPassage(rel, text);
		assert.match(rule, /`ai-factory\/risks\/<ID>-\*\.md`[^.]*this spec's ID/, `${rel} does not look up the risk file by this spec's ID`);
		assert.match(rule, /[Ee]very `open` finding of severity `blocker` or `major`[^.]*goes under Open questions/, `${rel} does not put open blocker and major findings under Open questions`);
		assert.match(rule, /the spec cites (that|the) risk file's path/, `${rel} does not cite the risk file's path in the spec`);
		assert.match(rule, /finding that is `mitigated`, `accepted` or `minor` does not go there/, `${rel} does not keep mitigated, accepted and minor findings out of Open questions`);
	}
});
test("consumers", "planner-mitigations", () => {
	for (const [rel, text] of consumerCopies("planner")) {
		const rule = riskPassage(rel, text);
		assert.match(rule, /`ai-factory\/risks\/<spec ID>-\*\.md`/, `${rel} does not look up the risk file by the spec's ID`);
		assert.match(rule, /spec and its plan share one risk file/, `${rel} does not say a spec and its plan share one risk file (AC36)`);
		assert.match(rule, /[Ee]ach mitigation[^.]*becomes a step or a risk check/, `${rel} does not turn each mitigation into a step or a risk check`);
		assert.match(rule, /finding id[^.]*risk file's path|risk file's path[^.]*finding id/, `${rel} does not cite the finding and the risk file`);
	}
});
test("consumers", "reviewer-mitigation-check", () => {
	const main = atMain("agents/reviewer.md");
	for (const [rel, text] of consumerCopies("reviewer")) {
		const rule = riskPassage(rel, text);
		const checks = reviewerChecks(rel, text);
		const before = reviewerChecks("main:agents/reviewer.md", main);
		assert.ok(checks.startsWith(`${before}\n8. `), `${rel}: checks 1–7 differ from main, or check 8 does not follow check 7`);
		assert.equal(verdictSchema(rel, text), verdictSchema("main:agents/reviewer.md", main), `${rel}: the verdict schema differs from main`);
		assert.ok(rule.startsWith("8. "), `${rel}: the risk rule is not check 8`);
		assert.ok(checks.includes(rule.slice(0, 40)), `${rel}: the risk rule is not in the check list`);
		// AC27: applicability by ID or by the Target: line.
		assert.match(rule, /carries the ID of the spec or plan (under review|being reviewed)/, `${rel} does not apply an assessment by the spec or plan ID`);
		assert.match(rule, /`Target:` line matches the change under review/, `${rel} does not apply a change assessment by its Target: line`);
		assert.match(rule, /`working-tree <branch>`[^.]*`branch <branch>`[^.]*branch names are equal/, `${rel} does not match working-tree and branch targets by branch name`);
		assert.match(rule, /every `open` or `mitigated` finding whose mitigation[^.]*(not|never) implement[^.]*as a finding/i, `${rel} does not report unimplemented open or mitigated mitigations as findings`);
		assert.match(rule, /existing verdict shape|verdict below/, `${rel} does not keep the findings in the existing verdict shape`);
		assert.match(rule, /[Ss]kip `accepted` findings/, `${rel} does not skip accepted findings`);
	}
});
test("consumers", "no-assessment-unchanged", () => {
	// AC28, the procedures: each rule is conditional on an applicable file and says so last.
	for (const name of CONSUMERS)
		for (const [rel, text] of consumerCopies(name)) {
			const rule = riskPassage(rel, text);
			assert.match(rule, /^(?:8\. [^.—]+— )?(?:[Ii]f|[Oo]nly when)\b[^.]*ai-factory\/risks\//, `${rel}: the risk rule is not conditional on an applicable file`);
			assert.ok(rule.endsWith(NO_ASSESSMENT), `${rel}: the risk rule does not end '${NO_ASSESSMENT}'`);
		}
	// AC28, the runner: with no risks/ file, the headless review input is what main's runner
	// selects. Two scratch repos with the same history differ only in the committed make/ they run.
	const MAKE_DIR = `${TEMPLATES}/ai-factory/make`;
	const listed = spawnSync("git", ["ls-tree", "-r", "--name-only", BASELINE, "--", `${MAKE_DIR}/`], { encoding: "utf8" });
	assert.equal(listed.status, 0, `git ls-tree ${BASELINE} failed: ${listed.stderr.trim()}`);
	const mainMake = listed.stdout.split("\n").filter(Boolean);
	assert.ok(mainMake.some((rel) => rel.endsWith("/runner.js")), "main has no runner.js");
	const STAMP = { GIT_AUTHOR_NAME: "Fixture", GIT_AUTHOR_EMAIL: "f@example.invalid", GIT_COMMITTER_NAME: "Fixture", GIT_COMMITTER_EMAIL: "f@example.invalid", GIT_AUTHOR_DATE: "2026-01-01T00:00:00Z", GIT_COMMITTER_DATE: "2026-01-01T00:00:00Z" };
	const run = (cwd, ...args) => {
		const result = spawnSync("git", args, { cwd, encoding: "utf8", env: { ...GIT_ENV, ...STAMP } });
		assert.equal(result.status, 0, `git ${args.join(" ")} failed in a scratch repo: ${result.stderr.trim()}`);
	};
	const write = (repo, rel, body) => {
		fs.mkdirSync(path.dirname(path.join(repo, rel)), { recursive: true });
		fs.writeFileSync(path.join(repo, rel), body);
	};
	const fixture = (repo, make) => {
		fs.mkdirSync(repo);
		run(repo, "init", "-q", "-b", "main");
		make(path.join(repo, "ai-factory/make"));
		write(repo, ".gitignore", "ai-factory/runs/\n");
		write(repo, "ai-factory/specs/ABC123-probe.md", "# ABC123 — Probe\n");
		write(repo, "src/app.js", "module.exports = 1;\n");
		run(repo, "add", "-A");
		run(repo, "commit", "-q", "-m", "base");
		run(repo, "checkout", "-q", "-b", "feature");
		write(repo, "src/app.js", "module.exports = 2;\n");
		run(repo, "commit", "-q", "-am", "branch change");
		write(repo, "src/staged.js", "staged\n");
		run(repo, "add", "src/staged.js");
		write(repo, "src/app.js", "module.exports = 3;\n");
		write(repo, "src/untracked.js", "untracked\n");
		write(repo, "fixture.diff", "diff --git a/src/app.js b/src/app.js\n--- a/src/app.js\n+++ b/src/app.js\n@@ -1 +1 @@\n-module.exports = 1;\n+module.exports = 4;\n");
		assert.ok(!fs.existsSync(path.join(repo, "ai-factory/risks")), "the fixture has a risks/ directory");
	};
	const inputs = (repo) => {
		const probe = `const { reviewInput } = require(${JSON.stringify(path.join(repo, "ai-factory/make/runner.js"))});
const out = {};
for (const [label, env] of [["working-tree", {}], ["branch", { REVIEW_SCOPE: "branch" }], ["supplied", { REVIEW_SCOPE: "supplied", INPUT_FILE: "fixture.diff" }]]) {
	const got = reviewInput(env);
	out[label] = { selection: got.selection, input: String(got.input), empty: got.empty };
}
process.stdout.write(JSON.stringify(out));`;
		const result = spawnSync(process.execPath, ["-e", probe], { cwd: repo, encoding: "utf8", env: GIT_ENV });
		assert.equal(result.status, 0, `reviewInput failed in ${path.basename(repo)}: ${result.stderr.trim()}`);
		return JSON.parse(result.stdout);
	};
	scratch("review-input", (dir) => {
		const now = path.join(dir, "now");
		const before = path.join(dir, "before");
		fixture(now, (make) => fs.cpSync(MAKE_DIR, make, { recursive: true }));
		fixture(before, (make) => {
			for (const rel of mainMake) write(make, path.relative(MAKE_DIR, rel), atMain(rel));
		});
		const [got, was] = [inputs(now), inputs(before)];
		for (const scope of ["working-tree", "branch", "supplied"]) {
			assert.ok(!got[scope].empty, `the ${scope} fixture selected nothing`);
			assert.deepEqual(got[scope], was[scope], `reviewInput for ${scope} differs from main's runner with no risks/ file`);
		}
	});
});
test("consumers", "plan-task-unchanged", () => {
	// AC29: /fc:plan is unchanged by this feature. tasks/plan.md carries uncommitted edits of plans
	// 0022 and 0024, so `main` is no baseline for it; what this feature must not add is any rule
	// about risk files, which lives in the planner agent alone.
	const rel = `${TEMPLATES}/ai-factory/tasks/plan.md`;
	const text = fs.readFileSync(rel, "utf8");
	for (const pattern of [/ai-factory\/risks/, /\brisks\//, /\/fc:risk\b/, /`risk`/, /\bassessment\b/i, /\bmitigation/i])
		assert.doesNotMatch(text, pattern, `${rel} mentions risk assessments (${pattern}); /fc:plan must stay unchanged`);
});

// ---- start (plan 0023 Step 8, AC29) -------------------------------------------------------
// Static reads of the start task: rule 3 names /fc:risk as an optional next step only when a
// risk trigger is present, and the "never return commands" sentence states that one mention as
// its only exception. The JSON contract is unchanged: the allowlist and validateStartResult stay
// as on `main`. That the classifier obeys is proved by the host runs of plan 0023 Step 10.
const START = `${TEMPLATES}/ai-factory/tasks/start.md`;
const START_MODELS = `${TEMPLATES}/ai-factory/make/models.js`;
function startText() {
	if (!fs.existsSync(START)) throw new Error(`${START} does not exist`);
	return fs.readFileSync(START, "utf8");
}
// A numbered rule of the start task, from "N. " at a line start to the next rule or blank line.
function startRule(text, n) {
	const match = new RegExp(`^${n}\\. [\\s\\S]*?(?=\\n\\d+\\. |\\n\\s*\\n|(?![\\s\\S]))`, "m").exec(text);
	assert.ok(match, `${START} has no rule ${n}`);
	return flatten(match[0]).trim();
}
// The sentence of rule 3 that names /fc:risk.
function riskSuggestion(text) {
	if (!/\/fc:risk\b/.test(text)) throw new Error("start.md never names /fc:risk");
	const rule = startRule(text, 3);
	const named = sentences(rule).filter((sentence) => /\/fc:risk\b/.test(sentence));
	assert.equal(named.length, 1, `${START}: rule 3 names /fc:risk in ${named.length} sentences, not one`);
	return named[0];
}
test("start", "start-rule3-suggests-risk", () => {
	const text = startText();
	const suggestion = riskSuggestion(text);
	assert.match(suggestion, /\breason names \/fc:risk\b/, `${START}: rule 3 does not put /fc:risk in reason`);
	assert.match(suggestion, /\boptional next step\b/, `${START}: rule 3 does not call /fc:risk an optional next step`);
	// Outside rule 3, /fc:risk appears only in the exception to "Never return commands".
	const outside = sentences(text.replace(/^3\. [\s\S]*?(?=\n\d+\. )/m, "")).filter((sentence) => /\/fc:risk\b/.test(sentence));
	assert.equal(outside.length, 1, `${START} names /fc:risk outside rule 3 in ${outside.length} sentences; only the exception may`);
	const flat = flatten(text);
	assert.match(
		flat,
		/Never return commands, rewritten input, model options, or a next-phase chain\. The one exception is the optional \/fc:risk mention that rule 3 allows in reason; it is never the routed task\./,
		`${START}: the 'Never return commands' rule does not state the /fc:risk mention as its one exception`,
	);
});
test("start", "start-no-trigger-no-suggestion", () => {
	// AC29, the negative: the suggestion is conditional on a risk trigger and absent without one.
	const suggestion = riskSuggestion(startText());
	assert.match(suggestion, /^Only when one of these risk triggers is present\b/, `${START}: the /fc:risk suggestion is not conditional on a risk trigger`);
	// The negative clause follows the suggestion directly (sentences() splits it off at the ';').
	const rule = startRule(startText(), 3);
	assert.ok(
		rule.includes(`${suggestion} with no risk trigger, reason never names it.`),
		`${START}: rule 3 does not say, right after the suggestion, that reason omits /fc:risk with no risk trigger`,
	);
	// The triggers the condition refers to are rule 3's own list.
	for (const trigger of ["uncertain requirements", "authorization", "public contracts", "migrations", "dependencies", "service ownership"])
		assert.ok(rule.includes(trigger), `${START}: rule 3 no longer lists the trigger '${trigger}'`);
});
test("start", "start-allowlist-unchanged", () => {
	const text = startText();
	const main = atMain(START);
	assert.equal(startRule(text, 6), startRule(main, 6), `${START}: rule 6 (the destination allowlist) differs from main`);
	assert.doesNotMatch(startRule(text, 6), /\brisk\b/, `${START}: rule 6 names risk as a destination`);
	const m = require(path.resolve(START_MODELS));
	assert.throws(() => m.validateStartResult({ status: "route", task: "risk", reason: "x" }), /invalid start result/, "validateStartResult accepts task risk");
	// The suggestion is data in reason, so a planned route that names it still validates.
	assert.deepEqual(
		m.validateStartResult({ status: "route", task: "spec", reason: "Touches authorization. Optional next step: /fc:risk." }),
		{ status: "route", task: "spec", reason: "Touches authorization. Optional next step: /fc:risk." },
	);
	const allowlist = (source) => {
		const match = /^const START_TASKS = (\[[^\]]*\]);$/m.exec(source);
		assert.ok(match, "models.js has no START_TASKS line");
		return JSON.parse(match[1]);
	};
	assert.deepEqual(allowlist(fs.readFileSync(START_MODELS, "utf8")), allowlist(atMain(START_MODELS)), "START_TASKS differs from main");
	const validator = (source) => {
		const match = /^function validateStartResult\(value\) \{\n[\s\S]*?\n\}\n/m.exec(source);
		assert.ok(match, "models.js has no validateStartResult function");
		return match[0];
	};
	assert.equal(validator(fs.readFileSync(START_MODELS, "utf8")), validator(atMain(START_MODELS)), "validateStartResult differs from main");
});

// ---- docs (plan 0023 Step 9: AC3, the AC20 citation, AC34, AC35) ---------------------------
// Static reads of the docs, the two plugin manifests and the CHANGELOG. Each counted number is
// compared with the files it counts, never with a literal, so the next command changes it once.
const DOC = (rel) => {
	if (!fs.existsSync(rel)) throw new Error(`${rel} does not exist`);
	return fs.readFileSync(rel, "utf8");
};
const WORKFLOW = "ai-factory/docs/workflow.md";
const FLEET = "ai-factory/docs/fleet.md";
const FACTORY = "FACTORY.md";
const README = "README.md";
const LAYOUT_SKILL = "skills/ai-layout/SKILL.md";
const AGENTS_COPIES = ["ai-factory/AGENTS.md", `${TEMPLATES}/ai-factory/AGENTS.md`];
const MANIFESTS = [".claude-plugin/plugin.json", ".codex-plugin/plugin.json"];
const CHANGELOG = "CHANGELOG.md";
const SPEC = "ai-factory/specs/0023-risk-agent.md";

test("docs", "no-eight-agents", () => {
	// AC34. The count says nine wherever a doc counts the agents.
	for (const rel of [WORKFLOW, FLEET, FACTORY, README]) {
		const flat = flatten(DOC(rel));
		assert.doesNotMatch(flat, /\beight (?:sub)?agents\b/i, `${rel} still says "eight agents"`);
	}
	for (const rel of [WORKFLOW, FLEET, FACTORY])
		assert.match(flatten(DOC(rel)), /\bnine (?:sub)?agents\b/i, `${rel} does not say "nine agents"`);
	// The canonical agents really are nine, risk among them.
	const agents = fs.readdirSync("agents").filter((name) => name.endsWith(".md"));
	assert.equal(agents.length, 9, `agents/ holds ${agents.length} agents, not nine`);
	assert.ok(agents.includes("risk.md"), "agents/ has no risk.md");
	// fleet.md names the agents it counts.
	const fleetRow = flatten(DOC(FLEET)).match(/nine agents \(([^)]*)\)/i)?.[1];
	assert.ok(fleetRow, `${FLEET} does not list the nine agents in parentheses`);
	for (const name of agents.map((file) => file.replace(/\.md$/, "")))
		assert.ok(new RegExp(`\\b${name}\\b`).test(fleetRow), `${FLEET}'s agent list omits ${name}`);
});
test("docs", "command-counts-25", () => {
	const count = fs.readdirSync("commands").filter((name) => name.endsWith(".md")).length;
	assert.equal(count, 25, `commands/ holds ${count} commands, not 25`);
	for (const rel of [README, WORKFLOW, LAYOUT_SKILL]) {
		const said = [...flatten(DOC(rel)).matchAll(/\ball (\d+) (?:native Claude |Claude slash |`\/fc:\*` )commands\b/g)].map((m) => Number(m[1]));
		assert.ok(said.length > 0, `${rel} states no command count`);
		for (const n of said) assert.equal(n, count, `${rel} says all ${n} commands; commands/ holds ${count}`);
	}
});
test("docs", "agents-md-lists-risk", () => {
	// AC34, both copies; SKILL.md's rule keeps each under 60 lines.
	for (const rel of AGENTS_COPIES) {
		const text = DOC(rel);
		const slash = text.split("\n").filter((line) => /^Slash commands:/.test(line));
		assert.equal(slash.length, 1, `${rel} has ${slash.length} "Slash commands:" lines, not one`);
		assert.ok(slash[0].split(/\s+/).includes("/fc:risk"), `${rel} does not list /fc:risk among the slash commands`);
		assert.ok(text.replace(/\n$/, "").split("\n").length < 60, `${rel} is 60 lines or more`);
	}
});
test("docs", "plugin-json-mentions-risk", () => {
	// AC34: both manifests name the agent and the task, and say the same thing.
	const descriptions = MANIFESTS.map((rel) => {
		const description = JSON.parse(DOC(rel)).description;
		assert.equal(typeof description, "string", `${rel} has no description`);
		assert.match(description, /\brisk\b[^.;]*\bagents?\b|\bagents?\b[^.;]*\brisk\b/, `${rel}: the description does not name the risk agent`);
		assert.ok(description.includes("/fc:risk"), `${rel}: the description does not name the /fc:risk task`);
		return description;
	});
	assert.equal(descriptions[0], descriptions[1], `${MANIFESTS[0]} and ${MANIFESTS[1]} describe the plugin differently`);
});
// The plan 0023 block of the CHANGELOG release entry that holds it: from its bold heading
// (Unreleased, or the released form) to the next bold heading line or the next release.
function changelogBlock() {
	const text = DOC(CHANGELOG);
	const entries = text.split(/\n## /).slice(1);
	assert.ok(entries.length, `${CHANGELOG} has no release entry`);
	const top = entries.find((entry) => /^\*\*(?:Unreleased — plan|Plan) 0023\b/m.test(entry));
	if (!top) throw new Error(`no ${CHANGELOG} release entry has a plan 0023 block`);
	const at = top.search(/^\*\*(?:Unreleased — plan|Plan) 0023\b/m);
	const rest = top.slice(at);
	const end = rest.slice(2).search(/\n\*\*[^*\n]+\*\*\n/);
	return end < 0 ? rest : rest.slice(0, end + 2);
}
test("docs", "changelog-breaking-risk", () => {
	// AC35, and every name Step 9 lists.
	const flat = flatten(changelogBlock());
	assert.match(flat, /\*\*Breaking for adopted repos\.\*\*/, `${CHANGELOG}: the plan 0023 block is not marked breaking for adopted repos`);
	for (const name of ["`planner`", "`specifier`", "`reviewer`", "`start`", "`models.yaml`"])
		assert.ok(flat.includes(name), `${CHANGELOG}: the plan 0023 block does not name the changed ${name} template`);
	assert.match(flat, /`risk` agent/, `${CHANGELOG}: the plan 0023 block does not name the risk agent`);
	assert.ok(flat.includes("/fc:risk"), `${CHANGELOG}: the plan 0023 block does not name /fc:risk`);
	assert.ok(flat.includes("ai-factory/risks/"), `${CHANGELOG}: the plan 0023 block does not name ai-factory/risks/`);
	assert.match(flat, /\bcommitted by default\b/, `${CHANGELOG}: the plan 0023 block does not say ai-factory/risks/ is committed by default`);
	assert.match(flat, /\b(?:gitignore|ignore)\b/, `${CHANGELOG}: the plan 0023 block does not say a repo may ignore ai-factory/risks/`);
	assert.match(flat, /\bnetwork\b/, `${CHANGELOG}: the plan 0023 block does not name the network exception`);
	assert.ok(flat.includes(ADR_ID), `${CHANGELOG}: the plan 0023 block does not cite ADR ${ADR_ID}`);
	assert.ok(flat.includes("routing.tasks.risk"), `${CHANGELOG}: the plan 0023 block does not name routing.tasks.risk`);
});
test("docs", "no-old-names", () => {
	// AC3, over the docs this step edits.
	const docs = [WORKFLOW, FLEET, FACTORY, README, LAYOUT_SKILL, ...AGENTS_COPIES, ...MANIFESTS, CHANGELOG, "ai-factory/docs/architecture.md"];
	for (const rel of docs) {
		const text = DOC(rel);
		for (const pattern of [/\bassessor\b/i, /\bassessments\b/i, /\/fc:assess\b/, /`assess`/, /\bfc-assess\b/, /TASK=assess\b/])
			assert.doesNotMatch(text, pattern, `${rel} uses an old name (${pattern})`);
	}
});
test("docs", "spec-cites-adr", () => {
	// AC20, the spec's half: the spec names the ADR the adr group finds, by its ID and its path.
	const naming = adrs().filter((adr) => SPEC_0012.test(flatten(adr.text)) && AC10.test(flatten(adr.text)));
	assert.equal(naming.length, 1, `expected one ADR naming the spec 0012 AC10 exception, found ${naming.length}`);
	const file = path.basename(naming[0].rel);
	const id = file.split("-")[0];
	const spec = DOC(SPEC);
	assert.ok(spec.includes(`ai-factory/adr/${file}`) || spec.includes(`../adr/${file}`), `${SPEC} does not cite ${naming[0].rel} by its path`);
	assert.match(spec, new RegExp(`\\b${id}\\b`), `${SPEC} does not cite the ADR by its ID ${id}`);
});

// ---- groups that later steps of plan 0023 fill --------------------------------------------
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
		failures.push(`${name}: no cases yet (plan 0023 Step ${step} adds them)`);
for (const line of failures) console.error(`FAIL ${line}`);
if (failures.length) process.exitCode = 1;
else console.log(`risk ok — ${passed} cases (${selected})`);
NODE
