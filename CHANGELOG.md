# Changelog

## 0.1.0 — unreleased

First release.

- `status` and `remove` commands; verdicts KEEP, REVIEW, REMOVE, PRUNE.
- Plain-git proof that a branch landed: ancestry, identical content, squash (patch-id),
  rebase (`git cherry`). Works with any git host.
- Optional GitHub pull-request checks through `gh`, ignoring fork PRs with the same
  branch name.
- Ignored files are inspected; only disposable build/dependency folders may be deleted.
- In-use detection through `/proc` on Linux or `lsof` elsewhere.
- Re-check immediately before each removal; never `--force`.
- Progress lines, sizes, space that can be freed and space actually freed.
- `--json`, `--no-fetch`, `--no-forge`, `--delete-branches`, `--disposable`.
- NUL-separated parsing, so paths with spaces and newlines are safe.
