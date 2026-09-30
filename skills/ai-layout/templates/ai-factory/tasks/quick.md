---
description: Complete a small, well-understood change with focused verification
argument-hint: <change and expected result>
---
If nothing follows the command name, ask for the change and expected result, then stop.

Read ai-factory/AGENTS.md, the applicable protection rules and coding conventions, then the
affected code and its nearby tests. Reuse unchanged context already read in this session.

1. Check scope. Use this route for a local change with an understood result. If requirements
   are uncertain, or the change affects authorization, public contracts, migrations, dependencies
   or service ownership, preserve current work and name the decision needing the normal workflow.
   File count alone does not decide risk. Respect a workflow the user explicitly chose.
2. Write a short acceptance checklist in the conversation. No separate spec, plan or delegated
   agent is required for this route. Inspect existing changes and preserve them. Only when
   `ai-factory/contracts/config.json` exists, write the checklist instead to
   `ai-factory/quick/<slug>.md` as `- [ ] QC1 — …` items with ``Verify (final): `command` `` lines
   (plain arguments, no shell syntax), then run `node ai-factory/make/contracts.js init quick <path>`.
3. Implement the requested change and meaningful regression coverage. For a bug, demonstrate
   the failing case first. For prose-only changes, use applicable document checks rather than
   inventing runtime tests. Do not introduce unrelated cleanup or a new dependency.
4. Run the affected checks and any project-required completion checks. Run the full required
   suite once at completion, not after every edit; rerun affected checks after further edits.
   A repeated failure needs a new hypothesis or evidence. After two attempts at the same failure
   with no new evidence, report the blocker and preserve work. Never weaken tests to pass.
   With contracts, tick the items, then record `make -f ai-factory/make/ai.mk verify DELIVERY=<id>`;
   report its result and `make -f ai-factory/make/ai.mk contracts DELIVERY=<id>`; `/t4:report <id>`
   writes the optional completion report.
5. Self-review the actual local diff, including relevant untracked files. Clearly call this a
   self-review. Use independent review if the user or project requires it; never imply independence.

Report the acceptance result, files changed, verification actually performed and any unresolved
concern. A failed or unavailable required check remains unverified; do not claim completion.

Lifecycle telemetry, only when `ai-factory/contracts/config.json` sets `"lifecycle": {"enabled": true}`:
first run `node ai-factory/make/lifecycle.js start --phase quick` and keep the run ID it prints;
bracket any wait for the developer with `lifecycle.js wait-start --run <run>` and `wait-end --run <run>
--wait <wait>`; at the end run `lifecycle.js end --run <run> --outcome succeeded|failed|interrupted --delivery <id>`.
A lifecycle message never changes this task's outcome; report it and carry on.

Change: $ARGUMENTS
