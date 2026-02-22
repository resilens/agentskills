#!/usr/bin/env bash
# render wrapper: use local PlantUML if present, otherwise run PlantUML via Docker.
# Falls back to a remote PlantUML server only if local and Docker are unavailable.
#
# Dependencies:
# - Optional: local `plantuml` on PATH
# - Fallback: `docker` on PATH and a working Docker daemon
# - Last resort: remote PlantUML server (default https://kroki.io)
#
# Behavior:
# - Passes all arguments through to PlantUML unchanged.
# - Mounts the current working directory into the container so relative paths work.
# - Prints clear error messages for common failure modes.

set -euo pipefail

SELF_NAME="${0##*/}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
LOCAL_INCLUDE_ROOT="${C4_LOCAL_INCLUDE_ROOT:-$SKILL_ROOT/assets/includes}"
LOCAL_C4_DIR="$LOCAL_INCLUDE_ROOT/C4"

die() {
  printf '%s: %s\n' "$SELF_NAME" "$*" >&2
  exit 1
}

have() { command -v "$1" >/dev/null 2>&1; }

print_c4_macro_hint() {
  cat >&2 <<EOF
$SELF_NAME: hint: If C4 macros are undefined, check:
$SELF_NAME: hint: - $LOCAL_C4_DIR/C4_All.puml contains Context/Container/Component/Dynamic/Deployment/Sequence includes
$SELF_NAME: hint: - RELATIVE_INCLUDE points to the vendored C4 folder (currently injected by this wrapper)
EOF
}

run_with_c4_hint() {
  set +e
  "$@"
  status=$?
  set -e
  if [[ $status -ne 0 ]]; then
    print_c4_macro_hint
  fi
  return $status
}

LOCAL_C4_ARGS=()
if [[ -f "$LOCAL_C4_DIR/C4_All.puml" ]]; then
  LOCAL_C4_ARGS=(
    "-DRELATIVE_INCLUDE=${LOCAL_C4_DIR}"
    -I "$LOCAL_C4_DIR/C4_All.puml"
  )
else
  printf '%s: warning: C4 preload bundle not found at %s; C4 macros may be undefined without explicit !include lines.\n' \
    "$SELF_NAME" "$LOCAL_C4_DIR/C4_All.puml" >&2
fi

# If a real plantuml exists and this script isn't shadowing itself (PATH recursion), use it.
if have plantuml; then
  # Resolve the first plantuml found in PATH (might be this wrapper if named plantuml).
  PLANTUML_PATH="$(command -v plantuml || true)"
  if [[ -n "${PLANTUML_PATH}" && "${PLANTUML_PATH}" != "$0" ]]; then
    run_with_c4_hint plantuml "${LOCAL_C4_ARGS[@]}" "$@"
    exit $?
  fi
fi

use_docker=true
if ! have docker; then
  use_docker=false
elif ! docker info >/dev/null 2>&1; then
  use_docker=false
fi

if "$use_docker"; then
  # Workdir mount: handle paths with spaces, and ensure we're mounting an existing directory.
  WORKDIR="${PWD}"
  [[ -d "$WORKDIR" ]] || die "Current directory does not exist: $WORKDIR"
  DOCKER_MOUNTS=()
  DOCKER_C4_ARGS=()

  if [[ -f "$LOCAL_C4_DIR/C4_All.puml" ]]; then
    DOCKER_MOUNTS=(-v "$LOCAL_INCLUDE_ROOT":/skill-includes:ro)
    DOCKER_C4_ARGS=(
      "-DRELATIVE_INCLUDE=/skill-includes/C4"
      -I /skill-includes/C4/C4_All.puml
    )
  fi

  # If user passes '-' (stdin) patterns, they must also pass -pipe, but that's PlantUML behavior.
  # We don't override; just provide a hint on a common mistake.
  for arg in "$@"; do
    if [[ "$arg" == "-" ]]; then
      printf '%s: note: reading from stdin requires -pipe (example: cat file.puml | %s -tsvg -pipe > out.svg)\n' \
        "$SELF_NAME" "$SELF_NAME" >&2
      break
    fi
  done

  IMAGE="${PLANTUML_DOCKER_IMAGE:-plantuml/plantuml:latest}"

  # Pull image if missing (avoid noisy pull output unless needed)
  if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    printf '%s: PlantUML image not found locally, pulling %s...\n' "$SELF_NAME" "$IMAGE" >&2
    docker pull "$IMAGE" >/dev/null || die "Failed to pull Docker image: $IMAGE"
  fi

  # Run PlantUML in Docker.
  # -i is needed to support -pipe/stdin use-cases.
  run_with_c4_hint docker run --rm -i \
    -v "$WORKDIR":/work -w /work \
    "${DOCKER_MOUNTS[@]}" \
    "$IMAGE" "${DOCKER_C4_ARGS[@]}" "$@"
  exit $?
fi

# Remote fallback (last resort)
SERVER_URL="${PLANTUML_SERVER_URL:-https://kroki.io}"
FORMAT="png"
PIPE_MODE=false
INPUT_FILE=""

for arg in "$@"; do
  case "$arg" in
    -tpng) FORMAT="png" ;;
    -tsvg) FORMAT="svg" ;;
    -pipe) PIPE_MODE=true ;;
    -*)
      ;;
    *)
      if [[ -n "$INPUT_FILE" ]]; then
        die "Remote fallback supports a single input file."
      fi
      INPUT_FILE="$arg"
      ;;
  esac
done

if ! have curl && ! have wget; then
  die "PlantUML not found and Docker unavailable. Install curl or wget to use the remote fallback."
fi

URL="${SERVER_URL%/}/plantuml/${FORMAT}"

if "$PIPE_MODE"; then
  if have curl; then
    exec curl -sS -H "Content-Type: text/plain" --data-binary @- "$URL"
  fi
  exec wget -qO- --header="Content-Type: text/plain" --post-file=- "$URL"
fi

if [[ -z "$INPUT_FILE" ]]; then
  die "Remote fallback requires -pipe or a single input file."
fi

if [[ ! -f "$INPUT_FILE" ]]; then
  die "Input file not found: $INPUT_FILE"
fi

if have curl; then
  exec curl -sS -H "Content-Type: text/plain" --data-binary @"$INPUT_FILE" "$URL"
fi
exec wget -qO- --header="Content-Type: text/plain" --post-file="$INPUT_FILE" "$URL"
