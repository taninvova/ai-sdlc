# 0003 — .claude-plugin/plugin.json is the single source of the plugin version

Date: 2026-09-06 · Status: accepted

## Context
Two files claim to hold the ai-sdlc version: `.claude-plugin/plugin.json` and the pin in
`.claude-plugin/marketplace.json`. They drifted silently through 0.4.0 and 0.5.0 — the
marketplace pin still read 0.3.0 — because the definition of done named only the first.
Drift detection is only as trustworthy as the version string it records, so a repo adopted
from a stale copy would record the wrong version with full confidence.

## Decision
`.claude-plugin/plugin.json` is the version. `manifest.js` reads it and nothing else.
`marketplace.json`'s pin is install metadata that must be verified to agree with it, which
item 3 of `ai/docs/definition-of-done.md` now requires on every release.

## Consequences
One place to change, one place to trust. The agreement is enforced by a checklist a human
follows, not by code, so it can still drift — it did twice — and the honest fix is a release
check that compares the two. Recorded as an open gap in `ai/docs/fleet.md` rather than
claimed as solved.
