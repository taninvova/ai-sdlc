# ASD-003 — User docs
Created: 2026-10-30T14:59:39.953Z

Target: spec ai-factory/specs/ASD-003-user-docs.md

## Categories assessed
- authorization: assessed
- data exposure: assessed
- secrets: assessed
- injection: assessed
- dependency/supply chain: assessed (no package manifest or lockfile in the repo; AC5 requires Node built-ins only, so no audit tool was run)
- migrations: assessed
- rollback: assessed
- blast radius: assessed

## Findings

| id | category | severity | status | evidence path | mitigation |
|---|---|---|---|---|---|
| R1 | blast radius | major | open | ai-factory/specs/ASD-003-user-docs.md (AC19, Open question 9); docs/choosing-a-workflow.md:41-46 | Inference, not verified: Mermaid's default `securityLevel: strict` disables `click`, and GitLab renders Mermaid in a sandboxed iframe, so `click` links may not navigate there, and a relative target would resolve against the iframe, not the page. Before planning, push one diagram to a branch on the `repository` host and try it. If it fails, answer Open question 9 in the spec (drop the `click` lines, or add a plain link list under each diagram) and reword AC19 so it can be met. |
| R2 | rollback | major | open | docs/commands.md:1-30 (untracked; hand-written "What it does" and "Writes" columns and the group table); git status shows `?? docs/` | The generator overwrites `docs/commands.md`, and none of `docs/` is in Git, so the first run destroys the hand-written draft with no copy to restore. Commit the draft (or copy it to the plan's working notes) before the first `sync-docs.js` run, and move the content the generator does not produce, such as the Writes column, into `docs/commands/_notes/` or the generator's template. |
| R3 | blast radius | major | open | ai-factory/specs/ASD-003-user-docs.md (AC6, AC11, Open question 2) | AC6 implies removing pages for commands that no longer exist. Limit any delete to regular `*.md` files directly in `docs/commands/`. Never recurse, and never touch `docs/commands/_notes/`, which holds the 25 hand-kept notes that make up most of the effort. Add a test in which an orphan page is removed and `_notes/` is left byte-identical. |
| R4 | blast radius | major | open | skills/ai-layout/scripts/sync-claude-commands.js:38-39; ai-factory/specs/ASD-003-user-docs.md (Open question 2) | `commands/*.md` ships to every plugin user. If `sync-claude-commands.js` or `sync-codex-skills.js` moves to the new shared reader, a parse difference (the current regex matches `description:` anywhere in the file, not only in frontmatter; quoting; trailing whitespace) changes shipped output. Either keep them on their current parsing in this change, or prove the outputs are byte-identical with both scripts' `--check` before and after the switch. |
| R5 | rollback | major | open | ai-factory/docs/definition-of-done.md:10; skills/ai-layout/scripts/check-versions.sh; ai-factory/specs/ASD-003-user-docs.md (AC16, Open question 6) | AC16 ties `docs/README.md` to `.claude-plugin/plugin.json`'s version, but neither the release step in the definition of done nor `check-versions.sh` names `docs/README.md`. The first release after this change then breaks `--check`, and the checks loop too if it is wired in (Open question 3). Add `docs/README.md` to the release step in the definition of done, or have `check-versions.sh` read the header, and fix the header's exact form (Open question 6). |
| R6 | blast radius | minor | open | ai-factory/AGENTS.md ("Checks (all of them)" runs only `check-*.sh`); repo root has no CI file | No CI file exists at the repo root, so the only gate is the local checks loop. If `--check` is not wired into it (Open question 3), generated pages drift silently from `commands/*.md`, which is itself generated from the task templates. Add a `check-docs.sh` wrapper so the existing loop runs it. |
| R7 | migrations | minor | open | skills/ai-layout/scripts/check-paths.sh (scan set includes `README.md`; pattern `docs\/workflow`) | `check-paths.sh` scans `README.md` and flags `docs/workflow` after any character other than `[-[:alnum:]_.]`. The current link `docs/README.md` passes, but a later README link to `docs/workflows/…` would fail AC22. Keep `README.md` linking only `docs/README.md`, or resolve Open question 11 before adding more links. |
| R8 | injection | minor | open | ai-factory/specs/ASD-003-user-docs.md (AC15) | The link check resolves relative paths from repo-owned markdown and only tests whether they exist. A `../` link that leaves the repo can resolve on one machine and not on another. Inference: there is no execution path, so this is a correctness risk, not a security one. Resolve links against the repo root, and fail any link whose resolved path is outside the repo. |
| R9 | data exposure | minor | open | docs/installation.md:22; .claude-plugin/plugin.json (`repository`) | The docs name the host `github.com` and a personal namespace. It is already public in the plugin manifest and `check-paths.sh`, so this adds no new exposure. If `docs/` is ever published more widely (out of scope here), review the host references first. |

## Residual risks
- AC19 depends on GitLab's rendering behaviour, which this repo cannot control. Even after R1 is verified, a later GitLab or Mermaid upgrade can break `click` links with no local check noticing.
- Notes completeness (AC9) is judged by a person unless Open question 5 adds a structural check, so the four required parts can erode over time.
- Authorization and secrets: no finding. The change reads repo-owned markdown and `plugin.json` (`version`, `repository`), writes only under `docs/`, and handles no credential.
- Outside the target, noted and not assessed: the working tree has `ai-factory/models.yaml` changed from a symlink into the templates to a regular file (`git status`: ` T ai-factory/models.yaml`). That conflicts with AGENTS.md's rule that this repo's layout is a symlink into the templates. It needs attention before an ASD-003 commit picks it up.
