#!/usr/bin/env node
const { readEvent, aiDir, appendJsonl, path } = require("./_common");
const ev = readEvent(); const ai = aiDir(ev); if (!ai) process.exit(0);
const file = ev.tool_input?.file_path || ev.tool_input?.path || ev.tool_input?.notebook_path;
if (!file) process.exit(0);
appendJsonl(path.join(ai, "runs", "edits.jsonl"), { session_id: ev.session_id, ts: new Date().toISOString(), tool: ev.tool_name, file });
