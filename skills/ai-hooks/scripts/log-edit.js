#!/usr/bin/env node
require("./_common").runHook(() => {
	const { readEvent, aiDir, appendJsonl, path } = require("./_common");
	const ev = readEvent();
	const ai = aiDir(ev);
	if (!ai) return;
	const file =
		ev.tool_input?.file_path ||
		ev.tool_input?.path ||
		ev.tool_input?.notebook_path;
	if (!file) return;
	appendJsonl(path.join(ai, "runs", "edits.jsonl"), {
		session_id: ev.session_id,
		ts: new Date().toISOString(),
		tool: ev.tool_name,
		file,
	});
});
