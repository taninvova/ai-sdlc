const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

function readEvent() {
  try { return JSON.parse(fs.readFileSync(0, "utf8")); } catch { return {}; }
}
// The layout directory, by name, newest first. 1.0.0 renamed `ai/` to `ai-factory/`. A repo that
// has taken the plugin update and not yet run /t4:migrate-layout still carries the old name, and
// must keep its dont-touch guard and its run log until it does — a rename that silently disarmed
// the guard would look like nothing was wrong. Transitional, but not until 2.0.0: dropping it is
// itself a silent break for any repo that never migrated (ADR 0008).
const LAYOUT_DIRS = ["ai-factory", "ai"];
function aiDir(ev) {
  const cwd = ev.cwd || process.cwd();
  for (const name of LAYOUT_DIRS) {
    try { const dir = path.join(cwd, name); if (fs.existsSync(dir)) return dir; } catch {}
  }
  return null;
}
function sh(cmd, cwd) {
  try { return execSync(cmd, { cwd, stdio: ["ignore", "pipe", "ignore"] }).toString().trim(); } catch { return ""; }
}
function user(cwd) { return process.env.GITLAB_USER || sh("git config user.name", cwd) || "unknown"; }
function branch(cwd) { return sh("git rev-parse --abbrev-ref HEAD", cwd) || ""; }
function appendJsonl(file, obj) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.appendFileSync(file, JSON.stringify(obj) + "\n");
}
module.exports = { readEvent, aiDir, sh, user, branch, appendJsonl, fs, path };
