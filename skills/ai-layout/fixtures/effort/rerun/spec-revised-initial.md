# ASD-901 — CSV export of invoices
Created: 2026-10-01T09:00:00.000Z

Accountants export a filtered invoice list as CSV.

## User story
As an accountant I want to export the invoices I filtered as CSV so that I can reconcile them in a spreadsheet.

## Acceptance criteria
- **AC1.** Given a filtered invoice list, when the accountant exports it, then the CSV holds exactly the filtered rows.
- **AC2.** Given a user without the `invoices:export` permission, when they request an export, then the request is refused with 403.

## Out of scope
- Excel and PDF formats.

## Effort and risk
Effort: M (size M: three files with tests; uncertainty S: the list export pattern exists).
Estimate: dev 4–8 h (assumption: the existing list query is reused), /fc:run ~20–40 min (assumption: three steps).

Triage:
- authorization: present — AC2 adds a permission check on a new route.
- data exposure: present — the CSV carries customer names and amounts.
- secrets: absent — no credential is read or written.
- injection: present — cell values starting with `=` reach a spreadsheet.
- dependency/supply chain: absent — no new package.
- migrations: absent — no schema change.
- rollback: absent — the route can be removed without data change.
- blast radius: absent — one new route, no shared code changed.
- uncertain requirements: absent — the filter already exists.
- public contracts: absent — the route is internal.
- dependencies: absent — no new package.
- service ownership: absent — one service owns invoices.

## Open questions
- Should the export cap the number of rows?
- Which date format does the CSV use?
- R1 (blocker, authorization) is open in ai-factory/risks/ASD-901-csv-export.md: check `invoices:export` before the query runs.

## Data touched
- Invoice: number, customer name, amount, issued date (read only)

## Routes touched
- GET /invoices/export

## Components likely involved
- InvoiceController, InvoiceQuery, CsvWriter
