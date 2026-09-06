# Definition of done — ai-sdlc

1. Hook scripts pass `node --check`; shell passes `bash -n`; `bash ai/make/sync-adapters.sh`
   runs clean and twice in a row produces no diff.
2. A prompt, skill or hook change has a before/after run linked in the MR.
3. Template changes name the blast radius (which adopted repos, breaking or not) and are
   recorded in CHANGELOG.md with the version bumped in BOTH .claude-plugin/plugin.json and
   .claude-plugin/marketplace.json — they drifted silently through 0.4.0 and 0.5.0.
4. Spec updated if behaviour changed; plan step ticked.
5. `/ai-check` run; no `blocker` findings open.
6. Commit message `ai(<task>): …` when AI produced the change; MR labelled `ai-assisted`.
7. README command table still matches what the plugin actually ships.
