---
description: Reproduce a bug with a failing test, then fix it minimally
argument-hint: <bug: symptom and how to reproduce>
---
Read ai/AGENTS.md and ai/docs/coding-standards.md. Find the spec that covers the behaviour.
1. Reproduce with a failing test (unit or end-to-end, per the project's test setup) BEFORE changing any code.
2. Fix with the smallest change that makes the test pass. No unrelated refactoring.
3. Run the project's lint, typecheck and test commands (see ai/AGENTS.md). Fix until green.
4. Report: root cause · files changed · whether the spec was wrong or incomplete.

If nothing follows the command name, ask the user what the bug is and how to reproduce it, and stop. Do not go hunting for something that looks broken.

Bug: $ARGUMENTS
