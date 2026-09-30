---
description: Optionally declare an external documentation source, confirm it with you, and prove it answers
allowed-tools: Bash, Read, Write, Edit
argument-hint: [server name]
---
Declare one external documentation source for this repo so the agents that read knowledge can
consult it. Optional: the repo's own `ai-factory/docs/`, ADRs and code stay the knowledge base,
and a declared source only enriches them. Ask before writing, write one file, then prove it
works. **Never write to the source itself**, and never write tool configuration — attaching a
server is the developer's job, in their own tool settings.

Refuse early, before reading or writing anything:

1. **No `ai-factory/docs/knowledge.md`?** Stop. Say this repo's layout predates knowledge-source
   support, and that `/t4:sync-sdlc` will report it as an upstream file to take. Do not create
   the file yourself — it is a template, and a local copy would fork it from the one that ships.

2. **Not an interactive session?** Stop, and say the command is interactive. Every step below
   asks before it writes, and a headless run has nobody to ask. Do not fall back to writing
   with assumed answers: a declaration written from guesses makes the repo look configured. If
   you cannot tell, assume you cannot ask.

Then follow *Setting up a source* in `ai-factory/docs/knowledge.md` — it is the only place that
knows what a source is, what counts as configured, and how a name is found. Name nothing
specific yourself: no product, no server, no configuration filename beyond what that document
tells you to write.

3. **Pick the source.** Offer the sources the session lists, and the one named in the arguments
   if any. If the chosen one is not listed, say so, name the fix that document gives, and write
   nothing.

4. **Ask what it is for**, and keep the developer's words.

5. **Write, once, never silently.** If the declaration already exists, show its current
   contents and ask a second time before adding to it — it is hand-written and a developer may
   have put something there deliberately. Refuse a name already declared. Write only what that
   document defines, and nothing more.

6. **Ask whether to commit it or ignore it.** If ignored, add the declaration path relative to
   `ai-factory/` to `ai-factory/.gitignore` — never duplicating one already there — and say plainly
   that the repo is now configured for this developer alone: a teammate who clones it gets the
   unconfigured behaviour. Choosing that is fine; not being told is not.

7. **Prove it.** Ask for one query, make one read-only call, and report what came back so setup
   is proved rather than assumed. If none is offered, say the source is declared but unverified
   and name what would verify it.

Report: what was written, whether it is committed or ignored, and whether it was proved.

Context: $ARGUMENTS
