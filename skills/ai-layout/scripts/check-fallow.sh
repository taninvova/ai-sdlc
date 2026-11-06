#!/usr/bin/env bash
# Keeps the 7.0.0 fallow cleanup from regressing: `fallow dead-code` and `fallow dupes`, run with
# the committed .fallowrc.jsonc, must report nothing. fallow is optional — where it is not
# installed this prints one line and passes, so the suite gains no hard dependency. `fallow
# health` stays advisory and is not run here.
#
# Findings are counted from the JSON output rather than the exit code: `fallow dupes` exits 0 even
# when it reports clone groups.
#
# A deliberate exception goes in .fallowrc.jsonc with its reason (ignoreExports, ignoredClones,
# ignorePatterns), never as a fallow-ignore comment in code.
set -euo pipefail
cd "$(dirname "$0")/../../.."

if ! command -v fallow >/dev/null 2>&1; then
  echo "fallow: skipped — fallow is not installed (optional; https://fallow.tools)"
  exit 0
fi
[ -f .fallowrc.jsonc ] || { echo "FAIL: .fallowrc.jsonc is missing; the check runs only with the committed scope" >&2; exit 1; }

fail=0
# count <command> <python expression over the parsed JSON `d`>
count() {
  local out
  out=$(fallow "$1" --format json 2>/dev/null) || true
  printf '%s' "$out" | python3 -c "import json,sys
try: d = json.load(sys.stdin)
except Exception: print('unreadable'); sys.exit(0)
print($2)"
}

dead=$(count dead-code "d['summary']['total_issues']")
case "$dead" in
  0) ;;
  unreadable) echo "FAIL: fallow dead-code printed no JSON" >&2; fail=1 ;;
  *) echo "FAIL: fallow dead-code reports $dead issue(s):" >&2; fallow dead-code 2>&1 | grep -v ' WARN ' >&2 || true; fail=1 ;;
esac

dupes=$(count dupes "len(d['clone_groups'])")
case "$dupes" in
  0) ;;
  unreadable) echo "FAIL: fallow dupes printed no JSON" >&2; fail=1 ;;
  *) echo "FAIL: fallow dupes reports $dupes clone group(s):" >&2; fallow dupes 2>&1 | grep -v ' WARN ' >&2 || true; fail=1 ;;
esac

if grep -rn 'fallow-ignore' --include='*.js' skills >/dev/null 2>&1; then
  echo "FAIL: fallow-ignore comments in code; record exceptions in .fallowrc.jsonc instead:" >&2
  grep -rn 'fallow-ignore' --include='*.js' skills >&2
  fail=1
fi

[ "$fail" = 0 ] || exit 1
echo "fallow ok — dead-code and dupes report nothing ($(fallow --version 2>/dev/null | head -1))"
