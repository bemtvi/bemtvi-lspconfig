#!/usr/bin/env bash
# Regenerate the vimdoc and fail if it differs from what's committed, so a push
# can't ship a stale help file. Wire as a pre-push hook (see
# .pre-commit-config.yaml), or run directly any time.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

command -v pandoc >/dev/null 2>&1 || { echo "error: pandoc (>= 3) is required" >&2; exit 1; }

bash scripts/gen-vimdoc.sh >/dev/null

OUTPUT="doc/nxvim-lspconfig.txt"
if ! git diff --quiet -- "$OUTPUT"; then
  echo "error: $OUTPUT is out of date — regenerate and commit it:" >&2
  echo "  bash scripts/gen-vimdoc.sh" >&2
  exit 1
fi
echo "vimdoc up to date"
