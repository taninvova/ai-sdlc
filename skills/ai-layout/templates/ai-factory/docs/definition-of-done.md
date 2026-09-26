# Definition of done — {{app}}

1. Lint, typecheck and tests green locally.
2. Each acceptance criterion touched has a test that fails if the change is reverted,
   written by `/t4:test` from the spec rather than alongside the implementation.
3. Spec updated if behaviour changed; plan step ticked.
4. `/t4:check` run; no `blocker` findings open.
5. Commit message `ai(<task>): …` when AI produced the change; MR labelled `ai-assisted`.
6. No new dependency without an ADR — write it with `/t4:adr`.
7. A change that crosses a service boundary or changes a contract others consume has a
   design doc in ai-factory/designs/ and an ADR, and ai-factory/docs/fleet.md reflects it.
{{dod_extra}}
