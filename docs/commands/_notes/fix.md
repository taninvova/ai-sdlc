## Usage

Run `/fc:fix` with the bug's symptom and how to reproduce it. It finds the spec that covers the
behaviour, then:

1. Reproduces the bug with a failing test, unit or end-to-end per the project's test setup, before
   changing any code.
2. Fixes it with the smallest change that makes that test pass, with no unrelated refactoring.
3. Runs the affected checks, and the full required suite once at completion.

It reports the root cause, the files changed, and whether the spec was wrong or incomplete.

With `ai-factory/assurance.json`, it first shows the preset and its effective requirements. Under
`standard` or `strict`, the acceptance checklist is recorded as a quick delivery, so that review and
completion have a delivery ID.

See also: [Fix workflow](../workflows/fix.md#steps) and
[workflow.md §5](../../ai-factory/docs/workflow.md#5-every-command).

## Examples

```
/fc:fix CSV export drops the last row when the report has exactly 100 rows; export the March report to reproduce
/fc:fix login returns 500 when the email has a trailing space: POST /login with "a@b.com "
```

## Writes

- A failing test first, then the fix.
- Under the `standard` or `strict` assurance preset, also the checklist as a quick delivery,
  `ai-factory/quick/<slug>.md`, and its verification evidence.

## Refuses or asks

- With no argument, it asks what the bug is and how to reproduce it, and stops. It never goes hunting
  for something that looks broken.
- It never weakens a test to pass. After two attempts at the same failure with no new hypothesis or
  evidence, it keeps the work and reports the blocker.
- Under a preset that requires independent review, its own self-review never counts. Only
  `make -f ai-factory/make/ai.mk review DELIVERY=<id>` records independent review, and it runs that only
  in a session you invoked directly.
- When the repo has no `ai-factory/` workspace, it reports that it needs `/fc:adopt-sdlc`.
