# 0002 — Layout drift is detected by pull, and ai-sdlc keeps no registry

Date: 2026-09-06 · Status: accepted

## Context
Something must notice that an adopted repo is behind. The obvious alternative is a registry:
ai-sdlc records which repo is on which version and reports centrally. That requires ai-sdlc to
enumerate and read other repos.

## Decision
Drift is detected only when someone runs `/ai-sdlc:sync` inside the repo, comparing that repo's
`ai/.sdlc.json` against the installed plugin's templates. ai-sdlc keeps no list of adopters,
never reads another repo, and never writes into one out of band. Each adopted repo is the
source of truth for its own version.

This also follows from the standalone rule in `ai/docs/fleet.md`: ai-sdlc depends on no repo and
may not name, read, list or version-pin one. A registry would break that rule outright.

## Consequences
ai-sdlc stays standalone and has no state to keep correct or secure. Nothing can answer
"which repos are behind?" from here — that view has to be assembled outside ai-sdlc, by whoever
wants it. A repo nobody runs `/ai-sdlc:sync` in drifts silently and forever; the check surfaces
drift, it does not chase it. A repo adopted before manifests existed is not an error: it is
told how to start a baseline from its files as they stand.
