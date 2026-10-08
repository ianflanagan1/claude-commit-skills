---
name: commit
description: Split all uncommitted work into atomic commits that each leave the project working, write a message for each in the repository's style, and commit them. Prints only the new commits' hashes and subjects.
disable-model-invocation: true
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git show:*), Bash(git add:*), Bash(git rm:*), Bash(git reset:*), Bash(sh */scripts/stage-lines.sh:*), Bash(sh */scripts/history-versions.sh:*), Bash(git ls-files:*), Bash(git rev-parse:*), Bash(git commit:*), Bash(git worktree:*)
---

# Commit

Turn everything uncommitted (staged, unstaged and untracked) into a series of atomic commits, oldest idea first, each of which builds and works on its own.

## Gather

Any text after the skill's name is a note from the user about this work, such as a ticket, a reason the diff doesn't show or what to keep out. Use it, but it doesn't override anything below.

Output of `scripts/worktree-context.sh`, captured when this skill loaded:

```
!`sh "${CLAUDE_SKILL_DIR}/scripts/worktree-context.sh" 2>&1; echo "exit $?"`
```

If the block above still shows the command rather than its output, run `sh <directory containing this file>/scripts/worktree-context.sh` from the repo root yourself. Never reuse a result from an earlier run.

- Exit 1: reply `➖ Nothing to commit.` and stop. Make no tool calls.
- Exit 2: reply `⚠️ ` followed by its error, and stop.
- A merge, rebase, cherry-pick or revert in progress: reply `🚧 <Operation> in progress; not committing.` and stop.
- The changes section shows every changed and untracked text file with its changed lines numbered (see Stage). Truncated: run `sh <directory containing this file>/scripts/stage-lines.sh <path>` for the files you need.

## Rules

- **Never change the working tree**, except to fix a small mistake a commit hook catches (see Commit). Don't edit, check out, restore, stash or delete files. Every commit is built in the index; the files on disk stay as the user left them. When you finish, the working tree must be byte-for-byte what it was when you started, apart from those fixes.
- Never pass `--no-verify` (or `-n`), and never skip hooks any other way (`core.hooksPath`, `HUSKY=0`, `SKIP=`). Don't pass `--amend` or `--no-gpg-sign`, don't rewrite commits that existed before this run, and don't push.
- Before staging anything, record the starting commit for the output: `git rev-parse --short HEAD` (none if the repo has no commits yet). Because the working tree is never touched, `git reset <start>` undoes the whole run.

## Plan

1. Read the whole diff and every untracked file, then group the changes into commits. One commit is one reason to change: a feature, a fix, a refactor, a rename, a dependency bump, a formatting pass. Keep a change and the tests, docs and config it needs in the same commit.
2. Order the commits so each one works on its own: definitions before their callers, migrations before the code that reads the new schema, a renamed symbol together with every use of it. If two groups can't be separated without breaking the build, merge them.
3. Leave out what is not work: secrets (`.env`, keys), build output, logs, editor and OS files, scratch files. Don't commit them and don't edit `.gitignore`; report them in the output.
4. If the work is one coherent change, make one commit. Don't split for the sake of it.
5. If the repo has no commits yet, make one commit of everything except what step 3 leaves out, and skip Check.

## Stage

Stage with the scripts next to this file, never by writing patches or blobs by hand. Below, `<scripts>` is the `scripts` directory next to this file.

Start each commit from an index that matches `HEAD` (`git reset --quiet` before the first; after each commit it already does). Stage only that commit's changes:

- **Whole file:** `git add -- <path>`, or `git rm --cached --quiet -- <path>` for a deletion.
- **Some changed lines of a file**, down to single lines within a hunk:

  ```sh
  sh <scripts>/stage-lines.sh <path> 3-7 12        # stage changed lines 3 to 7 and 12
  sh <scripts>/stage-lines.sh <path>               # list the file's changed lines, numbered
  ```

  Numbers are the ones the Gather section shows. They count the file's changed lines against the index, so they stay valid until that file's index entry changes; after you stage part of a file, list it again before using its numbers. Pass all of a file's lines for one commit in one call. An unselected `+` line is left out and an unselected `-` line is kept, so pick a removed line and its replacement together. It refuses a partial deletion or a binary file; stage those whole. Never use `git add -p` or other interactive commands.
- **An earlier version of a file** (a line changed twice, where the first change belongs to an earlier commit):

  ```sh
  sh <scripts>/history-versions.sh <path>                 # saved versions since the last commit
  sh <scripts>/stage-lines.sh -f <snapshot> <path>        # list what it changes, numbered
  sh <scripts>/stage-lines.sh -f <snapshot> <path> all    # stage it whole, or pick lines
  ```

  `history-versions.sh` lists, oldest first, the distinct versions saved by Claude Code checkpoints and VS Code's local history since the file was last committed, each with its save time and lines added and removed against `HEAD`. `-f` stages from that file instead of the working tree; the file keeps its mode in the index. A later commit then stages the final version from the working tree as usual. If no saved version fits, you may write the intermediate file yourself in your scratchpad directory and stage it with `-f`, but only when the change splits cleanly into two coherent steps; otherwise keep both changes in one commit.

Check the result before committing: `git diff --cached --stat`, and `git diff --cached` where you staged part of a file, should show exactly this commit's changes.

## Check

A commit has to work on its own, but the working tree holds the final state, so tests run there prove nothing about earlier commits. For each commit:

- Read the staged result as a whole: every name it uses is defined in that commit or before it, imports resolve, and nothing refers to a later commit.
- If the repo has a quick build, type-check or test command (from `CLAUDE.md`, `package.json` scripts, a `Makefile` or similar) and it runs without network access or installed dependencies the checkout lacks, run it on the commit in a throwaway worktree in your scratchpad directory:

  ```sh
  git worktree add --quiet --detach <scratch dir> HEAD
  (cd <scratch dir> && <command>)
  git worktree remove --force <scratch dir>
  ```

  If it fails, `git reset --soft HEAD~1` to undo that commit (the changes return to the index) and replan. Don't fix code to make it pass.
- Skip the command if it is slow, needs services or would change anything outside the worktree, and say in the output which commits weren't run.

## Message

Write each commit's message for that commit's staged diff alone, by this guide:

!`cat "${CLAUDE_SKILL_DIR}/references/commit-message-guide.md"`

If the line above still shows the command, read `references/commit-message-guide.md` next to this file before writing.

## Commit

Commit each one in its own Bash call, passing the message on stdin with a quoted heredoc so nothing in it is expanded:

```sh
git commit --quiet -F - <<'EOF'
<message>
EOF
git log -1 --format='%h %s'
```

If a hook rejects a commit, nothing was committed and the index still holds that commit's changes. Read the hook's output, work out the cause, and:

- **Your split caused it** (a check fails because the commit uses something a later commit adds, or misses a file it needs): unstage with `git reset --quiet`, replan the remaining commits, and try again.
- **A simple mistake in the code** (a lint or format error, a typo, an unused import, a missing semicolon): fix it in the working tree, stage just the fix into this commit, and try again. These edits are the one exception to never changing the working tree; list them in the output.
- **Anything bigger** (a failing test that points at a real bug, a design problem, a fix that would change behaviour or touch more than a few lines): stop. Leave the remaining work uncommitted and report the error, what causes it and the fix you propose. Don't apply it.

If the same commit is rejected again after two attempts, stop and report as for anything bigger. If a commit fails for another reason (signing fails), don't retry or work around it: stop, leave the remaining work uncommitted, and report.

## Finish

After the last commit, `git status --short` should list only what you deliberately left out. If anything else remains, say so.

## Output

Start with one line: `✅ Committed.` if every commit was made, or `🛑 Stopped.` if you stopped before the work was all committed. Then one fenced `text` code block holding the new commits, oldest first (`git log --reverse --format='%h %s' <start>..HEAD`, or without the range if the repo had no commits). After it, a line with the undo command, `git reset <start>` (`Undo: none (first commit)` for a repo that had no commits), and, only if they apply, short lines for:
- files left uncommitted, and why
- files you edited to get past a hook, and what you changed (`git reset <start>` doesn't undo these)
- commits whose check wasn't run, or a failure, the message you tried and the fix you propose

Nothing else: no preamble, explanation of the grouping or sign-off.
