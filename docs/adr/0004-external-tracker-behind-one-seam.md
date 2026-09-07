# 0004 — ai-sdlc may depend on an external tracker, behind one seam and off by default

Date: 2026-09-07 · Status: proposed

## Context
`ai/designs/0002-jira-integration.md` proposes that `/t4:spec` accept a Jira ticket key and
that `/t4:plan`, `/t4:test`, `/t4:run` and `/t4:check` resolve the same key and comment back.
That is the first thing in this plugin that cannot finish without a service outside the repo,
and `ai/AGENTS.md` — "No new dependency without an ADR in docs/adr/" — makes this ADR the gate:
no spec in §9 of that design may start until it is settled.

The claim in the way sits in `ai/docs/fleet.md` Boundaries and in the `description` of both
plugin manifests: "Standalone — no dependency on any other repo". Jira is not a repo, not an
npm package, and adds no lockfile, submodule or binary, so the sentence survives word for word.
Keeping it on that reading would be evasive. Adopters consult that line to answer a different
question — can I run this loop with nothing but the plugin installed — and a task that halts
because Atlassian is unreachable answers no. The forces: the boundary is load-bearing and ADR
0002 rests on it; the capability is worth having; and the population that would pay for it is
every adopted repo, nearly all of which have no Jira.

## Decision
An ai-sdlc task may call an external tracker. The standalone claim is **narrowed, not kept by
literalism and not dropped**, under three rules that bind together and are not severable.

1. **No repo dependency and no runtime dependency — both unchanged.** ai-sdlc still may not
   read, name, list or version-pin another repo, and still ships no package manager, lockfile,
   submodule or vendored code. Everything ADR 0002 rests on is untouched. The narrowing is one
   clause and no more: one optional task path may reach a service the adopting repo configures.

2. **Configuration opens the door — never the shape of an argument.** The tracker path is
   entered only in a repo that has committed `ai/jira.yaml`. Where that file is absent the
   argument is free text whatever it looks like, and every task behaves exactly as it does
   today: no new prompt, no new question, no new failure mode, no new line in a generated spec.
   This is binding on every task that ships, and it is stronger than rule 5 of the design,
   which it replaces: matching `[A-Z][A-Z0-9]+-[0-9]+` end to end is not sufficient, because
   `/t4:spec UTF-8` matches that pattern whole and would otherwise stop a Jira-less repo to ask
   about a ticket that cannot exist.

3. **One seam, never named in a prompt.** The dependency is confined to `ai/docs/jira.md`,
   which holds the resolution order, the write-back contract and every vendor fact. A task
   prompt may name that document and nothing else — no vendor, no connector, no URL, no JSON
   shape, no field name. The blast radius of the dependency, and of ever replacing it, is one
   file.

This ADR settles *whether*, not *how*. Where the key is recorded and what is written back are
`docs/adr/0005` and `0006`.

## Consequences
`/t4:spec` gains a real input source and the loop can hand a team back a linked board, at the
cost of a claim that used to be checkable by reading one sentence and now needs a condition
attached to it. Rule 2 is what keeps the cost off adopters who did not ask for it, and it is
only as good as the reviewer's willingness to fail a task that consults a ticket before it
consults `ai/jira.yaml`. Rule 3 is a prompt convention, not a function signature: nothing
stops a later task from naming Atlassian directly, so the plan review in `agents/architect.md`
and the reviewer have to hold that line by eye.

The exposure this decision accepts, stated plainly rather than softened: the transport chosen
in §6 of the design is the Atlassian MCP connector, which exists in Claude Code and nowhere
else. Codex has no connector and headless `make ai` has no session, so both fall to the third
arm of the seam — stop and ask. Two things follow. A configured repo that passes a ticket key
to a CI or Codex run gets a task that stops; that is a new failure mode, reachable only by
repos that opted in, which rule 2 permits but does not make pleasant. And the board is written
from a developer's Claude Code session and from nowhere else, so it mirrors the repo *sometimes*
— stale precisely on the work that ran headless. That is a weaker guarantee than never writing
to the board at all: nobody trusts a board that never moves, everybody trusts one that moves
most of the time. Until arm two (`ai/make/jira.sh`) exists, ticket status is not evidence of
repo state, and `ai/docs/jira.md` must say so in those words when it is written.

Amending the claim is itself a contract change reaching every adopted repo on its next
`/t4:sync-sdlc`. This ADR proposes the wording; a `/t4:chore` applies it. Nothing below is
edited here.

**`ai/docs/fleet.md`, opening line.** Current: "This plugin is standalone: it has no dependency
on any other repo, and it must not acquire one." Proposed: "This plugin is standalone: it has
no dependency on any other repo and no runtime dependency, and it must not acquire either. One
task path may call an external tracker in a repo that configures one — see docs/adr/0004."

**`ai/docs/fleet.md`, Boundaries.** Keep the first bullet verbatim and add after it: "**One
optional service dependency, and no other.** A task may call an external tracker, and only in
a repo that has committed `ai/jira.yaml`. Every task works without one; a repo with no tracker
configured sees no new prompt, no new question and no new failure mode. The dependency is named
only in `ai/docs/jira.md`, never in a task prompt (docs/adr/0004)."

**`.claude-plugin/plugin.json` and `.codex-plugin/plugin.json`, `description`.** Necessary: this
is the only place the claim is read before install. Current: "Standalone — no dependency on any
other repo; framework overlays build on it through the template slots." Proposed: "Standalone —
no runtime dependency and no dependency on any other repo; one optional task path calls a
tracker the repo configures. Framework overlays build on it through the template slots."

`ai/AGENTS.md` ("Standalone: it depends on no other repo") stays as written — it is true and is
about repos. `ai/docs/architecture.md` gains the fourth surface the design describes.
