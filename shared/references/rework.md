## Rework

The branch's commits since the base, and any uncommitted work, are rebuilt into a new series on top of the base. Nothing before the base changes.

- Merge commits on the branch: reply `🚫 Not reworking: the branch has merge commits; rebase it onto its base first.` and stop.
- Commits by someone else: reply `🚫 Not reworking: the branch has commits by <emails>.` and stop. If the base looks wrong, because the branch seems to include commits that aren't its own, add that the user can pass the base after the skill's name, or set one for the repo with `git config commit-skills.base <branch>`.
- Read every commit's message and, with `git show <hash>`, its diff. The messages hold reasons, tickets and trailers that the final diff doesn't show.
- If the commits already fit the approach and there is no uncommitted work, reply `➖ Already well organised.` and stop. Make no changes.
- Plan the whole new series before changing anything. Uncommitted work can join the commit it belongs with (a fix to it, say) or become commits of its own.

Record the starting commit for the output, `git rev-parse --short HEAD`, then reset to the base:

```sh
git reset --quiet <base>
```

This moves the branch and the index back to the base and leaves the working tree, which already holds the final state, as it is. If the first commits on the branch stay exactly as they are, reset to the last of them instead, so they keep their hashes. The numbers in the Gather section count from the base, so they match the index after resetting to it; after resetting anywhere else, list a file again before using its numbers. `git reset <start>` undoes the whole run, leaving any uncommitted work unstaged.

A file the Warnings list as ignored but committed must be staged with `git add -f`, or it is dropped.

To stage a file as it was in one of the original commits, before a later commit changed it again (`<scripts>` is the `scripts` directory next to SKILL.md):

```sh
sh <scripts>/stage-lines.sh -r <hash> <path>        # list what that version changes, numbered
sh <scripts>/stage-lines.sh -r <hash> <path> all    # stage it whole, or pick lines
```

Carry ticket keys and trailers (`Signed-off-by`, `Co-authored-by`) from the original commits into the new commits that take their changes.
