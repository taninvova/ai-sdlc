# Contract fixtures

Inputs for `skills/ai-layout/scripts/check-contracts.sh`. Each directory is copied into a fresh
Git repository under `ai-factory/runs/tmp/` together with the template `make/` scripts. Sidecars
and evidence are produced there by `contracts.js` itself; every invalid, stale, symlink and
traversal variant is derived from these files at run time, so no fixture holds a digest that
could silently drift.

- `planned/` — a spec with three criteria and a three-step plan (red, step and final commands).
- `quick/` — an acceptance checklist for quick work, with no spec or plan.
- `legacy/` — customized specs and plans from before contracts, one without AC IDs, for migration.
