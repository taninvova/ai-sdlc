# 0003 — /t4:setup-tracker

**Goal:** one interactive command that turns the tracker on for a repo and proves it, rather
than leaving a developer to guess a filename and a key.

**Spec:** `specs/0003-tracker-setup.md`

**Unblocked 2026-09-07.** `specs/0001` shipped in 0.19.0, and both of spec 0003's open
questions are answered: `base_url` only (AC11), and setup asks whether to commit or ignore
(AC12) while stating what ignoring costs (AC13).

## Files to create / modify
| File | Why |
|---|---|
| `commands/setup-tracker.md` | **new** — plugin command, not a task: AC7 requires it to run in a repo whose layout predates tracker support, where project tasks do not exist. |
| `README.md`, `docs/workflow.md` | command table, and the "how do I turn this on" path a developer currently cannot find. |
| `CHANGELOG.md` + 3 manifests | new command; version bump. |

No script. Every step is a question, a confirmation or a tracker read — none of it
deterministic enough to fixture, which is the opposite of `specs/0002` and the reason that one
went first.

## Server vs client components
Not applicable. The split that matters is **prompt versus seam**: the command asks and
confirms, `ai/docs/tracker.md` holds every fact about what to detect and what counts as
configured. AC10 makes that mechanical — `check-adapters.sh` already fails on a vendor name in
a prompt.

## Steps

- [x] **Step 1 — Refuse early and clearly.** No `ai/docs/tracker.md` → stop, name
  `/t4:sync-sdlc` and the drift it reports (AC7). Non-interactive → stop, say the command is
  interactive (AC8). Both before anything is read or written.
  *Proves:* AC7, AC8. *Check:* two scratch repos, one without the seam, one run headless.

- [~] **Step 2 — Detect, show, confirm.** Detect the reachable site, show it, ask before
  writing (AC1). Unreachable → report why and what to do, write nothing (AC4).
  *Proves:* AC1, AC4. *Check:* real run; and with the connector unavailable, which is the state
  `specs/0001` AC4 was proved in.

  **Result — AC1 proved, AC4 not yet.** Detection returned exactly one reachable site, it was
  shown with its scopes, and the write was declined. The command's only obligation at that
  point — write nothing without a yes — was therefore exercised against a real refusal rather
  than assumed, and nothing was written in the fixture or anywhere else.

  **AC4 is outstanding.** It needs a session where nothing is reachable. `specs/0001` AC4 proved
  that state for `/t4:spec`, which is a different command, and manufacturing it costs the
  developer a re-authorisation for a case that will arise on its own. It waits for a session
  already in that state.

- [x] **Step 3 — Write, without ever silently overwriting.** Write `base_url` and nothing else
  (AC2, AC11). If the file exists, show it and require a second confirmation (AC3). The file is
  hand-owned, so the bar for touching it is higher than for anything generated. Then ask commit
  or `.gitignore` (AC12), and if ignored, say plainly that the repo is now configured for this
  developer alone (AC13).
  *Proves:* AC2, AC3, AC11, AC12, AC13. *Check:* run twice; the second must not proceed on one
  confirmation. Choose ignore once and confirm both the `.gitignore` line and the warning.

- [x] **Step 4 — Prove it, or say it is unproven.** Ask for one key, resolve it, report the
  summary (AC5). No key offered → say the setup is unverified and name what verifies it (AC6).
  *Proves:* AC5, AC6. *Check:* a real key, then a run where none is given.

  **Result.** AC5 proved live: the `base_url` written in step 3 was used to resolve a real key
  through the seam's first arm, and the ticket came back with a summary and a status — so the
  configuration was exercised, not merely written. AC6 exercised as the no-key branch: with
  nothing offered to verify against, the report says the configuration is unverified and names
  what would verify it, rather than treating a written file as success. The key is not recorded
  in this repo, by request; it was a test ticket.

- [x] **Step 5 — Confirm the tracker was not written to.** No comment, no transition, no field
  (AC9). Check the ticket's status and comment count before and after.
  *Proves:* AC9. *Check:* compare both, on the same ticket step 4 used.

  **Result.** Five fields compared against the step-4 baseline: comments 0, status unchanged,
  resolution null, labels empty, and `updated` identical to the millisecond. That last one
  carries the weight — Jira advances it on any field write, so an unchanged timestamp rules out
  a write that happened to leave the visible fields looking the same. "I did not call a write
  tool" is the weaker argument, and it is the one AC9 exists to replace.
  `getTransitionsForJiraIssue` was called earlier while offering to close the ticket; it reads,
  and none of the transitions it listed was applied — named here because a reader scanning for
  tracker calls will see it.

- [x] **Step 6 — CHANGELOG, version bump, README, workflow.**
  *Check:* `check-versions.sh`, definition of done items 3 and 7.

## Risks
| Risk | How it is checked |
|---|---|
| It overwrites a hand-written `ai/jira.yaml` — destroying work the guard deliberately does not protect. | AC3, step 3, by running twice. The highest-consequence failure here. |
| It writes a file that does not satisfy the seam's own definition, so setup "succeeds" and `/t4:spec` still ignores it. | AC2 uses the seam's condition, not a second copy of it; step 4 proves end to end. |
| It reports success without proving anything. | AC5 and AC6 make verification explicit, including its absence. |
| It writes to the tracker while reading. | AC9 compares status and comments before and after. |
| A vendor name reaches the prompt. | AC10; `check-adapters.sh` already asserts it. |

## Verification
```
bash skills/ai-layout/scripts/check-adapters.sh     # AC10
bash skills/ai-layout/scripts/check-versions.sh
bash ai/make/sync-adapters.sh && bash ai/make/sync-adapters.sh
```
Plus steps 2–5 run for real against a live tracker, and `/t4:check`.

## Planning notes
- **Almost nothing here is fixturable**, and that is the honest difference from plan 0002. Its
  value is in questions asked in the right order and a refusal to overwrite; both are proved by
  running it, not by a check script. Expect the MR to lean on transcripts.
- **Step 5 exists because ADR 0006 is only paper until something checks it.** The setup command
  is the first code that touches a tracker with write scope available to it.
- **Ordering was the point.** The doctor tells a developer the tracker is not configured; this
  command configures it. Building them the other way round gives you a wizard for a problem
  nobody has diagnosed yet.
