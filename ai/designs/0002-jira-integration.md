# 0002 — Jira integration

Date: 2026-09-07 · Status: proposed · Plugin version at time of writing: 0.17.0.
**No accepted ADR binds this design.** It contradicts a standing boundary — see §2 — so it
cannot proceed on this document alone.

## 1. Capability
`/t4:spec PROJ-123` drafts a spec from a Jira ticket instead of from typed prose. The ticket
key is then recorded, so `/t4:plan`, `/t4:test`, `/t4:run` and `/t4:check` can be given the
same key and resolve it to the work already in flight. Each of those tasks comments its
artefact back to the ticket, and may move the ticket's status if the repo has configured it.

## 2. Drivers
- **This is the plugin's first dependency on an external service.** `.claude-plugin/plugin.json`
  says "Standalone — no dependency on any other repo; framework overlays build on it through
  the template slots", and `ai/docs/fleet.md` Boundaries repeats it. Jira is not another repo,
  so the letter survives, but the spirit does not: a task that cannot run without Atlassian
  being reachable is not standalone. **This is the ADR that gates the work.**
- **Three runtimes, one prompt.** Claude Code (plugin commands + subagents + hooks), Codex
  (`.codex/skills/`, no subagents, no hooks — CHANGELOG 0.9.0), and headless `make ai TASK=…`
  used by CI. The task prompt is the same file in all three; only the surrounding capability
  differs. Source: `docs/workflow.md` §8, `skills/ai-layout/templates/ai/make/ai.mk`.
- **The chosen transport reaches one of those three.** The Atlassian MCP connector is Claude
  Code only, is currently unauthenticated, and is absent from headless and cron runs. So
  ticket resolution and write-back happen from a developer's Claude Code session and nowhere
  else. Accepted deliberately (§6) — but it means the board is updated *sometimes*, which is
  a weaker guarantee than never, and the design has to say so out loud rather than let a team
  infer that Jira mirrors reality.
- **Tasks are prompt files, not code.** `ai/tasks/*.md` carry no `allowed-tools`; only the two
  plugin commands do. There is no function to put a seam in. Any indirection has to be a
  document the prompts point at.
- **Template changes reach every adopted repo.** `ai/docs/coding-standards.md` and fleet.md
  Boundaries. Adding a `Ticket:` line to what `/t4:spec` writes changes the output of every
  adopter, including those with no Jira at all.
- **`ai/tasks/*.md` are symlinks into `skills/ai-layout/templates/`**, so a task edit is one
  edit, not two. Adding a *new* template file is a drift event for every adopted repo
  (`ai/.sdlc.json`, ADR 0002).
- **A task that cannot get its input must ask, not invent.** Established in 0.14.0 for empty
  arguments; an unresolvable ticket key is the same failure with a different cause.
- **Specs have no frontmatter today.** They open with `# NNNN — Title`
  (`skills/ai-layout/templates/specs/0000-scaffold.md`). Somewhere has to hold the key.

## 3. Today
No Jira anywhere: no mention in any tracked file, no `jira`/`acli` binary on PATH, no
`JIRA_*` environment, no `mcpServers` in either plugin manifest. `/t4:spec` takes free text
and asks for it when absent. `/t4:plan` takes a spec path. Nothing links a spec to anything
outside the repo.

## 4. Options

### Transport
- **A. MCP connector.** Richest data, no token handling, no install. Claude Code only.
- **B. `ai/make/jira.sh` over REST.** Same behaviour in all three runtimes, no install, three
  env vars. Prompts stay free of JSON shape.
- **C. `jira` CLI.** Best ergonomics, but the first binary every developer and CI image must
  install.

### Linkage
- **D. Key recorded in the spec.** One fetch point; four resolvers; write-back knows its target.
- **E. `/t4:spec` only.** Smallest change; nothing downstream can comment or transition,
  because nothing downstream knows the ticket.

### Write-back
- **F. Comments always, transitions opt-in.** Additive by default; a repo names its own
  workflow states before anything moves.
- **G. Both on.** Most automation; every repo must get state names right before the first run.
- **H. Comments only.** The board is only ever moved by a person.

## 5. Comparison
| | CI / Codex parity | Setup cost | Blast radius | Reversible |
|---|---|---|---|---|
| A | none | zero | local sessions only | yes |
| B | full | 3 env vars | everywhere the task runs | yes |
| C | full | install per machine + image | everywhere | costly |
| D | n/a | one line per spec | changes every adopter's spec output | yes |
| E | n/a | none | none | yes |
| F | follows transport | `ai/jira.yaml` when wanted | comments always, moves on request | yes |
| G | follows transport | states required up front | moves cards from run one | yes |
| H | follows transport | none | additive only | yes |

## 6. Decision
**A + D + F**, with the seam from B built now and its implementation deferred.

- **Transport: the MCP connector, reached through a documented seam.** Tasks never name the
  connector. They say: resolve this ticket the way `ai/docs/jira.md` describes. That document
  defines the resolution order — MCP if the session has it, else `ai/make/jira.sh` if the repo
  has it, else stop and ask. Only the third arm exists in Codex and CI today; adding the
  second is then a new file plus a paragraph, with no task edited.
- **Linkage: `/t4:spec` writes the key into the spec it creates**, as a `Ticket: PROJ-123`
  line under the title. The label is vendor-neutral per `docs/adr/0005`: `ai/tasks/spec.md`
  carries it verbatim, so `Jira:` — this design's first wording — would have been the vendor
  named in a task prompt, which ADR 0004 rule 3 forbids. Specs stay frontmatter-free; this is body text, greppable, and survives
  a human editing the file. `/t4:plan`, `/t4:test`, `/t4:run` and `/t4:check` accept either a
  path (as today) or a key, resolving a key by grepping `specs/`.
- **Write-back: comment always, transition only when every runtime can.** Each task comments
  the artefact it produced, on every run. `docs/adr/0006` narrows what this design proposed:
  transitions need `ai/jira.yaml` **and** `ai/make/jira.sh` — arm two of the seam — not
  configuration alone, so no card moves until every runtime can move one. A refused transition
  is not retried and does not fail the task, but is reported.

### Rules that fall out
1. **Configuration opens the tracker path — never the shape of an argument.** Only a repo
   that has committed `ai/jira.yaml` resolves keys at all. *Inside* such a repo an argument is
   a key only if the whole of it matches `[A-Z][A-Z0-9]+-[0-9]+`, so "PROJ-123 but only the
   CSV part" is not silently reduced to the ticket. The first draft of this design made the
   pattern itself the trigger, which cannot work: `UTF-8`, `ISO-8601`, `RFC-7231` and `HTTP-2`
   all match it end to end, so `/t4:spec UTF-8` in a repo with no Jira would have stopped to
   ask about a ticket that cannot exist — precisely the new failure mode rule 5 promises
   Jira-less adopters never see. Corrected per `docs/adr/0004` rule 2, which supersedes the
   original wording.
2. **An unresolvable key stops the task.** Never fall through to treating `PROJ-123` as the
   feature description — that produces a confident spec about nothing, which is worse than
   no spec. Same rule as 0.14.0's empty argument.
3. **Two specs naming one ticket is an error, not a guess.** Report both paths and stop.
4. **Write-back never fails the task.** The artefact is already on disk; a rejected comment or
   transition is reported, not raised.
5. **A repo with no `ai/jira.yaml` and no Jira behaves exactly as it does today.** Adopters
   without Jira must see no new prompt, no new question, no new failure mode, and no new line
   in a generated spec. Rule 1 is what makes this hold; the two are one decision stated twice
   and neither survives alone.

## 7. Contracts and data ownership
| Thing | Owner | Written by | Notes |
|---|---|---|---|
| `ai/jira.yaml` | the adopting repo | a human | base URL, optional transition map. Never generated. |
| `Ticket:` line in a spec | the spec file | `/t4:spec` | body text under the title, not frontmatter; vendor-neutral (ADR 0005) |
| `ai/docs/jira.md` | ai-sdlc template | plugin release | the seam: resolution order and write-back contract |
| Ticket comments | Jira | any task, via the seam | additive; ai-sdlc owns none of it |
| Ticket status | Jira | opt-in **and** arm two present (ADR 0006) | the repo names the states; ai-sdlc names none |
| Credentials | the developer's environment | never the repo | no token is committed; MCP holds its own |

## 8. ADRs to write
- **0004 — ai-sdlc may depend on an external tracker, behind one seam and off by default.**
  **Written:** `docs/adr/0004-external-tracker-behind-one-seam.md`, Status: proposed. It
  narrows the standalone claim rather than preserving it by literalism, makes configuration
  the trigger, and confines the dependency to `ai/docs/jira.md`. **Not yet accepted — spec 1
  does not start until it is.**
- **0005 — the tracker key lives in the spec body, as one vendor-neutral line.**
  **Written:** `docs/adr/0005-ticket-key-lives-in-the-spec-body.md`, Status: proposed.
  Changed this design's label from `Jira:` to `Ticket:`; see §6.
- **0006 — write-back appends always, moves a ticket only when every runtime can.**
  **Written:** `docs/adr/0006-write-back-comments-always-transitions-gated.md`, Status:
  proposed. It answered the question this design left to 0004 and 0004 left open — it does
  *not* accept moving cards from one runtime out of three, on the grounds that a status is a
  cell people and board automation also write, so automating it partially kills the manual
  habit without replacing it. That is ADR 0002's two-writers-of-one-fact refusal arriving
  through a different door.

## 9. Specs to follow
1. `/t4:spec` accepts a ticket key, fetches it, writes the `Ticket:` line. Gated on
   `ai/jira.yaml` being present (ADR 0004 rule 2), not on the argument's shape; includes the
   whole-argument match rule *within* a configured repo, and the stop-on-unresolvable rule.
2. Key resolution in `/t4:plan`, `/t4:test`, `/t4:run`, `/t4:check`.
3. Write-back: comments from spec/plan/check, plus `ai/jira.yaml` and transitions.

Spec 1 is useful alone. 2 and 3 are not useful without 1.

## 10. Proposed updates to ai/docs/architecture.md and ai/docs/fleet.md
- architecture.md: a fourth surface reaching a developer — an external tracker, reached only
  through `ai/docs/jira.md`.
- fleet.md Boundaries: amend the standalone claim rather than delete it. Proposed wording —
  "ai-sdlc depends on no other repo and adds no runtime dependency. One task may call an
  external tracker when the repo configures one; every task works without it."

## 11. Open questions
- **Which ticket field becomes acceptance criteria?** Description prose, a checklist field, or
  a Jira plugin's AC field — differs per team, and `/t4:spec`'s whole output is Given/When/Then.
  Unresolved. Probably: read the description, and let the spec's own Open Questions carry
  whatever the ticket left implicit.
- ~~**Repeated runs comment repeatedly.**~~ **Resolved by ADR 0006:** every run comments,
  because a re-spec is a second event and suppressing it hides the interesting fact. Neither
  alternative survived the no-read-before-write rule.
- **The seam's filename still names the vendor.** ADR 0005 found the leak it could not close:
  a task prompt must name `ai/docs/jira.md`, so the vendor reaches the prompt through a
  filename even with a neutral `Ticket:` label. Renaming the seam — `ai/docs/tracker.md` —
  closes ADR 0004 rule 3 cleanly and costs nothing while none of this is built. Left unchanged
  here on purpose: it amends an ADR under review, which is the accepter's call, not a design
  edit.
- **Should `/t4:explore`, `/t4:fix` and `/t4:chore` take keys too?** They take requests, so it
  is natural. Deferred: they produce no spec, so there is nowhere to record the key.
- **Does the base URL come from `ai/jira.yaml` or from the connector?** Needed to write a
  browse link into a comment without a fetch.
- **When does arm two of the seam get built?** Until it exists, CI cannot resolve a ticket, and
  §2 says the board is only sometimes right.
