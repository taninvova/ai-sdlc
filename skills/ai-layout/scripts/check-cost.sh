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
# Aggregation is not asserted here. Step 2 of ai-factory/plans/0008-make-cost-report-and-export.md
# builds the harness over Step 1's reader; the group totals, the export's field names and the
# rendered table arrive in later steps and extend this file.
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

# --- 8. the reader touched nothing (AC16, the half a fixture can prove) ------------------------
[ "$(sums)" = "$BEFORE" ] || fail "the fixtures changed while being read; the reader must be read-only over the log"
eq "no fixture was added or removed during the run" "$(ls "$FX"/*.csv | wc -l | tr -d ' ')" 7

echo "cost reader ok — quoted commas and newlines held in one record, wrong-width and pre-0007 rows excluded and counted, an unclosed quote unreadable, an unmeasurable header inventing nothing, fields read by name with a missing column empty, header-only and missing logs answered, fixtures byte-identical after the run"
