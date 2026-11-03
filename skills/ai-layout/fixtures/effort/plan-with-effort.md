# ASD-902 — CSV export of invoices
Created: 2026-10-02T09:00:00.000Z

**Goal:** Accountants export a filtered invoice list as CSV.

**Spec:** `ai-factory/specs/ASD-902-csv-export.md`

## Steps

- [x] Step 1 — Export query and permission check (AC1, AC2).
  Effort: M · Estimate: dev 3–5 h, /fc:run ~15–30 min (assumption: the list query is reused as it is)
  - Tests: export holds exactly the filtered rows (AC1); a user without the permission gets 403 (AC2).
  - Verify (red): `npm test -- export`
  - Verify (step): `npm test -- export`
- [ ] Step 2 — CSV encoding (AC3).
  Effort: S · Estimate: dev 1–2 h, /fc:run ~10–20 min (assumption: the encoder already handles quoting)
  Depends on: 1
  - Tests: commas and quotes in a field survive a round trip (AC3).
  - Verify (step): `npm test -- csv`
- [ ] Step 3 — Download button (AC4).
  - Effort: L · Estimate: dev 6–10 h, /fc:run ~40–70 min (assumption: a new UI pattern with a modal)
  - Depends on: 1, 2
  - Tests: the button downloads the export (AC4).
  - Verify (step): `npm test -- button`
  - Verify (final): `npm test`
**Result — Step 4 withdrawn; merged into Step 3.**
- [x] Step 4 — Separate download route.
  Effort: S · Estimate: dev 1–2 h, /fc:run ~10–15 min (assumption: one route file)
