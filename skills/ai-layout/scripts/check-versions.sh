#!/usr/bin/env bash
# Every manifest that carries a version must carry the SAME version.
# .claude-plugin/plugin.json and marketplace.json drifted silently through 0.4.0 and 0.5.0,
# guarded only by a line in the definition of done. Codex support added a third field, so the
# checklist stopped being a reasonable defence. See docs/adr/0003.
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
if (found.length < 2) { console.error("check-versions: found " + found.length + " version fields; expected at least 2"); process.exit(1); }
const versions = [...new Set(found.map(([, v]) => v))];
if (versions.length > 1) {
  console.error("FAIL: manifests disagree on the version");
  for (const [f, v] of found) console.error(`  ${v}  ${f}`);
  process.exit(1);
}
console.log(`versions ok — ${found.length} manifests all at ${versions[0]}`);
'
