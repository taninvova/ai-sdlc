#!/usr/bin/env node
// ai/.sdlc.json — the record of which ai-sdlc layout an adopted repo holds, and the drift
// check that reads it. Design: ai/designs/0001-layout-version-and-drift.md.
//
//   manifest.js write <repo-root> <plugin-root> [--overlay name=version]
//   manifest.js check <repo-root> <plugin-root>
//
// Two hashes per file, not one. /t4:adopt-sdlc substitutes {{app}}, {{stack}} and friends, so a
// repo file never equals its template. `received` is what landed in the repo (detects local
// edits); `template` is the template it came from (detects upstream change). Comparing a
// repo file to a template directly would report every substituted file as modified forever.
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const SCHEMA = 1;
const MANIFEST = "ai/.sdlc.json";
// Volatile or per-project by nature — tracking them would report drift on every run.
const SKIP = [/^ai\/runs\//, /(^|\/)\.gitkeep$/, /(^|\/)\.DS_Store$/];

const sha = b => "sha256:" + crypto.createHash("sha256").update(b).digest("hex");
const rel = (root, p) => path.relative(root, p).split(path.sep).join("/");

function walk(dir, root = dir, out = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, e.name);
    if (e.isDirectory()) walk(full, root, out);
    else if (e.isFile()) { const r = rel(root, full); if (!SKIP.some(x => x.test(r))) out.push(r); }
  }
  return out;
}
const hashFile = f => { try { return sha(fs.readFileSync(f)); } catch { return null; } };

function templatesDir(pluginRoot) {
  const d = path.join(pluginRoot, "skills", "ai-layout", "templates");
  if (!fs.existsSync(d)) die(`no templates at ${d} — is ${pluginRoot} the ai-sdlc plugin root?`);
  return d;
}
function pluginVersion(pluginRoot) {
  try { return JSON.parse(fs.readFileSync(path.join(pluginRoot, ".claude-plugin", "plugin.json"), "utf8")).version || "unknown"; }
  catch { return "unknown"; }
}
function die(msg) { console.error(`manifest: ${msg}`); process.exit(2); }

// ai-sdlc's own repo symlinks ai/tasks, ai/agents and ai/make into the templates, so it is
// current by construction and must never carry a manifest.
// The plugin's own repo is where the templates come from, so it has no manifest and nothing to
// compare against. Path equality detects that only while the plugin is loaded from its working
// tree; once installed, pluginRoot is the cache, the paths differ, and the source repo looks
// like any other adopter — which is how a manifest got written into it. Identity is the durable
// test: a repo carrying this plugin's own name in its own plugin manifest IS this plugin.
const pluginName = root => {
  try { return JSON.parse(fs.readFileSync(path.join(root, ".claude-plugin", "plugin.json"), "utf8")).name || null; }
  catch { return null; }
};
const isPluginItself = (repoRoot, pluginRoot) => {
  if (path.resolve(repoRoot) === path.resolve(pluginRoot)) return true;
  const mine = pluginName(repoRoot);
  return mine !== null && mine === pluginName(pluginRoot);
};

function build(repoRoot, pluginRoot, prev) {
  const tdir = templatesDir(pluginRoot);
  const files = {};
  for (const r of walk(tdir)) {
    const inRepo = hashFile(path.join(repoRoot, r));
    if (!inRepo) continue;               // never received, or since deleted — not tracked
    files[r] = { received: inRepo, template: hashFile(path.join(tdir, r)) };
  }
  const today = new Date().toISOString().slice(0, 10);
  return {
    schema: SCHEMA, plugin: "ai-sdlc", version: pluginVersion(pluginRoot),
    adopted: prev?.adopted || today, updated: today,
    // Free-form and never written by ai-sdlc — an overlay owns its own block, which is how the
    // one-way dependency survives: ai-sdlc need not know any overlay exists.
    ...(prev?.overlay ? { overlay: prev.overlay } : {}),
    files,
  };
}

function readManifest(repoRoot) {
  try { return JSON.parse(fs.readFileSync(path.join(repoRoot, MANIFEST), "utf8")); } catch { return null; }
}

function cmdWrite(repoRoot, pluginRoot, args) {
  if (isPluginItself(repoRoot, pluginRoot)) { console.log("manifest: this is the ai-sdlc plugin itself — no manifest written."); return 0; }
  if (!fs.existsSync(path.join(repoRoot, "ai"))) die("no ai/ directory — run /t4:adopt-sdlc first");
  const prev = readManifest(repoRoot);
  const m = build(repoRoot, pluginRoot, prev);
  const ov = args.find(a => a.startsWith("--overlay="));
  if (ov) { const [name, version] = ov.slice(10).split("="); if (name) m.overlay = { name, version: version || "unknown" }; }
  fs.writeFileSync(path.join(repoRoot, MANIFEST), JSON.stringify(m, null, 2) + "\n");
  console.log(`manifest: wrote ${MANIFEST} — ai-sdlc ${m.version}, ${Object.keys(m.files).length} files tracked`);
  return 0;
}

function cmdCheck(repoRoot, pluginRoot) {
  if (isPluginItself(repoRoot, pluginRoot)) { console.log("layout: this is the ai-sdlc plugin itself — templates are the source, nothing to compare."); return 0; }
  const tdir = templatesDir(pluginRoot);
  const now = pluginVersion(pluginRoot);
  const m = readManifest(repoRoot);

  if (!m) {
    let guess = "";
    try { guess = (fs.readFileSync(path.join(repoRoot, "ai", "AGENTS.md"), "utf8").match(/ai-sdlc\s+([0-9]+\.[0-9]+\.[0-9]+)/) || [])[1] || ""; } catch {}
    console.log(`layout: no ${MANIFEST} — this repo was adopted before manifests existed.`);
    console.log(`  version: unknown${guess ? ` (ai/AGENTS.md says it was scaffolded with ${guess})` : ""} · plugin here: ${now}`);
    console.log(`  Drift cannot be computed without a baseline. To start one from the files as they`);
    console.log(`  stand now — which assumes they are correct — run:`);
    console.log(`    node "${path.join(pluginRoot, "skills/ai-layout/scripts/manifest.js")}" write . "${pluginRoot}"`);
    return 0;
  }
  if (m.schema > SCHEMA) {
    console.log(`layout: ${MANIFEST} is schema ${m.schema}; this plugin understands ${SCHEMA}.`);
    console.log("  The manifest is newer than the plugin. Update the plugin; nothing checked.");
    return 0;
  }

  const b = { upstream: [], local: [], both: [], added: [], removed: [], gone: [] };
  const tracked = m.files || {};
  for (const [r, h] of Object.entries(tracked)) {
    const repoNow = hashFile(path.join(repoRoot, r));
    const tplNow = hashFile(path.join(tdir, r));
    if (!repoNow) { b.gone.push(r); continue; }
    if (!tplNow) { b.removed.push(r); continue; }
    const localChanged = repoNow !== h.received;
    const upstreamChanged = tplNow !== h.template;
    if (localChanged && upstreamChanged) b.both.push(r);
    else if (upstreamChanged) b.upstream.push(r);
    else if (localChanged) b.local.push(r);
  }
  for (const r of walk(tdir)) if (!(r in tracked)) b.added.push(r);

  const head = `layout: repo has ai-sdlc ${m.version}${m.overlay ? ` + ${m.overlay.name} ${m.overlay.version}` : ""} · plugin here is ${now}`;
  console.log(m.version === now ? head : head + "  ← versions differ");
  const show = (list, label, note) => {
    if (!list.length) return;
    console.log(`\n  ${label} (${list.length}) — ${note}`);
    for (const r of list.sort()) console.log(`    ${r}`);
  };
  show(b.upstream, "upstream changed", "your copy is untouched, so it is safe to take");
  show(b.both,     "both changed",     "you edited it and so did upstream — merge by hand");
  show(b.local,    "locally modified", "yours; upstream has not moved since you adopted");
  show(b.added,    "new upstream",     "added to the templates since this repo adopted");
  show(b.removed,  "removed upstream", "no longer in the templates");
  show(b.gone,     "missing locally",  "received once, not in this repo now");
  const drifted = b.upstream.length + b.both.length + b.added.length + b.removed.length + b.gone.length;
  if (!drifted && !b.local.length) console.log("\n  up to date — every tracked file matches.");
  else if (!drifted) console.log("\n  up to date with upstream; the differences above are your own.");
  console.log("\n  Reported only — /t4:sync-sdlc changes nothing under ai/.");
  return 0;
}

const [cmd, repoRoot = ".", pluginRoot, ...rest] = process.argv.slice(2);
if (!pluginRoot) die("usage: manifest.js <write|check> <repo-root> <plugin-root> [--overlay=name=version]");
if (cmd === "write") process.exit(cmdWrite(repoRoot, pluginRoot, rest));
else if (cmd === "check") process.exit(cmdCheck(repoRoot, pluginRoot));
else die(`unknown command "${cmd}" — expected write or check`);
