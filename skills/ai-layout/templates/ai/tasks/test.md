---
description: Write acceptance tests from the spec's acceptance criteria, independently of the implementation
argument-hint: <spec path> red|gaps
---
Delegate to the `tester` subagent with this instruction: write the acceptance tests for the
spec and plan named below, in the mode named below (`red` before implementation, `gaps`
after). Read the spec's ACs, the plan, and the project's existing tests; read the
implementation's public surface only. Write test files only — never production code.
Return its AC → test table and failure messages unchanged, then add one line: whether the
red tests fail for the right reason, or which ACs are still uncovered.

Do not implement anything in this task, and do not edit any file yourself.

If nothing follows the command name, ask the user which spec and which mode, red or gaps, and stop.

Spec, plan and mode: $ARGUMENTS
