#!/usr/bin/env bash
# Pins migrate-layout.sh and rewrite-paths.js against synthetic repos whose answers are known by
# construction. Every case is built in a temp dir and thrown away; nothing here touches a real repo,
# which matters more for this script than any other — the thing under test moves directories.
#
# The happy-path fixture is a full copy of the templates wound BACK to the pre-1.0.0 layout, not a
# hand-written sketch. That is what makes the manifest assertion meaningful: a minimal fixture would
# report every template file it never had as "new upstream", and the check would prove nothing.
set -euo pipefail
shopt -s nullglob
cd "$(dirname "$0")/../../.."
ROOT=$PWD
MIGRATE=$ROOT/skills/ai-layout/scripts/migrate-layout.sh
REWRITE=$ROOT/skills/ai-layout/scripts/rewrite-paths.js
TMPL=$ROOT/skills/ai-layout/templates
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

# --- 1. the rewriter, on its own -------------------------------------------------------------
# Two of these are the false positives that were actually made when this rename was done by hand:
# a git remote (git@host:ai/repo.git) and a source directory that merely looks like the layout.
node -e '
const { rewrite } = require(process.argv[1]);
const cases = [
  ["@ai/AGENTS.md",                    "@ai-factory/AGENTS.md"],
  ["include ai/make/ai.mk",            "include ai-factory/make/ai.mk"],
  ["The spec in specs/ for the change","The spec in ai-factory/specs/ for the change"],
  ["an ADR in docs/adr/",              "an ADR in ai-factory/adr/"],
  ["ai/runs/*.json",                   "ai-factory/runs/*.json"],
  ["- `ai/tasks/`",                    "- `ai-factory/tasks/`"],
  ["git@gitlab.example.io:ai/x.git",   "git@gitlab.example.io:ai/x.git"],
  ["import x from \"src/ai/helper\"",  "import x from \"src/ai/helper\""],
  ["app/specs/foo_spec.rb",            "app/specs/foo_spec.rb"],
  ["vendor/docs/adr/x.md",             "vendor/docs/adr/x.md"],
  ["ai-factory/specs/0001.md",         "ai-factory/specs/0001.md"],
  ["ai-factory/adr/0008.md",           "ai-factory/adr/0008.md"],
  ["~/code/nsix/ai/ai-sdlc",           "~/code/nsix/ai/ai-sdlc"],
];
for (const [i, want] of cases) {
  const got = rewrite(i);
  if (got !== want) { console.error(`rewrite(${JSON.stringify(i)}) = ${JSON.stringify(got)}, wanted ${JSON.stringify(want)}`); process.exit(1); }
}
const once = rewrite("the spec in specs/ and ai/docs/ and docs/adr/x");
if (rewrite(once) !== once) { console.error("rewrite is not idempotent"); process.exit(1); }
' "$REWRITE" || fail "rewrite-paths.js got a case wrong (see above)"

# --- fixture builders -------------------------------------------------------------------------
gitinit() { git init -q .; git config user.email d@d; git config user.name dev; git config commit.gpgsign false; }

# A repo as ai-sdlc 0.27.1 left it: every template file, wound back to the old layout by the exact
# inverse of the migration's own rules, plus the five root files 0.27.1 wrote.
mk027() {
  local d=$1; mkdir -p "$d"; ( cd "$d"
    cp -R "$TMPL/ai-factory" ai
    mv ai/specs specs
    mkdir -p docs && mv ai/adr docs/adr
    printf 'See ai/AGENTS.md\n' > AGENTS.md
    printf '@ai/AGENTS.md\n' > CLAUDE.md
    cp "$TMPL/Makefile" Makefile
    printf 'ai/runs/*.json\nai/runs/*.jsonl\nai/runs/log.pending.csv\n' > .gitignore
    printf 'ai/runs/log.csv merge=union\n' > .gitattributes
    # the inverse of rewrite-paths.js, most specific rule first
    node -e '
      const fs=require("fs"),cp=require("child_process");
      const files=cp.execSync("find . -type f -not -path \"./.git/*\"",{encoding:"utf8"}).trim().split("\n");
      for (const f of files) { let s; try { s=fs.readFileSync(f,"utf8"); } catch { continue; }
        const n=s.replace(/\(ai-factory\|ai\)\//g,"ai/").replace(/ai-factory\/specs\//g,"specs/").replace(/ai-factory\/adr/g,"docs/adr").replace(/ai-factory\//g,"ai/");
        if(n!==s) fs.writeFileSync(f,n); }'
    gitinit; git add -A; git commit -qm "adopted at 0.27.1"
  )
}

run() { ( cd "$1" && bash "$MIGRATE" 2>&1 ); }
rc_of() { local d=$1; ( cd "$d" && bash "$MIGRATE" >/dev/null 2>&1 ); echo $?; }

# --- 2. the happy path ------------------------------------------------------------------------
D=$TMP/happy; mk027 "$D"
head=$( cd "$D" && git rev-parse HEAD )
out=$(run "$D") || fail "migrate refused a clean 0.27.1 repo: $out"

( cd "$D"
  [ -d ai-factory ] || fail "ai-factory/ was not created"
  [ ! -d ai ]       || fail "ai/ survived the move"
  [ ! -d specs ]    || fail "specs/ survived the move"
  [ ! -d docs ]     || fail "docs/ was left behind although it held nothing but adr/"
  [ -f ai-factory/AGENTS.md ]                || fail "the layout did not come across"
  [ -f ai-factory/specs/0000-scaffold.md ]   || fail "specs/ did not land in ai-factory/specs/"
  [ -f ai-factory/adr/0000-template.md ]     || fail "docs/adr/ did not land in ai-factory/adr/"
  [ "$(git rev-parse HEAD)" = "$head" ]      || fail "the migration committed something — it must not"
  grep -q '^See ai-factory/AGENTS.md$' AGENTS.md   || fail "root AGENTS.md was not rewritten"
  grep -q '^@ai-factory/AGENTS.md$'    CLAUDE.md   || fail "root CLAUDE.md was not rewritten"
  grep -q 'ai-factory/make/ai.mk'      Makefile    || fail "root Makefile was not rewritten"
  grep -q 'ai-factory/runs/'           .gitignore  || fail ".gitignore was not rewritten"
  grep -q 'ai-factory/runs/log.csv'    .gitattributes || fail ".gitattributes was not rewritten"
  [ -f ai-factory/.sdlc.json ] || fail "the manifest was not refreshed"
  [ -d .claude/commands/t4 ]   || fail "the adapters were not regenerated"
  # the report keeps the two kinds of change apart
  grep -q '^moved (' <<<"$out"      || fail "the report does not list what moved"
  grep -q '^rewritten' <<<"$out"    || fail "the report does not list what was rewritten"
  grep -q 'git log --follow' <<<"$out" || fail "the report does not explain the two-commit order"
  # the index holds pure renames, and only renames: that is what keeps history
  r=$(git diff --cached -M --name-status | grep -c '^R100' || true)
  [ "$r" -ge 10 ] || fail "expected the staged move to be pure renames, found only $r R100 entries"
  [ -n "$(git diff --name-only)" ] || fail "the rewrite should be unstaged, so the move can be committed alone"
)

# --- 3. history survives when the printed order is followed -----------------------------------
( cd "$D"
  git commit -qm "move" && git add -A && git commit -qm "rewrite"
  # Reaching the commit the file was born in is the property. Counting commits is not: a file the
  # rewrite never touched — one that named no path — legitimately appears in one commit fewer.
  for f in ai-factory/AGENTS.md ai-factory/specs/0000-scaffold.md ai-factory/adr/0000-template.md; do
    git log --follow --format=%s -- "$f" | grep -qx 'adopted at 0.27.1' \
      || fail "git log --follow does not reach the original commit for $f — the move lost its history:
$(git log --follow --format='  %h %s' -- "$f")"
  done
)

# --- 4. the rewrite changed paths and nothing else (ADR 0008) ---------------------------------
( cd "$D"
  node -e '
    const cp=require("child_process"), { rewrite }=require(process.argv[1]);
    const show=(rev,f)=>cp.execSync(`git show ${rev}:"${f}"`,{encoding:"utf8",stdio:["ignore","pipe","ignore"]});
    const files=cp.execSync("git diff --name-only HEAD~1 HEAD",{encoding:"utf8"}).trim().split("\n").filter(Boolean);
    const bad=[]; let n=0;
    for (const f of files) {
      let a; try { a=show("HEAD~1",f); } catch { continue; }   // new file: nothing to compare
      const b=show("HEAD",f);
      n++; if (b !== rewrite(a)) bad.push(f);
    }
    if (bad.length) { console.error("not a path-only change: "+bad.join(", ")); process.exit(1); }
    if (n < 5) { console.error("only "+n+" files compared — the assertion is vacuous"); process.exit(1); }
  ' "$REWRITE" || fail "the migration changed more than path strings (ADR 0008 bounds it to paths)"
)

# --- 5. the manifest it leaves behind is a usable baseline (AC18) ------------------------------
out=$(node "$ROOT/skills/ai-layout/scripts/manifest.js" check "$D" "$ROOT")
grep -q 'removed upstream' <<<"$out" && fail "manifest reports files removed upstream after a migration:
$out"
grep -q 'missing locally' <<<"$out"  && fail "manifest reports files missing locally after a migration:
$out"
grep -q 'new upstream' <<<"$out"     && fail "manifest reports new upstream files after a migration:
$out"

# --- 6. already migrated: a no-op, twice ------------------------------------------------------
before=$( cd "$D" && git status --porcelain; cd "$D" && git rev-parse HEAD )
out=$(run "$D") || fail "migrate refused a repo that is already migrated"
grep -q 'nothing to move' <<<"$out" || fail "an already-migrated repo was not told there is nothing to move: $out"
out2=$(run "$D") || fail "the second run on an already-migrated repo failed"
after=$( cd "$D" && git status --porcelain; cd "$D" && git rev-parse HEAD )
[ "$before" = "$after" ] || fail "running it on a migrated repo changed the tree"

# --- 7. the refusals: each names its own reason, and moves nothing -----------------------------
refuses() {                     # refuses <name> <expected phrase> <setup>
  local name=$1 want=$2 setup=$3
  local d=$TMP/ref-$name
  mkdir -p "$d"; ( cd "$d" && eval "$setup" ) >/dev/null 2>&1
  local snap out rc
  snap=$( cd "$d" && find . -not -path './.git/*' | sort )
  out=$( cd "$d" && bash "$MIGRATE" 2>&1 ) && rc=0 || rc=$?
  [ "$rc" != 0 ] || fail "$name: expected a refusal, got exit 0"
  grep -qF "$want" <<<"$out" || fail "$name: the refusal does not say why (wanted \"$want\"):
$out"
  [ "$snap" = "$( cd "$d" && find . -not -path './.git/*' | sort )" ] \
    || fail "$name: the refusal moved something — refusals must write nothing"
}
refuses not-git   "not a git repository"        "mkdir ai"
refuses neither   "no layout in this repo"      "$(declare -f gitinit); gitinit"
refuses both      "half migrated"               "$(declare -f gitinit); gitinit; mkdir -p ai ai-factory; touch keep; git add -A; git commit -qm x"
refuses specs     "both specs/ and ai-factory/specs/" "$(declare -f gitinit); gitinit; mkdir -p ai specs ai-factory/specs; echo a > specs/1.md; echo b > ai-factory/specs/1.md; git add -A; git commit -qm x"
refuses adr       "both docs/adr/ and ai-factory/adr/" "$(declare -f gitinit); gitinit; mkdir -p ai docs/adr ai-factory/adr; echo a > docs/adr/1.md; echo b > ai-factory/adr/1.md; git add -A; git commit -qm x"
refuses dirty     "tracked files"              "$(declare -f gitinit); gitinit; mkdir -p ai/docs; echo x > ai/docs/a.md; git add -A; git commit -qm x; echo more >> ai/docs/a.md"

# ...but an untracked file is not work in flight. It blocks nothing: it is named, and the move runs.
# This is the case that refused in a live run, for a scratch directory an MCP server had created.
D4=$TMP/untracked; mk027 "$D4"
mkdir -p "$D4/.some-mcp-tool" && : > "$D4/.some-mcp-tool/cache"
out=$( cd "$D4" && bash "$MIGRATE" 2>&1 ) || fail "an untracked file blocked the migration:
$out"
grep -q 'untracked files' <<<"$out" || fail "the untracked file was not named in the output:
$out"
[ -d "$D4/ai-factory" ] || fail "the migration did not run with an untracked file present"

# --- 8. ai/ alone, with neither specs/ nor docs/adr/ ------------------------------------------
D2=$TMP/bare; mkdir -p "$D2"
( cd "$D2" && gitinit && mkdir -p ai/docs ai/tasks \
  && printf 'Read ai/AGENTS.md\n' > ai/tasks/spec.md && printf '# x\n' > ai/AGENTS.md \
  && git add -A && git commit -qm x ) >/dev/null
out=$(run "$D2") || fail "migrate refused a repo that has ai/ but no specs/ or docs/adr/: $out"
[ -d "$D2/ai-factory" ] || fail "bare repo: ai-factory/ was not created"
grep -q 'ai-factory/AGENTS.md' "$D2/ai-factory/tasks/spec.md" || fail "bare repo: the prompt was not rewritten"

# --- 8b. a directory git mv cannot move, and a run that died halfway ---------------------------
# The reason these exist: `git mv` fails on a directory whose contents are all untracked, and that
# fatal used to land after ai/ had already moved — leaving the repo wrecked and the NEXT run
# reporting "nothing to move" with exit 0. Both halves are pinned: the refusal, and the resume.
D5=$TMP/untracked-dir; mkdir -p "$D5"
( cd "$D5" && gitinit && mkdir -p ai/docs specs && printf '# x\n' > ai/AGENTS.md \
  && printf -- '- `ai/runs/`\n' > ai/docs/dont-touch.md && git add -A && git commit -qm x \
  && printf '# never committed\n' > specs/0001-draft.md ) >/dev/null 2>&1   # path-scan-ok
snap=$( cd "$D5" && find . -not -path './.git/*' | sort )
out=$( cd "$D5" && bash "$MIGRATE" 2>&1 ) && fail "a directory holding only untracked files did not refuse:
$out"
grep -q 'none of them is tracked' <<<"$out" || fail "the refusal does not say why the directory cannot be moved:
$out"
[ "$snap" = "$( cd "$D5" && find . -not -path './.git/*' | sort )" ] \
  || fail "the untracked-directory refusal moved something — it fires after the first git mv"

# A repo where only the first move landed: ai/ gone, specs/ still at the root, prompts still stale.
D6=$TMP/interrupted; mk027 "$D6"
( cd "$D6" && git mv ai ai-factory && git commit -qm "interrupted" ) >/dev/null 2>&1
out=$( cd "$D6" && bash "$MIGRATE" 2>&1 ) || fail "an interrupted migration could not be resumed:
$out"
grep -q 'nothing to move' <<<"$out" && fail "an interrupted repo was told there is nothing to move — a broken repo with a false all-clear"
[ -d "$D6/ai-factory/specs" ] || fail "the resumed run did not finish moving specs/"
[ ! -d "$D6/specs" ] || fail "the resumed run left specs/ at the root"
grep -q 'ai-factory/specs/' "$D6/ai-factory/tasks/spec.md" || fail "the resumed run did not rewrite the prompts"

# --- 8c. AC14's other docs/ clause: untouched if it held anything else -------------------------
# Only "docs/ is gone when it held nothing but adr/" was asserted. Nothing would have failed if the
# rmdir grew into an rm -rf, which in an adopted repo deletes the developer's own documentation.
D7=$TMP/own-docs; mk027 "$D7"
( cd "$D7" && mkdir -p docs && printf '# our runbook\n' > docs/runbook.md \
  && git add -A && git commit -qm "a doc of our own" ) >/dev/null 2>&1
out=$( cd "$D7" && bash "$MIGRATE" 2>&1 ) || fail "migrate refused a repo with its own docs/:
$out"
[ -d "$D7/docs" ] || fail "docs/ was removed although it held the repo's own documentation"
[ -f "$D7/docs/runbook.md" ] || fail "the repo's own doc was deleted by the migration"
[ -d "$D7/ai-factory/adr" ] || fail "docs/adr/ was not moved out of a docs/ that had to survive"

# --- 9. text that already names both directories ------------------------------------------------
# Not a supported repo state — the refusals catch the real half-migrated cases — but a file can
# still hold both names, and the rewriter must not corrupt it. Two shapes are pinned.
#
# A both-name alternation survives untouched, which is the outcome worth having and is not luck:
# in `(ai-factory|ai)/tasks/` the closing paren sits between `ai` and the slash, so there is no
# `ai/` to match. A repo that has taken a newer sync-adapters.sh keeps its working cleanup.
D3=$TMP/mixed; mkdir -p "$D3"
printf 'grep -qE "(ai-factory|ai)/tasks/"\n' > "$D3/alt.sh"
cp "$D3/alt.sh" "$D3/alt.expected"
node "$REWRITE" "$D3/alt.sh" >/dev/null
cmp -s "$D3/alt.sh" "$D3/alt.expected" \
  || fail "a both-name alternation was rewritten; it must be left alone:
$(cat "$D3/alt.sh")"

# Prose naming both paths converges on the new one rather than doubling a prefix.
printf 'moved from ai/tasks/ to ai-factory/tasks/ today\n' > "$D3/prose.md"
node "$REWRITE" "$D3/prose.md" >/dev/null
grep -qx 'moved from ai-factory/tasks/ to ai-factory/tasks/ today' "$D3/prose.md" \
  || fail "a line naming both paths was not normalised to ai-factory/:
$(cat "$D3/prose.md")"

echo "migrate ok — 13 rewriter cases, a full 0.27.1 fixture migrated, history preserved across the two commits, path-only, manifest clean, 6 refusals, bare repo, mixed-name behaviour pinned"
