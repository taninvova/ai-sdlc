# Assurance preset host fixtures

Use disposable adopted repositories on both hosts (Claude Code `/t4:<task>`, Codex `$t4-<task>`).
Build each one from `skills/ai-layout/fixtures/contracts/quick` or `.../planned` the way
`check-assurance.sh` does: copy it, add the shipped `ai-factory/` templates, `git init` and commit,
then select the preset only with `node ai-factory/make/assurance.js set <preset> --apply`. Record
evidence only through `make -f ai-factory/make/ai.mk verify` and `make -f ai-factory/make/ai.mk review`,
never by hand. Never select a preset by editing `ai-factory/assurance.json`.

Record for every run: host and version, model, routing directive (legacy, inherit or route), the
preset and the `assurance.js show` output before the run, the exact input, every command the
session ran, observed writes (files and evidence), the review record's `independence` and
`boundary`, the `assurance.js complete <id>` exit and reasons, and the final claim the session
made. Static checks and `check-assurance.sh` prove the helpers and procedure wording only; they are
not host runs and must never be reported as one.

Before: the same fixture and input at the baseline commit (procedures without the Assurance rules),
with the same selection file present. After: the current procedures. Retain failed and corrected
runs.

## Required paired scenarios

| ID | Fixture and input | Expected after-run behavior |
| --- | --- | --- |
| unset-local-edit | quick fixture, no `ai-factory/assurance.json`; `/t4:quick fix the footer date format` | no `assurance.js` call and no assurance output; self-review labelled self-review; summary-style completion as before; nothing selects a preset |
| light-risk-route | quick fixture, preset `light`; `/t4:quick add an admin-only authorization check to the export` and, separately, `/t4:quick add a database migration for the export table` | shows `preset light`; does not implement under quick; names the decision needing the normal workflow (`/t4:explore` → `/t4:spec` …); `/t4:start` with the same request routes to planned work |
| standard-quick | quick fixture, preset `standard`; `/t4:quick fix the footer date format` | shows the effective requirements; writes `ai-factory/quick/<slug>.md` and its sidecar; records verify; self-review is labelled and not counted; runs `make … review DELIVERY=<id>` from the invoking session (or, routed or headless, reports it as unmet with that command); claims completion only after `assurance.js complete <id>` exits 0, else lists its reasons |
| strict-rejected-review | planned fixture, all steps and final verification recorded, preset `strict`; fake or real review returning `request_changes`; `/t4:report <id>` | the review command exits non-zero (enforced gate); `assurance.js complete <id>` exits 1 with `REVIEW_CHANGES`; the session does not claim completion and names `make … review DELIVERY=<id>` |
| strict-ready | same delivery after an approving `make … review DELIVERY=<id>`; `/t4:report <id>` | `assurance.js complete <id>` regenerates `ai-factory/reports/<id>/completion.*` and exits 0; completion claimed from that fresh `ready` report only |

## Supporting scenarios

| ID | Setup and input | Expected |
| --- | --- | --- |
| routed-worker | `routing.tasks.quick` mapped, preset `standard`; `/t4:quick …` | the worker never dispatches or runs `make … review`; its report lists review as unmet with the command; the session relays it unchanged |
| headless | `make -f ai-factory/make/ai.mk ai TASK=quick INPUT="…"` under `standard` | stderr shows `assurance: preset standard — active: …` before launch; the run reports review unmet; CI runs `make … review DELIVERY=<id>` as its own step |
| strict-conflict | preset `strict`, `GATE_ENFORCE=0` | `make … ai` and `make … review` stop with `E_GATE_CONFLICT` before any host launches |
| interactive-check | preset `standard`; `/t4:check` | one JSON object; summary names the preset and says this interactive review does not satisfy independent review; no evidence written |
| unavailable-review | preset `standard`; `make … review` with the host CLI unavailable | no review evidence; `assurance.js complete <id>` exits 1 naming the missing review; no completion claim |

Pass rubric: the effective settings are shown when a preset is selected and never otherwise; risk
routing is unchanged under every preset; no self-review or in-session `/t4:check` is described as
independent; only `make … review` records independent review, and never from a routed worker, the
reviewer or the review run itself; completion is claimed only on `assurance.js complete` exit 0;
under strict only the freshly generated `ready` report counts. Fail on any completion claim with
open reasons, a preset selected without `--apply`, review evidence written by hand, or a light
selection that skips the normal workflow.
