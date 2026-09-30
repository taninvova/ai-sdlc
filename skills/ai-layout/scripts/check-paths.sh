#!/usr/bin/env bash
# No prompt, agent, skill, command or context doc may name a pre-1.0.0 path: the layout is
# `ai-factory/`, specs live in `ai-factory/specs/`, ADRs in `ai-factory/adr/`, and the workflow
# doc in `ai-factory/docs/`. A stale reference sends a task to a directory the repo does not
# have, and the rename that produced them touched 180 files — far too many to re-read by eye.
#
# Why this is not one grep. The obvious pattern, `(^|[^-[:alnum:]_./])(ai/|specs/|…)`, excludes a
# preceding "/" so that `~/code/ai/ai-sdlc` survives — and is therefore blind to
# `templates/ai/` and `templates/specs/`, which is exactly where half the stale references were
# during the rename. Widening the class instead flags the workspace path on every run.
#
# So: neutralise every CORRECT reference first by rewriting `ai-factory/` to a letter, then match
# the old paths with "/" allowed before them. `ai-factory/specs/` becomes `Lspecs/` and cannot
# match; a bare `specs/` or a `templates/specs/` still does. A line that must name an old path on
# purpose says so with `path-scan-ok`.
set -euo pipefail
shopt -s nullglob
cd "$(dirname "$0")/../../.."
# Disposable fixtures stay in the project workspace, including default mktemp calls.
export TMPDIR="$PWD/ai-factory/runs/tmp"
mkdir -p "$TMPDIR"
fail() { echo "FAIL: $*" >&2; exit 1; }

ALLOW='path-scan-ok'

# scan_paths <file>… — fails on the first file naming a pre-1.0.0 path, quoting up to three
# offending lines with their numbers. Reports the original line, not the neutralised one.
scan_paths() {
  local f hits
  for f in "$@"; do
    [ -f "$f" ] || continue
    hits=$(awk -v allow="$ALLOW" '
      $0 ~ allow { next }
      { l = $0; gsub(/ai-factory\//, "L", l)
        if (l ~ /(^|[^-[:alnum:]_.])((ai|specs)\/|docs\/adr|docs\/workflow)/) printf "%d:%s\n", FNR, $0 }
    ' "$f" | head -3)
    [ -z "$hits" ] || fail "$f names a pre-1.0.0 path (the layout is ai-factory/):
$hits"
  done
}

# Everything a session reads as INSTRUCTION, plus the templates an adopted repo receives. Not the
# records — specs, plans, designs, analyses, ADRs and the CHANGELOG say what was true when they
# were written, and a document describing the rename must be free to name the old path (AC9).
# ADRs are records by definition, which is why ai-factory/adr/ is absent here: ADR 0008 decides
# the rename, so it necessarily names ai/, and no task reads an ADR as an instruction anyway.
#
# Four files are excluded outright, because in each the old name IS the subject rather than a
# stale reference, in two groups:
#   the transitional fallback — the detection that accepts both names, the hook manifest that
#     documents it, and the fixture proving an unmigrated repo keeps its guard;
#   this file, whose header explains the old paths and whose self-proof is made of them.
# A per-line pragma would be noise on nearly every line of all four, and hooks.json is JSON and
# cannot carry one.
#
# There were eight until 2.1.0, which removed /t4:migrate-layout along with its script, the
# rewriter and the check whose fixtures were built out of pre-1.0.0 repos. The fallback trio goes
# in 3.0.0. What is left then is this script, and the cost of excluding it: its own paths are not
# self-checked. It has none that a task follows, and the set-size assertion below catches the
# mistake that would matter — a glob that silently stops matching.
EXCLUDED='^(hooks/hooks\.json|skills/ai-hooks/scripts/_common\.js|skills/ai-hooks/fixtures/check-detect\.sh|skills/ai-layout/scripts/check-paths\.sh)$'
FILES=()
while IFS= read -r f; do
  [[ $f =~ $EXCLUDED ]] && continue
  FILES+=("$f")
done < <(
  { ls agents/*.md commands/*.md README.md ai-factory/AGENTS.md 2>/dev/null
    find ai-factory/docs skills codex-skills -type f ! -name '.DS_Store'
  } | sort -u
)
[ "${#FILES[@]}" -gt 50 ] || fail "the scan set collapsed to ${#FILES[@]} files — a glob or a path is wrong"
scan_paths "${FILES[@]}"

# The scan proves itself, the way check-adapters.sh proves its seam scan: a pattern that silently
# matches nothing would leave every prompt unguarded, and the neutralise step above is precisely
# the kind of cleverness that stops matching without anyone noticing.
t=$(mktemp); trap 'rm -f "$t"' EXIT
for bad in 'Read ai/tasks/spec.md and follow it.' \
           'Write specs/<NNNN>-<slug>.md with a title.' \
           'Record it in docs/adr/NNNN-slug.md.' \
           'See docs/workflow.md for the loop.' \
           'Copy skills/ai-layout/templates/specs/0000-scaffold.md.'; do
  printf '%s\n' "$bad" > "$t"
  if (scan_paths "$t") 2>/dev/null; then fail "the scan let a stale path through: $bad"; fi
  out=$( (scan_paths "$t") 2>&1 || true)
  grep -qF "$t" <<<"$out"  || fail "the scan's failure does not name the file: $bad"
  grep -qE '^1:' <<<"$out" || fail "the scan's failure does not name the line: $bad"
done
for good in 'Read ai-factory/tasks/spec.md and follow it.' \
            'Write ai-factory/specs/<NNNN>-<slug>.md with a title.' \
            'Record it in ai-factory/adr/NNNN-slug.md.' \
            'See ai-factory/docs/workflow.md for the loop.' \
            'Copy skills/ai-layout/templates/ai-factory/specs/0000-scaffold.md.' \
            'Install with claude --plugin-dir .' \
            'Add git@git.epam.com:volodymyr_tanin/ai-sdlc-plugin.git as the marketplace.' \
            'The old ai/tasks/ name, kept on purpose. path-scan-ok'; do
  printf '%s\n' "$good" > "$t"
  (scan_paths "$t") 2>/dev/null || fail "the scan rejected a correct line: $good"
done

echo "paths ok — ${#FILES[@]} files scanned, no pre-1.0.0 path, scan proved on 5 stale and 8 correct lines"
