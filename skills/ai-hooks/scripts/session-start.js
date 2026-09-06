#!/usr/bin/env node
const { readEvent, aiDir, user, branch, appendJsonl, fs, path } = require("./_common");
const ev = readEvent(); const ai = aiDir(ev); if (!ai) process.exit(0);
const cwd = ev.cwd || process.cwd();
let plan = null;
try {
  plan = fs.readdirSync(path.join(ai, "plans")).filter(f => f.endsWith(".md")).sort().pop() || null;
} catch {}
appendJsonl(path.join(ai, "runs", "sessions.jsonl"), {
  session_id: ev.session_id, ts: new Date().toISOString(), user: user(cwd), branch: branch(cwd), plan_in_flight: plan
});
