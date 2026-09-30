---
description: Reproduce a bug with a failing test, then fix it minimally
argument-hint: <bug: symptom and how to reproduce>
---
Read ai-factory/AGENTS.md and ai-factory/docs/coding-standards.md. Find the spec that covers the behaviour.
1. Reproduce with a failing test (unit or end-to-end, per the project's test setup) BEFORE changing any code.
2. Fix with the smallest change that makes the test pass. No unrelated refactoring.
3. Run affected checks and the project's required completion checks (see ai-factory/AGENTS.md); run the full required suite once at completion. Prose-only changes need applicable document checks, not invented runtime tests. Investigate failures with new evidence; after two repeated attempts with no new hypothesis or evidence, preserve work and report the blocker. Never weaken tests.
4. Report: root cause · files changed · whether the spec was wrong or incomplete.

If nothing follows the command name, ask the user what the bug is and how to reproduce it, and stop. Do not go hunting for something that looks broken.

Bug: $ARGUMENTS
