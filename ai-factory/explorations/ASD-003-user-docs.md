# ASD-003 — User documentation in the repo: install, usage, workflows, command help
Created: 2026-10-30T14:13:53.285Z

## 1. Request
Ship detailed markdown user documentation inside the plugin repo. It should cover how to install
the `fc` plugin and adopt a repo, how to use it day to day, worked examples of the workflows
(feature, fix, chore, quick, exploration) and help for every `/fc:*` command. The docs are plugin
source, not template payload: an adopted repo's `ai-factory/` is unchanged. An untracked draft of
exactly this already exists in `docs/`, so the real question is how to finish it and how to keep it
true as commands change.

## 2. What exists today
- **The draft in `docs/` (untracked, 11 files, about 1,020 lines).** `README.md` is the index.
  `installation.md`, `choosing-a-workflow.md`, `how-it-works.md`, `headless-ci.md` and
  `commands.md` are the topic pages, and `workflows/{feature,exploration,fix,chore,quick}.md` the
  workflow pages. They use Mermaid diagrams with `click` links. `README.md` has one new line that
  links to it (modified, uncommitted).
  Spot-checked against the source:
  - Correct: the install commands (match `README.md` Install and `.claude-plugin/plugin.json`).
  - Correct: the 25-command count and the descriptions and argument hints in
    `docs/commands.md` (match `commands/*.md` frontmatter).
  - Correct: the `TASK=loop` exit codes (match `PRIORITY` and the usage and invalid codes in
    `make/loop.js`).
  - Gap: `headless-ci.md` leaves out the `ai-sync` and `lifecycle-export` targets that
    `make/ai.mk` defines.
  - Gap: `docs/README.md` dates itself "as of ASD-001" when it could name the 5.0.0 release.
  - Gap: no page gives a command's help in depth (examples, what it refuses, what it asks).
    `commands.md` gives one table row per command.
- **Overlapping prose that is already in the repo.**
  - `ai-factory/docs/workflow.md` (966 lines) is the full user guide. It is not a template (no
    copy under `skills/ai-layout/templates/ai-factory/docs/`), so it is the plugin's own guide, and
    it has drifted. Line 112 says "22 `/fc:*` commands … 16 project task entry points". Line 144
    and `commands/` say 25, and `templates/ai-factory/tasks/` holds 18.
  - `README.md` (322 lines) and `FACTORY.md` (230 lines) repeat the install steps, the command
    list and the chain.
  - `CHANGELOG.md` is the version record.
- **How sync is enforced today.** `sync-claude-commands.js` and `sync-codex-skills.js` in
  `skills/ai-layout/scripts/` generate `commands/` and `codex-skills/` from the task frontmatter,
  and their `--check` mode fails on stale output. `check-continuation.sh` (`docs-boundary`),
  `check-effort.sh`, `check-ids.sh`, `check-loop.sh` and `check-risk.sh` assert specific phrases
  and counts in `README.md` and `workflow.md`. No check reads `docs/`.
  `check-paths.sh` scans `README.md`, and its pattern flags `docs/workflow`. A README link to
  `docs/workflows/…` would therefore fail it unless the line carries `path-scan-ok`.
- **Related.** ASD-002 (untracked) recommends a stdlib generator that builds an HTML presentation
  from the same frontmatter. It cites the 22-versus-25 drift as the reason a check is needed.

## 3. Options
**A — Finish the hand-written draft and add a light consistency check.** Fix the gaps above and
add a "Usage and examples" block per command in `commands.md` or under `docs/commands/`. Add
`check-docs.sh` that checks four things:
- every relative link in `docs/` resolves;
- every `commands/*.md` is named in `docs/commands.md`;
- the stated count equals the number of files in `commands/`;
- every `ai.mk` target is listed in `headless-ci.md`.

Fix `workflow.md:112`.
*Effort L:* size L (a new check); uncertainty S (known pattern).
*Risks:* descriptions and hints are still copied by hand, and the check sees presence, not wording.
*Later:* cheap to change; prose keeps drifting slowly. No ADR.

**B — Generate the command reference, keep the narrative hand-written.** Add
`skills/ai-layout/scripts/sync-docs.js`, Node stdlib only, with `--check` like
`sync-claude-commands.js`. From `commands/*.md` and the task frontmatter it writes:
- `docs/commands.md`;
- one help page per command, `docs/commands/<name>.md`, with the name, the Codex name, the
  description, the arguments, and whether it is plugin-level or a project task.

Examples, "writes" and "never does" come from a hand-kept supplement (`docs/commands/_notes/` or
one data file) that the generator merges in. The check fails on stale output, on a command with
no notes, and on a broken relative link in `docs/`. The narrative pages stay as they are in the
draft, corrected.
*Effort L:* size L (a generator and a check); uncertainty M (where the supplement lives).
*Risks:* adding frontmatter keys to the task templates instead would be a template change for
every adopted repo, so keep the supplement outside the templates.
*Later:* makes ASD-002 cheaper, because both can share one frontmatter reader. No ADR, no
dependency.

**C — Consolidate into one canonical guide.** Make `docs/` the only user guide. Reduce
`ai-factory/docs/workflow.md`, `README.md` and `FACTORY.md` to short summaries that point to it.
Move the phrase assertions in the five checks above to the `docs/` pages.
*Effort XL:* cross-cutting; it retargets five checks and touches every overlapping file.
*Risks:* weakening a check by mistake while moving it. `commands/doctor.md` links `workflow.md`
sections.
*Later:* one place to edit, ending the triple copy. No ADR, but a CHANGELOG entry.

**D — No `docs/`; extend `ai-factory/docs/workflow.md`.** Fold per-command help and the workflow
examples into the existing guide, which the checks already cover. Delete the draft and revert the
README line.
*Effort M:* 2–3 files; uncertainty S.
*Risks:* a 966-line single file grows further and has no navigable multi-page structure. That
arguably misses "detailed docs".
*Later:* simplest to keep in sync; hardest to read.

## 4. Comparison
| Option | Effort | Risk | Reversibility | Fits architecture.md | Recommendation |
|---|---|---|---|---|---|
| A Hand-written + light check | L | M: wording drifts | High | Yes | Fallback |
| B Generated command reference + check | L | L | High: delete script and output | Yes: same pattern as `sync-claude-commands.js`, stdlib only | **Yes** |
| C Consolidate into `docs/` | XL | M–H: moving check assertions | Low | Yes | Later, if the triple copy hurts |
| D Extend workflow.md only | M | L | High | Yes | No: not the docs set asked for |

## 5. Recommendation
**Option B** *(opinion)*. Command help is the part that drifts: `workflow.md` already contradicts
itself on the command count. B keeps that part true by construction, using a pattern the repo
already enforces. It also keeps the draft's narrative pages, which spot-check as mostly accurate,
so the existing work is not thrown away. Fix the draft's gaps and `workflow.md:112` in the same
change.
*What would change my mind:* if the developer wants only one user guide, choose C. If per-command
examples are not wanted beyond the table, choose A.

### Effort and risk
Effort **L**: size L (a new generator, a new check, more than 5 files), uncertainty M.
- Uncertain requirements: **present**. How deep "command help" goes, and whether the docs also
  ship to adopted repos, are not stated.
- Authorization: **absent**. Docs only; no permission or access path changes.
- Public contracts: **absent**. No template or task frontmatter changes, as long as the
  supplement stays outside `skills/ai-layout/templates/`.
- Migrations: **absent**. No data or layout move.
- Dependencies: **absent**. Node stdlib; Mermaid is rendered by the host, not installed.
- Service ownership: **absent**. Single plugin repo; no fleet boundary.

Uncertain requirements is present, so run `/fc:risk` on the spec once it exists.

## 6. Open questions
1. Is `docs/` the long-term home, with `workflow.md` kept as the deep guide? Or should C follow
   later?
2. Per-command help depth: examples and failure modes for all 25 commands, or only the 18 project
   tasks?
3. Should one generator also feed ASD-002's HTML, or should the two stay separate?
4. Do the `click` links in the Mermaid diagrams need to work on the GitLab host? GitLab's
   rendering of `click` is unverified here. If not, drop them.
5. Should the docs be versioned (a "for 5.0.0" header that the check compares with
   `plugin.json`)?

## 7. Next
`/fc:spec User documentation in docs/, option B from ai-factory/explorations/ASD-003-user-docs.md: keep and correct the hand-written narrative pages (installation, choosing a workflow, how it works, headless and CI, five workflow pages), generate docs/commands.md and docs/commands/<name>.md from commands/*.md and task frontmatter with a Node-stdlib skills/ai-layout/scripts/sync-docs.js plus a --check that fails on stale output, missing per-command notes or broken relative links, and fix the 22-versus-25 command count in ai-factory/docs/workflow.md`
