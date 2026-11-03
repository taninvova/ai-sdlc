## Usage

Use it when a capability spans services, its home is undecided, or it creates or changes a contract between services. The `architect` agent decides **where** it belongs, what contract it exposes and who owns the data, reading `ai-factory/docs/architecture.md`, `ai-factory/docs/fleet.md` and the accepted ADRs. It ends with the decision in one sentence and the exact `/fc:adr …` and `/fc:spec …` lines to run next. When the home is known, it is one repo and no cross-service contract changes, use `/fc:explore` instead.

`review <plan path>` checks a plan before the code exists: placement, dependency direction, contract changes, new dependencies without an ADR, data ownership and ADR contradictions. It returns the architect's JSON verdict unchanged, plus one line on which findings the session agrees with or disputes.

See also: [Exploration workflow: design](../workflows/exploration.md#design-settle-where-it-lives), [workflow.md §3](../../ai-factory/docs/workflow.md#3-which-command-do-i-want).

## Examples

```
/fc:design Refund approvals: which service owns the approval state, and what event tells billing
/fc:design review ai-factory/plans/PMB-006-refund-approval.md
```

## Writes

- `<capability>`: one new `ai-factory/designs/<ID>-<slug>.md`, created by the ID helper.
- `review`: nothing; a JSON verdict (`approve` or `request_changes` with findings).

Never code, specs, plans or context docs: a change to `architecture.md` is proposed as text in the report.

## Refuses or asks

- With no input, asks which capability to place, and stops.
- If `ai-factory/docs/fleet.md` is missing or still the shipped default, says so first and suggests `/fc:fleet`, then continues and marks what the missing map affected.
- With no ID prefix in the project yet, asks for the project name and a prefix interactively; headless, writes nothing and reports why.
- `review` does not judge correctness, tests, style or security; that is `/fc:review`.
