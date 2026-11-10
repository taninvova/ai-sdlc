# Coding standards — {{app}}

Framework-specific rules live in the overlay docs and ai-factory/skills/ (installed by the scaffold plugin). These are the rules that hold in every fc repo.

## Formatting and lint
The repo's configured formatter and linter own style. Run their fix command; never argue with the linter in reviews.

## Types
Use the strictest type checking the stack offers. Never silence the checker without a reason next to the suppression. Derive types from schemas rather than duplicating them.

## Structure
One responsibility per file; modules own their data access; cross-cutting concerns in one place. Do not reach across module boundaries with relative imports — use the stack's module or alias mechanism.

## Smallest complete change
The rule is `ai-factory/docs/ponytail.md` (Ponytail, MIT). The session hook loads that file into
the session and into each subagent. Follow the file. A required test or check in the task, the
plan or the contracts stays; the file does not remove one.

## Errors
Typed results or framework exceptions at the boundary; never swallow errors; log unexpected failures with context and a request id, never secrets or PII.

## Tests
A test next to the code it proves. A test the reviewer cannot explain is deleted, not merged. Coverage is a signal, not a target — do not pad it.

## Config and secrets
Config through one typed access point; every variable documented in one committed example or schema; local secret files never committed; secrets never logged.

## Dependencies
No new dependency without an ADR. Prefer the platform's existing choices (see ai-factory/docs/architecture.md) over a new library that does the same thing.
