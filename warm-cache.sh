#!/usr/bin/env bash
# Warm the Koka build cache by pre-compiling the full dependency chain
# using the EXACT same include paths that `hica test` uses. Run once
# after a fresh checkout or cache eviction.
# After this, `hica test` only needs to compile hq.kk + eval_test.kk.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

HML_DIR="$HOME/.hica/cache/pkg.hica.dev/hml/1.3.4"
STDLIB_DIR="$HOME/.hica/stdlib"

if [[ ! -d "$HML_DIR" ]]; then
  echo "HML cache not found, running hica --version to fetch it..."
  hica --version
fi

# Compile a module by wrapping it in a tiny program in tests/ so Koka
# uses the SAME include-path hash as `hica test tests/eval_test.hc`.
warmup_module() {
  local name="$1"    # Koka module name (e.g. "hq_node")
  echo "  warming: $name"
  local wrap="tests/warm_${name}.kk"
  local out="tests/warm_${name}_bin"
  printf 'module warm_%s\nimport %s\npub fun main() : io ()\n  ()\n' \
    "$name" "$name" > "$wrap"
  koka -O0 -v0 -o "$out" \
    -i"tests/std" -i"src" \
    -i"$HML_DIR" -i"$HML_DIR/src" \
    -i"$STDLIB_DIR" \
    "$wrap" > /dev/null 2>&1
  rm -f "$wrap" "$out"
}

echo "Pre-compiling HML + stdlib + src to warm .koka/ cache..."

# HML library (if not already warmed from a previous run)
warmup_module "hml_types"
warmup_module "parser"
warmup_module "api"
warmup_module "display"
warmup_module "hml"

# Project modules — HML .kki files are now warm
warmup_module "mutate"
warmup_module "hq_node"
warmup_module "hq_fmt"
warmup_module "hq_parse"

echo "Done — .koka/ cache is warm for all deps."
echo "hica test now only needs to compile hq.kk + eval_test.kk (~minutes)."
