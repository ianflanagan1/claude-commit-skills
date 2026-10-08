## Message style

Each message describes one set of changes: the one named above, not unstaged edits, earlier conversation or what was meant to change.

Match the recent commits first. Look for:
- a prefix scheme: Conventional Commits (`feat(api): ...`), ticket keys (`ABC-123 ...`), component tags (`nginx: ...`), gitmoji
- mood and capitalisation of subjects
- typical subject length

Pick the scope and type the repo actually uses. If there are fewer than about five commits or no consistent pattern, use the defaults:
- Subject: imperative mood (`Add`, `Fix`, `Remove`), capitalised, no trailing period, 50 characters or fewer, never more than 72.
- Body: only when the subject can't carry the change. Blank line after the subject, wrapped at 72. Say what changed and why, not how; the diff shows how.

## Message content

- Describe the change as a whole. Name the behaviour, not the file list.
- State why only when the diff, the code comments, the user's note or the messages of commits being reworked show it. Never invent a reason, a ticket number or a test result.
- Mention breaking changes, removals and migrations; use the repo's convention for them (`!`, `BREAKING CHANGE:` footer) if it has one.
- Unrelated changes in one commit: still write one message that covers them, subject on the main change, the rest as body bullets.
- First commit (the repo has no commits yet): the message is exactly `Initialise`, with no body, whatever it adds.
- Don't add `Co-Authored-By` or other trailers unless the recent commits use them.
