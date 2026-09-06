#!/usr/bin/env node
const { readEvent, aiDir, appendJsonl, path } = require("./_common");
const ev = readEvent(); const ai = aiDir(ev); if (!ai) process.exit(0);
const cmd = String(ev.tool_input?.command || "");
if (!/\b(vitest|biome|playwright|jest|tsc|(pnpm|npm|yarn)\s+(run\s+)?(test|lint|e2e|check|type-check|typecheck)(:\w+)?)\b/.test(cmd)) process.exit(0);
appendJsonl(path.join(ai, "runs", "cmds.jsonl"), { session_id: ev.session_id, ts: new Date().toISOString(), cmd: cmd.slice(0, 200) });
