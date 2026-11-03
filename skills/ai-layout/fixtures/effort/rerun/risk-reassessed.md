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
| R2 | injection | major | open | ai-factory/specs/ASD-901-csv-export.md:22 | Prefix cells starting with `=`, `+`, `-` or `@` with a quote |
| R3 | data exposure | major | open | ai-factory/specs/ASD-901-csv-export.md:20 | Export only the columns the list shows |

## Residual risks
None.

## Reassessment 2026-10-05T09:00:00.000Z
Target: plan ai-factory/plans/ASD-901-csv-export.md

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
| R1 | authorization | blocker | mitigated | ai-factory/plans/ASD-901-csv-export.md:14 | Check `invoices:export` before the query runs |
| R2 | injection | major | open | ai-factory/plans/ASD-901-csv-export.md:20 | Prefix cells starting with `=`, `+`, `-` or `@` with a quote |
| R3 | data exposure | blocker | open | ai-factory/plans/ASD-901-csv-export.md:9 | Export only the columns the list shows |
| R4 | rollback | minor | open | ai-factory/plans/ASD-901-csv-export.md:30 | Keep the route behind a flag for one release |

## Residual risks
None.

## Reassessment 2026-10-08T09:00:00.000Z
Target: plan ai-factory/plans/ASD-901-csv-export.md

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
| R1 | authorization | blocker | mitigated | ai-factory/plans/ASD-901-csv-export.md:14 | Check `invoices:export` before the query runs |
| R2 | injection | major | open | ai-factory/plans/ASD-901-csv-export.md:20 | Prefix cells starting with `=`, `+`, `-` or `@` with a quote |
| R3 | data exposure | blocker | accepted | ai-factory/plans/ASD-901-csv-export.md:9 | Accepted by the product owner on 2026-10-07: the list already shows these columns |
| R4 | rollback | minor | open | ai-factory/plans/ASD-901-csv-export.md:30 | Keep the route behind a flag for one release |
| R5 | blast radius | blocker | open | ai-factory/plans/ASD-901-csv-export.md:25 | Rate-limit the export route |
| R6 | secrets | major | mitigated | ai-factory/plans/ASD-901-csv-export.md:33 | Read the signing key from the vault, never from the request |

## Residual risks
- Large exports may still slow the invoice database.
