#!/usr/bin/env bash
# pack-check.sh — structural check of a software kind pack (_software plus one kind).
#
# EMITS OBSERVATIONS, NOT A VERDICT (CLAUDE.md, "Helpers in .claude/scripts/").
# One line per problem; the exit code only says whether any line was printed.
#
# Usage: bash .claude/scripts/pack-check.sh <service|application|generic>
#   PACK_KINDS_DIR overrides the kinds directory (default: ../kinds beside this script).
#
# Output: PACK: <name> OK   or   PACK: <name> PROBLEM <reason>   (one per problem)
# Exit code: 1 if any PROBLEM line was printed, else 0.
#
# bash 3.2 and BWK awk safe, no Python.

set -u
LC_ALL=C
export LC_ALL

HERE="$(cd "$(dirname "$0")" && pwd)"
KINDS="${PACK_KINDS_DIR:-$HERE/../kinds}"
KIND="${1:-}"
BASE=_software
STAGES="Concept|Design|Technical Setup|Build|Harden|Release"
GAME_RE='gdd|genre|engine|playtest|art bible|\.claude/agents|game'

problems=0
problem() { printf 'PACK: %s PROBLEM %s\n' "$1" "$2"; problems=$((problems + 1)); }

case "$KIND" in
  service|application|generic) ;;
  *) echo "usage: pack-check.sh <service|application|generic>" >&2; exit 2 ;;
esac

# yval <file> <key>: the raw value after "key:", comment stripped
yval() { sed -n "s/^$2:[[:space:]]*//p" "$1" | head -n 1 | sed 's/[[:space:]]*#.*$//; s/[[:space:]]*$//'; }
# ylist <file> <key>: items of an inline [a, b] list, one per line
ylist() { yval "$1" "$2" | sed 's/^\[//; s/\]$//' | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$'; }
# fm <file> <key>: value of a frontmatter key
fm() { awk -v k="$2" 'NR==1&&$0!="---"{exit} NR>1&&$0=="---"{exit} NR>1{i=index($0,":"); if(i>0&&substr($0,1,i-1)==k){v=substr($0,i+1); sub(/^[ \t]+/,"",v); sub(/[ \t]+$/,"",v); print v; exit}}' "$1"; }

# fm_has <file> <key>: exit 0 if the frontmatter has the key, even with an empty value
fm_has() { awk -v k="$2" 'NR==1&&$0!="---"{exit 1} NR>1&&$0=="---"{exit 1} NR>1{i=index($0,":"); if(i>0&&substr($0,1,i-1)==k) exit 0}' "$1"; }

# check_gate <pack> <file>: five fields and a known stage per row; prints labels to stdout via LABELS file
check_gate() {
  awk -F'\t' -v stages="$STAGES" 'BEGIN{n=split(stages,s,"|"); for(i=1;i<=n;i++) ok[s[i]]=1}
    /^#/||/^[ \t]*$/{next}
    { if (NF!=5) {printf "%s:%d has %d fields, expected 5\n", FILENAME, NR, NF; next}
      if (!($1 in ok)) printf "%s:%d unknown stage \"%s\"\n", FILENAME, NR, $1 }' "$2"
}

check_pack() { # <pack dir name>
  name="$1"; dir="$KINDS/$name"; py="$dir/pack.yaml"
  if [ ! -f "$py" ]; then problem "$name" "pack.yaml not found at $py"; return; fi
  pn=$(yval "$py" name)
  [ "$pn" = "$name" ] || problem "$name" "pack.yaml name is \"$pn\", directory is \"$name\""
  ext=$(yval "$py" extends)
  if [ "$name" != "$BASE" ]; then
    if [ "$ext" != "$BASE" ] || [ ! -f "$KINDS/$ext/pack.yaml" ]; then
      problem "$name" "extends \"$ext\" does not resolve to $BASE"
    fi
  fi

  for a in $(ylist "$py" agents); do
    f="$dir/agents/$a.md"
    if [ ! -f "$f" ]; then problem "$name" "listed agent file missing: agents/$a.md"; continue; fi
    for k in description mode; do
      [ -n "$(fm "$f" $k)" ] || problem "$name" "agents/$a.md has no $k"
    done
    case "$(fm "$f" model-role)" in plan|review) ;; *) problem "$name" "agents/$a.md model-role \"$(fm "$f" model-role)\" not in plan|review" ;; esac
    case "$(fm "$f" access)" in read|design-write) ;; *) problem "$name" "agents/$a.md access \"$(fm "$f" access)\" not in read|design-write" ;; esac
    # writes: optional, space-separated paths or globs, each under docs/design/, design-write agents only
    if fm_has "$f" writes; then
      w=$(fm "$f" writes)
      [ "$(fm "$f" access)" = design-write ] || problem "$name" "agents/$a.md has writes but access is not design-write"
      [ -n "$w" ] || problem "$name" "agents/$a.md writes is empty"
      set -f
      for p in $w; do
        case "$p" in
          *..*) problem "$name" "agents/$a.md writes \"$p\" contains .." ;;
          docs/design/?*) ;;
          *) problem "$name" "agents/$a.md writes \"$p\" is not under docs/design/" ;;
        esac
      done
      set +f
    fi
  done

  for s in $(ylist "$py" skills); do
    f="$dir/skills/$s/SKILL.md"
    if [ ! -f "$f" ]; then problem "$name" "listed skill file missing: skills/$s/SKILL.md"; continue; fi
    sn=$(fm "$f" name)
    [ "$sn" = "$s" ] || problem "$name" "skills/$s/SKILL.md name \"$sn\" differs from directory \"$s\""
    [ -n "$(fm "$f" description)" ] || problem "$name" "skills/$s/SKILL.md has no description"
  done

  # prompts: {orchestrator: prompts/x.md, ...}
  for p in $(yval "$py" prompts | sed 's/^{//; s/}$//' | tr ',' '\n' | sed 's/^[^:]*:[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$'); do
    [ -f "$dir/$p" ] || problem "$name" "listed prompt file missing: $p"
  done
  for s in $(ylist "$py" scripts); do
    [ -f "$dir/scripts/$s" ] || problem "$name" "listed script file missing: scripts/$s"
  done
  g=$(yval "$py" gate)
  if [ -n "$g" ] && [ "$g" != "null" ]; then
    if [ ! -f "$dir/$g" ]; then problem "$name" "listed gate file missing: $g"
    else
      check_gate "$name" "$dir/$g" > "$TMP/gate.out"
      while IFS= read -r l; do problem "$name" "gate row: $l"; done < "$TMP/gate.out"
    fi
  fi

  hits=$(grep -rniE "$GAME_RE" "$dir" 2>/dev/null | head -n 5)
  if [ -n "$hits" ]; then
    printf '%s\n' "$hits" | while IFS= read -r l; do printf 'PACK: %s PROBLEM game vocabulary: %s\n' "$name" "$l"; done
    problems=$((problems + 1))
  fi
}

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

before=$problems
check_pack "$BASE"
[ "$problems" = "$before" ] && printf 'PACK: %s OK\n' "$BASE"
before=$problems
check_pack "$KIND"

# extras must not repeat a base row's label
if [ -f "$KINDS/$KIND/gate.tsv" ] && [ -f "$KINDS/$BASE/gate.tsv" ]; then
  awk -F'\t' '/^#/||/^[ \t]*$/{next} {print $5}' "$KINDS/$BASE/gate.tsv" > "$TMP/base.labels"
  awk -F'\t' '/^#/||/^[ \t]*$/{next} NF==5{print $5}' "$KINDS/$KIND/gate.tsv" | while IFS= read -r l; do
    grep -Fxq -- "$l" "$TMP/base.labels" && printf 'duplicate of base label: %s\n' "$l"
  done > "$TMP/dup.out"
  while IFS= read -r l; do problem "$KIND" "gate row $l"; done < "$TMP/dup.out"
fi
[ "$problems" = "$before" ] && printf 'PACK: %s OK\n' "$KIND"

[ "$problems" = 0 ]
