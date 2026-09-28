#!/usr/bin/env bash
# install.sh — put git-worktree-clean on your PATH (macOS and Linux).
#
#   ./install.sh                  link into ~/.local/bin (updates with `git pull`)
#   ./install.sh --copy           copy instead of link
#   ./install.sh --prefix DIR     install into DIR instead of ~/.local/bin
#   ./install.sh --uninstall      remove what this script installed
#
# Run it from a clone of the repository. It never uses sudo; pick a --prefix you can
# write to. It refuses to replace a file it did not install unless you pass --force.

set -euo pipefail

NAME=git-worktree-clean
SRC_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
SRC="$SRC_DIR/$NAME"
PREFIX="$HOME/.local/bin"
MODE="link"; ACTION="install"; FORCE="no"

say()  { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die()  { printf 'install.sh: %s\n' "$1" >&2; exit "${2:-1}"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --copy) MODE=copy ;;
    --link) MODE="link" ;;
    --prefix) [ $# -ge 2 ] || die "--prefix needs a folder" 2; PREFIX="$2"; shift ;;
    --prefix=*) PREFIX="${1#--prefix=}" ;;
    --uninstall) ACTION=uninstall ;;
    --force) FORCE=yes ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown option: $1 (see --help)" 2 ;;
  esac
  shift
done

TARGET="$PREFIX/$NAME"

# Where a symlink points, as an absolute path (readlink -f is not on older macOS).
link_dest() {
  local dest; dest=$(readlink "$1")
  (cd "$(dirname "$1")" && cd "$(dirname "$dest")" 2>/dev/null && printf '%s/%s' "$(pwd -P)" "$(basename "$dest")")
}

# Ours means: a link to this clone's script, or a copy of git-worktree-clean.
is_ours() {
  if [ -L "$TARGET" ]; then [ "$(link_dest "$TARGET")" = "$SRC" ]; return; fi
  [ -f "$TARGET" ] && head -n 3 "$TARGET" | grep -q "^# $NAME "
}

if [ "$ACTION" = uninstall ]; then
  if [ ! -e "$TARGET" ] && [ ! -L "$TARGET" ]; then say "Nothing installed at $TARGET."; exit 0; fi
  is_ours || [ "$FORCE" = yes ] || die "$TARGET was not installed by this script; pass --force to remove it anyway"
  rm -f -- "$TARGET"
  say "Removed $TARGET."
  exit 0
fi

# ---------------------------------------------------------------- checks

[ -f "$SRC" ] || die "run install.sh from a clone of the repository ($SRC not found)"

OS=$(uname -s)
pkg_hint() {  # pkg_hint PACKAGE: the install command for this machine
  case "$OS" in
    Darwin) echo "brew install $1" ;;
    *)
      if   command -v apt-get >/dev/null; then echo "sudo apt-get install -y $1"
      elif command -v dnf     >/dev/null; then echo "sudo dnf install -y $1"
      elif command -v pacman  >/dev/null; then echo "sudo pacman -S $1"
      elif command -v apk     >/dev/null; then echo "sudo apk add $1"
      elif command -v zypper  >/dev/null; then echo "sudo zypper install $1"
      else echo "install $1 with your package manager"; fi ;;
  esac
}

command -v git >/dev/null || die "git is required: $(pkg_hint git)"
# shellcheck disable=SC2046  # split "2 39" into two words on purpose
set -- $(git version | sed -E 's/^git version ([0-9]+)\.([0-9]+).*/\1 \2/')
if [ "$1" -lt 2 ] || { [ "$1" -eq 2 ] && [ "$2" -lt 36 ]; }; then
  die "git 2.36 or later is required, found $(git version | cut -d' ' -f3): $(pkg_hint git)"
fi
set --
command -v jq >/dev/null || warn "jq not found: pull-request checks and --json are off. Install: $(pkg_hint jq)"
if ! command -v gh >/dev/null; then
  warn "gh not found: pull-request checks are off (plain-git checks still work). Install: $(pkg_hint gh)"
elif ! gh auth status >/dev/null 2>&1; then
  warn "gh is not logged in: run 'gh auth login' to enable pull-request checks"
fi
if ! command -v lsof >/dev/null && [ ! -d /proc/1 ]; then
  warn "neither lsof nor /proc found: cannot tell whether a worktree is open in a shell. Install: $(pkg_hint lsof)"
fi

# ---------------------------------------------------------------- install

mkdir -p "$PREFIX" || die "cannot create $PREFIX; choose a folder you can write to with --prefix"
[ -w "$PREFIX" ] || die "$PREFIX is not writable; choose another with --prefix (this script never uses sudo)"

if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
  is_ours || [ "$FORCE" = yes ] || die "$TARGET exists and was not installed by this script; pass --force to replace it"
  rm -f -- "$TARGET"
fi

chmod +x "$SRC"
if [ "$MODE" = link ]; then
  ln -s "$SRC" "$TARGET"
  how="linked to $SRC (update with: git -C $SRC_DIR pull)"
else
  cp "$SRC" "$TARGET" && chmod 755 "$TARGET"
  how="copied (re-run install.sh --copy after updating)"
fi

version=$("$TARGET" --version) || die "installed, but $TARGET --version failed"
say "Installed $version at $TARGET, $how."

# ---------------------------------------------------------------- PATH

case ":$PATH:" in
  *":$PREFIX:"*) say "Try it: git worktree-clean status" ;;
  *)
    # shellcheck disable=SC2088  # a literal ~ for display
    case "${SHELL##*/}" in
      zsh)  rc="~/.zshrc" ;;
      bash) if [ "$OS" = Darwin ]; then rc="~/.bash_profile"; else rc="~/.bashrc"; fi ;;
      fish) rc="~/.config/fish/config.fish" ;;
      *)    rc="your shell's startup file" ;;
    esac
    say ""
    say "$PREFIX is not on your PATH. Add this line to $rc, then open a new terminal:"
    if [ "${SHELL##*/}" = fish ]; then say "  fish_add_path $PREFIX"
    else say "  export PATH=\"$PREFIX:\$PATH\""; fi
    ;;
esac
