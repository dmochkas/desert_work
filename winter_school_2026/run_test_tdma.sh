#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  run_test_tdma.sh <n> <arg1> <arg2>

Runs (for i = 0..n inclusive):
  ns test_uwtdma.tcl <arg1> <arg2+i> > data/test_uwtdma_<arg1>_<arg2>_i.out

Notes:
  In test_uwtdma.tcl these map to:
    argv[0] -> windspeed
    argv[1] -> rngstream (computed per iteration as arg2+i)

Examples:
  ./run_test_tdma.sh 10 10 1
USAGE
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -ne 3 ]]; then
  echo "Error: expected exactly 3 arguments: n, arg1, arg2." >&2
  usage >&2
  exit 2
fi

n="$1"
arg1="$2"
arg2="$3"

if ! [[ "$n" =~ ^[0-9]+$ ]]; then
  echo "Error: n must be a non-negative integer, got: $n" >&2
  exit 2
fi

# arg2 participates in arithmetic: allow negative too.
if ! [[ "$arg2" =~ ^-?[0-9]+$ ]]; then
  echo "Error: arg2 must be an integer (used as arg2+i), got: $arg2" >&2
  exit 2
fi

# Make args safe for filenames (keep alnum, dot, underscore, dash; map others to '_').
make_safe() {
  local s="$1"
  s="${s//[^[:alnum:]._ -]/_}"
  s="${s// /_}"
  printf '%s' "$s"
}

arg1_safe="$(make_safe "$arg1")"
arg2_safe="$(make_safe "$arg2")"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

if ! command -v ns >/dev/null 2>&1; then
  echo "Error: 'ns' not found in PATH. Please install/configure ns (ns-2) first." >&2
  exit 127
fi

if [[ ! -f "test_uwtdma.tcl" ]]; then
  echo "Error: test_uwtdma.tcl not found in $script_dir" >&2
  exit 1
fi

mkdir -p data

for (( i=0; i<=n; i++ )); do
  out="data/test_uwtdma_${arg1_safe}_${arg2_safe}_${i}.out"
  arg2_i=$((arg2 + i))
  echo "[$(date +"%F %T")] Running iteration $i (arg1='$arg1', arg2='$arg2', arg2+i='$arg2_i') -> $out"
  ns test_uwtdma.tcl "$arg1" "$arg2_i" >"$out"
done

echo "Done. Outputs written to: $script_dir/data"
