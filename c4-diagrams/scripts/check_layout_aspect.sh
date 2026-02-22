#!/usr/bin/env bash
set -euo pipefail

SELF_NAME="${0##*/}"
WARN_RATIO="${C4_LAYOUT_WARN_RATIO:-1.25}"   # warn if height > WARN_RATIO * width
FAIL_ON_WARN="${C4_LAYOUT_FAIL_ON_WARN:-0}"  # set to 1 to fail on suspicious aspect

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/check_layout_aspect.sh [--warn-ratio <ratio>] [--fail-on-warn] <svg> [<svg> ...]

Checks SVG aspect ratio and warns when a diagram is suspiciously tall relative to
its width (common symptom of an underconstrained top-down C4 layout).
EOF
}

die() {
  printf '%s: %s\n' "$SELF_NAME" "$*" >&2
  exit 1
}

parse_svg_dims() {
  local svg="$1"
  python3 - "$svg" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8", errors="ignore")
head = text[:4000]

def parse_num(s):
    try:
        return float(s)
    except Exception:
        return None

width = None
height = None

m = re.search(r'\bwidth="([0-9.]+)(?:px)?"', head)
if m:
    width = parse_num(m.group(1))
m = re.search(r'\bheight="([0-9.]+)(?:px)?"', head)
if m:
    height = parse_num(m.group(1))

if width is None or height is None:
    m = re.search(r'\bviewBox="[^"]*\s([0-9.]+)\s([0-9.]+)"', head)
    if m:
        width = width if width is not None else parse_num(m.group(1))
        height = height if height is not None else parse_num(m.group(2))

if not width or not height:
    print("ERR")
    sys.exit(2)

print(f"{width} {height}")
PY
}

svg_paths=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --warn-ratio)
      WARN_RATIO="${2:-}"
      shift 2
      ;;
    --fail-on-warn)
      FAIL_ON_WARN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      svg_paths+=("$1")
      shift
      ;;
  esac
done

[[ ${#svg_paths[@]} -gt 0 ]] || { usage; die "at least one SVG path is required"; }

warnings=0

for svg in "${svg_paths[@]}"; do
  [[ -f "$svg" ]] || die "file not found: $svg"
  dims="$(parse_svg_dims "$svg")" || die "failed to parse SVG dimensions: $svg"
  [[ "$dims" != "ERR" ]] || die "could not detect width/height in SVG: $svg"
  width="${dims%% *}"
  height="${dims##* }"

  suspicious="$(python3 - "$width" "$height" "$WARN_RATIO" <<'PY'
import sys
w = float(sys.argv[1]); h = float(sys.argv[2]); ratio = float(sys.argv[3])
print("1" if h > ratio * w else "0")
PY
)"

  if [[ "$suspicious" == "1" ]]; then
    warnings=$((warnings + 1))
    printf '%s: warning: suspicious tall layout (height %.1f > %.2fx width %.1f): %s\n' \
      "$SELF_NAME" "$height" "$WARN_RATIO" "$width" "$svg" >&2
    printf '%s: hint: Use LAYOUT_LANDSCAPE(), Rel_L/R/U/D, and Lay_* to anchor peers and avoid one-column stacking.\n' \
      "$SELF_NAME" >&2
  else
    printf '%s: ok aspect %.1fx%.1f: %s\n' "$SELF_NAME" "$width" "$height" "$svg" >&2
  fi
done

if [[ "$warnings" -gt 0 && "$FAIL_ON_WARN" == "1" ]]; then
  die "layout aspect check reported $warnings suspicious diagram(s)"
fi
