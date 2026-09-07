---
description: Draft a feature spec with Given/When/Then acceptance criteria
argument-hint: <feature request>
---
Read ai/AGENTS.md and ai/docs/architecture.md. If ai/explorations/ has a file for this feature, read it and build the spec on the chosen option. Look at specs/ for the next number.
Write specs/<NNNN>-<slug>.md with:
- Title, one-line summary
- User story: as a … I want … so that …
- Acceptance criteria as Given/When/Then, each independently testable, numbered AC1…
- Out of scope
- Open questions — a spec with open questions is not buildable; list them for the developer
- Data touched (models, fields) · Routes touched · Components likely involved
Do not write code. Do not write the plan. Report the file path and the open questions.

If nothing follows the command name, ask the user which feature to specify, and stop. Do not invent one, and do not take it from the branch name.

Feature: $ARGUMENTS
