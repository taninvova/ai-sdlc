# ETT683 — Loop halt and commit exceptions
Created: 2026-10-25T15:58:21.150Z

Date: 2026-10-25 · Status: accepted

Spec: [`ai-factory/specs/0022-loop.md`](../specs/0022-loop.md) (AC53) ·
Plan: [`ai-factory/plans/0022-loop.md`](../plans/0022-loop.md) (Step 1) ·
Analysis: [`ai-factory/analyses/0001-root-mode-step-agents-orchestrator-knowledge.md`](../analyses/0001-root-mode-step-agents-orchestrator-knowledge.md)

## Context
Analysis 0001 makes the orchestrator halt at every gate: DEC-003 fixes the halts, BR-010 allows
one plan step per run, FR-026 halts after exactly one step, and FR-027 forbids `git commit`,
`git push` and opening an MR. Those rules keep a human between every step and every commit, but
they make a long plan cost one invocation per step. They also rule out running independent steps
concurrently, because isolating a step in a git worktree and taking back only its own delta needs
commits on that worktree's branch. Spec 0022 asks for one command that runs every unticked step
of a plan, while the developer's branch must still never gain a commit made by the factory.

## Decision
`/t4:loop` is an explicit, opt-in exception to DEC-003, BR-010 and FR-026: one invocation
implements every unticked step of one plan, halting only on a failure, conflict or timeout
and ending with one `/t4:check`. `/t4:run` is unchanged and still halts after one step.
Commits made by the loop on its own temporary worktree branches under
`ai-factory/runs/tmp/worktrees/` (a baseline commit and a step commit per worktree step) are
the only exception to FR-027. Nothing is ever committed on the developer's branch, nothing is
pushed, and no MR is opened; each step's delta is applied back to the main tree uncommitted.

## Consequences
- Easier: a plan with many steps runs in one invocation, and independent steps (`Depends on:`)
  can run concurrently.
- Harder: the developer no longer reviews between steps inside a loop run. A wrong early step is
  built on by later ones and is found only at the final `/t4:check`, so a bad loop run costs more
  to unpick than a bad `/t4:run`. The gate is now opt-in by command choice rather than universal.
- Harder: "the factory never commits" is no longer absolute. Every tool that inspects git state
  must now tell the loop's temporary branches and worktrees apart from the developer's branch:
  `/t4:check`, the guard hook and the repo's test, lint and typecheck tools must skip
  `ai-factory/runs/tmp/worktrees/`, and worktrees kept after a failure, conflict or timeout are
  left for the developer to remove.
- Must now: `docs/workflow.md` and `AGENTS.md` name this exception; `/t4:run` keeps its one-step
  halt; and any further exception to DEC-003, BR-010, FR-026 or FR-027 (an unattended mode, a
  per-run gate flag, a commit on the developer's branch) is a new ADR, not a widening of this one.
