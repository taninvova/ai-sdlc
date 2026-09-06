---
description: Reproduce a bug with a failing test, then fix it minimally
---
Read ai/AGENTS.md and ai/docs/coding-standards.md. Find the spec that covers the behaviour.
1. Reproduce with a failing test (unit or end-to-end, per the project's test setup) BEFORE changing any code.
2. Fix with the smallest change that makes the test pass. No unrelated refactoring.
3. Run the project's lint, typecheck and test commands (see ai/AGENTS.md). Fix until green.
4. Report: root cause · files changed · whether the spec was wrong or incomplete.

Bug: $ARGUMENTS
