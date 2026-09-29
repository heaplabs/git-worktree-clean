# git-worktree-clean

Find the git worktrees whose work is finished, and remove them without losing anything.

Worktrees pile up: one folder per branch, each a full checkout, often with a
`node_modules`. This tool checks every worktree for anything that exists nowhere else,
then removes only the ones that are safe.

```
$ git worktree-clean status ~/projects        # some columns trimmed
VERDICT WORKTREE         BRANCH        PR           SIZE  REASON
REMOVE  app-wt-login     feat/login    #812 merged  421M  squash-merged into origin/main
KEEP    app-wt-billing   fix/billing   #815 open       -  PR #815 is open
KEEP    api-wt-config    chore/config  #44 merged      -  ignored files would be lost: .env
REVIEW  api-wt-spike     try/queue     none         1.2M  pushed, but not merged into the default branch

  can be freed: 421M  ·  disk free: 12G of 228G
```

## Install

macOS or Linux, with git 2.36 or later.

```bash
git clone https://github.com/heaplabs/git-worktree-clean.git ~/.local/share/git-worktree-clean
~/.local/share/git-worktree-clean/install.sh
```

This links the command into `~/.local/bin` (no `sudo`) and tells you if anything is
missing or if that folder is not on your `PATH`. Update with
`git -C ~/.local/share/git-worktree-clean pull`.

**For every user on the machine**, copy it into a system folder instead. That folder is
usually owned by root, so this needs `sudo`. Copy rather than link: other users may not
be able to read your home folder.

```bash
sudo ~/.local/share/git-worktree-clean/install.sh --prefix /usr/local/bin --copy
```

After pulling an update, run the same command again.

Other installer options: `--uninstall` (with the same `--prefix`), `--help`.

For pull-request checks, also install [`gh`](https://cli.github.com/) (logged in) and `jq`.
Without them the tool still works, using plain git.

## Use

```bash
git worktree-clean status          # show every worktree and what would happen to it
git worktree-clean remove          # remove the safe ones, after you confirm
git worktree-clean status ~/code   # a folder of repositories instead of the current repo
```

| Option | Effect |
|---|---|
| `--yes` | remove without asking |
| `--delete-branches` | also delete each removed worktree's local branch |
| `--no-fetch` | don't fetch first (faster, uses what you last fetched) |
| `--add-disposable LIST` | more ignored files that may be deleted (see below) |
| `--json` | machine-readable `status` |

## Safe by default

A worktree is removed only if it has no uncommitted or untracked changes, nobody has a
shell open in it, it has no open PR, and its commits are already in the default branch
(merged, squashed or rebased) or its PR was merged at that exact commit. Anything it
cannot prove is shown as **REVIEW** and left alone. Every worktree is checked again just
before it is removed.

Ignored files count too: a leftover `.env` keeps a worktree, while build folders such as
`node_modules`, `target` and `dist` do not. To mark your own files as safe to lose, save
them once:

```bash
git config --global --add worktree-clean.disposable ".env.test.local,logs,reports"
```

The full rules, the default list and the known limits are in
[docs/how-it-works.md](docs/how-it-works.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). MIT licensed.
