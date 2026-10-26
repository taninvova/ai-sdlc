# DJX496 — Risk agent network audit
Created: 2026-10-26T00:30:49.721Z

Date: 2026-10-26 · Status: accepted

## Context

Spec 0012 AC10 ([`specs/0012-plugin-security.md`](../specs/0012-plugin-security.md)) promises
that the core runner, hook and gate checks reach no external integration, package download or
sibling repository. That boundary is what lets an adopter run the factory offline and trust that
no check leaks data or pulls code. The `risk` agent introduced by
[spec 0023](../specs/0023-risk-agent.md) (AC19, AC20) and [plan 0023](../plans/0023-risk-agent.md)
must assess the dependency/supply-chain category, and the facts that decide it — known
vulnerabilities in the locked versions — live in advisory databases, not in the repository.
Reading lockfiles alone can list what is installed but cannot say what is vulnerable, so
[exploration 0005](../explorations/0005-security-and-risk-assessment-agent.md) flagged
`npm audit`-style tools as a new network behaviour that needs a recorded decision.

## Decision

The `risk` agent alone may run network dependency-audit tools (`npm audit`, `pip-audit`,
`osv-scanner`), and only while assessing the dependency/supply-chain category, interactively
and in CI where the network is available. No other agent, hook, runner check or gate check
gains network access. Spec 0012 AC10 still holds for the core checks; spec 0012 is cited by
this ADR, not amended.

## Consequences

- Easier: supply-chain findings rest on current advisory data rather than a guess from lockfile
  contents, so a `blocker` for a known vulnerable version is evidence, not opinion.
- Harder: the `risk` agent's output is no longer reproducible offline or over time — the same
  lockfile can yield different findings on different days, and the advisory services become an
  availability dependency. Spec 0023 AC21 must therefore hold: a missing tool or unreachable
  service records the category as `not assessed: <reason>` and the run falls back to local
  lockfile inspection.
- Harder: dependency manifests and lockfile contents leave the machine for the advisory
  service, which an adopter with strict data-residency rules must be told about and may need
  to block.
- Harder: the network boundary is now an exception list rather than an absolute. Every future
  request to give another agent, hook or check network access must supersede or extend this ADR
  explicitly, and reviewers must check that audit tools are never invoked from the core checks
  or from any category other than supply chain.
- We must: have `agents/risk.md` cite this ADR by its ID and forbid audit tools outside the
  supply-chain category (plan 0023 Step 2), and have spec 0023 cite this ADR (AC20).
