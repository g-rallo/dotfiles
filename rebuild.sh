#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# Pass the live repo path through to home.nix's out-of-store symlinks and the
# current user through to flake.nix's output name. --impure is what lets the
# flake read USER, HOME and DOTFILES_DIR from the environment.
export DOTFILES_DIR="$PWD"
USERNAME="${USER:-$(id -un)}"

if command -v home-manager >/dev/null 2>&1; then
  exec home-manager switch --flake ".#${USERNAME}" --impure
else
  # First run on a fresh machine: fetch home-manager without installing it first.
  exec nix run home-manager/master -- switch --flake ".#${USERNAME}" --impure
fi
