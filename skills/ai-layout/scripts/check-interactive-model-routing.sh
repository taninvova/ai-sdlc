#!/usr/bin/env bash
# Interactive model routing: the entry points run dispatch before reading their task, dispatch
# names a worker whose host configuration pins the selected model, and every way that cannot be
# honored stops the task instead of running it on the chat's own model. Deterministic: no host
# session or model is started; host behavior itself is covered by the smoke runs in the workflow.
set -euo pipefail
cd "$(dirname "$0")/../../.."
node <<'NODE'
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const { boundary } = require("./skills/ai-layout/templates/ai-factory/make/safe-files.js");
const repo = process.cwd();
const TEMPLATE = path.join(repo, "skills/ai-layout/templates/ai-factory");
const models = require(path.join(TEMPLATE, "make/models.js"));
const safe = boundary(path.join(repo, "ai-factory"));
const scratch = safe.scratch(path.join(repo, "ai-factory/runs/tmp"));
const cases = [];
const check = (name, fn) => { fn(); cases.push(name); };
try {
	// --- entry points: dispatch comes first, in every task entry point of both hosts -------------
	check("entry points", () => {
		const tasks = fs.readdirSync(path.join(TEMPLATE, "tasks")).filter((f) => f.endsWith(".md")).map((f) => path.basename(f, ".md"));
		for (const task of tasks) {
			for (const [host, file] of [["claude", `commands/${task}.md`], ["codex", `codex-skills/t4-${task}/SKILL.md`]]) {
				const body = fs.readFileSync(file, "utf8");
				const preamble = models.entryPreamble(host, task);
				assert.ok(body.includes(preamble), `${file} lacks the routing step`);
				assert.ok(body.indexOf(preamble) < body.indexOf(`ai-factory/tasks/${task}.md\``), `${file} reads the task before dispatch`);
				assert.match(body, /Unless the directive routed the task to a worker/);
				if (/native delegation/.test(body)) assert.match(body, /applies only to the legacy and inherit directives/, `${file} keeps an unconditional same-session fallback`);
			}
		}
		const generated = fs.readFileSync(path.join(TEMPLATE, "make/sync-adapters.js"), "utf8");
		assert.ok(generated.includes('models.entryPreamble("claude", name)') && generated.includes('models.entryPreamble("codex", name)'), "project adapters must carry the routing step");
		assert.match(fs.readFileSync("commands/quick.md", "utf8"), /^allowed-tools: .*\bAgent\b/m, "quick must be able to launch its routed worker");
	});

	// --- a scratch project -----------------------------------------------------------------------
	const root = path.join(scratch, "project with spaces");
	fs.mkdirSync(root);
	fs.cpSync(TEMPLATE, path.join(root, "ai-factory"), { recursive: true });
	fs.writeFileSync(path.join(root, "ai-factory/tasks/deploy-notes.md"), "---\ndescription: Custom project task\n---\nWrite deploy notes.\n\nInput: $ARGUMENTS\n");
	const yaml = path.join(root, "ai-factory/models.yaml");
	const run = (args, env = {}) => spawnSync(process.execPath, ["ai-factory/make/models.js", ...args], { cwd: root, encoding: "utf8", env: { ...process.env, CLAUDE_CODE_SUBAGENT_MODEL: "", ...env } });
	const dispatch = (host, task, extra = [], env) => run(["dispatch", "--host", host, "--task", task, ...extra], env);
	const sync = (selection = "routing") => {
		const r = spawnSync(process.execPath, ["ai-factory/make/sync-adapters.js", `--adapters=${selection}`], { cwd: root, encoding: "utf8" });
		assert.equal(r.status, 0, r.stderr);
	};
	const records = () => { const f = path.join(root, "ai-factory/runs/routing.jsonl"); return fs.existsSync(f) ? fs.readFileSync(f, "utf8").trim().split("\n").filter(Boolean).map(JSON.parse) : []; };
	const agentOf = (out) => /subagent_type `([^`]+)`|agent_type `([^`]+)`/.exec(out)?.slice(1).find(Boolean);
	const dispatchId = (out) => /dispatch (d-[0-9]{14}-[0-9a-f]{6})/.exec(out)?.[1];
	const routeFiles = (dir) => (fs.existsSync(path.join(root, dir)) ? fs.readdirSync(path.join(root, dir)).filter((n) => n.startsWith("t4-route-")).sort() : []);
	const hostile = `gateway/"planning" $(touch pwned) 'claude'`;
	const config = (enabled, testClaude = "gateway/testing-claude") =>
		`claude:\ncodex:\nreview:\nrouting:\n  enabled: ${enabled}\n  tasks:\n    plan:\n      claude: ${JSON.stringify(hostile)}\n      codex: gateway/planning-codex\n    test:\n      claude: ${testClaude}\n      codex: gateway/testing-codex\n    check:\n      claude: gateway/review-claude\n      codex: gateway/review-codex\n    run:\n      codex: gateway/implementation-codex\n    deploy-notes:\n      claude: gateway/custom\n    ghost:\n      claude: gateway/nothing\n`;

	check("routing off is the legacy path", () => {
		for (const host of ["claude", "codex"]) {
			const r = dispatch(host, "plan");
			assert.equal(r.status, 0, r.stdout + r.stderr);
			assert.match(r.stdout, /directive: legacy/);
		}
		fs.writeFileSync(yaml, config("false"));
		assert.match(dispatch("claude", "plan").stdout, /directive: legacy/);
		assert.deepEqual(records(), [], "the legacy path records nothing");
		fs.unlinkSync(yaml);
		assert.match(dispatch("claude", "plan").stdout, /directive: legacy/);
	});

	check("missing agents block, never fall back", () => {
		fs.writeFileSync(yaml, config("true"));
		for (const host of ["claude", "codex"]) {
			const r = dispatch(host, "plan");
			assert.equal(r.status, 3);
			assert.match(r.stdout, /directive: blocked — .*is missing for .*sync-adapters\.sh --adapters=routing/);
			assert.match(r.stdout, /Do not read or carry out the task in this session, and do not run it on another model/);
		}
		assert.deepEqual(records().map((r) => [r.event, r.strategy]), [["blocked", "blocked"], ["blocked", "blocked"]]);
	});

	let first;
	check("plan then test in one chat dispatches distinct pinned workers", () => {
		sync();
		first = {};
		for (const host of ["claude", "codex"]) {
			for (const task of ["plan", "test", "plan"]) {
				const r = dispatch(host, task);
				assert.equal(r.status, 0, r.stdout);
				assert.match(r.stdout, /directive: route — dispatch d-/);
				assert.match(r.stdout, new RegExp(`Do not read or carry out ai-factory/tasks/${task}\\.md in this session`));
				const agent = agentOf(r.stdout);
				assert.match(agent, new RegExp(`^t4-route-${task}-[0-9a-f]{10}$`));
				if (first[`${host}:${task}`]) assert.equal(agent, first[`${host}:${task}`], "same config, same worker");
				first[`${host}:${task}`] = agent;
				const file = path.join(root, host === "claude" ? `.claude/agents/${agent}.md` : `.codex/agents/${agent}.toml`);
				const body = fs.readFileSync(file, "utf8");
				const want = { claude: { plan: hostile, test: "gateway/testing-claude" }, codex: { plan: "gateway/planning-codex", test: "gateway/testing-codex" } }[host][task];
				if (host === "claude") {
					assert.equal(JSON.parse(/^model: (.+)$/m.exec(body)[1]), want, "the alias reaches the agent file verbatim");
					assert.match(r.stdout, /no `model`/);
				} else {
					assert.equal(JSON.parse(/^model = (.+)$/m.exec(body)[1]), want);
					assert.match(r.stdout, /fork_turns `none`/);
				}
			}
			assert.notEqual(first[`${host}:plan`], first[`${host}:test`]);
		}
		assert.equal(fs.existsSync(path.join(root, "pwned")), false);
		const dispatched = records().filter((r) => r.event === "dispatched");
		assert.equal(dispatched.length, 6);
		assert.equal(new Set(dispatched.map((r) => r.dispatch_id)).size, 6, "every dispatch has its own ID");
		for (const r of dispatched) {
			assert.equal(r.schema, "t4.model-dispatch.v1");
			assert.equal(r.strategy, "native-agent");
			assert.equal(r.source, "task");
			assert.equal(r.reported_model, null, "a requested model is never recorded as verified");
			assert.match(r.config_digest, /^[0-9a-f]{12}$/);
		}
	});

	check("agent files: exact shape, host limits, no recursion", () => {
		const claude = routeFiles(".claude/agents");
		const codex = routeFiles(".codex/agents");
		// ghost has no task file; run has no claude model and no tool default, so no claude worker.
		assert.deepEqual(claude.map((n) => n.replace(/-[0-9a-f]{10}\.md$/, "")), ["t4-route-check", "t4-route-deploy-notes", "t4-route-plan", "t4-route-test"]);
		assert.deepEqual(codex.map((n) => n.replace(/-[0-9a-f]{10}\.toml$/, "")), ["t4-route-check", "t4-route-plan", "t4-route-run", "t4-route-test"]);
		for (const name of claude) {
			const body = fs.readFileSync(path.join(root, ".claude/agents", name), "utf8");
			assert.match(body, /^---\nname: t4-route-[a-z0-9-]+\ndescription: ".+"\ntools: .+\nmodel: ".+"\n---\n<!-- Generated by t4; canonical content lives in ai-factory\/\. -->\n/);
			assert.equal(body.split(models.MARKER).length, 2, "one marker");
			assert.ok(!body.includes("models.js dispatch --host"), "a worker must not dispatch again");
			assert.match(body, /Do not run `models\.js dispatch`/);
		}
		for (const name of codex) {
			const body = fs.readFileSync(path.join(root, ".codex/agents", name), "utf8");
			const fields = Object.fromEntries(body.split("\n").filter((l) => / = /.test(l)).map((l) => { const i = l.indexOf(" = "); return [l.slice(0, i), JSON.parse(l.slice(i + 3))]; }));
			assert.equal(fields.name, name.replace(/\.toml$/, ""));
			assert.ok(fields.description && fields.developer_instructions && fields.model, "Codex requires name, description and developer_instructions");
			assert.match(fields.name, /^[A-Za-z0-9 _-]+$/);
			assert.ok(!fields.developer_instructions.includes("models.js dispatch --host"));
		}
		const checkClaude = fs.readFileSync(path.join(root, ".claude/agents", claude.find((n) => n.startsWith("t4-route-check-"))), "utf8");
		assert.match(checkClaude, /^tools: Read, Grep, Glob, Bash$/m, "the review worker keeps the reviewer's read-only tools");
		assert.match(checkClaude, /Change no files\./);
		assert.match(fs.readFileSync(path.join(root, ".codex/agents", codex.find((n) => n.startsWith("t4-route-check-"))), "utf8"), /^sandbox_mode = "read-only"$/m);
		assert.doesNotMatch(fs.readFileSync(path.join(root, ".codex/agents", codex.find((n) => n.startsWith("t4-route-run-"))), "utf8"), /sandbox_mode/);
		const planClaude = fs.readFileSync(path.join(root, ".claude/agents", claude.find((n) => n.startsWith("t4-route-plan-"))), "utf8");
		assert.match(planClaude, /follow the complete procedure in `ai-factory\/agents\/planner\.md` yourself/);
		assert.match(planClaude, /return only the questions as your final message and stop/);
		const custom = fs.readFileSync(path.join(root, ".claude/agents", claude.find((n) => n.startsWith("t4-route-deploy-notes-"))), "utf8");
		assert.match(custom, /Where the procedure says to run in the current session/);
		const before = [...claude, ...codex].map((n) => fs.readFileSync(path.join(root, n.endsWith(".md") ? ".claude/agents" : ".codex/agents", n), "utf8"));
		sync();
		assert.deepEqual([...routeFiles(".claude/agents"), ...routeFiles(".codex/agents")], [...claude, ...codex], "sync is idempotent");
		assert.deepEqual([...routeFiles(".claude/agents"), ...routeFiles(".codex/agents")].map((n) => fs.readFileSync(path.join(root, n.endsWith(".md") ? ".claude/agents" : ".codex/agents", n), "utf8")), before);
	});

	check("an edited mapping is a new worker; in-flight workers keep theirs", () => {
		const oldTest = first["claude:test"];
		fs.writeFileSync(yaml, config("true", "gateway/testing-claude-v2"));
		const stale = dispatch("claude", "test");
		assert.equal(stale.status, 3, "a changed mapping must not run on the loaded agent");
		assert.match(stale.stdout, /restart the Claude Code session/);
		assert.equal(agentOf(dispatch("claude", "plan").stdout), first["claude:plan"], "an unchanged task keeps its worker");
		assert.ok(fs.existsSync(path.join(root, `.claude/agents/${oldTest}.md`)), "sync, not dispatch, changes agent files");
		sync();
		const fresh = dispatch("claude", "test");
		assert.equal(fresh.status, 0);
		const agent = agentOf(fresh.stdout);
		assert.notEqual(agent, oldTest, "a session holding the old agent cannot reach it under the new name");
		assert.equal(fs.existsSync(path.join(root, `.claude/agents/${oldTest}.md`)), false, "sync removes the old agent");
		assert.match(fresh.stdout, /this session started before .* existed: tell the developer to restart the session, do no task work, and stop/);
		const digests = records().filter((r) => r.event === "dispatched" && r.host === "claude" && r.task === "test").map((r) => r.config_digest);
		assert.notEqual(digests.at(0), digests.at(-1), "each dispatch records the configuration it resolved");
	});

	check("overrides", () => {
		const claude = dispatch("claude", "plan", ["--task-model=opus"]);
		assert.equal(claude.status, 0);
		assert.match(claude.stdout, /plan \/ claude: opus \(explicit override\)/);
		assert.match(claude.stdout, /subagent_type `t4:planner` and model `opus`/);
		assert.match(claude.stdout, /Claude Code accepts only its own model aliases here: if it rejects the value, report that/);
		assert.match(claude.stdout, /Worker instructions:\nYou are the routed worker for the t4 `plan` task/);
		assert.match(dispatch("claude", "quick", ["--task-model", "haiku"]).stdout, /subagent_type `general-purpose` and model `haiku`/);
		const codex = dispatch("codex", "test", ["--task-model", "gateway/other-codex"]);
		assert.match(codex.stdout, /spawn_agent with no agent_type, fork_turns `none` and model `gateway\/other-codex`/);
		const inherit = dispatch("claude", "plan", ["--task-model=inherit"]);
		assert.equal(inherit.status, 0);
		assert.match(inherit.stdout, /plan \/ claude: CLI's own configuration \(explicit inherit\)\ndirective: inherit/);
		for (const bad of ["a b", "$(touch pwned)", "'x'", "", "x;y"]) {
			const r = dispatch("claude", "plan", [`--task-model=${bad}`]);
			assert.equal(r.status, 3, bad);
			assert.match(r.stdout, /directive: blocked — --task-model accepts/);
		}
		for (const extra of [["--task-model"], ["--model", "x"], ["stray"], ["--task-model=a", "--task-model=b"]])
			assert.equal(dispatch("claude", "plan", extra).status, 3, extra.join(" "));
		assert.equal(fs.existsSync(path.join(root, "pwned")), false);
		// An override applies with routing off too, exactly like MODEL= on the command line.
		fs.writeFileSync(yaml, config("false"));
		assert.match(dispatch("codex", "plan", ["--task-model=gpt-x"]).stdout, /directive: route/);
		assert.match(dispatch("codex", "plan").stdout, /directive: legacy/);
		fs.writeFileSync(yaml, config("true", "gateway/testing-claude-v2"));
	});

	check("host settings and configuration that cannot be honored", () => {
		const env = dispatch("claude", "plan", [], { CLAUDE_CODE_SUBAGENT_MODEL: "sonnet" });
		assert.equal(env.status, 3);
		assert.match(env.stdout, /CLAUDE_CODE_SUBAGENT_MODEL=sonnet overrides every subagent's model/);
		assert.equal(dispatch("claude", "plan", ["--task-model=opus"], { CLAUDE_CODE_SUBAGENT_MODEL: "sonnet" }).status, 3);
		assert.equal(dispatch("codex", "plan", [], { CLAUDE_CODE_SUBAGENT_MODEL: "sonnet" }).status, 0);
		for (const body of ["routing:\n  enabled: ture\n", "routing:\n  tasks:\n    plan:\n      claude: a\n      claude: b\n"]) {
			fs.writeFileSync(yaml, body);
			const r = dispatch("claude", "plan");
			assert.equal(r.status, 3);
			assert.match(r.stdout, /directive: blocked — models\.yaml line \d+: .*Fix ai-factory\/models\.yaml; no task work was done/);
		}
		assert.equal(dispatch("claude", "missing-task").status, 3);
		assert.equal(dispatch("claude", "../plan").status, 3);
		assert.equal(dispatch("gemini", "plan").status, 3);
		fs.writeFileSync(yaml, "claude:\ncodex:\nreview:\nrouting:\n  enabled: true\n");
		const unmapped = dispatch("claude", "plan");
		assert.equal(unmapped.status, 0);
		assert.match(unmapped.stdout, /CLI's own configuration \(CLI default; routing fallback: no plan mapping\)\ndirective: inherit/);
	});

	check("record", () => {
		fs.writeFileSync(yaml, config("true", "gateway/testing-claude-v2"));
		const id = dispatchId(dispatch("codex", "plan").stdout);
		const ok = run(["record", "--dispatch", id, "--outcome", "succeeded", "--worker", "agent-7"]);
		assert.equal(ok.status, 0, ok.stderr);
		const done = records().filter((r) => r.dispatch_id === id);
		assert.deepEqual(done.map((r) => r.event), ["dispatched", "completed"]);
		assert.deepEqual([done[1].outcome, done[1].worker, done[1].requested_model, done[1].strategy], ["succeeded", "agent-7", "gateway/planning-codex", "native-agent"]);
		assert.notEqual(run(["record", "--dispatch", "d-20000101000000-000000", "--outcome", "succeeded"]).status, 0);
		assert.notEqual(run(["record", "--dispatch", id, "--outcome", "maybe"]).status, 0);
		assert.notEqual(run(["record", "--dispatch", id, "--outcome", "failed", "--worker", "$(x)"]).status, 0);
	});

	check("disable, re-enable and adapter hygiene", () => {
		fs.mkdirSync(path.join(root, ".claude/agents"), { recursive: true });
		fs.writeFileSync(path.join(root, ".claude/agents/mine.md"), "---\nname: mine\ndescription: hand-authored\n---\nMine.\n");
		fs.writeFileSync(path.join(root, ".codex/agents/mine.toml"), 'name = "mine"\ndescription = "hand"\ndeveloper_instructions = "Mine."\n');
		fs.writeFileSync(path.join(root, ".claude/agents/t4-route-mine.md"), "---\nname: t4-route-mine\n---\nHand-authored, no marker.\n");
		fs.writeFileSync(yaml, config("false"));
		sync();
		assert.deepEqual(routeFiles(".claude/agents"), ["t4-route-mine.md"], "disabled routing leaves no generated agent, and a hand-authored one stays");
		assert.deepEqual(routeFiles(".codex/agents"), []);
		assert.ok(fs.existsSync(path.join(root, ".claude/agents/mine.md")) && fs.existsSync(path.join(root, ".codex/agents/mine.toml")));
		assert.match(dispatch("claude", "plan").stdout, /directive: legacy/);
		fs.writeFileSync(yaml, config("true"));
		sync("claude,codex");
		assert.equal(dispatch("claude", "plan").status, 0);
		assert.equal(dispatch("codex", "test").status, 0);
		const pointer = fs.readFileSync(path.join(root, ".claude/commands/t4/deploy-notes.md"), "utf8");
		assert.ok(pointer.includes(models.entryPreamble("claude", "deploy-notes")));
		assert.doesNotMatch(pointer, /^@/m, "the pointer must not import the task before dispatch");
		assert.ok(fs.readFileSync(path.join(root, ".codex/skills/t4-deploy-notes/SKILL.md"), "utf8").includes(models.entryPreamble("codex", "deploy-notes")));
		const hash = () => [".claude", ".codex"].flatMap((d) => fs.readdirSync(path.join(root, d), { recursive: true }).sort().map((f) => { const p = path.join(root, d, f); return fs.statSync(p).isFile() ? `${f}:${fs.readFileSync(p, "utf8")}` : f; })).join("\n");
		const before = hash();
		sync("claude,codex");
		assert.equal(hash(), before, "a repeated sync changes nothing");
		fs.rmSync(path.join(root, ".claude/agents/t4-route-mine.md"));
	});

	check("doctor", () => {
		const rows = () => run(["doctor"]).stdout.trim().split("\n").map((l) => l.split("|"));
		let out = rows();
		assert.ok(out.some(([s, , d]) => s === "finding" && /ghost/.test(d)), "a mapping without a task is reported");
		assert.ok(out.some(([s, , d]) => s === "ok" && /claude route agent\(s\) current/.test(d)));
		fs.writeFileSync(yaml, config("true", "gateway/changed"));
		out = rows();
		assert.ok(out.some(([s, , d]) => s === "finding" && /claude route agents are not current \(1 missing, 1 stale\)/.test(d)), JSON.stringify(out));
		assert.ok(run(["doctor"], { CLAUDE_CODE_SUBAGENT_MODEL: "x" }).stdout.includes("CLAUDE_CODE_SUBAGENT_MODEL is set"));
		fs.writeFileSync(yaml, "routing:\n  enabled: ture\n");
		assert.match(run(["doctor"]).stdout, /^finding\|models\|models\.yaml line 2: routing\.enabled must be true or false/);
		fs.writeFileSync(yaml, config("false"));
		assert.match(run(["doctor"]).stdout, /^ok\|routing\|model routing is off \(routing\.enabled is false; mappings kept\)/);
		const shell = spawnSync("bash", [path.join(repo, "skills/ai-layout/scripts/doctor.sh"), root, repo], { encoding: "utf8" });
		assert.match(shell.stdout, /\[ok {5}\] routing +model routing is off/);
	});
	check("adoption ships routing off and keeps a customized configuration", () => {
		const target = path.join(scratch, "adopted repo");
		fs.mkdirSync(target);
		const adopt = () => spawnSync(process.execPath, [path.join(repo, "skills/ai-layout/scripts/adopt.js"), target], { encoding: "utf8" });
		const first = adopt();
		assert.equal(first.status, 0, first.stderr);
		const shipped = path.join(target, "ai-factory/models.yaml");
		assert.equal(fs.readFileSync(shipped, "utf8"), fs.readFileSync(path.join(TEMPLATE, "models.yaml"), "utf8"));
		assert.ok(fs.existsSync(path.join(target, "ai-factory/make/models.js")), "the adopted runner needs its own resolver");
		const r = spawnSync(process.execPath, ["ai-factory/make/models.js", "dispatch", "--host", "codex", "--task", "plan"], { cwd: target, encoding: "utf8" });
		assert.match(r.stdout, /directive: legacy/);
		const custom = "claude: mine\ncodex:\nreview:\nrouting:\n  enabled: true\n  tasks:\n    plan:\n      codex: my/alias\n";
		fs.writeFileSync(shipped, custom);
		assert.notEqual(adopt().status, 0, "adoption over an existing workspace must refuse");
		assert.equal(fs.readFileSync(shipped, "utf8"), custom, "a customized configuration survives repeated adoption");
		const show = spawnSync(process.execPath, ["ai-factory/make/models.js", "show", "--tool", "codex", "--task", "plan"], { cwd: target, encoding: "utf8" });
		assert.equal(JSON.parse(show.stdout).model, "my/alias");
	});
	console.log(`PASS: interactive model routing — ${cases.length} cases: ${cases.join("; ")}`);
} finally {
	fs.rmSync(scratch, { recursive: true, force: true });
}
NODE
