## Usage

Describe the change and the result you expect. `/fc:start` classifies the request and chooses one existing workflow: `quick`, `fix`, `chore`, `analyse`, `design`, `explore` or `spec`. It applies risk before size: uncertain requirements, authorization, public contracts, migrations, dependencies or service ownership always route to planned work, however small the change. It explains the choice in one line, then hands your original request, unchanged, to that one task, which runs to its own normal stopping point. It never implements anything itself and never chains a second phase.

When the request names a spec or exploration that carries an effort rating, an `L` or `XL` rating rules out `quick` and `chore`.

Interactive only: there is no headless `TASK=start`; CI names the destination task directly.

See also: [Choosing a workflow](../choosing-a-workflow.md), [workflow.md §3](../../ai-factory/docs/workflow.md#3-which-command-do-i-want).

## Examples

```
/fc:start Rename the "Save" button on the export dialog to "Export" — the label should change, nothing else
/fc:start CSV export returns an empty file when the filter has no matches; it should return the header row
/fc:start Let team leads approve refunds over 500 EUR — today only admins can
```

## Writes

Nothing itself: the classifier changes no file and returns one JSON result (`route`, `question` or `blocked`), validated by `ai-factory/make/models.js validate-start`. The chosen task then runs and writes its usual output.

## Refuses or asks

- With no request, asks for the change and the expected result, and stops.
- When the intent is ambiguous, or an explicit workflow choice in the request conflicts with the project's requirements, asks the smallest question and resumes with your answer.
- With no `ai-factory/` workspace, says it needs `/fc:adopt-sdlc`; with the start task, `models.js` or its `validate-start` operation missing, reports template drift for `/fc:sync-sdlc`. It never repairs either.
- Rejects a concrete `--task-model=<model>` for start itself; `--task-model=inherit` is accepted.
- A result that fails validation stops with no handoff.
