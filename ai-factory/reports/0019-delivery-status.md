# Compact delivery status — implementation evidence

Status: implemented; plan Steps 1–4 verified. Deterministic checks, before/after host transcripts
on Claude Code and Codex, and an independent review (approve, minor findings only) are recorded.
No release/version bump.

## Result

Claude `/t4:state --delivery <id>` and Codex `$t4-state --delivery <id>` show one artifact-contract
delivery, planned or quick, as a two-column `field`/`value` table. The repo must have contracts
enabled, and the ID uses the form `d-YYYYMMDD-xxxxxx`. `state.sh` parses the mode on its own path.
It passes the ID as one literal argument to the workspace's adopted `make/delivery-status.js`, which
collects and evaluates the delivery once in memory through `delivery-report.js`. It never generates
or saves a report, reads no saved report, runs no verification, review or continuation, writes
nothing and names no next action.

Rows: `delivery`, `kind`, evidence-derived `progress` (`planning`, `implementation`,
`verification-unproven`, `review-pending`, `ready`, `unknown`; never a claim that work is running),
the existing `readiness`, `steps`/`checks` as recorded progress only, criteria grouped as
`verified`, `attested`, `remaining` and `unknown`, `latest verification` (latest valid `finished_at`,
ties by ascending path, `unknown` when any timestamp or evidence file cannot be read), `review`,
`blockers`, `limitations` and `source` paths. The default listing, `--done` and `--next` are
unchanged. `--delivery` combines with neither and refuses missing, repeated, malformed, unknown or
duplicated IDs in one line. A missing helper is answered with `/t4:sync-sdlc` guidance.

## Documentation

- `README.md`: the `/t4:state` command entry names `--delivery`, and a new *Delivery status*
  section covers the contracts requirement, the ID form, rows, progress labels, chronology,
  refusals, sync guidance and the read-only guarantee.
- `ai-factory/docs/workflow.md`: a new *Delivery status* subsection in section 4, with tables for
  the fields and progress labels, plus the chronology rules, refusals, the missing/outdated helper
  case and three worked examples. The *Back after time away?* rule and the section 5 command table
  point to it.
- `CHANGELOG.md`: *Unreleased — delivery 0019 (no version bump)*, with template upgrade impact.
- `skills/ai-layout/SKILL.md`: the `ai-factory/make/` inventory now lists `delivery-status.js`
  and `continue.js` (a gap flagged in Step 3).
- Neither `ai-factory/AGENTS.md` nor the template `AGENTS.md` describes `/t4:state`. Both are left
  unchanged, and no command count changed (no new command).

The worked examples (missing evidence, stale review, attested criterion) are real output. Each
came from running `state.sh <repo> <plugin> --delivery <id>` against a disposable fixture built
from `skills/ai-layout/fixtures/contracts/planned` with `check-delivery-status.sh`'s fixture
builders. Every run was wrapped in that script's observer: the fixture tree was compared before
and after, and sentinel stand-ins for the verification commands, `make`, `claude` and `codex`
recorded nothing. Only the fixture delivery IDs were replaced, with `d-20261006-1a2b3c`. Refusal
lines for a missing ID, `--delivery … --done`, a path-like ID (`../x`) and a removed helper were
captured the same way and match the documented wording.

## Investigation: `ready` beside `contracts: invalid`

The attested worked example shows `readiness ready — … (contracts: invalid)`. I checked whether
this is a fixture mistake, a false green in the helper, or intended behaviour. **It is intended
behaviour. Neither the fixture nor the helper is at fault, and no code changed.**

- **The fixture is valid.** It is the canonical attestation scenario: S1 recorded, S2 recorded
  with `record --not-run --reason "needs a printer"` (which exits 1), S3 and final recorded, review
  approved, AC2 attested, `allow_attestation: true`. These are the same steps as the attestation
  case in `check-delivery-report.sh`, which asserts `ready` (spec 0014), and as
  `helper-attestation` in `check-delivery-status.sh`. I rebuilt it independently in a scratch repo
  and ran all three readers on the same files:
  - `contracts.js validate <id>`: `invalid`, exit 1. The only invalid artifact is `S2-step.json`
    (`E_EVIDENCE_NOT_RUN: verification was not run: needs a printer`). Spec, plan, S1, S3, final,
    review and attestation are all `valid`.
  - `delivery-report.js <id> --json`: `status ready`, `contract_status invalid`, with the single
    reason `ready:ATTESTED`.
  - `state.sh <repo> <plugin> --delivery <id>`: the attested example's rows exactly, with only the
    ID and `finished_at` different.
- **Why the values differ.** `contract.status` is the worst artifact state from
  `contracts.validate`. That check is structural and ignores completion policy, so `not_run`
  evidence always makes it `invalid`. `evaluate` in `delivery-report.js` is the readiness rule
  defined by spec 0014. It turns `E_EVIDENCE_NOT_RUN`/`E_EVIDENCE_UNAVAILABLE` on a step into the
  `ready` reason `ATTESTED`, but only when policy allows attestation and valid attestations cover
  every criterion of that step. Spec 0014 says attestation "counts only when the policy allows
  it, and never over a failed check", and both checks enforce that.
- **Not a false green under spec 0019.** The spec says to "use existing readiness reasons and
  severity rules" and "reuse existing contract policy". The helper prints the evaluator's status
  and the validator's status unchanged, adds no rule, and keeps AC2 under `attested`, separate from
  `verified`, as AC2 and AC3 of spec 0019 require. With policy off, the same files give `unverified`,
  covered by `helper-attestation`. The missing-evidence example shows `contracts: invalid` for the
  usual reason: required evidence that is `not_run`.
- **Decision.** The behaviour stays as it is, and the docs now explain it.
  `ai-factory/docs/workflow.md` has a note after the attested example and a more precise
  `readiness` field description. `README.md` has a one-sentence note.
- **Possible follow-up (not done; owner's call):** the helper's label `(contracts: invalid)`
  could read `(contract validation: invalid, before completion policy)`. That would change the
  helper's output and examples in a documentation-only step, so it was left out.

## Verification evidence

- Steps 1–3 (committed): `check-delivery-status.sh` was red in the `cli` group before Step 3.
  `check-state.sh`, `check-delivery-report.sh`, `check-contracts.sh`, `check-adapters.sh` and
  `check-entrypoints.sh` passed at their steps.
- Step 4, each command run as written:
  - `node skills/ai-layout/scripts/sync-codex-skills.js --check`: 24 skills verified, exit 0.
  - `node skills/ai-layout/scripts/sync-claude-commands.js --check`: 15 task wrappers verified,
    exit 0.
  - `bash skills/ai-layout/scripts/check-release-docs.sh`: release docs ok, 13 scratch fixtures,
    exit 0.
  - `bash skills/ai-layout/scripts/check-delivery-status.sh`: 32 cases (helper 19, cli 13),
    exit 0.
  - `make check`: the full suite, including both new fixture groups, `check-paths.sh` and
    `check-delivery-report.sh`. See *Step 4 final verification* below.

## Live behavior

**Verified on both hosts, 2026-10-06.** Claude Code 2.1.291 and Codex CLI 0.160.0 ran headlessly
in a disposable contracts-enabled Git repo. The repo was built from
`skills/ai-layout/fixtures/contracts/planned`: spec and plan initialised, S1 recorded and ticked,
no final verification and no review, delivery `d-20261006-3fa111`. *Before* is the cached plugin
2.8.0. *After* is this working tree.

- Claude: `claude -p "/t4:state <args>" --plugin-dir <plugin> --allowedTools Bash Read`.
- Codex: `codex exec "$t4-state <args>"` with an isolated `CODEX_HOME`, where t4 was installed
  through `codex plugin marketplace add <plugin>` and `codex plugin add t4@sdlc`. The user's own
  Codex configuration was untouched.

Before and after every run, the scratch repo's `git status --porcelain` and a SHA-256 tree
snapshot were taken. The snapshot covered everything outside `.git/` and `ai-factory/runs/`.

| Host | Invocation | Before (2.8.0) | After (this tree) |
|---|---|---|---|
| Claude | `--delivery <id>` | one-line refusal: `'--delivery d-20261006-3fa111' is not a flag /t4:state takes …` | ran `state.sh . <plugin> --delivery d-20261006-3fa111`; showed the 17-line field/value table as a two-column table, rows in order, `source` repeated, no extra lines |
| Claude | `--delivery <id> --done` | — | one-line `--delivery does not combine with --done …` passed through |
| Claude | `--delivery ../x` | — | one-line `delivery-status: expected one contract delivery ID of the form d-YYYYMMDD-xxxxxx` passed through |
| Claude | none / `--done` / `--next` | 3 outstanding rows / `nothing finished yet …` / `Step 2` | identical rows and selection |
| Codex | `--delivery <id>` | same one-line refusal | ran the same command with the ID verbatim; the same table, rows in order, no extra lines |
| Codex | `--delivery <id> --done` | — | one-line refusal passed through |
| Codex | none / `--done` / `--next` (`workspace-write`) | 3 outstanding rows / `nothing finished yet …` / `Step 2` | identical rows and selection |

Every run left the tree outside `ai-factory/runs/` unchanged, and `git status` showed no tracked
change. Under Claude Code, the plugin's own logging hooks created `ai-factory/runs/sessions.jsonl`,
`log.pending.csv` and per-session marker files. That is the hooks' documented behaviour, not
`state`. Under Codex nothing changed at all: plugin hooks are not trusted in a fresh
`CODEX_HOME`.

Observations:

- **Codex looked around before running the script.** On `--delivery` runs it listed files with
  `rg --files` and read `ai-factory/make/delivery-status.js`. On 2.8.0 listing runs it also read
  the spec and plan. Step 2 of the procedure forbids reopening the spec, plan, sidecars, evidence
  or reports to check the rows, and Codex reread none of them on any 0019 `--delivery` run. The
  table it presented was the script's output unchanged. Claude ran only the script.
- **Pre-existing listing bug under Codex `read-only`, not introduced by 0019.** With
  `codex exec -s read-only`, the listing modes fail in both 2.8.0 (`state.sh` lines 313/359) and
  this tree (lines 395/441). The error is `cannot create temp file for here document: Operation
  not permitted`, and the script then prints a false `nothing outstanding` with exit 0. Codex
  flagged that result as unreliable each time. The `--delivery` path does not hit it and passed
  under `read-only`. The listing rows above come from `workspace-write` runs. Possible follow-up
  (owner's call): make `state.sh` avoid here-docs, or fail loudly when one fails.

Raw transcripts (stream-JSON for Claude, `codex exec` output for Codex) were kept in session
scratch space and not committed, because they contain local absolute paths.

Review: **independent `t4:reviewer` pass on 85e4ace..HEAD plus this working tree. Verdict:
approve, with three minor findings:**

1. `progress` reads `review-pending` for any unmet review, including requested changes and
   blocking findings (`delivery-status.js` line 126). That is broader than the plan's "missing
   required review". It is not a false green, because `readiness` and `blockers` still show
   `blocked`. Addressed in documentation: the `review-pending` row in `workflow.md` now says
   exactly what it covers. Possible follow-up (owner's call): a distinct label for a blocking
   review, plus a `progress` assertion in `helper-approval-with-blockers`.
2. Step 4 needed host transcripts. Recorded above.
3. The spec status line still reads "draft for planning". Left for the spec owner.

## Step 4 final verification

`make check` exited 0. It ran all 42 check scripts (22 under `skills/ai-layout/scripts/`, 20
under `skills/ai-hooks/fixtures/`), in order and fail-fast, including:
`check-delivery-status.sh` (32 cases), `check-state.sh` (18 sections), `check-delivery-report.sh`
(20 cases), and `check-paths.sh` (235 files scanned, this report among them). Plugin hosts
reported 24 Codex skills, and the suite ended with the 62-case write-boundary check.

Host transcripts and the independent review are now recorded (see *Live behavior*). After the
`workflow.md` wording change, both `--check` syncs (24 Codex skills, 15 Claude wrappers) and
`make check` were re-run on 2026-10-06 and exited 0.

## Plan and spec notes

- The spec's status line still reads "draft for planning". Specs are outside the implementer's
  write scope, so it is left for the owner.
- The plan's Step 4 does not list `skills/ai-layout/SKILL.md`. The inventory gap flagged in
  Step 3 was fixed there.

## Upgrade impact

Adopted workspaces need the new `make/delivery-status.js`, received through `/t4:sync-sdlc` or
adoption. Until then `--delivery` answers with sync guidance and writes nothing, and the listing
modes are unaffected. Repos without contracts see no change. No dependency is added.
