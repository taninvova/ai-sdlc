#!/usr/bin/env node
const { readEvent, aiDir, user, branch, fs, path } = require("./_common");
const ev = readEvent(); const ai = aiDir(ev); if (!ai) process.exit(0);
const cwd = ev.cwd || process.cwd();
if (!ev.transcript_path || !fs.existsSync(ev.transcript_path)) process.exit(0);

let inp = 0, out = 0, cr = 0, cw = 0, turns = 0, model = "";
for (const line of fs.readFileSync(ev.transcript_path, "utf8").split("\n")) {
  if (!line.trim()) continue;
  let r; try { r = JSON.parse(line); } catch { continue; }
  const u = r.message?.usage || r.usage; if (!u) continue;
  turns++;
  if (r.message?.model || r.model) model = r.message?.model || r.model;
  inp += u.input_tokens ?? 0; out += u.output_tokens ?? 0;
  cr += u.cache_read_input_tokens ?? 0; cw += u.cache_creation_input_tokens ?? 0;
}
if (turns === 0) process.exit(0);

// Price the run with the model it actually used, so any provider costs correctly:
// exact model id, then the longest id it starts with, then `default`. No match leaves the
// built-in Anthropic figures in place and marks the cost "~" as an estimate.
let price = { input: 3, output: 15, cache_read: 0.3, cache_write: 3.75 }, approx = "~";
try {
  const y = fs.readFileSync(path.join(ai, "models.yaml"), "utf8");
  const table = {};
  for (const m of y.matchAll(/^[ \t]*([A-Za-z0-9._:\/-]+):[ \t]*\{([^}]*)\}/gm)) {
    const o = {};
    for (const kv of m[2].split(",")) { const [k, v] = kv.split(":").map(s => s.trim()); if (k && v) o[k] = Number(v); }
    table[m[1]] = o;
  }
  const prefix = Object.keys(table)
    .filter(k => k !== "default" && model.startsWith(k))
    .sort((a, b) => b.length - a.length)[0];
  const chosen = table[model] || (prefix && table[prefix]) || table.default;
  if (chosen) { price = { ...price, ...chosen }; approx = ""; }
} catch {}
const cost = (inp * price.input + out * price.output + cr * price.cache_read + cw * price.cache_write) / 1e6;
const hit = (cr / (inp + cr + cw || 1)).toFixed(2);

// Same columns as the headless writer, ai/make/log.js. Change one, change both.
const HEADER = "ts,session_id,source,user,branch,task,tool,model,turns,input_tokens,output_tokens,cache_read_tokens,cache_write_tokens,hit_rate,cost_usd,accepted";

// --- shared schema guard: byte-identical in both writers, pinned by fixtures/check-log-schema.sh ---
const COLS = HEADER.split(",").length;
// Records, not lines: csv() quotes any field holding a comma or a newline, so a line-based
// read would tear one row in two and then judge both of the halves malformed.
function records(body) {
  const out = []; let cur = null, q = false;
  for (const line of body.split("\n")) {
    cur = cur === null ? line : cur + "\n" + line;
    for (let i = 0; i < line.length; i++) {
      const c = line[i];
      if (q) { if (c === '"') { if (line[i + 1] === '"') i++; else q = false; } }
      else if (c === '"') q = true;
    }
    if (!q) { out.push(cur); cur = null; }
  }
  if (cur !== null) out.push(cur);
  return out;
}
// Commas inside quotes do not separate fields. An unclosed quote is not a row that can be
// measured at all, so it reports -1 and gets moved aside rather than counted as some width.
function width(rec) {
  let n = 1, q = false;
  for (let i = 0; i < rec.length; i++) {
    const c = rec[i];
    if (q) { if (c === '"') { if (rec[i + 1] === '"') i++; else q = false; } }
    else if (c === '"') q = true;
    else if (c === ",") n++;
  }
  return q ? -1 : n;
}
// Two ways the file goes wrong, one remedy. A header from an older schema means the whole
// file predates this one — move every row. A header that matches with rows that do not means
// a writer still on an older schema appended into a current file; the header check cannot see
// that, which is how twelve-field rows sat under a sixteen-field header. Move just those.
// Nothing is reinterpreted into the new columns: the shape is not enough to tell which writer
// produced a row, and guessing is how the original mixed-schema bug started.
function ensureSchema(file) {
  const prev = path.join(path.dirname(file), "log.previous.csv");
  fs.mkdirSync(path.dirname(file), { recursive: true });
  if (!fs.existsSync(file)) { fs.writeFileSync(file, HEADER + "\n"); return; }
  const body = fs.readFileSync(file, "utf8");
  if (body.split("\n")[0] !== HEADER) {
    fs.appendFileSync(prev, body);
    fs.writeFileSync(file, HEADER + "\n");
    return;
  }
  const keep = [], move = [];
  for (const r of records(body).slice(1)) {
    if (!r.trim()) continue;
    (width(r) === COLS ? keep : move).push(r);
  }
  if (!move.length) return;
  fs.appendFileSync(prev, `# ${new Date().toISOString()} moved out of log.csv: not ${COLS} fields\n${move.join("\n")}\n`);
  fs.writeFileSync(file, [HEADER, ...keep].join("\n") + "\n");
}
// --- end shared schema guard ---

const file = path.join(ai, "runs", "log.csv");
try {
  ensureSchema(file);
  const csv = v => { const s = String(v ?? ""); return /[",\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s; };
  fs.appendFileSync(file, [
    new Date().toISOString(), ev.session_id, "session", user(cwd), branch(cwd),
    "", "claude", model, turns, inp, out, cr, cw, hit, approx + cost.toFixed(4), "",
  ].map(csv).join(",") + "\n");
} catch {}
