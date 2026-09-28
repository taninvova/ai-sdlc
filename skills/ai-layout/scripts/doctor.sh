#!/usr/bin/env bash
# Reports what is wrong with a repo's ai-sdlc setup. Reports only — it writes nothing, changes
# no configuration, and never fixes. That is what makes it safe to run first, before you know
# what is wrong.
#
# Every check prints one line: [ok] nothing to do · [finding] wrong, with the remedy ·
# [unknown] could not be answered, with the reason. A check that cannot answer must not stop
# the others, so this deliberately does NOT use `set -e`.
#
# Usage: doctor.sh [repo-root] [plugin-root]
#   repo-root   defaults to the current directory
#   plugin-root defaults to $CLAUDE_PLUGIN_ROOT, else the plugin this script lives in
set -uo pipefail
shopt -s nullglob

REPO=${1:-.}
PLUGIN=${2:-${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}}
FINDINGS=0; UNKNOWNS=0

say() {
  case "$1" in
    finding) FINDINGS=$((FINDINGS + 1)) ;;
    unknown) UNKNOWNS=$((UNKNOWNS + 1)) ;;
  esac
  printf '[%-7s] %-16s %s\n' "$1" "$2" "$3"
}
done_() { echo; echo "summary: $FINDINGS finding(s), $UNKNOWNS unknown"; exit 0; }

[ -d "$REPO" ] || { say unknown repo "no such directory: $REPO"; done_; }
cd "$REPO" || { say unknown repo "cannot enter $REPO"; done_; }

# --- layout -----------------------------------------------------------------------------
# A repo with no layout is a finding, not an error: most repos on a machine do not have one,
# and the command must be runnable anywhere.
# 1.0.0 renamed ai/ to ai-factory/. Three states are worth telling apart, because the remedy  # path-scan-ok
# differs and the hooks behave differently in each: never adopted, adopted but not yet migrated,
# and half migrated. The hooks prefer ai-factory/ and fall back to ai/ until 3.0.0, so saying which  # path-scan-ok
# directory they are actually reading is the difference between "my log stopped" and a diagnosis.
if [ -d ai-factory ] && [ -d ai ]; then
  say finding layout "both ai/ and ai-factory/ exist — this repo is half migrated. The hooks are using ai-factory/; the prompts name it too. Decide which is current, remove the other, then run /t4:migrate-layout"  # path-scan-ok
elif [ ! -d ai-factory ] && [ -d ai ]; then
  say finding layout "ai/ but no ai-factory/ — this repo is on the pre-1.0.0 layout. The hooks still work (they accept ai/ until 3.0.0), but every prompt names ai-factory/, so the tasks will look in the wrong place. Run /t4:migrate-layout"  # path-scan-ok
  done_
elif [ ! -d ai-factory ]; then
  say finding layout "no ai-factory/ directory — this repo has not adopted the layout. Run /t4:adopt-sdlc"
  done_
fi
tasks=(ai-factory/tasks/*.md)
if [ ${#tasks[@]} -eq 0 ]; then
  say finding layout "ai-factory/ exists but ai-factory/tasks/ is empty — run /t4:adopt-sdlc, or /t4:sync-sdlc if this is a partial copy"
else
  say ok layout "ai-factory/ present, ${#tasks[@]} tasks"
fi

# --- adapters ---------------------------------------------------------------------------
# Generated from ai-factory/tasks/. Fewer commands than tasks means a sync was missed, which is the
# usual cause of "my slash commands are gone".
cmds=(.claude/commands/t4/*.md)
if [ ${#cmds[@]} -eq 0 ]; then
  say finding adapters "no .claude/commands/t4/ — adapters were never generated. Run /t4:sync-sdlc"
elif [ ${#cmds[@]} -ne ${#tasks[@]} ]; then
  say finding adapters "${#tasks[@]} tasks but ${#cmds[@]} commands — adapters are stale. Run /t4:sync-sdlc"
else
  say ok adapters "${#cmds[@]} commands match ${#tasks[@]} tasks"
fi
stale=(.claude/commands/*.md)
[ ${#stale[@]} -gt 0 ] && say finding adapters \
  "${#stale[@]} command(s) left at .claude/commands/ from an older naming — /t4:sync-sdlc removes them"

# --- is this the plugin's own repo? ------------------------------------------------------
# manifest.js treats repo-root == plugin-root as "the plugin itself" and refuses to write a
# manifest there. Without the same test, this script tells a maintainer standing in the plugin
# repo to create a baseline that manifest.js will decline to write. Same rule, mirrored — not a
# second opinion about what counts as the plugin.
# Same identity test manifest.js uses, and for the same reason: comparing paths only works
# while the plugin is loaded from its working tree. Installed, pluginRoot is the cache, the
# paths differ, and this repo would be told to start a baseline it must never have.
SELF=no
_name() { sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$1/.claude-plugin/plugin.json" 2>/dev/null | head -1; }
if [ "$(cd . && pwd -P)" = "$(cd "$PLUGIN" 2>/dev/null && pwd -P)" ] \
   || { [ -n "$(_name .)" ] && [ "$(_name .)" = "$(_name "$PLUGIN")" ]; }; then
  say ok layout-source "this is the plugin's own repo — the templates are the source, so there is no manifest and nothing to compare"
  SELF=yes
fi

# --- version recorded by this repo -------------------------------------------------------
if [ "$SELF" = yes ]; then
  : # no manifest and no drift by design; the environment checks below still apply
elif [ ! -f ai-factory/.sdlc.json ]; then
  say unknown version "no ai-factory/.sdlc.json — this repo was adopted before manifests existed, so drift cannot be computed. Start a baseline: node \"$PLUGIN/skills/ai-layout/scripts/manifest.js\" write . \"$PLUGIN\""
else
  # The key is `version`, not `plugin_version` — read from the manifest manifest.js writes,
  # not from what the field is called in prose. Getting this wrong reported "unknown" for a
  # repo whose version was recorded perfectly well.
  recorded=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' ai-factory/.sdlc.json | head -1)
  installed=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PLUGIN/.claude-plugin/plugin.json" 2>/dev/null | head -1)
  if [ -z "$recorded" ]; then
    say unknown version "ai-factory/.sdlc.json has no version — it may be hand-edited or from a newer schema"
  elif [ -z "$installed" ]; then
    # Never report agreement that was not checked. An empty $installed means plugin.json could
    # not be read, and "agree" would be a claim with no evidence behind it — the one thing a
    # diagnostic must not do.
    say unknown version "repo recorded $recorded, but the installed plugin's own version could not be read from $PLUGIN"
  elif [ "$recorded" != "$installed" ]; then
    say finding version "repo recorded $recorded but the plugin here is $installed — a session may behave unlike the layout expects"
  else
    say ok version "repo and plugin agree at $recorded"
  fi
fi

# --- drift ------------------------------------------------------------------------------
# Delegated to manifest.js rather than reimplemented: it owns the six drift states and the
# two-hash comparison, and a second implementation here would disagree with /t4:sync-sdlc.
if [ "$SELF" = yes ]; then
  :
elif ! command -v node >/dev/null 2>&1; then
  say unknown drift "node not on PATH, so the layout cannot be compared with the templates"
elif [ ! -f "$PLUGIN/skills/ai-layout/scripts/manifest.js" ]; then
  say unknown drift "cannot find the plugin's manifest.js (looked in $PLUGIN) — pass the plugin root as the second argument"
elif [ ! -f ai-factory/.sdlc.json ]; then
  : # already reported above as version/unknown; saying it twice helps nobody
else
  out=$(node "$PLUGIN/skills/ai-layout/scripts/manifest.js" check . "$PLUGIN" 2>&1)
  if [ $? -ne 0 ]; then
    say unknown drift "the drift check did not complete: $(printf '%s' "$out" | head -1)"
  else
    behind=$(printf '%s\n' "$out" | sed -n 's/.*upstream changed (\([0-9]*\)).*/\1/p' | head -1)
    added=$(printf '%s\n' "$out" | sed -n 's/.*new upstream (\([0-9]*\)).*/\1/p' | head -1)
    local_=$(printf '%s\n' "$out" | sed -n 's/.*locally modified (\([0-9]*\)).*/\1/p' | head -1)
    total=$(( ${behind:-0} + ${added:-0} ))
    if [ "$total" -gt 0 ]; then
      say finding drift "$total file(s) behind the installed templates (${behind:-0} changed upstream, ${added:-0} new) — /t4:sync-sdlc reports them; taking one is a separate edit"
    else
      say ok drift "layout matches the installed templates"
    fi
    [ "${local_:-0}" -gt 0 ] && say ok local-edits "${local_} file(s) modified here and not upstream — yours, nothing to do"
  fi
fi

# --- environment: which copy is actually running -----------------------------------------
# The repo checks above describe files. These describe the session, and they are the ones that
# cost the most time to work out by hand: a plugin enabled for a different project, and older
# cached copies still running the hooks. Nothing here is written to; every path is read-only.
#
# Names churn — this plugin and its marketplace have each been renamed more than once — so
# nothing below hardcodes one. The plugin's own name comes from its manifest and everything
# else is matched against that.
PLUGIN_NAME=$(sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PLUGIN/.claude-plugin/plugin.json" 2>/dev/null | head -1)

if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  case "$CLAUDE_PLUGIN_ROOT" in
    */plugins/cache/*) say ok source "running from the installed copy: $CLAUDE_PLUGIN_ROOT" ;;
    *) say ok source "running from a working tree, not an install: $CLAUDE_PLUGIN_ROOT" ;;
  esac
else
  say unknown source "CLAUDE_PLUGIN_ROOT is unset — this was not run from inside a session, so the copy a session would load cannot be identified"
fi

CFG=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
if [ ! -d "$CFG/plugins" ]; then
  # Absent under Codex, and on any machine that has never installed a plugin. One unknown,
  # not one per check below.
  say unknown install "no $CFG/plugins — install scope and cached versions cannot be read here"
elif ! command -v node >/dev/null 2>&1; then
  say unknown install "node not on PATH, so $CFG/plugins cannot be read"
elif [ -z "$PLUGIN_NAME" ]; then
  say unknown install "cannot read the plugin's own name from $PLUGIN/.claude-plugin/plugin.json"
else
  HERE=$(pwd -P)
  while IFS='|' read -r status label detail; do
    [ -n "$status" ] && say "$status" "$label" "$detail"
  done <<EOF_NODE
$(node -e '
const fs=require("fs"), path=require("path");
const cfg=process.argv[1], name=process.argv[2], here=process.argv[3];
const out=[];
const read=f=>{try{return JSON.parse(fs.readFileSync(f,"utf8"))}catch{return null}};
const inst=read(path.join(cfg,"plugins","installed_plugins.json"));
if(!inst||!inst.plugins) out.push(["unknown","install","installed_plugins.json is missing or unreadable"]);
else{
  const mine=Object.entries(inst.plugins).filter(([k])=>k.split("@")[0]===name);
  if(!mine.length) out.push(["finding","install",`${name} is not installed on this machine — /plugin install ${name}@<marketplace>`]);
  else for(const [ref,entries] of mine){
    const covers=entries.some(e=>e.scope==="user"||(e.projectPath&&path.resolve(e.projectPath)===here));
    const where=entries.map(e=>`${e.scope}${e.projectPath?" "+e.projectPath:""} @ ${e.version}`).join("; ");
    out.push([covers?"ok":"finding","install",
      covers?`${ref} installed — ${where}`
            :`${ref} is installed, but not for this repo — ${where}. Here its own commands and skills are absent (the /t4:* tasks generated into .claude/ still work); install at user scope, or enable it in this repo`]);
  }
}
// Older cached copies are what a stale session actually runs, so they are worth naming.
const cacheRoot=path.join(cfg,"plugins","cache");
let vers=[];
try{ for(const mk of fs.readdirSync(cacheRoot)){ const d=path.join(cacheRoot,mk,name);
      try{ for(const v of fs.readdirSync(d)) vers.push(`${mk}/${name}/${v}`);}catch{} } }catch{}
if(vers.length>1) out.push(["finding","cache",`${vers.length} cached copies of ${name}: ${vers.join(", ")} — a session that has not restarted may still be running an older one`]);
else if(vers.length===1) out.push(["ok","cache",`one cached copy: ${vers[0]}`]);

// Is the install behind the marketplace copy already on disk? A repo can be perfectly in step
// with an install that is itself several releases old, which is invisible to every check above
// — they all compare against whatever plugin they were handed. Local copy only: reaching the
// network would answer a different, larger question and this must not imply it.
const cmp=(a,b)=>{const A=String(a).split(".").map(Number),B=String(b).split(".").map(Number);
  for(let i=0;i<Math.max(A.length,B.length);i++){const x=A[i]||0,y=B[i]||0; if(x!==y) return x<y?-1:1;} return 0;};
const installedVers=[];
if(inst&&inst.plugins) for(const [ref,entries] of Object.entries(inst.plugins))
  if(ref.split("@")[0]===name) for(const e of entries) if(e.version) installedVers.push(e.version);
if(installedVers.length){
  const have=installedVers.sort(cmp).slice(-1)[0];
  let published=null, mkName=null;
  try{ for(const mk of fs.readdirSync(path.join(cfg,"plugins","marketplaces"))){
    const j=read(path.join(cfg,"plugins","marketplaces",mk,".claude-plugin","marketplace.json"));
    for(const pl of (j&&j.plugins)||[]) if(pl.name===name&&pl.version&&(!published||cmp(pl.version,published)>0)){published=pl.version;mkName=mk;}
  } }catch{}
  if(!published) out.push(["unknown","update",`no marketplace copy of ${name} could be read, so it is not known whether ${have} is current`]);
  else if(cmp(have,published)<0) out.push(["finding","update",`installed ${have}, but the ${mkName} marketplace copy on this machine is ${published} — /plugin install ${name}@${mkName}, then restart. (Compares against the copy already fetched, not the remote.)`]);
}
for(const r of out) console.log(r.join("|"));
' "$CFG" "$PLUGIN_NAME" "$HERE" 2>/dev/null)
EOF_NODE
fi

done_
