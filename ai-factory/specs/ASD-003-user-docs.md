# ASD-003 — User documentation in docs/ with a generated command reference
Created: 2026-10-30T14:53:55.368Z

Finish the user documentation in `docs/`. The hand-written narrative pages are kept and corrected. `docs/commands.md` and one help page per command are generated from `commands/*.md` and task frontmatter, and hand-kept per-command notes are merged into them. A `--check` mode keeps the output, the notes, the links and the version header true. `ai-factory/docs/workflow.md` stays the deep guide.

Parent: ai-factory/explorations/ASD-003-user-docs.md (option B). The developer answered the exploration's open questions 1–5 in an interview. Those answers are folded into the request this spec is built from: `docs/` is the home and `workflow.md` stays the deep guide; full help for all 25 commands; Mermaid `click` links are kept if they work on the GitLab host; a shared frontmatter reader is factored out, but ASD-002 itself is out of scope; a version header is checked against `.claude-plugin/plugin.json`; notes live at `docs/commands/_notes/<name>.md`.
Risk assessment: ai-factory/risks/ASD-003-user-docs.md (R1–R9). In a second interview the developer answered this spec's open questions 1–13 and settled R1–R8; those answers are the criteria below. A third answer accepted R9 (see Out of scope) and set the release to 5.0.1.
Starting point: the untracked draft in `docs/` (11 files) and the uncommitted `README.md` line linking `docs/README.md`.

## User story
As a developer installing or using the `fc` plugin, I want multi-page user documentation with a help page for every `/fc:*` command, kept in step with the commands by a generator and a check, so that I can learn how to install it, pick a workflow and use any command without the docs contradicting the plugin.

## Acceptance criteria
**Baseline**
- **AC1.** Given the ASD-003 feature branch, when its history is read, then a commit made before any build work holds the `docs/` draft and the `README.md` line linking `docs/README.md` exactly as they were before the build started.

**Narrative pages**
- **AC2.** Given the change, when `docs/` is listed, then it contains `README.md`, `installation.md`, `choosing-a-workflow.md`, `how-it-works.md`, `headless-ci.md` and `workflows/feature.md`, `workflows/exploration.md`, `workflows/fix.md`, `workflows/chore.md`, `workflows/quick.md`.
- **AC3.** Given `docs/headless-ci.md`, when it is read, then it documents the `ai-sync` and `lifecycle-export` targets defined in `skills/ai-layout/templates/ai-factory/make/ai.mk`.
- **AC4.** Given `docs/README.md`, when it is read, then its line 3 reads exactly `> For fc ai-sdlc <version>.`, where `<version>` is the `version` in `.claude-plugin/plugin.json`, and the page no longer dates itself "as of the ASD-001 change".
- **AC5.** Given every page under `docs/` other than `docs/README.md`, when it is read, then it carries no `> For fc ai-sdlc` version line.
- **AC6.** Given each narrative page in AC2, when every statement it makes about commands, arguments, paths, files written, `make` targets, options, exit codes and versions is compared line by line with the source it describes, then no statement contradicts that source.
- **AC7.** Given `README.md`, when it is read, then it links to `docs/README.md`, and that line carries the `path-scan-ok` marker.
- **AC8.** Given the change, when `skills/ai-layout/scripts/check-paths.sh` is diffed, then it is unchanged.

**Generated command reference**
- **AC9.** Given `skills/ai-layout/scripts/sync-docs.js` and `skills/ai-layout/scripts/_frontmatter.js`, when their source is read, then each requires only Node built-in modules, apart from `sync-docs.js` requiring `_frontmatter.js`.
- **AC10.** Given `skills/ai-layout/scripts/_frontmatter.js`, when another script requires it, then it returns the frontmatter reader without running `sync-docs.js` or writing any file, and `sync-docs.js` reads frontmatter through it.
- **AC11.** Given the change, when `skills/ai-layout/scripts/sync-claude-commands.js` and `skills/ai-layout/scripts/sync-codex-skills.js` are diffed, then neither has changed, and each one's `--check` exits 0.
- **AC12.** Given the 25 files in `commands/`, when `node skills/ai-layout/scripts/sync-docs.js` runs, then it writes `docs/commands.md` and one `docs/commands/<name>.md` for each of the 25 commands, and no page for a name that has no `commands/<name>.md`.
- **AC13.** Given a generated `docs/commands/<name>.md`, when it is read, then it states the command's `/fc:` name, its Codex name, its description and its arguments as taken from `commands/<name>.md` and, for a project task, the task frontmatter, and whether it is a plugin-level command or a project task.
- **AC14.** Given `docs/commands/_notes/<name>.md`, when `sync-docs.js` runs, then its content appears in the generated `docs/commands/<name>.md`.
- **AC15.** Given the change, when `docs/commands/_notes/` is listed, then it holds one `<name>.md` for each of the 25 commands; each one except `check.md` has the H2 headings `## Usage`, `## Examples`, `## Writes` and `## Refuses or asks`, each followed by non-empty content.
- **AC16.** Given the generated `docs/commands/check.md`, when it is read, then it marks `/fc:check` as deprecated and links to the `/fc:review` page, and `docs/commands/_notes/check.md` has a `## Usage` heading followed by non-empty content.
- **AC17.** Given the baseline draft of `docs/commands.md` (AC1), when the delivered docs are read, then each command's entry in the draft's "Writes" column is stated in that command's `## Writes` notes, and the draft's group table is kept as content under `docs/commands/_notes/` and appears in the generated `docs/commands.md`.
- **AC18.** Given a notes file that links to a section of `ai-factory/docs/workflow.md`, when `sync-docs.js` runs, then the link appears in the generated page; and given a notes file with no such link, when `--check` runs, then its absence causes no failure.
- **AC19.** Given the generated output is current, when `sync-docs.js` runs a second time, then no file under `docs/` changes.
- **AC20.** Given an orphan `docs/commands/<x>.md` for which no `commands/<x>.md` exists, a non-`.md` file directly in `docs/commands/`, and the notes in `docs/commands/_notes/`, when `sync-docs.js` runs, then the orphan page is deleted, the non-`.md` file is kept, and every file in `docs/commands/_notes/` is byte-identical to before; no file outside the top level of `docs/commands/` is deleted.

**Check mode**
- **AC21.** Given generated output that is current, when `node skills/ai-layout/scripts/sync-docs.js --check` runs, then it exits 0 and writes no file.
- **AC22.** Given a `docs/commands.md` or `docs/commands/<name>.md` that differs from what the generator would write, including after a command's description in `commands/<name>.md` is changed, when `--check` runs, then it exits non-zero and names the stale file.
- **AC23.** Given a command in `commands/` with no `docs/commands/_notes/<name>.md`, when `--check` runs, then it exits non-zero and names the command.
- **AC24.** Given a notes file for a command other than `check` that lacks one of `## Usage`, `## Examples`, `## Writes`, `## Refuses or asks`, or has one with no content before the next H2 heading or the end of the file, when `--check` runs, then it exits non-zero and names the file and the heading.
- **AC25.** Given `docs/commands/_notes/check.md` with a non-empty `## Usage` and none of the other three headings, when `--check` runs, then it reports no notes failure for it.
- **AC26.** Given a relative link in a page under `docs/`, including one that leaves `docs/` such as `../CHANGELOG.md`, whose target does not exist, when `--check` runs, then it exits non-zero and names the page and the link.
- **AC27.** Given a relative link in a page under `docs/` whose resolved path is outside the repository root, when `--check` runs, then it exits non-zero and names the page and the link, whether or not the path exists.
- **AC28.** Given a link with a `#fragment` in a page under `docs/`, to the same page or to another markdown file, when `--check` runs, then it exits non-zero, naming the page and the link, if the fragment matches no heading anchor that GitLab generates for the target; and it reports nothing for a fragment that does match, such as `#refuses-or-asks` for `## Refuses or asks`.
- **AC29.** Given a Mermaid `click` line in a page under `docs/` whose target, resolved like an ordinary relative link, does not exist or has a fragment that matches no heading, when `--check` runs, then it exits non-zero and names the page and the target.
- **AC30.** Given a link in the root `README.md` whose target is under `docs/` and does not exist, when `--check` runs, then it exits non-zero and names `README.md` and the link.
- **AC31.** Given a `docs/README.md` whose line 3 is missing, is not in the form `> For fc ai-sdlc <version>.`, or names a version other than `.claude-plugin/plugin.json`'s `version`, when `--check` runs, then it exits non-zero and names what it found and the expected version.
- **AC32.** Given `skills/ai-layout/scripts/check-docs.sh`, when it runs, then it runs `node skills/ai-layout/scripts/sync-docs.js --check` and exits with that command's status, and `ai-factory/AGENTS.md` is unchanged.
- **AC33.** Given the delivered change, when `--check` runs, then it exits 0.

**Version and release**
- **AC34.** Given a `docs/README.md` whose `> For fc ai-sdlc <version>.` line names a version that differs from the plugin manifests, when `bash skills/ai-layout/scripts/check-versions.sh` runs, then it exits non-zero and lists `docs/README.md` with its version among those that disagree.
- **AC35.** Given `ai-factory/docs/definition-of-done.md`, when its release step (item 3) is read, then it names the version line of `docs/README.md` among what a release bumps.

**Mermaid**
- **AC36.** Given the MR, when it is read, then it records a manual spike: the branch on the GitLab host of `.claude-plugin/plugin.json`'s `repository`, the diagram tried, and whether clicking its nodes opened the linked pages.
- **AC37.** Given the spike's recorded result, when the delivered diagrams are read, then either the spike found `click` works and every diagram that had `click` lines in the baseline draft still has them, or the spike found it does not work and no page under `docs/` has a `click` line, every such diagram is kept, and each is followed by a list of links to the pages its `click` lines targeted.

**Deep guide**
- **AC38.** Given `ai-factory/docs/workflow.md`, when it is read, then every statement of the number of `/fc:*` commands says 25, matching the files in `commands/`, and every statement of the number of project task entry points says 18, matching the files in `skills/ai-layout/templates/ai-factory/tasks/`.
- **AC39.** Given the change, when `ai-factory/docs/workflow.md` is read, then it still exists as the full guide and is not reduced to a pointer to `docs/`.

**Delivery**
- **AC40.** Given the change, when every check in `skills/ai-layout/scripts/check-*.sh` and `skills/ai-hooks/fixtures/check-*.sh` runs, then each exits 0.
- **AC41.** Given the change, when `skills/ai-layout/templates/` and the task frontmatter are diffed, then neither has changed.
- **AC42.** Given `CHANGELOG.md`, when its first `## ` heading is read, then it is a `5.0.1` entry above the `5.0.0` entry, and that entry has a "Docs" item for ASD-003 that describes the user documentation and `sync-docs.js` and states that it is not breaking for adopted repos.
- **AC43.** Given the MR, when it is read, then it links a before/after run showing `sync-docs.js --check` exiting non-zero on a stale page and exiting 0 after `sync-docs.js` regenerates it.
- **AC44.** Given the change, when every version field that `skills/ai-layout/scripts/check-versions.sh` reads is inspected (today `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json` and each plugin entry in `.claude-plugin/marketplace.json` and `.agents/plugins/marketplace.json` that carries a version), then each one is `5.0.1`.
- **AC45.** Given the change, when `docs/README.md` is read, then its line 3 reads exactly `> For fc ai-sdlc 5.0.1.`
- **AC46.** Given the change, when `bash skills/ai-layout/scripts/check-versions.sh` and `bash skills/ai-layout/scripts/check-release-docs.sh` each run directly, then each exits 0.

## Out of scope
- ASD-002 (the interactive HTML presentation) and any generator for it; this spec only factors the frontmatter reader so it can be reused.
- Moving `sync-claude-commands.js` or `sync-codex-skills.js` onto `_frontmatter.js` (R4).
- Option C: making `docs/` the only guide, shrinking `workflow.md`, `README.md` or `FACTORY.md`, or moving phrase assertions from the existing checks to `docs/`.
- Shipping `docs/` or `sync-docs.js` to adopted repos; an adopted repo's `ai-factory/` is unchanged.
- New frontmatter keys in the task templates or in `commands/*.md`.
- Changes to `ai-factory/AGENTS.md` or to `check-paths.sh`.
- Translating the docs or publishing them to a site.
- Automated checking of prose accuracy; AC6 is a review, and `--check` covers only output, notes structure, links, anchors and the version line.
- Changing how `docs/installation.md` names the GitLab host. R9 (minor, data exposure; ai-factory/risks/ASD-003-user-docs.md) is accepted: the pages keep naming `github.com` and the namespace as they do. Follow-up, not part of this delivery: review every host reference before `docs/` is published more widely.
- The local `ai-factory/models.yaml` change (a regular file with routing enabled): it stays a local-only change and is excluded from every ASD-003 commit.

## Effort and risk
Effort **L**: size L (a new generator with a check mode, a reader module, a check wrapper, changes to `check-versions.sh` and the definition of done, 25 notes files, 26 generated pages and a line-by-line accuracy pass over 10 narrative pages: well over 5 files and a new check); uncertainty M (known pattern from `sync-claude-commands.js`, with minor unknowns: the GitLab `click` spike's outcome and GitLab's anchor slug rules).
- `dev 16–30 h (assumption: the generator, check, link and anchor checking take 5–8 h, the 25 notes files 6–10 h, the accuracy pass over about 900 lines of narrative 3–6 h, the GitLab spike under 1 h, and the 5.0.1 version bump under 1 h)`
- `/fc:run ~75–180 min (assumption: 5–7 plan steps, with the 25 notes files written in one or two steps and the accuracy pass in one)`

Risk categories:
- Authorization: **absent**. Docs and a local generator; no permission or access path changes.
- Data exposure: **absent**. The pages describe public plugin behaviour; the host already named in `plugin.json` is the one new mention (R9).
- Secrets: **absent**. No credential is read or written; `plugin.json` holds only a version and a repository address.
- Injection: **absent**. The generator reads repo-owned markdown and writes markdown; no shell or eval of its input.
- Dependency/supply chain: **absent**. Node stdlib only; Mermaid is rendered by the host, not installed.
- Migrations: **absent**. No data, layout or template move.
- Rollback: **present**. The first generator run overwrites the untracked draft `docs/commands.md`, and the `docs/README.md` version line joins the release step.
- Blast radius: **present**. The generator deletes stale pages under `docs/commands/`, and `check-versions.sh` gains a file every release must bump; plugin repo only.

`/fc:start` risk triggers:
- Uncertain requirements: **present**. Whether GitLab follows Mermaid `click` links is known only after the spike; AC37 accepts either outcome.
- Authorization: **absent**. No access path changes.
- Public contracts: **absent**. No template or task frontmatter change; the reader is internal to the plugin repo.
- Migrations: **absent**. No data or layout move.
- Dependencies: **absent**. No new package.
- Service ownership: **absent**. Single plugin repo; no fleet boundary.

## Open questions
None. The developer answered every question; R9 is accepted (Out of scope) and the release is 5.0.1 (AC42, AC44–AC46).

## Data touched
- No models or runtime data. Files: `docs/**/*.md` (narrative, generated reference and `_notes/`), `README.md` (one link line with `path-scan-ok`), `ai-factory/docs/workflow.md` (command and task counts), `ai-factory/docs/definition-of-done.md` (release step), `CHANGELOG.md` (new 5.0.1 entry with a Docs item), the version fields in `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, `.claude-plugin/marketplace.json` and `.agents/plugins/marketplace.json` (5.0.0 → 5.0.1).
- Read only: `commands/*.md` frontmatter (`description`, `argument-hint`), task frontmatter under `skills/ai-layout/templates/ai-factory/tasks/`, `.claude-plugin/plugin.json` `version`, `skills/ai-layout/templates/ai-factory/make/ai.mk` targets (for AC3's content), and the sources AC6's review compares against.

## Routes touched
- None. No `/fc:*` command or `make` target changes. New script entry points: `node skills/ai-layout/scripts/sync-docs.js [--check]` and `bash skills/ai-layout/scripts/check-docs.sh`.

## Components likely involved
- New: `skills/ai-layout/scripts/sync-docs.js`, `skills/ai-layout/scripts/_frontmatter.js`, `skills/ai-layout/scripts/check-docs.sh`
- Changed: `skills/ai-layout/scripts/check-versions.sh`, the four plugin manifests (version only), `ai-factory/docs/definition-of-done.md`, `ai-factory/docs/workflow.md`, `README.md`, `CHANGELOG.md`
- `docs/README.md`, `docs/installation.md`, `docs/choosing-a-workflow.md`, `docs/how-it-works.md`, `docs/headless-ci.md`, `docs/workflows/*.md`, `docs/commands.md` (generated), `docs/commands/<name>.md` (generated), `docs/commands/_notes/<name>.md` (25, hand-kept)
- Patterns to follow: `skills/ai-layout/scripts/sync-claude-commands.js`, `skills/ai-layout/scripts/sync-codex-skills.js` (read, not changed)
- Checks that must stay green: `skills/ai-layout/scripts/check-paths.sh` (scans `README.md`), `check-continuation.sh`, `check-effort.sh`, `check-ids.sh`, `check-loop.sh`, `check-risk.sh` (assert phrases in `README.md` and `workflow.md`), `check-release-docs.sh` (top CHANGELOG entry), `check-versions.sh`
