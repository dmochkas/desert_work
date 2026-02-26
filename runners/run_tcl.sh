#!/usr/bin/env bash
# Run an ns Tcl script with arbitrary arguments and archive outputs.
#
# Usage:
#   ./run_tcl.sh <script.tcl> [<ns_arg1> <ns_arg2> ...]
#
# Semantics:
# - All CLI arguments after <script.tcl> are passed through to the Tcl script
#   in the same order.
# - Captures stdout/stderr into console.out and moves outputs/logs into a
#   per-run output folder.
#
# Env:
#   NS_BIN=ns        # override ns executable (path or name)
#   DRY_RUN=1        # if set, only print the actions instead of executing them

set -euo pipefail

NS_BIN=${NS_BIN:-ns}

usage() {
  echo "Usage: $0 <script.tcl> [<ns_arg1> <ns_arg2> ...]" >&2
  echo "Example: $0 main.tcl 1 28800 3" >&2
}

SCRIPT=${1:-}
if [[ -z "${SCRIPT:-}" ]]; then
  usage
  exit 1
fi
shift || true
NS_ARGS=("$@")

INVOKE_DIR="${PWD}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Dependency / script existence checks (skip when DRY_RUN=1)
if [[ "${DRY_RUN:-0}" != "1" ]]; then
  if ! command -v "${NS_BIN}" >/dev/null 2>&1; then
    echo "Error: '${NS_BIN}' command not found in PATH. Set NS_BIN to override." >&2
    exit 127
  fi
  if [[ ! -f "${SCRIPT}" ]]; then
    echo "Error: ${SCRIPT} not found (cwd=${INVOKE_DIR})" >&2
    exit 3
  fi
fi

move_if_exists() {
  local src=$1 dst=$2
  if [[ -f "$src" ]]; then
    mkdir -p -- "$(dirname "$dst")"
    mv -f -- "$src" "$dst"
  else
    echo "Warning: '$src' not found; skipping move to '$dst'" >&2
  fi
}

safe_cp() {
  local src=$1 dst=$2
  mkdir -p -- "$(dirname "$dst")"
  cp -f -- "$src" "$dst"
}

# Output folder based on script + args (filesystem-safe-ish)
SCRIPT_BASENAME="$(basename -- "${SCRIPT}")"
SCRIPT_NAME="${SCRIPT_BASENAME%.*}"
ARGS_TAG=""
if ((${#NS_ARGS[@]} > 0)); then
  ARGS_TAG="${NS_ARGS[*]}"
  ARGS_TAG=${ARGS_TAG//\//_}
  ARGS_TAG=${ARGS_TAG// /_}
fi
if ((${#NS_ARGS[@]} > 1)); then
  NS_ARGS_DIR=("${NS_ARGS[@]:0:${#NS_ARGS[@]}-1}")
  ARGS_TAG_DIR="${NS_ARGS_DIR[*]}"
  ARGS_TAG_DIR=${ARGS_TAG_DIR//\//_}
  ARGS_TAG_DIR=${ARGS_TAG_DIR// /_}
else
  ARGS_TAG_DIR=""   # only one arg -> directory has no args component
fi
OUT_DIR="data/${SCRIPT_NAME}/${ARGS_TAG_DIR}"
RUN_TAG="${ARGS_TAG}"

# Work on a temp copy to avoid accidental in-place edits during runs
SCRIPT_TMP="./.desert/tmp_${SCRIPT_NAME}_${RUN_TAG}.tcl"
safe_cp "${SCRIPT}" "${SCRIPT_TMP}"

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  echo "DRY_RUN: would run -> ${NS_BIN} ${SCRIPT_TMP} ${NS_ARGS[*]} > console.out 2>&1"
  echo "DRY_RUN: would mkdir -p '${OUT_DIR}'"
  echo "DRY_RUN: would move 'log_udp.out' -> '${OUT_DIR}/${RUN_TAG}_sink.out'"
  echo "DRY_RUN: would move 'console.out' -> '${OUT_DIR}/${RUN_TAG}_node.out'"
  echo "DRY_RUN: would delete temp script '${SCRIPT_TMP}'"
  exit 0
fi

echo "[$(date +'%F %T')] Running: ${NS_BIN} ${SCRIPT_TMP} ${NS_ARGS[*]}"
"${NS_BIN}" "${SCRIPT_TMP}" "${NS_ARGS[@]}" > "console.out" 2>&1

mkdir -p -- "${OUT_DIR}"
move_if_exists "log.out" "${OUT_DIR}/${RUN_TAG}_log.out"
move_if_exists "console.out" "${OUT_DIR}/${RUN_TAG}_console.out"

rm -f -- "${SCRIPT_TMP}"
