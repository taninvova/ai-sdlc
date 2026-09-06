#!/usr/bin/env node
// Appends one CSV line for a headless run: ts,run_id,task,tool,model,input,output,cache_read,cache_write,hit_rate,cost_usd,accepted
const fs = require("fs");
const [file, task, tool, model] = process.argv.slice(2);
const run = JSON.parse(fs.readFileSync(file, "utf8"));
const u = run.usage ?? {};
const inp = u.input_tokens ?? 0, out = u.output_tokens ?? 0, cr = u.cache_read_input_tokens ?? 0, cw = u.cache_creation_input_tokens ?? 0;
const hit = (cr / (inp + cr + cw || 1)).toFixed(2);
const cost = run.total_cost_usd ?? "";
process.stdout.write([new Date().toISOString(), run.session_id ?? "", task, tool, model, inp, out, cr, cw, hit, cost, ""].join(",") + "\n");
