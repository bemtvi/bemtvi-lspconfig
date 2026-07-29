#!/usr/bin/env bash
# Regenerate both help files and fail if either differs from what's committed, so a
# push can't ship stale docs. Wire as a pre-push hook (see .pre-commit-config.yaml),
# or run directly any time.
#
#   doc/nxvim-lspconfig.txt  ← authored doc/nxvim-lspconfig.md, via panvimdoc
#   doc/configs.{md,txt}     ← the `---@brief` blocks in lsp/, via docgen.lua
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

command -v pandoc >/dev/null 2>&1 || { echo "error: pandoc (>= 3) is required" >&2; exit 1; }

bash scripts/gen-vimdoc.sh >/dev/null

# The per-server reference needs nxvim itself to render the configs. Skip it rather
# than fail when nxvim isn't on $PATH: a contributor editing prose shouldn't be
# blocked by not having a build, and CI has one.
if command -v "${NXVIM:-nxvim}" >/dev/null 2>&1; then
  bash scripts/gen-configs.sh >/dev/null
else
  echo "note: ${NXVIM:-nxvim} not found — skipping doc/configs.* (set \$NXVIM to check them)" >&2
fi

stale=()
for f in doc/nxvim-lspconfig.txt doc/configs.md doc/configs.txt; do
  if ! git diff --quiet -- "$f"; then
    stale+=("$f")
  fi
done

if [ ${#stale[@]} -ne 0 ]; then
  echo "error: generated docs are out of date: ${stale[*]}" >&2
  echo "  regenerate with: bash scripts/gen-vimdoc.sh && bash scripts/gen-configs.sh" >&2
  exit 1
fi
echo "generated docs up to date"
