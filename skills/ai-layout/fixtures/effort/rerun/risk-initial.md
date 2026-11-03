# ASD-901 — Risk assessment of the CSV export
Created: 2026-10-02T09:00:00.000Z

Target: spec ai-factory/specs/ASD-901-csv-export.md

## Categories assessed
- authorization: assessed
- data exposure: assessed
- secrets: assessed
- injection: assessed
- dependency/supply chain: not assessed: no new package
- migrations: not assessed: no schema change
- rollback: assessed
- blast radius: assessed

## Findings

| id | category | severity | status | evidence path | mitigation |
|---|---|---|---|---|---|
| R1 | authorization | blocker | open | ai-factory/specs/ASD-901-csv-export.md:11 | Check `invoices:export` before the query runs |
| R2 | injection | major | mitigated | ai-factory/specs/ASD-901-csv-export.md:22 | Prefix cells starting with `=`, `+`, `-` or `@` with a quote |
| R3 | data exposure | minor | open | ai-factory/specs/ASD-901-csv-export.md:20 | Export only the columns the list shows |
| R4 | rollback | major | accepted | ai-factory/specs/ASD-901-csv-export.md:30 | Accepted by the product owner on 2026-10-02: the route is new |

## Residual risks
None.
