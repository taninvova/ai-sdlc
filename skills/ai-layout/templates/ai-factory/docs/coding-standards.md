# Coding standards — {{app}}

Framework-specific rules live in the overlay docs and ai-factory/skills/ (installed by the scaffold plugin). These are the rules that hold in every t4 repo.

## Formatting and lint
The linter (Biome) owns formatting. Run the fix command; never argue with the linter in reviews.

## Types
Strict mode on. No `any`, no `@ts-ignore`; `@ts-expect-error` only with a reason. Derive types from schemas rather than duplicating.

## Structure
One responsibility per file; modules own their data access; cross-cutting concerns in one place. No relative `../../` imports across module boundaries — use the path alias.

## Errors
Typed results or framework exceptions at the boundary; never swallow errors; log unexpected failures with context and a request id, never secrets or PII.

## Tests
A test next to the code it proves. A test the reviewer cannot explain is deleted, not merged. Coverage is a signal, not a target — do not pad it.

## Config and secrets
Config through one typed access point; every variable documented in `.env.example`; `.env` never committed; secrets never logged.

## Dependencies
No new dependency without an ADR. Prefer the platform's existing choices (see ai-factory/docs/architecture.md) over a new library that does the same thing.
