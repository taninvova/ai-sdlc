---
description: Turn a spec into an ordered implementation plan with checkboxes
---
Read ai/AGENTS.md, ai/docs/architecture.md, ai/docs/coding-standards.md, and the spec
named below. Read the relevant skills in ai/skills/ (forms, data-access, playwright).
Do not change any code.

Write ai/plans/<NNNN>-<slug>.md (same number as the spec):
- Goal (one sentence) · Spec link
- Files to create / modify, each with one line on why
- Server vs client components, with reasons
- Steps as a numbered checklist `- [ ] Step N — …`, each small enough for one /feature run,
  each naming the tests that prove it (map to AC numbers)
- Risks and how each is checked
- Verification: the exact commands and tests that must pass at the end
Report the plan path and anything in the spec that made planning ambiguous.

Spec: $ARGUMENTS
