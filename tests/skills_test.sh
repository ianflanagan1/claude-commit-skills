#!/bin/sh
# Structure of skills/: the shared files each skill inlines and links. Run with tests/run.sh.
#
# The shared references a skill inlines fix its approach to splitting work into commits:
#   agnostic        the user chose what goes in the commit   commit-message, commit-staged
#   atomic          atomic-commits.md                        commit, push, re-commit
#   review-ordered  its own Approach section                 re-commit-for-squash

# shellcheck source=tests/helpers.sh
. "$(dirname "$0")/helpers.sh"

# inlined skill: the references the skill's SKILL.md inlines, sorted, space-separated.
inlined() {
    # shellcheck disable=SC2016
    sed -n 's,^!`cat "${CLAUDE_SKILL_DIR}/references/\([^"]*\)"`$,\1,p' "$root/skills/$1/SKILL.md" |
        sort | tr '\n' ' ' | sed 's/ $//'
}

# procedure skill: the skill's SKILL.md from its first section up to its Output section, without
# a Push section: what it does to make its commits.
procedure() {
    awk '
        /^## Output/ { exit }
        /^## / { started = 1; skip = /^## Push/ }
        started && !skip
    ' "$root/skills/$1/SKILL.md"
}

# skills_inlining file: the skills whose SKILL.md inlines the reference, space-separated.
skills_inlining() {
    for s in "$root"/skills/*/; do
        s=$(basename "$s")
        case " $(inlined "$s") " in *" $1 "*) printf '%s ' "$s" ;; esac
    done | sed 's/ $//'
}

test_agnostic_skills_inline_no_approach() {
    assertEquals 'commit-message-guide.md' "$(inlined commit-message)"
    assertEquals 'commit-message-guide.md commit-safety.md' "$(inlined commit-staged)"
}

test_atomic_skills_inline_the_atomic_commit_rules() {
    assertEquals 'commit push re-commit' "$(skills_inlining atomic-commits.md)"
    assertEquals 'atomic-commits.md commit-message-guide.md commit-safety.md staging.md' "$(inlined commit)"
    assertEquals "$(inlined commit)" "$(inlined push)"
    assertEquals 'atomic-commits.md commit-message-guide.md commit-safety.md rework.md staging.md' "$(inlined re-commit)"
}

test_push_commits_exactly_as_commit_does() {
    assertEquals "$(procedure commit)" "$(procedure push)"
}

test_push_has_a_push_section_and_commit_does_not() {
    assertContains "$(cat "$root/skills/push/SKILL.md")" '## Push'
    assertNotContains "$(cat "$root/skills/commit/SKILL.md")" '## Push'
}

test_only_push_is_allowed_to_run_git_push() {
    assertEquals "$root/skills/push/SKILL.md" "$(grep -l '^allowed-tools:.*git push' "$root"/skills/*/SKILL.md)"
}

test_the_review_ordered_skill_states_its_own_approach() {
    assertEquals 'commit-message-guide.md commit-safety.md rework.md staging.md' "$(inlined re-commit-for-squash)"
    assertContains "$(cat "$root/skills/re-commit-for-squash/SKILL.md")" '## Approach: review-ordered commits'
}

test_no_skill_has_more_than_one_approach() {
    for skill in "$root"/skills/*/; do
        n=$(cat "$skill/SKILL.md" "$skill"/references/*.md | grep -c '^## Approach: ')
        assertTrue "$(basename "$skill") has $n approaches" "[ $n -le 1 ]"
    done
}

test_every_inlined_reference_and_script_exists_in_the_skill() {
    for skill in "$root"/skills/*/; do
        while IFS= read -r f; do
            assertTrue "$(basename "$skill")/$f" "[ -f '$skill/$f' ]"
        done <<EOF
$(sed -n 's,.*CLAUDE_SKILL_DIR}/\([a-z]*/[a-z.-]*\).*,\1,p' "$skill/SKILL.md")
EOF
    done
}

test_every_link_points_into_shared() {
    while IFS= read -r link; do
        case $(readlink "$link") in
            ../../../shared/*) ;;
            *) fail "$link points outside shared/" ;;
        esac
        assertTrue "$link resolves" "[ -e '$link' ]"
    done <<EOF
$(find "$root/skills" -type l)
EOF
}

test_every_shared_file_is_used_by_a_skill() {
    for f in "$root"/shared/*/*; do
        name=$(basename "$f")
        assertNotEquals "$name unused" '' "$(find "$root/skills" -type l -name "$name")"
    done
}

# shellcheck disable=SC1090
. "$(shunit2_path)"
