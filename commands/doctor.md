---
description: Report what is wrong with this repo's ai-sdlc setup, and the command that fixes each thing
allowed-tools: Bash, Read
---
Diagnose this repo's setup and report. **Change nothing.** Do not edit a file, install,
enable, sync, or start a baseline — every remedy is a command the developer runs, and being
read-only is what makes this safe to run first, before anyone knows what is wrong. Do not ask
the developer anything: this reports, it does not interview, and it must behave the same in a
headless run.

1. Run:
   `bash "${CLAUDE_PLUGIN_ROOT}/skills/ai-layout/scripts/doctor.sh" . "${CLAUDE_PLUGIN_ROOT}"`
   It prints one line per check — `[finding]` wrong, `[unknown]` unanswerable, `[ok]` nothing
   to do — and a summary. It always exits 0; a non-zero exit means the script itself failed,
   which is itself worth reporting.

2. Add one line about the tracker. If `ai/docs/tracker.md` exists, follow it to decide whether
   this repo is configured, and report which. If it does not exist, say this layout predates
   tracker support and name `/t4:sync-sdlc`. Name nothing specific yourself — no product, no
   service, no URL, no configuration filename. That document is the only thing allowed to know
   them, and repeating one here would put it in every repo that reads this command.

2b. Add one line about the knowledge seam, the same way. If `ai/docs/knowledge.md` exists,
   follow it to decide whether this repo has declared a source, and report configured or
   not. If it does not exist, say this layout predates knowledge-source support and name
   `/t4:sync-sdlc`. Name nothing specific — no source, no provider, no filename; that
   document is the only thing allowed to know them.

3. Report, worst first: findings, then unknowns. An `[ok]` line is noise unless nothing else
   is wrong — if there are no findings and no unknowns, say so in one line and stop.

4. Every finding carries the exact command or edit that resolves it. The script supplies one
   for each; keep it, and shorten it only if it stays runnable. A finding with no remedy is a
   complaint.

5. Judgement is the part a script cannot do, so add it sparingly and only where it changes what
   the developer should do first:
   - Several findings with one cause — an old layout usually explains a version finding and a
     drift finding at once — should be said once, with the order to fix them in.
   - An `[unknown]` is not a pass. Say what it would take to answer it.
   - If the repo is fine but the environment is not, say that plainly: the files here are not
     the reason the session is behaving oddly.

Do not repeat the raw output and then summarise it. One report.

**What this command cannot tell you:** whether the plugin is enabled in a repo where it is
not. There, this command does not exist, and its absence is the diagnosis — `docs/workflow.md`
carries that case, because nothing runnable can.

Context: $ARGUMENTS
