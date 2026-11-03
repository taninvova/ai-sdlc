## Usage

Run it once per repo after adoption, then again when a service or contract changes. It fills in `ai-factory/docs/fleet.md`, the service map the architect reads for `/fc:design` and `/fc:adr`. It first detects what the repo tells it (Git remote, manifests, deployables, routes and queue names, config, `CODEOWNERS`), then asks you only for what it could not detect, at most four questions at a time, offering its detected answer as the default. On a filled map it refreshes: it proposes changes, keeps every column and the row order, and records which facts were detected and which you supplied.

Give a focus to refresh one part of the map, or nothing for the whole map. It runs in the current session, never a subagent, because it asks questions.

See also: [workflow.md §2](../../ai-factory/docs/workflow.md#2-set-a-repo-up-once-per-repo).

## Examples

```
/fc:fleet
/fc:fleet the billing service and the queues it consumes
```

## Writes

`ai-factory/docs/fleet.md` only: the service table, Boundaries, Environments and Known gaps. It removes the `Status: unfilled default` line once at least one row is real. It changes no other file.

## Refuses or asks

- Asks you for what it cannot detect: which components are separate services, what data each owns, which contracts are public, the services outside this repo, the boundary rules and the owners.
- Headless (`make ai TASK=fleet`), it asks nothing: it writes what it detected, marks every unknown `TBD` and lists them under Known gaps.
- Never deletes a row it cannot prove is gone: it marks it `unverified`.
- Leaves a section empty rather than inventing it.
