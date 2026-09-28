#!/usr/bin/env node
// The task the session is running, remembered for the rows written later.
//
// UserPromptSubmit is the only event that can see which `/t4:` command was typed: Stop and
// SubagentStop fire long afterwards and carry nothing in their payloads that names a task. So this
// writes one line — the bare name, `spec` rather than `/t4:spec` — to `.task.<session_id>` beside
// the run log, and session-stop.js and subagent-stop.js read it to fill the `task` column.
//
// Nothing is printed, ever: not to stdout and not to stderr. Output from THIS event is the one kind
// that reaches the model, so a single stray byte lands inside the cached prefix and invalidates it
// for the rest of the session. Every other hook only has to keep stdout clean.
//
// A prompt carrying no `/t4:` command does nothing at all — the file keeps the last task rather
// than being cleared, so a plain prompt typed in the middle of a task does not unattribute the rows
// that follow it (open question 9; the cost of last-writer-wins is an agent still running from the
// previous task, which this cannot see).
const { readEvent, aiDir, fs, path } = require("./_common");
const ev = readEvent(); const ai = aiDir(ev); if (!ai) process.exit(0);
const m = /\/t4:([a-z][a-z0-9-]*)/.exec(String(ev.prompt || ""));
if (!m) process.exit(0);
try {
  const file = path.join(ai, "runs", ".task." + (ev.session_id || "unknown"));
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, m[1] + "\n");
} catch {}
