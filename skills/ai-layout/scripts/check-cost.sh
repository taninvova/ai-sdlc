#!/usr/bin/env bash
# Pins the `make cost` reader in skills/ai-layout/templates/ai-factory/make/cost.js against the
# fixture logs in skills/ai-hooks/fixtures/cost/, whose totals are known by construction (AC22).
#
# Why the fixtures carry the totals rather than the code. Every expected value below is a literal
# written down from reading the fixture by hand, and every sum is recomputed here from the CSV by
# a second, independent route — awk over a column, or a node reader that finds a field by counting
# from the END of the record so a quoted comma cannot shift it. Asking cost.js what the answer is
# and then asserting it matches would assert nothing.
#
# What each case exists to catch:
#   quoted        a comma and a newline inside a quoted field, each kept within one record (AC13)
#   wrong-width   an over-width row and a 16-field pre-0007 row, both excluded and counted
#                 (AC14, AC15) — the pre-0007 cumulative row needs no detector of its own, it is
#                 simply the wrong width under a 17-column header
#   unreadable    an unclosed quote, which width() reports as -1: a third category, neither
#                 conforming nor of some other width, and excluded from every total
#   bad-header    a header that cannot itself be measured — the reader invents no header and reads
#                 no field rather than guessing at the columns
#   reordered     a header in a different order with no `agent` column at all. This is the sharpest
#                 case here: spec 0007 put `agent` at position 8, and this fixture carries
#                 `accepted` in that slot, so a reader written against a fixed index would report
#                 "yes" as the agent. Reading by name answers "" for a column the header lacks.
#   empty-task    rows with an empty `task`, an empty `agent`, or both (AC11's inputs)
#   header-only   a log holding nothing but its header (AC10)
#   missing       no file at all (AC10) — readLog answers, it does not throw
# And finally: the fixtures are byte-identical after the whole run. The reader must not touch what
# it reads (AC16).
#
# Steps 1-3 of ai-factory/plans/0008-make-cost-report-and-export.md: the reader, this harness and
# the aggregation engine. The export's field names and the rendered table arrive in later steps
# and extend this file.
set -euo pipefail
shopt -s nullglob
cd "$(dirname "$0")/../../.."   # repo root
COST=$PWD/skills/ai-layout/templates/ai-factory/make/cost.js
FX=$PWD/skills/ai-hooks/fixtures/cost
SCHEMA=$PWD/skills/ai-hooks/scripts/_log-schema.js
fail() { echo "FAIL: $*" >&2; exit 1; }
# eq <what> <got> <want>
eq() { [ "$2" = "$3" ] || fail "$1: got '$2', want '$3'"; }

[ -f "$COST" ] || fail "the reader is missing: $COST"

# The fixtures must not drift from the header the two writers agree on, or this whole file would
# be pinning the reader against a schema nothing writes.
HEADER=$(sed -n 's/^const HEADER = "\(.*\)";$/\1/p' "$SCHEMA" | head -1)
[ -n "$HEADER" ] || fail "could not read HEADER from $SCHEMA"

# Byte-identity, half one: the checksum of every fixture before a single read.
sums() { shasum "$FX"/*.csv | shasum | cut -d' ' -f1; }
BEFORE=$(sums)

# Scratch space for the export assertions, which need stdout and stderr captured separately.
SCRATCH=$(mktemp -d); trap 'rm -rf "$SCRATCH"' EXIT
TMPOUT=$SCRATCH/out.json; TMPERR=$SCRATCH/err.txt; TMPOUT2=$SCRATCH/out2.json
TMPTSV=$SCRATCH/out.tsv; TMPTSV2=$SCRATCH/out2.tsv
TMPTAB=$SCRATCH/out.txt; TMPTAB2=$SCRATCH/out2.txt

# maxlen <file> — the longest line in CHARACTERS. awk length() counts bytes here and the em-dash in
# several messages is three of them, which would report a compliant line as too wide.
maxlen() { node -e 'const fs=require("fs");const l=fs.readFileSync(process.argv[1],"utf8").split("\n").filter(x=>x!=="");console.log(l.length?Math.max(...l.map(x=>[...x].length)):0);' "$1"; }

# rd <fixture> <js> — evaluates <js> with `C` bound to the module and `L` to readLog()'s answer
# over the fixture. Whatever it prints comes back.
rd() { node -e "const C = require('$COST'); const L = C.readLog('$FX/$1'); $2"; }
# counts <fixture> — "exists|columns|records|conforming|wrongWidth|unreadable"
counts() { rd "$1" 'const c = L.counts; console.log([L.exists, L.columns, c.records, c.conforming, c.wrongWidth, c.unreadable].join("|"));'; }
# sum <fixture> <column> — the reader's conforming rows summed over one column BY NAME. The
# arithmetic is this script's; the reader only supplies the parsed rows.
sum() { rd "$1" "console.log(L.rows.reduce((n, r) => n + Number(C.field(r, '$2') || 0), 0));"; }
# tail_sum <fixture> <from-end> — the same total by an independent route: records are re-split
# here (a line beginning with a year starts one, anything else continues the one before, which is
# how a quoted newline stays inside its record), and the field is counted from the end so a quoted
# comma earlier in the record cannot shift the index. input_tokens is 7 fields from the end of the
# 17-column header, output_tokens 6.
tail_sum() { node -e '
  const fs = require("fs"); const recs = [];
  for (const l of fs.readFileSync(process.argv[1], "utf8").split("\n")) {
    if (l === "") continue;
    if (!recs.length || /^\d{4}-\d\d-\d\d/.test(l)) recs.push(l); else recs[recs.length - 1] += "\n" + l;
  }
  recs.shift();   // the header
  let n = 0; for (const r of recs) { const p = r.split(","); n += Number(p[p.length - Number(process.argv[2])]); }
  process.stdout.write(String(n));' "$FX/$1" "$2"; }

# --- 1. quoted.csv — a quoted comma and a quoted newline, one record each (AC13) ---------------
# Three records over four data lines. A line-based reader would find four rows and judge two of
# them malformed; the record-aware one finds three, all conforming.
eq "quoted.csv: counts" "$(counts quoted.csv)" "true|17|3|3|0|0"
eq "quoted.csv: header pinned to the writers'" "$(head -1 "$FX/quoted.csv")" "$HEADER"
eq "quoted.csv: input_tokens total"  "$(sum quoted.csv input_tokens)"  600
eq "quoted.csv: output_tokens total" "$(sum quoted.csv output_tokens)" 60
eq "quoted.csv: input_tokens total, summed independently"  "$(tail_sum quoted.csv 7)" 600
eq "quoted.csv: output_tokens total, summed independently" "$(tail_sum quoted.csv 6)" 60
# In full, not merely once: the comma and the newline survive inside the field that held them.
eq "quoted.csv: the quoted comma stays in task" \
  "$(rd quoted.csv 'process.stdout.write(C.field(L.rows[0], "task"));')" "run,step 2"
eq "quoted.csv: the quoted newline stays in task" \
  "$(rd quoted.csv 'process.stdout.write(JSON.stringify(C.field(L.rows[1], "task")));')" '"spec 0008\nstep three"'
# The record that spans two lines is still a row like any other: the columns after the newline
# line up, rather than being shifted by it.
eq "quoted.csv: the split record's columns still line up" \
  "$(rd quoted.csv 'process.stdout.write([C.field(L.rows[1], "input_tokens"), C.field(L.rows[1], "model"), C.field(L.rows[1], "agent")].join("|"));')" \
  "200|claude-sonnet-4-5|implementer"

# --- 2. wrong-width.csv — an over-width row and a pre-0007 row, excluded and counted -----------
# Four records: two conforming (111 + 222 = 333), one 18-field row, and one 16-field cumulative
# snapshot from before spec 0007 added `agent`. Neither excluded row is reinterpreted into the
# columns that do exist, and neither is dropped silently — both are kept for the count.
eq "wrong-width.csv: counts" "$(counts wrong-width.csv)" "true|17|4|2|2|0"
eq "wrong-width.csv: header pinned to the writers'" "$(head -1 "$FX/wrong-width.csv")" "$HEADER"
eq "wrong-width.csv: input_tokens total excludes both" "$(sum wrong-width.csv input_tokens)" 333
# Independently: awk over the 17-field lines only. 9000 and 999 must be nowhere in that total.
eq "wrong-width.csv: input_tokens total, summed independently" \
  "$(awk -F, 'NR>1 && NF==17 {s+=$11} END {print s+0}' "$FX/wrong-width.csv")" 333
eq "wrong-width.csv: the excluded records are retained for the count" \
  "$(rd wrong-width.csv 'console.log(L.wrongWidth.length);')" 2
eq "wrong-width.csv: the pre-0007 row is one of them" \
  "$(rd wrong-width.csv 'console.log(L.wrongWidth.filter(r => r.split(",").length === 16).length);')" 1
eq "wrong-width.csv: the over-width row is the other" \
  "$(rd wrong-width.csv 'console.log(L.wrongWidth.filter(r => r.split(",").length === 18).length);')" 1

# --- 3. unreadable.csv — an unclosed quote is a third category -------------------------------
# width() reports -1 for a record it cannot measure at all, so the record is neither conforming
# nor of some other width. One conforming row of 42 tokens; the unreadable record claims 777,
# which must not appear anywhere.
eq "unreadable.csv: counts" "$(counts unreadable.csv)" "true|17|2|1|0|1"
eq "unreadable.csv: input_tokens total" "$(sum unreadable.csv input_tokens)" 42
eq "unreadable.csv: input_tokens total, read independently" \
  "$(awk -F, 'NR==2 {print $11}' "$FX/unreadable.csv")" 42
eq "unreadable.csv: width() measures the unreadable record as -1" \
  "$(rd unreadable.csv 'console.log(C.width(L.unreadable[0]));')" -1

# --- 4. bad-header.csv — an unmeasurable header invents no header -----------------------------
# The header line itself carries an unclosed quote. records() can only close a record when the
# quote closes, so the whole file accumulates into the header record and there are no rows below
# it to classify — which is why `records` and `unreadable` are both 0 here rather than 2. What
# matters is what does NOT happen: no column names are guessed, no row is parsed, the two rows'
# 500 and 600 tokens reach no total, and nothing throws.
eq "bad-header.csv: counts" "$(counts bad-header.csv)" "true|-1|0|0|0|0"
eq "bad-header.csv: no header was invented" "$(rd bad-header.csv 'console.log(L.names.length);')" 0
eq "bad-header.csv: no row was read"        "$(rd bad-header.csv 'console.log(L.rows.length);')" 0
eq "bad-header.csv: nothing reaches a total" "$(sum bad-header.csv input_tokens)" 0

# --- 5. reordered.csv — fields are read by name, and a missing column is "" -------------------
# 16 columns, in a different order, with no `agent` at all and `accepted` sitting in position 8 —
# where spec 0007 put `agent`. A reader indexing by position would report the agent as "yes".
eq "reordered.csv: counts" "$(counts reordered.csv)" "true|16|2|2|0|0"
eq "reordered.csv: a header without agent is not the writers' header" \
  "$(head -1 "$FX/reordered.csv" | grep -c ',agent,' || true)" 0
eq "reordered.csv: the absent agent column reads as empty, not as position 8" \
  "$(rd reordered.csv 'process.stdout.write(L.rows.map(r => JSON.stringify(C.field(r, "agent"))).join("|"));')" '""|""'
eq "reordered.csv: position 8 is accepted, and it is read as accepted" \
  "$(rd reordered.csv 'process.stdout.write(L.rows.map(r => C.field(r, "accepted")).join("|"));')" "yes|no"
eq "reordered.csv: the reordered columns are read by name" \
  "$(rd reordered.csv 'process.stdout.write(L.rows.map(r => C.field(r, "input_tokens")).join("|"));')" "500|600"
eq "reordered.csv: input_tokens total" "$(sum reordered.csv input_tokens)" 1100
eq "reordered.csv: input_tokens total, summed independently" \
  "$(awk -F, 'NR>1 && NF==16 {s+=$11} END {print s+0}' "$FX/reordered.csv")" 1100

# --- 6. empty-task.csv — the rows AC11's unattributed bucket is built from ---------------------
# Four conforming rows, 10 + 20 + 30 + 40 = 100 tokens: one attributed, one with no task, one with
# no agent, one with neither. All four are read; none is dropped for being unattributed. What the
# bucket is CALLED and how it prints is Step 3's assertion, not this one's.
eq "empty-task.csv: counts" "$(counts empty-task.csv)" "true|17|4|4|0|0"
eq "empty-task.csv: header pinned to the writers'" "$(head -1 "$FX/empty-task.csv")" "$HEADER"
eq "empty-task.csv: input_tokens total" "$(sum empty-task.csv input_tokens)" 100
eq "empty-task.csv: input_tokens total, summed independently" \
  "$(awk -F, 'NR>1 && NF==17 {s+=$11} END {print s+0}' "$FX/empty-task.csv")" 100
eq "empty-task.csv: rows with no task"  "$(rd empty-task.csv 'console.log(L.rows.filter(r => C.field(r, "task") === "").length);')"  2
eq "empty-task.csv: rows with no agent" "$(rd empty-task.csv 'console.log(L.rows.filter(r => C.field(r, "agent") === "").length);')" 2
eq "empty-task.csv: rows with neither"  "$(rd empty-task.csv 'console.log(L.rows.filter(r => C.field(r, "task") === "" && C.field(r, "agent") === "").length);')" 1

# --- 7. header-only.csv and a missing file — AC10's two empty shapes --------------------------
# Both must be distinguishable from each other and from a log with rows, because AC10 makes the
# report name the file it read and the count it found. Header-only: the file exists and its 17
# columns are known. Missing: nothing exists, and readLog answers rather than throwing.
eq "header-only.csv: counts" "$(counts header-only.csv)" "true|17|0|0|0|0"
eq "header-only.csv: header pinned to the writers'" "$(head -1 "$FX/header-only.csv")" "$HEADER"
eq "header-only.csv: the columns are still known" "$(rd header-only.csv 'console.log(L.names.length);')" 17
eq "missing: counts" "$(counts no-such-log.csv)" "false|0|0|0|0|0"
eq "missing: the file read is reported back" \
  "$(rd no-such-log.csv 'process.stdout.write(require("path").basename(L.file));')" "no-such-log.csv"

# --- 9. the aggregation engine (AC2, AC4, AC11, AC12) -----------------------------------------
# ag <fixture> <js> — like rd, with `A` bound to aggregate()'s answer as well as `L`.
ag() { node -e "const C = require('$COST'); const A = C.aggregate(C.readLog('$FX/$1')); $2"; }
# grp <fixture> <dimension> — "key=rows/input_tokens" per group, in the engine's own order.
grp() { ag "$1" "console.log(A.groups['$2'].map(g => g.key + '=' + g.rows + '/' + g.input_tokens).join(' '));"; }

# hit_rate is RECOMPUTED from the summed tokens, never averaged over rows. hit-rate.csv exists to
# make the difference impossible to miss: its two rows are 100/(0+100+0) = 1.00 and
# 100/(300+100+0) = 0.25, whose mean is 0.625, while the group's true rate is the summed
# 200/(300+200+0) = 0.40. A mean would weight a 100-token row like a 400-token one; on this repo's
# real log the two ends differ by six orders of magnitude.
eq "hit-rate.csv: summed tokens" \
  "$(ag hit-rate.csv 'const t = A.totals; console.log([t.rows, t.turns, t.input_tokens, t.cache_read_tokens, t.cache_write_tokens].join("|"));')" \
  "2|2|300|200|0"
eq "hit-rate.csv: hit_rate recomputed from the sums, not averaged" \
  "$(ag hit-rate.csv 'console.log(A.totals.hit_rate);')" "0.4"
# Per GROUP as well as in the totals, which are computed by separate lines: pinning only the total
# would let a broken group rate through, and the groups are what a reader actually looks at. Both
# rows of this fixture are task=run, so the single group's rate must equal the total's.
eq "hit-rate.csv: the task group's hit_rate is recomputed too, not averaged" \
  "$(ag hit-rate.csv 'console.log(A.groups.task.map(g => g.key + "=" + g.hit_rate).join(" "));')" "run=0.4"
eq "hit-rate.csv: every dimension's group agrees with the total for a single-group log" \
  "$(ag hit-rate.csv 'console.log(A.dimensions.every(d => A.groups[d].length === 1 && A.groups[d][0].hit_rate === A.totals.hit_rate));')" \
  "true"
eq "hit-rate.csv: the mean of the per-row rates is a different number, so this assertion bites" \
  "$(rd hit-rate.csv 'const v = L.rows.map(r => Number(C.field(r, "hit_rate"))); console.log(v.reduce((a, b) => a + b, 0) / v.length);')" \
  "0.625"
# AC12: coverage, never an average. One of the two rows carries `accepted`.
eq "hit-rate.csv: accepted coverage" \
  "$(ag hit-rate.csv 'console.log(A.accepted.covered + " of " + A.accepted.of);')" "1 of 2"
eq "bad-ts.csv: no row carries accepted, so coverage is zero of three" \
  "$(ag bad-ts.csv 'console.log(A.accepted.covered + " of " + A.accepted.of);')" "0 of 3"

# AC11: an empty `task` or a missing `agent` goes to a NAMED bucket with its count visible, never
# dropped and never folded into another group. empty-task.csv holds 4 rows: 2 with no task, 2 with
# no agent, 1 with neither, and input_tokens 10+20+30+40.
eq "empty-task.csv: task groups" "$(grp empty-task.csv task)" "(unattributed)=2/60 run=2/40"
eq "empty-task.csv: agent groups" "$(grp empty-task.csv agent)" "(unattributed)=2/70 implementer=2/30"
eq "empty-task.csv: nothing was dropped — the groups sum to the total" \
  "$(ag empty-task.csv 'const s = A.groups.task.reduce((n, g) => n + g.input_tokens, 0); console.log(s === A.totals.input_tokens ? "equal" : s + " vs " + A.totals.input_tokens);')" \
  "equal"
eq "the unattributed bucket is a name no real value can be" \
  "$(ag empty-task.csv 'console.log(A.unattributed);')" "(unattributed)"

# `day` is derived from `ts`, which the log has no column for. A row whose ts is empty or
# unparseable is bucketed as unattributed, never dated today — spend on a day that did not happen
# is worse than spend with no day. bad-ts.csv: one dated row (10), one empty ts (20), one "not-a-timestamp" (30).
eq "bad-ts.csv: day groups" "$(grp bad-ts.csv day)" "(unattributed)=2/50 2026-09-27=1/10"

# AC4: the session key survives into the aggregate, so a fleet view reading two layouts' exports
# can tell one session written to both. session-a.csv and session-b.csv share `shared-99`.
eq "session-a.csv: sessions" "$(grp session-a.csv session)" "only-a=1/11 shared-99=1/10"
eq "session-b.csv: sessions" "$(grp session-b.csv session)" "only-b=1/22 shared-99=1/20"
eq "the shared session_id survives into both aggregates" \
  "$(node -e "const C = require('$COST'); const k = f => C.aggregate(C.readLog('$FX/' + f)).groups.session.some(g => g.key === 'shared-99'); console.log(k('session-a.csv') && k('session-b.csv'));")" \
  "true"

# Every dimension the spec names is present, and `cost_usd` is not among the metrics: the decision
# of 2026-09-27 keeps money out of both surfaces, so the engine never opens that column.
eq "the dimensions are the eight the spec names" \
  "$(ag hit-rate.csv 'console.log(A.dimensions.join(","));')" \
  "task,agent,tool,model,branch,user,day,session"
eq "no cost metric exists" \
  "$(ag hit-rate.csv 'console.log(A.metrics.some(m => /cost/.test(m)));')" "false"
# Code only, not prose: cost.js explains in a comment that the column is deliberately unread, and
# that sentence is worth keeping. Full-line comments are stripped before looking.
if grep -vE '^[[:space:]]*//' "$COST" | grep -q 'cost_usd'; then
  fail "$COST reads cost_usd outside a comment; the reader must never open that column"
fi

# Only conforming rows reach a total, and the two excluded kinds stay separate (AC14's revised
# wording): wrong-width.csv has one 18-field row and one 16-field pre-0007 row, neither counted.
eq "wrong-width.csv: excluded records reach no total, and the counts stay distinct" \
  "$(ag wrong-width.csv 'const c = A.counts; console.log([A.totals.input_tokens, c.conforming, c.wrongWidth, c.unreadable].join("|"));')" \
  "333|2|2|0"
eq "unreadable.csv: the torn record is counted apart from wrong-width ones" \
  "$(ag unreadable.csv 'const c = A.counts; console.log([A.totals.input_tokens, c.wrongWidth, c.unreadable].join("|"));')" \
  "42|0|1"
# An empty log aggregates to zeroes rather than throwing, and a bad header carries no groups.
eq "header-only.csv: aggregates to nothing without throwing" \
  "$(ag header-only.csv 'console.log([A.totals.rows, A.groups.task.length, A.accepted.covered].join("|"));')" "0|0|0"
eq "bad-header.csv: no groups invented from a header that cannot be measured" \
  "$(ag bad-header.csv 'console.log([A.columns, A.groups.task.length, A.totals.rows].join("|"));')" "-1|0|0"
# Determinism: the same log twice gives byte-identical group ordering.
eq "the group order is stable across runs" \
  "$(grp empty-task.csv task)" "$(grp empty-task.csv task)"

# --- 10. the export is a contract (AC1, AC2, AC6) ---------------------------------------------
# ex <fixture> <js> — `D` is the parsed document that JSON mode wrote to stdout, so these
# assertions go through the real entry point rather than calling exportDoc() directly.
ex() { JSON=1 node "$COST" "$FX/$1" | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{const D=JSON.parse(s); $2});"; }

# AC1: one document and nothing else. Not "it parses" — that would pass with a banner on the line
# before, since JSON.parse of a leading banner throws but a trailing one might not. The whole of
# stdout is parsed, and stderr is required to be empty too.
JSON=1 node "$COST" "$FX/empty-task.csv" > "$TMPOUT" 2> "$TMPERR" || fail "JSON mode exited non-zero"
eq "JSON mode: stderr is empty" "$(wc -c < "$TMPERR" | tr -d ' ')" 0
eq "JSON mode: stdout is exactly one JSON document" \
  "$(node -e 'const fs=require("fs");const s=fs.readFileSync(process.argv[1],"utf8");JSON.parse(s);console.log("one");' "$TMPOUT")" \
  "one"
eq "JSON mode: nothing precedes the document" "$(head -c 1 "$TMPOUT")" "{"
# Reproducible, as coding-standards.md requires of generated output: two runs, byte for byte.
JSON=1 node "$COST" "$FX/empty-task.csv" > "$TMPOUT2" 2>/dev/null
cmp -s "$TMPOUT" "$TMPOUT2" || fail "JSON mode is not reproducible; two runs over one log differ"

# AC6's pin. Every field name in the document, gathered recursively, as one sorted list. This fails
# on a rename, a removal AND an addition — an addition does not move the version (a consumer
# reading version 1 keeps working when a field it ignores appears), but it must not slip in
# unnoticed, so the expected set below has to be edited deliberately.
NAMES=$(ex empty-task.csv '
  const seen = new Set();
  (function walk(v) {
    if (Array.isArray(v)) return v.forEach(walk);
    if (v && typeof v === "object") for (const k of Object.keys(v)) { seen.add(k); walk(v[k]); }
  })(D);
  console.log([...seen].sort().join(","));')
# `status` was added in step 7, deliberately: the version stays 1 because a consumer reading
# version 1 keeps working without it, but this list had to be edited by hand for the check to pass
# again — which is the whole point of failing on an addition.
eq "the export's field names, exactly" "$NAMES" \
  "accepted,agent,branch,cache_read_tokens,cache_write_tokens,conforming,counts,covered,day,dimensions,groups,hit_rate,input_tokens,key,log,metrics,model,of,output_tokens,records,rows,schema,session,status,task,tool,totals,turns,unattributed,unreadable,user,version,wrongWidth"

eq "the schema is named" "$(ex empty-task.csv 'console.log(D.schema);')" "ai-sdlc-cost"
eq "the version is the integer 1" "$(ex empty-task.csv 'console.log(D.version + "|" + (typeof D.version));')" "1|number"
# AC2: agent and tool are two independent dimensions, and no value is ever a composite. If the
# agent were folded into tool, a consumer would have to split "claude/implementer" to recover it.
eq "agent and tool are separate dimensions" \
  "$(ex empty-task.csv 'console.log(D.dimensions.includes("agent") && D.dimensions.includes("tool"));')" "true"
eq "no group key is a composite of tool and agent" \
  "$(ex empty-task.csv 'console.log(D.dimensions.every(d => D.groups[d].every(g => !/[\/|]/.test(g.key))));')" "true"
eq "every dimension the document names carries a group list" \
  "$(ex empty-task.csv 'console.log(D.dimensions.every(d => Array.isArray(D.groups[d])));')" "true"
eq "every group carries every published metric" \
  "$(ex empty-task.csv 'console.log(D.dimensions.every(d => D.groups[d].every(g => D.metrics.every(m => typeof g[m] === "number"))));')" "true"
eq "no cost field is published" \
  "$(ex empty-task.csv 'console.log(D.metrics.some(m => /cost/.test(m)) || Object.keys(D.totals).some(k => /cost/.test(k)));')" "false"
# AC4 through the real export: the session key reaches a consumer.
eq "the session key survives into the document" \
  "$(ex session-a.csv 'console.log(D.groups.session.map(g => g.key).join(" "));')" "only-a shared-99"
# The numbers in the document are the engine's, not a second implementation (AC7's export half).
# empty-task.csv by hand: 4 rows, input 10+20+30+40 = 100, cache_read 100+200+300+400 = 1000,
# cache_write 0 — so the rate is 1000/1100. Written as the fraction rather than as a copied
# float, so the expectation stays legible and is derived from the fixture, not from the code.
eq "the document's totals match the engine's" \
  "$(ex empty-task.csv 'console.log([D.totals.rows, D.totals.input_tokens, D.totals.hit_rate === 1000 / 1100].join("|"));')" \
  "4|100|true"

# --- 11. the TSV form carries the same numbers, flat (AC5) ------------------------------------
TSV=1 node "$COST" "$FX/quoted.csv" > "$TMPTSV" 2> "$TMPERR" || fail "TSV mode exited non-zero"
eq "TSV mode: stderr is empty" "$(wc -c < "$TMPERR" | tr -d ' ')" 0
eq "TSV mode: the header names the JSON's fields, plus the dimension a flat form needs" \
  "$(head -1 "$TMPTSV")" \
  "$(printf 'dimension\tkey\trows\tturns\tinput_tokens\toutput_tokens\tcache_read_tokens\tcache_write_tokens\thit_rate')"
# One header line plus one line per group, and NOT one per group-plus-a-torn-key. quoted.csv holds
# a task whose name contains a real newline; unescaped it would split its line in two and a
# consumer would read two groups where there is one.
eq "TSV mode: one line per group, with a newline in a key escaped rather than splitting a line" \
  "$(wc -l < "$TMPTSV" | tr -d ' ')" \
  "$(ex quoted.csv 'console.log(1 + D.dimensions.reduce((n, d) => n + D.groups[d].length, 0));')"
eq "TSV mode: every line has as many fields as the header" \
  "$(awk -F'\t' 'NR==1{w=NF} NF!=w{bad++} END{print bad+0}' "$TMPTSV")" 0
# The escape is reversible: what a consumer decodes is the key the JSON carries, not an approximation.
eq "TSV mode: an escaped key decodes back to the JSON's key" \
  "$(node -e '
     const C = require(process.argv[1]);
     const a = C.aggregate(C.readLog(process.argv[2]));
     const cell = C.exportTsv(a).split("\n").find(l => l.startsWith("task\tspec")).split("\t")[1];
     const back = cell.replace(/\\n/g, "\n").replace(/\\t/g, "\t").replace(/\\r/g, "\r").replace(/\\\\/g, "\\");
     console.log(back === a.groups.task.find(g => g.key.startsWith("spec")).key);
   ' "$COST" "$FX/quoted.csv")" "true"
# AC5's point: the same numbers as the JSON, not a second implementation of the arithmetic.
eq "TSV mode: the numbers are the JSON's" \
  "$(awk -F'\t' '$1=="agent" && $2=="implementer" {print $3"|"$5"|"$9}' "$TMPTSV")" \
  "$(ex quoted.csv 'const g = D.groups.agent.find(x => x.key === "implementer"); console.log([g.rows, g.input_tokens, g.hit_rate].join("|"));')"
# It has to be legible on a machine with nothing else installed.
column -t < "$TMPTSV" > /dev/null || fail "the TSV does not pipe into column -t"
# Reproducible, like the JSON.
TSV=1 node "$COST" "$FX/quoted.csv" > "$TMPTSV2" 2>/dev/null
cmp -s "$TMPTSV" "$TMPTSV2" || fail "TSV mode is not reproducible; two runs over one log differ"
# The whole flag surface: two modes, no filters in v1 (decided 2026-09-27). With both set JSON
# wins — one of them must, and printing two documents to one stdout would be worse than either.
eq "with both modes set, JSON wins and only one document is written" \
  "$(JSON=1 TSV=1 node "$COST" "$FX/quoted.csv" | head -c 1)" "{"
eq "a filter variable is ignored rather than honoured" \
  "$(TSV=1 BRANCH=main TASK=run SINCE=2026-01-01 node "$COST" "$FX/quoted.csv" | wc -l | tr -d ' ')" \
  "$(wc -l < "$TMPTSV" | tr -d ' ')"

# --- 12. the rendered table (AC7, AC8, AC9, AC12) ---------------------------------------------
node "$COST" "$FX/two-tools.csv" > "$TMPTAB" 2> "$TMPERR" || fail "the default mode exited non-zero"
eq "table mode: stderr is empty" "$(wc -c < "$TMPERR" | tr -d ' ')" 0
# AC9, and over EVERY line: a 120-character footnote wraps as badly as a wide row.
eq "table mode: the widest line is within 80 characters" \
  "$(maxlen "$TMPTAB" | awk '{ print ($1 <= 80) ? "within" : "over (" $1 ")" }')" "within"
# AC8: the four groupings, each as its own table, and no other dimension's table.
eq "table mode: the four groupings AC8 names, in order" \
  "$(awk '$1=="task"||$1=="agent"||$1=="branch"||$1=="day" {printf "%s ", $1} END {print ""}' "$TMPTAB" | sed 's/ $//')" \
  "task agent branch day"
eq "table mode: no table for a dimension AC8 does not name" \
  "$(awk '$1=="tool"||$1=="model"||$1=="user"||$1=="session" {n++} END {print n+0}' "$TMPTAB")" 0
# AC7: the numbers are the engine's, identical to the export's — the table is a view, not a second
# implementation. hit is the exported ratio to two decimals, the convention the writers use per row.
eq "table mode: the agent row's numbers are the export's" \
  "$(awk '$1=="implementer" {print $2"|"$3"|"$4"|"$5"|"$6"|"$7}' "$TMPTAB")" \
  "$(ex two-tools.csv 'const g = D.groups.agent.find(x => x.key === "implementer"); console.log([g.rows, g.turns, g.input_tokens, g.output_tokens, g.cache_read_tokens].join("|") + "|" + g.cache_write_tokens);')"
eq "table mode: the displayed hit is the exported ratio to two decimals" \
  "$(awk '$1=="implementer" {print $8}' "$TMPTAB")" \
  "$(ex two-tools.csv 'const g = D.groups.agent.find(x => x.key === "implementer"); console.log(g.hit_rate.toFixed(2));')"
eq "table mode: the TOTAL line matches the export's totals" \
  "$(awk '$1=="TOTAL" {print $2"|"$4}' "$TMPTAB")" \
  "$(ex two-tools.csv 'console.log(D.totals.rows + "|" + D.totals.input_tokens);')"
# A key longer than the label column is truncated, not wrapped: AC9 forbids the wrap, and the
# untruncated key is always in the JSON and the TSV.
eq "table mode: an over-long key is truncated with a marker rather than wrapping" \
  "$(awk '/^feature\/a-very/ {print substr($1, length($1) - 2)}' "$TMPTAB")" "$(printf '\xe2\x80\xa6')"
# AC8's footnote: this fixture's rows come from two tools, which attribute agents differently.
eq "table mode: a multi-tool total carries a footnote naming the tools" \
  "$(grep -c 'totals span 2 tools (claude, codex)' "$TMPTAB")" 1
eq "table mode: a single-tool log carries no such footnote" \
  "$(node "$COST" "$FX/empty-task.csv" | grep -c 'totals span' || true)" 0
# AC12: the coverage line appears only when a row carries a value.
eq "table mode: coverage shown when a row carries accepted" \
  "$(grep -c '^accepted: 1 of 2 rows carry a value' "$TMPTAB")" 1
eq "table mode: no coverage line at all when no row carries one" \
  "$(node "$COST" "$FX/empty-task.csv" | grep -c '^accepted:' || true)" 0
# Excluded records are reported, and the two kinds separately (AC14).
eq "table mode: excluded records are reported as two distinct counts" \
  "$(node "$COST" "$FX/wrong-width.csv" | grep -c '^excluded: 2 of the wrong width, 0 unreadable')" 1
# Reproducible, like both export forms.
node "$COST" "$FX/two-tools.csv" > "$TMPTAB2" 2>/dev/null
cmp -s "$TMPTAB" "$TMPTAB2" || fail "the table is not reproducible; two runs over one log differ"

# --- 13. the empty and missing cases (AC10, AC19) ----------------------------------------------
# Three not-ok states, and the point of the third is that it is NOT detectable from the row count:
# an unclosed quote in the header swallows the whole file into one record, so a damaged log and an
# empty one both count zero rows. Reporting a damaged log as "nothing recorded yet" would lose data
# silently, so the state is decided by the header.
eq "status: a missing log"            "$(ex no-such-log.csv 'console.log(D.status);')" "missing"
eq "status: a header-only log"        "$(ex header-only.csv 'console.log(D.status);')" "empty"
eq "status: an unreadable header"     "$(ex bad-header.csv  'console.log(D.status);')" "unreadableHeader"
eq "status: a log with countable rows" "$(ex two-tools.csv  'console.log(D.status);')" "ok"
# A log whose only rows are excluded by AC14/AC15 counts as empty, not ok: nothing is countable.
eq "status: every row excluded means empty, not ok" \
  "$(node -e "const C=require('$COST');const fs=require('fs');const t=require('os').tmpdir()+'/only-bad.csv';fs.writeFileSync(t,fs.readFileSync('$FX/wrong-width.csv','utf8').split('\n').filter((l,i)=>i===0||l.split(',').length!==17).join('\n'));const a=C.aggregate(C.readLog(t));console.log(C.status(a));fs.unlinkSync(t);")" \
  "empty"

for case in no-such-log.csv header-only.csv bad-header.csv; do
  node "$COST" "$FX/$case" > "$TMPTAB" 2> "$TMPERR" || fail "table mode exited non-zero on $case"
  eq "$case: table mode exits 0 with empty stderr" "$(wc -c < "$TMPERR" | tr -d ' ')" 0
  # AC10: it names the file it read and the row count it found, rather than printing an empty table.
  grep -q "$case" "$TMPTAB" || fail "$case: the message does not name the file it read: $(cat "$TMPTAB")"
  # Each state phrases the count its own way — "0 rows to report", "0 record(s) read ... 0
  # counted", "0 rows were counted" — so the assertion is that a zero count is stated, not that
  # one particular sentence is.
  grep -qE "0 (rows?|record)" "$TMPTAB" || fail "$case: the message does not give the row count: $(cat "$TMPTAB")"
  eq "$case: no table header is printed at all" \
    "$(awk '$1=="task"||$1=="agent"||$1=="branch"||$1=="day"||$1=="TOTAL" {n++} END {print n+0}' "$TMPTAB")" 0
  # The path line is exempt, and only it: a path longer than the terminal cannot be wrapped
  # without breaking it, and a broken path is one nobody can paste or click.
  tail -n +2 "$TMPTAB" > "$SCRATCH/body.txt"
  eq "$case: every line but the path is within 80 characters" \
    "$(maxlen "$SCRATCH/body.txt" | awk '{ print ($1 <= 80) ? "within" : "over (" $1 ")" }')" "within"
  eq "$case: the first line is the path, alone" "$(head -1 "$TMPTAB")" "$FX/$case"
done
# The distinction AC10 now requires, in words a developer will act on differently.
# Joined into one line before matching: the message is wrapped at 80, so any phrase long enough to
# be worth asserting on is likely to straddle a line break.
flat() { node "$COST" "$1" | tr "\n" " " | tr -s " "; }
eq "a damaged log is called damaged, not empty" \
  "$(flat "$FX/bad-header.csv" | grep -c "damaged log, not an empty one")" 1
eq "an empty log is not called damaged" \
  "$(flat "$FX/header-only.csv" | grep -c "damaged" || true)" 0
# JSON keeps AC1: one document, no message banner — the state travels as a field.
eq "JSON mode on a missing log is still exactly one document" \
  "$(JSON=1 node "$COST" "$FX/no-such-log.csv" | head -c 1)" "{"
# TSV on an empty log is a header and no rows: parseable, rather than a sentence a consumer chokes on.
eq "TSV mode on an empty log is the header alone" \
  "$(TSV=1 node "$COST" "$FX/header-only.csv" | wc -l | tr -d ' ')" 1

# AC19: usable from the moment the layout lands. A freshly adopted repo has an ai-factory/ layout
# and no log yet, so this builds that state and runs the real entry point in it. The /t4:adopt-sdlc
# command itself needs the plugin installed, which is the same blocker as plan 0007 step 7; what is
# proved here is the state a fresh adopt leaves behind, not the ceremony of adopting.
FRESH=$SCRATCH/fresh
mkdir -p "$FRESH/ai-factory/runs"
( cd "$FRESH" && node "$COST" ai-factory/runs/log.csv > out.txt 2> err.txt ) || fail "a freshly adopted repo made the target fail"
eq "a fresh layout with no log: exits 0, stderr empty" "$(wc -c < "$FRESH/err.txt" | tr -d ' ')" 0
# The path is the first line and the explanation follows it, so both halves are asserted.
eq "a fresh layout names the log it looked for" "$(head -1 "$FRESH/out.txt")" "ai-factory/runs/log.csv"
grep -q "no log here yet" "$FRESH/out.txt" \
  || fail "a fresh layout did not explain the absent log: $(cat "$FRESH/out.txt")"
# And the moment the header exists but no row does — what the first ensureSchema leaves behind.
printf '%s\n' "$HEADER" > "$FRESH/ai-factory/runs/log.csv"
( cd "$FRESH" && node "$COST" ai-factory/runs/log.csv > out2.txt 2>&1 ) || fail "a header-only log made the target fail"
grep -q 'holds no countable row' "$FRESH/out2.txt" \
  || fail "a header-only log in a fresh layout was not explained: $(cat "$FRESH/out2.txt")"
# Read-only even here: the target must not create the log it failed to find.
[ ! -e "$FRESH/ai-factory/runs/log.pending.csv" ] || fail "the target created a pending log"
eq "the fresh layout still holds only the log we wrote" \
  "$(ls "$FRESH/ai-factory/runs" | tr '\n' ' ')" "log.csv "

# --- 14. the make target (AC18, AC21) ----------------------------------------------------------
MK=$PWD/skills/ai-layout/templates/ai-factory/make/ai.mk
recipe() { awk '/^cost:/{f=1;next} /^[^\t]/{f=0} f' "$MK"; }
grep -qE '^cost:' "$MK" || fail "$MK declares no cost target"
grep -qE '^\.PHONY:.*\bcost\b' "$MK" || fail "cost is missing from .PHONY, so a file named cost would shadow it"
eq "the cost recipe is one line" "$(recipe | grep -c .)" 1
# `@` is not tidiness: an echoed recipe line puts make's own output on stdout ahead of the JSON
# document, and `make cost JSON=1` promises one document and nothing else (AC1).
eq "the cost recipe is silent, so make does not echo it onto stdout" \
  "$(recipe | grep -c '^\t@')" 1
# Read-only (AC16): the target must not create, delete or truncate anything. This assertion exists
# because a stray cleanup line did land in this recipe once while it was being written.
eq "the cost recipe neither deletes, creates nor redirects" \
  "$(recipe | grep -cE 'rm |[-]delete|mkdir|>|tee ' || true)" 0
# AC21: one layout's log and nothing else — no walk upward, no sibling repo. The workspace root
# includes this same ai.mk and inherits the target, which is what makes this matter.
eq "the cost recipe reads this layout's log and passes no other path" \
  "$(recipe | tr -s ' ' | sed 's/^\t//')" \
  '@node ai-factory/make/cost.js $(RUNS)/log.csv'
if grep -nE '\.\./|\$\(HOME\)|/Users/|~/' <(recipe) >/dev/null; then
  fail "the cost recipe names a path outside the repo"
fi
if grep -vE '^[[:space:]]*//' "$COST" | grep -qE '\.\./\.\./|\$HOME|/Users/|homedir\(\)|os\.homedir'; then
  fail "$COST reaches outside the repo it runs in (AC21)"
fi
# Both mode variables must be exported, or `make cost JSON=1` would set a make variable the script
# never sees and would silently print the table instead of the document.
for v in JSON TSV; do
  grep -qE "^export $v\$" "$MK" || fail "ai.mk does not export $v, so make cost $v=1 would not reach the script"
done

# --- 8. the reader touched nothing (AC16, the half a fixture can prove) ------------------------
[ "$(sums)" = "$BEFORE" ] || fail "the fixtures changed while being read; the reader must be read-only over the log"
eq "no fixture was added or removed during the run" "$(ls "$FX"/*.csv | wc -l | tr -d ' ')" 12

echo "cost reader ok — quoted commas and newlines held in one record, wrong-width and pre-0007 rows excluded and counted, an unclosed quote unreadable, an unmeasurable header inventing nothing, fields read by name with a missing column empty, header-only and missing logs answered, groups summing to their totals with unattributed spend named, hit_rate recomputed rather than averaged, the session key surviving for a fleet view, fixtures byte-identical after the run"
