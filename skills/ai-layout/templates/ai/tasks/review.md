---
description: Independent read-only review of the current branch diff
---
Delegate to the `reviewer` subagent with this instruction: review the diff
`git diff $(git merge-base HEAD main 2>/dev/null || git merge-base HEAD develop)...HEAD`
against the spec and plan in flight. Return its JSON verdict unchanged, then add one line:
which findings you agree with and which you would dispute, with a reason.
Do not fix anything in this task.

Context: $ARGUMENTS
