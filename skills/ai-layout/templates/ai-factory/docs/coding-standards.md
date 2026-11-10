# Coding standards — {{app}}

Framework-specific rules live in the overlay docs and ai-factory/skills/ (installed by the scaffold plugin). These are the rules that hold in every fc repo.

## Formatting and lint
The repo's configured formatter and linter own style. Run their fix command; never argue with the linter in reviews.

## Types
Use the strictest type checking the stack offers. Never silence the checker without a reason next to the suppression. Derive types from schemas rather than duplicating them.

## Structure
One responsibility per file; modules own their data access; cross-cutting concerns in one place. Do not reach across module boundaries with relative imports — use the stack's module or alias mechanism.

## Smallest complete change
Adapted from Ponytail (MIT, https://github.com/DietrichGebert/ponytail). Before writing, list every
place the change must reach: callers, tests, fixtures, config, exports. That is the scope; extra
features are not. Then take the first option that fully works:
1. Not needed: skip features, options and flexibility nobody asked for, and name them in one line of the report.
2. Already in this codebase (a helper, component or pattern): use it the way the surrounding code does.
3. The standard library or a platform feature, unless the project has its own.
4. An installed dependency. Never add one for a few lines.
5. Otherwise the minimum code that works. One line only when a reader gets it at a glance.

Be lazy about the solution, never about the change: finish every caller, test and fixture it
breaks. No abstraction, wrapper, option, config or "for later" code nobody asked for; deletion
beats addition; keep the existing layers and conventions. For a bug, find every caller of the
function first and fix the root cause once, in the shared code. Moved or merged code keeps its
error handling and validation. Between options of equal size, take the one correct on edge cases.
Comment only the why the code cannot show.
Never cut validation at trust boundaries, error handling that prevents data loss, security,
accessibility or anything the request asked for. This section never removes a required test or
check. End the report with one line: what was skipped or not checked, and any risk to know.

## Errors
Typed results or framework exceptions at the boundary; never swallow errors; log unexpected failures with context and a request id, never secrets or PII.

## Tests
A test next to the code it proves. A test the reviewer cannot explain is deleted, not merged. Coverage is a signal, not a target — do not pad it.

## Config and secrets
Config through one typed access point; every variable documented in one committed example or schema; local secret files never committed; secrets never logged.

## Dependencies
No new dependency without an ADR. Prefer the platform's existing choices (see ai-factory/docs/architecture.md) over a new library that does the same thing.
