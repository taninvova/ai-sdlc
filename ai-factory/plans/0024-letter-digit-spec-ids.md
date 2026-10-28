# Letter-and-digit artefact IDs

**Goal:** New `ai-factory/` artefacts get a random, collision-checked `[A-Z]{3}[0-9]{3}` ID. A single helper creates each one and a clash check runs across clones. Every reader accepts both the new IDs and the legacy four-digit numbers, and no existing file is renamed.

**Spec:** `ai-factory/specs/0024-letter-digit-spec-ids.md`. This plan keeps the legacy number `0024`, as AC27 and Round 2 decision 12 require.

## Design

- **One helper owns the ID format:** `skills/ai-layout/templates/ai-factory/make/ids.js` (CommonJS, stdlib only, no new dependency).
  - `new <kind> <slug> [--id <ID>] [--title "<Title>"]` creates an artefact; `check` runs the clash check.
  - Kinds map to directories: `spec→specs/`, `plan→plans/` (also reads `plans/done/`), `exploration→explorations/`, `analysis→analyses/`, `design→designs/`, `adr→adr/`, `risk→risks/`. A missing kind directory is created.
  - The workspace root is resolved from the entry path (`process.argv[1]`), as in `assurance.js`, so this repo's `ai-factory/make/ids.js` symlink works.
- **Drawing an ID.**
  - Letters come from `A–H J–N P–Z` and digits from `crypto.randomInt`. Nothing is counted (AC6).
  - Rejected: a first pair `AC` or `QC`, anything matching `^S[0-9]+$`, `\bAC[0-9]+\b` or `\bQC[0-9]+\b`, a triple on the built-in denylist or in `ai-factory/ids-deny.txt` (matched case-insensitively), and an ID that any entry name in the seven directories already uses, compared case-insensitively.
  - The draw scans every file name, sidecars included. The clash check counts only `.md` files.
- **Exclusive creation without slug races (AC13, AC14, AC17).** O_EXCL on `<ID>-<slug>.md` alone cannot stop two sessions using one ID with two different slugs. So the helper works in this order:
  1. It reserves the ID with an exclusive create under `ai-factory/runs/tmp/ids/`. The key is `<ID>` for a fresh draw, and `<kind>-<ID>` for a reuse.
  2. While it holds the reservation, it rescans for the ID.
  3. It creates the target with `safe-files.js` `write(..., { exclusive: true })`.
  4. It releases the reservation in a `finally`.

  A busy or used ID leads to a redraw. A reuse waits briefly, then reclaims a reservation older than a fixed age, or else refuses. A stale fresh reservation only takes that one ID out of use. `runs/tmp/` is already gitignored.
- **Test seam:** module exports only. The exports are `draw`, `create` and `check`, with an injectable random source, clock and pre-open callback. Behaviour never changes through environment variables or hidden CLI flags.
- **File content (AC8–AC10).**
  - A non-ADR file is exactly `# <ID> — <Title>\nCreated: <new Date().toISOString()>\n`.
  - An ADR is a copy of `ai-factory/adr/0000-template.md`: its first `# ` line is replaced, `Created:` is inserted after it, and everything else is copied byte for byte.
  - In this repo the template is read through a symlink; that read must tolerate it. Writes still go through the `safe-files.js` boundary.
  - The slug must match `^[a-z0-9]+(-[a-z0-9]+)*$`. A title with a newline is refused.
- **Exit and output contract:**

  | Exit | Meaning | Output |
  |---|---|---|
  | 0 | Created | the repository-relative path on stdout |
  | 2 | Refused: usage, bad slug or title, missing parent, or reuse not allowed for this kind | one line on stderr |
  | 3 | The target kind already has this ID (AC17) | the existing path on stdout, a message on stderr |
  | 1 | Runtime failure | stderr |

  Exit 3 lets the specifier tell AC52's "the parent's ID is already taken" apart from a real error.
- **Reuse (`--id`).**
  - `spec` needs an exploration or an analysis with that ID. `plan` and `risk` need a spec.
  - `design`, `adr`, `exploration` and `analysis` are refused.
  - The ID is matched case-insensitively and written uppercase.
  - A four-digit `--id` is accepted for `plan` and `risk` when a legacy spec with that number exists, and refused for `spec` (see Ambiguity 1).
- **Clash check (`ids.js check`).**
  - It reads the `.md` files of the seven kinds, with `plans/` and `plans/done/` counted as one kind.
  - **New-style IDs fail when:**
    - two files of one kind share an ID;
    - a group sharing an ID includes a design or an ADR;
    - a group holds kinds other than one spec, plus at most one of exploration or analysis, a plan and a risk. Exploration plus analysis fails, and so does a plan or risk with no spec.
  - **Legacy numbers** fail only on a same-kind duplicate. `0000-template.md` and `0000-scaffold.md` are ordinary legacy files.
  - **Undated new-style files.** A file whose line 2 is missing or is not `Created: YYYY-MM-DDTHH:MM:SS(.fff)?Z` gets a warning on stderr. A warning alone never fails the check.
  - It exits 0 on a pass and 1 on a failure, naming every path involved.
- **Ordering inside `state.sh`.** `Created:` is read from line 2 only, which is the same rule the check uses.
  - Listing order: within each directory the rows already sort by path. The plan replaces that filename sort with three bands:
    1. legacy files by number;
    2. dated new-style files by `Created:`, then by ID;
    3. undated new-style files by ID.

    Path and then step number break the remaining ties. The directory grouping stays (see Ambiguity 2), and a tree holding only legacy files lists its rows in the same order as today.
  - `--next`: the primary key is unchanged. Field 5 of the tie-break becomes a rank:
    1. dated new-style files by `Created:`, then by ID;
    2. undated new-style files by ID;
    3. legacy files by number.
- **Contracts.**
  - The spec's `contentDigest` replaces the value on line 2 when that line starts with `Created:`. The `Created:` token stays, so deleting the line still counts as drift, while editing its value does not.
  - Legacy specs, with no such line, keep a byte-identical digest, so no sidecar drifts after an upgrade.
  - The plan digest is unchanged.
  - The migrate fallback matches `^([0-9]{4}|[A-Za-z]{3}[0-9]{3})-` and compares IDs case-insensitively.

## Files

- Create `skills/ai-layout/templates/ai-factory/make/ids.js`: the generator, the built-in denylist, `new`, reuse and `check`. Adoption copies it to every repo, and the manifest tracks it.
- Create `skills/ai-layout/scripts/check-ids.sh`: groups `draw`, `new`, `reuse`, `check`, `state`, `procedures`, `docs` and `repo`. The default runs all of them, and `repo` is the clash check of this repo (AC42, AC48). Fixtures are built under `ai-factory/runs/tmp/`.
- Modify `skills/ai-layout/templates/ai-factory/make/ai.mk`: add the `ids-check` target (`node ai-factory/make/ids.js check`) and `.PHONY` (AC42).
- Modify `skills/ai-layout/templates/ai-factory/make/contracts.js`: `Created:` is left out of the spec digest (AC26), and the migrate fallback pairs by ID (AC32).
- Verify `continue.js`, `delivery-status.js` and `delivery-report.js` against new-style names (AC33). Their patterns already accept alphanumerics, so edit them only if a fixture shows otherwise.
- Modify `skills/ai-layout/scripts/state.sh`, which changes:
  - `number_of` becomes `id_of` (both forms, output uppercase);
  - `--spec` normalisation, made case-insensitive;
  - the plan→spec fallback glob, made case-insensitive;
  - the header field `number` becomes `id`;
  - the usage and refusal messages;
  - the listing sort key;
  - the `--next` tie rank and its reason wording.
- Modify `skills/ai-layout/scripts/check-state.sh`: the golden headers become `id`, and the `--spec` refusal wording expectations are updated. Legacy rows and order stay the same.
- Modify `skills/ai-layout/scripts/check-delivery-status.sh`: `LISTING_HEADER` uses `id`. Add a new-style-ID delivery case for AC33.
- Modify `skills/ai-layout/scripts/check-contracts.sh`: add cases for AC26 and AC32.
- Modify `skills/ai-layout/scripts/check-continuation.sh`: add a `selector` case for AC33 using new-style file names.
- Modify `skills/ai-layout/scripts/check-manifest.sh` and `check-workspace.sh`: adoption must deliver and track `ai-factory/make/ids.js`.
- Modify `commands/state.md`: the field becomes `id`, the flag becomes `--spec <id>`, and the description changes (AC34, AC35). Regenerate `codex-skills/fc-state/SKILL.md`.
- Modify the agents `agents/specifier.md`, `planner.md`, `explorer.md`, `analyst.md` and `architect.md`. Each creates its file through `ids.js` and writes below the helper's two lines. The planner passes `--id`. The specifier gets the parent rules (AC21–AC23, AC52). The architect sets `superseded by <ID>` and fills in the ADR's `Date:` (AC20, AC25). Regenerate `skills/ai-layout/templates/ai-factory/agents/*.md` with `materialize-agents.js`.
- Modify the tasks `skills/ai-layout/templates/ai-factory/tasks/spec.md`, `plan.md`, `explore.md`, `analyse.md`, `design.md` and `adr.md`: drop `<NNNN>` and the counting, and name the helper. Regenerate `commands/*.md` and `codex-skills/` with the sync scripts.
- Modify `skills/ai-layout/templates/ai-factory/adr/0000-template.md`: the heading becomes `# <ID> — Title`, with no `NNNN` and no `{{…}}` (AC25).
- Modify `ai-factory/docs/workflow.md`: the artefact table shows `<ID>-*.md`, and `--spec <id>` replaces `--spec <number>` (AC49).
- Modify `README.md`, `FACTORY.md`, `skills/ai-layout/SKILL.md` and `ai-factory/docs/architecture.md`: replace `--spec <number>`, list `ids.js` and the optional `ai-factory/ids-deny.txt`, and record that the ID format is owned in one place.
- Modify `CHANGELOG.md`: add an **Unreleased, breaking for adopted repos** block with the AC51 migration note.
- Create, in this repo only, the link `ai-factory/make/ids.js`, generated by `node skills/ai-layout/scripts/sync-self.js`. Never write it by hand: `ai-factory/make/` is in `dont-touch.md`.

## Server versus client

N/A. There is no application, UI or service. Local Node and bash helpers own the deterministic behaviour, and prompts tell the agents to call them.

## Steps

- [x] Step 1 — Draw IDs and create fresh artefacts with `ids.js new` (AC1–AC10, AC12–AC14).
  - Write the `draw` and `new` groups of `check-ids.sh` first. Each case reports a missing helper or export as its own failure, never as a crash.
  - Then implement drawing, the denylists, the one ID space, the reservation and exclusive create, the file content, titles and ADR copying.
  - Run `sync-self.js` so `node ai-factory/make/ids.js` works here.
  - Tests:
    - `draw` group:
      - `draw-form` (AC1)
      - `draw-builtin-deny` (AC2): a forced random sequence hits a built-in triple first
      - `draw-repo-deny` (AC3): mixed case and whitespace, and an absent file
      - `deny-hygiene` (AC4): blank lines and `#` lines are silent; `AB`, `ABCD` and `A1C` are each warned about by name, and the file is still created
      - `draw-no-criterion-shape` (AC5)
      - `draw-random` (AC6): 20 draws differ, and the result is the same whatever the artefact count or highest number
      - `draw-one-id-space` (AC12): a used ID in each of the seven directories, `plans/done/` included, forces a redraw
    - `new` group:
      - `new-creates` (AC7): every kind except plan; one file, the printed path, exit 0
      - `new-content` (AC8): exactly two lines, with a valid ISO timestamp
      - `new-title` (AC9)
      - `new-adr-template` (AC10): against the shipped template
      - `new-exclusive` (AC13): the pre-open callback creates the target, the file is not overwritten, and a different file is created
      - `new-parallel` (AC14): eight concurrent wrapper processes forced to the same first draw end with eight distinct IDs and files, each heading holding its own ID
  - Verify (red): `bash skills/ai-layout/scripts/check-ids.sh draw` and `bash skills/ai-layout/scripts/check-ids.sh new`. Every case listed above fails with "make/ids.js does not exist" (or "exports no draw()/create()") once the harness exists. A missing `check-ids.sh` is not red evidence.
  - Verify (step): the same two commands pass; `node --check skills/ai-layout/templates/ai-factory/make/ids.js`; `node skills/ai-layout/scripts/sync-self.js`, then `test -L ai-factory/make/ids.js`.

- [x] Step 2 — Reuse an ID with `--id` (AC15–AC18).
  - Add parent validation, the refused kinds, one file per kind per ID (exit 3 with the existing path) and case-insensitive `--id`.
  - Add four-digit `--id` for `plan` and `risk` when a legacy spec exists, and refuse it for `spec` (Ambiguity 1).
  - Tests, in the `reuse` group:
    - `reuse-permitted-parents` (AC15): spec from an exploration and from an analysis, plan and risk from a spec, and a missing parent named in the message
    - `reuse-refused-kinds` (AC16)
    - `reuse-one-per-kind` (AC17): an active plan and a `plans/done/` plan, a different slug, the existing file unchanged, its path printed, exit 3
    - `reuse-case-insensitive` (AC18)
    - `reuse-legacy-plan`: plan `0010` against a legacy spec `0010`
    - `reuse-parallel`: two concurrent `new plan … --id X` leave exactly one plan; the other exits 3
  - Verify (red): `bash skills/ai-layout/scripts/check-ids.sh reuse`. Every case fails because `--id` is rejected as an unknown flag, or is ignored and a fresh ID drawn.
  - Verify (step): `bash skills/ai-layout/scripts/check-ids.sh reuse`, `bash skills/ai-layout/scripts/check-ids.sh draw` and `bash skills/ai-layout/scripts/check-ids.sh new`.

- [x] Step 3 — The clash check and its two entry points (AC42–AC48).
  - Implement `ids.js check`, the `ai.mk` `ids-check` target and the `repo` group, which runs the check on this repository.
  - Make `check-manifest.sh` and `check-workspace.sh` assert that adoption delivers and tracks `ai-factory/make/ids.js`. Adoption adds no CI file.
  - Tests:
    - `check` group:
      - `check-entry-points` (AC42): `node ai-factory/make/ids.js check` and `make -f ai-factory/make/ai.mk ids-check` give the same exit code and the same named paths over identical fixtures
      - `check-same-kind` (AC43): includes an active plan against a `plans/done/` plan
      - `check-permitted` (AC44): includes exploration `KXT204` plus spec `KXT204` with a cited analysis `MRB517`
      - `check-cross-kind` (AC45): design and spec, ADR and plan, exploration and analysis, plan and risk with no spec
      - `check-legacy` (AC46)
      - `check-undated-warn` (AC47)
    - `repo` group: `repo-passes` (AC48)
  - Verify (red): `bash skills/ai-layout/scripts/check-ids.sh check` and `bash skills/ai-layout/scripts/check-ids.sh repo`. Every case fails because `ids.js` has no `check` subcommand (exit 2 usage) and `ai.mk` has no `ids-check` target.
  - Verify (step):
    - `bash skills/ai-layout/scripts/check-ids.sh check`
    - `bash skills/ai-layout/scripts/check-ids.sh repo`
    - `make -f ai-factory/make/ai.mk ids-check`
    - `bash skills/ai-layout/scripts/check-manifest.sh`
    - `bash skills/ai-layout/scripts/check-workspace.sh`

- [x] Step 4 — Contracts accept new IDs (AC26, AC32, AC33).
  - Leave `Created:` out of the spec digest and pair by ID in migrate, in `contracts.js`.
  - Add the AC33 fixtures: the `planned` contract fixture renamed to `DHW631-csv-export.*` with its `**Spec:**` link updated, then driven through `continue.js` and `state.sh --delivery`.
  - Tests:
    - `check-contracts.sh` cases:
      - `created-outside-digest` (AC26): a changed `Created:` value gives no `S_ARTIFACT_CHANGED`; a deleted `Created:` line, or any other edited line, is reported; a legacy spec's digest equals its pre-change value
      - `migrate-pairs-new-id` (AC32)
    - `check-continuation.sh`: `selector-new-style-ids` (AC33)
    - `check-delivery-status.sh`: `helper-new-style-ids` and `cli-new-style-ids` (AC33)
  - Verify (red): `bash skills/ai-layout/scripts/check-contracts.sh`. `created-outside-digest` fails with drift reported on a `Created:` change, and `migrate-pairs-new-id` fails with "its spec has no sidecar to link to". The AC33 cases are characterisation tests and are expected to pass at once. If one fails, the fix moves into this step.
  - Verify (step):
    - `bash skills/ai-layout/scripts/check-contracts.sh`
    - `bash skills/ai-layout/scripts/check-continuation.sh selector`
    - `bash skills/ai-layout/scripts/check-delivery-status.sh`
    - `bash skills/ai-layout/scripts/check-delivery-report.sh`

- [x] Step 5 — `/fc:state` reads IDs: selection, pairing, the `id` field and messages (AC28–AC31, AC34, AC35).
  - Change `state.sh` as follows:
    - `id_of`;
    - `--spec` accepts a legacy number in every spelling, or a new-style ID, basename or path, in any case;
    - the plan→spec fallback matches case-insensitively;
    - the header says `id`;
    - the messages use `--spec DHW631`, `--spec <id>` and "spec ID".
  - Update the golden headers and the refusal-wording expectations in `check-state.sh`, and the header in `check-delivery-status.sh`. Update `commands/state.md` and regenerate the Codex `fc-state` skill.
  - Tests, in the `state` group of `check-ids.sh`:
    - `state-legacy-unchanged` (AC28): a legacy tree under no flag, `--done`, `--specs` and `--plans` gives the same rows and pairings as before, apart from the header name
    - `state-legacy-spec-forms` (AC29): `0010`, `10`, `0010-fc-state` and the full path
    - `state-spec-case-insensitive` (AC30)
    - `state-pair-by-id` (AC31)
    - `state-id-field` (AC34): the header and `commands/state.md`
    - `state-usage-messages` (AC35)
  - Verify (red): `bash skills/ai-layout/scripts/check-ids.sh state`.
    - `state-spec-case-insensitive` fails with "'DHW631' is not a spec number".
    - `state-pair-by-id` fails because the spec is listed `not-started`.
    - `state-id-field` fails because the header still says `number`.
    - `state-usage-messages` fails because the message cites `--spec 0010`.
    - `state-legacy-unchanged` and `state-legacy-spec-forms` pass as characterisation tests; they compare rows, not the header.
  - Verify (step):
    - `bash skills/ai-layout/scripts/check-ids.sh state`
    - `bash skills/ai-layout/scripts/check-state.sh`
    - `bash skills/ai-layout/scripts/check-delivery-status.sh`
    - `node skills/ai-layout/scripts/sync-codex-skills.js --check`

- [x] Step 6 — `/fc:state` ordering and the `--next` tie-break (AC36–AC41).
  - Change the listing sort key to the three bands within each directory. Change the `--next` rank and its reason wording. Legacy-only ties still say "the lower number decided", and the `check-state.sh` 14d and golden `--next` text are unchanged.
  - Tests, in the `state` group:
    - `state-listing-order` (AC36): a legacy file, dated new-style files whose `Created:` order is the reverse of their alphabetical order, two with equal timestamps, and an undated one that sorts first alphabetically
    - `next-primary-key` (AC37): pinned commit dates and an untracked file
    - `next-tie-new-before-legacy` (AC38)
    - `next-tie-undated-last` (AC39)
    - `next-tie-earliest-created` (AC40)
    - `next-tie-equal-created` (AC41)

    The tie cases use a directory that is not a git root, so every key is equal.
  - Verify (red): `bash skills/ai-layout/scripts/check-ids.sh state`.
    - `state-listing-order` fails because path order puts the alphabetically first new ID before the earlier `Created:` one, and the undated file is not last.
    - `next-tie-new-before-legacy` fails because the legacy `0001` wins on field 5.
    - `next-tie-undated-last` and `next-tie-earliest-created` fail because the alphabetical ID wins.
    - `next-primary-key` and `next-tie-equal-created` pass as characterisation tests.
  - Verify (step): `bash skills/ai-layout/scripts/check-ids.sh state` and `bash skills/ai-layout/scripts/check-state.sh`.

- [x] Step 7 — The prompts and templates call the helper (AC11, AC19–AC23, AC25, AC49, AC52).
  - **Edit the canonical sources:**
    - `agents/*.md` (the five creators);
    - `templates/ai-factory/tasks/{spec,plan,explore,analyse,design,adr}.md`;
    - the ADR template;
    - `ai-factory/docs/workflow.md`.
  - **What the prompts say:**
    - Each prompt calls `node ai-factory/make/ids.js new <kind> <slug> [--title …]`, writes into the printed path, and keeps lines 1–2.
    - The planner passes `--id <spec ID>`. On exit 3 it reports the existing plan path and writes nothing.
    - The specifier:
      - with a new-style exploration, passes `--id <exploration ID>`; otherwise, with a new-style analysis, `--id <analysis ID>`;
      - with both, uses the exploration's ID and cites the analysis;
      - with a legacy parent, draws a fresh ID and cites the parent;
      - on exit 3, draws a fresh ID and cites the parent, without stopping.
    - The architect copies the ADR through the helper, fills in `Date:`, and sets `superseded by <ID>`.
  - **Regenerate:** `materialize-agents.js`, `sync-claude-commands.js`, `sync-codex-skills.js`, and this repo's adapters.
  - **Tests,** in the `procedures` group:
    - `prompts-call-helper` (AC20)
    - `planner-passes-id` (AC19, AC20)
    - `specifier-parent-rules` (AC21–AC23, AC52)
    - `agents-keep-header` (AC11)
    - `adr-template-no-nnnn` (AC25)
    - `no-number-counting` (AC49): it searches `agents/`, the template `tasks/` and `agents/`, and `ai-factory/docs/workflow.md` for "next free number", `NNNN-` and `<NNNN>-`

    These are static. Their behaviour is proved in Step 8.
  - Verify (red): `bash skills/ai-layout/scripts/check-ids.sh procedures`. Every case fails on today's text: "the next free number", `<NNNN>-<slug>`, `# NNNN — Title` and `superseded by NNNN`.
  - Verify (step):
    - `bash skills/ai-layout/scripts/check-ids.sh procedures`
    - `node skills/ai-layout/scripts/materialize-agents.js --check`
    - `node skills/ai-layout/scripts/sync-claude-commands.js --check`
    - `node skills/ai-layout/scripts/sync-codex-skills.js --check`
    - `bash skills/ai-layout/scripts/check-paths.sh`
    - `bash skills/ai-layout/scripts/check-plugin-hosts.sh`
    - `bash ai-factory/make/sync-adapters.sh`, then `git status --short` showing only the expected adapter regeneration

- [x] Step 8 — Docs, migration note, host runs and final verification (AC24, AC27, AC48, AC50, AC51).
  - **Docs:** update README, FACTORY, SKILL.md, `architecture.md` and the CHANGELOG. The CHANGELOG gets an Unreleased block, marked breaking for adopted repos, that covers:
    - the ID format;
    - that legacy files stay valid;
    - the `number` → `id` rename;
    - `make -f ai-factory/make/ai.mk ids-check` and the optional `ai-factory/ids-deny.txt`.
  - **Host runs:** in a scratch adopted repo, run one before/after spec creation on each host: `/fc:spec` on Claude Code, `$fc-spec` on Codex, and `make -f ai-factory/make/ai.mk ai TASK=spec INPUT=…`.
    - Each must show the helper call, a file matching AC1 and AC8, and lines 1–2 unchanged after the agent writes (AC11, AC24).
    - Also run `/fc:plan` on the new spec (AC19), and specs from a new-style exploration, from an exploration plus an analysis, from a legacy exploration, and a second spec from an already-used parent (AC21–AC23, AC52).
    - Link the transcripts in the MR, and mark the MR breaking.
  - **Host runs waived (2026-10-25).** The developer waived the host runs. Skipped:
    - `/fc:spec` on Claude Code;
    - `$fc-spec` on Codex;
    - `make -f ai-factory/make/ai.mk ai TASK=spec INPUT=…`;
    - `/fc:plan` on the new spec;
    - specs from a new-style exploration, from an exploration plus an analysis, and from a legacy exploration, and a second spec from an already-used parent.

    AC11, AC19, AC21, AC22, AC23, AC24 and AC52 are therefore unverified by host transcripts; only the static `procedures` checks cover them. The risk that a headless host refuses the agent's Bash call to `ids.js` stays unproven.
    The ADR-symlink risk was checked in a scratch copy of this repo that kept its symlinks: `node ai-factory/make/ids.js new adr probe` exited 0 and created `ai-factory/adr/CST733-probe.md`, holding `# CST733 — Probe`, then a `Created:` line, then the rest of the template byte for byte. `ids.js check` passed there. The copy was deleted, and no probe ADR is in this repo.
  - **Tests,** in the `docs` group of `check-ids.sh`: `changelog-breaking-note` (AC51, every clause) and `docs-spec-id` (README, FACTORY and workflow show `--spec <id>`).
  - Verify (red): `bash skills/ai-layout/scripts/check-ids.sh docs`. Both cases fail because the CHANGELOG has no IDs entry and the docs still say `--spec <number>`.
  - Verify (final):
    - `for f in skills/ai-hooks/scripts/*.js; do node --check "$f"; done`
    - `node --check skills/ai-layout/templates/ai-factory/make/ids.js`
    - `bash -n skills/ai-layout/templates/ai-factory/make/sync-adapters.sh`
    - `bash -n skills/ai-layout/scripts/check-ids.sh`
    - `node skills/ai-layout/scripts/materialize-agents.js --check`
    - `node skills/ai-layout/scripts/sync-claude-commands.js --check`
    - `node skills/ai-layout/scripts/sync-codex-skills.js --check`
    - `bash skills/ai-layout/scripts/check-ids.sh` (all groups; AC42, AC48)
    - `make -f ai-factory/make/ai.mk ids-check`
    - `make check` (AC50; stops at the first failing script)
    - `git diff --name-status --diff-filter=RMD main -- ai-factory/specs ai-factory/plans ai-factory/explorations ai-factory/analyses ai-factory/designs ai-factory/adr`: the output must be empty (AC27)
    - `node skills/ai-hooks/scripts/session-stop.js < skills/ai-hooks/fixtures/stop.json`

## Risks and how each is checked

- **Same ID, different slugs, at the same moment.** O_EXCL alone misses this. The ID-keyed reservation covers it, and `new-parallel` and `reuse-parallel` exercise it with forced identical draws.
- **A stale reservation after a crash blocks a reuse.** The age-based reclaim handles it. A `reuse` case pre-creates an old reservation.
- **Legacy sidecars drift after the digest change.** `created-outside-digest` asserts that a legacy spec's digest is byte-identical to the pre-change function's.
- **Listing order changes for legacy-only trees.** The `check-state.sh` goldens keep their row order, and only the header changes. `state-legacy-unchanged` covers the rows.
- **`--next` wording breaks `check-state.sh` 14d.** Legacy-only ties keep "the lower number"; the step verification runs `check-state.sh`.
- **The ADR template read fails on this repo's symlink.** `new-adr-template` runs against a fixture copy. A Step 8 host run, or a manual `node ai-factory/make/ids.js new adr probe` in a scratch clone, proves the symlinked case. Delete the probe afterwards: never leave a probe ADR in this repo.
- **Headless hosts may not permit the agent's Bash call to `ids.js`.** This is the same exposure the existing `contracts.js init` and `lifecycle.js` calls have. It is proved only by the Step 8 `make ai TASK=spec` run. A refused call stays a reported failure and is never claimed as a pass.
- **Prompt-only compliance (AC11, AC19, AC21–AC24, AC52).** Static `procedures` cases are not acceptance; the Step 8 transcripts are. If the host runs are waived, the plan records those ACs as unverified.
- **The full suite is red between steps** while later `check-ids.sh` groups are unimplemented. Step checks name their groups, and `make check` is required only at the final phase.
- **The template change breaks every adopted repo.** The CHANGELOG and MR say so (AC51), and `check-manifest.sh` and `check-workspace.sh` prove that adoption delivers `ids.js`.
- **Leaked `{{…}}` placeholders.** The new ADR heading uses `<ID>`, not braces, and `check-workspace.sh` already scans adopted output.

## Ambiguities in the spec

1. **A four-digit `--id`.** AC15 and AC18 describe only new-style IDs. Plans for legacy specs, including the coming plans for 0022 and 0023, still need `new plan <slug> --id 0022`. The plan accepts a four-digit `--id` for `plan` and `risk` against an existing legacy spec, and refuses it for `spec`, consistent with AC23.
2. **AC36 scope.** "All legacy artefacts in ascending number order" could be global, interleaving spec and plan rows. The plan applies the three bands within each directory (`plans/`, `plans/done/`, `specs/`) as today. That keeps legacy listings byte-identical apart from the header, and keeps the `check-state.sh` 14d guard meaningful. Switching to a global order changes one sort key, plus the goldens and 14d.
3. **Valid `Created:`.** "ISO 8601" is not narrowed. The plan treats as valid only the UTC form the helper writes, `YYYY-MM-DDTHH:MM:SS(.fff)?Z`, on line 2. An offset form counts as malformed, sorts as undated, and gets a warning.
4. **The ADR `Date:` line.** AC10 copies it unchanged. In adopted repos it holds the adoption date, and in this repo it holds `{{date}}`. The plan has the architect fill in `Date:` after the helper's lines (AC11 allows this).
5. **Planner on exit 3.** The spec does not say what the planner does when its spec already has a plan. The plan reports the existing path and writes nothing.
6. **Plan or risk sharing an ID with no spec.** AC45 read literally fails it, and the plan follows that reading.
7. **Undecided interface details:**
   - the exit codes (2 and 3) and the slug grammar;
   - the content of the built-in denylist, which the implementer chooses and which `draw-builtin-deny` tests only structurally;
   - the CHANGELOG placement: an Unreleased block inside the top entry, as in earlier deliveries, with no version bump. Whether this ships as 3.0.0 is a release decision.
