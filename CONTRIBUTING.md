# Contributing

## Tests

```bash
make test          # bats suite: real repos in temp folders, a fake gh in tests/bin
make test-bash32   # the same suite under /bin/bash (macOS's bash 3.2)
make lint          # shellcheck
```

Every safety check has a test that fails when the check is removed. Keep it that way:
when you add a check, break it on purpose and watch its test go red.

Under bash 3.2 a failing `[[ ]]` in the middle of a bats test does not fail the test, so
end those assertions with `|| false`.

## Pull requests

`main` is protected: one approving review, all three CI jobs green (Ubuntu, macOS bash 5,
macOS bash 3.2) and every review thread resolved. Review requests go to
`@heaplabs/repo-owners`. Only repo-owners can create release tags (`v*`), and tags cannot
be moved or deleted.

## Releasing

Set `VERSION` in `git-worktree-clean`, update `CHANGELOG.md`, merge, then push the tag
`v<VERSION>`. The release workflow checks the tag matches and attaches the script and its
checksum.
