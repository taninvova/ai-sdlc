# Plan 0010 — `/t4:state`: list the repo's outstanding specs and plans

**Goal:** Add one read-only plugin command, `/t4:state`, backed by a deterministic script under
`skills/ai-layout/scripts/`, that prints a table of this repo's outstanding specs and plans with each
outstanding plan's incomplete steps.

**Spec:** `ai-factory/specs/0010-t4-state.md` — written as a repo-root-relative path in backticks, not
as a relative markdown link, so it stays correct both here and after this plan is filed to
`ai-factory/plans/done/`, where a `../`-relative link resolves one level shallower. Plan 0009 learned
that the hard way.

## Before anything else: read this, then decide how far to run

Two things about this spec have to be said before any step is read.

**1. The spec's "What is there today" section is stale, and one of its inferences is false.** It was
written on 2026-09-27 and the queue has moved since. Verified against the tree on 2026-09-28:

| The spec says | What is true now |
|---|---|
| specs 0008 and 0009 are "both untracked on `main`" | both are tracked and committed — `git ls-files ai-factory/specs/` lists all ten |
| "Spec numbers run 0001–0006 then 0008–0010; **0007 is absent**" | `ai-factory/specs/0007-subagent-stop-per-agent-accounting.md` exists. The gap it reasons from does not exist |
| "Two specs have no plan" (0008, 0009) | both now have plans, and both are filed in `ai-factory/plans/done/` |
| "`ai-factory/plans/` is empty but for `done/`. Six plans — 0001–0006 — sit in `done/`" | `done/` holds nine — 0001–0009. `ai-factory/plans/` holds no plan file at all |
| "not one `- [ ]` remains anywhere in the repo" | two remain: plan 0007 Step 7 (recorded not run) and plan 0009 Step 2 (blocked, and withdrawn under one answer) |

The only claim in that section this plan relies on is the one that is still true and was checked
again: `- [~]` occurs exactly twice, in `ai-factory/plans/done/0003-tracker-setup.md` Step 2 and
`ai-factory/plans/done/0004-knowledge-seam.md` Step 5, each above a `**Result — … proved; …
outstanding.**` block. **No step below asserts anything about the live contents of
`ai-factory/specs/` or `ai-factory/plans/`.** Every assertion runs against fixtures under
`mktemp -d`. The queue was moving *while this plan was being written* — two plans were filed to
`done/` between one directory listing and the next — so a fixture built from the real tree would
flake, and a plan that encoded today's listing as the feature's expected output would be wrong
before anyone ran it. The feature is specified by **rules**; the rules are what get pinned.

**2. Nine open questions stood between Steps 1–4 and a finished feature. Four were answered in
writing on 2026-09-29; five are still open.** Steps 1–4 deliver `/t4:state` with no argument — AC1,
AC2, AC3, AC4, AC7 through AC15. AC5 (`--done`) and AC6 (`--next`) could not be built from the spec
alone, because the rule each needs is exactly what the spec leaves open — so the developer answered
**A, C, D and F** on 2026-09-29. Steps 5, 6, 7 and 8 are no longer blocked: each now carries the
answer as a concrete rule, and every one of the four is runnable. **B, E, G, H and I are still
open**; none of them blocks a step, and each is marked below. Nothing was settled by picking: an
answer that is not recorded below with its date is still an open question, and answering by picking
encodes the guess, which is what open questions exist to prevent.

### The ambiguities, as questions to answer

Four are the spec's own. Five are new, and three of the five are things the spec's stale snapshot
concealed. **Answered**, with a date, marks a question the developer settled in writing; anything
without that mark is still open.

- **A (spec OQ1) — what rule does `--next` select by?** The lowest-numbered outstanding plan's first
  incomplete step, the lowest-numbered spec with no plan, the most recently modified artefact, or
  simply the first row of the default listing? AC6 fixes only that the result is a subset and that
  the command says why. **Answered 2026-09-29: the most recently modified artefact — measured by
  its git commit date, `git log -1 --format=%ct -- <path>`, and not by filesystem mtime.** The
  reason is cross-clone agreement, not AC13: an mtime does not survive a clone, so two people
  sitting on the same commit would get different answers out of the same tree, while a commit date
  is identical in every clone. AC13 as worded — the same tree, run twice, nothing changed in
  between — is satisfied by *either* measure, so this is not an AC13 fix and must not be written up
  as one. An artefact with no commit date, because it is uncommitted or untracked, sorts as
  **newest**. Ties break on the artefact's leading four-digit number, lowest first, then on path,
  then on step number, so the ordering is total. Step 6 carries the rule.
- **B (spec OQ2) — which columns, in which order, and is the table sectioned by kind?** AC3 fixes
  that a row must carry the artefact path and, for a plan step, the step identifier and its
  one-line description; AC7 fixes header-plus-rows with the same columns throughout. Undecided:
  whether `number`, `kind`, `state` and `the command to run next` are columns, their order, and
  whether a spec row and a plan-step row share one column set. Step 2 emits the AC3-required fields
  and a state field; the presentation is the prompt's, and Step 3 renders whatever the answer fixes.
- **C (spec OQ3) — does `--done` replace the default listing or widen it to everything with a state
  per row?** AC5 is satisfied by both. **Answered 2026-09-29: it replaces.** `--done` lists only
  the items whose every step is complete, with the same columns, the same order and the same shape
  as the default listing. It does not widen the listing to everything-with-a-state. Step 5 carries
  the rule.
- **D (spec OQ4) — do the filters compose?** Is `/t4:state --done --next` meaningful, an error, or
  silently one of them? **Answered 2026-09-29: `--done --next` refuses.** It prints one line saying
  the combination is not meaningful and what each flag does on its own, then exits **0**. Exit 0 is
  deliberate: it is how this plan already treats an unknown flag, because a refused result is an
  answer, not a crash. Step 7 carries the rule; Steps 5 and 6 are unaffected, each flag alone
  keeping the behaviour its own answer fixes.
- **E — what makes a *spec* complete?** AC2 lists "every spec … that is not yet complete"; nothing
  in the spec defines a complete spec. Step 2 implements a rule **derived**, not chosen, from two
  lines the spec does fix — AC4's "'Not started yet' and 'part done' are what the default listing
  shows", and *Data touched*'s instruction to read "the `**Goal:**` and `**Spec:**` lines each plan
  opens with". The derivation: pair a spec to a plan by the plan's `**Spec:**` line, falling back to
  the leading four-digit number; a spec with no plan is *not started*; a spec whose paired plan has
  some steps incomplete is *part done*; a spec whose paired plan has every step complete is
  *complete* and is not listed. **Please confirm this derivation** — it is the one rule in Step 2
  that is reasoned rather than quoted.
- **F — which release carries this, given that the CHANGELOG's top entry is asserted to be a
  breaking one?** `skills/ai-layout/scripts/check-release-docs.sh` reads *the top entry only* and
  requires it to say breaking, to tell adopted repos to run `/t4:migrate-layout`, to say the hooks
  keep working, to tell the developer to grep their own CI, and to carry both deprecation notices
  (the command in 2.1.0, the fallback in 3.0.0). This was tested: a scratch copy of the repo with a
  2.1.0 feature entry for `/t4:state` and the three manifests bumped fails with
  `FAIL: CHANGELOG.md's 2.1.0 entry does not mark the change breaking`. A read-only reporting
  command is not breaking and must not claim to be. Three ways out, none derivable from this spec:
  ship inside the next genuinely breaking release (2.1.0, already scheduled to remove
  `/t4:migrate-layout`); amend `check-release-docs.sh` so the six assertions bind to the 2.0.0 entry
  by version rather than to whatever is on top; or write a patch entry that repeats the boilerplate.
  **Answered 2026-09-29: ship `/t4:state` as an ordinary, non-breaking feature entry, and fix the
  check rather than distort the CHANGELOG to satisfy it.** The mechanism, verified in the script:
  line 100 takes `top=$(awk '/^## /{n++} n==1' CHANGELOG.md)` — the top entry, unconditionally,
  whatever it is — and lines 116–124 then demand that entry mark the change breaking, name the
  migration command, and carry the rest. So the *first non-breaking release to land on top* fails,
  whatever it contains; `/t4:state` is merely the first to hit it. The fix is to bind those
  assertions to the **2.0.0 entry, located by version wherever it sits in the file**, and to leave on
  the top entry only what is true of every release — that a versioned entry exists and that its
  version equals `.claude-plugin/plugin.json`'s. **Not** to entries *marked breaking*: this script
  pins the 1.0.0/2.0.0 rename record, and five of its six statements are specific to that one
  migration, so a future unrelated breaking release — 3.0.0 dropping the hooks' fallback, say —
  would be forced to recite 2.0.0's migration instructions. That wrong reading was recorded here on
  2026-09-29 and corrected the same day; the check's own fixtures (b) and (e) now fail against it.
  One constraint still rides on this answer, and Step 8 records it rather than burying it:
  **the version number is still unresolved**. `2.1.0` is spoken for: commit `3fd5dfd` records it as
  belonging to the `/t4:migrate-layout` removal, and `check-release-docs.sh` asserts that the 2.0.0
  entry carries the deprecation notice naming `2.1.0`. Step 8 therefore names no version yet and invents none; that is the
  one question still open on it, and AC16's record half stays unsatisfied until the number is named.
- **G — is AC16's adapter-and-manifest clause achievable for a plugin command at all?** AC16 requires
  that "the generated `.claude/`, `.cursor/` and `.codex/` adapters include it" and that
  "`ai-factory/.sdlc.json` lists it". Verified: `ai-factory/make/sync-adapters.sh` generates adapters
  from `ai-factory/tasks/*.md`, `ai-factory/skills/` and `ai-factory/agents/` only — it never reads
  `commands/`, which is why `.claude/commands/t4/` holds twelve task commands and no `doctor`, why
  `.codex/skills/` holds twelve `t4-<task>` skills and no plugin command, and why
  `ai-factory/docs/workflow.md` §8's Codex table has a row for "the twelve `/t4:*` tasks" and none
  for the plugin commands. `.cursor/rules/ai.mdc` is a single static file that names no command at
  all. And `manifest.js` hashes only files under `skills/ai-layout/templates/`, so a file at
  `commands/state.md` is invisible to `ai-factory/.sdlc.json` by construction — proved in a scratch
  copy: with `commands/state.md` and `skills/ai-layout/scripts/state.sh` added,
  `check-manifest.sh` passes unchanged and reports no drift. Satisfying that clause therefore means
  either changing `sync-adapters.sh`/`manifest.js` — a template change, breaking for every adopted
  repo, which this spec nowhere authorises — or shipping `/t4:state` as a project task, which the
  spec's *Out of scope* forbids. **This plan changes neither, and leaves that clause of AC16
  unmet.** The rest of AC16 — `commands/`, the workflow tables, the CHANGELOG and the version — is
  Steps 4 and 8.
- **H — is a step deliberately withdrawn, blocked or not run distinguishable from one not yet
  started?** Today it is not: plan 0009 Step 2 is `- [ ] **Step 2 — BLOCKED. Do not run until Open
  question 2 is answered…**` and is withdrawn outright under one of the two answers, and plan 0007
  Step 7 is recorded as not run rather than done. Both are plain `- [ ]`, so under any rule the ACs
  fix they are reported as outstanding for as long as they exist. The spec catalogued `- [~]` but
  could not have catalogued these — neither existed when it was written. Step 2 reports them as
  outstanding, which is the conservative reading AC12's "never reported as complete" points at.
  Should there be a notation for withdrawn, and should `/t4:state` honour it?
- **I — is `ai-factory/specs/0000-scaffold.md` listed?** It ships in the templates, so every adopted
  repo receives it, it has no plan and never will, and under the Ambiguity-E rule it is reported *not
  started* — the first row of `/t4:state` in every adopted repo, for ever. Step 2 lists it, because no
  AC exempts it and AC2's "nothing else is listed" is about `ai-factory/tasks/`, not about this. Is
  that wanted, or is the scaffold spec exempt?

### What is settled, and not a guess

Two rules the spec does fix, recorded here because both were misread once already:

- **`- [~]` is incomplete, and a plan's *checkboxes* beat its *directory*.** AC10: "A plan whose every
  step is `- [x]` except one `- [~]` is outstanding, not done." Both `- [~]` steps sit in plans filed
  under `ai-factory/plans/done/`, and the spec says so in the same breath. So AC10 is only
  satisfiable if filing a plan to `done/` does not make it complete. Nothing is inferred from a
  plan's location. (The corollary — whether `done/` shows up as a state, a column or a `--done`
  filter — is Ambiguities B and C.)
- **Never assume the numbers are dense.** The spec's own reasoning about a 0007 gap was false, and
  `done/` now holds 0001–0009 while `ai-factory/plans/` holds none. Glob and sort; never iterate a
  counter.

## Files to create / modify

| Path | Why |
|---|---|
| `skills/ai-layout/scripts/state.sh` | **new.** The deterministic scan, the completeness decision and the row data, invoked as `doctor.sh` is (AC14). Takes `[repo-root] [plugin-root]`, always exits 0, reads nothing outside the repo root it is given (AC15) |
| `skills/ai-layout/scripts/check-state.sh` | **new.** The only test this repo has: fixture repos under `mktemp -d` pinning every rule, `- [~]` included. Named `check-*.sh` so the definition of done's blanket loop picks it up |
| `commands/state.md` | **new.** The prompt, shaped like `commands/doctor.md`: front-matter `description:` and `allowed-tools: Bash, Read`, an explicit change-nothing instruction, one step running the script with `"${CLAUDE_PLUGIN_ROOT}"`, and how to render the rows |
| `README.md` | the Commands list is the plugin's own inventory, and DoD item 7 requires it to match what ships |
| `ai-factory/docs/workflow.md` | §5's *Plugin-level — available in any repo* table is the one actual command table; §10 *When something is wrong* is where a returning developer looks |
| `CHANGELOG.md` · `.claude-plugin/plugin.json` · `.claude-plugin/marketplace.json` · `.codex-plugin/plugin.json` | AC16's record-the-change half. All three manifests, because `check-versions.sh` requires every manifest carrying a version to carry the same one — it reports "3 manifests all at 2.0.0" today. **Step 8.** Ambiguity F is answered — an ordinary feature entry — but the version number is still open, and the `check-release-docs.sh` fix Step 8 depends on is a separate change that lands first |

Deliberately **not** touched, each for a checked reason:

- `skills/ai-layout/templates/` — nothing. `/t4:state` is a plugin command, not a task (spec *Out of
  scope*), so no template file is added, no adopted repo's manifest moves, and this release is not a
  template change. Verified: with both new files present in a scratch copy, `check-manifest.sh`
  passes and reports no drift.
- `ai-factory/make/sync-adapters.sh` and `skills/ai-layout/scripts/manifest.js` — see Ambiguity G.
- `skills/ai-layout/SKILL.md` — the spec's *Data touched* calls it "the inventory", but it was read:
  its tree enumerates the `ai-factory/` layout an adopted repo receives, and names no plugin command
  anywhere. A `/t4:state` line there would describe a file that is not in the payload. No change.
- `ai-factory/plans/done/0003-tracker-setup.md` and `0004-knowledge-seam.md` — the two `- [~]`
  records stay byte-identical (spec *Out of scope*). Guarded in *Verification*.
- `ai-factory/tasks/`, `ai-factory/agents/`, `ai-factory/make/`, `.claude/`, `.cursor/`, `.codex/`,
  `ai-factory/runs/` — all on `ai-factory/docs/dont-touch.md`. The first three are symlinks into the
  templates; the guard-paths hook exits 2 on any of them. No step needs one.

## Server vs client components

**Does not apply.** This is a plugin/CLI source repo — markdown prompts, bash and dependency-free
Node, with no build step and, per `ai-factory/docs/architecture.md`, nothing that runs as a service.
There is no server component, no client component, no rendering boundary and no request path. The
one surface added is a developer entry point, `/t4:state`, whose whole output is terminal text.

## Steps

- [x] **Step 1 — Write `skills/ai-layout/scripts/check-state.sh`, red.** Fixture repos under
  `mktemp -d`, in the shape `check-doctor.sh` uses (`fail()`, `run()`, `trap 'rm -rf "$TMP"' EXIT`),
  asserting against `skills/ai-layout/scripts/state.sh`: a repo with no `ai-factory/` at all →
  exit 0 and one line (AC11); a spec with no plan → listed, by repository-relative path (AC2, AC3);
  a plan with three steps, two `[x]` and one `[ ]` → the plan listed once with the one incomplete
  step's identifier *and* its one-line description, and neither ticked step shown (AC2, AC3, AC4);
  a plan whose every step is `[x]` except one `[~]`, placed **inside a `done/` subdirectory** →
  outstanding (AC10, and the settled checkbox-beats-directory rule); a plan with every step `[x]` →
  absent from the default listing (AC4); an unreadable file (`chmod 000`) and a plan whose step
  lines match no rule → each reported `unknown` with a reason while every other artefact is still
  listed, and neither reported complete (AC12); the three `**Spec:**` link forms that exist in this
  repo — a backticked repo-relative path, a markdown link into `../../specs/`, and the pre-1.0.0
  bare form — all pairing to the same spec (Ambiguity E's derivation); two sibling fixture repos,
  running in one, asserting the other's artefact path appears nowhere in the output (AC15); two
  consecutive runs over one fixture, `diff`ed, identical (AC13); a filesystem snapshot
  (`find … | sort | shasum`) and a content snapshot (`find … -exec shasum {} + | sort | shasum`)
  equal before and after a run (AC8, AC9); `ai-factory/tasks/*.md` present in a fixture and absent
  from the output (AC2). No assertion may read the real `ai-factory/specs/` or `ai-factory/plans/`.
  *Proved by:* `bash skills/ai-layout/scripts/check-state.sh` exiting **non-zero** with a message
  naming the missing `state.sh` — red for the right reason — and `bash -n
  skills/ai-layout/scripts/check-state.sh` exiting 0. *ACs:* 2, 3, 4, 8, 9, 10, 11, 12, 13, 15.

- [x] **Step 2 — Write `skills/ai-layout/scripts/state.sh` until Step 1's check is green.** Bash,
  `set -uo pipefail` and `shopt -s nullglob` — deliberately not `set -e`, for the reason
  `doctor.sh` gives: one unanswerable artefact must not stop the others. Signature
  `state.sh [repo-root] [plugin-root]`, defaults as `doctor.sh`'s, `cd` into the repo root and read
  only relative paths from there (AC15). Glob-and-sort, never a counter. Emit a header row and one
  field-separated row per listed thing, carrying what AC3 fixes — the repository-relative artefact
  path, and for a plan step its identifier and its one-line description — plus a state field so
  AC4's "not started yet" and "part done" are distinguishable; **which of those fields become
  table columns, in what order, is Ambiguity B and belongs to the prompt, not here.** Sort rows by
  a total order that depends on nothing but the bytes on disk — path, then step number — so two
  runs agree (AC13). Treat `- [~]` and `- [ ]` as incomplete and `- [x]` as complete; infer nothing
  from a plan's directory. Pair spec to plan by the plan's `**Spec:**` line and fall back to the
  leading number (Ambiguity E). Guard every read; report what cannot be read or parsed as `unknown`
  with the reason, never as complete (AC12). One line and exit 0 when nothing matches (AC11).
  Create nothing, write nothing, tick nothing (AC8, AC9). An argument the spec has not settled —
  `--done`, `--next`, or any combination — prints one line saying the rule is not decided yet and
  names the spec's open question, and exits 0; that is provisional and Steps 5–7 replace it.
  *Proved by:* `bash skills/ai-layout/scripts/check-state.sh` exiting 0; `bash -n
  skills/ai-layout/scripts/state.sh`; `diff <(bash skills/ai-layout/scripts/state.sh .) <(bash
  skills/ai-layout/scripts/state.sh .)` empty. *ACs:* 2, 3, 4, 8, 9, 10, 11, 12, 13, 14, 15.

- [x] **Step 3 — Write `commands/state.md`.** Front matter `description:` written for the slash
  menu and `allowed-tools: Bash, Read`; an opening change-nothing instruction in the shape
  `commands/doctor.md` uses; one numbered step running
  `bash "${CLAUDE_PLUGIN_ROOT}/skills/ai-layout/scripts/state.sh" . "${CLAUDE_PLUGIN_ROOT}"`; an
  instruction to present the script's rows as a table with a header row and the same columns in the
  same order for every row, and not to re-infer which items are outstanding (AC7, AC14); an
  instruction to pass the script's one-line empty answer through as-is (AC11) and its `unknown`
  rows through with their reasons (AC12); `$ARGUMENTS` last, so the cached prefix is stable.
  Mind two scans that will read this file the moment it exists, both confirmed by adding a
  candidate `commands/state.md` to a scratch copy and running them: `check-adapters.sh` includes
  `commands/*.md` in its banned-term sweep, so the prompt may not contain `jira`, `atlassian`,
  `connector`, `base_url`, a URL, `.yaml`, `knowledge_base.md` or a standalone `MCP`; and
  `check-paths.sh` scans `commands/` as instruction, so no pre-1.0.0 path — the layout is
  `ai-factory/`. Add to Step 1's check-state.sh two invariants of the prompt itself: that it names
  `skills/ai-layout/scripts/state.sh` and that it contains an explicit change-nothing instruction.
  The table's final column set stays open until Ambiguity B is answered; render what the script
  emits. *Proved by:* `bash skills/ai-layout/scripts/check-adapters.sh` exiting 0; `bash
  skills/ai-layout/scripts/check-paths.sh` exiting 0; `bash
  skills/ai-layout/scripts/check-state.sh` exiting 0 with the two new prompt invariants; and — the
  standard `ai-factory/docs/coding-standards.md` sets for a prompt, which is a run and not an
  assertion — one recorded `/t4:state` transcript in this repo, linked in the MR. *ACs:* 1, 7, 11,
  12, 14.

- [x] **Step 4 — Name the command where a developer will find it.** One bullet in `README.md`'s
  Commands list, beside `/t4:doctor` and in its register. One row in `ai-factory/docs/workflow.md`
  §5's *Plugin-level — available in any repo* table — Command · Use it when · Writes, with *Writes*
  reading "nothing — terminal output only". One line in §10 *When something is wrong*, or in §4's
  rules, pointing a developer returning to a repo at `/t4:state` before `/t4:run`. Note while
  editing, and do not silently fix: that §5 plugin-level table lists three commands and already
  omits `/t4:doctor` and `/t4:setup-tracker`, and that §3 is a decision tree and §11 a loop
  sequence — neither is a command table, so the spec's "§3, §5 and §11 each enumerate the commands"
  holds for §5 only. Widening the table to the commands it is missing is a separate chore.
  Extend Step 1's check-state.sh with one assertion: `README.md` and
  `ai-factory/docs/workflow.md` each name `/t4:state`. *Proved by:* `bash
  skills/ai-layout/scripts/check-state.sh` exiting 0 with that assertion; `bash
  skills/ai-layout/scripts/check-paths.sh` exiting 0 (`ai-factory/docs/` is scanned as
  instruction); `bash skills/ai-layout/scripts/check-release-docs.sh` exiting 0. *ACs:* 16, in
  part — the docs half. The adapter and manifest half is Ambiguity G and is not met.

- [x] **Step 5 — `--done` lists only what is finished.** Ambiguity C, answered 2026-09-29: `--done`
  **replaces** the default listing rather than widening it. Extend check-state.sh first with the
  fixture the answer fixes — a repo holding one item whose every step is `[x]` and one with a step
  still `[ ]` — asserting that `--done` emits exactly the complete item's row and no row for the
  incomplete one, the mirror image of what the default listing produces over the same fixture, and
  that the header line and the column order are byte-identical to the default listing's. Add the
  two placement fixtures, so the settled checkbox-beats-directory rule holds under the filter too:
  a complete plan sitting in `ai-factory/plans/` rather than `done/` is still listed by `--done`,
  and an incomplete one sitting in `done/` is still not (AC10). Add the empty case: `--done` over a
  repo with nothing complete prints the same one-line empty answer the default listing gives, and
  exits 0 (AC11). Pin that it widens nothing — no column the default listing does not already
  carry, and no item that has no state. Then make it pass in `state.sh` by filtering the rows Step 2
  already builds on the state field Step 2 already emits, reusing one row builder for both listings
  so they cannot drift apart.
  **Added to this step's scope 2026-09-29 — the prompt-to-script hand-off, found during Step 3.**
  Nothing in the plan ever forwarded the developer's argument to `state.sh`: Step 3 fixes the
  invocation as `state.sh . "${CLAUDE_PLUGIN_ROOT}"` and places `$ARGUMENTS` last as trailing
  context, and Steps 6 and 7 name only `state.sh` and `check-state.sh`. So without this, the script
  would grow `--done`, `--next` and their refusal while `/t4:state --done` typed by a developer
  still rendered the default listing — half-wired, with every check green, because no assertion
  covered the hand-off. This step therefore also reopens `commands/state.md` to forward the
  argument through to the script, and adds one invariant to check-state.sh asserting that it does.
  **`$ARGUMENTS` must stay last in the file**: Step 3 put it there deliberately so the cached
  prefix is stable, and the two are compatible — the invocation line takes the value, the trailing
  `Context:` keeps the cache boundary. A fix that hoists `$ARGUMENTS` up into the invocation trades
  this gap for a silent caching regression and is not the fix.
  *Proved by:* `bash skills/ai-layout/scripts/check-state.sh` exiting 0.
  *ACs:* 5, 7, 10, 11, and AC14's hand-off.

- [ ] **Step 6 — `--next` names the most recently modified artefact, by git commit date.**
  Ambiguity A, answered 2026-09-29. The key for each row of the default listing is
  `git log -1 --format=%ct -- <path>`, run with the repo root as the working directory: the commit
  date, in seconds, of the artefact's last commit. An artefact the command answers with an empty
  string — uncommitted or untracked — sorts as **newest**. Highest key wins; ties break on the
  artefact's leading four-digit number, lowest first, then on path, then on step number, so the
  order is total and exactly one row can win. Emit that one row, byte-identical to the row the
  default listing produces for the same artefact (AC6's subset), plus one reason line naming the
  artefact and the rule that chose it — newest commit date, or uncommitted, or which tiebreak
  decided. **Why commit date and not mtime:** an mtime does not survive a clone, so two developers
  on the same commit would get different answers from the same tree, while a commit date is
  identical in every clone. AC13 — the same tree, run twice, nothing changed in between — holds
  under either measure, so this is cross-clone agreement, not an AC13 fix, and the reason line and
  the commit message should say it that way. **Two guards the rule needs.** *One:* `git` may be
  absent, or the repo root handed to `state.sh` may not be a git repository at all, in which case
  `git` walks **up** to an ancestor repository — verified on 2026-09-29: `git rev-parse
  --show-toplevel` run from `skills/` in this repo answers with this repo's root, and a plain
  directory nested under any repo answers with that repo. Reading an ancestor's history would break
  AC15, so gate every `git log` on `[ "$(git rev-parse --show-toplevel 2>/dev/null)" = "$(pwd -P)" ]`
  — `pwd -P`, because `mktemp -d` hands back a symlinked path on macOS while `--show-toplevel`
  answers with the physical one. *Two:* when that gate fails, no artefact has a commit date, every
  key is empty, and the tiebreak alone decides: still one row, still deterministic, still exit 0,
  and the reason line says that no commit dates were available. Extend check-state.sh first with
  fixtures whose selection is known by construction: `git init -q` a fixture repo under `mktemp -d`,
  commit two artefacts in two commits with `GIT_AUTHOR_DATE` and `GIT_COMMITTER_DATE` pinned to
  fixed instants, and assert `--next` picks the later one; leave a third artefact untracked and
  assert it displaces both; commit two artefacts at the same pinned instant and assert the lower
  number wins; and give one fixture no `.git` at all, asserting `--next` still answers, still exits
  0, and names no artefact from outside the fixture (AC15). Every fixture git invocation carries
  `-c user.email=… -c user.name=…`, so no assertion depends on the developer's own git config.
  *Proved by:* `bash skills/ai-layout/scripts/check-state.sh` exiting 0. *ACs:* 6, 13, 15.

- [ ] **Step 7 — `--done --next` refuses, and an unknown flag still answers.** Ambiguity D, answered
  2026-09-29: the filters do not compose. `--done --next`, in either order, prints one line saying
  the combination is not meaningful and what each flag does on its own — `--done` lists what is
  finished, `--next` names the one item to pick up — and exits **0**. It does not silently fall back
  to one of them and it prints no rows: a refused result is an answer, not a crash, which is the
  same treatment this plan already gives an unknown flag (AC11 in spirit). Keep the unknown-flag
  fixture Step 2 provisioned for — an argument that is neither `--done` nor `--next` prints one line
  and exits 0 — with its message updated, since after Steps 5 and 6 it can no longer say the rule is
  undecided. Pin all three cases, `--done --next`, `--next --done` and the unknown flag, asserting
  for each: exit 0, exactly one line of output, and not one table row. *Proved by:* `bash
  skills/ai-layout/scripts/check-state.sh` exiting 0. *ACs:* 11.

- [ ] **Step 8 — Record the release as an ordinary feature entry.** Ambiguity F, answered
  2026-09-29: `/t4:state` ships as an ordinary, non-breaking feature entry, and the release check is
  fixed rather than the CHANGELOG distorted to satisfy it.
  **Prerequisite — a separate change that landed before this step, deliberately not folded into it.
  Status: DONE, 2026-09-29.** `check-release-docs.sh` used to read the CHANGELOG's top entry
  unconditionally and then require *that* entry to mark the change breaking, to tell an adopted repo
  to run `/t4:migrate-layout`, to say the hooks keep working, to tell the developer to grep their own
  CI, and to carry both deprecation notices — so any non-breaking release landing on top failed it,
  and `/t4:state` was only the first to hit it. The fix introduces `RENAME_ENTRY=2.0.0` and an
  `entry()` that locates that record **by version, wherever it sits in the file**, matching the
  heading as a literal prefix so `## 2.0.0-rc1` cannot be mistaken for it. The six assertions and the
  ten-line floor moved to that record; the top entry keeps only what is true of every release — that
  a versioned entry exists and that its version equals `.claude-plugin/plugin.json`'s. An absent
  `## 2.0.0` entry fails first and by name, which is how a rebind-by-version otherwise stops checking
  anything. It ships with eleven fixtures in a self-tested section guarded by `RELEASE_DOCS_SELFTEST`,
  covering both directions: a non-breaking patch entry on top now passes, each of the six statements
  removed individually still fails by name, and a compliant top entry over a gutted 2.0.0 entry still
  fails. That last one is what proves the six are no longer reading the top entry at all.
  **Remaining open question on this step: the version number.** `2.1.0` is spoken for — commit
  `3fd5dfd` records it as belonging to the `/t4:migrate-layout` removal, and `check-release-docs.sh`
  still asserts that the 2.0.0 entry carries the deprecation notice naming `2.1.0`. So this step
  names no version yet and must not invent one; ask before writing the entry.
  Then, in one commit: a `CHANGELOG.md` entry naming the new command, the script behind it, the
  read-only guarantee and the blast radius (no template file moved, so no adopted repo's manifest
  changes and `/t4:sync-sdlc` reports no drift from it), and that same version in
  `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` and `.codex-plugin/plugin.json`.
  Run `check-release-docs.sh` both before writing the entry and after. *Proved by:* `bash
  skills/ai-layout/scripts/check-versions.sh` exiting 0 and reporting all three manifests at the
  new version; `bash skills/ai-layout/scripts/check-release-docs.sh` exiting 0 — which it will not
  do until the prerequisite above has landed. *ACs:* 16, the record half.

## Risks and how each is checked

| Risk | How it is checked |
|---|---|
| **A fixture drifts because the real queue moves.** Two plans were filed to `done/` while this plan was being written. Any assertion over the live tree would flake within the hour | Step 1 forbids it: every assertion builds its own repo under `mktemp -d`. `grep -n 'ai-factory/specs\|ai-factory/plans' skills/ai-layout/scripts/check-state.sh` should show only paths constructed inside `$TMP` |
| **A named command is not runnable.** Plan 0008 shipped four such defects and plan 0009 a fifth | Every command in *Verification* below was executed against this tree before being written down, and the two that need a `state.sh` were executed against a stub. The one exception is stated there by name |
| **The version bump fails the release check** | `bash skills/ai-layout/scripts/check-release-docs.sh` — already reproduced in a scratch copy, with the exact failure message. Ambiguity F's answer (2026-09-29) is to fix the check, not the entry: the fix binds its six assertions to the 2.0.0 entry located **by version**, not to entries merely marked breaking — five of the six are specific to that one migration — and it landed as a separate change before Step 8, **status DONE, 2026-09-29**, with eleven fixtures proving both directions. Step 8 still has no version number, so run the check before writing the entry and again after |
| **`--next` reads a repository the run was never given.** Step 6's rule calls `git`, and in a directory that is not itself a repository `git` walks up to an ancestor one — proved: `git rev-parse --show-toplevel` from `skills/` here answers with this repo's root. Answering `--next` from an ancestor's history would break AC15 | Step 6 gates every `git log` on `[ "$(git rev-parse --show-toplevel 2>/dev/null)" = "$(pwd -P)" ]`, and check-state.sh carries a fixture with no `.git` at all, asserting `--next` still answers, still exits 0 and names nothing from outside the fixture |
| **A prompt trips a scan the moment it lands** | `check-adapters.sh` (banned terms over `commands/*.md`) and `check-paths.sh` (pre-1.0.0 paths in `commands/`). Both were run in a scratch copy with a candidate `commands/state.md` and `skills/ai-layout/scripts/state.sh` present; both passed, as did `check-manifest.sh`, `check-entrypoints.sh`, `check-doctor.sh` and `check-release-docs.sh` |
| **The two `- [~]` records get edited while the rules about them are being pinned** | `git diff --exit-code -- ai-factory/plans/done/0003-tracker-setup.md ai-factory/plans/done/0004-knowledge-seam.md`, and their hashes: `1da2b5cf…` and `0b5a5a57…` from `shasum` |
| **`/t4:run` does not get the fresh context this plan assumes.** `ai-factory/agents/` symlinks four of the eight canonical agents — `analyst`, `architect`, `reviewer`, `tester` — and `.claude/agents/` is generated from it, so `explorer`, `implementer`, `planner` and `specifier` are not spawnable in *this* repo and `/t4:run` will be carried out by the session itself. The templates do ship all eight, so adopted repos are unaffected | `ls ai-factory/agents/` and `ls .claude/agents/` against `ls agents/`. Mitigation inside the steps: each one names its files and its proving command, so a session running it needs no memory of this conversation. `ai-factory/agents/` is dont-touch and symlinked — adding the missing four is a separate chore against `ai-factory/docs/dont-touch.md`'s target, not part of this plan |
| **A bare `make` target in a step would not run.** There is no `Makefile` at this repo's root — `find . -name Makefile` returns only `skills/ai-layout/templates/Makefile`, the one adopted repos receive | No step and no verification line names `make`. Where a make target is ever needed here, the form that resolves is `make -f ai-factory/make/ai.mk <target>` |
| **The default listing is noisy in every adopted repo** because `ai-factory/specs/0000-scaffold.md` ships in the templates with no plan | Ambiguity I. Step 2 lists it; a fixture pins that behaviour, so changing the answer later changes one fixture and one rule |
| **A withdrawn or blocked step is reported outstanding for ever** | Ambiguity H. Behaviour is deliberate and pinned by fixture, so the answer, when it comes, has one place to land |
| **Piping a check to `tail` reports `tail`'s status** — `ai-factory/AGENTS.md` and DoD 1b both warn | Every command below is run directly. No pipe |

## Verification

Run from the repo root. Every command was executed against this tree on 2026-09-28 before being
written here, unless the line says otherwise.

```bash
# 1. the new test, and the new script's syntax
bash skills/ai-layout/scripts/check-state.sh          # exit 0 — the new check (Step 1 writes it)
bash -n skills/ai-layout/scripts/state.sh
bash -n skills/ai-layout/scripts/check-state.sh

# 2. determinism, read-only, and the empty answer (AC8, AC9, AC11, AC13)
diff <(bash skills/ai-layout/scripts/state.sh .) <(bash skills/ai-layout/scripts/state.sh .)
before=$(find . -path ./.git -prune -o -type f -print | sort | shasum)
bash skills/ai-layout/scripts/state.sh . >/dev/null; echo "exit=$?"     # must be 0
after=$(find . -path ./.git -prune -o -type f -print | sort | shasum)
[ "$before" = "$after" ] && echo "no file created or removed"
b=$(find . -path ./.git -prune -o -type f -exec shasum {} + | sort | shasum)
bash skills/ai-layout/scripts/state.sh . >/dev/null
a=$(find . -path ./.git -prune -o -type f -exec shasum {} + | sort | shasum)
[ "$b" = "$a" ] && echo "no file edited"

# 3. every check in the repo, run directly — never piped (DoD 1b)
for f in skills/ai-layout/scripts/check-*.sh; do bash "$f" || echo "FAIL $f"; done
for f in skills/ai-hooks/fixtures/check-*.sh; do bash "$f" || echo "FAIL $f"; done
for f in skills/ai-hooks/scripts/*.js; do node --check "$f"; done
bash -n skills/ai-layout/templates/ai-factory/make/sync-adapters.sh

# 4. the two records this feature must not touch
git diff --exit-code -- ai-factory/plans/done/0003-tracker-setup.md \
                        ai-factory/plans/done/0004-knowledge-seam.md
```

What was actually run, so the next person does not have to trust this list:

- **Executed against this tree, all green:** the nine `skills/ai-layout/scripts/check-*.sh`
  (`check-adapters`, `check-cost`, `check-doctor`, `check-entrypoints`, `check-manifest`,
  `check-migrate`, `check-paths`, `check-release-docs`, `check-versions`); the four
  `skills/ai-hooks/fixtures/check-*.sh`; `node --check` over every hook script; `bash -n` on
  `sync-adapters.sh`; the `git diff --exit-code` guard on the two `- [~]` plans.
- **Executed against a stub `state.sh` in a scratch copy of this repo**, to prove the command forms
  themselves run: the `diff <(…) <(…)` determinism form; both `find … shasum` snapshot forms; the
  exit-code check; a two-sibling-repo isolation run.
- **Executed in a scratch copy with a candidate `commands/state.md` and an empty
  `skills/ai-layout/scripts/state.sh` present:** `check-adapters.sh`, `check-paths.sh`,
  `check-manifest.sh`, `check-release-docs.sh`, `check-entrypoints.sh`, `check-doctor.sh` — all
  passed, which is the evidence behind Ambiguity G and behind Step 3's scan warnings.
- **Executed in a scratch copy with a 2.1.0 feature CHANGELOG entry and all three manifests
  bumped:** `check-versions.sh` passed, `check-release-docs.sh` failed with
  `FAIL: CHANGELOG.md's 2.1.0 entry does not mark the change breaking` — the evidence behind
  Ambiguity F.
- **Executed on 2026-09-29, when Ambiguities A, C, D and F were answered and Steps 5–8 rewritten:**
  `git log -1 --format=%ct -- <path>` against this tree over a tracked file (answers with a
  timestamp) and over a path that does not exist (answers empty, exit 0); inside a fixture repo
  under `mktemp -d`, `git init -q` plus two commits with `GIT_AUTHOR_DATE` and `GIT_COMMITTER_DATE`
  pinned, proving a fixture's `--next` selection can be fixed by construction; `git rev-parse
  --show-toplevel` equal to `pwd -P` inside that fixture and *unequal* from `skills/` in this repo,
  which is the ancestor walk-up Step 6 gates against; and all thirteen `check-*.sh`, green before
  the edit and green after it.
- **Not executed, and why:** `bash ai-factory/make/sync-adapters.sh`. It writes `.claude/`,
  `.cursor/` and `.codex/`, and the working tree carried another session's in-flight changes while
  this plan was written; running it would have mixed them. Its syntax was checked with `bash -n`,
  and `check-adapters.sh` — which runs the generator itself and asserts it is idempotent — passed.
  Run it on a clean tree before the MR, as DoD item 1 requires. `bash
  skills/ai-layout/scripts/check-state.sh` could not be executed either: Step 1 creates it.
