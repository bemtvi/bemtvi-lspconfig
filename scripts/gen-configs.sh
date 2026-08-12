#!/usr/bin/env bash
#
# Generate doc/configs.md + doc/configs.txt — the per-server reference — from the
# files in lsp/, by running scripts/docgen.lua under bemtvi itself.
#
# Requires: bash, and `bemtvi` on $PATH (or $BEMTVI pointing at a build).
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BEMTVI="${BEMTVI:-bemtvi}"
command -v "$BEMTVI" >/dev/null 2>&1 || {
  echo "error: $BEMTVI not found — put bemtvi on \$PATH or set \$BEMTVI to a build" >&2
  exit 1
}

# `--lua` takes a chunk of Lua, not a path, so hand it a dofile of the generator.
# The generator resolves everything else off the cwd, which is the repo root here.
"$BEMTVI" --lua "dofile('$ROOT/scripts/docgen.lua')"
