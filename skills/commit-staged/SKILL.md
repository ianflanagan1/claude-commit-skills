---
name: commit-staged
description: Commit the currently staged changes with a message that matches the repository's existing style. Prints only the new commit's hash and subject.
disable-model-invocation: true
---

# Commit staged

Commit what is staged **now**, with one message written for exactly that: not for unstaged edits, earlier conversation or what you meant to change.

## Gather

Any text after the skill's name is a note from the user about this change, such as a ticket or a reason the diff doesn't show. Use it, but it doesn't override anything below.

Output of `scripts/staged-context.sh`, captured when this skill loaded:

```
!`sh "${CLAUDE_SKILL_DIR}/scripts/staged-context.sh" 2>&1; echo "exit $?"`
```

If the block above still shows the command rather than its output, run `sh <directory containing this file>/scripts/staged-context.sh` from the repo root yourself. Never reuse a result from an earlier run.

- Exit 1: reply `➖ Nothing staged.` and stop. Make no tool calls.
- Exit 2: reply `⚠️ ` followed by its error, and stop.
- `(a merge is in progress)`: reply `🚧 Merge in progress; not committing.` and stop.
- Truncated diff: run `git diff --cached -- <path>` for files you need to understand. Don't read unstaged or unrelated files.

## Message

Write the message by this guide:

!`cat "${CLAUDE_SKILL_DIR}/references/commit-message-guide.md"`

If the line above still shows the command, read `references/commit-message-guide.md` next to this file before writing.

## Commit

Commit only the index, in one Bash call, passing the message on stdin with a quoted heredoc so nothing in it is expanded:

```sh
git commit --quiet -F - <<'EOF'
<message>
EOF
git log -1 --format='%h %s'
```

- Don't stage, unstage or stash anything, and don't pass `-a`, paths, `--amend` or `--no-gpg-sign`.
- Never pass `--no-verify` (or `-n`), and never skip hooks any other way (`core.hooksPath`, `HUSKY=0`, `SKIP=`).
- If the commit fails (a hook rejects it, signing fails, nothing left to commit), don't retry, work around it or edit any files. Reply with a line `❌ Commit failed.`, then git's error and the message you tried in a fenced `text` code block, then a short line on what caused the failure and the fix you propose. Don't apply the fix.

## Output

On success, reply with a line `✅ Committed.`, then the `git log` line in one fenced `text` code block, and nothing else.
