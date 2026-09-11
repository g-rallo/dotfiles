#!/usr/bin/env bash
#
# One-command bootstrap for this dotfiles repo on WSL2 + Ubuntu.
#
#   git clone <this-repo> && cd dotfiles && ./install.sh
#
# Installs Nix if missing, applies the home-manager configuration, and then
# installs the agent tooling that lives outside Nix (skills, no-mistakes, gnhf,
# treehouse, firstmate, kilo, win32yank). Re-running it is safe: every step
# checks whether it is already done.
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

USERNAME="${USER:-$(id -un)}"
HOME_DIR="${HOME:-/home/$USERNAME}"
export DOTFILES_DIR="$REPO_DIR"

# Ensure anything install.sh drops into these dirs is reachable immediately.
export PATH="$HOME_DIR/.local/bin:$HOME_DIR/.npm-global/bin:$PATH"

log() { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }
optional() { "$@" || warn "step failed, continuing: $*"; }

if [ "$(id -u)" -eq 0 ]; then
  echo "Run this as your normal user, not root. Nix and home-manager are per-user." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 1. Nix (per-user, Determinate Systems installer)
# ---------------------------------------------------------------------------
if ! have nix; then
  log "Installing Nix"
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install --no-confirm
fi
# Make nix available in this shell for the rest of the script.
for profile in \
  /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh \
  "$HOME_DIR/.nix-profile/etc/profile.d/nix.sh"; do
  # shellcheck disable=SC1090
  [ -e "$profile" ] && . "$profile"
done
if ! have nix; then
  echo "Nix is not on PATH. Open a new shell and re-run ./install.sh." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 2. home-manager: packages, zsh, starship, and the in-repo config symlinks
# ---------------------------------------------------------------------------
log "Applying home-manager configuration"
"$REPO_DIR/rebuild.sh"
# home-manager just populated the user profile; surface its binaries (zsh, gh,
# node, unzip, ...) in the current shell so the steps below can use them.
export PATH="$HOME_DIR/.nix-profile/bin:$HOME_DIR/.local/state/nix/profiles/profile/bin:$PATH"

# ---------------------------------------------------------------------------
# 3. zsh as the login shell (system-level, one time per distro)
# ---------------------------------------------------------------------------
if have zsh && [ "$(basename "${SHELL:-}")" != "zsh" ]; then
  ZSH_PATH="$(command -v zsh)"
  log "Setting zsh as the login shell"
  if ! grep -qx "$ZSH_PATH" /etc/shells 2>/dev/null; then
    echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
  fi
  sudo chsh -s "$ZSH_PATH" "$USERNAME" || warn "run: chsh -s $ZSH_PATH"
fi

# ---------------------------------------------------------------------------
# 4. win32yank: bridges nvim's clipboard to the Windows clipboard
# ---------------------------------------------------------------------------
if [ ! -x "$HOME_DIR/.local/bin/win32yank.exe" ]; then
  log "Installing win32yank"
  tmp="$(mktemp -d)"
  if curl -sLo "$tmp/win32yank.zip" \
      https://github.com/equalsraf/win32yank/releases/latest/download/win32yank-x64.zip \
     && unzip -o "$tmp/win32yank.zip" -d "$tmp" >/dev/null; then
    mkdir -p "$HOME_DIR/.local/bin"
    install -m 0755 "$tmp/win32yank.exe" "$HOME_DIR/.local/bin/win32yank.exe"
  else
    warn "win32yank download/extract failed; nvim clipboard will not reach Windows"
  fi
  rm -rf "$tmp"
fi

# ---------------------------------------------------------------------------
# 5. Kilo Code CLI (multi-model agentic CLI, deliberately outside Nix)
# ---------------------------------------------------------------------------
if ! have kilo; then
  log "Installing Kilo Code CLI"
  curl -fsSL https://kilo.ai/cli/install | bash || warn "kilo installer reported an error"
fi
if ! have kilo; then
  kilo_bin="$(find "$HOME_DIR" -maxdepth 4 -type f -name kilo 2>/dev/null | head -n1 || true)"
  if [ -n "$kilo_bin" ]; then
    mkdir -p "$HOME_DIR/.local/bin"
    ln -sf "$kilo_bin" "$HOME_DIR/.local/bin/kilo"
  else
    warn "could not locate the kilo binary"
  fi
fi

# ---------------------------------------------------------------------------
# 6. Agent skills (user-level, under ~/.agents/skills)
# ---------------------------------------------------------------------------
if [ ! -d "$HOME_DIR/.agents/skills/lavish" ]; then
  log "Installing lavish skill"
  optional npx --yes skills@latest add kunchenguid/lavish-axi \
    --skill lavish --global --agent '*' --yes
fi
if [ ! -d "$HOME_DIR/.agents/skills/find-skills" ]; then
  log "Installing find-skills skill"
  optional npx --yes skills@latest add vercel-labs/skills \
    --skill find-skills --global --agent '*' --yes
fi

# ---------------------------------------------------------------------------
# 7. no-mistakes (validation gate; also installs its /no-mistakes skill)
# ---------------------------------------------------------------------------
if ! have no-mistakes; then
  log "Installing no-mistakes"
  curl -fsSL https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.sh | sh
fi
if have no-mistakes && git -C "$REPO_DIR" remote get-url origin >/dev/null 2>&1; then
  log "Initializing the no-mistakes gate for this repo"
  optional no-mistakes init
fi

# ---------------------------------------------------------------------------
# 8. gnhf (overnight autonomous agent loop; global npm package)
# ---------------------------------------------------------------------------
if ! have gnhf; then
  log "Installing gnhf"
  mkdir -p "$HOME_DIR/.npm-global"
  npm config set prefix "$HOME_DIR/.npm-global"
  optional npm install -g gnhf
fi

# ---------------------------------------------------------------------------
# 9. treehouse (reusable worktree pool for parallel agents)
# ---------------------------------------------------------------------------
if ! have treehouse; then
  log "Installing treehouse"
  curl -fsSL https://kunchenguid.github.io/treehouse/install.sh | sh
fi

# ---------------------------------------------------------------------------
# 10. GitHub CLI login (interactive, one time; needed by no-mistakes/firstmate)
# ---------------------------------------------------------------------------
if have gh; then
  if gh auth status >/dev/null 2>&1; then
    log "GitHub CLI already authenticated"
  else
    log "Authenticating the GitHub CLI"
    optional gh auth login
  fi
else
  warn "gh not found on PATH; after 'exec zsh', run: gh auth login"
fi

# ---------------------------------------------------------------------------
# 11. firstmate (agent distro: one first mate supervising a crew)
# ---------------------------------------------------------------------------
if [ ! -d "$HOME_DIR/github/firstmate/.git" ]; then
  log "Cloning firstmate"
  mkdir -p "$HOME_DIR/github"
  git clone https://github.com/kunchenguid/firstmate \
    "$HOME_DIR/github/firstmate" \
    || warn "firstmate clone failed (repo is public; check your network)"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
DISTRO="${WSL_DISTRO_NAME:-Ubuntu}"
log "Bootstrap complete"
cat <<EOF

Manual steps that cannot be fully automated:

  1. Authenticate Claude Code:  claude    (pick a subscription or API account)
  2. Windows, once, in PowerShell as Administrator (or with Developer Mode on):

       winget install wez.wezterm
       cd "\\\\wsl\$\\${DISTRO}\\home\\${USERNAME}\\github\\dotfiles"
       powershell -ExecutionPolicy Bypass -File .\\windows\\setup.ps1

  3. Start a fresh shell so zsh and the new PATH take effect:

       exec zsh

Then launch WezTerm from the Windows Start menu. Everything else is installed.
EOF
