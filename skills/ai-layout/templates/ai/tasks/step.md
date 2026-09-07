---
description: Implement one step of a plan
argument-hint: <plan path> <step>
---
Read ai/AGENTS.md, ai/docs/coding-standards.md, and the plan named below.
Implement ONLY the step named. Do not start the next step.

1. Restate the step; list the files you expect to touch.
2. Implement, following the ai/skills/ that apply to the area.
3. Write or update tests for behaviour you added.
4. Run lint, typecheck and tests. Fix until green. If you cannot, stop and explain.
5. Tick the step's checkbox in the plan file.
6. Report: files changed · tests added · anything the plan or spec got wrong.

If nothing follows the command name, ask the user which plan and which step, and stop. Name the unticked steps if the plan is obvious — do not start one on your own.

Plan and step: $ARGUMENTS
