# Spec 0001 — CSV export

**Summary:** Export the report table as CSV.

Ticket: DEMO-12

## Acceptance criteria

| ID | Given / When / Then |
|---|---|
| AC1 | Given a report with rows, when it is exported, then the CSV has one line per row. |
| AC2 | Given a value containing a comma, when it is exported, then the value is quoted. |
| AC3 | Given an empty report, when it is exported, then only the header line is written. |

```
| AC9 | An example row inside a fence is not a declaration. |
```

## Out of scope

Excel output. See `/etc/hosts` and `../../outside.md` — prose paths are never read.

## Effort and risk
Effort: M (size M: two files with tests; uncertainty S: the table export pattern exists).
Estimate: dev 3–6 h (assumption: the table model is reused), /fc:run ~15–30 min (assumption: three steps).

Triage:
- authorization: present — the export route needs the report's read permission, as AC1 assumes.
- data exposure: present — AC1 and AC3 write every visible column, AC7-style extra columns included.
- secrets: absent — no credential is read or written.
- injection: present — a value from AC2 that starts with `=` reaches a spreadsheet.
- dependency/supply chain: absent — no new package.
- migrations: absent — no schema change.
- rollback: absent — the export can be removed without data change.
- blast radius: absent — AC3 touches only the export path.
- uncertain requirements: absent — the table already exists.
- public contracts: absent — the route is internal.
- dependencies: absent — no new package.
- service ownership: absent — one service owns reports.

## Open questions
- Run `/fc:risk ai-factory/specs/0001-csv-export.md`
