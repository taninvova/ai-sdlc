# Plan 0001 — CSV export

**Spec:** `ai-factory/specs/0001-csv-export.md`

## Implementation sequence

- [ ] **Step 1 — Rows to lines.** AC1. Verify (red): `node test/red.js` Verify (step): `node test/pass.js rows`
- [ ] **Step 2 — Quote commas.** AC2. Verify: `node test/pass.js quote`
- [ ] **Step 3 — Empty report.** AC3.
  Verify (step): `node test/pass.js empty` Verify (final): `node test/pass.js all`
