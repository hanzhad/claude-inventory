# claude-inventory

## What it is

Two files that show you the state of your Claude Code skills and agents.

- `bin/claude-inventory.sh` — per skill and per agent: body size in prose lines,
  description length, category words in the description, whether it declares
  `when_to_use`, an agent's tool allowlist, and how many times the thing was
  actually invoked across a month of your transcripts.
- `agents/claude-audit.md` — the agent that runs the script, then sends one
  subagent per file to read that file and report back in a fixed shape: text
  that changes nothing at runtime, facts belonging to one project, whether the
  description names a moment or a whole category of work, and anything said
  twice.

## What it does not do

- **No verdict.** It never says a skill is bad or an agent should go. It points
  at things and stops; what gets deleted is your call.
- **No fixing.** The agent holds no write tools, so "changes nothing" is
  checkable rather than promised.
- **No ranking**, and no answer to "which of these should I delete first".
- **No evals.** It prints the command for one and stops: an eval set written in
  the same run measures its own guess at what should trigger the skill.
- **No plugin audits.** Plugin skills are listed, marked as not audited, because
  an enabled plugin's descriptions sit in your context next to yours. Editing
  them is pointless — an update overwrites it.

## Install

```sh
mkdir -p ~/.claude/agents ~/.claude/bin && curl -fsSL -o ~/.claude/agents/claude-audit.md https://raw.githubusercontent.com/hanzhad/claude-inventory/main/agents/claude-audit.md && curl -fsSL -o ~/.claude/bin/claude-inventory.sh https://raw.githubusercontent.com/hanzhad/claude-inventory/main/bin/claude-inventory.sh && chmod +x ~/.claude/bin/claude-inventory.sh
```

Update with the same command. Uninstall with `rm` on those two paths.

If either path is already a symlink — say you keep `~/.claude` in a repository
of your own — delete the link first: `curl -o` follows it and writes through into
whatever it points at.

## The agent

Ask for it by name.

| you say | it does |
| --- | --- |
| `run claude-audit` | asks which folder, unless only one of the usual ones exists |
| `run claude-audit on ~/.claude/skills` | every skill there |
| `run claude-audit on ~/.claude/agents` | every agent there |
| `run claude-audit on ~/.claude/skills/foo` | that one file, whoever wrote it |

Numbers are printed for every file. The reading subagent is spawned only for
files you wrote — see below — except when you name a single file, where it runs
regardless.

## The script

Usable on its own, and it is the same output the agent prints.

```sh
~/.claude/bin/claude-inventory.sh                        # every skill in ~/.claude/skills
~/.claude/bin/claude-inventory.sh ~/.claude/agents       # agents instead
~/.claude/bin/claude-inventory.sh --row ~/.claude/skills/foo/SKILL.md
~/.claude/bin/claude-inventory.sh --list ~/.claude/skills   # paths only, yours only
```

Skills or agents is detected from the layout; `--kind skill|agent` overrides it.

## The one convention it needs

A skill you installed looks exactly like one you wrote — same directory, same
permissions — so provenance has to be declared. In the frontmatter of anything
you did not write:

```yaml
metadata:
  origin: upstream
```

`metadata` is allowed by the published skill spec. Marked files are still
counted and printed; they are just not sent to a subagent for reading. An
installer that regenerates its own skill file will erase the marker on its next
update.

## Optional settings check

With `python3`, `pyyaml`, and Anthropic's `skill-creator` plugin present, the
settings at the top of every skill are also parsed and their names checked
against the published list. Without them the agent asks once, then each file
carries "settings not checked". It installs nothing on its own.

The venv it offers to build lives at `~/.claude/.claude-audit-venv` — about
14 MB, pyyaml plus a link to the python already installed, and `rm -rf` on that
one directory undoes it.

## Why it is shaped this way

None of this is derivable from the two files, and all of it came from a run that
went wrong.

**The agent's body holds rules; this file holds the arguments.** The audit
reports "text that changes nothing while it runs" as a finding, and it found
three such stretches in the agent itself — every one of them a reason added
after some earlier run. Kept in the body they are read on every invocation and
compete with the rules beside them. Read here, they are read when someone is
deciding whether to keep the file, which is the moment they matter.

**Quote first, line number after.** A number rots: anything inserted above moves
it, and a report is read later than it is written. The quote also carries what
the reader needs — the decision is "does this text stay in the body", and a
number cannot answer that. `Repeats` is the exception, because the two copies
read alike and only the numbers separate them.

**The quote may not include the rule it argues for.** Asked for a line range
with the first line quoted, a subagent returned `47-51` on a file whose 47 is a
heading and whose 49 opens with the rule — so the report read as "replace it
with this", and the rule was the part that had to stay.

**Print the validator's output, never its command line.** One run printed the
`quick_validate.py` invocation instead of running it. Four skills were reported
on, none were checked, and the report looked exactly as though they had been —
the previous run's genuine finding, a YAML parse error, silently disappeared.

**The legend is printed once, by the script.** The same explanation beside every
file is the duplication this tool exists to report. It lives in the script
rather than in the agent's prompt because a paragraph in a prompt gets reworded
slightly on every pass, and a legend that drifts is worse than none — the reader
learns the wording instead of the meaning.

**A validator's verdict is not a verdict on the file.** `Skill is valid!` means
the settings parse and their names are on the published list; it never looks at
the instructions below them. The other direction matters more: two skills here
are reported as having unexpected keys and both work, because Claude Code reads
keys the publishing spec does not list.

**Ask about the venv before spawning anything.** A silent skip is discovered
only in the finished report, and getting the check afterwards means running the
whole audit again, one subagent per file. A question at step 0 costs nothing.
The path must also outlive the run: built under a session scratchpad, it
vanished, and the same question was asked again of someone who had already
answered it and paid for the download.

**The list of files comes from `--list`, not from a glob in the prompt.** A rule
in the enumerator cannot be forgotten by whatever fans out over it. When step 3
listed folders itself, a `README.md` symlinked into `~/.claude/agents/` was
audited as an agent with no description and every tool inherited.

**One subagent per file, and it is told not to judge whether the file is
needed.** It is the thing under audit, so it would judge generously. It also
never sees the other files, which is why the overlap pass exists at all.

## Known limits

- The overlap pass reads `enabledPlugins` from `~/.claude/settings.json`. A
  session can have more plugin skills loaded than that key lists, so plugin
  overlaps are under-reported.
- `Repeats` is not exhaustive. Two runs over the same unchanged file returned
  two different sets of duplicates. Treat it as "there are repeats here", not as
  a list to work through.
- Whether a description names a moment or a whole category is a judgement, and
  two subagents split on the same file once. One vote is weak evidence.

## Requirements

Claude Code and `/bin/sh`. No Node, no dependencies. Invocation counts come from
`~/.claude/projects/**/*.jsonl` — your local transcripts, which never leave the
machine.
