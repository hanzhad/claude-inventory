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

## Optional spec check

With `python3`, `pyyaml`, and Anthropic's `skill-creator` plugin present, every
skill is also checked against the published frontmatter spec. Without them the
agent asks once, then each block carries "spec not checked". It installs nothing
on its own.

## Requirements

Claude Code and `/bin/sh`. No Node, no dependencies. Invocation counts come from
`~/.claude/projects/**/*.jsonl` — your local transcripts, which never leave the
machine.
