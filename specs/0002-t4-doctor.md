# 0002 — /t4:doctor

Summary: one read-only command that says what is wrong with this repo's ai-sdlc setup, and
names the exact command to fix each thing.

Chosen ahead of an interactive setup wizard (option D before option A of the in-session
exploration) for one reason: in the session that produced `specs/0001`, nothing that cost time
was a missing config file. It was a plugin enabled for a different project, stale cached
versions running the hooks, three names in play at once, a repo four generations behind, and a
headless runner that had never worked. A wizard would have helped with none of those. Each was
invisible state that a check could have named in a sentence.

## User story
As a developer whose slash commands are missing, or whose hooks are writing the wrong thing, I
want one command that tells me which of the half-dozen possible causes is the actual one, so
that I stop guessing at plugin scope, cache versions and layout drift in that order.

## Acceptance criteria

- **AC1** Given any repo, When `/t4:doctor` runs, Then it writes no file, changes no
  configuration, and makes no network request that writes. It reports only.
- **AC2** Given a repo with no `ai/` directory, When it runs, Then it says the repo carries no
  layout and stops. That is a finding, not an error.
- **AC3** Given a repo with the layout, When it runs, Then it reports the plugin version
  actually loaded in this session alongside the version `ai/.sdlc.json` records, and marks them
  as agreeing or not. A session running an older cached copy than the repo expects is the
  reported finding, not a footnote.
- **AC4** Given a session where the hooks are running from an installed copy rather than the
  working tree, When it runs, Then it reports the path the hooks are loaded from, because a
  session behaving unlike the code in front of you is otherwise indistinguishable from a bug in
  the code.
- **AC5** Given a repo whose layout is behind the installed templates, When it runs, Then it
  reports drift using the existing manifest check and does not reimplement it.
- **AC6** Given a repo with no `ai/.sdlc.json`, When it runs, Then it reports that drift cannot
  be computed and names the command that starts a baseline.
- **AC7** Given a repo where the generated adapters are stale or absent, When it runs, Then it
  says so and names `/t4:sync-sdlc`.
- **AC8** Given a tracker is or is not configured, When it runs, Then it reports which — by
  following `ai/docs/tracker.md`, naming no vendor, no connector and no URL itself.
- **AC9** Given any finding, When it is reported, Then it carries the exact command or edit
  that resolves it. A finding with no remedy is a complaint.
- **AC10** Given a headless run, When it runs, Then it produces the same report and asks
  nothing. `/t4:doctor` reports; it never interviews.
- **AC11** Given every check passes, When it runs, Then it says so in one line rather than
  printing a clean bill of health per check.
- **AC12** Given a check cannot be answered — a file unreadable, a tool absent — When it runs,
  Then that check reports "unknown" with the reason, and the command still completes. One
  unanswerable check must not suppress the others.

## Out of scope
- **Fixing anything.** `/t4:doctor` never edits, installs, enables or syncs. Every remedy is a
  command the developer runs. Keeping it read-only is what makes it safe to run first.
- Enabling or installing the plugin. See Open questions 1 — this is the one thing it cannot fix
  and the one that hurt most.
- Diagnosing another repo. Boundaries: ai-sdlc never reads another repo.

## Open questions
Answered before implementation, and kept for the reasoning:

1. ~~**Can it diagnose its own installation?**~~ **No, and it must say so.** `/t4:doctor` runs
   inside a session that already loaded the plugin, so it cannot detect "the plugin is not
   enabled in this repo" — in that repo the command does not exist. It can report scope and
   version *once loaded*, and the README must carry the not-loaded case, because no command can.
2. ~~**May it read `~/.claude`?**~~ **Yes, read-only, and never assume it exists.** Install
   scope and cached versions live there and are the highest-value findings. It is not another
   repo, so the Boundaries rule is not engaged. Under Codex the path is absent, which AC12
   turns into an "unknown", not a failure.
3. ~~**Task or plugin command?**~~ **Plugin command** (`commands/doctor.md` → `/t4:doctor`).
   It must work in a repo with no layout (AC2), and project tasks only exist once a repo has
   one. That is the same reason `/t4:adopt-sdlc` is a plugin command.

**No open questions remain. This spec is buildable.**

## Data touched
- `commands/doctor.md` — **new**, the command.
- `skills/ai-layout/scripts/doctor.sh` — **new**; the mechanical checks, so the prompt reports
  rather than reimplements. Reuses `manifest.js check` and `check-versions.sh`.
- `README.md`, `docs/workflow.md` — the command table, and the not-loaded case from question 1.

## Routes touched
None. The surface is one new plugin command.

## Components likely involved
`skills/ai-layout/scripts/manifest.js` (drift, unchanged), `check-versions.sh` (manifest
agreement), `ai/docs/tracker.md` (AC8's only source of tracker facts),
`skills/ai-hooks/scripts/_common.js` (how hooks locate `ai/`, for AC4).
