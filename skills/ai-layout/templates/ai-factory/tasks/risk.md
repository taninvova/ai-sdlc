---
description: Assess one spec, plan or change for security threats and delivery risk — findings with severity, status, evidence and mitigation — recorded in one committed file under ai-factory/risks/
argument-hint: <spec or plan path | working tree | branch | diff path>
---
Delegate to the `risk` subagent with this instruction: assess the target named below for
security threats and delivery risk. Resolve it to exactly one spec, plan, working tree, branch
or diff; create the risk file with the ID helper, or append a Reassessment to the one that
already covers this target, as `ai-factory/agents/risk.md` says, and write only under
`ai-factory/risks/`. Change no code, spec, plan or evidence.
Return its report unchanged: the file path, the target kind and what was assessed, whether the
file was created or appended to, the open blocker and major findings, and any category not
assessed and why.

If it returns a question instead of a file, ask the developer that question and stop. In a
headless run there is nobody to ask: report the question, say nothing was written, and stop.

Use this before /t4:spec or /t4:plan to turn threats into open questions and mitigations, or
before /t4:review on a change. An assessment gates nothing.

Do not assess anything yourself in this task, and do not edit any file yourself.

If nothing follows the command name, ask the user what to assess, and stop. Do not guess the
target from the branch name or the last commit.

Target: $ARGUMENTS
