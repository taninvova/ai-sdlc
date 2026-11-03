<!--
Hand-kept group table for docs/commands.md, read by skills/ai-layout/scripts/sync-docs.js.
Each row is a linked group title, then its backticked command names: the generator takes the group order and
membership from the backticked names, and a command in commands/ that is in no group fails
--check. The table below is rendered into docs/commands.md, so its anchors point at that page's
group headings.

Links in the per-command notes files (docs/commands/_notes/<name>.md) are written relative to
the generated page docs/commands/<name>.md, not to _notes/: write `review.md` for another
command, `../choosing-a-workflow.md` for a narrative page and
`../../ai-factory/docs/workflow.md#5-every-command` for the deep guide.
-->
| Group | Commands |
|---|---|
| [Entry and resume](#entry-and-resume) | `start`, `continue`, `state`, `current` |
| [Setup and maintenance](#setup-and-maintenance) | `adopt-sdlc`, `doctor`, `sync-sdlc`, `fleet`, `setup-tracker`, `setup-knowledge` |
| [Decide before building](#decide-before-building) | `analyse`, `ba` (shortcut), `analyze` (shortcut), `design`, `adr`, `explore`, `scout` (shortcut), `risk` |
| [Specify and plan](#specify-and-plan) | `spec`, `plan` |
| [Build and verify](#build-and-verify) | `test`, `run`, `loop`, `fix`, `chore`, `quick` |
| [Review and hand off](#review-and-hand-off) | `review`, `check` (deprecated), `report` |
