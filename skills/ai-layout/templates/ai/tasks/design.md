---
description: Decide where a capability belongs across services, what contract it exposes and who owns the data — before any spec
---
Use this when the capability spans services, its home is undecided, or it creates or changes
a contract between services. When the home is known, it is one repo and no cross-service
contract changes, use /ai-explore instead — that decides how to build it, this decides where
it lives.

Delegate to the `architect` subagent.

- Input starting with `review` — run the architect's `review` mode against the plan named
  after it. Return its JSON verdict unchanged, then add one line: which findings you agree
  with and which you would dispute, with a reason. Change nothing.
- Anything else — run the architect's `design` mode on it. Output goes to
  `ai/designs/<NNNN>-<slug>.md` (create the directory if missing).

Do not change any code, spec or plan in this task, and do not edit any file yourself.
If ai/docs/fleet.md is missing or still the shipped default, say so first and suggest
/ai-fleet — then continue without it and mark what the missing map affected.

End with the decision in one sentence and the exact `/ai-adr …` and `/ai-spec …` lines to
run next.

Capability, or `review <plan path>`: $ARGUMENTS
