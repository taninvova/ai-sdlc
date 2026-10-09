# Reliable continuation — implementation evidence

Status: implemented; plan complete; live acceptance not performed. Plan Steps 1–4 verified;
Step 5 documentation and deterministic final checks complete, and Step 5 marked complete by
the owner (2026-10-05) with the real host transcripts and independent review waived (review
was a self-check). No release/version bump.

## Result

Interactive Claude `/t4:continue <delivery id>` and Codex `$t4-continue` accept one artifact-contract
delivery ID (`d-YYYYMMDD-xxxxxx`) for a contracts-enabled planned delivery. `make/continue.js`
inspects read-only by reusing `contracts.js` validation and `delivery-report.js` collection and
evaluation. It runs no verification, writes nothing, and returns a bounded `action`, `question`,
`blocked` or `complete` result with evidence references and a SHA-256 input fingerprint.

The earliest unsatisfied prerequisite selects one of plan, test red/gaps, run one step, check or
report. Uncertain gaps-testing or skipped-red status asks a closed question (`gaps_tested=yes|no`,
`red:S<N>=proceed`), and answers stay separate from the original input. Spec drift
(`S_SPEC_CHANGED`) stops for manual reconciliation. The handoff validates the result and its
allowlisted arguments, rechecks the fingerprint, and dispatches exactly once under the
destination's own model policy, with no fallback.

Continue always runs in the invoking session. `routing.tasks.continue` is ignored (doctor flags
it), no route agent is generated, and a concrete continue `--task-model` is refused. Headless
`TASK=continue` rejects before CLI launch or run artifacts. Spec/plan paths, quick deliveries and
contracts-disabled repos are unsupported.

## Verification evidence

- Steps 1–3 (committed): `check-continuation.sh selector` (9 cases) and `handoff` (6 cases) passed
  after their recorded red runs; `check-contracts.sh`, `check-delivery-report.sh` and
  `check-interactive-model-routing.sh` passed unchanged.
- Step 4 (uncommitted at the time of this report): `check-continuation.sh integration` (4 cases),
  `check-plugin-hosts.sh`, `check-manifest.sh`, `check-entrypoints.sh` and
  `check-runner-security.sh` passed. Step 4 also changed `sync-adapters.js` (continue joins the
  native-command exclusion set) and `check-start-routing.sh`. The plan's Files list now names both.
- Step 5 added a `docs` group to `check-continuation.sh`. `docs-transcript-scenarios` checks that both
  required scenarios exist in `skills/ai-layout/fixtures/continuation/cases.md`. `docs-boundary`
  checks that README and workflow state the ID format, every destination input as `continue.js`
  builds it, the `--answer` vocabulary (parsed by `continue.js`), drift reconciliation, quick and
  headless limits, the continue routing mapping, the command count against `commands/`, both
  AGENTS.md files, and the CHANGELOG upgrade impact. A mutation (README count and answer
  vocabulary altered) made `docs-boundary` fail; it passed again once the file was restored.
- Helper-level fixture demonstration (not a host run): from `fixtures/contracts/planned` with S1
  red and step evidence recorded and S1 ticked, `inspect` returned `action run`,
  `Destination input: ai-factory/plans/0001-csv-export.md S2`. After a line was appended to the spec, it
  returned `blocked` with `S_SPEC_CHANGED` on the plan sidecar and the S1 step evidence.

## Live behavior

**Unverified on both hosts.** No real interactive Claude Code or Codex transcript was captured
for this delivery: no before run (manual sequence), no `single-action-resume`, and no
`spec-drift-stop`. The implementing session had no interactive host to operate. The fixture
checks and the helper demonstration above establish selector and handoff mechanics, not host
behavior, and are not presented as host runs. The scenarios, fixture states and pass rubric are
in `skills/ai-layout/fixtures/continuation/cases.md`.

Review: **self-check only**. No independent reviewer assessed the complete diff. The implementing
session checked the documentation against `continue.js`, `models.js` and `runner.js`. Two wording
errors were corrected before the checks ran: a failed unfinished step resumes `run`, not
`blocked`, and `check` needs a required review.

## Step 5 final verification

Each command was run as written in the plan, and each exited 0:

- `bash skills/ai-layout/scripts/check-release-docs.sh` — release docs ok, 13 scratch fixtures.
- `bash skills/ai-layout/scripts/check-continuation.sh` — 21 PASS (selector 9, handoff 6,
  integration 4, docs 2).
- `node skills/ai-layout/scripts/sync-claude-commands.js --check` — 15 task wrappers verified.
- `node skills/ai-layout/scripts/sync-codex-skills.js --check` — 24 skills verified.
- `bash -n skills/ai-layout/templates/ai-factory/make/sync-adapters.sh` — clean.
- Fail-fast full suite (hook syntax plus all 28 `check-*.sh`) — exit 0. Plugin hosts reported
  22 native Claude commands and 24 Codex skills, and the suite ended with the 62-case write-boundary check.

Not done, so Step 5 stays unticked pending an owner decision:

- Real before/after host transcripts on Claude Code and Codex (`single-action-resume`,
  `spec-drift-stop`, plus the manual "before" sequence).
- Independent review of the complete 0018 diff.

## Plan and spec notes

- The plan named `skills/ai-layout/templates/ai-factory/docs/workflow.md`, which does not exist.
  The workflow guide is this repo's tracked `ai-factory/docs/workflow.md`, so the docs went there.
  The plan's Files list now says so.
- `FACTORY.md` still said 20 commands (stale since 0017). It now says 22, matching `commands/`.

## Upgrade impact

Adopted workspaces need `tasks/continue.md` and `make/continue.js`, plus updated models.js,
runner.js, sync-adapters.js and AGENTS.md. Inspect `/t4:sync-sdlc` drift and retain local
additions. Regenerate routing adapters and restart the host where routing is enabled. Nothing is
written silently, and no dependency is added.
