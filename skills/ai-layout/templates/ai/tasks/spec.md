---
description: Draft a feature spec with Given/When/Then acceptance criteria
argument-hint: <feature request>
---
Read ai/AGENTS.md and ai/docs/architecture.md. If ai/explorations/ has a file for this feature, read it and build the spec on the chosen option. Look at specs/ for the next number.

Where the request comes from. If `ai/docs/tracker.md` exists AND this repo is configured as
that file defines AND the whole argument is a key in the form it gives, follow that file to
resolve the key, and spec what it returns. If it does not resolve, stop and ask — never spec
the key itself. If one spec already records that key, report its path and stop; if two do,
report both and stop. In every other case — not configured, no such file, or an argument that
is not wholly a key — the argument IS the request, exactly as typed, and no key is resolved.
When this repo is not configured, say nothing about keys, configuration or that file in what
you report: describe the spec exactly as you would have before this paragraph existed. A repo
that has configured nothing must not learn from your report that the mechanism is there.

Write specs/<NNNN>-<slug>.md with:
- Title, one-line summary
- `Ticket: <key>` alone on the next line, and only when a key was resolved
- User story: as a … I want … so that …
- Acceptance criteria as Given/When/Then, each independently testable, numbered AC1…
  From a resolved key, take these from the description it returned and from nothing else.
  What the description leaves implicit — an unnamed actor, an unstated error case, a threshold
  with no number — goes under Open questions. Never write it as a criterion: an inferred
  criterion gets tested and reviewed by people who do not know it was never agreed.
- Out of scope
- Open questions — a spec with open questions is not buildable; list them for the developer
- Data touched (models, fields) · Routes touched · Components likely involved
Do not write code. Do not write the plan. Report the file path and the open questions.

If nothing follows the command name, ask the user which feature to specify, and stop. Do not invent one, and do not take it from the branch name.

Feature: $ARGUMENTS
