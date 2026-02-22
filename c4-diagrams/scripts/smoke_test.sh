#!/usr/bin/env bash
set -euo pipefail

SELF_NAME="${0##*/}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
RENDER_SH="$SKILL_ROOT/scripts/render.sh"
CHECK_LAYOUT_SH="$SKILL_ROOT/scripts/check_layout_aspect.sh"

die() {
  printf '%s: %s\n' "$SELF_NAME" "$*" >&2
  exit 1
}

[[ -x "$RENDER_SH" ]] || die "render wrapper not found or not executable: $RENDER_SH"

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

run_case() {
  local name="$1"
  local puml="$tmpdir/${name}.puml"
  local out="$tmpdir/${name}.svg"

  cat > "$puml"
  if ! cat "$puml" | bash "$RENDER_SH" -tsvg -pipe >"$out" 2>"$tmpdir/${name}.stderr"; then
    printf '%s: failed rendering %s\n' "$SELF_NAME" "$name" >&2
    cat "$tmpdir/${name}.stderr" >&2 || true
    return 1
  fi

  [[ -s "$out" ]] || die "expected output not created: $out"
  printf '%s: ok %s -> %s\n' "$SELF_NAME" "$name" "$out" >&2

  # Heuristic warning only (unless C4_LAYOUT_FAIL_ON_WARN=1) for common
  # top-down-string layout failures in L1/L2 diagrams.
  if [[ -x "$CHECK_LAYOUT_SH" && ( "$name" == "context" || "$name" == "container" ) ]]; then
    bash "$CHECK_LAYOUT_SH" "$out" >&2 || return 1
  fi
}

run_case context <<'EOF'
@startuml context-smoke
LAYOUT_LANDSCAPE()
left to right direction

Person(user, "User", "Primary actor")
Person(admin, "Admin", "Operator")
System(system, "System", "Does useful work")
System_Ext(ext_api, "External API", "Neighbor integration")
System_Ext(ext_store, "External Store", "Persistence")

Rel_R(user, system, "Uses")
Rel_D(admin, system, "Operates")
Rel_R(system, ext_api, "Calls")
Rel_D(system, ext_store, "Stores state")

Lay_U(user, admin)
Lay_D(ext_api, ext_store)
@enduml
EOF

run_case container <<'EOF'
@startuml container-smoke
Person(user, "User")
System_Boundary(s1, "System") {
  Container(api, "API", "HTTP", "Handles requests")
  ContainerDb(db, "DB", "PostgreSQL", "Stores data")
}
Rel(user, api, "Uses")
Rel(api, db, "Reads/Writes")
@enduml
EOF

run_case component <<'EOF'
@startuml component-smoke
Container_Boundary(c1, "API Container") {
  Component(ctrl, "Controller", "Module", "Receives requests")
  Component(svc, "Service", "Module", "Business logic")
}
Rel(ctrl, svc, "Calls")
@enduml
EOF

run_case dynamic <<'EOF'
@startuml dynamic-smoke
Person(user, "User")
System(system, "System")
RelIndex(1, user, system, "Uses")
@enduml
EOF

run_case sequence <<'EOF'
@startuml sequence-smoke
SHOW_INDEX()
Person(user, "User")
System(system, "System")
Rel(user, system, "Uses")
@enduml
EOF

run_case sequence_boundary <<'EOF'
@startuml sequence-boundary-smoke
SHOW_INDEX()
Person(user, "User")
System(system, "System")
Container_Boundary(app_boundary, "App") 
  Container(api, "API", "Node.js", "Handles requests")
Boundary_End()
Rel(user, api, "Sends request")
Rel(api, system, "Calls")
@enduml
EOF

run_case deployment <<'EOF'
@startuml deployment-smoke
Deployment_Node(node1, "App Node", "Docker")
@enduml
EOF

printf '%s: all C4 smoke renders passed\n' "$SELF_NAME" >&2
