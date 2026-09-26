# Definition of done — ai-sdlc

1. Hook scripts pass `node --check`; shell passes `bash -n`; `bash ai-factory/make/sync-adapters.sh`
   runs clean and twice in a row produces no diff.
1b. Every `check-*.sh` under `skills/ai-layout/scripts/` and `skills/ai-hooks/fixtures/` exits 0,
   run directly — not piped, which would report `tail`'s status instead of the check's.
   `check-paths.sh` is the one that fails if a prompt reaches back for a pre-1.0.0 path.
2. A prompt, skill or hook change has a before/after run linked in the MR.
3. Template changes name the blast radius (which adopted repos, breaking or not) and are
   recorded in CHANGELOG.md with the version bumped in every manifest —
   `bash skills/ai-layout/scripts/check-versions.sh` enforces it, after two silent drifts.
4. Spec updated if behaviour changed; plan step ticked.
5. `/t4:check` run; no `blocker` findings open.
6. Commit message `ai(<task>): …` when AI produced the change; MR labelled `ai-assisted`.
7. README command table still matches what the plugin actually ships.
