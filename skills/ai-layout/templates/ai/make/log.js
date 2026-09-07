#!/usr/bin/env node
// Appends one row for a headless run (make ai) to ai/runs/log.csv.
// The interactive path — skills/ai-hooks/scripts/session-stop.js — writes the SAME columns.
// If you change HEADER here, change it there too; the fixture test pins them together.
const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

const HEADER = "ts,session_id,source,user,branch,task,tool,model,turns,input_tokens,output_tokens,cache_read_tokens,cache_write_tokens,hit_rate,cost_usd,accepted";

// A file whose header is not HEADER predates the single schema. Its rows came from two
// writers with different column meanings and cannot be reinterpreted safely, so move them
// aside rather than guess: nothing is lost and nothing is mixed.
function ensureHeader(file) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  if (!fs.existsSync(file)) { fs.writeFileSync(file, HEADER + "\n"); return; }
  const body = fs.readFileSync(file, "utf8");
  if (body.split("\n")[0] === HEADER) return;
  fs.appendFileSync(path.join(path.dirname(file), "log.previous.csv"), body);
  fs.writeFileSync(file, HEADER + "\n");
}

function sh(cmd) {
  try { return execSync(cmd, { stdio: ["ignore", "pipe", "ignore"] }).toString().trim(); } catch { return ""; }
}
const csv = v => { const s = String(v ?? ""); return /[",\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s; };

// Two output shapes. claude -p --output-format json writes one object with `usage` and
// `total_cost_usd`. codex exec --json writes JSONL events: `thread.started` carries the id,
// each `turn.completed` carries usage. Sniffed, not configured, so the file speaks for itself.
function parseRun(text) {
  const t = text.trim();
  try {
    const o = JSON.parse(t);
    const u = o.usage ?? {};
    return { id: o.session_id ?? "", turns: o.num_turns ?? "", cost: o.total_cost_usd ?? "",
             inp: u.input_tokens ?? 0, out: u.output_tokens ?? 0,
             cr: u.cache_read_input_tokens ?? 0, cw: u.cache_creation_input_tokens ?? 0 };
  } catch {}
  const r = { id: "", turns: 0, cost: "", inp: 0, out: 0, cr: 0, cw: 0 };
  for (const line of t.split("\n")) {
    if (!line.trim()) continue;
    let e; try { e = JSON.parse(line); } catch { continue; }
    if (e.type === "thread.started" && e.thread_id) r.id = e.thread_id;
    if (e.type === "turn.completed" && e.usage) {
      const u = e.usage;
      r.turns++;
      // codex reports input_tokens INCLUSIVE of cached ones (the OpenAI convention), while
      // claude reports them separately. Subtract so the column means the same in both rows.
      const cached = u.cached_input_tokens ?? 0;
      r.inp += Math.max(0, (u.input_tokens ?? 0) - cached);
      r.cr += cached;
      r.cw += u.cache_write_input_tokens ?? 0;
      // output_tokens already includes reasoning_output_tokens.
      r.out += u.output_tokens ?? 0;
    }
  }
  return r;   // cost stays "" — codex reports none, and a guessed price is worse than none
}

const [file, task, tool, model] = process.argv.slice(2);
const run = parseRun(fs.readFileSync(file, "utf8"));
const { inp, out, cr, cw } = run;
const hit = (cr / (inp + cr + cw || 1)).toFixed(2);

ensureHeader(path.join(path.dirname(file), "log.csv"));
process.stdout.write([
  new Date().toISOString(), run.id, "make",
  process.env.GITLAB_USER || sh("git config user.name") || "unknown",
  sh("git rev-parse --abbrev-ref HEAD"),
  task, tool, model || "",
  run.turns, inp, out, cr, cw, hit, run.cost, "",
].map(csv).join(",") + "\n");
