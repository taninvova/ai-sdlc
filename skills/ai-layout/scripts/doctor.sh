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
if [ ! -d ai ]; then
  say finding layout "no ai/ directory — this repo has not adopted the layout. Run /t4:adopt-sdlc"
  done_
fi
tasks=(ai/tasks/*.md)
if [ ${#tasks[@]} -eq 0 ]; then
  say finding layout "ai/ exists but ai/tasks/ is empty — run /t4:adopt-sdlc, or /t4:sync-sdlc if this is a partial copy"
else
  say ok layout "ai/ present, ${#tasks[@]} tasks"
fi

# --- adapters ---------------------------------------------------------------------------
# Generated from ai/tasks/. Fewer commands than tasks means a sync was missed, which is the
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
if [ "$(cd . && pwd -P)" = "$(cd "$PLUGIN" 2>/dev/null && pwd -P)" ]; then
  say ok layout-source "this is the plugin's own repo — the templates are the source, so there is no manifest and nothing to compare"
  done_
fi

# --- version recorded by this repo -------------------------------------------------------
if [ ! -f ai/.sdlc.json ]; then
  say unknown version "no ai/.sdlc.json — this repo was adopted before manifests existed, so drift cannot be computed. Start a baseline: node \"$PLUGIN/skills/ai-layout/scripts/manifest.js\" write . \"$PLUGIN\""
else
  # The key is `version`, not `plugin_version` — read from the manifest manifest.js writes,
  # not from what the field is called in prose. Getting this wrong reported "unknown" for a
  # repo whose version was recorded perfectly well.
  recorded=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' ai/.sdlc.json | head -1)
  installed=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PLUGIN/.claude-plugin/plugin.json" 2>/dev/null | head -1)
  if [ -z "$recorded" ]; then
    say unknown version "ai/.sdlc.json has no version — it may be hand-edited or from a newer schema"
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
if ! command -v node >/dev/null 2>&1; then
  say unknown drift "node not on PATH, so the layout cannot be compared with the templates"
elif [ ! -f "$PLUGIN/skills/ai-layout/scripts/manifest.js" ]; then
  say unknown drift "cannot find the plugin's manifest.js (looked in $PLUGIN) — pass the plugin root as the second argument"
elif [ ! -f ai/.sdlc.json ]; then
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

done_
