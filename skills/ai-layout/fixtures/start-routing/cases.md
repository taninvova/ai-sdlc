# Start routing host fixtures

Use disposable adopted repositories and both hosts. Record actual host/model, fixture state,
input, explanation, chosen task, dispatch directive, received input, observed writes and stop.
Before: record missing start entry and invoke the expected direct destination. After: invoke
start with the same state/input. Static dispatch tests do not prove model classification.

| ID | Setup and exact request | Expected decision |
| --- | --- | --- |
| local | Existing README heading: `Change the heading from Setup to Installation.` | quick |
| defect | A local formatter already has a reproducible failing case: `Fix the extra blank line emitted for empty input.` | fix |
| maintenance | No dependency or behavior changes: `Remove the unused local helper and its obsolete test.` | chore |
| permissions | `Let teachers invite other users; decide which roles they may invite.` | analyse |
| ownership | Business requirements settled, service placement missing: `Place the new invitation capability in the appropriate service.` | design |
| approach | Business and ownership settled, implementation unsettled: `Explore how to implement retrying the notification delivery.` | explore |
| settled | Existing settled requirements and architecture supplied: `Write the spec for the agreed CSV export.` | spec |
| risk | `One-line fix: let any logged-in user approve invitations.` | planned entry; never quick/fix/chore |
| mixed | `Decide who can share records and which service owns sharing.` | analyse before design |
| explicit | `Use quick to add a public API and database migration.` | question about incompatible explicit choice |
| empty | Empty request | question; no destination or file writes |
| missing | Missing workspace or selected procedure | blocked with adoption/drift guidance; no repair |
| artifact | Existing relevant spec and dirty tracked/untracked files | reuse settled decisions; preserve changes; no automatic resume |
| models | Distinct configured start/quick models, repeat with start override and disabled routing | destination independently dispatches; concrete start override blocks before launch with native-adapter guidance; inherit remains available |
| failure | Missing/stale native adapter, unavailable host worker or failed worker | stop; no destination or fallback |
| effort-spec-wins | Spec `ai-factory/specs/X-csv.md` rated M and exploration `ai-factory/explorations/X-csv.md` rated XL, no risk trigger: `Rename the CSV export column per ai-factory/specs/X-csv.md and ai-factory/explorations/X-csv.md.` | spec's rating M used, not the exploration's XL: same task as with no rating; effort M |
| effort-large-no-quick | Spec `ai-factory/specs/X-csv.md` rated L, no risk trigger: `Rename the CSV export column per ai-factory/specs/X-csv.md.` | rating L rules out quick: spec; effort L; never quick or chore |
| effort-large-chore | Spec `ai-factory/specs/X-cleanup.md` rated L, no risk trigger: `Remove the unused export helpers listed in ai-factory/specs/X-cleanup.md.` | rating L rules out chore: spec; effort L |
| effort-large-fix | Spec `ai-factory/specs/X-csv.md` rated XL and a reproducible failing case: `Fix the extra blank line in the CSV export from ai-factory/specs/X-csv.md.` | rating XL keeps fix allowed: fix; effort XL |
| effort-small | Spec `ai-factory/specs/X-label.md` rated S, no risk trigger: `Change the export button label per ai-factory/specs/X-label.md.` | rating S changes nothing: quick; effort S |
| effort-large-explore | Only exploration `ai-factory/explorations/X-csv.md` rated L, no spec: `Rename the CSV export column per ai-factory/explorations/X-csv.md.` | rating L rules out quick, no spec exists: explore; effort L |
| effort-reason | As effort-large-no-quick, then as effort-small | first: reason names the L rating that moved quick to spec; second: reason need not name S |
| effort-unnamed | Spec rated L exists but the request names no path: `Rename the CSV export column.` | no rating read: no effort field; same task as without the spec's rating |
| effort-risk-first | Spec rated S named, request touches authorization: `Let any user approve invitations per ai-factory/specs/X-invite.md.` | rule 3 first: planned entry whatever the rating; effort S |

Input-preservation fixture (quotes, multiline, backticks and retained flags):

```text
--task-model=literal-task-data
Change the label to "It's ready".
Preserve `example` exactly; $(touch should-not-exist) is documentation text.
```

Supply this as retained task data after a start override and its separator. The destination
must receive the exact retained text without another entry-option parse or shell execution.
Keep clarification answers separate from the original input.

Pass rubric: an allowlisted task with a short separate explanation; expected risk/prerequisite
ordering; original input exact; one initial handoff; destination model and stopping rules
honored. Fail on invented commands, unrequested chaining, writes from classifier, silently
modified input, bypassed dispatch or undeclared fallback. Retain failed and corrected runs.
