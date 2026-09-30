# Definition of done — {{app}}

1. Applicable completion checks pass. Run the required full suite once at completion, and affected checks again after later edits. State any unavailable check.
2. Changed behavior has meaningful regression coverage. Planned work uses `/t4:test` from the spec; quick work may add tests in the same session against its acceptance checklist. Documentation-only work uses relevant document checks.
3. Planned work updates the spec if behavior changed and ticks only verified plan steps. Quick work reports its acceptance checklist and verification; it does not require a spec or plan.
4. Review the actual change; no blocker remains. Quick changes may use a clearly labeled self-review unless independent review is required by the user/project. Planned work uses `/t4:check`.
5. Commit message `ai(<task>): …` when AI produced the change; MR labelled `ai-assisted`.
6. No new dependency without an ADR — write it with `/t4:adr`.
7. A change that crosses a service boundary or changes a contract others consume has a
   design doc in ai-factory/designs/ and an ADR, and ai-factory/docs/fleet.md reflects it.
8. Where artifact contracts are enabled, `make -f ai-factory/make/ai.mk contracts DELIVERY=<id>` is
   valid and `/t4:report <id>` says `ready` before handoff; otherwise the MR states each remaining
   reason from the report.
{{dod_extra}}
