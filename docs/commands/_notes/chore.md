## Usage

Run `/fc:chore` for small maintenance with no behaviour change: a version bump, a rename, a config
tidy. It makes the change with the smallest diff and runs the affected checks, and the full required
suite once at completion. It reports the files changed and anything that should become a spec or an
ADR.

With `ai-factory/assurance.json`, it first shows the preset and its effective requirements. Under
`standard` or `strict`, the acceptance checklist is recorded as a quick delivery, so that review and
completion have a delivery ID.

See also: [Chore workflow](../workflows/chore.md#steps) and
[workflow.md §5](../../ai-factory/docs/workflow.md#5-every-command).

## Examples

```
/fc:chore bump the node version to 22 in .nvmrc and CI
/fc:chore rename the reportUtils module to report-format
```

## Writes

- Source and test files for the change.
- Under the `standard` or `strict` assurance preset, also the checklist as a quick delivery,
  `ai-factory/quick/<slug>.md`, and its verification evidence.

## Refuses or asks

- With no argument, it asks what to change and stops. It never goes looking for something that
  seems untidy.
- It changes no behaviour beyond the request. Prose-only changes get document checks, not invented
  runtime tests.
- Under a preset that requires independent review, its own self-review never counts. Only
  `make -f ai-factory/make/ai.mk review DELIVERY=<id>` records independent review.
- When the repo has no `ai-factory/` workspace, it reports that it needs `/fc:adopt-sdlc`.
