#!/usr/bin/env node
// rewrite-paths.js <file>... — rewrites pre-1.0.0 layout paths to ai-factory/ ones, in place.
// Path strings and nothing else: migrate-layout.sh calls it, and ADR 0008 bounds the migration to
// exactly this. Prints the files it changed, one per line.
//
// Guarding the match matters more here than in the plugin's own repo, because this runs in
// someone else's: a preceding "/" excludes a segment that only looks like the layout (src/ai/,
// app/specs/, vendor/docs/adr), and a preceding ":" excludes a git remote such as
// git@host:ai/repo.git — which is exactly how a URL was corrupted when this rename was first done
// by hand. `specs/` already carrying the ai-factory/ prefix is left alone so the pass is
// repeatable: running it twice changes nothing the second time.
const fs = require("fs");

const B = "(?<![-A-Za-z0-9_./:])";
const RULES = [
  [new RegExp(B + "(?<!ai-factory/)specs/", "g"), "ai-factory/specs/"],
  [new RegExp(B + "(?<!ai-factory/)docs/adr", "g"), "ai-factory/adr"],
  [new RegExp(B + "ai/", "g"), "ai-factory/"],
];

function rewrite(text) {
  let out = text;
  for (const [re, to] of RULES) out = out.replace(re, to);
  return out;
}

if (require.main === module) {
  const changed = [];
  for (const f of process.argv.slice(2)) {
    let s;
    try { s = fs.readFileSync(f); } catch { continue; }
    if (s.includes(0)) continue;                      // a NUL byte: binary, never touched
    const text = s.toString("utf8");
    const next = rewrite(text);
    if (next !== text) { fs.writeFileSync(f, next); changed.push(f); }
  }
  if (changed.length) console.log(changed.join("\n"));
}

module.exports = { rewrite };
