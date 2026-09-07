# 0001 — /t4:spec accepts a ticket key

Summary: in a repo that has configured a tracker, `/t4:spec PROJ-123` drafts the spec from the
ticket instead of from typed prose, and records the key in the spec it writes.

Implements spec 1 of `ai/designs/0002-jira-integration.md` §9. Bound by `docs/adr/0004`
(configuration opens the tracker path; one seam, never named in a prompt), `docs/adr/0005`
(the key lives in the spec body as a vendor-neutral `Ticket:` line) and `docs/adr/0006`
(write-back — out of scope here, but the `Ticket:` line is what later makes it possible).

## User story
As a developer whose work arrives as tickets, I want `/t4:spec` to take the ticket key I
already have, so that the spec starts from what the ticket actually says rather than from my
paraphrase of it, and so the spec and the ticket stay findable from each other.

## Acceptance criteria

- **AC1** Given a repo with no `ai/jira.yaml`, When a developer runs `/t4:spec UTF-8`, Then the
  session treats `UTF-8` as the feature request, drafts a spec about it, and at no point
  fetches a ticket, asks about a ticket, or writes a `Ticket:` line.
- **AC2** Given a repo with `ai/jira.yaml` and a session that can reach the tracker, When a
  developer runs `/t4:spec PROJ-123`, Then the session resolves the key by following
  `ai/docs/tracker.md`, and writes `specs/<NNNN>-<slug>.md` containing a `Ticket: PROJ-123`
  line as the first line under the title.
- **AC3** Given a repo with `ai/jira.yaml`, When a developer runs
  `/t4:spec PROJ-123 but only the CSV part`, Then the whole argument is the feature request,
  no ticket is fetched, and no `Ticket:` line is written.
- **AC4** Given a repo with `ai/jira.yaml` and a session that cannot reach the tracker — Codex,
  or headless `make ai`, where `ai/docs/tracker.md` resolves to its stop-and-ask arm — When a
  developer runs `/t4:spec PROJ-123`, Then the session reports that it cannot resolve the key,
  asks how to proceed, and writes no spec file.
- **AC5** Given a repo with `ai/jira.yaml` and a reachable tracker, When a developer runs
  `/t4:spec PROJ-999` and no such ticket exists, Then the session reports that the key did not
  resolve, asks how to proceed, and writes no spec file.
- **AC6** Given any repo, When a developer runs `/t4:spec` with nothing after it, Then the
  session asks which feature to specify and stops — the behaviour shipped in 0.14.0, unchanged
  by this spec whether or not a tracker is configured.
- **AC7** Given `skills/ai-layout/templates/ai/tasks/spec.md`, When it is read, Then the only
  tracker-related path it names is `ai/docs/tracker.md`, and it contains no vendor name, no
  connector name, no URL, no field name and no JSON shape.
- **AC8** Given a spec written by AC2, When it is read, Then it carries exactly one `Ticket:`
  line, whose value is the key alone with no surrounding prose, so that a whole-token grep
  over `specs/` resolves it unambiguously.
- **AC9** Given a repo with `ai/jira.yaml` whose tracker is reachable, When two specs already
  carry `Ticket: PROJ-123` and a developer runs `/t4:spec PROJ-123`, Then the session reports
  both paths and stops rather than choosing one.

## Out of scope
- Resolving a key in `/t4:plan`, `/t4:test`, `/t4:run`, `/t4:check` — design §9 spec 2.
- Any write-back: comments and transitions — design §9 spec 3, `docs/adr/0006`.
- `ai/make/jira.sh`, arm two of the seam. Until it exists AC4 is the normal path outside
  Claude Code, not an error case.
- Teaching `/t4:explore`, `/t4:fix` or `/t4:chore` to take keys — design §11, deferred.

## Open questions
A spec with open questions is not buildable. These are for the developer before implementation:

1. **Which ticket field becomes acceptance criteria?** `/t4:spec`'s whole output is
   Given/When/Then, and teams keep ACs in the description, in a checklist field, or in a Jira
   plugin's own field. Design §11 leaves this unresolved and it is the largest unknown here.
   Proposed default: read the description, and let the spec's own Open Questions carry whatever
   the ticket left implicit — but this needs one real ticket tried before it is settled.
2. **Does `ai/docs/tracker.md` ship as a template, and what does that cost adopters?** Adding a
   template file is a drift event for every adopted repo (`ai/.sdlc.json`, ADR 0002), including
   the majority with no tracker.
3. **What exactly is `ai/jira.yaml` required to contain for AC1's gate to be unambiguous?** An
   empty file, or a file with only comments — configured or not?

## Data touched
No application data; this repo ships prompts and templates.
- `skills/ai-layout/templates/ai/tasks/spec.md` — the prompt gains the gate, the whole-argument
  rule, the stop-and-ask rule and the `Ticket:` line instruction. `ai/tasks/spec.md` is a
  symlink to it, so this is one edit.
- `skills/ai-layout/templates/ai/docs/tracker.md` — **new**; the seam. Resolution order,
  and the only place naming the vendor or `ai/jira.yaml`.
- `skills/ai-layout/templates/ai/docs/dont-touch.md` — consider listing `ai/jira.yaml`.
- `CHANGELOG.md`, `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`,
  `.claude-plugin/marketplace.json` — version bump, per the definition of done.

## Routes touched
None — this repo exposes no routes. The equivalent surface is the command
`/t4:spec`, whose contract changes for configured repos only.

## Components likely involved
- `skills/ai-layout/scripts/check-adapters.sh` — AC7 is a static property of the generated
  command and is cheap to assert there, alongside the argument-hint checks added in 0.14.0.
- `skills/ai-layout/scripts/manifest.js` — a new template file changes what adopters see as
  drift (open question 2).
- The Codex generator in `sync-adapters.sh` — AC4 is Codex's normal path, so its skill must
  carry the same stop-and-ask behaviour rather than silently differing.
