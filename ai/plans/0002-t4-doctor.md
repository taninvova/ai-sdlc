# 0002 — /t4:doctor

**Goal:** one read-only command that names what is wrong with this repo's setup and the exact
command that fixes each thing.

**Spec:** `specs/0002-t4-doctor.md` · **Depends on:** nothing. Independent of the tracker work,
except AC8, which reads `ai/docs/tracker.md` if it is there and reports "not configured" if not.

## Files to create / modify
| File | Why |
|---|---|
| `skills/ai-layout/scripts/doctor.sh` | **new** — the mechanical checks. Shell, so the prompt reports rather than reimplements, and so it is testable without a session. |
| `commands/doctor.md` | **new** — runs the script, reports its findings, adds the judgement a script cannot make. |
| `skills/ai-layout/scripts/check-doctor.sh` | **new** — fixtures: a repo with no layout, one with drift, one with no manifest, one healthy. |
| `README.md`, `docs/workflow.md` | command table, plus the not-loaded case that no command can report. |
| `CHANGELOG.md` + 3 manifests | new command; version bump. |

## Server vs client components
Not applicable. The equivalent split is **script versus prompt**, and it matters here: every
check with a deterministic answer belongs in `doctor.sh` where a fixture can pin it. The prompt
does only what a script cannot — deciding which findings matter most, and phrasing a remedy for
this repo. A check that lives in the prompt cannot be tested, and this command exists to be
trusted when something is already wrong.

## Steps

- [x] **Step 1 — `doctor.sh`: layout and drift.** No `ai/` → report and exit 0 (AC2). Present →
  report the recorded version, shell out to `manifest.js check` for drift (AC5), and handle the
  no-manifest case by naming the baseline command (AC6). Every check prints one line with a
  status of `ok` / `finding` / `unknown`.
  *Proves:* AC2, AC5, AC6, AC12. *Check:* fixtures in step 4.

- [x] **Step 2 — `doctor.sh`: environment.** Loaded plugin version and the path it loaded from
  (AC3, AC4); `~/.claude/plugins` read-only for install scope and cached versions, absent
  without failing (AC12, spec question 2); adapters present and current (AC7). This is the step
  that would have caught what the `specs/0001` session lost hours to, so it is worth being
  specific rather than generic: report scope, version and path, not "plugin: ok".
  *Proves:* AC3, AC4, AC7, AC12. *Check:* fixtures, plus running it in this repo where the
  answers are known by hand.

- [x] **Step 3 — `commands/doctor.md`.** Run the script, report findings worst-first, one line
  each with its remedy (AC9), a single line when all clear (AC11), ask nothing (AC10). AC8's
  tracker line comes from `ai/docs/tracker.md` and names no vendor — the same rule `spec.md`
  follows, so `check-adapters.sh` already asserts it.
  *Proves:* AC1, AC8, AC9, AC10, AC11. *Check:* real runs, step 5.

- [x] **Step 4 — `check-doctor.sh`.** Four scratch repos: no layout, drift, no manifest,
  healthy. Assert the expected finding appears and that the command exits 0 in all four —
  a doctor that fails when it finds something is a doctor nobody runs in CI. Verify by breaking
  each fixture, not by passing.
  *Proves:* AC2, AC5, AC6, AC11, AC12. *Check:* `bash skills/ai-layout/scripts/check-doctor.sh`.

- [x] **Step 5 — Run it where the answers are already known.** Run against both, with
  `CLAUDE_PLUGIN_ROOT` set as a session sets it. Every answer cross-checked against
  `manifest.js` run directly, and both repos byte-identical afterwards (AC1). In this repo it
  correctly self-detects as the plugin source and reports the two environment findings that are
  genuinely true here. In coach, against the copy actually installed there (0.17.0), it reports
  green — and that is right, and is also the gap below. This repo (healthy, no tracker),
  and `/Users/tanin/code/apps/coach` (drift after its migration, no tracker). coach is the real
  test: its findings are known independently from this session, so a wrong answer is visible.
  Read-only, so running it there changes nothing.
  *Proves:* AC1, AC3, AC4, AC7, AC9. *Check:* transcripts in the MR.

- [ ] **Step 6 — CHANGELOG, version bump, README, workflow.** Include the not-loaded case:
  if `/t4:doctor` does not exist, the plugin is not enabled here — and say where that is fixed.
  *Check:* `check-versions.sh`, definition of done items 3 and 7.

## Risks
| Risk | How it is checked |
|---|---|
| It reports "healthy" on a broken setup — worse than not existing, because it is trusted. | Step 4 breaks each fixture deliberately; step 5 runs against coach, whose faults are known independently. |
| It reads `~/.claude` and fails where that is absent, e.g. under Codex. | AC12: unknown-with-reason, never a failure. Fixture with the path unset. |
| Findings without remedies — a list of complaints. | AC9 is asserted per finding in step 4. |
| The prompt quietly reimplements a check, so it cannot be tested. | Step 3 is a reporter only; anything deterministic lives in the script. |
| It grows into a fixer. | Out of scope is explicit; read-only is what makes it safe to run first. |

## Verification
```
bash -n  skills/ai-layout/scripts/doctor.sh
bash skills/ai-layout/scripts/check-doctor.sh
bash skills/ai-layout/scripts/check-adapters.sh      # AC8's no-vendor rule
bash skills/ai-layout/scripts/check-versions.sh
bash ai/make/sync-adapters.sh && bash ai/make/sync-adapters.sh
```
Plus step 5's two transcripts, and `/t4:check` with no blocker findings.

## Found in step 5 — not fixed, not in scope
**The doctor compares a repo against the plugin it was handed, and never says a newer one
exists.** Run in coach against its installed 0.17.0, everything reports green. Run against the
0.19.0 working tree, the same repo is a version behind with two files to take. Both answers are
correct; they answer different questions. But the published marketplace clone is at 0.19.0
while coach's install is 0.17.0, so a developer there sees "all green" while the release
carrying the `ai.mk` fix they need sits uninstalled.

That is precisely the invisible state this command exists for, and `specs/0002` does not ask
for it — AC3 promises loaded-versus-recorded, which is delivered. It needs a new AC comparing
the installed version against the marketplace's, not a quiet addition here.

## Planning notes
- **Nothing here can fix the plugin's own installation**, and step 6 exists partly to write
  that down. The command runs inside a session that already loaded the plugin, so the case that
  hurt most today is the one case only the README can cover.
- **coach is the fixture that cannot be faked.** Its drift, its missing `e2e` task and its
  broken `ai.mk` were all found by hand earlier; a doctor that misses them is wrong regardless
  of what the scratch fixtures say.
