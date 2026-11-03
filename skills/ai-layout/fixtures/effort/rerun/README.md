# Specifier re-run fixtures (spec ASD-001, AC17–AC23)

`check-effort.sh rerun` loads `cases.json`. Each case is a request, the existing spec it may
name, the risk file present for that spec's ID (or none), and the outcome the specifier's
`Re-run on an existing spec` procedure prescribes:

- `new-id` — the request names no spec path, or cites another spec's path only as context
  (`cites-other-spec-new-id`), so `ids.js` exit 3 draws the next free ID and the existing spec
  stays unchanged (AC17). `helper_path` is the spec the helper reports as holding the parent's
  ID: a named spec is revised only when the request asks to revise or re-run it, or it is that
  spec.
- `unchanged` — the spec is left byte-for-byte as it is: no risk file yet (AC18), or no
  "Run `/fc:risk`" line to revise, with a risk file (plan Ambiguity 5) or without one (an
  all-absent triage, `named-no-risk-file-all-absent`). `report` says what the specifier reports:
  `run-risk` when the spec asks for `/fc:risk` and no risk file exists, else `nothing-to-revise`.
- `revised` — the spec is edited in place: the "Run `/fc:risk`" line is gone and the open
  blocker/major findings of the risk file's latest section are added (AC19–AC21). `expected`
  is the spec after the edit; `added` lists the finding ids it must name, no others.

`risk-reassessed.md` holds an initial body and two Reassessments whose statuses differ, so a
reader that takes any section but the latest names the wrong findings. `risk-initial.md` has no
Reassessment, so its body above the first one is the latest section.

The fixtures only exercise the procedure's rules: that an agent obeys them is proved by the host
runs of plan ASD-001 Step 7.
