#!/usr/bin/env bash
# kind-read.sh — what project.kind says for this project.
# It reads only; it writes nothing.
#
# EMITS OBSERVATIONS, NOT A VERDICT (CLAUDE.md, "Helpers in .claude/scripts/").
# A value outside the known eight is reported as invalid(<value>); what to do
# about it is the caller's call.
#
# Usage: bash .claude/scripts/kind-read.sh [project-root]
#   project-root   defaults to the current directory
#
# project.kind is locked to project.yaml (effects-map.md, "Locked to
# project.yaml"), so project.local.yaml is never read.
#
# Output:
#   KIND: <value>                  game when the key is absent
#   SOURCE: <project.yaml|default>
#   PACK: <yes|no>                 yes only for service, application, generic
#
# Exit code: 0 always.
#
# bash 3.2 and BWK awk safe, no Python.

set -u
LC_ALL=C
export LC_ALL

ROOT="${1:-.}"
HERE="$(cd "$(dirname "$0")" && pwd)"

value=""
if [ -f "$ROOT/project.yaml" ]; then
  value=$(YG_PATH=project.kind awk -f "$HERE/yaml-get.awk" "$ROOT/project.yaml" 2>/dev/null)
fi

if [ -z "$value" ]; then
  kind="game"; source="default"
else
  kind="$value"; source="project.yaml"
fi

pack=no
case "$kind" in
  game|tool|engine|mod|library) shown="$kind" ;;
  service|application|generic) shown="$kind"; pack=yes ;;
  *) shown="invalid($kind)" ;;
esac

printf 'KIND: %s\nSOURCE: %s\nPACK: %s\n' "$shown" "$source" "$pack"
exit 0
