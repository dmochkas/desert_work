#!/usr/bin/env bash
# Run ns main.tcl nn sink_mode period rng in a loop and archive outputs.
# Usage:
#   ./run_main.sh <nn> <period> <sink_mode> <n> [<start_rng>]
# - nn: number of nodes (integer)
# - period: Poisson/CBR period (non-negative float allowed, e.g., 28800, 0.5, 10.)
# - sink_mode: must be 1 or 3
# - n: number of iterations to run (positive integer)
# - start_rng: optional start value for rng/x (default: 1)
#
# Env:
#   DRY_RUN=1        # if set, only print the commands instead of executing them

set -euo pipefail

usage() {
  echo "Usage: $0 <nn> <period> <sink_mode> <n> [<start_rng>]" >&2
  echo "Example: $0 1 28800 1 5         # rng=1..5 with nn=1, period=28800, sink=1" >&2
  echo "         $0 2 14400 0 3 10     # rng=10..12 with nn=2, period=14400, sink=0" >&2
}

# Parse args (order: nn period sink n [start])
SCRIPT="main.tcl"
NN=${1:-}
PERIOD=${2:-}
SINK_MODE=${3:-}
N=${4:-}
START=${5:-1}

if [[ -z "${NN:-}" || -z "${PERIOD:-}" || -z "${SINK_MODE:-}" || -z "${N:-}" ]]; then
  usage
  exit 1
fi

# Validate args are integers
if ! [[ "${NN}" =~ ^[0-9]+$ ]]; then
  echo "Error: <nn> must be a non-negative integer." >&2
  exit 2
fi
# period: float (non-negative); allow forms: 123, 123.45, 123., .45
if ! [[ "${PERIOD}" =~ ^([0-9]+([.][0-9]*)?|[.][0-9]+)$ ]]; then
  echo "Error: <period> must be a non-negative number (float allowed), got '${PERIOD}'." >&2
  exit 2
fi
# sink_mode: exactly 1 or 3
if ! [[ "${SINK_MODE}" == "1" || "${SINK_MODE}" == "3" ]]; then
  echo "Error: <sink_mode> must be 1 or 3, got '${SINK_MODE}'." >&2
  exit 2
fi
if ! [[ "${N}" =~ ^[0-9]+$ && ${N} -gt 0 ]]; then
  echo "Error: <n> must be a positive integer." >&2
  exit 2
fi
if ! [[ "${START}" =~ ^[0-9]+$ ]]; then
  echo "Error: <start_rng> must be a non-negative integer." >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# Check dependencies (skip when DRY_RUN=1)
if [[ "${DRY_RUN:-0}" != "1" ]]; then
  if ! command -v ns >/dev/null 2>&1; then
    echo "Error: 'ns' command not found in PATH. Please install/configure ns2." >&2
    exit 127
  fi
  if [[ ! -f ${SCRIPT} ]]; then
    echo "Error: ${SCRIPT} not found in ${SCRIPT_DIR}" >&2
    exit 3
  fi
fi

END=$(( START + N - 1 ))

# Output folder based on parameters
OUT_DIR="data/${NN}_${PERIOD}_${SINK_MODE}"

safe_cp() {
  local src=$1 dst=$2
  mkdir -p -- "$(dirname "$dst")"
  cp -f "$src" "$dst"
}

dry_run() {
  echo "DRY_RUN: would run -> ns ${SCRIPT} ${NN} ${SINK_MODE} ${PERIOD} ${rng} > console.out 2>&1"
  echo "DRY_RUN: would mkdir -p '${OUT_DIR}'"
  echo "DRY_RUN: would move 'log_udp.out' -> '${OUT_DIR}/${NN}_${PERIOD}_${SINK_MODE}_${rng}_sink.out'"
  echo "DRY_RUN: would move 'console.out' -> '${OUT_DIR}/${NN}_${PERIOD}_${SINK_MODE}_${rng}_node.out'"
}

move_if_exists() {
  local src=$1 dst=$2
  if [[ -f "$src" ]]; then
    mv -f -- "$src" "$dst"
  else
    echo "Warning: '$src' not found; skipping move to '$dst'" >&2
  fi
}

safe_cp "${SCRIPT}" "./.desert/tmp_${SCRIPT}"
SCRIPT_TMP="./.desert/tmp_${SCRIPT}"

echo "Running ${N} iteration(s): rng from ${START} to ${END} (params: nn=${NN}, period=${PERIOD}, sink_mode=${SINK_MODE})"
for (( rng=START; rng<=END; rng++ )); do
  echo "[$(date +'%F %T')] Iteration rng=${rng}: ns ${SCRIPT_TMP} ${rng} ${NN} ${PERIOD} ${SINK_MODE}"
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    dry_run
    continue
  fi

  ns "${SCRIPT_TMP}" "${rng}" "${NN}" "${PERIOD}" "${SINK_MODE}" > "console.out" 2>/dev/null
  mkdir -p -- "${OUT_DIR}"
  move_if_exists "log_udp.out" "${OUT_DIR}/${NN}_${PERIOD}_${SINK_MODE}_${rng}_sink.out"
  move_if_exists "console.out" "${OUT_DIR}/${NN}_${PERIOD}_${SINK_MODE}_${rng}_node.out"
done

rm -f "${SCRIPT_TMP}"