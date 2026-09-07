# 0001 — ai/.sdlc.json records the layout an adopted repo holds

Date: 2026-09-06 · Status: accepted

## Context
An adopted repo receives a copy of `skills/ai-layout/templates/` and then diverges: the
templates move on, and the repo edits its own copies. Neither side could tell which. The
version was recorded only as prose in `ai/AGENTS.md`, which no tool reads, and `/ai-sdlc:sync`
regenerated adapters without ever comparing anything. See
`ai/designs/0001-layout-version-and-drift.md`.

## Decision
Every adopted repo carries a committed `ai/.sdlc.json`: `schema`, `plugin`, `version`,
`adopted`, `updated`, an optional free-form `overlay` block, and a `files` map holding **two**
hashes per received file — `received` (the bytes that landed in the repo) and `template` (the
template they came from).

Two hashes, not the one the design sketched: `/ai-sdlc:adopt` substitutes `{{app}}`, `{{stack}}`
and friends, so a repo file never equals its template. With a single hash every substituted
file would report as modified forever and the check would be worthless. `received` detects
local edits; `template` detects upstream change; the pair distinguishes "safe to take" from
"needs a merge".

It lives at the repo root under `ai/`, not `ai/runs/`, because `ai/runs/*` is gitignored and
this must be committed. It is listed in the template `ai/docs/dont-touch.md` so
`guard-paths.js` blocks hand edits.

## Consequences
Drift becomes computable, and `/ai-sdlc:sync` can say which upstream changes are safe to take.
The manifest is one more committed file that must stay honest — a hand edit or a lost write
makes the check lie, hence the guard. Adding a key is safe; renaming or removing one, or
changing the hash algorithm, is breaking and must bump `schema`; a reader meeting an unknown
`schema` reports "manifest newer than this plugin" and does nothing. Volatile paths
(`ai/runs/`, `.gitkeep`) are excluded, so drift in them is invisible by design.
