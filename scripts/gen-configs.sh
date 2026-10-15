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

# Run against an empty config dir. `--lua` still sources the user's init.lua, and a
# config that layers onto `btv.lsp.config("*", …)` (an `on_attach`, `root_markers`)
# leaks into every config the generator resolves through `btv.lsp.get_config` —
# the renamed-server aliases — so the page would document the generating machine's
# setup rather than the plugin's defaults.
EMPTY_CONFIG="$(mktemp -d)"
trap 'rm -rf "$EMPTY_CONFIG"' EXIT

# `--lua` takes a chunk of Lua, not a path, so hand it a dofile of the generator.
# The generator resolves everything else off the cwd, which is the repo root here.
BEMTVI_CONFIG="$EMPTY_CONFIG" "$BEMTVI" --lua "dofile('$ROOT/scripts/docgen.lua')"
