## Usage

Run `/fc:quick` for a small, well-understood local change with an understood result. No spec, plan
or delegated agent is needed. It:

1. Checks scope. When requirements are uncertain, or the change affects authorization, public
   contracts, migrations, dependencies or service ownership, it names the decision that needs the
   normal workflow. File count alone does not decide risk.
2. Writes a short acceptance checklist.
3. Implements the change with meaningful regression coverage. For a bug, it shows the failing case
   first.
4. Runs the affected checks, and the full required suite once at completion.
5. Self-reviews the actual local diff and labels it a self-review. It never implies the review was
   independent.

It reports the acceptance result, the files changed, the verification actually performed and any
unresolved concern.

See also: [Quick change](../workflows/quick.md#steps) and
[workflow.md: workspace defaults and small changes](../../ai-factory/docs/workflow.md#workspace-defaults-and-small-changes).

## Examples

```
/fc:quick show the export button only when the report has rows; hidden for an empty report
/fc:quick fix the typo in the settings page title: "Prefrences" should read "Preferences"
```

## Writes

- Source and test files for the change.
- With artifact contracts enabled, also the checklist as `ai-factory/quick/<slug>.md`, with
  `QC1…` items, its `.contract.json` from `contracts.js init quick`, and the evidence from
  `make -f ai-factory/make/ai.mk verify DELIVERY=<id>`.
- Without contracts, the checklist stays in the conversation.

## Refuses or asks

- With no argument, it asks for the change and the expected result, and stops.
- When the change is out of scope for this route, it keeps the current work and names the decision.
  A workflow you chose explicitly is respected.
- It adds no unrelated cleanup and no new dependency. It never weakens a test to pass. A failed or
  unavailable required check is reported as unverified, never as complete.
- When the effective `review_independence` is `independent` (`standard`, `strict`), its self-review
  never satisfies review. Only `make -f ai-factory/make/ai.mk review DELIVERY=<id>` records it.
- When the repo has no `ai-factory/` workspace, it reports that it needs `/fc:adopt-sdlc`.
