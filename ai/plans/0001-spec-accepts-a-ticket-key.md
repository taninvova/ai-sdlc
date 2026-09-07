# 0001 — /t4:spec accepts a ticket key

**Goal:** teach `/t4:spec` to draft from a tracker ticket in a configured repo, while a repo
with no `ai/jira.yaml` cannot tell the feature shipped.

**Spec:** `specs/0001-spec-accepts-a-ticket-key.md` · **ADRs:** `docs/adr/0004`, `0005`, `0006`
· **Design:** `ai/designs/0002-jira-integration.md`

## Files to create / modify
| File | Why |
|---|---|
| `skills/ai-layout/templates/ai/docs/tracker.md` | **new** — the seam. The only file naming the vendor, the connector or `ai/jira.yaml`. ADR 0004 rule 3. |
| `skills/ai-layout/templates/ai/tasks/spec.md` | the gate, the whole-argument rule, stop-and-ask, and the `Ticket:` line. `ai/tasks/spec.md` is a symlink, so one edit. |
| ~~`skills/ai-layout/templates/ai/docs/dont-touch.md`~~ | **not changed** — step 2 decided `ai/jira.yaml` stays unguarded; the reasoning goes in the CHANGELOG at step 7. |
| `skills/ai-layout/scripts/check-adapters.sh` | AC7 and AC12 are static properties of generated output — assert them where the other prompt invariants already live. |
| `skills/ai-layout/templates/ai/make/sync-adapters.sh` | only if the Codex skill needs the stop-and-ask arm spelled out (step 5). |
| `CHANGELOG.md` + 3 manifests | definition of done item 3: template change, blast radius named, version bumped everywhere. |

## Server vs client components
Not applicable — this repo ships prompts and templates, no application. The equivalent split is
**what the prompt says** versus **what the seam document says**, and ADR 0004 rule 3 fixes it:
the prompt names `ai/docs/tracker.md` and nothing else; every vendor fact lives in the seam.
Step 1 builds the seam first so that step 2 has something to point at and no reason to inline.

## Steps

- [x] **Step 1 — Write the seam, `ai/docs/tracker.md`.** Resolution order (connector if the
  session has it; `ai/make/jira.sh` if the repo has it; otherwise stop and ask), what counts as
  configured, and the fields read. It is the only file naming the vendor or `ai/jira.yaml`.
  *Proves:* AC13's definition of configured. *Check:* `grep -L` for vendor strings in every
  other file touched.

- [x] **Step 2 — Decided: `ai/jira.yaml` is not dont-touch.** Everything on that list is
  generated (`.claude/`, `.cursor/`, `.codex/`, `ai/runs/`, `ai/.sdlc.json`) or secret
  (`.env`). This is neither — it is hand-written config a developer is meant to author, and
  `guard-paths.js` blocks Edit/Write with exit 2, so listing it would stop a session creating
  the very file that turns the feature on. It holds no credential either: ADR 0004 keeps those
  in the environment. Same category as `ai/docs/architecture.md`, which is also unguarded.
  **Output folded into step 7** — the CHANGELOG line records it; `dont-touch.md` is unchanged,
  so this step edits nothing.
  *Noted while reading the guard:* its last match clause is a basename **prefix** test, so
  `.env` also blocks `.envrc`. Not a problem here, but the list matches more loosely than it
  reads, and anyone adding a rule should know.

- [x] **Step 3 — Teach `ai/tasks/spec.md` the gate and the rules.** Configuration opens the
  path (AC1, AC13); whole-argument match inside a configured repo (AC2, AC3); stop and ask on
  unresolvable or unknown (AC4, AC5); empty argument unchanged (AC6); `Ticket:` line, one line,
  key alone, under the title (AC2, AC8); two matches is an error (AC9); criteria from the
  description only (AC10) and implicit gaps become Open questions, never invented ACs (AC11).
  Keep the task under two pages — it is already near the limit, so prefer deleting a sentence
  to adding one. *Proves:* AC1–AC6, AC8–AC11. *Check:* real runs, per step 6.

- [x] **Step 4 — Assert the prompt invariants in `check-adapters.sh`.** AC7: the generated
  `/t4:spec` command names `ai/docs/tracker.md` and contains no vendor name, connector name,
  URL, field name or JSON shape. Verify it fails when a vendor string is reintroduced, not just
  that it passes. *Proves:* AC7. *Check:* `bash skills/ai-layout/scripts/check-adapters.sh`,
  plus the deliberate-break run.

- [ ] **Step 5 — Make Codex behave the same, or say why not.** AC4 is Codex's *normal* path,
  not an edge case, since arm two does not exist. Confirm the generated skill inherits
  stop-and-ask by pointing at the task file; if it does not, add it in `sync-adapters.sh`.
  *Proves:* AC4 under Codex. *Check:* read a generated `.codex/skills/t4-spec/SKILL.md`.

- [ ] **Step 6 — Run the ACs for real and record the transcripts.** The repo has no test
  runner; behaviour is proved by runs (coding-standards, Tests). Minimum set: AC1
  (`/t4:spec UTF-8` with no config — the regression that shaped the design), AC12 (seam present,
  no config, nothing changes), AC3 (partial match), AC4 (configured, unreachable), AC2 (happy
  path, needs one real ticket). *Proves:* AC1–AC6, AC12. *Check:* transcripts linked in the MR,
  definition of done item 2.

- [ ] **Step 7 — CHANGELOG, version bump, README.** Name the blast radius: every adopted repo
  receives `ai/docs/tracker.md` on its next sync and gains nothing until it writes
  `ai/jira.yaml`. Carry step 2's decision: `ai/jira.yaml` is deliberately not in
  `dont-touch.md`, because a developer must be able to write it. Bump all three manifests.
  Check the README command table still matches.
  *Proves:* nothing. *Check:* `check-versions.sh`, definition of done items 3 and 7.

## Risks
| Risk | How it is checked |
|---|---|
| The feature leaks into repos with no tracker — the failure that matters most (spec summary). | AC1 and AC12 run for real in step 6, not reasoned about. |
| A vendor name reaches a task prompt, breaching ADR 0004 rule 3 — already happened once, in the seam's own filename. | Step 4 asserts it mechanically and is verified by deliberate break. |
| `spec.md` grows past two pages and drifts from the house style. | Step 3 says delete before adding; `wc -l` before and after. |
| Codex silently differs, so the same command behaves differently per tool. | Step 5 inspects generated output rather than assuming inheritance. |
| AC2 cannot be proved without a real ticket and a reachable connector. | Acknowledged: step 6 lists it last and it is the one AC that can block. |
| The seam is a new template file, so every adopted repo shows drift. | Step 7 names it in the CHANGELOG; AC12 proves the drift is inert. |

## Verification
```
node --check skills/ai-hooks/scripts/*.js
bash -n  skills/ai-layout/templates/ai/make/sync-adapters.sh
bash ai/make/sync-adapters.sh && bash ai/make/sync-adapters.sh   # twice, no diff
bash skills/ai-layout/scripts/check-adapters.sh
bash skills/ai-layout/scripts/check-versions.sh
bash skills/ai-layout/scripts/check-manifest.sh
bash skills/ai-hooks/fixtures/check-log-schema.sh
```
Plus the step 6 transcripts, and `/t4:check` with no blocker findings open.

## Planning notes
- **AC2 is the only criterion this repo cannot prove on its own.** It needs a configured
  `ai/jira.yaml`, an authenticated connector and a real ticket. Everything else is provable
  here. If that is not available, step 6 stops at AC2 and the plan is not done — better than
  ticking it on a mock that proves the mock.
- **Steps 1 and 3 are ordered deliberately.** Writing the prompt first would invite inlining
  vendor facts and then extracting them, which is how the filename leak happened.
- **Nothing in the spec was ambiguous.** All thirteen ACs are testable as written, and the
  three open questions were closed before planning. The single soft spot is step 2, which the
  spec raises only as "consider" — it is a step here so the decision is recorded rather than
  skipped.
