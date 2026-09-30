#!/usr/bin/env bash
# Asserts sync-adapters.sh generates all three adapter sets from ai-factory/, that Codex skills carry
# the inline-agent note exactly where a task delegates, that a second run changes nothing, and
# that no prompt names what only a seam document may (ADR 0004 for the tracker, 0007 for the
# knowledge source).
set -euo pipefail
shopt -s nullglob
cd "$(dirname "$0")/../../.."
# Disposable fixtures stay in the project workspace, including default mktemp calls.
export TMPDIR="$PWD/ai-factory/runs/tmp"
mkdir -p "$TMPDIR"
fail() { echo "FAIL: $*" >&2; exit 1; }

bash ai-factory/make/sync-adapters.sh --adapters=all > /dev/null
before=$(find .claude .cursor .codex -type f -o -type l | sort | xargs shasum | shasum)
bash ai-factory/make/sync-adapters.sh --adapters=all > /dev/null
[ "$before" = "$(find .claude .cursor .codex -type f -o -type l | sort | xargs shasum | shasum)" ] \
  || fail "sync-adapters is not idempotent"

# A task whose name the plugin already registers as a native command (commands/<name>.md) takes no
# Claude pointer: two /t4:<name> entries in one menu, described differently, is the bug this guards
# against. Codex plugins ship no commands, so every task still gets a Codex skill.
native=()
for c in commands/*.md; do
  n=$(basename "$c" .md)
  [ -f "ai-factory/tasks/$n.md" ] && native+=("$n")
done
tasks=$(ls ai-factory/tasks/*.md | wc -l | tr -d ' ')
command_files=(.claude/commands/t4/*.md)
cmds=${#command_files[@]}
skills=$(ls -d .codex/skills/t4-*/ 2>/dev/null | wc -l | tr -d ' ')
[ "$((tasks - ${#native[@]}))" = "$cmds" ] \
  || fail "$tasks tasks, ${#native[@]} of them already native plugin commands, but $cmds claude commands"
[ "$tasks" = "$skills" ] || fail "$tasks tasks but $skills codex skills"
for n in ${native[@]+"${native[@]}"}; do
  [ -f ".claude/commands/t4/$n.md" ] \
    && fail ".claude/commands/t4/$n.md repeats the plugin's own /t4:$n — the menu would list it twice"
  [ -f ".codex/skills/t4-$n/SKILL.md" ] || fail "missing .codex/skills/t4-$n/SKILL.md"
done
# A pointer left over from before the exclusion is removed by the next sync, not kept.
if [ ${#native[@]} -gt 0 ]; then
  mkdir -p .claude/commands/t4
  printf -- '---\ndescription: stale\n---\n@../../../ai-factory/tasks/%s.md\n' "${native[0]}" \
    > ".claude/commands/t4/${native[0]}.md"
  bash ai-factory/make/sync-adapters.sh --adapters=claude > /dev/null
  [ ! -f ".claude/commands/t4/${native[0]}.md" ] \
    || fail "sync kept a pointer that repeats the plugin's /t4:${native[0]}"
fi

for t in ai-factory/tasks/*.md; do
  n=$(basename "$t" .md); s=".codex/skills/t4-$n/SKILL.md"
  [ -f "$s" ] || fail "missing $s"
  grep -q "^name: t4-$n$" "$s" || fail "$s has the wrong name in its frontmatter"
  grep -q "ai-factory/tasks/$n.md" "$s" || fail "$s does not point at its task file"
  # A task that delegates must carry the note; one that does not must not.
  if grep -q 'Delegate to the `[a-z]*` subagent' "$t"; then
    a=$(sed -n 's/.*Delegate to the `\([a-z]*\)` subagent.*/\1/p' "$t" | head -1)
    grep -q "native delegation" "$s" || fail "$s is missing the inline-agent note"
    grep -q "ai-factory/agents/$a.md" "$s"       || fail "$s does not name ai-factory/agents/$a.md"
  else
    grep -q "native delegation" "$s" && fail "$s has an inline-agent note but $t delegates to nothing"
  fi
done

for t in ai-factory/tasks/*.md; do
  n=$(basename "$t" .md); c=".claude/commands/t4/$n.md"
  [ -f "commands/$n.md" ] && continue   # the plugin's own command, asserted absent above
  [ -f "$c" ] || fail "missing $c"
  inc=$(sed -n 's/^@//p' "$c" | head -1)
  [ -n "$inc" ] || fail "$c has no @include"
  target=$(cd "$(dirname "$c")" && cd "$(dirname "$inc")" 2>/dev/null && pwd)/$(basename "$inc")
  [ -f "$target" ] || fail "$c includes $inc, which does not resolve to a file"
  [ "$target" = "$PWD/$t" ] || fail "$c resolves to $target, expected $PWD/$t"
done

# A task's argument-hint must reach the generated command, or the menu advertises no input
# and the user discovers the requirement only by running it. A task without a hint must not
# gain an empty one.
for t in ai-factory/tasks/*.md; do
  n=$(basename "$t" .md); c=".claude/commands/t4/$n.md"
  [ -f "commands/$n.md" ] && c="commands/$n.md"   # the plugin's own command carries the hint instead
  h=$(sed -n 's/^argument-hint: *//p' "$t" | head -1)
  g=$(sed -n 's/^argument-hint: *//p' "$c" | head -1)
  [ "$h" = "$g" ] || fail "$n: task hint '$h' but command hint '$g'"
done

# A task that takes input must say what to do when it gets none, or an empty invocation
# leaves a dangling label and the task guesses. Hint present => prompt present.
for t in ai-factory/tasks/*.md; do
  n=$(basename "$t" .md)
  h=$(sed -n 's/^argument-hint: *//p' "$t" | head -1)
  case "$h" in
    "" ) continue ;;                       # takes no input
    \[*\] ) continue ;;                     # optional input, marked by brackets
  esac
  grep -q "If nothing follows the command name" "$t" \
    || fail "$n requires input ($h) but never says what to do when it gets none"
done

# A repo adopted under an older naming keeps its old command files unless sync removes them,
# and then answers both /spec and /t4:spec. Reproduce that: a pre-0.5.0 bare command, a
# 0.5.0-era ai- command, a stale codex skill — and a hand-written command that must survive,
# because the only thing separating it from ours is the include, not the name.
printf -- '---\ndescription: stale\n---\n@../../ai/tasks/spec.md\n' > .claude/commands/spec.md  # path-scan-ok: reproducing the pre-1.0.0 name is the point
printf -- '---\ndescription: stale\n---\n@../../ai/tasks/plan.md\n' > .claude/commands/ai-plan.md  # path-scan-ok: ditto, and it proves the cleanup matches both names
mkdir -p .codex/skills/ai-spec && printf -- '---\nname: ai-spec\n---\nRead `ai-factory/tasks/spec.md`\n' > .codex/skills/ai-spec/SKILL.md
printf -- '---\ndescription: mine\n---\nMy own prompt, nothing to do with ai-factory/tasks.\n' > .claude/commands/spec-of-mine.md
bash ai-factory/make/sync-adapters.sh --adapters=all > /dev/null
[ ! -f .claude/commands/spec.md ]        || fail "sync left the pre-0.5.0 bare command in place"
[ ! -f .claude/commands/ai-plan.md ]     || fail "sync left the 0.5.0-era ai- command in place"
[ ! -d .codex/skills/ai-spec ]           || fail "sync left a stale codex skill in place"
[ -f .claude/commands/spec-of-mine.md ]  || fail "sync deleted a hand-written command"
rm -f .claude/commands/spec-of-mine.md

# ADR 0004 rule 3: a task prompt may name the seam document and nothing else. The vendor, the
# connector, a URL, a config filename — all of it belongs in ai-factory/docs/tracker.md, so that
# replacing the tracker touches one file. Checked on the task AND on both generated forms,
# because the generated command is what a developer actually runs. The word "json" is NOT
# forbidden: check, design and fleet legitimately describe JSON output of their own.
BANNED='jira|atlassian|connector|base_url|https?://|\.yaml'
# commands/*.md is in this list because a plugin command is read by a session exactly as a task
# is, and /t4:doctor has to describe tracker state without knowing what a tracker is. ADR 0004
# rule 3 names task prompts only; the seam is worth just as little if the plugin's own commands
# leak around it.
PROMPTS=(ai-factory/tasks/*.md commands/*.md .claude/commands/t4/*.md .codex/skills/t4-*/SKILL.md)
# scan_banned <pattern> <message> <file>... — fails on the first file matching the pattern,
# naming the file and up to three matching lines with their numbers. Case-insensitive, so a
# prompt cannot slip a term past it by capitalising.
scan_banned() {
  local pat=$1 msg=$2 f; shift 2
  for f in "$@"; do
    [ -f "$f" ] || continue
    if grep -qiE "$pat" "$f"; then
      fail "$f $msg:
$(grep -inE "$pat" "$f" | head -3)"
    fi
  done
}
scan_banned "$BANNED" "names a tracker implementation detail — ADR 0004 rule 3 confines those to ai-factory/docs/tracker.md" "${PROMPTS[@]}"

# ADR 0007 rule 1: the knowledge seam has a list of its own, because the tracker list bans
# `.yaml` and the knowledge declaration is a markdown file — `ai-factory/knowledge_base.md` passes the
# block above untouched. The list is the declaration filename plus every provider or product
# name the seam document names (ai-factory/specs/0004 decision 2); today the seam names none, so the list
# is one term. "MCP" and "knowledge base" are deliberately not here: they are ordinary prose.
KNOWLEDGE_BANNED='knowledge_base\.md'
# This repo keeps a real-file copy of the seam document in its own layout (ai-factory/docs/ here is not a
# symlink). A template edit that misses the copy would leave this repo's own agents following a
# stale seam, so the two must be byte-identical wherever both exist.
if [ -f ai-factory/docs/knowledge.md ] && [ -f skills/ai-layout/templates/ai-factory/docs/knowledge.md ]; then
  cmp -s ai-factory/docs/knowledge.md skills/ai-layout/templates/ai-factory/docs/knowledge.md \
    || fail "ai-factory/docs/knowledge.md has drifted from skills/ai-layout/templates/ai-factory/docs/knowledge.md"
fi
scan_banned "$KNOWLEDGE_BANNED" "names the knowledge declaration — ADR 0007 rule 1 confines it to ai-factory/docs/knowledge.md" "${PROMPTS[@]}"

# The scan proves itself against a scratch prompt (ai-factory/specs/0004 AC11): a pattern that silently
# matches nothing would leave the seam guarded by nobody, and the two-list refactor above is
# exactly the kind of edit that breaks a grep without anyone noticing.
t=$(mktemp)
printf 'Read ai-factory/knowledge_base.md and follow it.\n' > "$t"
if (scan_banned "$KNOWLEDGE_BANNED" "x" "$t") 2>/dev/null; then
  fail "the knowledge scan let a prompt naming the declaration through"
fi
out=$( (scan_banned "$KNOWLEDGE_BANNED" "x" "$t") 2>&1 || true)
grep -qF "$t" <<<"$out"  || fail "the knowledge scan's failure does not name the file"
grep -qE '^1:' <<<"$out" || fail "the knowledge scan's failure does not name the line"
printf 'Read ai-factory/docs/knowledge.md and follow it.\n' > "$t"
(scan_banned "$KNOWLEDGE_BANNED" "x" "$t") 2>/dev/null \
  || fail "the knowledge scan rejects a prompt that names only the seam document"
rm -f "$t"

# ai-factory/specs/0004 AC10: wider than the ban, over the agents as well — nothing outside the seam
# document may name the declaration, the protocol or a URL. "MCP" is not banned in prose
# generally, but a prompt or agent that needs the word is describing a source, and that
# description belongs in ai-factory/docs/knowledge.md. The seam document is not in this set, so "only
# the seam document matches" means this set matches nothing.
SWEEP='knowledge_base\.md|(^|[^A-Za-z])MCP([^A-Za-z]|$)|https?://'
scan_banned "$SWEEP" "names a knowledge-source detail — ai-factory/specs/0004 AC10 permits that only in ai-factory/docs/knowledge.md" \
  "${PROMPTS[@]}" agents/*.md skills/ai-layout/templates/ai-factory/agents/*.md

# AC12 of ai-factory/specs/0001: a repo that has configured no tracker must not be able to tell the
# feature shipped. argument-hint is rendered in the command menu, so it is output, and a hint
# mentioning tickets would advertise the feature to every repo that cannot use it.
for t in ai-factory/tasks/*.md; do
  h=$(sed -n 's/^argument-hint: *//p' "$t" | head -1)
  case "$h" in
    *icket*|*racker*|*ira*)
      fail "$(basename "$t" .md) advertises a tracker in its argument-hint (\"$h\") — the command menu is visible to repos with no tracker configured" ;;
  esac
done

# The codex skill must not copy the prompt text — that would fork from ai-factory/tasks/.
body=$(sed -n '/^---$/,/^---$/!p' .codex/skills/t4-spec/SKILL.md | wc -l | tr -d ' ')
[ "$body" -lt 15 ] || fail "codex skills look like copies of the task, not pointers ($body lines)"

echo "adapters ok — $tasks tasks → $cmds claude commands (${#native[@]} left to the plugin) + $skills codex skills, idempotent, agent notes correct"
