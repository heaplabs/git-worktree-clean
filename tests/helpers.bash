# Shared fixtures: a bare "remote" whose path contains github.com (so forge checks can
# run against the fake gh in tests/bin), a clone of it under $ROOT, and helpers to
# create worktrees in every state the tool must recognise.

BIN="${WT_BIN:-$BATS_TEST_DIRNAME/../git-wt-clean}"

setup() {
  T="$BATS_TEST_TMPDIR"
  export HOME="$T/home" GIT_CONFIG_NOSYSTEM=1 NO_COLOR=1
  mkdir -p "$HOME"
  git config --global user.name "Test"
  git config --global user.email "test@example.com"
  git config --global init.defaultBranch main
  git config --global advice.detachedHead false
  export PATH="$BATS_TEST_DIRNAME/bin:$PATH"
  export FAKE_GH_PRS="$T/prs.json"
  echo '[]' >"$FAKE_GH_PRS"

  REMOTE="$T/github.com/acme/app.git"
  ROOT="$T/projects"
  REPO="$ROOT/app"
  mkdir -p "$ROOT" "$(dirname "$REMOTE")"
  git init -q --bare "$REMOTE"
  git clone -q "$REMOTE" "$REPO" 2>/dev/null
  echo "base" >"$REPO/file.txt"
  printf 'node_modules/\n.env\n' >"$REPO/.gitignore"
  git -C "$REPO" add -A
  git -C "$REPO" commit -qm "initial"
  git -C "$REPO" push -q origin main
  git -C "$REPO" remote set-head origin main
}

# Run the tool under test (WT_BASH lets CI force /bin/bash 3.2 on macOS).
wt() { "${WT_BASH:-bash}" "$BIN" "$@"; }

# new_wt NAME: a worktree ../NAME on a new branch NAME, with one commit on its own file.
new_wt() {
  git -C "$REPO" worktree add -q -b "$1" "$ROOT/$1" origin/main
  echo "$1" >"$ROOT/$1/$1.txt"
  git -C "$ROOT/$1" add -A
  git -C "$ROOT/$1" commit -qm "work on $1"
}
push_wt() { git -C "$ROOT/$1" push -q origin "$1" 2>/dev/null; }

# Land a branch on origin/main in the given style, from the main clone.
land() {  # land BRANCH merge|squash|rebase
  git -C "$REPO" checkout -q main
  git -C "$REPO" pull -q origin main
  case "$2" in
    merge)  git -C "$REPO" merge -q --no-ff -m "merge $1" "$1" ;;
    squash) git -C "$REPO" merge -q --squash "$1" && git -C "$REPO" commit -qm "squash $1" ;;
    rebase) git -C "$REPO" cherry-pick "$(git -C "$REPO" merge-base main "$1")..$1" >/dev/null ;;
  esac
  git -C "$REPO" push -q origin main
}

# Another commit on main after landing, touching the given file.
main_edits() {
  git -C "$REPO" checkout -q main
  echo "later edit" >>"$REPO/$1"
  git -C "$REPO" commit -qam "later edit to $1"
  git -C "$REPO" push -q origin main
}

# JSON status for one worktree, by folder name.
status_of() {  # status_of NAME [extra args...]
  local name="$1"; shift
  wt status --json "$@" "$ROOT" | jq -c --arg n "$name" 'select(.path | endswith("/" + $n))'
}
verdict_of() { status_of "$@" | jq -r .verdict; }
reason_of()  { status_of "$@" | jq -r .reason; }

# fake_prs '[{"number":7,"headRefName":"x","headRefOid":"...","state":"MERGED","isCrossRepository":false}]'
fake_prs() { printf '%s\n' "$1" >"$FAKE_GH_PRS"; }
head_of() { git -C "$ROOT/$1" rev-parse HEAD; }
