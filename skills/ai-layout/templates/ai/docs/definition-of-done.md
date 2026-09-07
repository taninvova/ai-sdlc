# Definition of done — {{app}}

1. Lint, typecheck and tests green locally.
2. Each acceptance criterion touched has a test that fails if the change is reverted,
   written by `/ai-test` from the spec rather than alongside the implementation.
3. Spec updated if behaviour changed; plan step ticked.
4. `/ai-check` run; no `blocker` findings open.
5. Commit message `ai(<task>): …` when AI produced the change; MR labelled `ai-assisted`.
6. No new dependency without an ADR — write it with `/ai-adr`.
7. A change that crosses a service boundary or changes a contract others consume has a
   design doc in ai/designs/ and an ADR, and ai/docs/fleet.md reflects it.
{{dod_extra}}
