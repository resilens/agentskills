#!/usr/bin/env bash
set -euo pipefail

exec python3 - "$0" "$@" <<'PY'
import argparse
import html
import json
import os
import re
import sys
from pathlib import Path


SCRIPT_PATH = Path(sys.argv[1]).resolve()
SELF_NAME = SCRIPT_PATH.name
CLI_ARGS = sys.argv[2:]
SCRIPT_DIR = SCRIPT_PATH.parent
SKILL_ROOT = SCRIPT_DIR.parent
TEMPLATE_PATH = Path(os.environ.get("C4_EXPLORER_TEMPLATE", str(SKILL_ROOT / "assets" / "explorer-template.html")))


def die(msg: str, code: int = 1) -> None:
    print(f"{SELF_NAME}: {msg}", file=sys.stderr)
    raise SystemExit(code)


def warn(msg: str) -> None:
    print(f"{SELF_NAME}: warning: {msg}", file=sys.stderr)


def slugify(value: str) -> str:
    value = value.strip().lower()
    value = re.sub(r"[^a-z0-9]+", "_", value)
    value = re.sub(r"_+", "_", value).strip("_")
    return value or "item"


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        die(f"file not found: {path}")
    except Exception as exc:
        die(f"failed to read {path}: {exc}")
    assert False


def extract_readme_summary(path: Path) -> str | None:
    if not path.is_file():
        return None

    lines = read_text(path).splitlines()
    in_code = False
    in_frontmatter = False
    frontmatter_done = False
    para: list[str] = []

    for idx, line in enumerate(lines, start=1):
        if not frontmatter_done and idx == 1 and re.match(r"^---\s*$", line):
            in_frontmatter = True
            continue
        if in_frontmatter:
            if re.match(r"^---\s*$", line):
                in_frontmatter = False
                frontmatter_done = True
            continue

        if line.startswith("```"):
            in_code = not in_code
            continue
        if in_code:
            continue

        if re.match(r"^\s*$", line):
            if para:
                break
            continue
        if re.match(r"^\s*#", line):
            continue
        if re.match(r"^\s*[-*]\s+", line):
            continue
        if re.match(r"^\s*\d+\.\s+", line):
            continue
        if re.match(r"^\s*>", line):
            continue
        if re.match(r"^\s*!\[", line):
            continue
        if re.match(r"^\s*\|", line):
            continue

        para.append(line.strip())

    if not para:
        return None

    text = " ".join(para)
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)
    text = re.sub(r"`([^`]+)`", r"\1", text)
    text = re.sub(r"\*\*([^*]+)\*\*", r"\1", text)
    text = re.sub(r"\*([^*]+)\*", r"\1", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text or None


def resolve_input(path_str: str, base_dir: Path) -> Path:
    p = Path(path_str)
    if not p.is_absolute():
        p = base_dir / p
    return p.resolve()


def rel_to_output(out_dir: Path, target: Path) -> str:
    return os.path.relpath(str(target), str(out_dir))


def require_file(path_str: str | None, label: str, base_dir: Path) -> Path:
    if not path_str:
        die(f"--{label} is required")
    p = resolve_input(path_str, base_dir)
    if not p.is_file():
        die(f"{label} file not found: {path_str}")
    return p


def optional_file(path_str: str | None, label: str, base_dir: Path) -> Path | None:
    if not path_str:
        return None
    p = resolve_input(path_str, base_dir)
    if not p.is_file():
        warn(f"{label} file not found, skipping: {path_str}")
        return None
    return p


def json_for_html(data: object) -> str:
    raw = json.dumps(data, indent=2, ensure_ascii=False)
    return raw.replace("<", "\\u003c").replace("&", "\\u0026")


def make_view(view_id: str, label: str, image_rel: str, breadcrumbs: list[str]) -> dict:
    return {
        "id": view_id,
        "label": label,
        "image": image_rel,
        "breadcrumbs": breadcrumbs,
    }


def count_component_views(model: dict) -> int:
    total = 0
    for system in model["systems"]:
        for container in system.get("containers", []):
            total += len(container.get("components", []))
    return total


def top_level_view_count(model: dict) -> int:
    count = 1 if model.get("landscape") else 0
    for system in model["systems"]:
        count += len(system.get("system_views", []))
    return count


def should_compact(model: dict) -> bool:
    return (
        len(model["systems"]) == 1
        and count_component_views(model) <= 1
        and top_level_view_count(model) <= 5
    )


def flatten_views(model: dict) -> list[dict]:
    ordered: list[dict] = []
    if model.get("landscape"):
        ordered.append(model["landscape"])
    for system in model["systems"]:
        ordered.extend(system.get("system_views", []))
        for container in system.get("containers", []):
            ordered.extend(container.get("components", []))
    return ordered


def validate_duplicate(scope: set[str], value: str, label: str) -> None:
    if value in scope:
        die(f"duplicate {label}: {value}")
    scope.add(value)


def build_flat_model(args: argparse.Namespace, out_dir: Path, cwd: Path) -> tuple[dict, str, str]:
    if not args.title:
        die("--title is required when not using --manifest")

    context = require_file(args.context, "context", cwd)
    container = require_file(args.container, "container", cwd)
    component = require_file(args.component, "component", cwd)
    landscape = optional_file(args.landscape, "landscape", cwd)
    deployment = optional_file(args.deployment, "deployment", cwd)
    sequence = optional_file(args.sequence, "sequence", cwd)

    readme_path = resolve_input(args.readme or "README.md", cwd)
    summary = extract_readme_summary(readme_path)
    if not summary:
        warn(f"could not extract summary from README, using fallback: {args.readme or 'README.md'}")
        summary = "System overview not found in README.md."

    system_name = args.title
    system_slug = slugify(system_name)

    system_views: list[dict] = [
        make_view(f"{system_slug}__context", "Context", rel_to_output(out_dir, context), [system_name, "Context"]),
        make_view(f"{system_slug}__container", "Container", rel_to_output(out_dir, container), [system_name, "Container"]),
    ]
    if deployment:
        system_views.append(
            make_view(
                f"{system_slug}__deployment",
                "Deployment",
                rel_to_output(out_dir, deployment),
                [system_name, "Deployment"],
            )
        )
    if sequence:
        system_views.append(
            make_view(
                f"{system_slug}__sequence_default",
                "Sequence",
                rel_to_output(out_dir, sequence),
                [system_name, "Sequences", "Sequence"],
            )
        )

    model = {
        "schemaVersion": 1,
        "title": args.title,
        "compact": True,
        "landscape": (
            make_view("landscape", "Landscape", rel_to_output(out_dir, landscape), ["Landscape"])
            if landscape
            else None
        ),
        "systems": [
            {
                "id": system_slug,
                "name": system_name,
                "system_views": system_views,
                "containers": [
                    {
                        "id": "primary_container",
                        "name": "Primary Container",
                        "components": [
                            make_view(
                                "primary_container__components",
                                "Components",
                                rel_to_output(out_dir, component),
                                [system_name, "Primary Container", "Components"],
                            )
                        ],
                    }
                ],
            }
        ],
    }

    views = flatten_views(model)
    model["defaultViewId"] = (model["landscape"]["id"] if model.get("landscape") else views[0]["id"])
    model["compact"] = should_compact(model)
    return model, args.title, summary


def _require_manifest_str(obj: dict, key: str, ctx: str) -> str:
    value = obj.get(key)
    if not isinstance(value, str) or not value.strip():
        die(f"{ctx}.{key} must be a non-empty string")
    return value.strip()


def build_manifest_model(args: argparse.Namespace, out_dir: Path, cwd: Path) -> tuple[dict, str, str]:
    manifest_path = resolve_input(args.manifest, cwd)
    if not manifest_path.is_file():
        die(f"manifest file not found: {args.manifest}")
    try:
        manifest = json.loads(read_text(manifest_path))
    except json.JSONDecodeError as exc:
        die(f"invalid JSON manifest {args.manifest}: {exc}")
    if not isinstance(manifest, dict):
        die("manifest root must be a JSON object")

    manifest_dir = manifest_path.parent
    title = args.title or (manifest.get("title") if isinstance(manifest.get("title"), str) else None)
    if not title:
        die("manifest.title is required (or pass --title override)")

    readme_candidate = args.readme or manifest.get("readme") or "README.md"
    readme_base = cwd if args.readme else manifest_dir
    readme_path = resolve_input(str(readme_candidate), readme_base)
    summary = extract_readme_summary(readme_path)
    if not summary:
        warn(f"could not extract summary from README, using fallback: {readme_candidate}")
        summary = "System overview not found in README.md."

    landscape_path = None
    if manifest.get("landscape") is not None:
        if not isinstance(manifest.get("landscape"), str):
            die("manifest.landscape must be a string path when present")
        landscape_path = optional_file(manifest.get("landscape"), "landscape", manifest_dir)

    systems_raw = manifest.get("systems")
    if not isinstance(systems_raw, list) or not systems_raw:
        die("manifest.systems must be a non-empty array")

    system_ids: set[str] = set()
    systems: list[dict] = []

    for idx, system_raw in enumerate(systems_raw):
        ctx = f"systems[{idx}]"
        if not isinstance(system_raw, dict):
            die(f"{ctx} must be an object")
        system_id = _require_manifest_str(system_raw, "id", ctx)
        system_name = _require_manifest_str(system_raw, "name", ctx)
        validate_duplicate(system_ids, system_id, "system id")

        context_path = require_file(system_raw.get("context"), f"{ctx}.context", manifest_dir)
        container_path = require_file(system_raw.get("container"), f"{ctx}.container", manifest_dir)

        system_views = [
            make_view(
                f"{system_id}__context",
                "Context",
                rel_to_output(out_dir, context_path),
                [system_name, "Context"],
            ),
            make_view(
                f"{system_id}__container",
                "Container",
                rel_to_output(out_dir, container_path),
                [system_name, "Container"],
            ),
        ]

        if "deployment" in system_raw and system_raw["deployment"] is not None:
            if not isinstance(system_raw["deployment"], str):
                die(f"{ctx}.deployment must be a string path")
            deployment = optional_file(system_raw["deployment"], f"{ctx}.deployment", manifest_dir)
            if deployment:
                system_views.append(
                    make_view(
                        f"{system_id}__deployment",
                        "Deployment",
                        rel_to_output(out_dir, deployment),
                        [system_name, "Deployment"],
                    )
                )

        sequences_raw = system_raw.get("sequences", [])
        if sequences_raw is None:
            sequences_raw = []
        if not isinstance(sequences_raw, list):
            die(f"{ctx}.sequences must be an array when present")
        seq_ids: set[str] = set()
        for sidx, seq_raw in enumerate(sequences_raw):
            sctx = f"{ctx}.sequences[{sidx}]"
            if not isinstance(seq_raw, dict):
                die(f"{sctx} must be an object")
            seq_id = _require_manifest_str(seq_raw, "id", sctx)
            seq_name = _require_manifest_str(seq_raw, "name", sctx)
            seq_diagram_str = _require_manifest_str(seq_raw, "diagram", sctx)
            validate_duplicate(seq_ids, seq_id, f"{ctx} sequence id")
            seq_diagram = optional_file(seq_diagram_str, sctx + ".diagram", manifest_dir)
            if seq_diagram:
                system_views.append(
                    make_view(
                        f"{system_id}__sequence__{seq_id}",
                        f"Sequence: {seq_name}",
                        rel_to_output(out_dir, seq_diagram),
                        [system_name, "Sequences", seq_name],
                    )
                )

        containers_raw = system_raw.get("containers", [])
        if containers_raw is None:
            containers_raw = []
        if not isinstance(containers_raw, list):
            die(f"{ctx}.containers must be an array when present")
        container_ids: set[str] = set()
        containers: list[dict] = []
        for cidx, container_raw in enumerate(containers_raw):
            cctx = f"{ctx}.containers[{cidx}]"
            if not isinstance(container_raw, dict):
                die(f"{cctx} must be an object")
            container_id = _require_manifest_str(container_raw, "id", cctx)
            container_name = _require_manifest_str(container_raw, "name", cctx)
            validate_duplicate(container_ids, container_id, f"{ctx} container id")

            components_raw = container_raw.get("components", [])
            if not isinstance(components_raw, list):
                die(f"{cctx}.components must be an array")
            component_ids: set[str] = set()
            component_views: list[dict] = []
            for pidx, comp_raw in enumerate(components_raw):
                pctx = f"{cctx}.components[{pidx}]"
                if not isinstance(comp_raw, dict):
                    die(f"{pctx} must be an object")
                comp_id = _require_manifest_str(comp_raw, "id", pctx)
                comp_name = _require_manifest_str(comp_raw, "name", pctx)
                comp_diagram_str = _require_manifest_str(comp_raw, "diagram", pctx)
                validate_duplicate(component_ids, comp_id, f"{cctx} component id")
                comp_diagram = require_file(comp_diagram_str, pctx + ".diagram", manifest_dir)
                component_views.append(
                    make_view(
                        f"{system_id}__container__{container_id}__component__{comp_id}",
                        comp_name,
                        rel_to_output(out_dir, comp_diagram),
                        [system_name, container_name, comp_name],
                    )
                )

            containers.append(
                {
                    "id": container_id,
                    "name": container_name,
                    "components": component_views,
                }
            )

        systems.append(
            {
                "id": system_id,
                "name": system_name,
                "system_views": system_views,
                "containers": containers,
            }
        )

    model = {
        "schemaVersion": 1,
        "title": title,
        "compact": False,
        "landscape": (
            make_view("landscape", "Landscape", rel_to_output(out_dir, landscape_path), ["Landscape"])
            if landscape_path
            else None
        ),
        "systems": systems,
    }

    views = flatten_views(model)
    if not views:
        die("manifest does not define any renderable diagrams")
    model["defaultViewId"] = (model["landscape"]["id"] if model.get("landscape") else views[0]["id"])
    model["compact"] = should_compact(model)
    return model, str(title), summary


def parse_args(argv: list[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(prog=SELF_NAME, description="Build an interactive C4 explorer HTML page.")
    p.add_argument("--out", required=True, help="Output HTML file")
    p.add_argument("--title", help="Explorer title (required in flat mode; optional override in manifest mode)")
    p.add_argument("--readme", help="README path for summary extraction")
    p.add_argument("--manifest", help="JSON manifest for hierarchical explorer mode")
    p.add_argument("--landscape", help="Landscape diagram image")
    p.add_argument("--context", help="Context diagram image (flat mode)")
    p.add_argument("--container", help="Container diagram image (flat mode)")
    p.add_argument("--component", help="Component diagram image (flat mode)")
    p.add_argument("--deployment", help="Deployment diagram image (flat mode)")
    p.add_argument("--sequence", help="Sequence diagram image (flat mode)")
    return p.parse_args(argv)


def ensure_mode_args(args: argparse.Namespace) -> None:
    flat_flags = [args.landscape, args.context, args.container, args.component, args.deployment, args.sequence]
    has_flat = any(v is not None for v in flat_flags)

    if args.manifest and has_flat:
        die("--manifest cannot be combined with flat diagram flags (--landscape/--context/--container/--component/--deployment/--sequence)")
    if not args.manifest and not (args.context and args.container and args.component):
        die("flat mode requires --context, --container, and --component")


def render_html(template_path: Path, title: str, system_description: str, model: dict, out_path: Path) -> None:
    if not template_path.is_file():
        die(f"template not found: {template_path}")
    template = read_text(template_path)
    html_out = template
    html_out = html_out.replace("__TITLE__", html.escape(title, quote=True))
    html_out = html_out.replace("__SYSTEM_DESCRIPTION__", html.escape(system_description, quote=True))
    html_out = html_out.replace("__EXPLORER_MODEL_JSON__", json_for_html(model))
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(html_out, encoding="utf-8")


def main() -> None:
    args = parse_args(CLI_ARGS)
    ensure_mode_args(args)

    cwd = Path.cwd()
    out_path = resolve_input(args.out, cwd)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_dir = out_path.parent.resolve()

    if args.manifest:
        model, title, system_description = build_manifest_model(args, out_dir, cwd)
    else:
        model, title, system_description = build_flat_model(args, out_dir, cwd)

    render_html(TEMPLATE_PATH, title, system_description, model, out_path)
    print(f"{SELF_NAME}: wrote explorer HTML: {out_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
PY
