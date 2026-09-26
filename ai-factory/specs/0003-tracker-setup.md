# 0003 — /t4:setup-tracker

Summary: an interactive command that detects the tracker site, confirms it with the developer,
writes `ai/jira.yaml`, and proves the result by resolving one real key.

Option A of the in-session exploration, deliberately after `specs/0002`. It exists because
`ai/jira.yaml` is the switch that turns `specs/0001` on, and today a developer has to know the
filename, the one required key and its exact shape — none of which any command tells them.

## User story
As a developer who wants `/t4:spec ABC-12` to work in this repo, I want one command that sets
the tracker up and then proves it works, so that I find out now rather than the first time I
pass a key and get a stop-and-ask I cannot explain.

## Acceptance criteria

- **AC1** Given a repo with `ai/docs/tracker.md`, When `/t4:setup-tracker` runs, Then it
  detects the reachable tracker site, shows it, and asks the developer to confirm before
  writing anything.
- **AC2** Given the developer confirms, When it writes, Then `ai/jira.yaml` contains a mapping
  with `base_url` set to the confirmed site, and the file parses — the same condition
  `ai/docs/tracker.md` uses to decide a repo is configured.
- **AC3** Given `ai/jira.yaml` already exists, When it runs, Then it shows the current contents
  and does not overwrite without an explicit second confirmation. That file is hand-owned —
  `docs/adr/0004` and plan 0001 step 2 — and a command that silently rewrites it contradicts
  the reason it was left out of `dont-touch.md`.
- **AC4** Given no tracker site can be reached, When it runs, Then it reports why, writes
  nothing, and names what to do — authorising a connector, or writing the file by hand.
- **AC5** Given the file has been written, When it finishes, Then it resolves one key supplied
  by the developer and reports the ticket's summary, so setup is proved rather than assumed.
- **AC6** Given the developer supplies no key to verify with, When it finishes, Then it says
  the configuration is unverified and names the command that would verify it. Writing the file
  is not evidence it works.
- **AC7** Given a repo with no `ai/docs/tracker.md`, When it runs, Then it stops and says the
  layout predates tracker support, naming `/t4:sync-sdlc` and the drift it will report.
- **AC8** Given a headless or non-interactive run, When it runs, Then it makes no change and
  says the command is interactive. It asks before writing, and there is nobody to ask.
- **AC9** Given the command runs at all, When it finishes, Then nothing has been written to the
  tracker — no comment, no transition, no field. Setup reads; `docs/adr/0006` governs writing
  and is not engaged by this spec.
- **AC10** Given the command's prompt is read, When checked, Then it names `ai/docs/tracker.md`
  and no vendor, connector, URL or field — the rule `check-adapters.sh` already asserts.
- **AC11** Given setup writes the file, When it is read, Then it carries `base_url` and nothing
  else. A key nothing reads yet is a key that goes stale without anyone noticing, and a second
  definition of "configured" would drift from the seam's.
- **AC12** Given the file has been written, When setup finishes, Then it asks whether to commit
  it or add it to `.gitignore`, and does what is chosen — appending the line if asked, and
  never rewriting an existing `.gitignore` entry.
- **AC13** Given the developer chooses to ignore it, When setup reports, Then it states plainly
  that the tracker will then resolve keys for this developer only: a teammate cloning the repo
  gets the unconfigured behaviour, so `/t4:spec ABC-12` means different things to different
  people on one team. Choosing to ignore is allowed; not being told is not.

## Out of scope
- Configuring anything but the tracker. Whole-layout setup was option B and was rejected: it
  overlaps `/t4:adopt-sdlc` and `/t4:fleet`, and three commands that all set things up drift
  apart.
- Any write to the tracker.
- Enabling the plugin, which no command can do — `specs/0002` question 1.

## Open questions
1. ~~**Does `ai/jira.yaml` need anything beyond `base_url` on day one?**~~ **Answered:**
   `base_url` only — AC11. It is exactly what AC13 of `specs/0001` already calls configured, so
   setup and resolution cannot drift into two definitions. A project key can be added when
   something reads it.
2. ~~**Should it offer to add `ai/jira.yaml` to `.gitignore`?**~~ **Answered: yes, ask** — AC12.
   Chosen over committing by default, which was the recommendation, so the cost it carries is
   made explicit rather than left implicit: an ignored config means the repo is configured for
   one developer and unconfigured for everyone else, and the same `/t4:spec ABC-12` behaves
   differently per machine. AC13 requires setup to say that at the moment the choice is made.
   The file holds no credential either way — ADR 0004 keeps those in the environment — so this
   is a workflow preference, not a secrets decision.

**No open questions remain. This spec is buildable.**

## Data touched
- `commands/setup-tracker.md` — **new**, the command. Plugin command, not a task: it must run
  in a repo whose layout may predate tracker support (AC7).
- `ai/jira.yaml` — written in the repo it runs in. Never generated elsewhere, never templated.
- `README.md`, `docs/workflow.md` — command table, and how a repo turns the tracker on.

## Routes touched
None.

## Components likely involved
`ai/docs/tracker.md` (the only source of what configured means and how to resolve),
`skills/ai-layout/scripts/check-adapters.sh` (AC10, already asserted),
and `/t4:doctor` from `specs/0002`, whose tracker line is the natural place AC6 points to.
