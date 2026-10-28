# Risk agent and /fc:risk

Add a ninth step agent, `risk`, and a `/fc:risk` task. It assesses one spec, plan or change for security threats and delivery risk, and records its findings in one committed artefact under `ai-factory/risks/`. The specifier, the planner and the reviewer read that artefact (exploration 0005, option B, with the developer's decisions applied).

**Amended after spec 0024 (letter-and-digit artefact IDs) landed**, as its Sequencing section requires. Risk files are now created through `node ai-factory/make/ids.js new risk …`, and AC9 is removed. Open questions 1–5 are settled with the choices recorded in the Ambiguities section of [plan 0023](../plans/0023-risk-agent.md) (AC6–AC8, AC16, AC20, AC36–AC40). The exception to spec 0012 AC10 is recorded in ADR DJX496 ([`ai-factory/adr/DJX496-risk-agent-network-audit.md`](../adr/DJX496-risk-agent-network-audit.md)).

## User story

As a developer running the planned workflow, I want to assess a spec, a plan or a change for security threats and delivery risk and get a durable record of each finding with its severity, status and mitigation, so that the spec, the plan and the review can each act on those mitigations.

## Acceptance criteria

In these criteria, `<ID>` is an artefact ID as spec 0024 defines it: a new-style ID such as `KXT204`, or a legacy four-digit number such as `0023`.

### The agent, the task and the entry points
- **AC1 — The agent exists and is registered.** Given the plugin, when its agents are listed, then `agents/risk.md` exists as a canonical step agent and is registered as `fc:risk`. `risk` is in the `nativeClaudeAgents` set in `skills/ai-layout/templates/ai-factory/make/sync-adapters.js`.
- **AC2 — The task exists on both hosts.** Given the plugin, when its entry points are listed, then `skills/ai-layout/templates/ai-factory/tasks/risk.md` exists. `commands/risk.md` and `codex-skills/fc-risk/` are generated from it the same way the other task wrappers are generated, and `/fc:risk` delegates to the `risk` agent.
- **AC3 — No old names remain.** Given the plugin after this change, when its files are searched, then no agent, task, command, skill, directory or doc introduced by this change is named `assessor`, `assess` or `assessments`.

### Targets
- **AC4 — A clear free-text target is stated.** Given `/fc:risk` run with free text that has exactly one reading as a spec, plan, working tree, branch or diff, when the agent finishes, then it writes the assessment, and its report states the target kind and the spec, plan or change it assessed.
- **AC5 — An unclear target is a question (interactive).** Given an interactive `/fc:risk` run whose free text has more than one plausible reading, or none, when the agent stops, then it returns a question that lists the candidate targets it found and writes nothing.
- **AC6 — A spec can be assessed.** Given free text that names an existing spec `ai-factory/specs/<ID>-…`, when `/fc:risk` runs, then the agent creates the assessment with `node ai-factory/make/ids.js new risk <slug> --id <spec ID>` and writes it to the path the helper prints, `ai-factory/risks/<ID>-<slug>.md`, carrying the spec's ID. The file's `Target:` line names that spec. When the helper exits 3 because a risk file already has that ID, the agent appends to the path the helper printed (AC15, AC36) instead of creating a file. On any other non-zero exit it writes nothing and reports the helper's message.
- **AC7 — A plan can be assessed.** Given free text that names an existing plan `ai-factory/plans/<ID>-…`, when `/fc:risk` runs, then the agent creates the assessment with `node ai-factory/make/ids.js new risk <slug> --id <spec ID>`, where the spec ID is the plan's ID, and writes it to the path the helper prints, `ai-factory/risks/<ID>-<slug>.md`. The file's `Target:` line names that plan. Exit 3 and other non-zero exits are handled as in AC6.
- **AC8 — A change gets a freshly drawn ID.** Given free text that names a working-tree change, a branch or a diff, and no existing change assessment matches it under AC16, when `/fc:risk` runs, then the agent creates the assessment with `node ai-factory/make/ids.js new risk <slug>` (no `--id`) and writes it to the path the helper prints, `ai-factory/risks/<ID>-<slug>.md`, with a freshly drawn ID. No file is named `change-<slug>.md`. For a working-tree or branch target, the slug is the branch name in lower case, with every run of characters outside `[a-z0-9]` replaced by `-` and leading and trailing `-` trimmed. The slug carries no identity: the file's `Target:` line (AC37) identifies the change, so two branches whose names give the same slug never share a file.
- **AC9 — Removed.** Superseded by spec 0024. It required that change assessments never take a spec or plan number. Under spec 0024, every risk file is named by an ID that `ids.js` issues from one ID space shared with specs and plans, so a change assessment cannot occupy or collide with a spec or plan ID. The number AC9 is kept so that the other criteria keep their numbers.

### The artefact
- **AC10 — Contents.** Given any completed assessment, when its file is read, then it contains: the target; the categories assessed; a findings table with the columns id, category, severity, status, evidence path and mitigation; and a residual risks section.
- **AC11 — Categories.** Given any completed assessment, when its categories assessed are read, then they include authorization, data exposure, secrets, injection, dependency/supply chain, migrations, rollback and blast radius.
- **AC12 — Severity scale.** Given any finding, when its severity is read, then it is one of `blocker`, `major` or `minor`.
- **AC13 — Status values.** Given any finding, when its status is read, then it is one of `open`, `mitigated` or `accepted`. An `accepted` finding records who accepted it and why. Who may set each status is in AC39 and AC40.
- **AC14 — Category and mitigation.** Given any finding, when its row is read, then its category and its mitigation are both non-empty.
- **AC15 — Reassessment appends a full restatement.** Given an assessment file already exists for a target, when `/fc:risk` runs again on the same target, then the file gains a new dated "Reassessment" section. That section restates every finding still relevant, each with its current status. Every earlier section remains in the file unchanged, as history.
- **AC16 — Same target for a change.** Given a change assessment in `ai-factory/risks/` whose `Target:` line (AC37) matches the change now named, when `/fc:risk` runs, then the agent appends a Reassessment section to that file and does not call `ids.js new risk`. Two `Target:` lines match when they are equal, except that a `working-tree <branch>` target and a `branch <branch>` target match each other when the branch names are equal. Base commits are not compared, so on a long-lived branch (for example `main`) every change assessed on that branch appends to the same file.
- **AC17 — Commits are recorded.** Given a working-tree or branch target, when an assessment or Reassessment section is written, then that section records the base commit and the head commit it assessed.
- **AC18 — Write boundary.** Given a `risk` run on any target, when the run ends, then the only file it created or changed is under `ai-factory/risks/`. Code, specs, plans and evidence are unchanged.

### Supply chain: an exception to spec 0012 AC10
- **AC19 — Network audit tools are allowed for this agent only.** Given a target with dependency manifests or lockfiles, when the `risk` agent assesses the dependency/supply-chain category, then it may run network dependency-audit tools (for example `npm audit`, `pip-audit`, `osv-scanner`), interactively and in CI where the network is available. No other agent, hook, runner check or gate check gains network access, and the core checks covered by spec 0012 AC10 still reach no external integration.
- **AC20 — The exception has an ADR.** Given this feature is delivered, when `ai-factory/adr/` is read, then ADR DJX496, [`ai-factory/adr/DJX496-risk-agent-network-audit.md`](../adr/DJX496-risk-agent-network-audit.md), is the record of the exception to spec 0012 AC10: network audit tools for the `risk` agent only. The ADR states why, and cites spec 0012 without amending it. This spec cites the ADR by its ID and path.
- **AC21 — Audit unavailable falls back.** Given an audit tool is missing or its service is unreachable, when the supply-chain category is assessed, then the assessment records that category as `not assessed: <reason>`. The agent inspects the lockfiles and manifests locally instead, and the run continues to completion.

### Layout and adoption
- **AC22 — The workspace directory ships and is committed.** Given a repo that adopts the layout after this change, when the layout is applied, then `ai-factory/risks/` exists, seeded from `skills/ai-layout/templates/ai-factory/risks/.gitkeep`, and the layout does not gitignore it. Given a repo that adopted the layout before this change, when `/fc:sync-sdlc` runs, then it stays read-only and does not create `ai-factory/risks/`; when `/fc:risk` first writes an assessment there, `ids.js` creates the directory. Sync does not create it because sync is pull-only and the manifest skips `.gitkeep`. `skills/ai-layout/scripts/check-entrypoints.sh` fails if the templates stop carrying `risks`.
- **AC23 — Opting out is the repo's choice.** Given an adopting repo that has gitignored `ai-factory/risks/`, when the layout is synced, then sync does not remove the ignore rule or force the directory to be tracked.

### Consumers
- **AC24 — Consumers read the latest section only.** Given an assessment file with one or more Reassessment sections, when the `specifier`, `planner` or `reviewer` reads it, then it acts on the findings in the latest Reassessment section only.
- **AC25 — The specifier turns open findings into open questions.** Given `ai-factory/risks/<ID>-…` exists for a spec with ID `<ID>`, when the `specifier` writes or updates that spec, then every `open` blocker or major finding appears under Open questions, and the spec cites the assessment path. A finding that is `mitigated`, `accepted` or `minor` does not appear there.
- **AC26 — The planner uses mitigations.** Given `ai-factory/risks/<ID>-…` exists for the feature with ID `<ID>`, when the `planner` writes the plan, then each mitigation in that assessment becomes a step or a risk check in the plan.
- **AC27 — The reviewer checks mitigations.** Given an assessment applies to the change under review, when the `reviewer` reviews it, then every `open` or `mitigated` finding whose mitigation was not implemented is reported as a finding in the existing verdict shape. `accepted` findings are not checked, and reviewer checks 6 and 7 still run as before. An assessment applies when it carries the ID of the spec or plan being reviewed, or when it is a change assessment whose `Target:` line matches the change under review (AC16).
- **AC28 — No assessment, no change.** Given a feature with no applicable assessment in `ai-factory/risks/`, when the `specifier`, `planner` or `reviewer` runs, then its output is the same as before this change.
- **AC29 — Start suggests it.** Given a request to `/fc:start` that hits a risk trigger under rule 3 (authorization, public contracts, migrations, dependencies, service boundaries or uncertain requirements), when start proposes its route, then it names `/fc:risk` as an optional next step. Given a request with no risk trigger, it does not. `/fc:plan` is unchanged.

### Headless, knowledge, models
- **AC30 — Headless run.** Given `make ai TASK=risk INPUT="…"`, when the agent can proceed, then it writes the assessment as in AC6–AC8. When it would need to ask the developer, including for an unclear target, it reports the question, writes nothing, and changes no file.
- **AC31 — Knowledge sources.** Given a repo with a configured knowledge source, when `/fc:risk` runs, then the `risk` agent may consult that source under the rules of `ai-factory/docs/knowledge.md`, and that file lists `risk` and `/fc:risk` among the executors that may consult a source. Given an unconfigured repo, the agent's output mentions no source.
- **AC32 — Model routing entry.** Given the `ai-factory/models.yaml` template after this change, when it is read, then it carries `routing.tasks.risk` with `claude: claude-opus-5-5` and a blank `codex` entry (the host default).
- **AC33 — The pin only applies with routing on.** Given routing is disabled, when `/fc:risk` runs, then the pin has no effect and model resolution is as before. Given routing is enabled and the gateway does not serve the pinned model, when `/fc:risk` is dispatched, then dispatch fails with the normal routing error.

### Docs and release
- **AC34 — Documentation.** Given the plugin after this change, when the docs are read, then `ai-factory/docs/workflow.md` and `ai-factory/docs/fleet.md` no longer say "eight agents". `/fc:risk` appears in the slash-command list in `ai-factory/AGENTS.md` and its template. The `plugin.json` descriptions mention the new agent and task.
- **AC35 — Marked breaking.** Given the MR and the CHANGELOG entry for this change, when they are read, then both mark it as breaking. Both name the changed `planner`, `specifier`, `reviewer`, `start` and `models.yaml` templates.

### Amendment after spec 0024: one file per ID, target lines, statuses
- **AC36 — A spec and its plan share one risk file.** Given `ai-factory/risks/<ID>-…` already exists for a spec or plan with ID `<ID>`, when `/fc:risk` assesses the spec or the plan with that ID, then `ids.js new risk <slug> --id <ID>` exits 3 and the agent appends a Reassessment section to the path it printed, whose `Target:` line names the spec or plan now assessed. In particular, a plan assessed after its spec has been assessed is appended to the spec's risk file as a Reassessment whose `Target:` names the plan. No second risk file with that ID is created.
- **AC37 — The `Target:` line has one shape per target kind.** Given any assessment or Reassessment section, when its `Target:` line is read, then it has exactly one of these shapes:
  - `Target: spec <path>`
  - `Target: plan <path>`
  - `Target: working-tree <branch>`
  - `Target: branch <branch>`
  - `Target: detached <head sha>`, for a working tree on a detached HEAD
  - `Target: diff <path>`, for a diff supplied as a file, or `Target: diff supplied`, for a diff pasted into the request
- **AC38 — Diffs are matched by path; a pasted diff is always new.** Given a change assessment whose `Target:` is `diff <path>`, when `/fc:risk` runs on a diff supplied at the same path, then it appends to that file (AC16), and for a diff at a different path it creates a new file (AC8). Given a pasted diff, when `/fc:risk` runs, then it always creates a new file with `Target: diff supplied`, even if an earlier file has that same `Target:` line.
- **AC39 — `mitigated` needs cited evidence.** Given a finding whose status the agent sets to `mitigated` in an assessment or Reassessment section, when its row is read, then its evidence path cell cites the evidence for the mitigation. The agent never sets `mitigated` on a finding for which it cites no evidence; such a finding stays `open`.
- **AC40 — Only the developer sets `accepted`.** Given a `risk` run, when it writes a section, then it sets no finding to `accepted` that was not already `accepted` in the latest section of the file. Given the developer has edited a finding in the latest section to `accepted`, with who accepted it and why, when the agent next reassesses that target, then it carries that finding forward as `accepted` with the same who and why. The agent never asks the developer to accept a finding.

## Out of scope

- Making an assessment an assurance requirement, a contracts evidence kind, or a gate condition (exploration 0005 option D). An assessment gates nothing.
- Any change to the reviewer's verdict shape. The reviewer's procedure gains only the mitigation check in AC27.
- Changes to `/fc:plan`, `make/gate.js`, `make/assurance.js`, `make/contracts.js` or `make/ids.js`. The `risk` kind of `ids.js` is used as spec 0024 shipped it.
- Comparing base commits, or starting a new file after a merge, to tell apart changes on one long-lived branch (AC16).
- Amending spec 0012. ADR DJX496 cites it and does not amend it.
- A chat-only JSON output with no artefact (option A).
- Network access for any agent, hook or check other than `risk` (AC19).

## Open questions

None. Open questions 1–4 of the earlier version are settled by AC8, AC16 and AC36–AC40 with the choices recorded in plan 0023's Ambiguities section. Open question 5 (ADR number and authorship) is settled: the ADR is DJX496, written with `/fc:adr`, and it cites spec 0012 without amending it (AC20).

## Data touched

No application data. There is a new committed workspace artefact type in `ai-factory/risks/`:
- File names: `<ID>-<slug>.md`, created only by `node ai-factory/make/ids.js new risk <slug>`. A spec or plan assessment takes the spec's ID with `--id <spec ID>`, and a spec and its plan share one file (AC36). A change assessment takes a freshly drawn ID. The first two lines are the helper's `# <ID> — <Title>` heading and `Created:` line.
- Fields: a `Target:` line in one of the shapes in AC37, categories assessed, findings (id, category, severity, status, evidence path, mitigation), residual risks, and dated Reassessment sections, each with its own `Target:` line and, for a working-tree or branch target, base and head commits.

A new `.gitkeep` is seeded in the templates, and `models.yaml` gains a `routing.tasks.risk` entry.

## Routes touched

There are no web routes. A new slash command `/fc:risk`, a new Codex skill `fc-risk`, a new agent `fc:risk` and a new headless task `TASK=risk` are added. The agent calls the existing `node ai-factory/make/ids.js new risk <slug> [--id <ID>]` entry point.

## Components likely involved

- `agents/risk.md` (new); procedure changes in `agents/specifier.md`, `agents/planner.md`, `agents/reviewer.md`
- `skills/ai-layout/templates/ai-factory/tasks/risk.md` (new) and `tasks/start.md` (rule 3 suggestion); generated `commands/risk.md`, `codex-skills/fc-risk/`
- `skills/ai-layout/templates/ai-factory/risks/.gitkeep` (new), plus manifest/sync wiring for the new directory
- `skills/ai-layout/templates/ai-factory/make/ids.js` (existing `risk` kind, used unchanged)
- `skills/ai-layout/templates/ai-factory/make/sync-adapters.js` (`nativeClaudeAgents`); the headless runner for `TASK=risk`
- `skills/ai-layout/templates/ai-factory/models.yaml` (`routing.tasks.risk`)
- `skills/ai-layout/templates/ai-factory/docs/knowledge.md` and this repo's `ai-factory/docs/knowledge.md` (executor list)
- `ai-factory/adr/DJX496-risk-agent-network-audit.md` (exists; the spec 0012 AC10 exception)
- `skills/ai-layout/scripts/check-entrypoints.sh` (template entry list)
- `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json` descriptions
- `ai-factory/docs/workflow.md`, `ai-factory/docs/fleet.md`, `ai-factory/AGENTS.md` and its template, CHANGELOG
- A before/after run linked in the MR, as the repo rules require for prompt changes
- Edit the canonical targets only, never the `ai-factory/tasks/`, `ai-factory/agents/` or `ai-factory/make/` symlinks
