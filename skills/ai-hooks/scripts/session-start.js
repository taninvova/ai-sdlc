#!/usr/bin/env node
require("./_common").runHook(() => {
	const {
		readEvent,
		aiDir,
		logDir,
		user,
		branch,
		appendJsonl,
		fs,
		path,
	} = require("./_common");
	const ev = readEvent();
	// The plan in flight is this checkout's; the row goes to the main repository's run log.
	const ai = aiDir(ev);
	const logs = logDir(ev);
	if (!logs) return;
	const cwd = ev.cwd || process.cwd();
	let plan = null;
	try {
		plan =
			fs
				.readdirSync(path.join(ai || logs, "plans"))
				.filter((f) => f.endsWith(".md"))
				.sort()
				.pop() || null;
	} catch {}
	appendJsonl(path.join(logs, "runs", "sessions.jsonl"), {
		session_id: ev.session_id,
		ts: new Date().toISOString(),
		user: user(cwd),
		branch: branch(cwd),
		plan_in_flight: plan,
	});
});
