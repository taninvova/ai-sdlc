---
description: Implement one step of a plan
argument-hint: <plan path> <step>
---
Delegate to the `implementer` subagent with this instruction: implement ONLY the step named
below of the plan named below, and never start the next one. Read ai-factory/AGENTS.md,
ai-factory/docs/coding-standards.md, the plan, the spec it names and the ai-factory/skills/ that apply;
restate the step and the files it expects to touch; implement; write or update tests for the
behaviour added; run lint, typecheck and tests until green; tick that step's checkbox in the
plan only when green. If the tests cannot be made green, or the step names tests or a command
that cannot be found or run, stop with the checkbox unticked and explain what was tried.
Return its report unchanged: files changed · tests added · anything the plan or spec got wrong.

If it stopped with an explanation instead of a ticked step, relay the explanation and ask the
developer how to proceed. In a headless run there is nobody to ask: report it and stop.

Do not implement anything yourself in this task, and do not edit any file yourself.

If nothing follows the command name, ask the user which plan and which step, and stop. Name the unticked steps if the plan is obvious — do not start one on your own.

Plan and step: $ARGUMENTS
