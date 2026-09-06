const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

function readEvent() {
  try { return JSON.parse(fs.readFileSync(0, "utf8")); } catch { return {}; }
}
function aiDir(ev) {
  const cwd = ev.cwd || process.cwd();
  const dir = path.join(cwd, "ai");
  return fs.existsSync(dir) ? dir : null;
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
