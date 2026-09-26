---
description: Turn a spec into an ordered implementation plan with checkboxes
argument-hint: <spec path>
---
Delegate to the `planner` subagent with this instruction: turn the spec named below into
ai-factory/plans/<NNNN>-<slug>.md, same number as the spec. Read ai-factory/AGENTS.md, ai-factory/docs/architecture.md,
ai-factory/docs/coding-standards.md, the spec and the relevant ai-factory/skills/; write the goal and spec
link, files to create or modify with one line each on why, server versus client components,
steps as `- [ ] Step N — …` each small enough for one `/t4:run` and naming the tests that prove
it, risks and how each is checked, and the exact verification commands; change no code. Return
its report unchanged: the plan path and anything in the spec that made planning ambiguous.

If it returns a question instead of a file, ask the developer that question and stop. In a
headless run there is nobody to ask: report the question, say nothing was written, and stop.

Do not plan anything yourself in this task, and do not edit any file yourself.

If nothing follows the command name, ask the user which spec to plan, and stop. List the paths in ai-factory/specs/ if there are several — do not assume the newest.

Spec: $ARGUMENTS
