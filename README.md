# commit-message

Claude Code skills for commit messages. `/commit-message` suggests a message for whatever is staged when you run it and prints only the message. `/commit-staged` commits what is staged. `/commit` splits all uncommitted work into atomic commits.

## Why

Asking an agent to "write a commit message" usually gets a message for the whole conversation, the working tree, or a mix of both, wrapped in commentary. This skill looks only at the index, at the moment it runs, and copies the repository's existing style.

## What it does

1. Runs `shared/scripts/staged-context.sh`, which prints recent commit subjects, the staged file list and the staged diff. In Claude Code the script runs as the skill loads and its output goes straight into the prompt, so an empty index gets `➖ Nothing staged.` without any tool calls. Agents without that feature run the script themselves.
2. Matches the style of recent commits: Conventional Commits, ticket prefixes, component tags, subject length. With no clear pattern, it uses an imperative subject of 50 characters or fewer and a body wrapped at 72 only when needed. The first commit in a repo is always `Initialise`.
3. Replies with the message in a single code block. No explanation, no alternatives, no trailers the repo doesn't already use. It never commits.

```
/commit-message
```

The skills are meant to be run bare. Text typed after the name is treated as a note, for the rare case the diff can't show something, such as a ticket number or the reason for a change. Without one, the skill won't invent a reason that isn't in the diff.

## Committing staged changes

`/commit-staged` writes the message the same way and then commits the index with it, printing `✅ Committed.` and the new commit's short hash and subject. It commits exactly what is staged: it never stages or unstages files, amends or skips hooks. If the commit fails it prints `❌ Commit failed.`, git's error and the message it tried.

```
/commit-staged
```

## Committing everything

`/commit` takes all uncommitted work (staged, unstaged and untracked), splits it into atomic commits ordered so each one works on its own, writes a message for each and commits them. It prints `✅ Committed.` (or `🛑 Stopped.` if a hook or signing failure stops it part way), the new commits and the `git reset <start>` command that undoes the run. In a repo with no commits it makes a single `Initialise` commit instead of splitting.

```
/commit
```

It builds every commit in the index and never touches the working tree, using two scripts in `shared/scripts/`:
- `stage-lines.sh <path> [ids]` lists a file's changed lines with numbers, or stages only the numbered lines given, down to single lines within a hunk. With `-f <file>` it stages from another copy of the file, such as an earlier version.
- `history-versions.sh <path>` lists the earlier versions of a file saved since its last commit by Claude Code checkpoints and VS Code's local history. Staging one of them first lets a line changed twice go in at its earlier version. Both stores are undocumented, so this is best-effort.

Where it can, it checks each commit by running the repo's quick build or test command in a throwaway `git worktree`.

It leaves out secrets, build output and scratch files and lists them. Its `allowed-tools` pre-approve the git commands it uses while it runs.

## Tests

The scripts are tested with [shunit2](https://github.com/kward/shunit2), one `tests/<script>_test.sh` per script, each test named for the behaviour it asserts. With [devbox](https://www.jetify.com/devbox), nothing else is needed:

```sh
devbox run test    # shunit2 and shellcheck come from devbox.json
devbox run lint
```

Without devbox, install shunit2 (`brew install shunit2`, `apt install shunit2`) and run `sh tests/run.sh`. It finds shunit2 on `PATH`, or at `$SHUNIT2`. Every test runs in a throwaway repository with `HOME` redirected, so no real history is read.

## Problems

These skills don't report their own problems. If you use [`/improve-skill`](https://github.com/ianflanagan1/improve-skill), a rule in your global `CLAUDE.md` has Claude log problems with any skill, these included, for it to fix.

## Approaches

Each skill follows one approach to deciding what goes in a commit:

| Approach | Skills | Rule |
|---|---|---|
| Agnostic | `commit-message`, `commit-staged` | The user chose what goes in the commit; only the message is written. |
| Atomic | `commit` | Every commit holds one reason to change and leaves the project building and working, so it can be reverted, cherry-picked or bisected on its own. |

## Shared files

Rules and scripts the skills share live once in `shared/`, and each skill links to the files it uses from its own `references/` and `scripts/` folders. Every `references/*.md` file is inlined into the skill when it loads:

- `commit-message-guide.md`: how messages are written (every skill)
- `commit-safety.md`: how to run `git commit`, and never skipping hooks (every skill that commits)
- `staging.md`: building commits in the index without touching the working tree, and handling hook rejections (`commit`)
- `atomic-commits.md`: the atomic approach: grouping, ordering and checking each commit (`commit`)

The links make a skill's approach visible in its folder, and `tests/skills_test.sh` fails if a skill inlines the files of the wrong approach. When vendoring a skill, copy it with `cp -RL` so the links become real files.

## Script

`staged-context.sh` is POSIX `sh` and works without an agent.

```sh
sh shared/scripts/staged-context.sh          # print context for the staged changes
sh shared/scripts/staged-context.sh -n 500   # truncate the diff after 500 lines (default 2000)
```

Lockfiles and minified files are listed with their change counts but left out of the diff. It exits with 0 when it prints staged changes, 1 when nothing is staged, and 2 on a usage error or outside a git work tree.

## Claude Code

Install it as a plugin:

```
/plugin marketplace add ianflanagan1/commit-message
/plugin install commit-message@commit-message
```

Plugin skills are namespaced, so they're invoked as `/commit-message:commit-message`, `/commit-message:commit-staged` and `/commit-message:commit`.

You can vendor them instead, so collaborators get them with the repo: `cp -RL skills/<name> .claude/skills/` in your project, and each is invoked as `/<name>`. Don't install them both ways at once, or Claude will see each skill twice.

## Other agents

`skills/commit-message/SKILL.md` uses the [Agent Skills](https://agentskills.io) format, so other agents that support skills can load it. Copy it with `cp -RL skills/commit-message <your agent's skills directory>/` so the linked files become real files alongside `SKILL.md`. Slash-command arguments may behave differently, so just ask in plain language, for example "suggest a commit message for what's staged".
