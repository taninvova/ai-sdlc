#!/usr/bin/env bash
# Every manifest that carries a version must carry the SAME version.
# .claude-plugin/plugin.json and marketplace.json drifted silently through 0.4.0 and 0.5.0,
# guarded only by a line in the definition of done. Codex support added a third field, so the
# checklist stopped being a reasonable defence. See ai-factory/adr/0003.
# Line 3 of docs/README.md ("> For fc ai-sdlc <version>.") is read as one more version (ASD-003).
set -euo pipefail
cd "$(dirname "$0")/../../.."
node -e '
const fs = require("fs");
const found = [];
const read = f => { try { return JSON.parse(fs.readFileSync(f, "utf8")); } catch { return null; } };
// Any manifest may be absent; only what exists is checked, so adding one is caught but a
// deliberate removal does not fail the build.
for (const f of [".claude-plugin/plugin.json", ".codex-plugin/plugin.json"]) {
  const j = read(f); if (j?.version) found.push([f, j.version]);
}
for (const f of [".claude-plugin/marketplace.json", ".agents/plugins/marketplace.json"]) {
  const j = read(f); if (!j) continue;
  for (const p of j.plugins ?? []) if (p.version) found.push([`${f} → ${p.name}`, p.version]);
}
// The user docs name the release on line 3 of docs/README.md (ASD-003, R5), so a release bumps it
// with the manifests. A line 3 that is not "> For fc ai-sdlc <version>." is recorded as found,
// quoted, and fails like any other disagreement. A repo without docs/README.md skips this row.
let docs = null;
try { docs = fs.readFileSync("docs/README.md", "utf8"); } catch {}
const manifests = found.length;
if (docs !== null) {
  const line = docs.split(/\r?\n/)[2] ?? "";
  const m = /^> For fc ai-sdlc (\S+)\.$/.exec(line);
  if (m) found.push(["docs/README.md (line 3)", m[1]]);
  else found.push(["docs/README.md (line 3, expected \"> For fc ai-sdlc <version>.\")", JSON.stringify(line)]);
}
if (manifests < 2) { console.error("check-versions: found " + manifests + " manifest version fields; expected at least 2"); process.exit(1); }
const versions = [...new Set(found.map(([, v]) => v))];
if (versions.length > 1) {
  console.error("FAIL: manifests and docs/README.md disagree on the version");
  for (const [f, v] of found) console.error(`  ${v}  ${f}`);
  process.exit(1);
}
console.log(`versions ok — ${manifests} manifests${docs !== null ? " and docs/README.md" : ""} all at ${versions[0]}`);
'
