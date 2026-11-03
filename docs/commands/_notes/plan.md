## Usage

Run `/fc:plan` with a spec's path once its open questions are answered. The `planner` subagent
reads the spec, `ai-factory/AGENTS.md`, `ai-factory/docs/architecture.md`,
`ai-factory/docs/coding-standards.md` and the relevant `ai-factory/skills/`. It writes one plan with:

- the goal and a `**Spec:**` line naming the spec;
- the files to create or change, with one line on why for each;
- ordered `- [ ] Step N — …` checkboxes, each small enough for one [`/fc:run`](run.md);
- the tests that prove each step and its verification phase (`red`, `step` or `final`);
- the risks and how each is checked;
- the exact verification commands.

Each step's indented body carries one `Effort: … · Estimate: …` line. A step may also carry
`Depends on: N, M`; a step without that line waits for every earlier step. This is what lets
[`/fc:loop`](loop.md) run independent steps in parallel.

See also: [Feature workflow: Plan](../workflows/feature.md#5-plan) and
[workflow.md §4](../../ai-factory/docs/workflow.md#4-the-main-loop).

## Examples

```
/fc:plan ai-factory/specs/PMB-003-csv-export.md
/fc:plan --task-model=opus -- ai-factory/specs/PMB-003-csv-export.md
```

## Writes

- `ai-factory/plans/<ID>-*.md`, with the spec's ID. The file is created with
  `node ai-factory/make/ids.js new plan <slug> --id <spec ID>`.
- With artifact contracts enabled, also the plan's `.contract.json` beside it, from
  `contracts.js init plan`. The planner fixes every diagnostic it reports (an acceptance criterion
  no step covers, an unknown criterion, a step with no verification command, no `final` check) and
  reruns it until the plan is valid.

It changes no code.

## Refuses or asks

- With no argument, it asks which spec to plan and stops. When `ai-factory/specs/` holds several
  specs it lists their paths; it never assumes the newest.
- When the spec already has a plan (the ID helper exits 3), it reports the existing plan's path and
  writes nothing.
- When the planner returns a question instead of a file, it asks you that question and stops.
  Headless, it reports the question, says nothing was written, and stops.
- When the spec still has open questions, the planner plans what the criteria allow and names each
  question as an ambiguity in its report.
- When the repo has no `ai-factory/` workspace, it reports that it needs `/fc:adopt-sdlc`.
