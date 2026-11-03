#!/usr/bin/env bash
# User docs: runs the read-only `sync-docs.js --check` over the real docs/ tree so the checks loop
# catches a stale command reference, a broken notes structure, a dead link or anchor, and a wrong
# version line. It writes nothing; to fix a reported drift run `node skills/ai-layout/scripts/sync-docs.js`.
# Exits with the generator's own status.
set -euo pipefail
cd "$(dirname "$0")/../../.."
exec node skills/ai-layout/scripts/sync-docs.js --check
