# 0005 — The tracker key lives in the spec body, as one vendor-neutral line

Date: 2026-09-07 · Status: proposed — it cannot be accepted ahead of its gate,
`docs/adr/0004-external-tracker-behind-one-seam.md`, which is itself proposed.

## Context
`ai/designs/0002-jira-integration.md` §6 has `/t4:spec` fetch a ticket and four later tasks —
`/t4:plan`, `/t4:test`, `/t4:run`, `/t4:check` — resolve the same key back to the work in
flight. Something has to hold the key between them, and the candidates are not equivalent.

Specs have no frontmatter today: `skills/ai-layout/templates/specs/0000-scaffold.md` opens
`# NNNN — Title` and goes straight to prose. Introducing a `---` block changes the shape of the
artefact every adopted repo produces — a contract change under `ai/docs/fleet.md` Boundaries —
and, because the scaffold is a tracked template, editing it reports as `upstream changed` in
every repo's next `/t4:sync-sdlc` (ADR 0001, ADR 0002), including the great majority with no
tracker at all. Frontmatter also asserts a parse contract this plugin cannot honour: tasks are
prompt files, not code (design §2), so there is no parser, no schema and no validator behind
the fence — and Claude Code already reads frontmatter in `ai/tasks/*.md` as command metadata,
so a second, differently-shaped block in specs invites a reader to expect the same treatment.

A sidecar index — `ai/jira-links.json` — is the other shape, and it is the one worth arguing
with, because this repo already keeps a sidecar: `ai/.sdlc.json`. That precedent is narrower
than it looks. The manifest records what no file can carry — the hash of the template a file
came from, which is history, not content — and it is written and read only by
`skills/ai-layout/scripts/manifest.js`, guarded by `ai/docs/dont-touch.md` so no hand can rot
it. A ticket key is the opposite on all three counts: it is content, the file can hold it, and
the only writer available is a prompt. Nothing here can maintain a JSON index transactionally,
so a renamed or deleted spec silently orphans its entry, and two features specced on two
branches conflict in one file on every merge. ADR 0002 refused a registry of repos for the same
reason a sidecar should be refused here: state belongs with the thing it describes.

The last force is a collision. ADR 0004 rule 3 confines the vendor to `ai/docs/jira.md` and
forbids a task prompt from naming it; rule 2 promises a repo with no `ai/jira.yaml` sees no new
line in a generated spec. This decision has a task write a label into a file in every adopting
repo, so the wording of that label is a rule-3 question, not a matter of taste.

## Decision
The key lives in the spec body, as a single line directly under the title and above the
summary, written only by `/t4:spec` and only in a repo that has committed `ai/jira.yaml`:

    Ticket: PROJ-123

**The label is vendor-neutral, which departs from the literal `Jira:` in design §6 and §7.**
The prompt in `ai/tasks/spec.md` has to contain the label verbatim, so a vendor-named label is
the vendor named in a task prompt — the exact thing rule 3 forbids, breached on the first task
that ships under it. `Ticket:` also keeps the blast radius of replacing the tracker at one
file, instead of at every spec in every adopted repo. This is a correction to the design's
wording, not to its substance; the substance — body text, one line, greppable — stands.

I will not claim more consistency than I have. Rule 3 is still not clean after this change: the
prompt must name the seam document, and that document is called `ai/docs/jira.md`, so the
vendor reaches the prompt through a filename whatever the label says. That leak is 0004's to
close by renaming the seam, and this ADR neither closes nor widens it.

The value is the bare key and nothing else — no URL, no title, no prose, the whole of it
matching `[A-Z][A-Z0-9]+-[0-9]+`. A link would put the vendor's host in every spec and
recreate the leak the label just avoided; the base URL stays in `ai/docs/jira.md`.

Resolution is `grep` over `specs/`, matching the key as a whole token so `PROJ-12` never hits
`PROJ-123`. Tens of files, no index to keep warm. The edges are decided, not left to judgement:

- **Exactly one match** — that spec.
- **No match** — stop and ask. Never fall through to treating `PROJ-123` as a feature
  description (design rule 2); a confident spec about nothing is worse than no spec.
- **Two or more** — report every path and stop (design rule 3). Never break the tie by number,
  mtime or git history.

**The key is an alias, never the only handle.** Every task still accepts a spec path exactly as
it does today, so a missing, deleted or mistyped line degrades to current behaviour rather than
blocking the loop. And a repo with no `ai/jira.yaml` gets no such line at all: `/t4:spec` there
emits the file it emits today, byte for byte, per ADR 0004 rule 2.

What is written back to the ticket is `docs/adr/0006`, not this ADR.

## Consequences
The link travels with the artefact. It survives a rename, a cherry-pick and a merge, shows up
in the diff a human reviews, renders on the forge, and is legible without a tool. No new file,
no new schema, no new guard, no drift event, and nothing at all for the adopters who have no
tracker.

The cost is that the link is unvalidated body text a human can break, and nothing in the loop
will notice. It can be deleted, copy-pasted from a neighbouring spec, or left pointing at a
ticket that has since been moved, renumbered or closed. Duplication surfaces as the two-match
error above — loud, at the point of use, fixable by editing one line — but a stale key does
not surface at all: it resolves cleanly to the wrong ticket, and the write-back in 0006 will
comment there in good faith. The plugin has no way to detect this, will not grow one here, and
must not be described to adopters as if the spec and the board are guaranteed to agree.

That is accepted because the alternative pays the same cost with less to show for it. A
machine-owned index is not self-correcting either — it is only unfixable by the person holding
the file, invisible in review, conflict-prone across branches, and orphaned by a rename that
nothing watches. A wrong line a developer can see and edit beats a wrong record they cannot.

Two smaller things get harder. `Ticket:` is a weaker grep target than a vendor name, and a
human may one day write `Ticket: see the thread in Slack` on a hand-authored spec; the
whole-value pattern above means such a line resolves to nothing rather than to something wrong,
which is the failure we want, but it does mean the label alone is not proof of a key. And a
line under the title is one more piece of the spec's shape that later tasks must leave in
place — the reviewers of `/t4:plan` and `/t4:check` output should treat its silent
disappearance as a defect, not as tidying.
