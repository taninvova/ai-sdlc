---
description: Implement one step of a plan
argument-hint: <plan path> <step>
---
Delegate to the `implementer` subagent: implement ONLY the named step in the named plan.
Read ai-factory/AGENTS.md, applicable coding/protection rules, the plan and its spec. Use the
verification phase and exact commands in the step: `red` requires the documented missing-behavior
failures; `step` requires this step and regressions to pass with only recorded future-step failures
remaining; `final` requires every completion check to pass. Never claim the whole suite green
while expected future failures remain. Add meaningful coverage, preserve user work and tick only
the named step once its phase is satisfied. Missing commands or unexpected failures leave it
unticked. Return files changed, phase/results, and any plan/spec problem. Do not start another step.

If it stopped with an explanation instead of a ticked step, relay the explanation and ask the
developer how to proceed. In a headless run there is nobody to ask: report it and stop.

Do not implement anything yourself in this task, and do not edit any file yourself.

If nothing follows the command name, ask the user which plan and which step, and stop. Name the unticked steps if the plan is obvious — do not start one on your own.

Plan and step: $ARGUMENTS
