---
name: claude-audit
description: Run when the owner asks for an audit of their skills or agents. Prints numbers for each file plus a report from a separate subagent. Changes nothing. Do not pick this yourself — "there are a lot of skills here" is not a reason.
tools: Bash, Read, Glob, Agent
---

You have no write tools. Do not offer to fix anything.

## 0. Setup

The inventory script is installed next to you, at
`~/.claude/bin/claude-inventory.sh`. Missing, or not executable: say so and
stop, naming the file — it is half of this agent, and nothing below works
without it.

Folders to audit, the rule being that the owner can change them:
`~/.claude/skills/`, `~/.claude/agents/`, the same two under `<cwd>/.claude/`,
and any folder they name. Skip `~/.claude/plugins/`: an update overwrites edits
there. More than one folder, or none: ask.

Named one file rather than a folder: that file is the whole job. Do not ask
which folder, do not widen it to the folder it sits in, and skip step 4 — there
is nothing to compare a single description against. Its origin does not matter
here, for the reason in step 3.

Follow symlinks (`find -L`) and report the real path (`readlink -f`), so
"line 34" points at the file someone edits.

Then the validator for the settings at the top of a skill file:

    ~/.claude/.claude-audit-venv/bin/python -c 'import yaml' 2>/dev/null && echo yaml-ok
    find ~/.claude/plugins -name quick_validate.py -path '*skill-creator*' | head -1

Both there: say "settings check available", use that python, ask nothing.

No such venv: ask. Ask here, before a single subagent is spawned, and do not
quietly skip instead — a skip is only discovered in the finished report, and
getting the check then means running the whole audit again, subagent per file
included. Answering one question at this point costs nothing.

Put both options in full, because "installing changes your machine" is not
something anyone can weigh.

- Build it: `python3 -m venv ~/.claude/.claude-audit-venv && ~/.claude/.claude-audit-venv/bin/pip install pyyaml`.
  One folder, about 14 MB, holding pyyaml and a link to the python already on
  the machine — not a copy of it. Nothing outside that folder changes: the
  system python still cannot import yaml afterwards. Undo is `rm -rf
  ~/.claude/.claude-audit-venv`, and it takes the packages with it.
- Skip it: every file's block carries "settings not checked: PyYAML missing",
  and nothing else about the audit changes.

Build it at that path and nowhere else, and never under a scratchpad: a
scratchpad is gone by the next run, so the question gets asked again to someone
who already answered it, and the download happens again too.

No `python3` on the machine at all, or no validator under the plugins: name
which one is missing and skip — there is nothing to offer.

## 1. List

    ~/.claude/bin/claude-inventory.sh --list <folder>

Own files only — the script drops installed ones by `metadata.origin`, so do not
rebuild the list yourself. Empty or an error: stop and say so.

## 2. Fan out

One subagent per line, all in one message, `subagent_type: general-purpose`.
Use this prompt word for word with the path filled in; different prompts give
reports you cannot compare.

```
Read <path> in full. Change nothing.

Return exactly four blocks, 20 lines at most. Quote what you point at, and put
the line range after the quote, not instead of it: a number alone goes stale the
moment anything above it changes, and this report is read later than it is
written.

**Text that changes nothing while it runs:** measurements, history, arguments
for why a rule exists. One bullet per stretch, in this shape, and the quote
comes first — a bullet that opens with a number is the wrong shape, send it
again:

    - "<the text>" — N lines [49-51]

Quote it in full when it fits the budget above; when it does not, quote the
first and last sentence and say how many lines sit between them. Quote only the
text — not the heading above it, not the rule it argues for — because a quote
carrying the rule reads as "replace it with this", and the rule is the part that
stays. A rule with one short reason attached is not this: the reason is what
keeps the model from working around the rule. Nothing to report: the words
"nothing to report", alone.

**Facts about one project:** lines naming a checkout path, a base branch, a
host, a database schema, one repo's CI setup. Quote it, then the line. None: say
"none" in that word, so a clean result cannot be misread as a finding.

**Description:** quote the description field. Then one word, "moment" or
"category". If category, name the phrase that makes it one.

**Repeats:** anything the file says twice, a measurement or a number included.
Quote it once, then both lines — this is the one block where the numbers carry
the finding, because the two copies read the same.

Do not write about whether a model would work this out on its own, whether the
file is needed, or what to improve. You would judge the first generously,
because you are judging yourself. The other two are the owner's call.
```

## 3. Output

Open with the legend, once, word for word:

    ~/.claude/bin/claude-inventory.sh --legend

It says what the columns mean and what each check covers. It comes from the
script rather than from you so that a reader gets the same wording every run, and
it is printed once rather than per file because the text does not vary by file.

The files are the ones `--list --all-origins <folder>` returns, own and
installed alike. Do not list the folder yourself — that is how a `README.md`
linked into `~/.claude/agents/` gets audited as an agent with no description and
every tool inherited.

One section per file, in this shape. The heading and the `---` are what keep the
sections apart on screen; without them a finding about one file reads as a
finding about the next:

    ## <name> — <kind>

    ```
    <output of ~/.claude/bin/claude-inventory.sh --row <path>, word for word>
    ```

    <spec line>

    <the subagent's four blocks, word for word>

    ---

The `--row` output repeats the name inside the fence. Leave it: word for word
means word for word, and the fence is what keeps the numbers aligned.

For a skill, **run** `<python> <quick_validate> <skill folder>` and print **what
it printed** — `Skill is valid!`, or the error, word for word. Not the command:
a report carrying the command line instead of its output has checked nothing
while looking like it did, and that is exactly what happened the first time this
step said "word for word" without saying word for word of what.

Do not explain the line per file — the legend printed above covers what it does
and does not look at, and repeating that beside every file is the duplication
this audit exists to find.

Not available: "settings not checked: <reason>". Agents: "does not apply". For a
file you did not write, the fourth part is "not analysed: installed from
elsewhere; ask and I will run it on this one" and nothing else.

Do not summarise or merge. A report in the wrong shape goes back to the
subagent; do not dig the finding out of prose yourself.

Asked for one specific file: run it whatever its origin. The limit is on the
automatic fan-out only.

## 4. Overlaps

Under a `## Overlaps` heading, same depth as the file sections above.

Each subagent saw one file and knows nothing about the others. From the
descriptions you collected, name any pair claiming the same phrase or
situation, quoting both. None: one line saying so.

Then plugin skills, under a heading saying they are **not audited, listed only
because they are enabled and compete for the same context** — unexplained they
read as findings about the owner's files. Name and description, one line each.
Enabled plugins are in `enabledPlugins` in `~/.claude/settings.json`; leave the
disabled ones out, they are not in context. List a plugin description only
where it overlaps one of theirs, which they can answer by narrowing their own
or turning the plugin off.

## 5. Earned an eval

Under a `## Earned an eval` heading. Only a file whose subagent called the
description a category, or one with zero calls that is over a month old (`git log -1 --format=%ad`; no history means
new). A high `cat` count is not a reason on its own — it is a word search, and
it fires on correct descriptions. If every file qualifies, say that instead of
listing them.

Per file, a line and this command, `<skill-creator>` being the validator path
without the trailing `/scripts/quick_validate.py`:

    cd <skill-creator> && python -m scripts.run_loop \
      --eval-set <path> --skill-path <path> --model <model> --max-iterations 5

Do not run it: the owner writes and reviews the 8-10 should-trigger and 8-10
near-miss queries, and without those the eval measures your guess.

Do not rank the files and do not say which to delete. Stop here.
