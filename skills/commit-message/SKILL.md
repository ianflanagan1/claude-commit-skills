---
name: commit-message
description: Suggest a commit message for the currently staged changes, matching the repository's existing style. Prints only the message.
disable-model-invocation: true
---

# Commit message

Write one commit message for what is staged **now**, not for unstaged edits, earlier conversation or what you meant to change.

## Gather

Any text after the skill's name is a note from the user about this change, such as a ticket or a reason the diff doesn't show. Use it, but it doesn't override anything below.

Output of `scripts/staged-context.sh`, captured when this skill loaded:

```
!`sh "${CLAUDE_SKILL_DIR}/scripts/staged-context.sh" 2>&1; echo "exit $?"`
```

If the block above still shows the command rather than its output, run `sh <directory containing this file>/scripts/staged-context.sh` from the repo root yourself. Never reuse a result from an earlier run.

- Exit 1: reply `➖ Nothing staged.` and stop. Make no tool calls.
- Exit 2: reply `⚠️ ` followed by its error, and stop.
- Truncated diff: run `git diff --cached -- <path>` for files you need to understand. Don't read unstaged or unrelated files.

## Message

Write the message by this guide:

!`cat "${CLAUDE_SKILL_DIR}/references/commit-message-guide.md"`

If the line above still shows the command, read `references/commit-message-guide.md` next to this file before writing.

## Output

Reply with the message in one fenced `text` code block and nothing else: no preamble, explanation, alternatives, questions or sign-off. Don't run `git commit`.
