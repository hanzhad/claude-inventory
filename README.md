# claude-inventory

Two files that tell you which of your Claude Code skills and agents are worth
keeping. It counts, it reads, and it decides nothing — the file that gets
deleted is your call, because the two questions that actually decide (would a
capable model have written this anyway, does this rule have to hold
unconditionally) are not mechanical.

- `bin/claude-inventory.sh` — per skill and per agent: body size in prose
  lines, description length, category words in the description, whether it
  declares `when_to_use`, an agent's tool allowlist, and how many times the
  thing was actually invoked across a month of your transcripts.
- `agents/claude-audit.md` — the agent that runs it, then sends one subagent per
  file to read that file and report four things back in a fixed shape.

## Install

```sh
mkdir -p ~/.claude/agents ~/.claude/bin && curl -fsSL -o ~/.claude/agents/claude-audit.md https://raw.githubusercontent.com/hanzhad/claude-inventory/main/agents/claude-audit.md && curl -fsSL -o ~/.claude/bin/claude-inventory.sh https://raw.githubusercontent.com/hanzhad/claude-inventory/main/bin/claude-inventory.sh && chmod +x ~/.claude/bin/claude-inventory.sh
```

Updating is the same command again. Uninstalling is `rm` on those two paths.

If either path is already a symlink — say you keep your `~/.claude` in a
repository of your own — delete the link first. `curl -o` follows it and writes
through into whatever it points at.

## Use

Ask for it by name in Claude Code: "run claude-audit". It is deliberately hard
to trigger by accident; its own description tells the model not to pick it
because a directory looks crowded.

The script is also usable on its own, and it is the same output the agent
prints:

```sh
~/.claude/bin/claude-inventory.sh                       # every skill in ~/.claude/skills
~/.claude/bin/claude-inventory.sh ~/.claude/agents      # agents instead
~/.claude/bin/claude-inventory.sh --row ~/.claude/skills/foo/SKILL.md
```

## What it will not do

- Write anything. The agent has no write tools, so "changes nothing" is
  checkable rather than promised.
- Rank your files or tell you which to delete.
- Run an eval. It prints the command and stops, because an eval set generated
  in the same run measures the agent's own guess at what should trigger the
  skill, not what you would type.
- Audit plugin skills. An update overwrites edits there, so the choice is keep
  or disable, not edit. They are listed, under a heading saying they were not
  audited, because an enabled plugin's descriptions sit in your context and
  compete with your own skills.

## The one convention it needs from you

A skill you installed from someone else looks exactly like one you wrote: same
directory, same permissions. So provenance is declared, not detected. Add this
to the frontmatter of anything you did not write:

```yaml
metadata:
  origin: upstream
```

`metadata` is a key the published skill spec allows, so this does not break
anything. Files marked that way still get counted and printed — a skill you
installed and never opened is exactly the one worth seeing the size of — but
they are not sent to a subagent for reading, and the report says why.

Note that an installer which regenerates its own skill file will erase the
marker on its next update. That is worth knowing rather than working around.

## Optional: the spec check

If `python3`, `pyyaml`, and Anthropic's `skill-creator` plugin are all present,
each skill also gets checked against the published frontmatter spec. Missing
any of them, the agent stops and asks once, and every block then carries "spec
not checked". It will not install anything on its own.

## Requirements

Claude Code, and `/bin/sh`. No Node, no dependencies. The invocation counts are
read from `~/.claude/projects/**/*.jsonl`, which is your local transcript
history and never leaves the machine.
