# Readers fixture (plan ASD-001 Step 6, AC41)

`spec-with-effort.md` is the contracts fixture spec `fixtures/contracts/planned/ai-factory/specs/0001-csv-export.md`
with an `Open questions` section and a `## Effort and risk` section in front of it. Its triage
evidence lines mention AC IDs inside list items, never as their first token. `check-effort.sh readers`
drops the `## Effort and risk` section to get its twin, places each in a copy of the planned fixture,
and compares what `contracts.js`, `delivery-report.js` and `continue.js` read from the two.
