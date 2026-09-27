#!/usr/bin/env node
const { readEvent, aiDir, user, branch, fs, path } = require("./_common");
const { claims, sumTranscript, price } = require("./_usage");
const ev = readEvent(); const ai = aiDir(ev); if (!ai) process.exit(0);
const cwd = ev.cwd || process.cwd();
if (!ev.transcript_path || !fs.existsSync(ev.transcript_path)) process.exit(0);

// The session's claim ledger, shared with the subagent rows so a record copied into an agent
// transcript is counted once across the two kinds of row. Claims are RECORDED here and not yet
// enforced against this row: `has` answers false, so the session row is still the cumulative
// snapshot it has always been. Turning it into the increment is the next change, and it is the
// one line below — the ledger passed in place of this wrapper.
const ledger = claims(ai, ev.session_id);
const { turns, inp, out, cr, cw, model } =
  sumTranscript(ev.transcript_path, { has: () => false, add: k => ledger.add(k) });
if (turns === 0) process.exit(0);

const { rate, approx } = price(ai, model);
const cost = (inp * rate.input + out * rate.output + cr * rate.cache_read + cw * rate.cache_write) / 1e6;
const hit = (cr / (inp + cr + cw || 1)).toFixed(2);

// Rows go to log.pending.csv, which is gitignored, not to the committed log.csv. A Stop fires
// after every turn, so writing straight into a tracked file kept it dirty for the whole session
// and refused every `git checkout`. log-flush.js moves the rows into log.csv when the session
// commits, so the log changes only inside the commit that produced the work.
const { ensureSchema, csv } = require("./_log-schema");
const file = path.join(ai, "runs", "log.pending.csv");
try {
  ensureSchema(file);
  fs.appendFileSync(file, [
    new Date().toISOString(), ev.session_id, "session", user(cwd), branch(cwd),
    // `agent` is empty on a session row: the subagent rows carry their own name.
    "", "claude", "", model, turns, inp, out, cr, cw, hit, approx + cost.toFixed(4), "",
  ].map(csv).join(",") + "\n");
} catch {}
