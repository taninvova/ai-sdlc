# ASD-011 — Break the require() cycles among the make scripts
Created: 2026-11-04T01:43:57.866Z

Restructure `assurance.js`, `gate.js`, `contracts.js` and `delivery-report.js` in the make templates so that `fallow dead-code` reports no circular dependency, with every CLI behaving exactly as before.

Parent: none (no exploration or analysis for this feature). Related: `ai-factory/specs/ASD-010-narrow-unused-make-exports.md`, written at the same time, removes unused exports from the same make scripts.

## User story
As a maintainer of the ai-sdlc templates, I want the make scripts' modules to have no circular `require()` dependencies, so that no module can see a half-initialised `exports` object depending on which file loads first, and `fallow dead-code` stops reporting cycles.

## Current behaviour (read from the code on 2026-11-03)
Files are under `skills/ai-layout/templates/ai-factory/make/` (`ai-factory/make/` symlinks to them). `fallow dead-code` 3.38.1, run from the repository root, reports three cycles, all through `assurance.js`:
- assurance.js → contracts.js → gate.js → assurance.js
- assurance.js → delivery-report.js → contracts.js → gate.js → assurance.js
- assurance.js → delivery-report.js → gate.js → assurance.js

The require sites that make them:

| Edge | Site | Kind |
|---|---|---|
| contracts.js → gate.js | `contracts.js:10` `const { digest, assuranceModule } = require("./gate.js")` | top-level |
| delivery-report.js → contracts.js | `delivery-report.js:9` | top-level |
| delivery-report.js → gate.js | `delivery-report.js:10` `const { digest } = require("./gate.js")` | top-level |
| gate.js → assurance.js | `gate.js:93` `assuranceModule()`: `require(path.join(__dirname, "assurance.js"))` when the file exists | lazy, computed path |
| gate.js → assurance.js | `gate.js:116` `gateMode()` and `gate.js:129` `evaluate()`: `require("./assurance.js")` | lazy, literal |
| assurance.js → contracts.js | `assurance.js:256` `readContracts()` | lazy |
| assurance.js → delivery-report.js | `assurance.js:384` `complete()` | lazy |

`assurance.js` requires only `safe-files.js` at the top level; every edge back into it is inside a function. So no cycle is followed while modules load: each lazy `require` runs after all the files it touches have finished loading. The one place a module is re-entered while it is still the running entry point is `node ai-factory/make/assurance.js show|set|complete`: `main()` lazily loads `contracts.js` (and, for `complete`, `delivery-report.js`), whose `contracts.assurance()` calls `gate.assuranceModule()`, which `require`s `assurance.js` again and receives the entry module from Node's cache. That is safe today only because `assurance.js` assigns `module.exports` before calling `main()` (`assurance.js:451–468`, with a comment saying so), and because Node resolves the symlinked entry to the same real path as `gate.js`'s `__dirname`. `contracts.js` calls `main()` before assigning `module.exports` (`contracts.js:1492–1496`), but nothing that `main()` reaches synchronously requires `contracts.js` back, so it is not re-entered.

Conclusion: no current entry point (the four CLIs above, `runner.js`, `loop.js`, `continue.js`, `delivery-status.js`, `ai.mk` targets) reaches a partial export today. The safety rests on statement ordering and lazy placement, which a later edit can break without any check noticing.

## Acceptance criteria
- AC1. Given the changed templates, when `fallow dead-code` 3.38.1 runs from the repository root, then its output has no "Circular dependencies" finding for any file under `skills/ai-layout/templates/ai-factory/make/`.
- AC2. Given the changed templates, when the make scripts are searched for `fallow-ignore` comments, then none suppresses `circular-dependency`: the cycles are removed by restructuring the modules, not by suppression.
- AC3. Given the same arguments, environment and repository state, when each of `gate.js`, `contracts.js`, `assurance.js` and `delivery-report.js` is run as a CLI before and after the change, then stdout, stderr and the exit code are identical.
- AC4. Given an `ai-factory/make/` copy that has no `assurance.js`, when `gate.js` runs, then it behaves as before: legacy gate behaviour with no `ai-factory/assurance.json`, and with that file present the same error naming `/fc:sync-sdlc` and exit 2.
- AC5. Given the changed templates, when `node ai-factory/make/assurance.js complete <delivery>` and `node ai-factory/make/assurance.js show` run, then each produces the same output and exit code as before the change.
- AC6. Given the changed templates, when the repository's checks run (`for f in skills/ai-layout/scripts/check-*.sh skills/ai-hooks/fixtures/check-*.sh; do bash "$f" || echo "FAIL $f"; done`), then no check prints `FAIL`.
- AC7. Given the change ships changed template files, when the release is prepared, then `CHANGELOG.md` names each changed or added template under `ai-factory/make/` and states that the change is breaking for adopted repos and is received through `/fc:sync-sdlc`, as `ai-factory/AGENTS.md` requires for template changes.

## Impact on adopted repos
Every file touched here is a template copied into adopted repos by `/fc:adopt-sdlc` and updated by `/fc:sync-sdlc`, so the change is breaking by the repo's rule regardless of its shape. What differs between the shapes the fix may take:
- Moving functions between existing files only: no new file reaches adopters; a repo that has not synced keeps the old, working files.
- A new shared module (for example one holding `digest` or the assurance loader): adopters receive one more file in `ai-factory/make/`, tracked by the `.sdlc.json` manifest; `skills/ai-layout/SKILL.md` lists the make files and would need it added. A partially synced repo could hold new callers without the new module, which `gate.js` today guards for `assurance.js` only (AC4).
- Removing or moving an export (`gate.js` exports `assuranceModule`, `selectedPreset`, `gateMode`, `digest`, which `contracts.js`, `runner.js`, `loop.js` and `delivery-report.js` use): any adopter code that `require`s these modules directly would break. Whether that is supported is an open question.

## Out of scope
- The unused-export cleanup in the same scripts (ASD-010).
- Any other `fallow` finding, and `fallow architecture`.
- Changing what any CLI prints, its options or its exit codes.
- Adding `fallow` to the repository's checks or CI (see Open questions).
- Make scripts outside the four files in the cycles, except as callers that must keep working.

## Effort and risk
Effort: **L**. Size L: at least four template scripts plus `CHANGELOG.md` and the plugin version change, and possibly a new module with its `SKILL.md` listing; uncertainty M: a known refactoring pattern (extract the shared leaf, invert the lazy edge), with minor unknowns about the computed-path require and the export surface.
- dev 3–6 h (assumption: no new shared module beyond one small leaf file, and a before/after CLI comparison done by hand over the existing check fixtures)
- /fc:run ~40–90 min (assumption: a plan of three to five steps, each verified by the existing checks)

Risk triage:
- authorization: absent — the scripts carry no access control and the change adds none.
- data exposure: absent — no new data is read, written or printed.
- secrets: absent — no credential or key is handled by the touched code.
- injection: absent — require targets stay fixed paths beside the script; no input reaches a `require` path.
- dependency/supply chain: absent — no package is added; `fallow` is used as an external tool, not added to the repo.
- migrations: absent — no file format, sidecar, schema or manifest format changes.
- rollback: absent — reverting the templates and running `/fc:sync-sdlc` restores the old files; no state is written by the refactor.
- blast radius: present — the files are templates in every adopted repo and sit on the review gate, contracts and completion paths.
- uncertain requirements: present — whether the computed-path require counts as a cycle and whether exports may move are not settled.
- authorization (trigger): absent — no permission or role logic is touched.
- public contracts: present — the CLIs' output and the modules' exports are relied on by other templates and possibly by adopters.
- migrations (trigger): absent — nothing stored changes shape.
- dependencies: absent — no new third-party dependency.
- service ownership: absent — all touched files are owned by this plugin.

## Open questions
- Run `/fc:risk ai-factory/specs/ASD-011-break-make-require-cycles.md`.
- `gate.js:93` loads `assurance.js` through a computed path, which `fallow` presumably does not see as an edge. Must that runtime edge also be gone (no cycle at all at runtime), or is "fallow reports none" (AC1) the bar?
- May the fix add a new shared module under `ai-factory/make/`, or must it only move functions between the existing files? A new file changes what adopters receive and what `SKILL.md` lists.
- Must the current exports of `gate.js`, `contracts.js`, `assurance.js` and `delivery-report.js` stay importable from the same files (for adopter code that requires them directly), or only what the shipped scripts use? This interacts with ASD-010.
- If a new module is added, should callers guard its absence in a partially synced repo the way `gateMode`/`assuranceModule` guard a missing `assurance.js`, or is a partial copy unsupported for it?
- Should a regression guard be added so a cycle cannot return (a check script, or `fallow` in CI), or is a one-off `fallow` run enough? Adding `fallow` to the checks would introduce a tool dependency.
- How is AC3's "identical output" to be demonstrated: the existing check fixtures, or a recorded before/after run per CLI linked in the MR?
- Does this ship in the same release as ASD-010, and in which version (the plugin is at 6.0.0)?

## Decisions as shipped
Implemented directly on `chore/fallow-cleanup` (MR !25, release 7.0.0) without a plan; recorded
here so the spec matches what shipped. Each answers the open question in the order listed.

1. **Risk.** `/fc:risk` was not run; the independent review of MR !25 covered AC1–AC7.
2. **Runtime edge.** Gone too, not only in fallow's view: `gate.js` loads the policy through
   `assurance-policy.js` on both the literal and the computed path, so nothing re-enters
   `assurance.js` while its CLI runs.
3. **New module.** Yes: `make/assurance-policy.js`, a leaf requiring only Node built-ins and
   `safe-files.js`, holding the presets, `enforcement`, `resolve` and `readSelection`.
   `skills/ai-layout/SKILL.md` lists it, and this repo's `ai-factory/make/` links it.
4. **Exports.** Every export of `gate.js`, `contracts.js`, `assurance.js` and `delivery-report.js`
   stays importable from the same file; `assurance.js` re-exports the policy. ASD-010 narrows
   others separately.
5. **Partial copy.** Guarded both ways. `gate.js` names `make/assurance-policy.js` when a preset is
   selected and it is missing (AC4, with the new file name in the message). `make ai` under a
   preset refuses with a `/fc:sync-sdlc` message when `assurance.js` is missing, and
   `assurance.js` exits 2 with one when its policy module is missing. `check-assurance.sh` pins
   all three.
6. **Regression guard.** `.fallowrc.jsonc` is committed; running fallow as a check is a follow-up.
7. **AC3 evidence.** The four CLIs were run on this repo before and after, and stdout, stderr and
   exit codes matched; the existing checks cover the rest. No recorded run is linked.
8. **Release.** 7.0.0, together with ASD-010.

## Data touched
None: no model, field, sidecar, schema or file under `ai-factory/` that the scripts read or write changes shape.

## Routes touched
None (no service). CLI surfaces whose behaviour must not change: `make/gate.js`, `make/contracts.js` (`validate`, `snapshot`, `init`, `record`, and the rest), `make/assurance.js` (`show`, `set`, `complete`), `make/delivery-report.js`, and the `ai.mk` targets `contracts`, `verify` and the report target that call them.

## Components likely involved
- `skills/ai-layout/templates/ai-factory/make/assurance.js`, `gate.js`, `contracts.js`, `delivery-report.js`
- Callers that must keep working: `runner.js`, `loop.js`, `continue.js`, `delivery-status.js`
- Possibly a new module in the same directory, and `skills/ai-layout/SKILL.md` (make file list)
- `CHANGELOG.md`, `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` versions
- Checks exercising them: `skills/ai-layout/scripts/check-review-gate.sh`, `check-contracts.sh`, `check-assurance.sh`, `check-delivery-report.sh`, `check-delivery-status.sh`, `check-loop.sh`, `check-manifest.sh`
