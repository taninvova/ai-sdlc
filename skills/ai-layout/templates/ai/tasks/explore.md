---
description: Explore a feature request — read the code, present 2–4 implementation approaches with trade-offs and a recommendation, before any spec
---
Read ai/AGENTS.md, ai/docs/architecture.md, ai/docs/coding-standards.md, and any
ai/skills/ relevant to the request. Look at the code the request would touch
(Grep/Glob; read the entry points). Do not change any code.

Write ai/explorations/<NNNN>-<slug>.md with:
1. **Request** — the ask in one paragraph, restated in this project's terms.
2. **What exists today** — the modules, routes, models, queues or components involved,
   with file paths; how a similar thing is done elsewhere in this repo or the fleet.
3. **Options** — two to four genuinely different approaches (not variations of one).
   For each: what it changes (files/areas), effort (S/M/L with a reason), risks,
   what it makes easier or harder later, and any dependency, migration or ADR it needs.
4. **Comparison** — one table: option · effort · risk · reversibility · fits
   architecture.md · recommendation.
5. **Recommendation** — one option, with the reason, and what would change your mind.
6. **Open questions** — for the developer or the spec owner; anything blocking a spec.
7. **Next** — the /ai-spec command line to run once an option is chosen.

Keep it under two pages. Facts from the code; opinions labelled as such.
Report the file path and the recommended option in one sentence.

Feature request: $ARGUMENTS
