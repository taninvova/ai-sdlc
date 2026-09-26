---
description: Configure this repo's tracker, confirm it with you, and prove it resolves a real key
allowed-tools: Bash, Read, Write, Edit
argument-hint: [site url]
---
Set this repo up so `/t4:spec ABC-12` can draft from a ticket. Ask before writing, write one
file, then prove it works. **Never write to the tracker itself** — this reads, and nothing here
comments on or moves anything.

Refuse early, before reading or writing anything:

1. **No `ai-factory/docs/tracker.md`?** Stop. Say this repo's layout predates tracker support, and that
   `/t4:sync-sdlc` will report it as an upstream file to take. Do not create the file yourself —
   it is a template, and writing a local copy would fork it from the one that ships.

2. **Not an interactive session?** Stop, and say the command is interactive. Every step below
   asks before it writes, and a headless run has nobody to ask. Do not fall back to writing
   with assumed answers: a config file written from guesses is worse than none, because the
   repo then looks configured. If you cannot tell, assume you cannot ask.

Then follow `ai-factory/docs/tracker.md` — it is the only place that knows what a tracker is, what
counts as configured, and what to detect. Name nothing specific yourself: no product, no
service, no URL, no configuration filename.

3. **Detect and confirm.** Detect the reachable site. Show it and ask before writing anything.
   If nothing is reachable, say why, write nothing, and name what would fix it.

4. **Write, once, never silently.** If the file already exists, show its current contents and
   ask a second time before replacing it — it is hand-written and a developer may have put
   something there deliberately. Write only what that document defines as required, and nothing
   more: a key nothing reads yet is a key that goes stale unnoticed.

5. **Ask whether to commit it or ignore it.** If ignored, add the line to `.gitignore` — never
   duplicating one already there — and say plainly that the repo is now configured for this
   developer alone: a teammate who clones it gets the unconfigured behaviour, so the same
   command means different things to different people on one team. Choosing that is fine;
   not being told is not.

6. **Prove it.** Ask for one key and resolve it, and report what came back so setup is proved
   rather than assumed. If none is offered, say the configuration is unverified and name what
   would verify it — writing a file is not evidence it works.

Report: what was written, whether it is committed or ignored, and whether it was proved.

Context: $ARGUMENTS
