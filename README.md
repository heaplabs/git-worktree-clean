# git-worktree-clean

Find the git worktrees whose work is finished, and remove them without losing anything.

If you (or your coding agents) create a worktree per branch, they pile up: a folder
per merged pull request, each holding a full checkout and often a `node_modules`.
`git worktree prune` only forgets worktrees whose folder is already gone. Deciding
which *existing* folders are safe to delete means checking, for each one, whether
there is anything in it that exists nowhere else. That is what this tool does.

Example session (names shortened):

```
$ git-worktree-clean status ~/projects
git-worktree-clean status  ~/projects — disk: 12G free of 228G

VERDICT WORKTREE              BRANCH              CHANGES UNPUSHED PR          AGE_D   SIZE  REASON
REMOVE  app-wt-login          feat/login                0        2 #812 merged     3   421M  squash-merged into origin/main
KEEP    app-wt-billing        fix/billing               0        0 #815 open       0      -  PR #815 is open
KEEP    app-wt-spike          spike/cache               3        1 none            6      -  3 uncommitted change(s)
KEEP    api-wt-config         chore/config              0        0 #44 merged      1      -  ignored files would be lost: .env
REVIEW  api-wt-experiment     try/queue                 0        0 none           12   1.2M  pushed, but not merged into the default branch
PRUNE   /tmp/review-88        (detached)                -        - -               -      -  folder is gone

  keep 3 · review 1 (1.2M) · remove 1 · prune 1
  can be freed: 421M  ·  disk free: 12G of 228G  ·  6 worktrees in 9s

  next: git-worktree-clean remove

$ git-worktree-clean remove ~/projects
...
[1/2] REMOVED app-wt-login  421M in 3s  branch feat/login kept
[2/2] PRUNED  /tmp/review-88

Done in 14s: 2 done, 0 skipped, 0 failed
  freed:     421M  (sum of removed worktree sizes)
  disk free: 12G → 12.4G of 228G
```

## What it guarantees

A worktree is removed only when **all** of these hold at the moment of removal:

1. It is not locked (`git worktree lock`).
2. No process has its current folder inside it (a shell, an agent, a dev server).
3. `git status` shows no modified, staged or untracked files.
4. Every **ignored** file in it is *disposable*: a build or dependency folder such as
   `node_modules` or `target`. An ignored `.env`, local config or notes file makes it KEEP,
   because `git worktree remove` would delete it and git keeps no copy.
5. Its work is proven to exist elsewhere, in one of these ways:
   - its `HEAD` is already in the default branch (merge or fast-forward);
   - every file it changed is identical in the default branch;
   - its combined diff equals one commit on the default branch (squash merge);
   - each of its commits has an equivalent on the default branch (rebase merge);
   - or its GitHub pull request was merged or closed **at exactly this commit**
     (or a later one that contains it).
6. It has no open pull request.

Everything else is KEEP or REVIEW, and REVIEW is never removed automatically.
When a check *cannot run* — the fetch fails, GitHub does not answer — the answer is
REVIEW, never REMOVE: not being able to look is not the same as finding nothing.

`remove` re-checks each worktree immediately before removing it, so a worktree that
changed after the plan was shown is skipped. It never passes `--force` to git, so git's
own refusal (for example, a worktree with submodules) is a second line of defence.

### What it does not check

- **Open files in an editor.** It sees processes whose *current folder* is inside the
  worktree, not an editor that merely has a file open. Save your work first.
- **Stashes** are shared by all worktrees of a repository, so removing a worktree does
  not lose them; they are not inspected.
- **Pull requests on GitLab, Bitbucket and others** are not looked up. The plain-git
  checks in (5) work everywhere; only the pull-request shortcut needs GitHub.
- **Fork workflows.** It compares against the remote's default branch. If you push to a
  fork and merge upstream, your fork's `main` may not contain the work yet, so you will
  see REVIEW until the fork is synced.

## Install

Needs bash (3.2 or later, so the macOS default works), git 2.36 or later, and `df`/`du`.
Optional: [`gh`](https://cli.github.com/) (logged in) and `jq` for pull-request checks,
and `jq` for `--json`.

```bash
git clone git@github.com:heaplabs/git-worktree-clean.git ~/src/git-worktree-clean
ln -s ~/src/git-worktree-clean/git-worktree-clean ~/.local/bin/git-worktree-clean
```

`git pull` in the clone updates it. It is one file; read it before running it. Because the name starts with `git-`, it also
runs as `git worktree-clean`.

## Usage

```
git-worktree-clean status [options] [PATH...]
git-worktree-clean remove [options] [PATH...]
```

`PATH` is a repository, or a folder whose direct children are repositories. With no
path it uses the repository you are in, otherwise the children of the current folder.
Worktrees are found through git, so ones created elsewhere (`/tmp`, `.claude/worktrees`)
are listed too.

| Option | Effect |
|---|---|
| `--yes`, `-y` | remove without asking |
| `--delete-branches` | also delete the local branch of each removed worktree |
| `--no-fetch` | skip fetching; compare against the remote-tracking refs you already have |
| `--no-forge` | skip GitHub pull-request lookups |
| `--disposable LIST` | replace the list of ignored names that may be deleted |
| `--json` | `status` only: one JSON object per worktree |

Default disposable names: `node_modules target dist build out .next .nuxt .svelte-kit
.turbo .cache .parcel-cache coverage __pycache__ .pytest_cache .mypy_cache .ruff_cache
.venv venv .tox .gradle .bsp .metals .bloop .idea .DS_Store *.pyc *.class`. A name
matches the file or any folder above it.

Exit codes: `0` success or nothing to do, `1` a removal failed or was aborted,
`2` bad usage, `3` missing dependency.

Colour follows [`NO_COLOR`](https://no-color.org/); progress lines appear only on a terminal.

## How it decides

```
folder gone? ─────────────────────────────── PRUNE
locked / in use / uncommitted changes /
non-disposable ignored files? ────────────── KEEP
open pull request? ───────────────────────── KEEP
work provably in the default branch? ─────── REMOVE   (merged, same content, squash, rebase)
PR merged or closed at this commit? ──────── REMOVE
commits that are on no remote? ───────────── KEEP
otherwise ────────────────────────────────── REVIEW
```

Only repositories that have linked worktrees are fetched, and pull requests are listed
once per repository, so a folder of dozens of repositories scans in seconds.

## Development

```bash
make test          # bats suite; builds real repos in temp folders, fake gh in tests/bin
make test-bash32   # the same suite under /bin/bash (macOS)
make lint          # shellcheck
```

Each safety check has a test that fails when the check is removed; keep it that way
when adding one.

## License

MIT
