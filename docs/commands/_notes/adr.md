## Usage

Record one architectural decision that outlives the change that prompted it: a dependency, a boundary, a protocol, a storage choice, a convention the whole repo must follow. Every rule that says "no new dependency without an ADR" is served by this command. The `architect` agent writes Context, Decision and Consequences with the date and a Status, and the report names the cost the Consequences section records.

If the decision came from a design document, name that file so the ADR links to it. If the input holds several decisions, it writes one ADR per decision and says so. If it supersedes an earlier ADR, it names it and marks that ADR superseded.

See also: [workflow.md §5](../../ai-factory/docs/workflow.md#5-every-command).

## Examples

```
/fc:adr Use PostgreSQL advisory locks, not Redis, to serialise refund approvals
/fc:adr Adopt the decision in ai-factory/designs/PMB-005-refund-approval.md: billing owns the approval state
```

## Writes

- One new `ai-factory/adr/<ID>-<slug>.md` per decision, created by the ID helper from `ai-factory/adr/0000-template.md`.
- When it supersedes an ADR: that ADR's `Status:` line becomes `superseded by <ID>`.

No code.

## Refuses or asks

- With no input, asks which decision to record, and stops. It never infers one from the diff or the last commit.
- With no ID prefix in the project yet, asks for the project name and a prefix interactively; headless, writes nothing and reports why.
- An accepted ADR is binding: the new ADR never contradicts one. It may only supersede it, and says so explicitly.
