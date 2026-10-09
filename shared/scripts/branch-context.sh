#!/bin/sh
# branch-context: print what is needed to rework a branch's commits and uncommitted work.
#
# The base is where the work started: the merge-base with the given branch or commit; else, on
# the default branch or the configured base's own branch, with its upstream, so only unpushed
# commits are reworked; else with the branch set in git config commit-message.base; else with
# the nearest other branch, local or remote-tracking, leaving the fewest commits since the base.
#
# Usage: branch-context.sh [-n lines] [base]
#   -n lines  maximum diff lines to print (default: 3000)
#   base      the branch or commit the work started from
#
# Prints, in order:
#   - the base and how it was found
#   - warnings: an operation in progress, merge commits, commits by others, pushed commits,
#     committed files that are now ignored
#   - recent commit subjects before the base, so messages can match the repository's style
#   - the branch's commits since the base, oldest first, with full messages and file stats
#   - the status of every changed and untracked file
#   - the diff of every file changed since the base, committed or not, with changed lines
#     numbered as stage-lines.sh numbers them once the index is reset to the base, without
#     lockfiles and minified files, truncated after a line limit
#
# Exit status: 0 printed, 1 nothing to rework, 2 usage error, not a git work tree or no base.

set -eu

usage() {
    sed -n '9,11p' "$0" | sed 's/^# \{0,1\}//'
}

max=3000
while getopts 'n:h' opt; do
    case $opt in
        n) max=$OPTARG ;;
        h) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done
shift $((OPTIND - 1))
[ $# -le 1 ] || { usage >&2; exit 2; }
case $max in
    '' | *[!0-9]*) usage >&2; exit 2 ;;
esac

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo 'Not a git work tree' >&2; exit 2; }
head=$(git rev-parse -q --verify HEAD) || { echo 'No commits yet; use the commit skill' >&2; exit 2; }
cur=$(git symbolic-ref -q --short HEAD || true)

tmp=$(mktemp -d "${TMPDIR:-/tmp}/branch-context.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

# The default branch: origin's HEAD, else a local main or master.
default=$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)
default=${default#origin/}
if [ -z "$default" ]; then
    for b in main master; do
        if git show-ref -q --verify "refs/heads/$b"; then default=$b; break; fi
    done
fi

# The configured base, and the branch it names, without its remote.
configured=$(git config commit-message.base || true)
own=$configured
! git show-ref -q --verify "refs/remotes/$configured" || own=${configured#*/}

if [ $# -eq 1 ]; then
    git rev-parse -q --verify "$1^{commit}" >/dev/null || { echo "Not a commit: $1" >&2; exit 2; }
    base=$(git merge-base HEAD "$1") || { echo "No history in common with $1" >&2; exit 2; }
    how="$1 (given)"
elif [ -n "$cur" ] && { [ "$cur" = "$default" ] || [ "$cur" = "$own" ]; }; then
    upstream=$(git rev-parse -q --abbrev-ref '@{upstream}' 2>/dev/null) ||
        { echo "On $cur with no upstream; pass the base to rework from" >&2; exit 2; }
    base=$(git merge-base HEAD "$upstream")
    how="$upstream (upstream of $cur: unpushed commits only)"
elif [ -n "$configured" ]; then
    git rev-parse -q --verify "$configured^{commit}" >/dev/null ||
        { echo "commit-message.base is $configured, which is not a commit" >&2; exit 2; }
    base=$(git merge-base HEAD "$configured") || { echo "No history in common with $configured" >&2; exit 2; }
    how="$configured (from git config commit-message.base)"
else
    # Candidates as "commits since the merge-base, merge-base, name". Skip this branch, its
    # remote copies and branches built on top of it.
    git for-each-ref --format='%(refname) %(objectname)' refs/heads refs/remotes |
        while read -r ref tip; do
            case $ref in
                refs/heads/"$cur" | refs/remotes/*/"$cur" | refs/remotes/*/HEAD) continue ;;
            esac
            mb=$(git merge-base HEAD "$ref" 2>/dev/null) || continue
            [ "$mb" != "$head" ] || [ "$tip" = "$head" ] || continue
            printf '%s %s %s\n' "$(git rev-list --count "$mb..HEAD")" "$mb" "${ref#refs/*/}"
        done | sort -n >"$tmp/cand"
    [ -s "$tmp/cand" ] || { echo 'No other branch to find the base from; pass the base to rework from' >&2; exit 2; }
    read -r n base _ <"$tmp/cand"
    awk -v n="$n" '$1 == n' "$tmp/cand" >"$tmp/near"
    if [ "$(cut -d' ' -f2 "$tmp/near" | sort -u | wc -l)" -gt 1 ]; then
        echo "Several branches are equally near: $(cut -d' ' -f3 "$tmp/near" | tr '\n' ' ')" >&2
        echo 'Pass the base to rework from' >&2
        exit 2
    fi
    how="$(cut -d' ' -f3 "$tmp/near" | tr '\n' ',' | sed 's/,$//; s/,/, /g') (guessed: nearest branch)"
fi

dirty=$(git status --porcelain --untracked-files=all)
[ "$base" != "$head" ] || [ -n "$dirty" ] || { echo 'Nothing to rework' >&2; exit 1; }
total=$(git rev-list --count "$base..HEAD")

echo '## Base'
echo "$(git rev-parse --short "$base") $how"
echo "$total commits since the base"

echo
echo '## Warnings'
{
    git_dir=$(git rev-parse --git-dir)
    [ ! -f "$git_dir/MERGE_HEAD" ] || echo '(a merge is in progress)'
    [ ! -d "$git_dir/rebase-merge" ] && [ ! -d "$git_dir/rebase-apply" ] || echo '(a rebase is in progress)'
    [ ! -f "$git_dir/CHERRY_PICK_HEAD" ] || echo '(a cherry-pick is in progress)'
    [ ! -f "$git_dir/REVERT_HEAD" ] || echo '(a revert is in progress)'
    merges=$(git rev-list --count --merges "$base..HEAD")
    [ "$merges" -eq 0 ] || echo "(merge commits: $merges)"
    me=$(git config user.email || true)
    git log --format=%ae "$base..HEAD" | sort | uniq -c | while read -r count email; do
        [ "$email" = "$me" ] || echo "(not yours: $count commits by $email)"
    done
    unpushed=$(git rev-list --count HEAD "^$base" --not --remotes)
    [ "$unpushed" -eq "$total" ] || echo "(pushed: $((total - unpushed)) of $total commits are on a remote)"
    git diff --name-only --no-renames "$base" HEAD | git check-ignore --no-index --stdin |
        sed 's/^/(ignored but committed: /; s/$/)/' || true
} >"$tmp/warn"
if [ -s "$tmp/warn" ]; then cat "$tmp/warn"; else echo '(none)'; fi

echo
echo '## Recent commits before the base'
git log -n 15 --no-merges --format='%s' "$base"

echo
echo '## Commits since the base, oldest first'
if [ "$total" -eq 0 ]; then
    echo '(none)'
else
    git log --reverse --no-color --stat=200 --format='### %h%n%B' "$base..HEAD"
fi

echo
echo '## Status (X = staged, Y = unstaged, ?? = untracked)'
if [ -n "$dirty" ]; then git status --short --untracked-files=all; else echo '(clean)'; fi

echo
echo '## Changes since the base, changed lines numbered (lockfiles and minified files omitted)'
here=$(cd "$(dirname "$0")" && pwd)
cd "$(git rev-parse --show-toplevel)"
{ git diff "$base" --name-only --no-renames; git ls-files --others --exclude-standard; } | sort -u |
    while IFS= read -r f; do
        case $f in
            *.lock | *-lock.json | *-lock.yaml | *go.sum | *.min.js | *.min.css | *.map)
                echo "(omitted: $f)"; continue ;;
        esac
        sh "$here/stage-lines.sh" -b "$base" "$f" 2>&1 || true
    done |
    awk -v max="$max" '
        NR <= max
        END { if (NR > max) printf "[truncated: %d of %d lines shown; once the index is reset to the base, run stage-lines.sh <path> for the rest]\n", max, NR }'
