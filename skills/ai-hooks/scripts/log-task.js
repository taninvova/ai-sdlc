#!/usr/bin/env node
require("./_common").runHook(() => {
	// The task the session is running, remembered for the rows written later.
	//
	// UserPromptSubmit is the only event that can see which `/fc:` command was typed: Stop and
	// SubagentStop fire long afterwards and carry nothing in their payloads that names a task. So this
	// writes one line — the bare name, `spec` rather than `/fc:spec` — to `.task.<session_id>` beside
	// the run log, and session-stop.js and subagent-stop.js read it to fill the `task` column.
	//
	// Normal operation is silent; rejected writes produce a stderr diagnostic. Output from THIS event is the one kind
	// that reaches the model, so a single stray byte lands inside the cached prefix and invalidates it
	// for the rest of the session. Every other hook only has to keep stdout clean.
	//
	// A prompt carrying no `/fc:` command does nothing at all — the file keeps the last task rather
	// than being cleared, so a plain prompt typed in the middle of a task does not unattribute the rows
	// that follow it (open question 9; the cost of last-writer-wins is an agent still running from the
	// previous task, which this cannot see).
	const {
		readEvent,
		logDir,
		identifier,
		path,
	} = require("./_common");
	const { withLogLock } = require("./_safe-files");
	const ev = readEvent();
	const ai = logDir(ev);
	if (!ai) return;
	const m = /(?:\/fc:|\$(?:fc:)?fc-)([a-z][a-z0-9-]*)/.exec(
		String(ev.prompt || ""),
	);
	if (!m) return;
	// A deprecated command or a shortcut runs another task, so its rows carry that task's name:
	// /fc:check and $fc-check are the old names of review; /fc:ba and /fc:analyze are shortcuts of
	// analyse and /fc:scout of explore. One table, the union of TASK_ALIASES and TASK_SHORTCUTS in
	// the template's make/models.js, which a hook cannot load; check-codex.sh pins them together.
	const ALIASES = { check: "review", ba: "analyse", analyze: "analyse", scout: "explore" };
	const name = Object.hasOwn(ALIASES, m[1]) ? ALIASES[m[1]] : m[1];
	const file = path.join(ai, "runs", ".task." + identifier(ev.session_id));
	withLogLock(ai, (safe) => {
		safe.write(file, name + "\n");
	});
});
