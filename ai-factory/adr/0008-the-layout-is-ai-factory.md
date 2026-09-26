# 0008 — The layout directory is ai-factory/, and every loop artefact lives in it

Date: 2026-09-25 · Status: accepted

## Context
The layout shipped as `ai/`, with two of the loop's own directories outside it: `specs/` at the
repo root and ADRs in `docs/adr/`. Nothing chose that split — it is the order the pieces were
added in. The cost is paid three times over: an adopting repo gains three top-level entries
instead of one, a reviewer cannot tell at a glance what belongs to the operating model, and a
bare `ai/` says nothing about what it holds to anyone who did not install the plugin.

`ai/` is also a poor name in a workspace that already has directories called `ai`, and it
collides conceptually with source directories (`src/ai/`) in exactly the repos most likely to
adopt this.

## Decision
The layout directory is `ai-factory/`, and everything the loop reads or writes lives in it:

```
ai-factory/AGENTS.md  docs/  tasks/  agents/  make/  models.yaml  runs/
ai-factory/specs/   was specs/
ai-factory/adr/     was docs/adr/
ai-factory/docs/workflow.md   was docs/workflow.md
```

Only three paths stay at the repo root, because the tools look for them there: `AGENTS.md`,
`CLAUDE.md` and `Makefile`. An adopted repo therefore gains exactly one directory.

Two things are transitional. They do not expire together, because removing them fails in
different ways:

1. **The hooks accept either name.** `_common.js` prefers `ai-factory/` and falls back to `ai/`.
   A repo that takes the plugin update before running the migration would otherwise lose its
   dont-touch guard and its run log with no error at all — the worst failure a rename can have,
   because nothing looks wrong. The prompts get no such fallback: they name the new paths only,
   and a prompt pointed at a missing directory fails in front of the person who can fix it.
2. **`/t4:migrate-layout`.** The move an adopted repo makes, once, when it takes the update.

**The command goes in 1.1.0. The fallback waits for 2.0.0.** Dropping the command is harmless: a
repo that still needs it can run the script from an older checkout, and its absence is a missing
slash command, which is loud. Dropping the fallback disarms the dont-touch guard and stops the run
log in any repo that never migrated, with no error — the exact failure this ADR added the fallback
to prevent. Doing that in a minor release would be the silent break we refused at the start, so it
waits for a major, where a reader expects to check what was removed.

## The exception this decision makes, and its bounds
`/t4:sync-sdlc` holds that taking an upstream change is a separate, reviewable edit, and ADR 0002
holds that ai-sdlc never reaches into a repo. The migration rewrites path strings in a repo's own
prompts, which brushes against the first of those. It is allowed, bounded as follows:

- **Path strings only.** No new prompt text, no reworded rule, no template content. Asserted, not
  promised: `check-migrate.sh` compares every changed file against `rewrite(old)` and fails on any
  other difference.
- **Reported as its own list**, apart from the moves, so it can be reviewed and reverted alone.
- **Never automatic.** No hook, no task and neither `/t4:adopt-sdlc` nor `/t4:sync-sdlc` invokes it.

The reason for the exception is that the alternative is worse: a move without the rewrite leaves
every prompt in the repo pointing at a directory that no longer exists.

## Consequences
Breaking for every adopted repo. Each runs `/t4:migrate-layout` itself; ai-sdlc keeps no list of
adopters and cannot know which have (ADR 0002). Until a repo runs it, its hooks work and its
prompts do not.

The migration should be committed as two commits — the moves, then the rewrite — and the command
stages the moves and leaves the rewrite unstaged so that order is the easy one to follow.

How much this matters depends on how much of each file the rewrite changes, and the first version of
this ADR overstated it. Git pairs a rename by similarity, so a file where the path lines are most of
the content — a short task prompt, a one-line context doc, a stub — falls below the 50% threshold
when the move and the rewrite land together, and `git log --follow` then stops at the migration.
A file of ordinary length survives a single commit: measured on this repo's own release, which
GitLab squashed into one commit, every real content file kept its history and only the symlinks lost
theirs, and they were unpairable either way because their target string changed completely.

Two commits are still the instruction, because they make the outcome independent of file size
instead of leaving each file to its own similarity score. But a repo that ends up with one commit —
a squash merge, most likely — has not necessarily lost anything, and should check rather than assume.

Paths this plugin cannot see do not get fixed: CI jobs, pipeline config and tooling in an adopted
repo that name `ai/`. The 1.0.0 release note says to grep for them.

`check-paths.sh` now guards the rename: no prompt, agent, skill, command or context doc may name a
pre-1.0.0 path. Records are exempt — specs, plans, designs, analyses, ADRs and the CHANGELOG say
what was true when they were written, including this ADR, which cannot state the decision without
naming the old path.
