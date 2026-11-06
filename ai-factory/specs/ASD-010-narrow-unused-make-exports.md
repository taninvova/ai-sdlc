# ASD-010 — Narrow unused module exports in make scripts
Created: 2026-11-04T01:42:40.692Z

Remove from `module.exports` the 20 names that `fallow dead-code` v3.38.1 reports as unused and that nothing outside their defining file references, keeping every function and constant in place and every behaviour unchanged.

## User story
As a maintainer of the ai-sdlc plugin, I want each script under `skills/ai-layout/` to export only the names some other file actually uses, so that the export surface — the test seam and what adopted repos could `require()` — is no wider than it needs to be.

## Background
Found with `fallow dead-code` v3.38.1. The repo has no `package.json`, so fallow detects no entry points here; the analysis ran with a temporary config declaring `skills/**/*.js` as entries, ignoring the `ai-factory/make/**` symlinks, with `--include-entry-exports`. It flagged 102 exports; 82 are referenced by name elsewhere and are kept. For the 20 below, `git grep -w <name>` outside the defining file returns nothing in code, checks, fixtures or docs (at spec time the only other hit is `WORKSPACE`, which appears as plain text inside recorded run data under `ai-factory/runs/small-task-benchmark-2026-10-06T19-45-13-186Z/`, not as a reference to the export). Every one of the 20 is still used inside its own file: this narrows exports, it deletes no definition.

| File | Names to drop from `module.exports` |
|---|---|
| `skills/ai-layout/scripts/benchmark-small-tasks.js` | `buildReport`, `completionOf`, `renderReport` |
| `skills/ai-layout/templates/ai-factory/make/continue.js` | `ACTIONS`, `answersProblem`, `resultProblem` |
| `skills/ai-layout/templates/ai-factory/make/cost.js` | `DIMENSIONS`, `emptyMessage`, `EXPORT_METRICS`, `renderTable`, `TABLE_DIMENSIONS`, `TSV_COLUMNS`, `UNATTRIBUTED` |
| `skills/ai-layout/templates/ai-factory/make/delivery-report.js` | `renderJson`, `renderMarkdown` |
| `skills/ai-layout/templates/ai-factory/make/ids.js` | `normalise` |
| `skills/ai-layout/templates/ai-factory/make/loop.js` | `parseOptions`, `planRows`, `UsageError` |
| `skills/ai-layout/templates/ai-factory/make/runner.js` | `WORKSPACE` |

Related: a separate spec, being written concurrently, covers import cycles in the same `make/` scripts; the two touch the same files and should be sequenced or merged with care.

## Acceptance criteria
- **AC1** — Given `skills/ai-layout/scripts/benchmark-small-tasks.js`, When it is loaded with `require()`, Then the returned object has no own property `buildReport`, `completionOf` or `renderReport`, and every other name it exported before the change is still exported.
- **AC2** — Given `skills/ai-layout/templates/ai-factory/make/continue.js`, When it is loaded with `require()`, Then the returned object has no own property `ACTIONS`, `answersProblem` or `resultProblem`, and every other name it exported before the change is still exported.
- **AC3** — Given `skills/ai-layout/templates/ai-factory/make/cost.js`, When it is loaded with `require()`, Then the returned object has no own property `DIMENSIONS`, `emptyMessage`, `EXPORT_METRICS`, `renderTable`, `TABLE_DIMENSIONS`, `TSV_COLUMNS` or `UNATTRIBUTED`, and every other name it exported before the change is still exported.
- **AC4** — Given `skills/ai-layout/templates/ai-factory/make/delivery-report.js`, When it is loaded with `require()`, Then the returned object has no own property `renderJson` or `renderMarkdown`, and every other name it exported before the change is still exported.
- **AC5** — Given `skills/ai-layout/templates/ai-factory/make/ids.js`, When it is loaded with `require()`, Then the returned object has no own property `normalise`, and every other name it exported before the change is still exported.
- **AC6** — Given `skills/ai-layout/templates/ai-factory/make/loop.js`, When it is loaded with `require()`, Then the returned object has no own property `parseOptions`, `planRows` or `UsageError`, and every other name it exported before the change is still exported.
- **AC7** — Given `skills/ai-layout/templates/ai-factory/make/runner.js`, When it is loaded with `require()`, Then the returned object has no own property `WORKSPACE`, and every other name it exported before the change is still exported.
- **AC8** — Given any of the seven files, When its source is searched, Then each of the 20 names it no longer exports is still defined in that file and still used there (no definition is deleted).
- **AC9** — Given the change is applied, When every check in AGENTS.md's "Checks (all of them)" command runs, plus `node --check` on each of the seven files, Then each exits 0, as it did before the change.
- **AC10** — Given the change is applied, When `git grep -w <name>` is run for each of the 20 names, Then no file other than its defining one references it as code (a `require`, destructure or property access), so no in-repo caller is broken.
- **AC11** — Given the same `fallow dead-code` v3.38.1 configuration that produced the original report, When it runs after the change, Then none of the 20 names is reported as an unused export.

## Out of scope
- The other 82 exports fallow flagged; they are referenced elsewhere and are kept.
- Deleting, renaming or rewriting any function or constant; changing any CLI, output, exit code or file format.
- Import cycles in the `make/` scripts (the related, concurrent spec).
- Adding `package.json`, a fallow config, or fallow as a check or CI step.
- Editing `ai-factory/make/` or anything else under `ai-factory/` that dont-touch protects; the change goes to the template targets only.

## Effort and risk
Effort: **L** — size L (seven files, over the five-file line, though each edit is a few lines inside one `module.exports` literal), uncertainty M (a known pattern; the open unknown is whether an adopted repo requires any of these names, plus the release and CHANGELOG treatment).

- dev 1–2 h (assumption: edits are confined to the seven `module.exports` blocks, the existing checks need no change, and the adopter question is answered before work starts)
- /fc:run ~15–40 min (assumption: one or two plan steps, dominated by running the full check suite once)

Risk triage (categories):
- authorization — absent: no access control or permission logic is touched; only export lists change.
- data exposure — absent: no data is read, written or logged differently; narrowing exports exposes less, not more.
- secrets — absent: none of the 20 names holds or handles credentials.
- injection — absent: no input parsing, shell or path handling changes.
- dependency/supply chain — absent: no dependency is added or removed; fallow was used once for discovery and is not added to the repo.
- migrations — absent: no data, schema or file format changes.
- rollback — absent: a plain revert restores the exports; nothing persistent is written.
- blast radius — present: six of the seven files are templates that ship to every adopted repo (`ai-factory/make/` symlinks there), and AGENTS.md classes template changes as breaking.

Risk triage (`/fc:start` triggers):
- uncertain requirements — present: whether any adopted repo `require()`s one of these names is unknown, and the request leaves it open.
- authorization — absent: no authorization surface is involved.
- public contracts — present: `module.exports` of the shipped `make/` scripts is a de facto API for adopted repos, and this change narrows it.
- migrations — absent: nothing to migrate.
- dependencies — absent: no package or tool dependency changes.
- service ownership — absent: all seven files are owned by this plugin; no other service is involved.

## Open questions
1. Could an adopted repo `require()` any of the 17 names from the six template files (`continue.js`, `cost.js`, `delivery-report.js`, `ids.js`, `loop.js`, `runner.js`)? Is a search of known adopters needed first, or is the `make/` export surface declared internal (loop.js's header calls its exports "the test seam")?
2. AGENTS.md says template changes are breaking and must be stated in the MR and CHANGELOG. Does this change need a CHANGELOG entry and a version bump, and if so is it a major release (as 6.0.0 was), or is narrowing an internal test seam treated as non-breaking?
3. Should a deprecation period apply (keep the names exported for one release with a notice) instead of removing them outright?
4. Should AC11 be a criterion at all? Re-running fallow requires the temporary config, which the request does not commit to the repo; if it is not reproducible in review, AC10 alone may be the verification.
5. Should anything stop the exports from growing back (a check, a note in coding-standards), or is this a one-off clean-up? The request asks for neither.
6. Ordering with the concurrent import-cycles spec on the same `make/` files: which lands first, or do they ship together?
7. Run `/fc:risk ai-factory/specs/ASD-010-narrow-unused-make-exports.md`

## Decisions as shipped
Implemented directly on `chore/fallow-cleanup` (MR !25, release 7.0.0) without a plan; recorded
here so the spec matches what shipped. Each answers the open question of the same number.

1. **Adopters.** No search of adopted repos was made. The `make/` export surface is treated as the
   test seam it is, and the narrowing is stated as breaking: CHANGELOG 7.0.0 names the removed
   names' files and says adopter code requiring one must keep its own copy.
2. **Release.** A CHANGELOG entry and a major version: 7.0.0, shared with the stack-agnostic base and
   the rest of the fallow cleanup.
3. **Deprecation.** None; the names are removed outright.
4. **AC11.** Kept and reproducible: the repo now commits `.fallowrc.jsonc` (scoped to shipped code),
   and `fallow dead-code` reports no unused export with it. That config is a separate commit in the
   same MR, outside this spec's change, which the Out of scope line on a fallow config now cedes.
5. **Regrowth.** `.fallowrc.jsonc` records the scope and thresholds; adding fallow as a check is a
   separate follow-up, not part of this spec.
6. **Ordering.** Shipped together with ASD-011 in one release.
7. **Risk.** `/fc:risk` was not run; the independent review of MR !25 covered AC1–AC11.

## Data touched
None: no models, fields, stored data or file formats.

## Routes touched
None. No `/fc:` command, CLI argument or `make` target changes.

## Components likely involved
- `skills/ai-layout/scripts/benchmark-small-tasks.js` (plugin-only script, not shipped)
- `skills/ai-layout/templates/ai-factory/make/continue.js`, `cost.js`, `delivery-report.js`, `ids.js`, `loop.js`, `runner.js` (templates shipped to adopted repos)
- The checks under `skills/ai-layout/scripts/check-*.sh` and `skills/ai-hooks/fixtures/check-*.sh`, as verification only
- `CHANGELOG.md`, depending on open question 2
