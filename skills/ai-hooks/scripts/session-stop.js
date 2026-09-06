#!/usr/bin/env node
const { readEvent, aiDir, user, branch, fs, path } = require("./_common");
const ev = readEvent(); const ai = aiDir(ev); if (!ai) process.exit(0);
const cwd = ev.cwd || process.cwd();
if (!ev.transcript_path || !fs.existsSync(ev.transcript_path)) process.exit(0);

let inp = 0, out = 0, cr = 0, cw = 0, turns = 0;
for (const line of fs.readFileSync(ev.transcript_path, "utf8").split("\n")) {
  if (!line.trim()) continue;
  let r; try { r = JSON.parse(line); } catch { continue; }
  const u = r.message?.usage || r.usage; if (!u) continue;
  turns++;
  inp += u.input_tokens ?? 0; out += u.output_tokens ?? 0;
  cr += u.cache_read_input_tokens ?? 0; cw += u.cache_creation_input_tokens ?? 0;
}
if (turns === 0) process.exit(0);

let price = { input: 3, output: 15, cache_read: 0.3, cache_write: 3.75 }, approx = "~";
try {
  const y = fs.readFileSync(path.join(ai, "models.yaml"), "utf8");
  const m = y.match(/default:\s*\{([^}]*)\}/);
  if (m) { const o = {}; for (const kv of m[1].split(",")) { const [k, v] = kv.split(":").map(s => s.trim()); if (k && v) o[k] = Number(v); } price = { ...price, ...o }; approx = ""; }
} catch {}
const cost = (inp * price.input + out * price.output + cr * price.cache_read + cw * price.cache_write) / 1e6;
const hit = (cr / (inp + cr + cw || 1)).toFixed(2);

const file = path.join(ai, "runs", "log.csv");
if (!fs.existsSync(file)) fs.writeFileSync(file, "ts,session_id,user,branch,turns,input_tokens,output_tokens,cache_read_tokens,cache_write_tokens,hit_rate,cost_usd,accepted\n");
fs.appendFileSync(file, [new Date().toISOString(), ev.session_id, user(cwd), branch(cwd), turns, inp, out, cr, cw, hit, approx + cost.toFixed(4), ""].join(",") + "\n");
