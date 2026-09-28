#!/usr/bin/env node
// Reads ai-factory/runs/log.csv for `make cost` and classifies what it finds. Read-only over the
// log: nothing here creates, modifies, moves or deletes a file. `log.previous.csv` is never read —
// the rows quarantined there are cumulative snapshots from before spec 0007's collection change,
// and reading them would reinterpret them.
// This file runs inside an adopted repo, so it cannot require the plugin's
// skills/ai-hooks/scripts/_log-schema.js; it carries a byte-identical copy of the record-reading
// pair below, and fixtures/check-log-schema.sh pins the copies together.
const fs = require("fs");

// --- shared schema guard: the records()/width() pair, byte-identical with the two writers, pinned by fixtures/check-log-schema.sh ---
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
// --- end shared schema guard ---

// The inverse of the writers' csv(): a quoted field keeps its commas and newlines, and a doubled
// quote inside one is a single quote. Only called on a record width() could measure.
function fields(rec) {
  const out = []; let cur = "", q = false;
  for (let i = 0; i < rec.length; i++) {
    const c = rec[i];
    if (q) {
      if (c === '"') { if (rec[i + 1] === '"') { cur += '"'; i++; } else q = false; }
      else cur += c;
    } else if (c === '"') q = true;
    else if (c === ",") { out.push(cur); cur = ""; }
    else cur += c;
  }
  out.push(cur);
  return out;
}

// By NAME, never by position. Spec 0007 inserts `agent` as the eighth column, not the last, so a
// reader that counted to a fixed index would read `accepted` where it meant `agent`. A column the
// header does not carry is absent, not an error: field() answers "" for it.
function row(names, rec) {
  const vals = fields(rec);
  const o = Object.create(null);
  for (let i = 0; i < names.length; i++) o[names[i]] = vals[i] ?? "";
  return o;
}
const field = (r, name) => (r && name in r ? r[name] : "");

// Three outcomes per record, and no fourth. A record as wide as the header conforms. A record of
// any other width is excluded from every total and counted — which is also what makes a pre-0007
// cumulative row harmless, since a 16-field row under a 17-column header is exactly that, so no
// detector for it exists here and none may be added. A record width() cannot measure at all
// (an unclosed quote) is unreadable and likewise excluded and counted.
function readLog(file) {
  const out = { file, exists: false, header: "", names: [], columns: 0, rows: [], wrongWidth: [], unreadable: [], counts: { records: 0, conforming: 0, wrongWidth: 0, unreadable: 0 } };
  let body;
  try { body = fs.readFileSync(file, "utf8"); } catch { return out; }
  out.exists = true;
  const recs = records(body).filter(r => r.trim() !== "");
  if (!recs.length) return out;
  const head = recs[0];
  out.header = head;
  out.columns = width(head);
  out.names = out.columns === -1 ? [] : fields(head);
  if (out.columns === -1) {                 // an unmeasurable header: every row below it too
    out.unreadable = recs.slice(1);
    out.counts.records = recs.length - 1;
    out.counts.unreadable = out.unreadable.length;
    return out;
  }
  for (const rec of recs.slice(1)) {
    const w = width(rec);
    if (w === -1) out.unreadable.push(rec);
    else if (w === out.columns) out.rows.push(row(out.names, rec));
    else out.wrongWidth.push(rec);
  }
  out.counts.records = recs.length - 1;
  out.counts.conforming = out.rows.length;
  out.counts.wrongWidth = out.wrongWidth.length;
  out.counts.unreadable = out.unreadable.length;
  return out;
}

// --- aggregation ------------------------------------------------------------------------------

// The bucket for a row that cannot be attributed on some dimension. A literal, not an empty
// string: "" as a group key is indistinguishable from a branch or task legitimately named "",
// and AC11 requires unattributed spend to be named rather than folded into another group.
const UNATTRIBUTED = "(unattributed)";

// The dimensions the spec names, each reading the column of the same name — except `session`,
// which reads `session_id`, and `day`, which the log has no column for and which is derived.
const DIMENSIONS = ["task", "agent", "tool", "model", "branch", "user", "day", "session"];

// `cost_usd` is never read, by the decision of 2026-09-27: this feature reports tokens and turns,
// and a fleet view that wants money prices the token counts itself.
const METRICS = ["turns", "input_tokens", "output_tokens", "cache_read_tokens", "cache_write_tokens"];

// A field that should hold a number and does not contributes nothing, rather than poisoning a
// whole group's total with NaN.
const num = v => { const n = Number(v); return Number.isFinite(n) ? n : 0; };

// The date part of an ISO `ts`. A row whose `ts` is missing or is not a date cannot be placed on
// a day and is bucketed as unattributed, never dated today: spend recorded on a day that did not
// happen is worse than spend with no day.
function day(ts) {
  const s = String(ts ?? "");
  return /^\d{4}-\d{2}-\d{2}/.test(s) ? s.slice(0, 10) : UNATTRIBUTED;
}

function keyOf(r, dim) {
  if (dim === "day") return day(field(r, "ts"));
  const v = String(field(r, dim === "session" ? "session_id" : dim) ?? "");
  return v === "" ? UNATTRIBUTED : v;
}

// Recomputed from the summed tokens, NEVER averaged across rows. `hit_rate` is a ratio, and the
// mean of per-row ratios weights a ten-token row the same as a ten-million-token one — on this
// repo's own log those differ by six orders of magnitude. Same formula the writers use per row.
const hitRate = m =>
  m.cache_read_tokens / (m.input_tokens + m.cache_read_tokens + m.cache_write_tokens || 1);

const blank = key => {
  const m = { key, rows: 0 };
  for (const k of METRICS) m[k] = 0;
  m.hit_rate = 0;
  return m;
};

function accumulate(m, r) {
  m.rows++;
  for (const k of METRICS) m[k] += num(field(r, k));
  return m;
}

// One pass over the conforming rows, producing a group list per dimension plus the totals. Only
// rows the reader judged conforming are counted: a wrong-width or unreadable record reaches no
// total, and its count travels separately in `counts` so the two are never added together.
function aggregate(log) {
  const acc = Object.create(null);
  for (const dim of DIMENSIONS) acc[dim] = new Map();
  const totals = blank("(all)");
  let covered = 0;

  for (const r of log.rows) {
    accumulate(totals, r);
    // Coverage, not an average: AC12. How many rows carry a value at all, since the column is
    // hand-filled and usually empty.
    if (String(field(r, "accepted") ?? "") !== "") covered++;
    for (const dim of DIMENSIONS) {
      const k = keyOf(r, dim);
      acc[dim].set(k, accumulate(acc[dim].get(k) || blank(k), r));
    }
  }

  totals.hit_rate = hitRate(totals);
  const groups = Object.create(null);
  for (const dim of DIMENSIONS) {
    const list = [...acc[dim].values()];
    for (const m of list) m.hit_rate = hitRate(m);
    // Sorted by key so the same log yields the same order every run. Ordering for a reader's eye
    // belongs to whatever renders this, not here.
    list.sort((a, b) => (a.key < b.key ? -1 : a.key > b.key ? 1 : 0));
    groups[dim] = list;
  }

  return {
    file: log.file,
    exists: log.exists,
    columns: log.columns,
    counts: { ...log.counts },   // records · conforming · wrongWidth · unreadable, kept distinct
    totals,
    // AC12: the count and the denominator, so a caller can say "3 of 412" and never an average.
    accepted: { covered, of: log.rows.length },
    dimensions: DIMENSIONS.slice(),
    metrics: METRICS.slice(),
    unattributed: UNATTRIBUTED,
    // AC4: `session` is a dimension like any other, so every session_id survives into whatever is
    // exported — which is what lets a fleet view spot one session written to two layouts' logs.
    groups,
  };
}

module.exports = { records, width, fields, row, field, readLog, aggregate, day, UNATTRIBUTED, DIMENSIONS, METRICS };
