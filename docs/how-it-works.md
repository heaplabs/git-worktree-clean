# How git-worktree-clean decides

## Verdicts

The first rule that matches wins.

```
locked? ──────────────────────────────────── KEEP     (also when its folder is missing)
folder gone? ─────────────────────────────── PRUNE    (git forgets it; nothing is deleted)
in use / uncommitted changes /
ignored files that are not disposable? ───── KEEP
open pull request? ───────────────────────── KEEP
work provably in the default branch? ─────── REMOVE
PR merged or closed at this commit? ──────── REMOVE
commits that are on no remote? ───────────── KEEP
otherwise ────────────────────────────────── REVIEW   (never removed automatically)
```

"Work provably in the default branch" means one of:

- `HEAD` is already in the default branch (merge or fast-forward);
- every path the branch changed is identical in the default branch;
- the branch's combined diff equals one commit there (squash merge);
- each of its commits has an equivalent there (rebase merge).

These checks use plain git and work with any host. The pull-request check needs GitHub,
`gh` and `jq`; a pull request from a fork with the same branch name is ignored.

When a check cannot run (the fetch fails, GitHub does not answer), the answer is
REVIEW, never REMOVE: not being able to look is not the same as finding nothing.

## During `remove`

- Each worktree is checked again right before removal, including which processes have
  a folder open inside it. Anything that changed since the plan is skipped.
- git is never given `--force`, so git's own refusal (for example, a worktree with
  submodules) is a second safety net.
- Local branches are kept unless you pass `--delete-branches`.

## Disposable ignored files

`git worktree remove` deletes ignored files and git keeps no copy, so each one is checked.
These names are disposable by default, matching the file or any folder above it:

```
node_modules target dist build out .next .nuxt .svelte-kit .turbo .cache .parcel-cache
coverage __pycache__ .pytest_cache .mypy_cache .ruff_cache .venv venv .tox .gradle .bsp
.metals .bloop .idea .DS_Store *.pyc *.class
```

Add to them with `--add-disposable LIST` or the `worktree-clean.disposable` git config
setting (comma-separated, may be set more than once, global or per repository).
`--disposable LIST` replaces the defaults entirely. Only list files you would never
miss: anything matching is deleted with the worktree.

## What it does not check

- **Resources outside the folder**: a database, container or port created for a worktree
  is left behind.
- **Open files in an editor**: it sees processes whose current folder is inside the
  worktree, not an editor that only has a file open.
- **Stashes**: shared by all worktrees of a repository, so they are not lost.
- **Fork workflows**: it compares against your remote's default branch, so work merged
  upstream shows REVIEW until your fork is synced.

## Output details

- `UNPUSHED` counts commits on no remote branch. After a squash merge the remote branch
  is usually deleted, so a merged worktree can show a large number; `REASON` says why it
  is still safe.
- Only repositories with linked worktrees are fetched, and pull requests are listed once
  per repository, so a folder of dozens of repositories scans in seconds.
- Exit codes: `0` success or nothing to do, `1` a removal failed or was aborted,
  `2` bad usage, `3` missing dependency.
- Colour follows [`NO_COLOR`](https://no-color.org/); progress lines appear only on a
  terminal. Other options: `--no-forge` skips GitHub, `--help` lists everything.
