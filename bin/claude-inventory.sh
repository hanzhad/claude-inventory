#!/bin/sh
#
# Inventory of the prompt artefacts on this machine — one block per skill or
# agent: where it is, the numbers, and only the questions those numbers raise.
#
# It is not a check and it never fails, and the name is apart from the
# `check-*.sh` shape on purpose: those are pass/fail, they run on every push,
# and a broken YAML frontmatter belongs to one of those. What is here has no
# verdict — 700 lines is not an error, zero invocations is not an error, and
# both are worth looking at once a month.
#
# A table was the first shape and it was the wrong one: a table compares
# artefacts against each other, and nothing is ever decided that way. One is
# kept or removed on its own.
#
# Modes:
#
#   (default) DIR         every artefact in DIR, one block each
#   --list DIR            one path per line — only the ones the owner authored
#   --list --all-origins DIR   every path, for the description-collision pass
#   --row PATH            the block for one artefact
#   --legend              what the columns mean and what each check affects
#
# `--legend` lives here rather than in the agent that prints it because the text
# is the same for every file in a report: printed per file it is duplication the
# audit itself would flag, and kept in a prompt it would be reworded slightly on
# every pass.
#
# Kind is detected from the layout: a directory of `<name>/SKILL.md` is skills,
# a directory of flat `*.md` is agents. `--kind skill|agent` overrides it.
# Detection beats a required flag because the flag is the thing a caller gets
# wrong.
#
# Provenance is declared, not detected: a vendored artefact sits in the same
# directory with the same owner and the same permissions as an authored one.
# It goes in the one frontmatter key the published skill spec allows for it,
#
#     metadata:
#       origin: upstream
#
# and no key means authored here. `--list` filters on it so that whatever fans
# out over the result cannot forget the rule; the default mode still prints
# vendored artefacts, because a skill you merely installed and never open is
# exactly the one worth seeing the size of.
#
# The columns:
#
#   prose   Body size in prose lines: frontmatter, fenced blocks, indented
#           commands and blank lines all excluded, so the number means "text
#           that could be shorter". No threshold — the two questions it feeds
#           are asked about every file, at the bottom, because a file being
#           short is not a reason to skip them.
#   desc    Description length. It sits in context for every session whether or
#           not the artefact is ever used, which is the one cost that never
#           goes away. No threshold either, for the same reason.
#   cat     Category words in the description — any, whenever, always, more
#           than N steps. Naming a category rather than a moment is the shape
#           that made epic-orchestrator fire on everything. Not a verdict.
#   wtu     Skills only: has when_to_use. Literal phrases the owner types beat
#           a paraphrase of the description.
#   tools   Agents only: the allowlist. Absent means it inherits everything,
#           including write access, which is how an agent that promises to
#           change nothing changes something.
#   calls   Invocations across a month of transcripts. Skills are counted in
#           both shapes the transcript uses — `"skill":"name"` when the model
#           reached for it and `<command-name>/name` when the owner typed it —
#           because counting only the first reports zero for every skill built
#           to be invoked by hand. Agents use `"subagent_type":"name"`. Zero,
#           while installed, is the strongest single signal here.

set -eu

TRANSCRIPTS="$HOME/.claude/projects"
CATEGORY_WORDS='any |anything|whenever|always|every time|all cases|more than [0-9]|любая|любой|всегда|более [0-9]|каждый раз'
DIVIDER="────────────────────────────────────────────────────────────────────"
KIND=""

# Prose only: no frontmatter, no fenced block, no indented command, no blank
# line. The raw line count promised "text you could shorten" and did not mean
# it — a verbatim prompt an agent has to paste, and a page of example commands,
# are both incompressible and both counted.
prose_lines() {
  awk '
    NR==1 && $0=="---" {fm=1; next}
    fm && $0=="---"    {fm=0; next}
    fm                 {next}
    /^```/             {fence = !fence; next}
    fence              {next}
    /^[ \t][ \t][ \t][ \t]/ {next}
    /^[ \t]*$/         {next}
                       {n++}
    END {print n+0}
  ' "$1"
}

frontmatter() {
  awk 'NR==1 && $0=="---"{f=1;next} f && $0=="---"{exit} f' "$1"
}

origin_of() {
  awk 'NR==1 && $0=="---"{f=1;next} f && $0=="---"{exit}
       f && /^metadata:/{m=1;next}
       f && m && /^[^ \t]/{m=0}
       f && m && /^[ \t]+origin:/{gsub(/^[ \t]+origin:[ \t]*/,"");gsub(/["\x27]/,"");print;exit}' "$1"
}

# skills live at <dir>/<name>/SKILL.md, agents are flat <dir>/<name>.md
detect_kind() {
  for f in "$1"/*/SKILL.md; do [ -f "$f" ] && { echo skill; return; }; done
  for f in "$1"/*.md; do
    [ -f "$f" ] || continue
    case "$(basename "$f")" in README.md) continue ;; esac
    echo agent; return
  done
  echo skill
}

kind_of_path() {
  case "$1" in
    */SKILL.md) echo skill ;;
    *.md) echo agent ;;
    *) echo skill ;;
  esac
}

paths_in() {
  dir="$1"; kind="$2"
  if [ "$kind" = skill ]; then
    for s in "$dir"/*/; do
      [ -f "$s/SKILL.md" ] || continue
      printf '%s\n' "${s%/}/SKILL.md"
    done
  else
    for f in "$dir"/*.md; do
      [ -f "$f" ] || continue
      case "$(basename "$f")" in README.md) continue ;; esac
      printf '%s\n' "$f"
    done
  fi
}

# A blank line before the first note, so the numbers and the reading start
# apart. Printed once, on whichever note fires first.
note_gap() {
  if [ "$gap" = pending ]; then echo; gap=done; fi
}

block() {
  file="$1"
  gap=pending
  kind=$(kind_of_path "$file")
  if [ "$kind" = skill ]; then
    name=$(basename "$(dirname "$file")")
    # Two shapes, and a skill built for manual use only ever produces the
    # second: the Skill tool records `"skill":"name"`, while typing /name
    # records `<command-name>/name`.
    grep_key="\"skill\":\"$name\""
    slash_key="<command-name>/$name<"
  else
    name=$(basename "$file" .md)
    grep_key="\"subagent_type\":\"$name\""
    slash_key=""
  fi

  lines=$(prose_lines "$file")
  fm=$(frontmatter "$file")
  desc=$(printf '%s\n' "$fm" | sed -n 's/^description:[[:space:]]*//p' | head -1)
  desclen=$(printf '%s' "$desc" | wc -c | tr -d ' ')
  cat_hits=$(printf '%s' "$desc" | grep -icE "$CATEGORY_WORDS" || true)
  origin=$(origin_of "$file"); [ -n "$origin" ] || origin=mine

  if [ -d "$TRANSCRIPTS" ]; then
    calls=$(grep -rhoF "$grep_key" "$TRANSCRIPTS" --include='*.jsonl' 2>/dev/null | wc -l | tr -d ' ')
    if [ -n "$slash_key" ]; then
      slash=$(grep -rhoF "$slash_key" "$TRANSCRIPTS" --include='*.jsonl' 2>/dev/null | wc -l | tr -d ' ')
      calls=$((calls + slash))
    fi
  else
    calls='-'
  fi

  echo
  echo "$DIVIDER"
  echo "$file"
  echo "$name ($kind)"

  if [ "$kind" = skill ]; then
    case "$fm" in *when_to_use:*|*when-to-use:*|*whenToUse:*) wtu=yes ;; *) wtu=no ;; esac
    echo "  prose $lines   desc $desclen   cat $cat_hits   wtu $wtu   calls $calls   origin $origin"
  else
    tools=$(printf '%s\n' "$fm" | sed -n 's/^tools:[[:space:]]*//p' | head -1)
    [ -n "$tools" ] || tools='(inherits everything)'
    echo "  prose $lines   desc $desclen   cat $cat_hits   calls $calls   origin $origin"
    echo "  tools: $tools"
  fi

  if [ "$origin" != mine ]; then
    note_gap
    echo "  - You did not write this one. The choice here is keep or turn off,"
    echo "    not edit: an update overwrites whatever you changed."
  fi
  if [ "$cat_hits" -gt 0 ]; then
    note_gap
    if [ "$origin" = mine ]; then
      echo "  - Broad words in the description. If the rule has to hold all the"
      echo "    time, it belongs in CLAUDE.md or an output style, not here."
    else
      echo "  - Broad words in a description you do not own. It sits in context"
      echo "    and competes with yours. You cannot narrow it; you can turn it off."
    fi
  fi
  if [ "$kind" = skill ] && [ "$wtu" = no ] && [ "$origin" = mine ]; then
    note_gap
    echo "  - No when_to_use. Add the phrases you actually type, or confirm"
    echo "    that it is only ever called by name."
  fi
  if [ "$kind" = agent ]; then
    note_gap
    case "$tools" in
      '(inherits everything)')
        echo "  - No tools list. It inherits everything, writing included, so"
        echo "    \"changes nothing\" rests on wording, not on permissions." ;;
      *Write*|*Edit*)
        echo "  - tools includes write access. Confirm it is needed: the list is"
        echo "    the only thing that makes \"edits nothing\" checkable." ;;
    esac
  fi
  if [ "$calls" = 0 ]; then
    note_gap
    echo "  - Zero calls in a month of transcripts. Delete it, or find out why"
    echo "    nothing reaches it. If it is new, come back in a month."
  fi
  case "$fm" in
    *description:*) : ;;
    *) note_gap; echo "  - No description. It will never be offered." ;;
  esac
}

# --kind may appear anywhere in the arguments
args=""
for a in "$@"; do
  case "$a" in
    --kind=*) KIND=${a#--kind=} ;;
    *) args="$args
$a" ;;
  esac
done
set -- $(printf '%s' "$args" | sed '/^$/d')

case "${1:-}" in
  --legend)
    cat <<'EOF'
**What this report is.** A look at the skills and agents installed on this
machine. Nothing here is a verdict: no file is called good or bad, nothing is
ranked, and nothing is changed.

**The numbers, per file.**

- `prose` — lines of text you could shorten. The settings at the top, code
  blocks and indented commands are not counted.
- `desc` — length of the description. It sits in every session whether the file
  is ever used or not, so it is the one cost that never goes away.
- `cat` — how many broad words the description uses (any, always, whenever).
  Broad words are what make a file fire when you did not ask for it.
- `wtu` — whether a skill lists the phrases you actually type.
- `tools` — what an agent may use. Nothing listed means everything, writing
  included.
- `calls` — times it was used across a month of your transcripts. Zero, while
  installed, is the loudest thing in this report.

**The settings check, skills only.** The few lines at the top of the file are
parsed, and their names compared against Anthropic's published list. It never
looks at the instructions below them, so "valid" is not praise for the file. A
name that is not on the list still works here — it only stops the file from
being packaged for publishing. A parse error is different and worth fixing: the
file loads anyway, which means the value may be read differently than you meant
it.

**The reading, per file.** One subagent reads one file and reports text that
changes nothing while the file runs, facts belonging to one project, whether the
description names a moment or a whole kind of work, and anything said twice.
"Nothing to report" is the normal answer, not a failure to look.
EOF
    ;;
  --row)
    target="${2:?--row needs a path}"
    case "$target" in
      *.md) file="$target" ;;
      *) file="${target%/}/SKILL.md" ;;
    esac
    [ -f "$file" ] || { echo "no such file: $file" >&2; exit 1; }
    block "$file"
    ;;
  --list)
    ALL=no
    if [ "${2:-}" = "--all-origins" ]; then ALL=yes; shift; fi
    DIR="${2:-$HOME/.claude/skills}"
    kind="${KIND:-$(detect_kind "$DIR")}"
    paths_in "$DIR" "$kind" | while read -r f; do
      if [ "$ALL" = no ]; then
        o=$(origin_of "$f")
        [ -z "$o" ] || [ "$o" = mine ] || continue
      fi
      printf '%s\n' "$f"
    done
    ;;
  *)
    DIR="${1:-$HOME/.claude/skills}"
    kind="${KIND:-$(detect_kind "$DIR")}"
    paths_in "$DIR" "$kind" | while read -r f; do
      block "$f"
    done
    cat <<'EOF'

Not in the numbers. Ask these about every file above, whatever its size:

  - Cross out every prose line a capable model would have written anyway. Less
    than half left means the file should be rewritten as that half.
  - Does the description name a moment, or a kind of work? A kind of work makes
    it fire on everything.
  - The body holds rules, each with at most one short reason. Proof goes in the
    README: measurements, history, what would make you delete the file.
  - Does anything here belong to one project? A checkout path, a base branch,
    one repo's CI setup. Those age into wrong answers the day that project ends.
  - Is the file needed at all? The only way to tell is to run the same task
    with it and without it. Once per file, not once per commit.
EOF
    ;;
esac
