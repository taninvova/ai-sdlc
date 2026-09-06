# 0001 — Layout version and drift

Date: 2026-09-06 · Status: proposed · Fleet map: filled (refreshed by `/ai-fleet`), not the
shipped default. `docs/adr/` does not exist in this repo — only
`skills/ai-layout/templates/docs/adr/0000-template.md`. **No accepted ADR binds this design.**

## 1. Capability
An adopted repo must be able to tell that its `ai/` layout is older than the templates in the
`sdlc` plugin it has installed, and `sdlc` must be able to tell which adopted repos are on
which version — without a server, an npm package, or CI shared between `sdlc` and adopters.

## 2. Drivers
- **No push channel exists.** No server, no shared CI, no bot; plugins are pulled from a git
  marketplace. Anything that notifies must be initiated by the adopter. Source: fleet.md
  Environments; task brief.
- **Hooks cannot speak.** Hook scripts never write to stdout (cache-neutral) and no-op where
  `ai/` is absent. Source: `ai/AGENTS.md` rule 3, `skills/ai-hooks/SKILL.md`,
  `hooks/hooks.json`. So ambient detection can record, but cannot warn.
- **`ai/AGENTS.md` must hold no dynamic content** — it is the cached prefix. Source:
  `skills/ai-layout/SKILL.md`, "Rules for AGENTS.md". The version therefore cannot live where
  it lives today.
- **`ai/runs/*.json` is gitignored** (`.gitignore`), so a committed record cannot live there.
- **Template changes are contract changes** reaching every adopted repo. Source: fleet.md
  Boundaries; `ai/docs/coding-standards.md`.
- **sdlc must not depend on a scaffold or name one in a template.** Source: fleet.md Boundaries.
- **Adopters own their `ai/` copy.** A drift mechanism that overwrites local edits is worse
  than no mechanism. *(assumption — no doc states this; it follows from adopters editing
  `ai/docs/*` by design.)*
- **Fleet-wide answers are needed rarely, at release time.** *(assumption)*

## 3. Today
Facts from the code, not the map:
- `/sdlc:adopt` (`commands/adopt.md` step 3) copies `skills/ai-layout/templates/` and
  substitutes `{{plugin_version}}`. It lands in exactly two places, both as prose:
  `ai/AGENTS.md` — "Scaffolded with ai-sdlc {{plugin_version}}" — and
  `specs/0000-scaffold.md`, which still says "ai-base {{plugin_version}}" (stale name).
- **`/sdlc:sync` does not update the layout.** `commands/sync.md` runs
  `ai/make/sync-adapters.sh`, which only regenerates `.claude/` and `.cursor/` from `ai/`; it
  copies `sync-adapters.sh` itself only when missing. Nothing else is re-copied. So fleet.md's
  claim that "adopters find out by running `/sdlc:sync`" is **not true of the code**: there is
  no update path at all today. Re-running `/sdlc:adopt` refuses when `ai/` exists (step 1).
- Two files claim to be the plugin version: `.claude-plugin/plugin.json` (`0.5.0`) and
  `.claude-plugin/marketplace.json` (pins `0.3.0`).
- `README.md` already installs from `git@gitlab.nsix.io:ai/sdlc.git`, matching the remote —
  the second Known gap in fleet.md appears **already fixed at HEAD** and the map is stale there.
- Contracts in play: `skills/ai-layout/templates/` (consumed by adopted repos and both
  scaffolds), the `{{…}}` placeholder set, `hooks/hooks.json`, `ai/docs/dont-touch.md`'s
  ``- `prefix` `` grammar read by `guard-paths.js`.

## 4. Options
**A — Version marker, pull, on demand.** The adopted repo carries a machine-readable version
(a committed file it owns). `/sdlc:sync` compares it to the installed plugin's `plugin.json`
and reports behind/level. Fleet-wide view stays manual: a human writes versions into fleet.md.

**B — Content manifest, pull, three-way.** The repo carries version *plus* a sha256 per copied
file, written at adopt. `/sdlc:sync` computes three sets: files the plugin changed since that
version, files the adopter changed locally, and files that are both. Reports; later can safely
overwrite the untouched ones. Fleet-wide: sdlc reads each adopter's manifest on demand
(GitLab raw file), keeping no registry — the repos stay the source of truth.

**C — Ambient detection in the SessionStart hook.** The hook already runs in every adopted repo
with the plugin root on disk, so it can compare versions every session. It may not print, so it
writes a drift record under `ai/runs/` and something else must surface it later.

**D — Push from a central registry.** sdlc owns a repo→version table and its release pipeline
opens an MR or issue in each adopted repo. Needs GitLab CI, a group token and a bot identity in
`nsix/ai/` — none of which exist.

## 5. Comparison
| Option | Boundaries crossed | Data ownership | Failure mode | Reversibility | Effort |
|---|---|---|---|---|---|
| A version marker | none — plugin reads a repo file it wrote | adopter owns the file, sdlc writes it at adopt | says "behind" but not what changed; silent when the adopter hand-edited a task | delete one file | S |
| B manifest | same, plus optional read-only GitLab API reads of adopters | same; hashes are sdlc-owned data inside the adopter | manifest goes stale if a future adopt/update path forgets to rewrite it | delete one file; degrades to A | M |
| C hook | none, but adds work to every session in every repo | writes `ai/runs/`, which sdlc already owns | detects drift nobody ever reads; a stdout slip breaks every adopter's prefix cache | remove hook entry | S |
| D push | sdlc reaches into adopter repos; inverts the stated one-way dependency | sdlc would own a copy of adopter state that drifts | registry wrong the moment a repo adopts without telling sdlc | dismantle CI + token | L |

## 6. Decision
**B, pull-only, with no central registry: every adopted repo carries `ai/.sdlc.json` — schema
version, plugin version, and a sha256 per file received — and `/sdlc:sync` becomes the detector
that compares it against the installed plugin's templates.** sdlc answers "who is on what" by
reading that file from the repos listed in fleet.md when asked, not by storing a table.

Why: the only channel that exists is the adopter pulling, so detection belongs where the
adopter already goes; hashes cost one file more than A and are what makes a later automatic
update safe rather than destructive; a stored registry would be a second copy of a fact the
repos already hold, and it would be wrong first.

Rejected: **D**, because it inverts the boundary "the scaffolds depend on sdlc; sdlc must never
depend on a scaffold" and needs infrastructure the fleet has none of. **C** is deferred, not
refused — it is strictly additive on top of B once something surfaces `ai/runs/`.

**What would change my mind:** a group-level CI runner and bot token in `nsix/ai/` makes D cheap
and turns the fleet-wide half from pull into push. Evidence that adopters routinely edit
`ai/tasks/` and `ai/agents/` would collapse B's value back to A, because "untouched" would be rare.

**Rollout:** (1) adopt writes `ai/.sdlc.json`; (2) sync reads it and reports, changing nothing
else; (3) later, `sync --update` overwrites only files whose hash still matches what was
received. A repo with no manifest is not an error: sync reports `version: unknown (adopted
before manifest)`, falls back to the `ai/AGENTS.md` prose line for a guess, and offers to write
a manifest with today's hashes. **Rollback:** delete `ai/.sdlc.json`; sync degrades to today's
adapter regeneration. Nothing else reads it.

**Effect on the two open bugs:** this makes the marketplace/plugin.json disagreement matter
*more* — drift detection is only as trustworthy as the string it compares, and two files
currently claim to be the version, so a repo adopted from the marketplace copy could record
`0.3.0` while the source is `0.5.0`. The README URL matters *less*: it appears fixed at HEAD, and
a wrong install URL yields no plugin at all, which no drift check can help with.

## 7. Contracts and data ownership
**New contract: `ai/.sdlc.json`** — committed (must not be under `ai/runs/`, which is
gitignored), one per adopted repo.

```json
{ "schema": 1,
  "plugin": "sdlc",
  "version": "0.5.0",
  "adopted": "2026-09-06",
  "updated": "2026-09-06",
  "overlay": { "name": "nextjs", "version": "0.3.0" },
  "files": { "ai/tasks/spec.md": "sha256:…", "ai/docs/dont-touch.md": "sha256:…" } }
```

- **Writers:** `/sdlc:adopt`, a future `/sdlc:sync --update`, and the `nextjs` / `nestjs`
  scaffolds when they scaffold (they must fill `overlay`; `sdlc` never names them — the field is
  free-form, which keeps the one-way dependency intact). **Readers:** `/sdlc:sync`, `/ai-fleet`,
  and any human. Nothing else may write it; add `ai/.sdlc.json` to the template
  `ai/docs/dont-touch.md` so `guard-paths.js` blocks hand edits.
- **Compatibility:** adding a key is safe. Renaming or removing one, or changing the hash
  algorithm, is breaking and must bump `schema`. A reader that meets an unknown `schema` reports
  "manifest newer than this plugin" and does nothing else.
- **`.claude-plugin/plugin.json` is the single source of the plugin version.**
  `marketplace.json`'s pin is install metadata that must be checked to agree with it.
- **Unchanged:** `sync-adapters.sh`'s output and the `.claude/` / `.cursor/` layout. Sync gains a
  report; it must keep regenerating adapters exactly as it does now.
- **Data ownership:** each adopted repo owns its manifest and is the source of truth for its own
  version. sdlc owns the schema and the templates. sdlc stores no copy of adopter state.
- **sdlc's own repo** is excluded: its `ai/tasks/`, `ai/agents/` and `ai/make/` are symlinks into
  the templates, so it is current by construction and gets no manifest.

## 8. ADRs to write
- `/ai-adr ai/.sdlc.json is the version and integrity record every adopted repo carries — schema 1, sha256 per received file, written by adopt and by the scaffolds, read-only to everything else`
- `/ai-adr layout drift is detected by pull at /sdlc:sync; sdlc keeps no registry of adopter versions and never pushes into an adopted repo`
- `/ai-adr .claude-plugin/plugin.json is the single source of the sdlc plugin version; marketplace.json's pin must be verified against it in the definition of done`

## 9. Specs to follow
In order, all in repo `ai/sdlc` (local dir `ai-sdlc`) unless stated:
1. `/ai-spec /sdlc:adopt writes ai/.sdlc.json (schema 1, plugin version from .claude-plugin/plugin.json, sha256 of every file copied from skills/ai-layout/templates/), and the template ai/docs/dont-touch.md lists it`
2. `/ai-spec /sdlc:sync reports layout drift: compares ai/.sdlc.json against the installed plugin's templates and prints three buckets — upstream-changed, locally-modified, both — plus the migration path for a repo with no manifest; it changes no file under ai/ and adapter regeneration is unaffected`
3. `/ai-spec /ai-fleet records each adopted repo's sdlc version in ai/docs/fleet.md by reading its ai/.sdlc.json, marked (d), and marks a repo it could not read as unverified`
4. Later, once each scaffold repo has run `/sdlc:adopt`: `/ai-spec the scaffold writes the overlay block of ai/.sdlc.json when it scaffolds a project` — in `ai/nextjs-base` and again in `ai/nestjs-base`.

Not yet specified: `/sdlc:sync --update`, which needs specs 1–2 in the field first.

## 10. Proposed updates to ai/docs/architecture.md and ai/docs/fleet.md
*(Do not apply here — hand to `/ai-chore`.)*

**`ai/docs/architecture.md`, replace the "Data ownership" section with:**
> ## Data ownership
> Owns the templates, the prompt text, and the `ai/.sdlc.json` schema. Writes only to
> `ai/runs/` and, at adopt time, `ai/.sdlc.json` in the repo it runs in. Each adopted repo owns
> its own manifest and is the source of truth for its layout version; this plugin keeps no
> registry of adopter versions. Reads `ai/models.yaml` for model aliases; the LiteLLM proxy at
> llm.nsix.io resolves them.

**`ai/docs/fleet.md`, replace the "adopted app repos" row with:**
> | adopted app repos | various | their own application code; a copy of the layout under `ai/`; `ai/.sdlc.json`, the record of which sdlc version they hold | `ai/.sdlc.json`, readable by `/ai-fleet` | the templates, via `/sdlc:adopt` and `/sdlc:sync` (d) | per repo |

**`ai/docs/fleet.md`, add to Boundaries:**
> - Drift is pull-only. sdlc never writes into an adopted repo out of band and stores no copy of
>   adopter versions; an adopter learns it is behind by running `/sdlc:sync`.

**`ai/docs/fleet.md`, replace the last Known gap and correct the README one:**
> - The README install URL gap is closed at HEAD (`ai/sdlc.git`, matching the remote); re-verify
>   on the next refresh.
> - Adopted repos learn they are behind only by running `/sdlc:sync` — design 0001 makes that
>   real; until specs 1–2 ship, `/sdlc:sync` regenerates adapters and nothing more.

## 11. Open questions
1. **Which repos are actually adopted?** fleet.md says "various". Spec 3 needs a list or a
   GitLab group to enumerate. Blocks spec 3 only.
2. **Does the marketplace install expose `plugin.json` or the pinned `marketplace.json` version
   to a running session?** If the pin is what reaches the repo, ADR 3 is not merely tidy — it is
   the correctness of the whole mechanism. Verify before spec 1.
3. **Do the scaffolds copy the templates themselves, or call `/sdlc:adopt`?** Determines whether
   spec 4 is one line or a real change. Not read here — the scaffold repos are out of this tree.
4. **Who surfaces drift to a human who never runs `/sdlc:sync`?** Deferred with option C; needs a
   channel that is not stdout.

## Amendment — 2026-09-06, standalone constraint

Recorded after this document was written; the body above is left as it was produced.

The plugin must depend on no other repo, and must not name, read or version-pin one
(`ai/docs/fleet.md` → Boundaries). Effect on this design:

- **The core decision is unaffected and is reinforced by the constraint.** `ai/.sdlc.json`
  is written into the adopted repo and read there; detection is pull-side at `/sdlc:sync`.
  sdlc keeps no registry and never reaches into another repo — which is precisely what the
  standalone rule requires. Option "central registry", already rejected, is now forbidden.
- **Spec 4 is out of scope for this repo.** An overlay plugin writing its own block of
  `ai/.sdlc.json` is work for that overlay's repo, driven by its own loop. What belongs here
  is only the schema's `overlay` field and the rule that sdlc never writes it.
- **Spec 3 needs rewording.** `/ai-fleet` may not enumerate adopted repos from this repo —
  that is knowledge of other repos. Open question 1 is therefore answered "not here": an
  adopted repo records its own version, and whoever wants a fleet-wide view collects it
  outside sdlc.
- Open question 3 stands and is unanswerable from this tree by design.
