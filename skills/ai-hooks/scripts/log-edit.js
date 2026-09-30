#!/usr/bin/env node
require("./_common").runHook(() => {
	const { readEvent, aiDir, appendJsonl, path } = require("./_common");
	const ev = readEvent();
	const ai = aiDir(ev);
	if (!ai) return;
	for (const file of require("./_edit-targets").editTargets(ev)) {
		appendJsonl(path.join(ai, "runs", "edits.jsonl"), {
			session_id: ev.session_id,
			ts: new Date().toISOString(),
			tool: ev.tool_name,
			file,
		});
	}
});
