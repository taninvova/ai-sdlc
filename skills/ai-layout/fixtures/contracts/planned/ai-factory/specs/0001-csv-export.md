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
