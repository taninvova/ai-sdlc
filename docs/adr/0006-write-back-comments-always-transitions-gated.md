# 0006 — Write-back appends to a ticket always, and moves one only when every runtime can

Date: 2026-09-07 · Status: accepted 2026-09-07

## Context
`ai/designs/0002-jira-integration.md` §6 decides that each task comments the artefact it
produced back to the ticket, and that status transitions ship in the same release but stay
inert unless `ai/jira.yaml` names the workflow states. `docs/adr/0004-external-tracker-behind-one-seam.md`
settles *whether* ai-sdlc may reach a tracker at all and hands *what it writes* here. 0004 is
`proposed`, so nothing below may be implemented before it is accepted, and this ADR is
`proposed` for that reason alone.

Three forces decide this, and they do not point the same way.

**ai-sdlc owns none of a ticket.** The design's own ownership table (§7) says so: comments are
"additive; ai-sdlc owns none of it", status is "opt-in only; the repo names the states; ai-sdlc
names none". Writing into a system you do not own is the act `docs/adr/0002-drift-is-pull-only.md`
already refused once, in a different system — ai-sdlc never writes into an adopted repo out of
band. The refusal there rested on two things: it would need a registry of adopters, and it would
make ai-sdlc a *second writer* of a fact the repo is the source of truth for. Write-back keeps
the first property intact — it happens inside the run the developer started, in the repo they
are standing in, against a target that repo named in its own committed `ai/jira.yaml`; no
registry, no repo enumerated, nothing stored here. The second property is where comments and
transitions part company, and it is why this ADR gives them different answers.

**One runtime writes, three run.** 0004 states the exposure plainly and declines to resolve it:
the MCP transport exists in Claude Code only, so the board is written from a developer's session
and nowhere else, is stale precisely on the work that ran headless, and "ticket status is not
evidence of repo state" until arm two of the seam (`ai/make/jira.sh`) exists. 0004 calls that a
weaker guarantee than never writing at all and leaves the argument to this ADR.

**A comment and a transition are not the same act.** A comment appends an event that only
ai-sdlc knows happened — nobody was writing "the plan is at `ai/plans/0007-foo.md`" by hand, so
a gap in that stream displaces nothing and asserts nothing false; it is an incomplete log whose
every entry is true. A status is a single mutable cell that other people, board automation,
sprint reports and WIP limits all read and write. Partial automation of that cell is worse than
none: the moment cards start moving by themselves some of the time, the human habit that kept
the field correct stops, and the field ends up maintained by neither. That is the same
two-writers-of-one-fact shape ADR 0002 refused, arriving through a different door.

## Decision
ai-sdlc may **append** to a ticket whenever it resolved one, and may **move** a ticket only in
a repo where every runtime can move it. This narrows §6 of the design, which gated transitions
on configuration alone.

1. **Three tasks comment: `/t4:spec`, `/t4:plan`, `/t4:check`.** They are the three that produce
   one durable artefact at a stable path — the spec, the plan, the verdict. `/t4:test` and
   `/t4:run` resolve the key so they can find the spec, and write nothing: `/t4:run` executes one
   plan step at a time and would flood the ticket with its own progress. Where §6 says "each
   task" and §9 says "spec/plan/check", §9 is the one that ships.

2. **The comment is a pointer, never a copy.** The task that ran, the repo-relative path of the
   artefact, and the ref it is on. No spec body, no plan steps, no diff. A comment whose whole
   payload is a path either resolves or does not; it cannot rot into a plausible lie the way a
   pasted summary can, and the repo stays the only place the work is written down.

3. **The trigger is a resolved ticket, not the argument form.** A task that resolved a key —
   passed on the command line, or read from the spec it was handed — comments. A task that
   resolved none does not. In a repo with no `ai/jira.yaml` no key is ever resolved, so nothing
   is ever posted (`docs/adr/0004` rule 2).

4. **Every run comments; nothing is de-duplicated, suppressed or edited.** This resolves the
   open question the design left in §11. Re-running `/t4:spec` on one ticket posts a second
   comment, because it *is* a second event, and the interesting fact — the spec was rewritten
   after the plan was drafted — is exactly what suppression would hide. The alternative the
   design floated, commenting only when the file did not already exist, makes the ticket claim
   the spec was written once when it was written three times, and the design already called it
   surprising. Editing a prior comment is worse: it needs a read-modify-write against a system
   that rule 4 forbids us to fail on.

5. **Transitions require two conditions, not one.** `ai/jira.yaml` must name the workflow states
   — ai-sdlc names none, ever, and infers none from a status's label — **and** the repo must
   carry `ai/make/jira.sh`, arm two of the seam. Until arm two exists, a repo's headless and
   Codex runs cannot move a card, and 0004 has already found the name for a status field written
   from one runtime out of three: not evidence. Making the second arm the gate turns that
   sentence from a warning in `ai/docs/tracker.md` into a condition in the code. Transitions ship in
   this release, as the design intends; they are inert in every repo until both conditions hold.

6. **A transition is idempotent and quiet when refused.** Already in the target state is a no-op.
   Unavailable from the current status is skipped, not retried and not raised. This repo's
   instinct is to fail loudly — an unresolvable key stops the task, two specs naming one ticket
   is an error — and that instinct is right about ai-sdlc's *own* inputs, which it owns. A Jira
   workflow that forbids the move from a card sitting in Blocked is the adopting org's rule about
   the adopting org's board, and a task has no standing to call it wrong. Quiet means it does not
   fail and does not retry. It does not mean unreported: see rule 7.

7. **Write-back never fails the task** (design rule 4). The artefact is on disk before anything
   is posted; a rejected comment or transition cannot unmake it. The price is that a developer
   can walk away believing the board was updated when it was not, so the run report must state
   what was written and what was refused, with the reason — and say nothing at all when nothing
   was attempted, so a Jira-less repo's report is unchanged.

Where the ticket key is recorded is `docs/adr/0005`, not this one.

## Consequences
A team gets a ticket that accumulates the three links worth having and a board they still move
by hand. That second half is the cost, and it is deliberate: under rule 5, transitions will be
inert in every repo on day one and in most repos for as long as arm two goes unbuilt, so a repo
that adopted this expecting its cards to move gets comments and a config key that does nothing
yet. The honest defence is that the alternative was not "cards move" but "cards move on the
half of the work a human happened to run interactively", which decays the habit of moving them
by hand without replacing it. This ADR would be wrong if arm two lands quickly, or if a repo
demonstrates it runs the whole loop interactively and never headless — in that repo the gate
buys nothing and should be revisited by superseding this decision, not by adding an override.

The comment stream is noisy by construction. A feature specced three times carries three spec
comments, and there is no mechanism to clean them up, because rule 7 forbids depending on a
write succeeding and rule 4 forbids reading before writing. A ticket is now an append-only log
of runs, which is the shape being chosen, not an accident of it.

Write access is a real widening, and it is not the same grant as reading a ticket. A read-only
credential turns a bad run into a wasted fetch. A write credential makes a bad run visible to
everyone watching the board, and a mistyped key that happens to resolve puts a comment on
somebody else's ticket. Comments are additive and a human can delete them; a transition fires
notifications, board automation and SLA clocks, which is a third reason it is gated harder.
Today the grant is the developer's own Jira identity held by the connector, so every comment is
attributed to a person and no token is committed — but the session reaches everything that
person can reach, not just this project. When arm two is built it will need a token in CI, which
is a shared service account writing to a board on behalf of nobody in particular; that is a
different and wider grant, and the spec for arm two must decide it rather than inherit it.

This decision does not soften ADR 0002. ai-sdlc still writes into no repo out of band, keeps no
registry, and names no adopter. It also does not settle which ticket field becomes acceptance
criteria, or whether a comment carries a browse link — both are still open in the design's §11
and neither blocks spec 3.
