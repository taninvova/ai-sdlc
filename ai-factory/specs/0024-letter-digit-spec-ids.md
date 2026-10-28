# 0024 — Letter-and-digit artefact IDs

Every numbered artefact in `ai-factory/` (specs, plans, explorations, analyses, designs, ADRs and risk assessments) gets a random ID of three letters and three digits, such as `DHW631`, instead of the next free four-digit number. A script helper draws the ID, checks it against one ID space shared by all of `ai-factory/`, and creates the file exclusively, so parallel sessions cannot clash. A check catches clashes between separate clones. Existing four-digit artefacts stay valid and are never renamed.

## User story

As a developer who runs more than one session at a time, I want each new artefact to get a random, collision-checked letter-and-digit ID instead of "the next free number", so that two agents writing at the same moment, or on separate branches, never end up with the same ID. (Two concurrent specifiers recently both picked the same next free number.)

## Request (verbatim)

> change specs numbering — use letter with numbers, example: A001, DHW631

## Decisions from the developer (interviews)

Round 1:

1. Spec IDs change from the four-digit "next free number" to letters plus digits.
2. The ID is random and collision-safe, and it is checked free before the file is written.
3. The plan keeps its spec's ID.
4. The existing four-digit specs and plans stay valid.
5. This is a template change that breaks adopted repos. The MR and the CHANGELOG say so.

Round 2:

1. Scope: everything that uses `NNNN`. That is specs, plans, explorations, analyses, designs, ADRs (including the ADR template and its `superseded by NNNN` line) and risk assessments (spec 0023).
2. The generator always writes exactly `[A-Z]{3}[0-9]{3}`. Readers accept that form and the legacy four-digit form. Matching is case-insensitive, and files are written uppercase.
3. The letters exclude `I` and `O`. A denylist of offensive letter triples is excluded. IDs that would match the `AC`/`QC`/`S` ID patterns are rejected.
4. There is one ID space across `ai-factory/`. Feature artefacts reuse the feature's ID.
5. The file is created exclusively, and the helper redraws if it exists. A check catches clashes between separate clones or branches.
6. The script helper `node ai-factory/make/ids.js` creates every artefact, on Claude Code, Codex and headless.
7. The helper writes a `Created: <ISO timestamp>` line, and ordering uses it. Legacy files sort by number, before all new ones.
8. `/fc:state`'s `number` field is renamed `id`, which breaks parsers. The usage messages are reworded.
9. A new artefact's heading carries its ID. Existing files are not touched.
10. 0024 ships first. 0022 and 0023 are amended afterwards.
11. Adopted repos get a CHANGELOG migration note. There is no doctor check.
12. This spec and its plan keep `0024`.

Round 3:

1. `--next` keeps the last commit date as its primary key, with uncommitted work first. `Created:` replaces only the tie-break. On a tie, legacy files rank below new-style ones.
2. A new-style file with a missing or malformed `Created:` sorts after all dated files, and the check warns about it but does not fail. Equal timestamps are ordered alphabetically by ID.
3. A spec reuses the ID of the exploration or analysis it came from. A plan and a risk assessment reuse the spec's ID. Designs and ADRs always get their own ID. The clash check allows exactly these pairings.
4. The clash check ships as `skills/ai-layout/scripts/check-ids.sh` and as a template make target such as `make -f ai-factory/make/ai.mk ids-check`. Adoption adds no CI wiring, and the CHANGELOG mentions the target.
5. Legacy four-digit IDs are exempt from the one-ID-space rule and from cross-kind clash checking. Only same-kind duplicates of a four-digit number are reported.
6. A built-in denylist ships in `ids.js`. An optional `ai-factory/ids-deny.txt`, one triple per line, adds entries.
7. Reuse goes through `ids.js new <kind> <slug> --id <ID>`. The helper validates that the ID exists in a permitted parent kind. If the target file already exists, it exits non-zero and prints the existing path.
8. The helper writes `# <ID> — <Title>` with `Created: <ISO timestamp>` on the next line; for ADRs it copies the ADR template with the ID filled in. The agent writes the rest. `Created:` is excluded from the spec's contract content digest.

Round 4 (the developer accepted these defaults):

1. The helper takes `--title "<Title>"`. Without it, the title is derived from the slug: hyphens become spaces and the first letter is capitalised.
2. ADRs get a `Created:` line too, after the template's heading, so they sort like every other kind. The template's `Date:` line is kept.
3. There is one file per kind per ID. With `--id`, the helper refuses whenever any file of that kind already has that ID, whatever its slug.
4. A spec built on a legacy (four-digit) exploration or analysis draws a fresh ID and cites the exploration's or analysis's path.
5. A spec built on both an exploration and an analysis reuses the exploration's ID and cites the analysis. The clash check allows this.
6. `ids-deny.txt` entries match case-insensitively. After trimming, blank lines and `#` comments are ignored. Any other line that is not exactly three letters is warned about and skipped.
7. In the `--next` tie-break, among dated new-style files with the same key, the earliest `Created:` wins. This matches today's "lowest number first".

Follow-up:

1. An exploration or analysis may feed several specs. A second spec from a parent whose ID an earlier spec already reused draws a fresh ID and cites the parent's path, exactly as for a four-digit parent.

## Acceptance criteria

### The ID format
- **AC1 — Generated form.** Given the ID helper, when it draws an ID, then the ID matches exactly `^[A-HJ-NP-Z]{3}[0-9]{3}$`: three uppercase letters, none of them `I` or `O`, then three digits.
- **AC2 — Built-in denylist.** Given the denylist built into `ids.js`, when the helper draws IDs, then it never returns an ID whose letters are a triple on that list.
- **AC3 — Repo denylist.** Given `ai-factory/ids-deny.txt` lists a triple on a line of its own, in any case and with any surrounding whitespace, when the helper draws IDs, then it never returns an ID with those letters. Given the file is absent, the helper uses the built-in list alone and reports no error.
- **AC4 — Denylist hygiene.** Given `ai-factory/ids-deny.txt` holds blank lines, lines starting with `#`, and lines that are not exactly three letters after trimming (such as `AB`, `ABCD` or `A1C`), when the helper reads it, then blank and `#` lines are ignored silently. Each other bad line is skipped with a warning that names it, and the helper still creates the file.
- **AC5 — No ID reads as a criterion, check or step ID.** Given the helper, when it draws IDs, then it never returns an ID that starts with `AC` or `QC`, nor one that matches `^S[0-9]+$`, `\bAC[0-9]+\b` or `\bQC[0-9]+\b`.
- **AC6 — Random, not counted.** Given an unchanged `ai-factory/`, when the helper draws an ID several times, then the IDs differ from one another. None of them is computed from the count of existing artefacts or from the highest existing number.

### The helper: new IDs
- **AC7 — The helper creates the file.** Given `node ai-factory/make/ids.js new <kind> <slug>` with no `--id`, for kind `spec`, `exploration`, `analysis`, `design`, `adr` or `risk`, when it runs, then it creates exactly one new file `ai-factory/<kind dir>/<ID>-<slug>.md` with a freshly drawn uppercase `<ID>`. It prints that file's repository-relative path and exits zero.
- **AC8 — What the helper writes.** Given any non-ADR file the helper creates, when it is read straight after creation, then its first line is `# <ID> — <Title>` and its second line is `Created: <ISO 8601 timestamp>`, holding the time of creation. Nothing else is in the file.
- **AC9 — The title.** Given `--title "Compact delivery status"`, when the helper creates the file, then `<Title>` is `Compact delivery status`. Given no `--title` and the slug `compact-delivery-status`, then `<Title>` is `Compact delivery status`: hyphens become spaces and the first letter is capitalised.
- **AC10 — ADRs come from the template.** Given `ids.js new adr <slug>`, when it runs, then the new file is a copy of `ai-factory/adr/0000-template.md`. Its heading is `# <ID> — <Title>`. A `Created: <ISO 8601 timestamp>` line follows straight after the heading, and the template's `Date:` line and the rest of the template come after that, unchanged.
- **AC11 — The agent writes the rest.** Given any artefact-creating agent, when it writes its artefact, then it keeps the helper's heading line and `Created:` line unchanged and writes the body below them.
- **AC12 — One ID space for new IDs.** Given a new-style ID already used by any file in `ai-factory/specs/`, `plans/` (including `plans/done/`), `explorations/`, `analyses/`, `designs/`, `adr/` or `risks/`, when the helper draws that ID, then it rejects the ID and draws another.
- **AC13 — Exclusive creation.** Given the target file comes into existence between the helper's check and its write, when the helper creates the file, then the create fails without overwriting the file (O_EXCL or equivalent), and the helper redraws and creates a different file.
- **AC14 — Parallel sessions do not clash.** Given two helper invocations in the same working tree at the same time, when both finish, then they have created two files with two different IDs, and neither file holds the other's content.

### The helper: reusing an ID
- **AC15 — Permitted parents.** Given `ids.js new <kind> <slug> --id <ID>`, when it runs, then it creates the file only if an artefact with that ID exists in a permitted parent kind:
  - for a `spec`, an exploration or an analysis;
  - for a `plan` or a `risk`, a spec.
  Otherwise it creates nothing and exits non-zero with a message naming the missing parent.
- **AC16 — No reuse for designs, ADRs, explorations and analyses.** Given `ids.js new design|adr|exploration|analysis <slug> --id <ID>`, when it runs, then it creates nothing and exits non-zero.
- **AC17 — One file per kind per ID.** Given any file of `<kind>` already has the ID `<ID>`, whatever its slug (for a plan, active or under `plans/done/`), when `ids.js new <kind> <slug> --id <ID>` runs, then it creates nothing, leaves the existing file unchanged, prints the existing file's path and exits non-zero. For example, with `plans/DHW631-foo.md` present, `ids.js new plan other --id DHW631` creates no `plans/DHW631-other.md`.
- **AC18 — `--id` is case-insensitive.** Given spec `ai-factory/specs/DHW631-foo.md`, when `ids.js new plan foo --id dhw631` runs, then it creates `ai-factory/plans/DHW631-foo.md`, in uppercase.
- **AC19 — The plan points at its spec.** Given a plan created with `--id DHW631`, when the planner has written it, then its `**Spec:**` line points at `ai-factory/specs/DHW631-…`.

### Who calls the helper
- **AC20 — Every creating agent and task calls it.** Given the specifier, planner, explorer, analyst and architect (design and ADR) prompts and their task templates, when they are read, then each one tells the agent to create its artefact by calling the helper and to write into the path the helper printed. The planner passes `--id` with the spec's ID. None of them tells the agent to pick a number or an ID itself.
- **AC21 — A spec from a new-style exploration or analysis.** Given a spec built on exploration `KXT204` alone, or on analysis `KXT204` alone, and no spec has the ID `KXT204` yet, when the specifier creates it, then the spec is created with `--id KXT204` and has that ID.
- **AC22 — A spec from both.** Given a spec built on exploration `KXT204` and analysis `MRB517`, and no spec has the ID `KXT204` yet, when the specifier creates it, then the spec has the ID `KXT204` and its body cites the analysis's path `ai-factory/analyses/MRB517-…`.
- **AC23 — A spec from a legacy parent.** Given a spec built on the legacy exploration `0005` or a legacy analysis `0001`, when the specifier creates it, then the spec gets a freshly drawn new-style ID (no `--id`), and its body cites that exploration's or analysis's path.
- **AC24 — Every host.** Given `/fc:spec` run on Claude Code, the Codex `fc-spec` skill, and `make ai TASK=spec`, when each one writes a spec, then the spec's file was created by the helper and satisfies AC1 and AC8.

### Templates and contracts
- **AC25 — ADR template and supersession.** Given `skills/ai-layout/templates/ai-factory/adr/0000-template.md` and the architect's ADR procedure, when they are read, then neither shows `NNNN`. A new ADR that supersedes another sets the old ADR's status to `superseded by <ID>`, where `<ID>` is the new ADR's ID.
- **AC26 — `Created:` is outside the content digest.** Given a contracts-enabled spec whose sidecar is up to date, when only its `Created:` line is changed, then the spec's content digest is unchanged and `make contracts` reports no drift. Given any other line is changed, drift is reported as before.

### Legacy artefacts
- **AC27 — Nothing is renamed.** Given the existing four-digit artefacts, this spec `0024` and its plan, when this change is delivered, then none of them is renamed, and none of their headings or numbers is rewritten.
- **AC28 — Legacy specs and plans are read as before.** Given the existing four-digit specs and plans, active and under `plans/done/`, when `/fc:state` runs with no flag and with `--done`, `--specs` and `--plans`, then every legacy artefact appears with the same state and the same plan pairing as before. Its `id` field shows its four-digit number as it is.
- **AC29 — Legacy `--spec` forms still work.** Given spec `0010`, when `/fc:state --spec 0010`, `--spec 10`, `--spec 0010-fc-state` and `--spec ai-factory/specs/0010-fc-state.md` run, then each lists spec `0010` with its plans.

### Readers
- **AC30 — Case-insensitive selection.** Given a spec `ai-factory/specs/DHW631-foo.md` and its plan, when `/fc:state --spec DHW631`, `--spec dhw631`, `--spec DHW631-foo` and `--spec ai-factory/specs/DHW631-foo.md` run, then each lists that spec with its plan.
- **AC31 — Pairing by ID without a `**Spec:**` line.** Given a plan `ai-factory/plans/DHW631-foo.md` with no `**Spec:**` line, when `/fc:state` runs, then the plan is paired with `ai-factory/specs/DHW631-foo.md`.
- **AC32 — Contract migration pairs by ID.** Given a contracts-enabled repo with a plan `ai-factory/plans/DHW631-foo.md` that has no `**Spec:**` line and no sidecar, and a spec `DHW631-foo.md` that has a sidecar, when `make/contracts.js` migrates sidecars, then the plan's sidecar carries that spec's delivery ID.
- **AC33 — Continuation and delivery status accept new IDs.** Given a contracts-enabled delivery whose spec and plan have new-style IDs, when `/fc:continue <delivery id>` and `/fc:state --delivery <delivery id>` run, then each behaves as it does for a delivery with four-digit file names.

### `/fc:state` output and ordering
- **AC34 — `number` becomes `id`.** Given any `/fc:state` listing, when its rows and header are read, then the second field is named `id` and no field is named `number`. `commands/state.md` describes the field as `id`.
- **AC35 — Reworded usage messages.** Given `/fc:state --spec` with no argument, with an argument that is not an ID, or given twice, when it prints its message, then the message uses a new-style example such as `--spec DHW631`. The flag is described as `--spec <id>`.
- **AC36 — Listing order.** Given a tree with legacy and new-style artefacts, when `/fc:state` lists them, then the order is:
  1. all legacy artefacts in ascending number order;
  2. the new-style artefacts with a valid `Created:` line, in ascending `Created:` order, with equal timestamps ordered alphabetically by ID;
  3. last, new-style artefacts whose `Created:` line is missing or malformed, alphabetically by ID.
- **AC37 — `--next` primary key is unchanged.** Given artefacts with different last-commit dates, or uncommitted ones, when `/fc:state --next` runs, then it picks the same artefact as it would before this change, whatever their `Created:` lines say.
- **AC38 — `--next` tie: new before legacy.** Given a legacy artefact and a new-style artefact with the same `--next` key, when `/fc:state --next` runs, then it picks the new-style one.
- **AC39 — `--next` tie: undated last.** Given two new-style artefacts with the same `--next` key, one with a valid `Created:` line and one without, when `/fc:state --next` runs, then it picks the dated one.
- **AC40 — `--next` tie: earliest `Created:` wins.** Given two new-style artefacts with the same `--next` key and valid but different `Created:` timestamps, when `/fc:state --next` runs, then it picks the one with the earlier timestamp.
- **AC41 — `--next` tie: equal timestamps.** Given two new-style artefacts with the same `--next` key and the same `Created:` timestamp, when `/fc:state --next` runs, then it picks the one whose ID sorts first alphabetically.

### Clash check
- **AC42 — Two entry points.** Given this repo, when `bash skills/ai-layout/scripts/check-ids.sh` runs, and given an adopted repo, when `make -f ai-factory/make/ai.mk ids-check` runs, then both apply the same rules (AC43–AC48) to that repo's `ai-factory/`. Adoption adds no CI configuration.
- **AC43 — Same-kind duplicates fail.** Given two files of the same kind that share a new-style ID (for example specs `DHW631-a.md` and `DHW631-b.md`, as two branches would produce after a merge), when the check runs, then it fails and names both paths. Active plans and `plans/done/` count as one kind.
- **AC44 — Permitted pairings pass.** Given a new-style ID shared only by an exploration or an analysis and a spec, a spec and its plan, or a spec and its risk assessment, when the check runs, then it passes. This includes a spec that shares its exploration's ID and cites an analysis with a different ID (AC22).
- **AC45 — Other cross-kind sharing fails.** Given a new-style ID shared by a design or an ADR and any other artefact, or by any pair of kinds not listed in AC44, when the check runs, then it fails and names both paths.
- **AC46 — Legacy numbers: same-kind only.** Given two artefacts of the same kind with the same four-digit number, when the check runs, then it fails and names both. Given the same four-digit number in two different kinds (for example exploration `0005` and spec `0005`), it passes.
- **AC47 — Undated files warn.** Given a new-style artefact whose `Created:` line is missing or malformed, when the check runs, then it prints a warning naming that file, and the warning alone does not make the check fail.
- **AC48 — This repo passes.** Given this repository's tree after the change, when the check runs, then it passes.

### Docs, checks, release
- **AC49 — No prompt or doc counts.** Given `agents/`, `skills/ai-layout/templates/ai-factory/tasks/`, `skills/ai-layout/templates/ai-factory/agents/` and `ai-factory/docs/workflow.md`, when they are searched, then none says "next free number" or shows an artefact path as `NNNN-…` or `<NNNN>-…`.
- **AC50 — All checks pass.** Given the plugin after this change, when every `skills/ai-layout/scripts/check-*.sh` (including `check-ids.sh`) and `skills/ai-hooks/fixtures/check-*.sh` runs, then each passes.
- **AC51 — Breaking-change migration note.** Given the CHANGELOG entry and the MR, when they are read, then both mark the change as breaking for adopted repos. The CHANGELOG's migration note:
  - describes the new ID format;
  - says legacy files stay valid;
  - describes the `/fc:state` `number` → `id` rename;
  - names the `ids-check` make target and the optional `ai-factory/ids-deny.txt`.
  The MR links a before/after run.

### Several specs from one parent
- **AC52 — A later spec from an already-used parent draws a fresh ID.** Given spec `ai-factory/specs/KXT204-first.md` already reuses exploration (or analysis) `KXT204`'s ID, when the specifier creates a second spec built on that same exploration (or analysis), then it does not stop or report the existing spec. It creates the new spec with a freshly drawn new-style ID (no `--id`), exactly as for a legacy parent (AC23), and the new spec's body cites the parent's path `ai-factory/explorations/KXT204-…` (or `ai-factory/analyses/KXT204-…`). Both specs remain, and the ID check (AC42) passes.

## Sequencing

This spec ships first. Afterwards, separately and not as criteria of this spec:
- **Spec 0022 (`/fc:loop`)** is amended so that `/fc:loop <id>` accepts new-style IDs (case-insensitive) as well as legacy numbers.
- **Spec 0023 (risk agent)** is amended so that a risk file for a spec or plan is created with `ids.js new risk <slug> --id <spec ID>`, and a change assessment gets its own ID from `ids.js new risk <slug>`. Its AC9 is dropped. For a reassessment (0023 AC15/AC16), the agent calls the helper, gets the non-zero exit with the existing path (AC17 here), and appends to that path. The amendment also has to settle how a change assessment is found again for the same target once its file name no longer comes from the branch slug.

## Out of scope

- Renaming, renumbering or re-heading any existing artefact (AC27).
- A `/fc:doctor` or `/fc:sync-sdlc` check, and any CI wiring added by adoption.
- The contract delivery ID (`d-YYYYMMDD-<hex>`), step IDs (`S1`…), criterion IDs (`AC1`…) and quick-check IDs (`QC1`…). They are unchanged.
- `ai-factory/quick/<slug>.md`, which carries no number.
- Editing specs 0022 and 0023 (see *Sequencing*).

## Open questions

None. Every question from the four interview rounds and the follow-up is resolved in the criteria above.

## Data touched

No application data. The changes are to workspace artefact names and contents and to fields read from them:
- File names `<ID>-<slug>.md` in `ai-factory/specs/`, `plans/` (including `done/`), `explorations/`, `analyses/`, `designs/`, `adr/` and `risks/`.
- New artefacts, ADRs included, carry `# <ID> — <Title>` and `Created: <ISO timestamp>` as their first two lines. ADRs are copied from the template, keeping its `Date:` line below them.
- A new optional `ai-factory/ids-deny.txt` (one triple per line; blank lines and `#` comments allowed).
- `/fc:state` rows: the `number` field is renamed `id`, and `--spec <number>` becomes `--spec <id>`.
- The ADR `Status: superseded by <ID>` line.
- The spec content digest in `make/contracts.js` excludes the `Created:` line. Sidecar fields are unchanged.

## Routes touched

There are no web routes. The behaviour of `/fc:spec`, `/fc:plan`, `/fc:explore`, `/fc:analyse`, `/fc:design`, `/fc:adr`, `/fc:state` (`--spec`, `--next`, listings, row shape) and `/fc:continue` changes, as do their Codex skills and headless `make ai TASK=…`. There are new entry points: `node ai-factory/make/ids.js new <kind> <slug> [--id <ID>] [--title "<Title>"]` and the `ids-check` make target.

## Components likely involved

- New `skills/ai-layout/templates/ai-factory/make/ids.js` (generator, built-in denylist, `new`, the check). `make/ai.mk` gains the `ids-check` target. Manifest and sync wiring ships both to adopted repos.
- New `skills/ai-layout/scripts/check-ids.sh`, in this repo's check suite.
- Agents: `agents/specifier.md`, `planner.md`, `explorer.md`, `analyst.md`, `architect.md`, and their copies under `skills/ai-layout/templates/ai-factory/agents/`.
- Tasks: `skills/ai-layout/templates/ai-factory/tasks/spec.md`, `plan.md`, `explore.md`, `analyse.md`, `design.md`, `adr.md`. The generated `commands/*.md` and `codex-skills/` wrappers are regenerated from them.
- `skills/ai-layout/templates/ai-factory/adr/0000-template.md` (`# NNNN — Title`).
- `skills/ai-layout/templates/ai-factory/make/contracts.js`: the `/^(\d{4})-/` plan-to-spec fallback around line 1333, and the spec `contentDigest` excluding `Created:`.
- `skills/ai-layout/templates/ai-factory/make/continue.js`, `delivery-status.js` and `delivery-report.js`. Their path patterns already accept alphanumerics, so they need verifying.
- `skills/ai-layout/scripts/state.sh`:
  - `number_of` (four-digit `sed` pattern) and the `--spec` normalisation (`printf '%04d'`);
  - case-insensitive matching;
  - the `number` → `id` rename and the usage messages;
  - listing order, and the `--next` tie-break (the `sort -k5,5` field).
  `commands/state.md` describes the row shape.
- `skills/ai-layout/scripts/check-state.sh`, `check-paths.sh` and `check-contracts.sh` (fixtures and expectations).
- `ai-factory/docs/workflow.md` (the artefact table), and `ai-factory/AGENTS.md` and its template if they mention numbering or the checks.
- CHANGELOG (breaking change and migration note) and the MR with a before/after run.
- Edit the canonical targets only, never the `ai-factory/tasks/`, `ai-factory/agents/` or `ai-factory/make/` symlinks.
