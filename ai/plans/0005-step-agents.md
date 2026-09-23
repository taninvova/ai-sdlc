# 0005 — Step agents: explorer, specifier, planner, implementer

**Goal:** the four loop steps run in agents of their own, each starting from its artefacts and
nothing else, while the task prompts keep the refusal, the question and the report that only a
session can give — and the one enforced rule, the dont-touch guard, is shown to hold inside the
implementer.

**Spec:** `specs/0005-step-agents.md` · **Decisions:** DEC-002, DEC-010 in `ai/analyses/0001`;
the spec's four decisions (no knowledge source for the implementer; not breaking; absent tests
stop and explain; headless reach measured).

No open questions.

## Files to create / modify
| File | Why |
|---|---|
| `agents/explorer.md`, `agents/specifier.md`, `agents/planner.md`, `agents/implementer.md` | **new** — each carries what its task prompt says today: reading list, steps, artefact format, prohibitions, report. Frontmatter as the existing four. |
| `skills/ai-layout/templates/ai/agents/{explorer,specifier,planner,implementer}.md` | **new** — project stubs in the shape of the existing ones: "follow the ai-sdlc X instructions exactly" plus fill-in lines for project conventions. |
| `skills/ai-layout/templates/ai/tasks/{explore,spec,plan,run}.md` | delegation line, the relay instruction, the empty-argument refusal kept in the session; the steps that moved out are removed so the prompt and the agent do not fork. The tracker paragraph in `spec.md` stays in the session: resolving a key and stopping on failure is a session act (FR-015). |
| `skills/ai-layout/templates/ai/docs/knowledge.md` + `ai/docs/knowledge.md` | executor list names the three agents; implementer stated as not consulting (decision 1). |
| `skills/ai-hooks/SKILL.md`, `docs/workflow.md` §9 | one sentence: tokens spent inside a subagent are not in the session row (AC9). |
| `docs/workflow.md` §5, §8; `skills/ai-layout/SKILL.md`; `README.md` | eight agents listed; Codex table names all eight as inlined; the tree gains four stub lines. |
| `CHANGELOG.md` + 3 manifests | 0.27.0; blast radius: four prompts changed, four stubs new, not breaking, merge by hand if a prompt was edited. |
| `ai/docs/fleet.md`, `commands/adopt-sdlc.md` | one-line consistency: "four agents" becomes eight. |

Not touched: `check-adapters.sh` — its delegation assertions already cover any task that
delegates, and it fails if a note is missing (AC2). `guard-paths.js` — AC8 proves it, it does
not change it. `agents/{reviewer,tester,architect,analyst}.md` and their stubs — AC10; the one
`agents/tester.md` change the 0004 reviewer suggested (a say-nothing clause) is a 0004
follow-up chore, not this plan. `ai/models.yaml`, `hooks/hooks.json` — AC11, out of scope.

## Server vs client components
Not applicable. The split that matters is **session versus agent**: the session refuses an
empty argument, asks the developer, resolves a tracker key, and relays; the agent reads
artefacts and writes one artefact. A sentence in the wrong place is the failure mode — a
question inside the agent is guessed (a subagent cannot ask), and a step inside the session
sees the chat it was meant not to see.

## Steps

- [x] **Step 1 — The four agents.** Write `agents/explorer.md`, `specifier.md`, `planner.md`,
  `implementer.md`. Each: frontmatter (`name`, `description`, `tools: Read, Grep, Glob, Write,
  Edit, Bash`, `model: inherit`); "What you read"; "What you may write" with the single target
  and the prohibitions moved verbatim from the task prompt; the artefact format the prompt
  specifies today; "When you cannot proceed" — the cases FR-015 names, returned as a question
  with no artefact written for that decision; "Report" — the same report as today. The
  implementer additionally: implement ONLY the step named, never the next; tests it cannot
  find or run → stop and explain, naming the command tried (decision 3); tick the checkbox
  only when green. The explorer, specifier and planner carry the knowledge-seam read line the
  tasks carry today; the implementer carries a one-line exclusion (decision 1).
  *Proves:* AC1 (agents half), AC3, AC11. *Check:* frontmatter grep; every prohibition in the
  four task prompts found in the matching agent by grep; `check-adapters.sh` AC10 sweep passes
  over `agents/*.md`.

- [x] **Step 2 — The stubs and the seam list.** Four project stubs under the templates in the
  shape of the existing ones; `ai/docs/knowledge.md` executor section in both copies names
  explorer, specifier, planner and says the implementer consults nothing.
  *Proves:* AC1 (stubs half), AC12. *Check:* `diff` of the two seam copies empty;
  `check-adapters.sh`.

- [x] **Step 3 — The task prompts delegate.** `explore.md`, `spec.md`, `plan.md`, `run.md`: keep
  the empty-argument paragraph in the session, where it was — last, before `$ARGUMENTS`; for `spec.md` keep the tracker paragraph
  in the session and pass the resolved description to the specifier as the request; add
  ``Delegate to the `<agent>` subagent`` with the relay instruction ("return its report
  unchanged"); remove the moved steps. Then `sync-adapters.sh` and `check-adapters.sh`.
  *Proves:* AC2, and AC5/AC6 by construction. *Check:* nine Codex skills carry the note; the
  four name the right agent; `check-adapters.sh` hint→prompt assertion still passes; sync
  twice, no diff.

- [x] **Step 4 — Prove the four steps live.** Scratch repo built from the templates with a
  small fake project and two specs. Under Claude Code, through the task prompts:
  `/t4:explore` (explorer in the transcript; report = path and option), `/t4:spec` (specifier;
  path and open questions), `/t4:plan` (planner; path and ambiguities), `/t4:run … step 1`
  (implementer; files, tests, what the plan got wrong). Then the empty argument for each: the
  session asks, lists the two specs for `/t4:plan`, and no agent appears in the transcript.
  Then one headless `make ai TASK=explore` in the same repo, reported either way (decision 4).
  *Proves:* AC4, AC5, and the headless measurement. *Check:* transcript greps for the agent
  names; report shapes compared with a pre-change run of the same request.

  **Result — AC4 and AC5 proved; headless measured.** Scratch repo from the release templates
  (a Node library with two functions and two tests), the plugin loaded from this working tree,
  each command run as a real headless Claude Code session (`claude -p "/t4:<task> …"`,
  stream-json transcript kept). Same feature through all four steps:
  `/t4:explore` → `explorer` in the transcript, `ai/explorations/0001-export-report-csv.md`,
  report = path and recommended option. `/t4:spec` → `specifier`, `specs/0001-…md`, report =
  path and open questions. `/t4:plan` → `planner`, `ai/plans/0001-…md`, report = path and what
  made planning ambiguous — and it found a real defect in the scratch scaffold: on Node 22
  `node --test test/` treats the argument as a glob and fails before any change. `/t4:run …
  step 1` → `implementer`: added `renderCsv` and its tests, tests pass by direct path, and it
  left the checkbox unticked with an explanation because the plan's own `npm test` command
  cannot go green — decision 3's behaviour, unprompted. No session edited a file itself.
  **AC5 pass:** all four commands with nothing after the name → the session asked and stopped;
  no `subagent_type` in any of the four transcripts; `/t4:plan` listed the three spec paths.
  **Headless reach (decision 4): yes.** `make ai TASK=explore` invoked the `explorer` inside
  `claude -p`; as before, the runner's `Write` was denied so the exploration came back in the
  result text. The hooks also fired in every headless session: `ai/runs/sessions.jsonl` and
  `cmds.jsonl` grew, and the flush hook moved pending rows into `log.csv` on the scratch
  commits.

- [x] **Step 5 — Questions come back; red stays red; the guard holds.** In the scratch repo:
  a plan step whose test cannot go green → the implementer stops, box unticked, explanation
  (AC7); a plan step naming a test file that does not exist → stop and explain, naming what it
  tried (decision 3); `/t4:plan` with two specs and none named → the session asks (AC6). Then
  AC8: add `prisma/migrations/` to the scratch repo's `ai/docs/dont-touch.md`, give the
  implementer a step that writes there, and confirm the guard's message
  ("Blocked by ai/docs/dont-touch.md …") appears in the transcript and the file is absent.
  This run is what turns DEC-010's first half into evidence; if the guard does not fire, stop
  and report — the release does not ship an unguarded implementer.
  *Proves:* AC6, AC7, AC8. *Check:* transcripts; `ls` of the guarded path.

  **Result — AC6, AC7, AC8 proved.** Same scratch repo and headless-session method as step 4;
  the scaffold's test script fixed first so red and green mean something; `prisma/migrations/`
  added to its `ai/docs/dont-touch.md`; a three-step plan of deliberate stop cases.
  **AC7 pass:** a step demanding a test that contradicts the spec, with the only fix forbidden
  — the implementer wrote the test, saw 13 pass / 1 fail, deleted it, left the box unticked and
  explained the contradiction. **Decision 3 pass:** a step naming `npm run e2e`, which does
  not exist — it stopped, quoted the npm error, named what it tried, invented nothing.
  **AC6:** the two-specs case was proved in step 4 (`/t4:plan` listed the paths and asked); the
  implementer's two stops above came back to the session as explanations, not guesses. The
  unresolvable-tracker-key case was not run — no tracker is configured in the scratch repo and
  that path did not change in this plan.
  **AC8 pass, two ways.** (1) The implementer, given a step that writes under
  `prisma/migrations/`, read the rule and refused before calling Write; no file, box unticked.
  (2) Because that proves the prompt and not the hook, a probe: a plain `general-purpose`
  subagent with no knowledge of the rule, told to write the file and report the tool result
  verbatim. Its Write was blocked by the PreToolUse hook with the guard's own message —
  `Blocked by ai/docs/dont-touch.md: "prisma/migrations/0001_init.sql" matches rule
  "prisma/migrations/"` — the file was not created, and the hook's stderr appears five times in
  the outer transcript. DEC-010's first half is now evidence, not a supplied fact.

- [x] **Step 6 — Docs, release notes, version.** AC9's sentence in `skills/ai-hooks/SKILL.md`
  and workflow §9; workflow §5 (eight agents, one line each) and §8 (Codex row names eight);
  ai-layout skill tree (four stubs); README agents list; CHANGELOG 0.27.0 naming the blast
  radius per decision 2; version bump. Then AC14: a scratch repo adopted at 0.26.0, one prompt
  edited by hand, `manifest.js check` against this tree → four prompts upstream changed (the
  edited one "both changed"), four stubs new upstream, nothing else.
  *Proves:* AC9, AC13, AC14; definition of done 3 and 7. *Check:* `check-versions.sh`,
  `check-manifest.sh`, the scratch check.

  **Result.** AC9: the hooks skill and workflow §9 state the under-count. AC13: workflow §5
  lists eight agents, §8's Codex row names all eight, the seam paragraph names the agents.
  AC14: a repo adopted from the 0.26.0 templates with `ai/tasks/spec.md` edited by hand,
  checked against this tree — four upstream changed (three prompts and the seam document's
  executor paragraph), `spec.md` both changed, four agent stubs new upstream, nothing else.
  AC10: `git diff` on the four existing agents and their stubs since the spec commit is
  empty. check-versions, check-adapters, check-manifest, check-doctor pass; sync idempotent.

## Risks
| Risk | How it is checked |
|---|---|
| The guard does not fire inside a subagent, and the implementer is the first agent that edits source. | AC8 in step 5, before the release; a failure stops the plan. |
| A question moves into an agent and gets guessed instead of asked. | AC5 and AC6 in steps 4–5; the tracker paragraph stays in `spec.md` by design. |
| The prompt and its agent fork — a prohibition kept in one and lost in the other. | Step 1's grep of every prohibition; step 3 removes the moved text rather than duplicating it. |
| Report shape drifts, breaking what developers and the future orchestrator read. | AC4's side-by-side with a pre-change run. |
| An adopter who edited `spec.md` for their tracker loses the edit on sync. | AC14 shows "both changed"; CHANGELOG says merge by hand (decision 2). |
| Cost rows silently under-count once steps delegate. | AC9 documents it; PROP-013 is the follow-up, out of scope. |

## Verification
```
bash skills/ai-layout/scripts/check-adapters.sh      # AC2, AC10 sweep over the new agents
bash skills/ai-layout/scripts/check-versions.sh
bash skills/ai-layout/scripts/check-manifest.sh
bash skills/ai-layout/scripts/check-doctor.sh
bash ai/make/sync-adapters.sh && bash ai/make/sync-adapters.sh   # no diff
for f in skills/ai-hooks/scripts/*.js; do node --check "$f"; done
git diff --stat -- agents/reviewer.md agents/tester.md agents/architect.md agents/analyst.md   # empty (AC10)
```
Plus steps 4–5's scratch runs and `/t4:check`.

## Planning notes
- **Step 1 before step 3, deliberately.** An agent must exist before a prompt delegates to it;
  the reverse order leaves a window where `/t4:spec` delegates to nothing.
- **AC8 is the gate.** Everything else in this plan is a move; AC8 is the one thing that could
  make the release unsafe. It is in step 5, before the docs and the version, so a failure is
  cheap to stop on.
- **The spec's AC4 names one request for all four steps.** Running the four steps on the same
  feature in one scratch repo is both the cheapest and the most honest proof: the specifier
  reads the explorer's file, the planner the specifier's, the implementer the planner's.
- **Nothing here changes what a step produces.** If a run in step 4 produces a different
  artefact shape from the pre-change run, that is a defect in the agent, not a new format.
