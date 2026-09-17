#!/usr/bin/env node
// ai/runs/log.csv schema, shared by the two plugin-side scripts that touch the run log:
// session-stop.js (writes a row to log.pending.csv) and log-flush.js (moves pending rows into
// log.csv). The headless writer, templates/ai/make/log.js, runs inside an adopted repo and
// cannot require this file, so it carries a byte-identical copy of the guard below;
// fixtures/check-log-schema.sh pins the two copies together.
const fs = require("fs");
const path = require("path");

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
  fs.appendFileSync(prev, `# ${new Date().toISOString()} moved out of ${path.basename(file)}: not ${COLS} fields\n${move.join("\n")}\n`);
  fs.writeFileSync(file, [HEADER, ...keep].join("\n") + "\n");
}
// --- end shared schema guard ---

const csv = v => { const s = String(v ?? ""); return /[",\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s; };

module.exports = { HEADER, COLS, records, width, ensureSchema, csv };
