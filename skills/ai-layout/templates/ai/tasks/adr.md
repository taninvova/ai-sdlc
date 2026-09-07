---
description: Record one architectural decision as an ADR in docs/adr/
---
Every rule that says "no new dependency without an ADR" is served by this task. Use it for a
decision that outlives the change that prompted it: a dependency, a boundary, a protocol, a
storage choice, a convention the whole repo must follow.

Delegate to the `architect` subagent in its `adr` mode. It writes
`docs/adr/<NNNN>-<slug>.md` from `docs/adr/0000-template.md` — Context, Decision,
Consequences, with the date and a Status.

If the decision came from a design document, name that file so the ADR links to it. If the
input carries more than one decision, the architect writes one ADR per decision and says so.
If it supersedes an earlier ADR, the architect names it and updates that file's Status line.

Do not change any code in this task. Report the file path, the decision in one sentence, and
the cost it names in Consequences.

Decision: $ARGUMENTS
