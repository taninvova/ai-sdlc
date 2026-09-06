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

const [file, task, tool, model] = process.argv.slice(2);
const run = JSON.parse(fs.readFileSync(file, "utf8"));
const u = run.usage ?? {};
const inp = u.input_tokens ?? 0, out = u.output_tokens ?? 0;
const cr = u.cache_read_input_tokens ?? 0, cw = u.cache_creation_input_tokens ?? 0;
const hit = (cr / (inp + cr + cw || 1)).toFixed(2);

ensureHeader(path.join(path.dirname(file), "log.csv"));
process.stdout.write([
  new Date().toISOString(), run.session_id ?? "", "make",
  process.env.GITLAB_USER || sh("git config user.name") || "unknown",
  sh("git rev-parse --abbrev-ref HEAD"),
  task, tool, model || run.model || "",
  run.num_turns ?? "", inp, out, cr, cw, hit, run.total_cost_usd ?? "", "",
].map(csv).join(",") + "\n");
