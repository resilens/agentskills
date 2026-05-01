#!/usr/bin/env bash
set -euo pipefail

SELF_NAME="${0##*/}"
WARN_RATIO="${C4_LAYOUT_WARN_RATIO:-1.25}"   # warn if height > WARN_RATIO * width
FAIL_ON_WARN="${C4_LAYOUT_FAIL_ON_WARN:-0}"  # set to 1 to fail on suspicious aspect
BOUNDARY_TITLE_MIN_GAP="${C4_BOUNDARY_TITLE_MIN_GAP:-30}"  # warn if header is too close to nested content
BOUNDARY_HEADER_MAX_RATIO="${C4_BOUNDARY_HEADER_MAX_RATIO:-0.45}"  # warn if header consumes too much of boundary height

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/check_layout_aspect.sh [--warn-ratio <ratio>] [--boundary-title-min-gap <px>] [--boundary-header-max-ratio <ratio>] [--fail-on-warn] <svg> [<svg> ...]

Checks SVG aspect ratio and warns when a diagram is suspiciously tall relative to
its width (common symptom of an underconstrained top-down C4 layout). Also warns
when a boundary title block is too close to nested content, which is a common
deployment-diagram legibility failure.
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

check_boundary_title_gaps() {
  local svg="$1"
  python3 - "$svg" "$BOUNDARY_TITLE_MIN_GAP" "$BOUNDARY_HEADER_MAX_RATIO" <<'PY'
import sys
import xml.etree.ElementTree as ET

svg_path = sys.argv[1]
min_gap = float(sys.argv[2])
max_ratio = float(sys.argv[3])

def strip_ns(tag):
    return tag.rsplit("}", 1)[-1]

def to_float(value):
    if value is None:
        return None
    try:
        return float(str(value).replace("px", ""))
    except Exception:
        return None

def text_baseline(node):
    y = to_float(node.get("y"))
    if y is None:
        return None
    size = to_float(node.get("font-size")) or 12.0
    return y - size

tree = ET.parse(svg_path)
root = tree.getroot()
clusters = []

for group in root.iter():
    if strip_ns(group.tag) != "g":
        continue
    if group.get("class") != "cluster":
        continue
    qualified_name = group.get("data-qualified-name")
    if not qualified_name:
        continue

    rect = None
    header_bottom = None
    for child in group:
      tag = strip_ns(child.tag)
      if tag == "rect" and rect is None:
          rect = child
      elif tag == "text":
          y = to_float(child.get("y"))
          if y is not None:
              header_bottom = y if header_bottom is None else max(header_bottom, y)

    if rect is None or header_bottom is None:
        continue

    clusters.append(
        {
            "name": qualified_name,
            "header_bottom": header_bottom,
            "rect_top": to_float(rect.get("y")) or 0.0,
            "rect_height": to_float(rect.get("height")) or 0.0,
        }
    )

issues = []
for cluster in clusters:
    prefix = cluster["name"] + "."
    descendant_top = None
    descendant_name = None

    for group in root.iter():
        if strip_ns(group.tag) != "g":
            continue
        qn = group.get("data-qualified-name")
        if not qn or not qn.startswith(prefix):
            continue

        group_top = None
        for child in group:
            tag = strip_ns(child.tag)
            if tag == "rect":
                y = to_float(child.get("y"))
                if y is not None:
                    group_top = y if group_top is None else min(group_top, y)
            elif tag == "text":
                y = text_baseline(child)
                if y is not None:
                    group_top = y if group_top is None else min(group_top, y)

        if group_top is None:
            continue

        if descendant_top is None or group_top < descendant_top:
            descendant_top = group_top
            descendant_name = qn

    if descendant_top is None:
        continue

    gap = descendant_top - cluster["header_bottom"]
    header_ratio = 0.0
    if cluster["rect_height"] > 0:
        header_ratio = (cluster["header_bottom"] - cluster["rect_top"]) / cluster["rect_height"]
    if gap < min_gap and header_ratio > max_ratio:
        issues.append((cluster["name"], descendant_name, gap, header_ratio))

for cluster_name, descendant_name, gap, header_ratio in issues:
    print(f"WARN\t{cluster_name}\t{descendant_name}\t{gap:.1f}\t{header_ratio:.2f}")
PY
}

svg_paths=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --warn-ratio)
      WARN_RATIO="${2:-}"
      shift 2
      ;;
    --boundary-title-min-gap)
      BOUNDARY_TITLE_MIN_GAP="${2:-}"
      shift 2
      ;;
    --boundary-header-max-ratio)
      BOUNDARY_HEADER_MAX_RATIO="${2:-}"
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

  while IFS=$'\t' read -r kind cluster_name descendant_name gap header_ratio; do
    [[ -n "${kind:-}" ]] || continue
    warnings=$((warnings + 1))
    printf '%s: warning: boundary title may collide with nested content (gap %spx < %spx, header ratio %s > %s): %s\n' \
      "$SELF_NAME" "$gap" "$BOUNDARY_TITLE_MIN_GAP" "$header_ratio" "$BOUNDARY_HEADER_MAX_RATIO" "$svg" >&2
    printf '%s: hint: tighten wrapping with $NODE_TYPE_MAX_CHAR_WIDTH, $NODE_DESCR_MAX_CHAR_WIDTH, or $DEFAULT_WRAP_WIDTH; then try Deployment_Node_L/R or Node_L/R for %s.\n' \
      "$SELF_NAME" "$cluster_name" >&2
    printf '%s: detail: closest nested element is %s\n' \
      "$SELF_NAME" "$descendant_name" >&2
  done < <(check_boundary_title_gaps "$svg")
done

if [[ "$warnings" -gt 0 && "$FAIL_ON_WARN" == "1" ]]; then
  die "layout aspect check reported $warnings suspicious diagram(s)"
fi
