#!/usr/bin/env bash
set -euo pipefail

SELF_NAME="${0##*/}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
TARGET_DIR="$SKILL_ROOT/assets/includes/C4"
REPO_URL="${C4_PLANTUML_REPO_URL:-https://github.com/plantuml-stdlib/C4-PlantUML.git}"
REPO_REF="${C4_PLANTUML_REF:-master}"

die() {
  printf '%s: %s\n' "$SELF_NAME" "$*" >&2
  exit 1
}

have() { command -v "$1" >/dev/null 2>&1; }

have git || die "git is required."

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

printf '%s: syncing C4-PlantUML from %s (%s)\n' "$SELF_NAME" "$REPO_URL" "$REPO_REF" >&2
git clone --depth 1 --branch "$REPO_REF" "$REPO_URL" "$tmpdir/C4-PlantUML" >/dev/null 2>&1

repo="$tmpdir/C4-PlantUML"
commit="$(git -C "$repo" rev-parse HEAD)"
date="$(git -C "$repo" show -s --format=%cs HEAD)"

mkdir -p "$TARGET_DIR"
cp -f "$repo"/C4*.puml "$TARGET_DIR"/
cp -f "$repo"/LICENSE "$TARGET_DIR"/LICENSE

# Rewrite local include mode to use an absolute path macro so wrappers can point
# RELATIVE_INCLUDE to this vendored folder.
patch_local_include() {
  local file="$1"
  local dep="$2"
  perl -pi -e "s#!include \\./${dep}#!include RELATIVE_INCLUDE/${dep}#g" "$TARGET_DIR/$file"
}

patch_local_include "C4_Context.puml" "C4.puml"
patch_local_include "C4_Container.puml" "C4_Context.puml"
patch_local_include "C4_Component.puml" "C4_Container.puml"
patch_local_include "C4_Dynamic.puml" "C4_Component.puml"
patch_local_include "C4_Deployment.puml" "C4_Container.puml"
patch_local_include "C4_Sequence.puml" "C4_Component.puml"

cat > "$TARGET_DIR/C4_All.puml" <<'EOF'
' Preload all C4 levels from the local vendored bundle.
' RELATIVE_INCLUDE must point at this folder.
!include_once RELATIVE_INCLUDE/C4_Dynamic.puml
!include_once RELATIVE_INCLUDE/C4_Deployment.puml
!include_once RELATIVE_INCLUDE/C4_Sequence.puml
EOF

cat > "$TARGET_DIR/VENDORED_FROM.txt" <<EOF
Source: $REPO_URL
Ref: $REPO_REF
Commit: $commit
Date: $date
EOF

printf '%s: updated %s (commit %s)\n' "$SELF_NAME" "$TARGET_DIR" "$commit" >&2
