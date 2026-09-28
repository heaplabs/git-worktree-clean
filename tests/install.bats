#!/usr/bin/env bats
# install.sh: link/copy into a prefix, refuse foreign files, uninstall only its own.

INSTALL="$BATS_TEST_DIRNAME/../install.sh"
SCRIPT="$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)/git-worktree-clean"

setup() {
  P="$BATS_TEST_TMPDIR/bin"
  export SHELL=/bin/zsh
}
run_install() { "${WT_BASH:-bash}" "$INSTALL" "$@"; }

@test "links into the prefix by default, and the result runs" {
  run run_install --prefix "$P"
  [ "$status" -eq 0 ]
  [ -L "$P/git-worktree-clean" ]
  [ "$(cd "$P" && cd "$(dirname "$(readlink git-worktree-clean)")" && pwd -P)/git-worktree-clean" = "$SCRIPT" ]
  "$P/git-worktree-clean" --version | grep -q '^git-worktree-clean '
  [[ "$output" == *"Installed git-worktree-clean"* ]]
}

@test "--copy installs a regular file" {
  run run_install --prefix "$P" --copy
  [ "$status" -eq 0 ]
  [ -f "$P/git-worktree-clean" ] && [ ! -L "$P/git-worktree-clean" ]
  cmp -s "$P/git-worktree-clean" "$SCRIPT"
}

@test "re-running replaces its own install" {
  run_install --prefix "$P" --copy
  run run_install --prefix "$P"
  [ "$status" -eq 0 ]
  [ -L "$P/git-worktree-clean" ]
}

@test "refuses to replace a file it did not install" {
  mkdir -p "$P"; echo 'echo mine' >"$P/git-worktree-clean"
  run run_install --prefix "$P"
  [ "$status" -ne 0 ]
  [[ "$output" == *"was not installed by this script"* ]]
  [ "$(cat "$P/git-worktree-clean")" = "echo mine" ]
}

@test "--force replaces a foreign file" {
  mkdir -p "$P"; echo 'echo mine' >"$P/git-worktree-clean"
  run run_install --prefix "$P" --force
  [ "$status" -eq 0 ]
  [ -L "$P/git-worktree-clean" ]
}

@test "prints a PATH line for the user's shell when the prefix is not on PATH" {
  run run_install --prefix "$P"
  [[ "$output" == *"is not on your PATH"* ]]
  [[ "$output" == *"~/.zshrc"* ]]
  [[ "$output" == *"export PATH=\"$P:\$PATH\""* ]]
}

@test "no PATH hint when the prefix is already on PATH" {
  PATH="$P:$PATH" run run_install --prefix "$P"
  [[ "$output" != *"is not on your PATH"* ]]
  [[ "$output" == *"Try it"* ]]
}

@test "--uninstall removes its own install" {
  run_install --prefix "$P"
  run run_install --prefix "$P" --uninstall
  [ "$status" -eq 0 ]
  [ ! -e "$P/git-worktree-clean" ] && [ ! -L "$P/git-worktree-clean" ]
}

@test "--uninstall leaves a foreign file alone" {
  mkdir -p "$P"; echo 'echo mine' >"$P/git-worktree-clean"
  run run_install --prefix "$P" --uninstall
  [ "$status" -ne 0 ]
  [ -f "$P/git-worktree-clean" ]
}

@test "--uninstall with nothing installed succeeds" {
  run run_install --prefix "$P" --uninstall
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing installed"* ]]
}

@test "unwritable prefix fails with a clear message" {
  [ "$(id -u)" -ne 0 ] || skip "root can write anywhere"
  mkdir -p "$P"; chmod 555 "$P"
  run run_install --prefix "$P"
  chmod 755 "$P"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not writable"* ]]
}

@test "unknown option is a usage error" {
  run run_install --frobnicate
  [ "$status" -eq 2 ]
}
