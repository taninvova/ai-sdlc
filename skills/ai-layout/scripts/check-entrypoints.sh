#!/usr/bin/env bash
# The three files an adopted repo keeps at its root, and the two git files it is told to write.
# These are the only paths the layout places outside ai-factory/ (AC2), and none of them is read by
# a person: Claude Code follows CLAUDE.md's single @ import, make resolves the include, and a tool
# that opens AGENTS.md follows the one line in it. So a stale line here is not a wrong instruction
# — it is a repo where nothing loads, and nobody reports it, because nothing appears to happen.
#
# Asserted as exact content, not by grep. Each of the two markdown files is one line whose whole
# purpose is to point into the layout directory; an extra line pointing somewhere else would be
# invisible to a grep for the right one.
#
# The gitignore and gitattributes lines are asserted twice over: as the prescription in
# skills/ai-hooks/SKILL.md, which is what an adopting repo copies, and then as this repo's own two
# files, from the same list — because a prescription this repo does not follow is how a run log the
# hooks write ends up tracked, dirtying the tree for a whole session.
set -euo pipefail
shopt -s nullglob
cd "$(dirname "$0")/../../.."
fail() { echo "FAIL: $*" >&2; exit 1; }
T=skills/ai-layout/templates

# is <file> <exact content> — the whole file, because these files are one line.
is() {
  local got
  got=$(cat "$1") || fail "$1 is missing — an adopted repo would get no entry point at its root"
  [ "$got" = "$2" ] || fail "$1 must be exactly \"$2\", not \"$got\""
}

is "$T/AGENTS.md" 'See ai-factory/AGENTS.md'
is "$T/CLAUDE.md" '@ai-factory/AGENTS.md'
grep -qE '^include[[:space:]]+ai-factory/make/ai\.mk$' "$T/Makefile" \
  || fail "$T/Makefile does not include ai-factory/make/ai.mk — \"make ai\" would not resolve in an adopted repo:
$(cat "$T/Makefile")"

# ...and nothing else arrives outside the layout directory.
[ -d "$T/ai-factory" ] || fail "$T/ai-factory is missing — the templates carry no layout directory"
outside=()
for e in "$T"/* "$T"/.[!.]*; do
  case ${e#"$T"/} in ai-factory | AGENTS.md | CLAUDE.md | Makefile) ;; *) outside+=("${e#"$T"/}") ;; esac
done
[ "${#outside[@]}" = 0 ] \
  || fail "the templates place ${outside[*]} outside ai-factory/; only AGENTS.md, CLAUDE.md and Makefile may sit at an adopted repo's root"

# --- the two git files every repo is told to write ---------------------------------------------
SKILL=skills/ai-hooks/SKILL.md
IGNORE=('ai-factory/runs/*.json' 'ai-factory/runs/*.jsonl' 'ai-factory/runs/log.pending.csv' 'ai-factory/runs/.counted.*' 'ai-factory/runs/.task.*' 'ai-factory/runs/report.html')
ATTR='ai-factory/runs/log.csv merge=union'

# The lines under the first "## " heading matching $2, up to the next one.
section() { awk -v h="$2" '/^## /{inside = ($0 ~ h)} inside' "$1"; }

gi=$(section "$SKILL" '[Gg]itignore')
[ -n "$gi" ] || fail "$SKILL has no gitignore section — an adopting repo is told nothing to ignore"
for l in "${IGNORE[@]}"; do
  grep -qxF -- "$l" <<<"$gi" || fail "$SKILL's gitignore section does not prescribe \"$l\""
done
ga=$(section "$SKILL" '[Gg]itattributes')
[ -n "$ga" ] || fail "$SKILL has no gitattributes section"
grep -qxF -- "$ATTR" <<<"$ga" || fail "$SKILL's gitattributes section does not prescribe \"$ATTR\""

# The same lines, in this repo, which runs the hooks it ships.
for l in "${IGNORE[@]}"; do
  grep -qxF -- "$l" .gitignore \
    || fail ".gitignore does not carry \"$l\", which $SKILL prescribes — a file the hooks write every turn would be tracked"
done
grep -qxF -- "$ATTR" .gitattributes \
  || fail ".gitattributes does not carry \"$ATTR\", which $SKILL prescribes — two branches' log rows would conflict on merge"

# --- the layout an adopting repo receives, entry by entry (AC1) --------------------------------
# The templates are a payload: a file dropped from them ships nothing to every repo that adopts
# next, and the drift check cannot see it — manifest.js tracks what a repo received, so a template
# that no longer exists is simply never missed. Named here so deleting one has to be deliberate.
T=skills/ai-layout/templates/ai-factory
for entry in AGENTS.md models.yaml docs tasks agents make plans/done runs/log.csv \
             designs analyses explorations specs adr; do
  [ -e "$T/$entry" ] \
    || fail "the templates no longer carry $entry — every repo adopting from here on would be missing it, and no drift check would notice"
done
# The two seeded files inside those last two. Both paths are under $T — inside the layout, not
# beside it — but check-paths.sh cannot see through the variable and reads the segment after it as a
# pre-1.0.0 path, so the two lines say so rather than being contorted to please the scanner.
[ -e "$T/specs/0000-scaffold.md" ] || fail "the templates no longer carry the scaffold spec"  # path-scan-ok
[ -e "$T/adr/0000-template.md" ]   || fail "the templates no longer carry the ADR template"  # path-scan-ok
for d in tasks agents docs; do
  n=$(ls "$T/$d"/*.md 2>/dev/null | wc -l | tr -d ' ')
  [ "$n" -gt 0 ] || fail "$T/$d/ holds no .md files"
done

echo "entry points ok — AGENTS.md, CLAUDE.md and Makefile are the only three template paths outside ai-factory/ and each points into it; ${#IGNORE[@]} gitignore lines and 1 gitattributes line name ai-factory/runs/, in the skill and in this repo; the templates carry all 13 named entries"
