# Artifact contracts

Contracts add deterministic checks between workflow steps, so a malformed, incomplete or stale spec, plan, checklist or verification result is never silently used as the next step's input. You keep writing Markdown. Small JSON sidecars next to it record what a machine can check. `ai-factory/make/contracts.js` validates them using Node's built-in modules only.

**Contracts check structure, not quality.** A `valid` result means the IDs, references, content digests and recorded executions are consistent with each other. It never means a requirement is correct, complete or well tested. Every validator output repeats this.

## How to use it

Commands below use `make` as shorthand for `make -f ai-factory/make/ai.mk`. `<id>` is the delivery ID. You can find it in the spec's `.contract.json` or in the line `init spec` prints.

### 1. Turn it on, once per repo

```
node ai-factory/make/contracts.js enable
git add ai-factory/contracts/config.json ai-factory/.sdlc.json
```

From then on, `/t4:spec`, `/t4:plan`, `/t4:test`, `/t4:run`, `/t4:check` and `/t4:quick` maintain the contracts themselves. You rarely run the commands below by hand, except to see where a delivery stands or to fix what a diagnostic points at.

**Choose the code scope.** Before the first delivery, pick the files that count as code in `ai-factory/contracts/config.json`. The default `include: ["**"]` covers every tracked and untracked file that Git does not ignore. Add the output your tests generate to `exclude`, such as coverage or snapshots that are not gitignored:

```json
{
  "schema": "t4-contracts-config",
  "version": 1,
  "code_scope": { "include": ["src/**", "test/**", "package.json"], "exclude": ["test/__snapshots__/**"] }
}
```

If a verification run changes an in-scope file, the validator reports `E_EVIDENCE_UNSTABLE`, and that is the sign something belongs in `exclude`.

### 2. A planned feature: spec → plan → test → run → check

**Spec.** `/t4:spec <request>` writes the spec as usual, then runs `contracts.js init spec`. Criteria must be numbered so the validator can find them:

```
| ID | Given / When / Then |
|---|---|
| AC1 | Given a report with rows, when it is exported, then the CSV has one line per row. |
| AC2 | Given a value containing a comma, when it is exported, then the value is quoted. |
```

`init spec` prints the new delivery ID:

```
contracts: wrote ai-factory/specs/0007-csv-export.contract.json (d-20260930-c4cc51) — valid
```

**Plan.** `/t4:plan <spec>` names the criteria each step covers and each step's checks, then runs `contracts.js init plan`:

```
- [ ] **Step 1 — Rows to lines.** AC1. Verify (red): `npm test -- export.rows` Verify: `npm test -- export.rows`
- [ ] **Step 2 — Quote commas.** AC2. Verify: `npm test -- export.quote` Verify (final): `npm run check`
```

- Write each check as ``Verify (red|step|final): `command` ``. The phase defaults to `step`.
- Commands run as plain arguments, not through a shell. Put anything that needs quotes, pipes or `&&` in a script or make target, then call that.
- Every AC must be named by some step, and at least one step needs a `final` command. `init plan` reports anything missing, and the planner fixes the plan until the report is clean.

**Tests (red).** `/t4:test <spec> red` writes the failing tests, then records that they fail:

```
make verify DELIVERY=<id> STEP=S1 PHASE=red
contracts: recorded failed (red, expected fail) → ai-factory/evidence/<id>/S1-red.json
```

A red run that passes is reported as `E_RED_PASSED`. It means the test checks nothing.

**Run.** Each `/t4:run <plan> step N` implements one step and records its checks. It ticks the box only if the recording passes and validation stays `valid`:

```
make verify DELIVERY=<id> STEP=S1
make contracts DELIVERY=<id>
```

The last step also records final verification with `make verify DELIVERY=<id> PHASE=final`. Once every step is ticked, final evidence is required.

**Check.** `/t4:check` runs the read-only validator and reports anything that is not valid as a review finding. Headless, `make review DELIVERY=<id>` also records review evidence. Before merging, require both final and review evidence:

```
make contracts DELIVERY=<id> REQUIRE=final,review
```

### 3. Quick work

With contracts enabled, `/t4:quick` writes its checklist to `ai-factory/quick/<slug>.md` instead of the chat:

```
- [ ] QC1 — The footer shows dates as YYYY-MM-DD.
- [ ] QC2 — Existing footer tests still pass.

Verify (final): `npm test -- footer`
```

It runs `contracts.js init quick` on the checklist, ticks the items, and finishes with `make verify DELIVERY=<id>`. There is no spec, plan or step number.

### 4. Where does a delivery stand?

```
make contracts                          # every delivery, plus legacy artifacts
make contracts DELIVERY=<id>            # one delivery
make contracts DELIVERY=<id> JSON=1     # the same, as one JSON document for CI or scripts
node ai-factory/make/contracts.js validate ai-factory/specs/0007-csv-export.md   # by artifact path
```

Each artifact gets a line with its state. A line that is not valid carries a diagnostic code and a hint. For example:

```
contracts: invalid — d-20260930-c4cc51
  [invalid] ai-factory/evidence/d-20260930-c4cc51/S1-step.json
    E_EVIDENCE_NOT_RUN ai-factory/evidence/d-20260930-c4cc51/S1-step.json: not_run: Step 1 is ticked but has no recorded verification
      → Run make verify for this scope; a checked box is not execution proof.
```

The command exits `0` only when everything is valid, so the same command works as a CI gate.

### 5. Fixing what it reports

| You see | Why | Do |
|---|---|---|
| `E_DUP_ID`, `E_MISSING_ID` | Criteria or steps are duplicated, unnumbered, or disagree with the sidecar. | Fix the numbering in the Markdown, then rerun `contracts.js init spec` or `init plan` on it. |
| `E_UNKNOWN_REF`, `E_UNCOVERED_AC` | A step names an AC the spec doesn't have, or an AC is covered by no step. | Fix the step's AC references, then rerun `init plan`. |
| `E_NO_VERIFY` | A step has no command, or the plan has no `final` check. | Add a `Verify (…)` command, then rerun `init plan`. |
| `S_ARTIFACT_CHANGED` | The Markdown was edited after its sidecar was written. | Rerun `init` on that file. Its dependents then turn stale, as intended. |
| `S_SPEC_CHANGED` on the plan | The spec changed after planning. | Check the plan still fits, then rerun `init plan`. |
| `S_SPEC_CHANGED`, `S_PLAN_CHANGED`, `S_CODE_CHANGED` on evidence | What was verified is no longer what exists. | Run the same `make verify` (or `make review`) again. |
| `E_EVIDENCE_FAILED`, `E_EVIDENCE_UNAVAILABLE`, `E_EVIDENCE_NOT_RUN` | The check failed, could not start, or never ran. | Fix the cause and record again. If a check truly cannot run, record that honestly with `node ai-factory/make/contracts.js record --delivery <id> --step S<N> --not-run --reason "…"`. The result stays not valid. |
| `E_RED_PASSED`, `E_RED_NOT_FINAL` | A red test passes before the code exists, or a red run was used as final verification. | Fix the test, or run the final phase. |
| `E_EVIDENCE_UNSTABLE` | The checks changed in-scope files while running. | Add that output to `code_scope.exclude`. |
| `E_PATH_ESCAPE`, `E_SYMLINK` | An artifact path leaves the project or goes through a symlink. | Use a regular file inside `ai-factory/`. |
| `L_NO_SIDECAR`, `L_REVIEW_REQUIRED` | An artifact from before contracts, or an unreviewed migration draft. | See the next section. |

Never edit a `.contract.json` or an evidence file by hand. Change the Markdown or the code, then rerun `init` or `make verify`.

### 6. A repo that already has specs and plans

```
node ai-factory/make/contracts.js migrate          # dry run: prints what it would draft
node ai-factory/make/contracts.js migrate --write  # writes the drafts
```

- **What it drafts.** Each spec with numbered ACs gets a sidecar. Each plan gets one linked to its spec, found through the plan's `**Spec:**` line or its number.
- **What it skips.** A spec without AC IDs is skipped with a reason, because migration never invents IDs.
- **Reviewing drafts.** Drafts are `legacy_unverified` (`L_REVIEW_REQUIRED`). Review the extracted IDs and commands, then rerun `init spec` or `init plan` on the Markdown to accept them.
- **Old ticked steps.** Steps that were already ticked still need evidence. Record it again, or leave the old plan as legacy history.

### 7. The completion report

Once review is done, or at any point you want to know where a delivery stands, run `/t4:report <id>`. It is the same as:

```
make delivery-report DELIVERY=<id>            # writes ai-factory/reports/<id>/completion.md and .json
make delivery-report DELIVERY=<id> JSON=1     # also prints the JSON document, for scripts
```

The report reads only this delivery's sidecars, Markdown and evidence, plus optional telemetry. It runs no check, edits nothing else and publishes nothing. It holds:
- what was requested;
- one row per AC or QC, showing its steps, checks, result and evidence;
- the changed files and the verification that actually ran;
- the review verdict and findings;
- open questions, risks and follow-up;
- telemetry;
- a draft MR description.

It exits `0` only when the delivery is `ready`.

| Status | Meaning |
|---|---|
| `blocked` | A required check failed, a red test passes before its code exists, or review found a blocking finding. |
| `unverified` | Required evidence is missing, malformed, stale or unavailable, or verification was interrupted. |
| `incomplete` | Evidence is sound, but steps or checklist items are unticked, or review requested changes. |
| `ready` | Every criterion has current passing evidence (or an allowed attestation), and final verification and review requirements are met. This means ready for handoff, not merged. |

The worst reason sets the status, and every reason is listed with its evidence reference. A criterion is mapped only to the steps its plan sidecar names, never by similar wording.

**Completion policy.** Add an optional `completion` block to `config.json` (defaults shown):

```json
"completion": { "require_review": true, "require_review_quick": false, "blocking_severities": ["blocker"], "allow_attestation": false }
```

**Attestation for a criterion that cannot run automatically.** Record why the check did not run, then attest the criterion:

```
node ai-factory/make/contracts.js record --delivery <id> --step S2 --not-run --reason "needs a printer"
node ai-factory/make/contracts.js attest --delivery <id> --criterion AC2 --actor "QA lead" --rationale "Checked the printed output by hand" --source "DEMO-12 comment 3"
```

- The report always shows the attestation.
- It counts toward completion only when `allow_attestation` is true and no automated check for that criterion failed.
- Editing the spec makes it stale.

**Telemetry.** The report reads an optional `ai-factory/runs/telemetry/<id>.json` (schema `schema/telemetry.v1.json`). Nothing produces that file yet, so the section says `unavailable`. A missing or unknown value is never shown as zero, and telemetry never changes the status.

A report is a snapshot. It records its generation time, the code snapshot and a fingerprint of the evidence it read. Regenerate it after anything changes; two runs over identical evidence differ only in `generated_at`.

### 8. Lifecycle telemetry (opt-in)

Lifecycle telemetry records how long a delivery took, how long it waited, how often a step was retried, how each run ended, and which token usage belongs to it. It sits beside the existing run log: `log.csv` and `make cost` do not change.

**Turn it on** in `config.json` (retention defaults to 90 days):

```json
"lifecycle": { "enabled": true, "retention_days": 90 }
```

**Recording is explicit.**
- **Headless runs.** `make ai` and `make review` record themselves, taking `DELIVERY=` and `STEP=` from the environment.
- **Interactive tasks.** Each task procedure brackets its own work:

  ```
  node ai-factory/make/lifecycle.js start --phase run --delivery <id> --step S1   # prints: lifecycle: started run r-… attempt a-…
  node ai-factory/make/lifecycle.js wait-start --run <run>                        # waiting on the developer
  node ai-factory/make/lifecycle.js wait-end --run <run> --wait <wait>
  node ai-factory/make/lifecycle.js end --run <run> --outcome succeeded|failed|interrupted
  ```

- **Recording never blocks the work.** When lifecycle is disabled, or an event cannot be written, these commands print one line on stderr and exit 0.

**Reading it.**

```
make lifecycle [DELIVERY=<id>] [JSON=1]      # human summary, or the t4-lifecycle-report v1 document
make lifecycle-export DELIVERY=<id>          # writes ai-factory/runs/telemetry/<id>.json (telemetry.v1)
node ai-factory/make/lifecycle.js prune [--days N] [--write]   # dry run unless --write
```

`make delivery-report` reads the same numbers directly from the events when lifecycle is enabled.

| Metric | Meaning |
|---|---|
| Elapsed | The union of the delivery's run intervals. Parallel runs are never added together. It is unknown while any run is open, and the measured part is shown separately. |
| Waiting | The union of recorded `wait-start`/`wait-end` intervals, clipped to the run windows. It is unknown while a wait is open; idle gaps are never counted as waits. |
| Active | Recorded attempt intervals minus waits. It is unknown when any attempt is incomplete. |
| Agent effort | The sum of each subagent's transcript window. It is labelled, and may exceed elapsed. |
| Retries | Another attempt of the same phase and step after a failure. An attempt after an interruption counts as *resumed*; one after a success counts as a *rerun*. |
| Tokens | The existing normalized usage. Each unique source record counts once, even when it appears in several transcripts. |
| Cost | A known subtotal plus the number of unpriced records. The total is unknown whenever any record has no price. Zero-priced records are counted separately. Each figure carries its provenance: `host-reported`, `estimated:models.yaml` or `estimated:built-in-rates`. |

**Attribution** happens only by explicit identity, never by branch name or the most recent ticket:
- **Headless children** inherit `T4_LIFECYCLE_RUN`.
- **Interactive sessions** are bound to a run when the command hook sees `lifecycle.js start`.

Usage whose transcript timestamps overlap exactly one bound run belongs to that run. Ambiguous or unbound usage is reported as unattributed, with the reason.

**Unknown stays unknown.**
- Events are immutable files, one per event, under the gitignored `ai-factory/runs/lifecycle/events/`.
- A crashed run stays open until `end` is recorded.
- A clock that runs backwards is flagged `invalid_clock`.
- A torn event file is reported as corrupt, and an event from another schema version as unsupported.

**Privacy and retention.**
- Events hold IDs, timings, outcomes and token counts, never prompts, file contents or command output.
- `prune` removes events older than the retention period, except for deliveries with a saved completion report. It records what it removed, so later summaries say `detail_pruned` instead of reading low.

**Coverage gaps.**
- No host signal reports waiting, so waits exist only where recorded.
- Codex's hook payload has not been confirmed to include command output. Until it is, interactive Codex sessions cannot be bound, and their usage stays unattributed.

### 9. CI

```
make -f ai-factory/make/ai.mk contracts JSON=1 > contracts.json   # nonzero on anything not valid
make -f ai-factory/make/ai.mk contracts DELIVERY="$DELIVERY" REQUIRE=final,review
make -f ai-factory/make/ai.mk delivery-report DELIVERY="$DELIVERY"   # exit 0 only when ready; keep completion.md as an artifact
```

Run the validator against the branch's working tree. It reads only sidecars, the Markdown beside them, evidence records and in-scope code, and it writes nothing.

## Adoption

- Contracts are opt-in. Run `node ai-factory/make/contracts.js enable`, or accept the offer in `/t4:sync-sdlc`. Either one creates `ai-factory/contracts/config.json` and records `capabilities.contracts.version` in `ai-factory/.sdlc.json`.
- Until `config.json` exists, every task behaves exactly as before.
- You can run `validate` explicitly at any time. In an unadopted project it reports artifacts without sidecars as `legacy_unverified`.
- `contracts.js migrate` shows the sidecars it would draft for existing specs and plans. `migrate --write` creates them. Migration:
  - never edits Markdown;
  - only extracts IDs that are already in the Markdown, and never invents any;
  - never creates evidence.

  A drafted sidecar stays `legacy_unverified` until someone reviews it and reruns `init` on its Markdown. Running migration twice changes nothing.
- To roll back, delete `config.json`. Sidecars and evidence stay in place and are not reinterpreted as verified.

## Delivery identity

- Each delivery has one `delivery_id` of the form `d-YYYYMMDD-xxxxxx`. `init` creates it the first time and keeps it every time after.
- The ID does not depend on file names or on a tracker key. `tracker_key` is optional and is taken from the spec's `Ticket:` line.
- Because the chain is keyed by the ID, a renamed artifact or a plan moved to `plans/done/` keeps its links. When you rename, move the Markdown and its sidecar together.

## Files

| File | Written by | Holds |
|---|---|---|
| `ai-factory/specs/<name>.contract.json` | `contracts.js init spec <md>` | delivery ID, spec digest, criteria `AC1…` |
| `ai-factory/plans/[done/]<name>.contract.json` | `contracts.js init plan <md> --spec <spec md>` | spec digest the plan was written against, steps `S1…` with criteria and verification argv |
| `ai-factory/quick/<name>.md` + `.contract.json` | the quick task, then `contracts.js init quick <md>` | checklist `QC1…` and verification argv |
| `ai-factory/evidence/<delivery_id>/S<N>-red.json`, `S<N>-step.json`, `final.json`, `quick.json`, `review.json` | `make verify` and `make review` only | what actually ran, its outcome, and the input and code digests it ran against |
| `ai-factory/evidence/<delivery_id>/AC<n>-attest.json` or `QC<n>-attest.json` | `contracts.js attest` only | a human attestation: actor, time, rationale, source, and the content it was made against |
| `ai-factory/reports/<delivery_id>/completion.{md,json}` | `make delivery-report` only | the completion report snapshot |
| `ai-factory/runs/evidence/<delivery_id>/*.log` (gitignored) | `make verify` | command output, referenced from the evidence by path and hash |

The JSON Schema documents in `schema/` are informative. The validator implements the same rules directly and has no schema dependency.

## Markdown conventions the validator reads

- **Criteria.** A spec criterion is a line whose first token is its ID, either as a table row or as a list item: `| AC1 | Given … |` or `- AC1 Given …`.
- **Checklist items.** A quick checklist item is written `- [ ] QC1 — …`.
- **Plan steps.** A plan step is `- [ ] **Step N — title.**` at the start of a line. This is the same grammar `/t4:state` uses. `**Result — Step N withdrawn; …**` withdraws a step.
- **Step criteria.** The `ACn` references in a step's text are the criteria that step covers.
- **Verification commands.** Write each one as ``Verify (red|step|final): `command` ``. The phase defaults to `step`.
  - Commands run as argv, without a shell. A command that needs quotes, pipes or globbing is not drafted. Wrap it in a script or a make target instead.
  - At least one step must declare a `final` command.
- **Fenced code** is ignored.

## States

| State | Meaning |
|---|---|
| `valid` | Everything checked is consistent and current. |
| `invalid` (`E_…`) | Malformed or inconsistent: a duplicate or missing ID, an unknown reference, a missing verification command, an unsupported schema version, a path escape or symlink, or required evidence that failed, was not run, or was unavailable. |
| `stale` (`S_…`) | An input changed after something was derived from it: a spec after its plan, a plan after its evidence, in-scope code after final, quick or review evidence. |
| `legacy_unverified` (`L_…`) | There is no sidecar, or a migrated draft has not been reviewed. |

A missing or unsupported sidecar is never `valid`. `I_…` diagnostics are informational only.

## Freshness

Freshness is decided by content, never by timestamps.

- **Markdown digests.** Each Markdown file is identified by its SHA-256. For plans and checklists, checkbox marks are normalized to `[ ]` before hashing, so ticking progress does not make anything stale.
- **Code snapshot.** Code is identified by a snapshot: the SHA-256 over the path and content hash of every tracked, modified and untracked-but-not-ignored file that `code_scope` selects.
  - `ai-factory/` is never part of the snapshot, so writing evidence, reports or telemetry cannot invalidate evidence.
  - Symlinks are hashed by the text of their target and never followed.
- **Step evidence** must match the current spec and plan. A later step changing the code is expected and reported as `I_CODE_ADVANCED`.
- **Final, quick and review evidence** must also match the current code snapshot.
- **Ticked steps.** A ticked step with no passing step evidence is `E_EVIDENCE_NOT_RUN`. Once every step is ticked, final verification is required. A checked box is never proof that anything ran.

## Evidence outcomes

- `passed`: every declared command exited 0.
- `failed`: a command exited nonzero or was interrupted. Any signal counts as failed.
- `unavailable`: a command could not be started. It is never counted as a pass.
- `not_run`: recorded with `--not-run --reason …`, or reported when required evidence is missing.
- **Red runs** expect failure. They record `expected: "fail"` and are never accepted as final verification. A red run that passes is `E_RED_PASSED`.

## Commands

```
node ai-factory/make/contracts.js validate [<delivery_id> | <artifact path> | --all] [--require final,review] [--json]
node ai-factory/make/contracts.js init spec|plan|quick <markdown> [--spec <spec md>] [--tracker KEY]
node ai-factory/make/contracts.js record --delivery <id> [--step S<N>] [--phase red|step|final] [--not-run --reason …]
node ai-factory/make/contracts.js snapshot [--json]
node ai-factory/make/contracts.js enable
node ai-factory/make/contracts.js migrate [--write] [--json]
make -f ai-factory/make/ai.mk contracts [DELIVERY=…] [REQUIRE=final] [JSON=1]
make -f ai-factory/make/ai.mk verify DELIVERY=… [STEP=S<N>] [PHASE=red|step|final]
```

- **Exit codes.**
  - `0`: valid, or the recording matched its expectation.
  - `1`: invalid, stale, legacy_unverified, or a recording that did not meet its expectation.
  - `2`: an invocation error.
  - `130`: the recording was interrupted.
- **JSON output.** With `--json` or `JSON=1`, stdout carries exactly one JSON document.
- **Read-only commands.** `validate` and `snapshot` never write anything. They read only sidecars, the Markdown beside them, evidence records and in-scope code. A file mentioned in an artifact's prose is never opened.
