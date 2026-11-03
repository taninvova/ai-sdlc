# ASD-004 — Command shortcuts /fc:ba and /fc:scout
Created: 2026-10-30T19:10:10.913Z

## Request
Add two first-class shortcut commands: `/fc:ba`, which runs the `analyse` task, and `/fc:scout`, which runs the `explore` task. On Codex they would be `$fc-ba` and `$fc-scout`. Unlike `/fc:check`, they are not deprecated. Each one runs the same task as its target, with the same input, the same model routing (`models.js dispatch --task <target>`), the same run-log label and the same agent, and adds no deprecation line. The developer wrote "fc:analyze". The real command is `/fc:analyse` (British spelling), so this exploration treats the request as `/fc:ba` → `/fc:analyse` (see Open questions).

## What exists today
- **The one alias table is a deprecation table.** `TASK_ALIASES = { check: "review" }` and `canonicalTask()` are in `skills/ai-layout/templates/ai-factory/make/models.js:18-26`. `aliasNotice()` (`models.js:396`) throws for any name that is not in the table, and its text always says "is deprecated".
- **Generators.** `skills/ai-layout/scripts/sync-claude-commands.js` and `sync-codex-skills.js` emit `commands/check.md` and `codex-skills/fc-check/` with the description "Deprecated — use /fc:review" and the `aliasNotice` preamble. Both refuse a task file whose name is an alias. For adopted repos, the template's `make/sync-adapters.js:217-230` emits a project Codex skill `.codex/skills/fc-check/` with the same deprecated text. Claude needs no such skill because the plugin command is native.
- **Readers of the table.** The headless runner (`make/runner.js:285-289`) canonicalises `TASK` and prints "TASK=check is deprecated" for every alias. The parser (`models.js:155-165`) reads an alias key in `models.yaml` `routing.tasks` as its target and pushes it to `routing.aliased`. Doctor (`models.js:717`) reports each such key as "uses the deprecated name". `make/cost.js:189` and `make/lifecycle.js:79,380` group data under the canonical name.
- **Hook.** `skills/ai-hooks/scripts/log-task.js:35` keeps its own copy, `ALIASES = { check: "review" }`, because a hook cannot load templates. `skills/ai-hooks/fixtures/check-codex.sh:64-67` asserts that this copy equals `TASK_ALIASES` exactly. Without a mapping, `/fc:ba` would write `ba` to `.task.<session>`, and `make cost` would show it as a separate task.
- **Checks.** `check-adapters.sh:41-55` counts project Codex skills as tasks plus aliases and greps for "is deprecated in favour of". `check-start-routing.sh:86-101` requires every routed entry whose name differs from its task to carry `aliasNotice`. `check-interactive-model-routing.sh:161-180` and `check-doctor.sh` / `check-workspace.sh` reference `check`.
- **Unaffected.** `/fc:start` returns canonical names from `START_TASKS` (`models.js:15`), so shortcuts never reach its classifier output.
- **Docs.** `ai-factory/docs/architecture.md:56` ("Owns the deprecated task names … the one table"), `README.md:46,177` and `CHANGELOG.md:184` document the table.
- **In-flight work.** ASD-003 (`ai-factory/specs/ASD-003-user-docs.md`) generates docs from `commands/*.md` and fixes the count at 25: AC12, AC15 (one notes file per command), AC38 (the `workflow.md` counts) and AC44 (5.0.1). Two new command files raise the count to 27 and need two notes files. Opinion: give them the reduced `check.md`-style notes.

## Options
**A. Plugin entry points only, with no template change.** Add a plugin-side `SHORTCUTS = { ba: "analyse", scout: "explore" }` table to the two generators. They would emit `commands/ba.md`, `commands/scout.md`, `codex-skills/fc-ba/` and `codex-skills/fc-scout/` with the target's own description and preamble and no notice. `log-task.js` would gain the two mappings, and `check-codex.sh` would compare the hook against `TASK_ALIASES` ∪ `SHORTCUTS`. Changes: 2 generators, 4 generated entries, the hook, check-codex.sh, check-start-routing.sh, README and CHANGELOG. Effort **L**: size L (more than 5 files), uncertainty S. Risks: `make ai TASK=ba` fails because no such task exists, so the parity is partial. `routing.tasks.ba` in `models.yaml` is not read as `analyse`. A second alias table outside `models.js` contradicts the "one table" line in architecture.md. Project Codex adapters get no `fc-ba` skill (the plugin's skill covers Codex users with the plugin installed). Easier later: non-breaking, so it can ship as 5.1.0 with no adopter sync. Harder later: two tables to reconcile once shortcuts need headless support. Needs no ADR.

**B. One alias table with a kind: deprecated or shortcut.** Make the `models.js` table carry both kinds. For example, keep `TASK_ALIASES` and add `TASK_SHORTCUTS = { ba: "analyse", scout: "explore" }`. `canonicalTask()` would resolve both, and a `deprecatedName()` predicate would gate `aliasNotice`. Generators and `sync-adapters.js` would emit shortcuts with the target's own description, without the notice. The runner warns only for deprecated names. The parser accepts a shortcut key, and doctor treats it as a duplicate when both names are mapped but does not call it deprecated. The hook table gains the two entries, and check-codex.sh compares it against the union. Changes: `models.js`, `runner.js`, `sync-adapters.js`, both generators, `log-task.js`, 4 check scripts, generated entries, architecture.md, README and CHANGELOG. Effort **L**: size L (more than 5 files across template, hook and checks), uncertainty M (doctor and duplicate-key semantics for shortcut keys need deciding). Risks: it is a template change, so CHANGELOG must say breaking. An adopted repo keeps working without a sync, because plugin commands dispatch the canonical task, but `TASK=ba` and the project `$fc-ba` arrive only after `/fc:sync-sdlc`. Easier later: adding a shortcut is one table line with full parity. Needs no ADR (it extends an existing table).

**C. Shortcuts declared in task frontmatter.** Add an `aliases: ba` key to `templates/ai-factory/tasks/analyse.md`, with `scout` on `explore.md`. Generators, `sync-adapters.js` and `canonicalTask()` would read the key from the workspace's task files. The hook would read `ai-factory/tasks/*.md` at prompt time instead of keeping a pinned copy. Changes: as in B, plus a frontmatter reader in `models.js` and in the hook, and the two task templates. Effort **XL**: size L, uncertainty XL (it is a new pattern: an adopted repo could declare its own shortcuts and collide with plugin commands, and the hook does filesystem work on every prompt). Risks: plugin command names would come from adopter data, but plugin `commands/` are generated in this repo, so adopter-declared shortcuts would get project Codex skills but no Claude command. ASD-003 lists new task frontmatter keys as out of scope. Easier later: shortcuts per repo. Harder later: it is a second source of command names. Probably needs an ADR.

## Comparison
| Option | Effort | Risk | Reversibility | Fits architecture.md | Recommendation |
|---|---|---|---|---|---|
| A. Plugin-only entry points | L | Low; partial parity | High (delete 4 entries and 1 table) | Partly: a second alias table | No |
| B. One table, two kinds | L | Medium; template change | Medium (adopters synced) | Yes: extends "the one table" | **Yes** |
| C. Task frontmatter | XL | High; new pattern, hook I/O | Low | No: names leave models.js | No |

## Recommendation
**B.** Opinion: "first-class" means a shortcut behaves like its target everywhere a task name is accepted: slash command, Codex skill, `TASK=`, `routing.tasks`, run-log and cost grouping. B gets that from the existing single table and its existing readers, and keeps architecture.md's "one table" true. The template change is additive, and repos that have not synced degrade gracefully. Ship it on its own branch off `main` as a minor release, 5.1.0, after ASD-003's 5.0.1 has merged. Rebasing then adds two notes files and moves the ASD-003 counts from 25 to 27.
What would change my mind: if the developer wants shortcuts in interactive sessions only, with no `TASK=ba` and no routing key, A gives that and is not breaking.

### Effort and risk
Effort **L**: size L (more than 5 files across `models.js`, `runner.js`, `sync-adapters.js`, two generators, the hook and four check scripts), uncertainty M (doctor and duplicate-key wording for shortcut keys).
- Uncertain requirements — **present**: "analyze" vs `analyse`, and whether headless and routing parity are in scope, are unanswered.
- Authorization — absent: there is no permission or access change; the shortcuts dispatch the same tasks.
- Public contracts — **present**: new `/fc:` and `$fc-` names, new `TASK=` values and `routing.tasks` keys, and a template change for every adopted repo.
- Migrations — absent: recorded data keeps canonical names, and nothing is rewritten.
- Dependencies — absent: no npm package; stdlib only.
- Service ownership — absent: one plugin repo, no other service.

Present: uncertain requirements and public contracts. Run `/fc:risk` once the spec exists.

## Open questions
1. Should `/fc:analyze` (American spelling) also exist, as a third shortcut or as a deprecated alias, or is `/fc:ba` enough?
2. Is headless parity required (`make ai TASK=ba`, `routing.tasks.ba`), or are interactive entry points enough? The answer decides between A and B.
3. When `models.yaml` maps a shortcut key (`routing.tasks.scout`), should doctor say nothing, give an "ok, read as explore" note, or raise a finding that asks for the canonical key?
4. Should the slash-menu description of a shortcut be the target's description verbatim, or prefixed with something like "Shortcut for /fc:analyse —"?
5. Release ordering: confirm that this ships as 5.1.0 after ASD-003's 5.0.1, with ASD-003's counts (25 → 27, notes files) updated on rebase rather than in ASD-003 itself.

## Next
`/fc:spec ai-factory/explorations/ASD-004-command-shortcuts.md option B`
