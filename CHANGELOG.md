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
- `--add-disposable` and the `worktree-clean.disposable` git config setting extend the
  disposable list instead of replacing it.
- `remove --discard` offers, one at a time, worktrees kept only by local files (no open
  PR, nothing committed lost). It shows every file that would go, stashes tracked and
  untracked changes first, re-checks after the answer, and is never answered by `--yes`.
  `status` marks those rows `[--discard]` and `--json` adds `discardable`.
- The PR and UNPUSHED columns are now filled in for worktrees with uncommitted changes too.
- `install.sh` for macOS and Linux: dependency check with per-OS install hints, link or
  copy into `~/.local/bin` (or `--prefix`), PATH guidance per shell, `--uninstall`.

### Fixed before release (review by a teammate, 2026-09-29)

- The release workflow still named the pre-rename script `git-wt-clean`.
- The in-use check ran once at scan time; it now runs again right before each removal.
- A linked worktree that sorted first could become a repository's home folder, so
  removing it made later removals in that repository fail. The main worktree is used.
- A locked worktree whose folder was missing (unplugged drive) was listed as PRUNE.
- Rename detection hid the deleted old path from the "content already in target" check.
- Test suite: under bash 3.2 a failing `[[ ]]` in the middle of a bats test does not fail
  it. All 25 such assertions now end in `|| false`.
