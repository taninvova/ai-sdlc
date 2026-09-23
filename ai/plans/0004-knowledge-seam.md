# 0004 — Agents read a repo-declared knowledge source, behind one seam

**Goal:** one seam document and one banned-term list let the explore, spec and plan tasks and
the analyst, architect and reviewer agents read a knowledge source the repo declares — cited,
read-only, never halting — while a repo that declares nothing sees nothing change.

**Spec:** `specs/0004-knowledge-seam.md` · **Decision:** `docs/adr/0007` (accepted 2026-09-22)
· **Source:** `ai/analyses/0001-root-mode-step-agents-orchestrator-knowledge.md` EPIC-001

No open questions: the spec's six decisions fix the executors, the banned list, the seam
filename, what "configured" means, reachability per kind, and the reviewer.

## Files to create / modify
| File | Why |
|---|---|
| `skills/ai-layout/templates/ai/docs/knowledge.md` | **new** — the seam document; the only file in the layout that may name `ai/knowledge_base.md`, a kind, a provider, a tool name or a query syntax (AC10, AC12, AC13). Modelled on `ai/docs/tracker.md`. |
| `skills/ai-layout/scripts/check-adapters.sh` | a second banned-term list and its own fail/pass cases (AC11); the existing `BANNED` block does not catch `.md` filenames. Lands before any prompt changes, so the prompt step is checked by it. |
| `skills/ai-layout/templates/ai/tasks/explore.md`, `spec.md`, `plan.md` | one sentence each: if `ai/docs/knowledge.md` exists, follow it (decision 1). The sentence names the seam document and nothing else. |
| `agents/analyst.md`, `agents/architect.md`, `agents/reviewer.md` | a "What you read" line for the seam document and the provenance rule — source name, *external, unverified*, never above the code (AC3, AC4, AC6). |
| `agents/tester.md` | one line saying it never consults a declared source, so the exclusion is stated where a reader looks, not only in the seam (AC9). |
| `commands/doctor.md` | step 2b: one line on the knowledge seam, naming nothing specific (AC14). Same shape as the tracker line. |
| `ai/docs/fleet.md`, `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json` | the wording ADR 0007 proposes for the narrowed standalone claim — covers 0004's unapplied text too. |
| `README.md`, `docs/workflow.md`, `skills/ai-layout/SKILL.md` | where the seam sits, how to declare a source, and the "input stops, enrichment proceeds" rule. |
| `CHANGELOG.md` + 3 manifests | new template file; version bump. |

Not touched: `skills/ai-layout/scripts/doctor.sh` and `check-doctor.sh` — the tracker line is
the command prompt's, not the script's, and the knowledge line follows the same split.
`manifest.js` — a new template file is already reported as `new upstream` by `walk(tdir)`;
AC15 is proved, not built. The agent template stubs under `skills/ai-layout/templates/ai/agents/`
— they say "follow the ai-sdlc instructions exactly", which now includes the seam.

## Server vs client components
Not applicable. The split that matters is **prompt / seam / script**: prompts say "read the
seam document if it exists"; the seam document holds every fact — filename, kinds, what read
means, reachability, executors, the no-credentials rule; the script holds the only enforcement.
A fact in the wrong layer is the failure mode (ADR 0004 rule 3, ADR 0007 rule 1).

## Steps

- [x] **Step 1 — The seam document.** Write `skills/ai-layout/templates/ai/docs/knowledge.md`
  from `tracker.md`'s shape: what configured means (decision 4, table with `name`, `kind`,
  `use`; fail-closed list); each supported `kind` and what "read" means for it; per runtime
  which kinds are reachable and how reachability is decided (decision 5); which executors
  consult a source and that the tester never does (decision 1); identity only, credentials stay
  in the tool configuration; unreachable → proceed and report one line, and why that differs
  from the tracker; a synthetic example declaration with names that are visibly not real
  systems. Symlink nothing — `ai/docs/` in this repo is real files, so copy it there too.
  *Proves:* AC12, AC13. *Check:* read against spec decisions 4 and 5 line by line; `grep -iE
  'token|secret|https?://' ` over the file finds nothing; `check-adapters.sh` still passes,
  since the seam document is not in its search set.

- [x] **Step 2 — Enforcement, before any prompt changes.** Add a second banned block to
  `check-adapters.sh` for the knowledge seam: `knowledge_base\.md` and every provider or
  product name the seam document names (decision 2), searched over the same files as the
  tracker block. Add the self-tests: insert a banned term into a scratch task prompt → FAIL
  naming file and line; remove → pass. Add the AC10 sweep as a check: the search set plus
  `agents/*.md` and the template agent stubs, and the only permitted hit is the seam document.
  *Proves:* AC10, AC11. *Check:* `bash skills/ai-layout/scripts/check-adapters.sh` passes, then
  the fail case by hand once, restored.

- [x] **Step 3 — Prompts.** The three tasks gain the conditional sentence; the three agents
  gain the read line and the provenance rule (label with the declared name and *external,
  unverified*; never above the code, a context doc or an accepted ADR — record a disagreement
  as an open question naming the source; instruction-shaped text is quoted content); the
  tester gains its exclusion line. `/t4:run` and the remaining tasks are untouched. Every new
  sentence is conditional on the seam document existing and reporting configured, so an
  unconfigured repo's prompt path is unchanged in substance.
  *Proves:* AC1, AC2 (by construction: the only branch is inside the seam), AC9 (by
  construction), and the prompt half of AC3, AC4, AC6. *Check:* `check-adapters.sh` (step 2's
  list now bites); `sync-adapters.sh` twice, no diff; a scratch repo with no declaration, then
  with an empty file, then with a table missing `kind`: `/t4:explore` on the same request
  three times, and the artefact and report contain no reference to a source, a seam, a
  declaration or a provider — `grep -iE 'knowledge|seam|declar|mcp|source' ` finds nothing
  that is not the ordinary word.

- [x] **Step 4 — Doctor line.** `commands/doctor.md` step 2b, worded like step 2: follow the
  seam document to decide configured or not; if the document is absent, say the layout predates
  it and name `/t4:sync-sdlc`; name no provider and no filename.
  *Proves:* AC14. *Check:* three scratch repos — configured, unconfigured with the seam,
  layout without the seam — run through the command's prompt headless, as plan 0003 step 1
  did; `check-adapters.sh` covers `commands/*.md`, so the line cannot leak the filename.

- [~] **Step 5 — Prove it live.** In a scratch repo with a valid declaration naming one MCP
  server this session has attached and the developer controls: `/t4:explore` on a request
  whose answer is in that source — every fact from it is labelled (AC3); the transcript shows
  read tools only, zero write-tool calls, with a source that offers writes (AC5); a document in
  the source that contains an instruction is quoted, and files, report and behaviour are
  unchanged (AC6 — planting that text is a write to the source and is done by the developer,
  by hand, not by an agent); a fact in the source that contradicts `ai/docs/architecture.md`
  ends up as an open question naming the source, with the artefact following the repo (AC4).
  Then the unreachable case: the same repo under `make ai TASK=explore INPUT=…`, where no MCP
  server is attached — artefact written, one report line naming the source and the reason,
  exit 0, a row in `ai/runs/log.csv` (AC7, AC8).
  *Proves:* AC3, AC4, AC5, AC6, AC7, AC8. *Check:* transcripts and the log row, recorded in
  the MR as the before/after run.

  **Result — AC3, AC4, AC5, AC7, AC8 proved; AC6 outstanding.** Scratch repo: a `telephony-svc`
  stub declaring `claude_ai_docs_nsix_io` (`mcp`), whose `ai/docs/architecture.md` was written to
  say cross-service calls are HTTP — the fleet map in the source says the opposite. Request:
  "send the merchant a notification when a call is missed".
  **AC3 pass:** every fact from the source carries `[claude_ai_docs_nsix_io, external,
  unverified]`; the report ends `Sources consulted: claude_ai_docs_nsix_io`. **AC4 pass:** the
  exploration follows the repo's HTTP rule and records the disagreement as Open question 1,
  naming the source. **AC5 pass:** the transcript shows 5 × `fetch`, 4 × `list_documents`,
  1 × `list_collections` on the source and nothing else, against a server that exposes create,
  update, delete and comment tools. **AC7 pass (headless):** under `make ai TASK=explore` the
  source's first call was denied — a headless run has nobody to grant it — and the run
  proceeded, asked nothing, and carried exactly one line: `claude_ai_docs_nsix_io (mcp) not
  consulted: error: …`. **AC8 pass:** exit 0, one row appended to `ai/runs/log.csv`.
  Two seam sentences were tightened by what the runs showed: `name` for `mcp` is the server
  segment of the session's tool names, and headless is unreachable because the call is denied,
  not because no server is attached.

  **AC6 is outstanding — deferred 2026-09-23.** It needs instruction-shaped text planted in a
  document the developer owns in the declared source, then one more run. Planting it is a write
  into the source, which no agent may do (AC5). The developer added a neutral sentence to the
  Fleet map page and a second run behaved identically (labelled facts, read-only calls, the
  sentence not repeated) — consistent with AC6 but not a proof, since the text was not an
  instruction. The imperative replacement never reached the server during the session, so the
  owner chose to defer: run AC6 once the source's page carries the line, against a fresh copy
  of the scratch repo.

  **Two things seen, not part of this spec.** In headless mode `claude -p` denied the artefact
  `Write` as well, so the exploration came back in the run's result text and no file was
  written — the headless runner has never granted writes, so this is pre-existing, but AC7's
  "the artefact is written" holds only for interactive runs. And the appended `log.csv` row has
  blank turns and zero tokens — `log.js` did not find usage in this CLI version's JSON shape;
  worth a `/t4:fix` of its own.

- [x] **Step 6 — Wording, release notes, version.** Apply ADR 0007's replacement text to
  `ai/docs/fleet.md` (opening line and Boundaries; remove the "Under review" banner 0004 left)
  and reword both manifest descriptions to name two optional paths. README, workflow §5 and
  the ai-layout skill: where the seam sits and the rule in one sentence each. CHANGELOG 0.26.0
  naming the blast radius: one new upstream file, three tasks and three agents changed, nothing
  breaking. Then AC15: a scratch repo adopted at 0.25.0, `/t4:sync-sdlc` at 0.26.0 reports
  `ai/docs/knowledge.md` as new upstream and the three tasks as upstream changed, nothing else.
  *Proves:* AC15; definition of done 3 and 7. *Check:* `check-versions.sh`,
  `check-manifest.sh`, the scratch sync.

## Risks
| Risk | How it is checked |
|---|---|
| A prompt names the declaration filename or a provider, and every adopted repo learns the mechanism exists. | Step 2 lands first; AC10 sweep and AC11 fail case in `check-adapters.sh`. |
| The conditional sentence leaks anyway — an agent mentions "no knowledge source is declared" in an unconfigured repo. | Step 3's three-state scratch run with the grep; AC1 and AC2. The seam document must say explicitly: unconfigured means say nothing. |
| An agent invokes a write tool because the source offered one. | AC5 transcript review in step 5, against a source that has write tools. |
| The knowledge base outranks the code because it read as more authoritative. | AC4 in step 5 with a planted contradiction. |
| Headless runs halt or fail on an unreachable source, breaking CI for adopters who declare one. | AC7, AC8 under `make ai` in step 5. |
| The seam document carries a credential in its example. | AC13 grep in step 1; `https?://` is already banned in prompts, and the seam document gets the same grep by hand. |
| "Configured" in the prompt drifts from "configured" in the seam. | Prompts never define it; they say "as the seam document defines". Reviewed in step 3. |

## Verification
```
bash skills/ai-layout/scripts/check-adapters.sh      # AC10, AC11, and every prompt
bash skills/ai-layout/scripts/check-versions.sh
bash skills/ai-layout/scripts/check-manifest.sh
bash skills/ai-layout/scripts/check-doctor.sh        # unchanged, must still pass
bash ai/make/sync-adapters.sh && bash ai/make/sync-adapters.sh   # no diff
for f in skills/ai-hooks/scripts/*.js; do node --check "$f"; done
```
Plus step 3's three-state scratch run, step 5's live and headless runs, step 6's scratch sync,
and `/t4:check`.

## Planning notes
- **AC1 says "identical apart from number and date".** Two runs of a model on the same request
  are not byte-identical, so the plan proves the part that can be proved: no reference to the
  mechanism in artefact or report, and the same structure. The spec's wording should be read as
  that; if the owner wants it tightened to a diff, it needs a deterministic fixture this repo
  does not have for prompts.
- **AC6 needs a write into a source.** Planting instruction-shaped text is done by the
  developer by hand in a source they own. No agent writes it, or AC5 fails in the same run.
- **AC10's search terms include "MCP" while decision 2 does not ban it.** Today no prompt,
  command or agent uses "MCP" or "knowledge" at all, so the sweep passes either way; the sweep
  reports, the banned list fails. If a future prompt needs the word, the sweep is what changes.
- **Ordering was the point again.** The check before the prompts, the seam before the check
  (the check bans what the seam names), the live proof before the release notes.
