#!/usr/bin/env node
// PreToolUse on Bash. When the session is about to run `git commit`, move the rows that
// session-stop.js buffered in ai/runs/log.pending.csv into the committed ai/runs/log.csv and
// stage it, so the rows land in the commit that produced the work. Any other command: no-op.
//
// The pending file exists because log.csv is tracked: a Stop fires after every turn, and a
// tracked file that changes every turn is dirty for the whole session, which refuses every
// `git checkout`. Buffering makes log.csv change only here, on the way into a commit.
//
// A commit made outside a session does not pass through this hook; `make log-flush` does the
// same move from a terminal, and rows never flushed simply wait for the next commit.
const { readEvent, aiDir, sh, fs, path } = require("./_common");
const { HEADER, COLS, records, width, ensureSchema } = require("./_log-schema");

const ev = readEvent(); const ai = aiDir(ev); if (!ai) process.exit(0);
const cmd = String(ev.tool_input?.command || "");
// `git commit`, allowing global options between the two words (`git -C dir commit`,
// `git -c user.name=x commit`). A dry run commits nothing, so it flushes nothing.
if (!/\bgit\s+(?:-[cC]\s+\S+\s+|--\S+\s+)*commit\b/.test(cmd) || /--dry-run\b/.test(cmd)) process.exit(0);

const cwd = ev.cwd || process.cwd();
const pending = path.join(ai, "runs", "log.pending.csv");
const log = path.join(ai, "runs", "log.csv");
try {
  if (!fs.existsSync(pending)) process.exit(0);
  ensureSchema(pending);
  const rows = records(fs.readFileSync(pending, "utf8")).slice(1).filter(r => r.trim() && width(r) === COLS);
  if (rows.length) {
    ensureSchema(log);
    const body = fs.readFileSync(log, "utf8");
    fs.appendFileSync(log, (body.endsWith("\n") || !body ? "" : "\n") + rows.join("\n") + "\n");
    sh(`git add -- ${JSON.stringify(path.relative(cwd, log))}`, cwd);
  }
  fs.unlinkSync(pending);
} catch {}
