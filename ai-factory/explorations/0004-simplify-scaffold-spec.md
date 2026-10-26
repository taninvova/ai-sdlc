# 0004 — Simplify the scaffold spec

## Request
"Simplify scaffold spec." In this repo "the scaffold spec" is one artefact:
`skills/ai-layout/templates/ai-factory/specs/0000-scaffold.md`, the spec every adopted repo
receives as `ai-factory/specs/0000-scaffold.md` on `/t4:adopt-sdlc` and is offered again on
`/t4:sync-sdlc`. Plan 0010 already calls it that ("is the scaffold spec exempt?"). The ask, read
literally: make that file shorter and plainer for the adopter, without breaking anything that
depends on it existing.

## What exists today
- **The file has already been simplified once.** Commit `addbbc7` rewrote it from four
  Given/When/Then criteria (a `/t4:chore add a /healthz route` example, "one line appended to
  log.csv") to a "Setup check": four one-line ACs — project checks pass; a small `/t4:quick`
  change yields a checked, reviewable diff; protected paths are blocked; turns land in
  `log.pending.csv` and move to `log.csv` on commit — plus an "Out of scope" line. `CHANGELOG.md`
  records it under **Unreleased — scaffold spec simplification**, with the template-upgrade note.
- **Things that depend on the file existing:**
  `skills/ai-layout/scripts/check-entrypoints.sh:70` fails if the template is gone;
  `check-paths.sh:82-93` uses its path as a stale/correct path fixture (string only).
- **Things that already treat it as special:** `templates/ai-factory/make/contracts.js:469` skips
  every `0000-*.md` when indexing artefacts. `/t4:state` (`skills/ai-layout/scripts/state.sh`)
  does **not** skip it — it heads the outstanding listing in every adopted repo, an open question
  recorded in the 2.2-era CHANGELOG entry and plan 0010 ambiguity I.
- **Drift:** `skills/ai-layout/scripts/manifest.js` hashes the raw template, so the
  `{{plugin_version}}` placeholder does not cause drift per release; any text edit reports
  "upstream changed" in every adopted repo, and deleting the template reports "removed upstream"
  (not deleted for them).
- `/t4:doctor` (`skills/ai-layout/scripts/doctor.sh`) already reports on setup (layout, adapters,
  hooks) — it overlaps with ACs 3-4 of the scaffold spec.
- Stale references to the pre-1.0.0 path `templates/specs/0000-scaffold.md` remain in historical
  docs (ADR 0005, design 0002) — records, not instructions.

## Options
**A. Treat it as delivered; close the request.** No template change. Optionally move the
Unreleased CHANGELOG entry into the next release. Effort S (nothing to build). Risk: the requester
meant something the `addbbc7` rewrite did not cover. Keeps every adopted repo free of a second
"upstream changed" in one release window. No ADR.

**B. Trim the content further.** E.g. collapse to two ACs (project checks pass; one `/t4:quick`
change produces a reviewable diff) and leave hook behaviour to `/t4:doctor`; drop
`{{plugin_version}}`. Changes the template and the CHANGELOG entry. Effort S (one file plus a
before/after run). Risk: a second consecutive upstream change for every adopter; losing ACs 3-4
removes the only human-readable statement that the guard and log hooks are expected to work.
Easier later: less to keep in sync with hook behaviour (AC4 must change whenever log handling does).

**C. Stop shipping it as a spec.** Delete the template; let `/t4:doctor` (or a short section in
`ai-factory/AGENTS.md`/`docs/workflow.md`) carry the setup check. Changes `check-entrypoints.sh`,
the templates, possibly `doctor.sh`, CHANGELOG with a breaking-template note. Effort M (removal
semantics in sync, doctor coverage, docs). Risk: adopted repos keep their copy and see "removed
upstream"; anyone using spec 0000 as their first-run checklist loses it. Easier later: `/t4:state`
noise disappears, the `0000-` special case in `contracts.js` becomes vestigial. Worth an ADR
(the layout stops guaranteeing a spec 0000).

**D. Keep the file, simplify how the tooling treats it.** Exempt `0000-*` from `/t4:state`
listings the way `contracts.js` already does. Changes `state.sh`, a `check-state.sh` fixture.
Effort S. Risk: hides a spec a repo may have genuinely edited into real work. This simplifies
the experience around the spec rather than the spec itself — it answers plan 0010 ambiguity I.

## Comparison
| Option | Effort | Risk | Reversibility | Fits architecture.md | Recommendation |
|---|---|---|---|---|---|
| A. Close as delivered | S | Low (may miss intent) | Full | Yes | **Recommended** |
| B. Trim further | S | Medium (repeat drift, loses hook ACs) | High | Yes | If A is rejected |
| C. Remove the spec | M | Medium-high (breaking, removal drift) | Medium | Yes, needs ADR | No |
| D. Exempt in `/t4:state` | S | Low-medium | High | Yes | Separate request |

## Recommendation
**A** (opinion): the change the request names is already in the tree (`addbbc7`, Unreleased
CHANGELOG entry), and shipping a second rewrite before adopters have absorbed the first doubles
their sync work for little gain. I would switch to **B** if the requester points at specific text
in the current four ACs that is still too heavy, and to **C** if the real complaint is that a
setup checklist should not be a spec at all. If the irritation is the spec heading `/t4:state`,
that is **D**, a different request.

## Open questions
1. Was this request filed before `addbbc7` landed? If so, is the current file what was wanted?
2. If not: which part is still too complex — the number of ACs, the hook/log detail in AC3-4,
   the `{{plugin_version}}` line, or that it is a spec at all?
3. Is it acceptable for every adopted repo to see the file as "upstream changed" a second time
   before the next release?

## Next
Once an option is chosen (only needed for B, C or D):
`/t4:spec simplify the scaffold spec — <option B|C|D as chosen>, per ai-factory/explorations/0004-simplify-scaffold-spec.md`
