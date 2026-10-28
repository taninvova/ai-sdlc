# 0023 — Risk agent
Created: 2026-10-26T00:22:34.027Z

**Goal:** Add a ninth step agent, `risk`, and a `/fc:risk` task that assess one spec, plan or change for security threats and delivery risk, record the findings in one committed artefact under `ai-factory/risks/` created by `ids.js new risk`, and have the specifier, planner and reviewer act on its latest section.

**Spec:** [`ai-factory/specs/0023-risk-agent.md`](../specs/0023-risk-agent.md). Exploration: [`ai-factory/explorations/0005-security-and-risk-assessment-agent.md`](../explorations/0005-security-and-risk-assessment-agent.md), option B.

**This plan follows spec 0024's Sequencing section, not the file names written in spec 0023.** Spec 0024 has landed, and `ids.js` already knows the `risk` kind (`risks/`, reusing a spec's ID with `--id`, one risk file per ID). Spec 0023 has not been amended yet. So this plan:
- names a spec or plan assessment `ai-factory/risks/<ID>-<slug>.md`, created with `node ai-factory/make/ids.js new risk <slug> --id <spec ID>` (AC6, AC7 as amended);
- names a change assessment `ai-factory/risks/<ID>-<slug>.md` with a freshly drawn ID, created with `node ai-factory/make/ids.js new risk <slug>`. It is not named `change-<slug>.md` (AC8 as amended);
- drops AC9. The shared ID space in `ids.js` makes the collision impossible, and `check-ids.sh` (`new`, `reuse`, `check`) already proves that;
- finds an existing assessment again through the helper's exit 3 (spec or plan) or through the `Target:` line (change). See Ambiguities 1–3.

## Design

- **The agent writes one directory.** `agents/risk.md` has the tools `Read, Grep, Glob, Bash, Write, Edit`. Its "What you may write" section names `ai-factory/risks/` only, and only through a path the helper printed or an existing assessment it is appending to (AC18). It is modelled on `explorer.md` and `analyst.md`. It starts with the standard "If you are not already reading `ai-factory/agents/risk.md`…" line, which `check-workspace.sh` requires.
- **Choosing the target (AC4, AC5, AC30).**
  - The agent resolves the free text to exactly one of five kinds: `spec`, `plan`, `working-tree`, `branch` or `diff`.
  - If there is more than one plausible reading, or none, it returns a question listing the candidates it found and writes nothing.
  - In a headless run, the task reports that question, writes nothing and changes no file.
- **Creating the file, or finding it again.**
  - **A spec or plan target.** The agent runs `ids.js new risk <slug> --id <ID>`. On exit 0 it writes below the helper's two lines. On exit 3 it appends a Reassessment section to the path the helper printed (AC15). Any other exit: the agent writes nothing and reports the helper's message.
  - **A change target.**
    1. The agent first looks for an existing `ai-factory/risks/*.md` whose `Target:` line equals the one it would write, byte for byte (AC16). If it finds one, it appends to it.
    2. Otherwise it runs `ids.js new risk <slug>`.
    3. The slug is the branch name in lower case, with every run of characters outside `[a-z0-9]` turned into `-` and trimmed, so it matches the helper's slug rule. It is cosmetic: identity is the `Target:` line, so two branches that give the same slug never share a file (spec Open question 3).
  - **The `Target:` line has one fixed shape per kind:**
    - `Target: spec <path>`
    - `Target: plan <path>`
    - `Target: working-tree <branch>`
    - `Target: branch <branch>`
    - `Target: detached <head sha>`
    - `Target: diff <path or "supplied">`

    For AC16, a working-tree target and a branch target on the same branch name match each other: the comparison uses the branch name only.
- **The artefact shape (AC10–AC14, AC17).** Below the helper's two lines the file holds these sections:
  - `Target:`;
  - `Base commit:` and `Head commit:`, for a working-tree or branch target;
  - `## Categories assessed`, listing all eight categories, each `assessed` or `not assessed: <reason>`;
  - `## Findings`, a table with the columns `id | category | severity | status | evidence path | mitigation`;
  - `## Residual risks`.

  Rules for the rows:
  - severity is `blocker|major|minor`;
  - status is `open|mitigated|accepted`;
  - an `accepted` row records who accepted it and why in its mitigation cell;
  - neither the category nor the mitigation cell may be empty.

  A reassessment appends `## Reassessment <ISO date>`. It has its own `Target:` and commit lines, restates every finding that is still relevant together with its current status, and leaves every earlier byte unchanged (AC15, AC17).
- **Statuses (spec Open question 4; see Ambiguity 4).**
  - The agent may set `mitigated` on reassessment, and only when it can cite an evidence path in the change.
  - It never sets `accepted` itself. It carries forward an `accepted` row, with its who and why, that the developer edited by hand into the latest section.
- **Supply chain (AC19, AC21).**
  - Only `agents/risk.md` names the network audit tools (`npm audit`, `pip-audit`, `osv-scanner`). It runs them only when manifests or lockfiles exist.
  - If a tool is missing or its service is unreachable, the agent records `dependency/supply chain: not assessed: <reason>`, inspects the lockfiles locally, and continues.
  - No hook, runner, gate or check script changes, so spec 0012 AC10's fixtures stay as they are.
- **Consumers (AC24–AC28).**
  - Each consumer reads only the latest `## Reassessment` section, or the initial body if there is no reassessment.
  - **Specifier.** It maps `open` blocker or major findings to Open questions and cites the path.
  - **Planner.** It turns each mitigation into a step or a risk check.
  - **Reviewer.** It adds one check after check 7. That check reports, in the existing verdict shape, every `open` or `mitigated` finding whose mitigation is not implemented, and it skips `accepted` findings. An assessment applies when its ID is the reviewed spec or plan's ID, or when its `Target:` line matches the change under review.
  - When no assessment applies, each consumer's procedure says to do nothing different (AC28).
  - `tasks/plan.md` is not edited (AC29).
- **Start (AC29).** Rule 3 of `tasks/start.md` gains one sentence: when a risk trigger is present, the `reason` names `/fc:risk` as an optional next step. `risk` is not added to the destination allowlist, and `validateStartResult` is unchanged.
- **Routing (AC32, AC33).** The `models.yaml` template ships `routing.tasks.risk` with `claude: claude-opus-5-5` and a blank `codex:`, under `enabled: false`. The parser in `models.js` and the resolution order are unchanged.

## Files

**Create**
- `agents/risk.md`: the canonical `risk` step agent (AC1, AC4–AC8, AC10–AC19, AC21, AC30, AC31).
- `skills/ai-layout/templates/ai-factory/agents/risk.md`: the adopted copy, generated by `node skills/ai-layout/scripts/materialize-agents.js`. Never hand-written.
- `skills/ai-layout/templates/ai-factory/tasks/risk.md`: the task. It says "Delegate to the `risk` subagent", which lets both generators derive the agent (AC2, AC5, AC30).
- `commands/risk.md` and `codex-skills/fc-risk/SKILL.md`: generated by `sync-claude-commands.js` and `sync-codex-skills.js` (AC2).
- `skills/ai-layout/templates/ai-factory/risks/.gitkeep`: seeds the workspace directory on adoption (AC22).
- `ai-factory/risks/.gitkeep`: this repo's own copy. Other workspace directories here carry one.
- `ai-factory/adr/<ID>-risk-agent-network-audit.md`: created by `node ai-factory/make/ids.js new adr risk-agent-network-audit` through `/fc:adr`. It records the exception to spec 0012 AC10 (AC20).
- `skills/ai-layout/scripts/check-risk.sh`: this feature's checks, in the groups `adr`, `agent`, `task`, `layout`, `routing`, `knowledge`, `consumers`, `start` and `docs`. The default runs every group. Each case reports a missing file as its own failure, as `check-loop.sh` does.
- This repo only: the links `ai-factory/agents/risk.md` and `ai-factory/tasks/risk.md`, generated by `node skills/ai-layout/scripts/sync-self.js`. Both paths are in `dont-touch.md`, so never write them by hand.

**Modify**
- `skills/ai-layout/templates/ai-factory/make/sync-adapters.js`: add `risk` to `nativeClaudeAgents` (AC1) and to `nativeClaudeCommands`, so that no duplicate pointer is generated.
- `agents/specifier.md`, `agents/planner.md` and `agents/reviewer.md`: read the risk assessment (AC24–AC28). Their template copies are regenerated by `materialize-agents.js`.
- `skills/ai-layout/templates/ai-factory/tasks/start.md`: the rule 3 suggestion (AC29).
- `skills/ai-layout/templates/ai-factory/models.yaml`: `routing.tasks.risk` (AC32). `ai-factory/models.yaml` here is a symlink to it.
- `skills/ai-layout/templates/ai-factory/docs/knowledge.md` and `ai-factory/docs/knowledge.md` (a regular file here, identical today): add `risk` and `/fc:risk` to "Who consults a source" (AC31).
- `skills/ai-layout/scripts/check-entrypoints.sh`: add `risks` to the payload entry list (AC22).
- `skills/ai-layout/scripts/check-manifest.sh` and `check-workspace.sh`: adoption delivers and tracks `ai-factory/tasks/risk.md` and `ai-factory/agents/risk.md`, and creates `ai-factory/risks/` (AC22).
- `skills/ai-layout/scripts/check-model-selection.sh`: the shipped-template assertion (`tasks:{}`, line 44) becomes the risk entry, and the AC33 cases are added.
- `skills/ai-layout/scripts/check-start-routing.sh`: only if a case pins the rule 3 text. Otherwise unchanged.
- `ai-factory/AGENTS.md` and `skills/ai-layout/templates/ai-factory/AGENTS.md`: add `/fc:risk` to the slash-command list (AC34).
- `ai-factory/docs/workflow.md`: say "nine agents" instead of "eight agents" (line 6), "25" instead of "24" (line 140), and add `/fc:risk` to the command tables and the `risks/` artefact row (AC34).
- `ai-factory/docs/fleet.md`: say "nine agents" and add `risk` to the list (AC34).
- `README.md` (the "all 24" Claude commands become 25), `FACTORY.md` ("eight agents"), `skills/ai-layout/SKILL.md` (the "all 24" commands, the description's task and agent lists, and the `ai-factory/risks/` row of the layout tree), and `ai-factory/docs/architecture.md` (the module map, if it lists agents).
- `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json`: the `description` names the `risk` agent and the `/fc:risk` task (AC34).
- `CHANGELOG.md`: an **Unreleased, breaking for adopted repos** block naming the changed `planner`, `specifier`, `reviewer`, `start` and `models.yaml` templates (AC35).

Unchanged by design: `tasks/plan.md`, `make/gate.js`, `make/assurance.js`, `make/contracts.js` and `make/ids.js` (spec Out of scope); `runner.js` (`TASK=risk` already reaches `tasks/risk.md` through the generic path); and every hook script.

## Server versus client

Not applicable. This is a plugin of markdown prompts, Node helpers and bash checks, with no application, UI or service. Behaviour lives in the `risk` agent's procedure. The only deterministic code it relies on is the existing `ids.js`.

## Prerequisite outside the steps

**Amend spec 0023 before Step 2.** The developer does this with `/fc:spec`, because a plan never edits a spec. The amendment does the following, and the steps below assume it:
- applies spec 0024's Sequencing section;
- drops AC9;
- cites the new ADR (the "this spec cites it" clause of AC20);
- settles Open questions 1–4.

If the amendment settles a question differently from this plan's choices (Ambiguities 1–4), re-plan the affected steps first. Until it lands, `spec-cites-adr` in Step 9 stays red.

## Steps

The `Depends on:` lines are this plan's real ordering, and `/fc:loop` reads them.

- [x] Step 1 — Record the spec 0012 AC10 exception as an ADR (AC20, the ADR half).
  - Do this step with `/fc:adr`, which runs the architect and creates the file with `node ai-factory/make/ids.js new adr risk-agent-network-audit`. Then tick it here.
  - The decision text says:
    - network dependency-audit tools (for example `npm audit`, `pip-audit`, `osv-scanner`) may be run by the `risk` agent only, interactively and in CI where the network is available;
    - no other agent, hook, runner check or gate check gains network access, and spec 0012 AC10 still holds for the core checks;
    - why the exception exists;
    - that spec 0012 is cited, not amended (see Ambiguity 5).
  - First create `check-risk.sh` with its harness, its group dispatch, and one `adr` case: `adr-records-audit-exception`. That case finds exactly one ADR, with Status `accepted`, that names spec 0012 AC10, the `risk` agent and at least one audit tool, and that says no other agent gains network access.
  - Verify (red): `bash skills/ai-layout/scripts/check-risk.sh adr`. `adr-records-audit-exception` fails with "no ADR names the spec 0012 AC10 exception".
  - Verify (step): `bash skills/ai-layout/scripts/check-risk.sh adr`, `node ai-factory/make/ids.js check` and `bash skills/ai-layout/scripts/check-ids.sh check`.

- [x] Step 2 — The `risk` agent procedure and its registration (AC1, AC3; the agent side of AC4–AC8, AC10–AC19, AC21 and AC30).
  - Depends on: 1
  - Write `agents/risk.md` to the Design above. It:
    - cites the Step 1 ADR by its ID;
    - names `ai-factory/docs/knowledge.md` in the standard paragraph, and nothing else about knowledge sources;
    - states what the agent must not do: edit code, specs, plans or evidence; set `accepted`; or run audit tools for any category other than supply chain;
    - stays under two pages.
  - Add `risk` to `nativeClaudeAgents`. Run `node skills/ai-layout/scripts/materialize-agents.js` and `node skills/ai-layout/scripts/sync-self.js`.
  - Tests, in the `agent` group:
    - `agent-registered` (AC1): the file exists, its frontmatter says `name: risk`, and `nativeClaudeAgents` has `risk`.
    - `agent-defers-to-repo-copy`: the file names `ai-factory/agents/risk.md`.
    - `agent-calls-helper` (AC6–AC8 as amended):
      - the text has `` `node ai-factory/make/ids.js new risk <slug> --id <spec ID>` ``, `` `node ai-factory/make/ids.js new risk <slug>` `` and "the path it prints";
      - the text handles exit 3 as an append;
      - no `ids.js` `COUNTING` pattern matches (no `<NNNN>-`, `NNNN-`, `change-<slug>`, or "next number").
    - `agent-target-kinds` (AC4, AC5): the five kinds, the question that lists candidates, and the rule that a question writes nothing.
    - `agent-target-line` (AC8, AC16): the six `Target:` shapes and the rule that branch names are compared.
    - `agent-artefact-shape` (AC10–AC14): the three section headings, the six column names in order, all eight categories, the three severities, the three statuses, the accepted who-and-why rule, and the non-empty category and mitigation rule.
    - `agent-reassessment` (AC15, AC17): the dated `## Reassessment` heading, the restatement of current statuses, the rule that earlier sections stay byte-unchanged, and the base and head commit lines.
    - `agent-write-boundary` (AC18): "What you may write" names only `ai-factory/risks/`.
    - `agent-audit-only-here` (AC19, AC21): only `agents/risk.md`, of all the files under `agents/`, `skills/ai-layout/templates/ai-factory/tasks/` and `skills/ai-hooks/scripts/`, names `npm audit`, `pip-audit` or `osv-scanner`; the text has the `not assessed: <reason>` fallback; and it names the Step 1 ADR.
    - `agent-headless-no-question` (AC30): a headless run reports the question and writes nothing.
    - `no-old-names` (AC3): no path added since `main`, and no text in `agents/risk.md`, uses `assessor`, `assess` (as a command or task name) or `assessments`.
  - Verify (red): `bash skills/ai-layout/scripts/check-risk.sh agent`. Every case fails with "agents/risk.md does not exist". The exception is `no-old-names`, which passes as characterisation.
  - Verify (step):
    - `bash skills/ai-layout/scripts/check-risk.sh agent`
    - `node skills/ai-layout/scripts/materialize-agents.js --check`
    - `bash skills/ai-layout/scripts/check-workspace.sh`
    - `bash skills/ai-layout/scripts/check-adapters.sh`
    - `test -L ai-factory/agents/risk.md`

- [x] Step 3 — The `/fc:risk` task and its generated entries (AC2; the task side of AC5 and AC30).
  - Depends on: 2
  - Write `tasks/risk.md`. Its first line after the frontmatter is "Delegate to the `risk` subagent". It returns the agent's report unchanged. With no input, it asks what to assess and stops. Given a question from the agent, it asks the developer; in a headless run it reports the question, says nothing was written, and stops. The task itself does not assess or edit anything.
  - Add `risk` to `nativeClaudeCommands`. Run `node skills/ai-layout/scripts/sync-claude-commands.js`, `node skills/ai-layout/scripts/sync-codex-skills.js` and `node skills/ai-layout/scripts/sync-self.js`.
  - Extend `check-manifest.sh` and `check-workspace.sh` so adoption delivers and tracks `ai-factory/tasks/risk.md` and `ai-factory/agents/risk.md`.
  - Tests, in the `task` group:
    - `task-exists-delegates` (AC2)
    - `task-generated-both-hosts` (AC2): `commands/risk.md` and `codex-skills/fc-risk/SKILL.md` exist, and the Codex skill names `ai-factory/agents/risk.md`
    - `task-headless-question` (AC30)
    - `task-empty-input-asks` (AC5)
    - `task-native-command`: `nativeClaudeCommands` has `risk`
  - Verify (red): `bash skills/ai-layout/scripts/check-risk.sh task`. Every case fails with "tasks/risk.md does not exist".
  - Verify (step):
    - `bash skills/ai-layout/scripts/check-risk.sh task`
    - `node skills/ai-layout/scripts/sync-claude-commands.js --check`
    - `node skills/ai-layout/scripts/sync-codex-skills.js --check`
    - `bash skills/ai-layout/scripts/check-plugin-hosts.sh`: it reports 25 native Claude commands
    - `bash skills/ai-layout/scripts/check-manifest.sh`
    - `bash skills/ai-layout/scripts/check-workspace.sh`
    - `bash skills/ai-layout/scripts/check-start-routing.sh`: the generated-entry sweep covers `commands/risk.md`
    - `bash skills/ai-layout/scripts/check-runner-security.sh`
    - `test -L ai-factory/tasks/risk.md`

- [x] Step 4 — The `ai-factory/risks/` workspace directory (AC22, AC23).
  - Depends on: 1
  - Add `skills/ai-layout/templates/ai-factory/risks/.gitkeep` and `ai-factory/risks/.gitkeep`. Add `risks` to the payload list in `check-entrypoints.sh`. Make no change to the template `.gitignore`.
  - Tests, in the `layout` group:
    - `template-carries-risks` (AC22): the `.gitkeep` exists, and with `risks` deleted from a fixture copy of the templates, `check-entrypoints.sh` fails.
    - `adopt-creates-risks` (AC22): `adopt()` into a scratch repo under `ai-factory/runs/tmp/` creates `ai-factory/risks/`, and `git check-ignore ai-factory/risks/x.md` exits 1 there.
    - `template-gitignore-silent` (AC22): the template `.gitignore` has no line matching `risks`.
    - `sync-keeps-user-ignore` (AC23): in an adopted scratch repo whose root `.gitignore` has `ai-factory/risks/`, `sync-adapters.js` runs twice and `manifest.js check` runs once. The `.gitignore` is byte-identical afterwards, and nothing under `ai-factory/risks/` is staged or created.
    - `ids-creates-risks-dir`: in a synced repo with no `risks/`, `ids.js new risk probe --id <spec ID>` creates the directory. This covers existing adopters, whose sync skips `.gitkeep` (see Ambiguity 6).
  - Verify (red): `bash skills/ai-layout/scripts/check-risk.sh layout`.
    - `template-carries-risks` and `adopt-creates-risks` fail with "templates carry no risks/".
    - `template-gitignore-silent`, `sync-keeps-user-ignore` and `ids-creates-risks-dir` pass as characterisation.
  - Verify (step): `bash skills/ai-layout/scripts/check-risk.sh layout`, `bash skills/ai-layout/scripts/check-entrypoints.sh`, `bash skills/ai-layout/scripts/check-manifest.sh` and `bash skills/ai-layout/scripts/check-workspace.sh`.

- [x] Step 5 — The model routing entry (AC32, AC33).
  - Depends on: 3
  - Add `risk:` under `routing.tasks` in the `models.yaml` template, with `claude: claude-opus-5-5` and a blank `codex:`, and keep `enabled: false`. Update the shipped-template assertion in `check-model-selection.sh` (line 44) to expect that entry.
  - Tests, in `check-model-selection.sh` and in the `routing` group:
    - `template-routes-risk` (AC32): `models.js` parses the template to `tasks.risk = {claude: "claude-opus-5-5", codex: ""}`.
    - `disabled-no-effect` (AC33): with routing disabled, `select("claude","risk")` and `select("codex","risk")` equal the result before the change (tool default).
    - `enabled-unserved-model-errors` (AC33): with routing enabled and a fake gateway that rejects the model, `dispatch --task risk` gives the normal routing error. That is the same error shape as an unserved `plan` mapping.
    - `codex-blank-falls-back` (AC32): with routing enabled, the blank codex entry falls back and says so.
  - Verify (red): `bash skills/ai-layout/scripts/check-risk.sh routing`. `template-routes-risk` fails with "no routing.tasks.risk". The other cases pass as characterisation.
  - Verify (step):
    - `bash skills/ai-layout/scripts/check-risk.sh routing`
    - `bash skills/ai-layout/scripts/check-model-selection.sh`
    - `bash skills/ai-layout/scripts/check-interactive-model-routing.sh`
    - `bash skills/ai-layout/scripts/check-doctor.sh`: the template routing entry produces no doctor finding

- [x] Step 6 — The knowledge seam lists the new executor (AC31).
  - Depends on: 2
  - In both copies of `knowledge.md`, add `risk` to the agents and `/fc:risk` to the commands under "Who consults a source". The two files stay byte-identical.
  - Tests, in the `knowledge` group:
    - `knowledge-lists-risk` (AC31): both copies list `risk` and `/fc:risk`
    - `knowledge-copies-equal`
    - `agent-names-only-seam` (AC31): `agents/risk.md` names `ai-factory/docs/knowledge.md` and no source kind, provider or tool name
  - Verify (red): `bash skills/ai-layout/scripts/check-risk.sh knowledge`. `knowledge-lists-risk` fails with "knowledge.md does not list risk".
  - Verify (step): `bash skills/ai-layout/scripts/check-risk.sh knowledge` and `bash skills/ai-layout/scripts/check-paths.sh`.

- [x] Step 7 — Specifier, planner and reviewer read the assessment (AC24–AC28).
  - Depends on: 2
  - Add one short paragraph each, under the existing reading sections:
    - **Specifier:** if `ai-factory/risks/<this spec's ID>-*.md` exists, read only its latest section; every `open` blocker or major finding goes under Open questions, and the spec cites the path.
    - **Planner:** for the feature's ID, read only the latest section; each mitigation becomes a step or a risk check.
    - **Reviewer:** an eighth check, after check 7, that applies the rules in the Design. The JSON schema text is unchanged.

    Each paragraph ends: "No applicable assessment: nothing here changes."
  - Leave `tasks/plan.md` and `tasks/review.md` alone. Run `materialize-agents.js`.
  - Tests, in the `consumers` group:
    - `latest-section-only` (AC24): all three procedures say they use only the latest Reassessment section
    - `specifier-open-questions` (AC25): `open`, blocker and major are named; `mitigated`, `accepted` and `minor` are excluded; the path is cited
    - `planner-mitigations` (AC26)
    - `reviewer-mitigation-check` (AC27): `open` or `mitigated` without an implemented mitigation is a finding; `accepted` is skipped; the applicability rule uses the ID or the `Target:` line; checks 1–7 are byte-identical to `main`; the JSON schema block is byte-identical to `main`
    - `no-assessment-unchanged` (AC28): each paragraph is conditional on an applicable file; a fixture review input with no `risks/` file produces the same `reviewInput` from `runner.js` as before
    - `plan-task-unchanged` (AC29): `tasks/plan.md` is byte-identical to `main`
  - Verify (red): `bash skills/ai-layout/scripts/check-risk.sh consumers`.
    - The first four cases fail because no consumer mentions `ai-factory/risks/`.
    - `no-assessment-unchanged` and `plan-task-unchanged` pass as characterisation.
  - Verify (step):
    - `bash skills/ai-layout/scripts/check-risk.sh consumers`
    - `node skills/ai-layout/scripts/materialize-agents.js --check`
    - `bash skills/ai-layout/scripts/check-ids.sh procedures`: the planner and specifier still call the helper and do not count
    - `bash skills/ai-layout/scripts/check-loop.sh procedures`: the planner's `Depends on:` text is intact
    - `bash skills/ai-layout/scripts/check-review-gate.sh`
    - `bash skills/ai-layout/scripts/check-review-scope.sh`

- [x] Step 8 — `/fc:start` suggests `/fc:risk` on a risk trigger (AC29).
  - Depends on: 3
  - Add one sentence to rule 3: when a trigger is present, `reason` names `/fc:risk` as an optional next step; otherwise it does not. Reword the "Never return commands … or a next-phase chain" sentence so that this single optional mention is the stated exception (see Risks). The allowlist in rule 6 is unchanged.
  - Tests, in the `start` group:
    - `start-rule3-suggests-risk` (AC29)
    - `start-no-trigger-no-suggestion` (AC29): the sentence is conditional on the trigger
    - `start-allowlist-unchanged`: `validateStartResult` still rejects `{"status":"route","task":"risk"}`
  - Regenerate both wrappers; their text includes no task body, so this should be a no-op.
  - Verify (red): `bash skills/ai-layout/scripts/check-risk.sh start`. `start-rule3-suggests-risk` fails with "start.md never names /fc:risk".
  - Verify (step):
    - `bash skills/ai-layout/scripts/check-risk.sh start`
    - `bash skills/ai-layout/scripts/check-start-routing.sh`
    - `node skills/ai-layout/scripts/sync-claude-commands.js --check`
    - `node skills/ai-layout/scripts/sync-codex-skills.js --check`

- [x] Step 9 — Documentation, plugin descriptions and the changelog (AC3, AC20 citation, AC34, AC35).
  - Make the doc edits from the Files list. The CHANGELOG block is marked breaking for adopted repos and names:
    - the changed `planner`, `specifier`, `reviewer`, `start` and `models.yaml` templates;
    - the new `risk` agent and `/fc:risk` task;
    - the `ai-factory/risks/` directory, and that it is committed by default and may be ignored;
    - the network exception and its ADR.
  - Tests, in the `docs` group:
    - `no-eight-agents` (AC34): `workflow.md`, `fleet.md`, `FACTORY.md` and `README.md` contain no "eight agents"
    - `command-counts-25`: README, `workflow.md` and `SKILL.md` say 25, matching `ls commands/*.md`
    - `agents-md-lists-risk` (AC34): both `AGENTS.md` copies
    - `plugin-json-mentions-risk` (AC34): both manifests
    - `changelog-breaking-risk` (AC35): every name listed above
    - `no-old-names` (AC3), rerun over the docs
    - `spec-cites-adr` (AC20): `ai-factory/specs/0023-risk-agent.md` names the Step 1 ADR's path. This case stays red until the prerequisite amendment lands.
  - Verify (red): `bash skills/ai-layout/scripts/check-risk.sh docs`. Every case except `no-old-names` fails on today's text ("eight agents", 24, no `/fc:risk`, no CHANGELOG entry). `spec-cites-adr` fails until the spec is amended.
  - Verify (step):
    - `bash skills/ai-layout/scripts/check-risk.sh docs`
    - `bash skills/ai-layout/scripts/check-release-docs.sh`
    - `bash skills/ai-layout/scripts/check-versions.sh`
    - `bash skills/ai-layout/scripts/check-plugin-hosts.sh`

- [x] Step 10 — Host runs and final verification (the behaviour of AC4–AC8, AC15–AC18, AC21, AC25–AC27, AC29 and AC30).
  - **Host runs.** In a scratch adopted repo under `ai-factory/runs/tmp/`, with a legacy spec, its plan, a new-style spec, and a branch with a dependency lockfile, run these before and after the change:
    - `/fc:risk` on Claude Code, once each for a spec, a plan of the same ID (which appends; see Ambiguity 1), a working tree, a branch, and an unclear target (AC4–AC8, AC5);
    - `$fc-risk` on Codex for one spec;
    - `make -f ai-factory/make/ai.mk ai TASK=risk INPUT=…` for one clear target and one unclear target (AC30);
    - a rerun on the same branch, which must append a Reassessment with base and head commits (AC15–AC17);
    - one run with the network blocked (AC21);
    - `/fc:spec`, `/fc:plan`, `/fc:review` and `/fc:start` with and without an applicable assessment (AC25–AC29).

    After each run, `git status --porcelain` shows changes only under `ai-factory/risks/` (AC18). Link the transcripts in the MR, and mark the MR breaking (AC35). If the developer waives a host run, record which ACs are left proven only by static checks, as plan 0024 Step 8 did.
  - **Host runs waived (2026-10-26).** The developer waived the host runs. Skipped, both before and after the change:
    - Claude Code `/fc:risk` for a spec, a plan of the same ID (the append), a working tree, a branch and an unclear target;
    - Codex `$fc-risk` for one spec;
    - headless `make -f ai-factory/make/ai.mk ai TASK=risk INPUT=…` for one clear and one unclear target;
    - the rerun on the same branch that must append a Reassessment with base and head commits;
    - the run with the network blocked;
    - `/fc:spec`, `/fc:plan`, `/fc:review` and `/fc:start` with and without an applicable assessment;
    - the `git status --porcelain` check after each run.

    AC4, AC5, AC6, AC7, AC8, AC15, AC16, AC17, AC18, AC21, AC25, AC26, AC27, AC29 and AC30 are therefore unverified by host transcripts. So are AC28, which the host-run list above also names, and AC36. They rest only on the static checks: `check-risk.sh` (all groups) and the rest of the full-suite loop, including `check-start-routing.sh`, `check-model-selection.sh`, `check-ids.sh`, `check-loop.sh`, `check-runner-security.sh` and `check-write-boundary.sh`.
    These prompt-only behaviours are unobserved:
    - whether the model follows `/fc:start` rule 3's single optional `/fc:risk` suggestion and still returns only the allowlisted JSON (AC29);
    - the `risk` agent's `ids.js new risk` calls, its handling of exit 3, and its `Target:` matching for a change (AC6–AC8, AC15, AC16);
    - the spec-then-plan Reassessment appended to one shared risk file (AC36);
    - the audit tools' network use under ADR DJX496, the AC21 fallback when the network is blocked, and whether a headless host refuses the Bash call (AC21, AC30).
  - Verify (final):
    - `for f in skills/ai-hooks/scripts/*.js; do node --check "$f"; done`
    - `node --check skills/ai-layout/templates/ai-factory/make/sync-adapters.js`
    - `bash -n skills/ai-layout/scripts/check-risk.sh`
    - `node skills/ai-layout/scripts/materialize-agents.js --check`
    - `node skills/ai-layout/scripts/sync-claude-commands.js --check`
    - `node skills/ai-layout/scripts/sync-codex-skills.js --check`
    - `bash skills/ai-layout/scripts/check-risk.sh` (all groups)
    - `node ai-factory/make/ids.js check`
    - `bash ai-factory/make/sync-adapters.sh`, then `git status --short`: only the expected changes
    - `make check`: the whole suite, including spec 0012 AC10's `check-runner-security.sh` and `check-write-boundary.sh`, unchanged (AC19)
    - `node skills/ai-hooks/scripts/session-stop.js < skills/ai-hooks/fixtures/stop.json`

## Expected red, scoped to the next step

Only Step 1's red applies now:

| Test | Command | Expected failure and cause |
|---|---|---|
| `adr-records-audit-exception` | `bash skills/ai-layout/scripts/check-risk.sh adr` | Fails with "no ADR names the spec 0012 AC10 exception": no ADR in `ai-factory/adr/` records it yet |

A missing `check-risk.sh` is not red evidence: the harness is written first, then run. The red runs of later steps are listed in each step and apply when that step is next.

## Risks and how each is checked

- **The `/fc:start` "never return commands … next-phase chain" rule contradicts AC29.**
  - Step 8 rewords it so the single optional `/fc:risk` mention is the explicit exception.
  - `start-allowlist-unchanged` and `check-start-routing.sh` prove the JSON contract is intact.
  - The Step 10 `/fc:start` runs prove the model follows it.
- **The shipped `models.yaml` now carries a routing entry.**
  - `check-model-selection.sh` line 44 asserts `tasks:{}` and must change in Step 5. `disabled-no-effect` proves AC33.
  - `check-doctor.sh` proves doctor does not flag a shipped entry for an existing task.
- **The reviewer template is the most-used agent in every adopted repo.** `reviewer-mitigation-check` asserts that checks 1–7 and the verdict schema are byte-identical to `main`. The `/fc:review` before/after run in Step 10 is the acceptance evidence.
- **The planner and specifier procedures are also pinned by `check-ids.sh procedures` and `check-loop.sh procedures`.** Step 7 runs both, so a new paragraph cannot drop the helper call or the `Depends on:` text.
- **Network access leaks beyond the agent (AC19).**
  - `agent-audit-only-here` proves that only the `risk` agent names an audit tool.
  - No hook, runner or check script changes.
  - `make check` reruns spec 0012 AC10's fixtures.
- **Prompt-only compliance (AC4–AC8, AC15–AC18, AC21, AC25–AC30).** Static checks only show that the procedure says it. The Step 10 transcripts are the acceptance evidence. If they are waived, the plan records those ACs as unverified.
- **A headless host may refuse the agent's Bash call to `ids.js` or to an audit tool.** The `make ai TASK=risk` run in Step 10 proves it either way. A refused audit must take the AC21 fallback, never fail the run.
- **Committed threat detail.** The exploration's open question 1 is settled by AC22 and AC23: the directory is committed by default, and a repo that ignores it keeps that choice. `sync-keeps-user-ignore` proves it.
- **The template change breaks adopted repos.** The CHANGELOG and MR say so (AC35). `check-manifest.sh` and `check-workspace.sh` prove that adoption delivers the new task, agent and directory.
- **A leaked `{{…}}` placeholder.** The new task and agent use no braces. `check-workspace.sh` already scans the adopted output.

## Ambiguities in the spec

1. **The spec still names risk files `<NNNN>-<slug>.md` and `change-<slug>.md`, and keeps AC9.**
   - Spec 0024's Sequencing section requires 0023 to be amended: `ids.js new risk … --id` for a spec or plan target, a fresh ID for a change, and AC9 dropped. That amendment has not been made.
   - This plan follows 0024 and `ids.js`, which already implements the `risk` kind. It does not follow the file names in 0023.
   - One more consequence: `ids.js` allows one risk file per ID, so a spec assessment and a plan assessment of the same feature (AC6 and AC7) share one file. A plan assessment after a spec assessment is appended as a Reassessment whose `Target:` names the plan. The spec does not say this.
2. **How a change assessment is found again (AC16, and 0024's open item).** The file name no longer comes from the branch slug. This plan matches on the `Target:` line, comparing branch names. It does not compare base commits (spec Open question 2), so on a long-lived branch such as `main` every change appends to one file.
3. **A diff and a detached HEAD (Open questions 1 and 2).**
   - A supplied diff gets `Target: diff <path>` and is the same target only when the path is the same. A pasted diff (`Target: diff supplied`) always gets a new file.
   - A detached HEAD gets `Target: detached <head sha>`.

   The slug mapping (Open question 3) becomes cosmetic under 0024, because identity is the `Target:` line, not the name.
4. **Who sets `mitigated` and `accepted` (Open question 4).** This plan lets the agent set `mitigated` from cited evidence. It never lets the agent set `accepted`: that status comes only from the developer's hand edit, which the agent carries forward. Neither rule is in the criteria.
5. **The ADR (Open question 5).**
   - The spec says the next ADR is 0010. Since 0024, a new ADR takes a letter-and-digit ID from `ids.js new adr`.
   - This plan writes the ADR as Step 1 through `/fc:adr`. It cites spec 0012 and does not amend it.
   - AC20's "this spec cites it" needs an edit to spec 0023, which a plan cannot make. It is part of the prerequisite amendment, and `spec-cites-adr` stays red until that amendment lands.
6. **AC22 "adopts or syncs".** Adoption copies `risks/.gitkeep`. `/fc:sync-sdlc` is pull-only (ADR 0002), and `manifest.js` skips `.gitkeep`, so an existing adopter gets `ai-factory/risks/` only when `ids.js` first creates it (`ids-creates-risks-dir`). This plan does not make sync create the directory.
7. **The check task is now `review`.** The spec's "reviewer checks 6 and 7" still holds. Any reference to `/fc:check` that the exploration carried over is written as `/fc:review` in this plan.
