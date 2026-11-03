## Usage

Run it when you come back to a repo and want to know what is left. With no argument it lists the outstanding specs and plans, each outstanding plan with its incomplete steps, as one table. It reads the files on disk, so the answer is the same twice running and the same headless. It is read-only and asks nothing.

| Argument | Lists |
|---|---|
| none | everything outstanding |
| `--done` | what is finished instead (a plan with withdrawn steps shows as `closed`, not `complete`) |
| `--next` | the single item to pick up next |
| `--specs` / `--plans` | only that kind of row |
| `--spec <id>` | one spec with its plans, finished and outstanding rows together |
| `--delivery <id>` | one contract delivery's status as a field/value table |

A row whose state is `unknown` is one the script could not read; its reason is kept beside it.

See also: [Feature workflow: what is left](../workflows/feature.md#fcstate-what-is-left), [workflow.md: Delivery status](../../ai-factory/docs/workflow.md#delivery-status).

## Examples

```
/fc:state
/fc:state --next
/fc:state --done --plans
/fc:state --spec PMB-003
/fc:state --delivery d-20261030-a1b2c3
```

## Writes

Nothing: terminal output only. It edits no file, ticks no box, moves no plan to `done/`, and starts no step, test, review or agent.

## Refuses or asks

It never asks. Each refusal is one line, and that line is the answer:

- `--done` with `--next`.
- `--specs` with `--plans`, a second `--spec`, or `--spec` with no ID.
- `--delivery` with `--done`, `--next` or a filter, with no ID, or given twice.
- A flag it does not take: named back with the ones it does take.
- With no `ai-factory/` layout, nothing to list; under `--delivery`, a missing delivery-status helper is answered with `/fc:sync-sdlc` guidance.
