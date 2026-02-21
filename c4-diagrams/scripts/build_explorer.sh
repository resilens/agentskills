#!/usr/bin/env bash
set -euo pipefail

SELF_NAME="${0##*/}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_PATH="${C4_EXPLORER_TEMPLATE:-$SKILL_ROOT/assets/explorer-template.html}"

die() {
  printf '%s: %s\n' "$SELF_NAME" "$*" >&2
  exit 1
}

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/build_explorer.sh \
    --out <html> \
    --title <title> \
    [--readme <path>] \
    [--landscape <img>] \
    --context <img> \
    --container <img> \
    --component <img> \
    [--deployment <img>] \
    [--sequence <img>]
EOF
}

require_file() {
  local label="$1"
  local path="$2"
  [[ -n "$path" ]] || die "--${label} is required"
  [[ -f "$path" ]] || die "--${label} file not found: $path"
}

html_escape() {
  local value="$1"
  value="${value//&/&amp;}"
  value="${value//</&lt;}"
  value="${value//>/&gt;}"
  value="${value//\"/&quot;}"
  value="${value//\'/&#39;}"
  printf '%s' "$value"
}

normalize_relpath() {
  local output_dir="$1"
  local target_path="$2"
  OUTPUT_DIR="$output_dir" TARGET_PATH="$target_path" perl -MCwd=abs_path -MFile::Spec -e '
    my $base = $ENV{OUTPUT_DIR};
    my $target = $ENV{TARGET_PATH};
    my $base_abs = abs_path($base) or die "cannot resolve output directory: $base\n";
    my $target_abs = abs_path($target) or die "cannot resolve target path: $target\n";
    print File::Spec->abs2rel($target_abs, $base_abs);
  '
}

extract_readme_summary() {
  local path="$1"
  [[ -f "$path" ]] || return 1

  README_PATH="$path" perl -e '
    use strict;
    use warnings;

    my $path = $ENV{README_PATH};
    open my $fh, "<", $path or exit 1;

    my $in_code = 0;
    my $in_frontmatter = 0;
    my $frontmatter_done = 0;
    my @paragraph;

    while (my $line = <$fh>) {
      chomp $line;

      if (!$frontmatter_done && $. == 1 && $line =~ /^---\s*$/) {
        $in_frontmatter = 1;
        next;
      }
      if ($in_frontmatter) {
        if ($line =~ /^---\s*$/) {
          $in_frontmatter = 0;
          $frontmatter_done = 1;
        }
        next;
      }

      if ($line =~ /^```/) {
        $in_code = !$in_code;
        next;
      }
      next if $in_code;

      next if $line =~ /^\s*#/;
      next if $line =~ /^\s*[-*]\s+/;
      next if $line =~ /^\s*\d+\.\s+/;
      next if $line =~ /^\s*>/;
      next if $line =~ /^\s*!\[/;
      next if $line =~ /^\s*\|/;

      if ($line =~ /^\s*$/) {
        last if @paragraph;
        next;
      }

      push @paragraph, $line;
    }

    exit 1 unless @paragraph;

    my $text = join(" ", @paragraph);
    $text =~ s/\[([^\]]+)\]\([^)]+\)/$1/g;
    $text =~ s/`([^`]+)`/$1/g;
    $text =~ s/\*\*([^*]+)\*\*/$1/g;
    $text =~ s/\*([^*]+)\*/$1/g;
    $text =~ s/\s+/ /g;
    $text =~ s/^\s+|\s+$//g;

    exit 1 unless $text ne q{};
    print $text;
  '
}

out_path=""
title=""
readme_path="README.md"
landscape_path=""
context_path=""
container_path=""
component_path=""
deployment_path=""
sequence_path=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)
      out_path="${2:-}"
      shift 2
      ;;
    --title)
      title="${2:-}"
      shift 2
      ;;
    --readme)
      readme_path="${2:-}"
      shift 2
      ;;
    --landscape)
      landscape_path="${2:-}"
      shift 2
      ;;
    --context)
      context_path="${2:-}"
      shift 2
      ;;
    --container)
      container_path="${2:-}"
      shift 2
      ;;
    --component)
      component_path="${2:-}"
      shift 2
      ;;
    --deployment)
      deployment_path="${2:-}"
      shift 2
      ;;
    --sequence)
      sequence_path="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      die "unknown argument: $1"
      ;;
  esac
done

[[ -f "$TEMPLATE_PATH" ]] || die "template not found: $TEMPLATE_PATH"
[[ -n "$out_path" ]] || die "--out is required"
[[ -n "$title" ]] || die "--title is required"

require_file "context" "$context_path"
require_file "container" "$container_path"
require_file "component" "$component_path"

if [[ -n "$landscape_path" && ! -f "$landscape_path" ]]; then
  printf '%s: warning: --landscape file not found, skipping: %s\n' "$SELF_NAME" "$landscape_path" >&2
  landscape_path=""
fi
if [[ -n "$deployment_path" && ! -f "$deployment_path" ]]; then
  printf '%s: warning: --deployment file not found, skipping: %s\n' "$SELF_NAME" "$deployment_path" >&2
  deployment_path=""
fi
if [[ -n "$sequence_path" && ! -f "$sequence_path" ]]; then
  printf '%s: warning: --sequence file not found, skipping: %s\n' "$SELF_NAME" "$sequence_path" >&2
  sequence_path=""
fi

mkdir -p "$(dirname -- "$out_path")"
out_dir="$(cd -- "$(dirname -- "$out_path")" && pwd)"

title_escaped="$(html_escape "$title")"
system_description="System overview not found in README.md."
if extracted_summary="$(extract_readme_summary "$readme_path" 2>/dev/null)"; then
  system_description="$extracted_summary"
else
  printf '%s: warning: could not extract summary from README, using fallback: %s\n' "$SELF_NAME" "$readme_path" >&2
fi
system_description_escaped="$(html_escape "$system_description")"

buttons_html=""
sections_html=""

add_view() {
  local key="$1"
  local label="$2"
  local input_path="$3"
  local open_attr="$4"
  local path_rel alt_escaped

  path_rel="$(normalize_relpath "$out_dir" "$input_path")"
  alt_escaped="$(html_escape "$label diagram")"

  buttons_html+=$'\n'"        <button type=\"button\" class=\"view-toggle\" data-target=\"view-${key}\">${label}</button>"
  sections_html+=$'\n'"        <details class=\"diagram-view\" id=\"view-${key}\"${open_attr}>"
  sections_html+=$'\n'"          <summary>${label}</summary>"
  sections_html+=$'\n'"          <div class=\"diagram-wrap\">"
  sections_html+=$'\n'"            <img src=\"${path_rel}\" alt=\"${alt_escaped}\" loading=\"lazy\" />"
  sections_html+=$'\n'"          </div>"
  sections_html+=$'\n'"        </details>"
}

if [[ -n "$landscape_path" ]]; then
  add_view "landscape" "Landscape" "$landscape_path" " open"
  add_view "context" "Context" "$context_path" ""
else
  add_view "context" "Context" "$context_path" " open"
fi
add_view "container" "Container" "$container_path" ""
add_view "component" "Component" "$component_path" ""
if [[ -n "$deployment_path" ]]; then
  add_view "deployment" "Deployment" "$deployment_path" ""
fi
if [[ -n "$sequence_path" ]]; then
  add_view "sequence" "Sequence" "$sequence_path" ""
fi

tmp_output="$(mktemp)"
cleanup() { rm -f "$tmp_output"; }
trap cleanup EXIT

while IFS= read -r line; do
  case "$line" in
    *__TITLE__*)
      printf '%s\n' "${line//__TITLE__/$title_escaped}" >> "$tmp_output"
      ;;
    *__SYSTEM_DESCRIPTION__*)
      printf '%s\n' "${line//__SYSTEM_DESCRIPTION__/$system_description_escaped}" >> "$tmp_output"
      ;;
    __BUTTONS__)
      printf '%s\n' "$buttons_html" >> "$tmp_output"
      ;;
    __SECTIONS__)
      printf '%s\n' "$sections_html" >> "$tmp_output"
      ;;
    *)
      printf '%s\n' "$line" >> "$tmp_output"
      ;;
  esac
done < "$TEMPLATE_PATH"

mv "$tmp_output" "$out_path"
trap - EXIT

printf '%s: wrote explorer HTML: %s\n' "$SELF_NAME" "$out_path" >&2
