#!/usr/bin/env node
// Token accounting shared by the two plugin-side scripts that write a row carrying tokens:
// session-stop.js (one row per Stop, from the session transcript) and subagent-stop.js (one row
// per concluded subagent, from that agent's own transcript). Three things live here because both
// need all three and a second copy of any of them would drift: the sum over a JSONL transcript,
// the per-session claim ledger that keeps a record counted once however many transcripts carry a
// copy of it, and the models.yaml price resolution.
//
// Nothing here prints, and every filesystem touch is guarded: a hook that throws on a malformed
// transcript would surface as a failed turn.
const fs = require("fs");
const path = require("path");

// A newline-delimited ledger of what this session has already counted, kept beside the run log
// as `.counted.<session_id>` and gitignored. Two kinds of claim share it: `u:<message uuid>` for
// one usage record and `a:<agent id>` for a whole concluded subagent.
//
// Appended, never rewritten, one short line at a time — two subagents concluding at once would
// lose each other's claims to a read-modify-write. The file is created on the first claim rather
// than on the first read, so a session whose transcript carries no uuid leaves no state behind.
function claims(ai, sessionId) {
  const file = path.join(ai, "runs", ".counted." + (sessionId || "unknown"));
  const seen = new Set();
  try {
    for (const line of fs.readFileSync(file, "utf8").split("\n")) if (line) seen.add(line);
  } catch {}
  return {
    file,
    has: k => seen.has(k),
    // True when this call is what claimed `k`, false when it was already claimed.
    add(k) {
      if (seen.has(k)) return false;
      seen.add(k);
      try {
        fs.mkdirSync(path.dirname(file), { recursive: true });
        fs.appendFileSync(file, k + "\n");
      } catch {}
      return true;
    },
  };
}

// Sum one JSONL transcript's usage records into {turns, inp, out, cr, cw, model}.
//
// `claim` is optional. Given a ledger, a record whose `uuid` is already claimed is skipped whole
// — its turn as well as its tokens, so `turns` stays summable alongside the token columns — and
// every record that is counted claims its own `uuid`. A record carrying no `uuid` cannot be
// de-duplicated at all, so it is counted and never claimed: over-counting on a transcript format
// that omits the key is a better failure than silently losing the tokens.
function sumTranscript(file, claim) {
  const t = { turns: 0, inp: 0, out: 0, cr: 0, cw: 0, model: "" };
  let body;
  try { body = fs.readFileSync(file, "utf8"); } catch { return t; }
  for (const line of body.split("\n")) {
    if (!line.trim()) continue;
    let r; try { r = JSON.parse(line); } catch { continue; }
    const u = r.message?.usage || r.usage; if (!u) continue;
    const id = r.uuid || r.message?.uuid;
    if (claim && id) {
      if (claim.has("u:" + id)) continue;
      claim.add("u:" + id);
    }
    t.turns++;
    if (r.message?.model || r.model) t.model = r.message?.model || r.model;
    t.inp += u.input_tokens ?? 0; t.out += u.output_tokens ?? 0;
    t.cr += u.cache_read_input_tokens ?? 0; t.cw += u.cache_creation_input_tokens ?? 0;
  }
  return t;
}

// Price the run with the model it actually used, so any provider costs correctly: exact model
// id, then the longest id it starts with, then `default`. No match leaves the built-in Anthropic
// figures in place and returns the "~" marker, which the caller prefixes to the cost to say the
// number is an estimate.
function price(ai, model) {
  const id = String(model ?? "");
  let rate = { input: 3, output: 15, cache_read: 0.3, cache_write: 3.75 }, approx = "~";
  try {
    const y = fs.readFileSync(path.join(ai, "models.yaml"), "utf8");
    const table = {};
    for (const m of y.matchAll(/^[ \t]*([A-Za-z0-9._:\/-]+):[ \t]*\{([^}]*)\}/gm)) {
      const o = {};
      for (const kv of m[2].split(",")) { const [k, v] = kv.split(":").map(s => s.trim()); if (k && v) o[k] = Number(v); }
      table[m[1]] = o;
    }
    const prefix = Object.keys(table)
      .filter(k => k !== "default" && id.startsWith(k))
      .sort((a, b) => b.length - a.length)[0];
    const chosen = table[id] || (prefix && table[prefix]) || table.default;
    if (chosen) { rate = { ...rate, ...chosen }; approx = ""; }
  } catch {}
  return { rate, approx };
}

module.exports = { claims, sumTranscript, price };
