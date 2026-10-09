# Start entry command — implementation evidence

Status: implemented; plan complete; live acceptance incomplete. Plan steps 1 and 3 verified;
Steps 2 and 4 marked complete by the owner (2026-10-05) with their host runs waived, and
Step 4's independent review of the final diff waived. Deterministic final checks pass
(see "Step 4 final verification"). No release/version bump.

## Result

Interactive Claude `/t4:start` and Codex `$t4-start` classify into one allowlisted existing
workflow, validate bounded JSON, and hand original request text to the destination independently.
The classifier changes no files. Configured native workers have read-only host profiles.
Questions resume classification; answers remain separate context. Existing direct entries remain.
Headless start rejects before provider launch and run artifacts.

Concrete start model overrides are deliberately rejected before an unrestricted generic worker
could launch. Use configured native routing adapters, explicitly sync and restart, or select
`--task-model=inherit` for session classification. This adjusts the original plan's override design
after review identified that host per-call overrides cannot enforce the required tool profile.

## Verification evidence

- Dispatch red: start-read-only failed on generic write permissions; start-result-validation
  failed on absent validator; start-session-handoff failed on generic completion. Other-worker
  and independent-destination controls passed. All five subsequently passed.
- Entry red: generated generic wrappers failed start-wrapper-handoff, original-input-preserved
  and target-override-not-inherited. All three subsequently passed.
- Override review red: expected blocked but actual ready for concrete start override. After
  rejecting unsupported override workers, dispatch and existing routing checks passed.
- Headless red: fake Claude host launched start and produced a run. Early rejection then passed
  on both hosts; direct quick controls still launched successfully.
- `check-interactive-model-routing.sh`: 12 cases passed.
- `check-plugin-hosts.sh`: 21 Claude commands and 23 Codex skills verified.
- Both generator `--check` invocations passed; repeat generation and self synchronization passed.
- `check-runner-security.sh`, `check-manifest.sh`, `check-workspace.sh` passed; workspace reported
  28 cases. Fresh/older/customized start adoption preserves files and creates no implicit adapters.
- All start groups pass. Hook JavaScript syntax and adapter-shell syntax passed.
- Full `make check`: initial sandbox attempt stopped on adapter-write EPERM; an approved retry
  reached the required empty-input wording convention. Added that convention to start; full-suite
  rerun then encountered fixture drift when models.js changed during doctor verification. Host-specific
  classifier guidance is now fixed (Claude read tools; Codex read-only exec_command under its sandbox),
  and its dispatch/routing checks pass. The next run passed through host checks then caught the
  changelog release-heading convention; corrected the unreleased preamble while retaining 2.8.0
  as the latest release. The unchanged release-docs check passes. **Final `make check` passed (exit 0): all 27 regression scripts completed**, including start
  routing and the final 62-case write-boundary check. Log: `/private/tmp/t4-start-full-check.log`.

Step 1's original ordering required generated Step 2 entries for its routing regression. Once
those entries existed, the exact regression passed and Step 1 was checked. Workspace regression
also exposed a duplicate Claude command: start needed adding to the existing native-command
exclusion set in sync-adapters.js. The unchanged regression passed after this fix.

## Live behavior

A real Claude interactive attempt in `/private/tmp/t4-start-live-rhq3j_s6` changed README's
Setup heading to Installation through start, but selected chore instead of expected quick.
The fixture also contained unsubstituted template placeholders. Retain this as a failed
classification run, not acceptance. The task now explicitly routes requested wording/heading/
label edits to quick and reserves chore for explicit cleanup/maintenance.

Corrected live runs passed on both hosts:

- Heading change: start selected quick, handed off once, and changed the README heading as requested.
- Empty request: asked for the change and expected result without dispatching.
- Incompatible explicit choice (`Use quick to add a public API and database migration.`): both
  hosts returned a validated question, with no destination dispatch or file changes. Codex asked
  to use the planned workflow; Claude offered planned/design or analyse options.
- Claude transcript: [interactive run](/Users/Volodymyr_Tanin/.claude/projects/-private-tmp-t4-start-live-rhq3j-s6/9959488f-690c-4cf8-b55d-1e4cdcb3b780.jsonl).
- Codex transcript: [interactive run](/Users/Volodymyr_Tanin/.codex/sessions/2026/10/05/rollout-2026-10-05T17-04-01-01a10de1-75b4-71f1-8326-f8f761be5831.jsonl).

Codex used a native local skill in an isolated fixture. This does not prove installed-plugin
skill discovery. These links identify source evidence; raw transcripts with private system
context are not reproduced in this report. Live outcomes were supplied by the coordinating
session that operated the hosts.

Independent review of the final change by review_start: **approve, no findings**. Its earlier
findings produced the concrete-override rejection and host-specific read-only guidance described
above; the final review assessed those corrections.

The rest of the plan matrix remains pending on both hosts: remaining fix/chore classifications; broader risk and
prerequisite ordering; compatible explicit choices and existing artifacts; ambiguous/missing/dirty workspaces;
model configuration and failure cases; exact multiline/quoted/retained-flag input. Static prompt
assertions and fake hosts establish deterministic mechanics, not model classification quality.

## Step 4 final verification (2026-10-05)

Documentation gap review: README, both AGENTS.md files, workflow.md and CHANGELOG already
described start, its classification scope, start-versus-destination model scope, the blocked
concrete start override, the interactive-only limit and template upgrade impact. One real gap
fixed: README still said the plugin ships 20 Claude slash commands; it now says 21, matching
`commands/` and workflow.md. The plan's design text and run matrix were aligned with the
implemented blocked concrete start override.

Final checks, each run as written in the plan, all exit 0:

- `bash skills/ai-layout/scripts/check-start-routing.sh` — 11 PASS (dispatch 5, entry 4, headless 2).
- `node skills/ai-layout/scripts/sync-claude-commands.js --check` — 14 task wrappers verified.
- `node skills/ai-layout/scripts/sync-codex-skills.js --check` — 23 skills verified.
- `bash -n skills/ai-layout/templates/ai-factory/make/sync-adapters.sh` — clean.
- Fail-fast full suite (hook syntax plus every `check-*.sh`) — exit 0, ending with the 62-case
  write-boundary check.

Not done in this step, so Step 4 stays unticked pending an owner decision:

- No new host transcripts were captured. The only before/after evidence is the live runs listed
  above (heading change, empty request, incompatible explicit choice on both hosts); the rest of
  the plan's matrix is unverified on both hosts, and Step 2's paired runs were waived.
- No new independent review of the final diff was performed in this step; the earlier
  review_start approval predates these documentation edits (README count, plan text).

## Upgrade impact

Adopted workspaces need start.md plus updated models.js, runner.js, sync-adapters.js and AGENTS.md.
Inspect drift and retain local additions; explicitly regenerate configured routing adapters and
restart the host where necessary. No automatic adapter synchronization or new dependency.
