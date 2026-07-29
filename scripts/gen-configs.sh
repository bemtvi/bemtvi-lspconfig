#!/usr/bin/env bash
#
# Generate doc/configs.md + doc/configs.txt — the per-server reference — from the
# files in lsp/, by running scripts/docgen.lua under nxvim itself.
#
# Requires: bash, and `nxvim` on $PATH (or $NXVIM pointing at a build).
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

NXVIM="${NXVIM:-nxvim}"
command -v "$NXVIM" >/dev/null 2>&1 || {
  echo "error: $NXVIM not found — put nxvim on \$PATH or set \$NXVIM to a build" >&2
  exit 1
}

# `--lua` takes a chunk of Lua, not a path, so hand it a dofile of the generator.
# The generator resolves everything else off the cwd, which is the repo root here.
"$NXVIM" --lua "dofile('$ROOT/scripts/docgen.lua')"
