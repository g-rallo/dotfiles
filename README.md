# Reproducible agentic dev environment (WSL2 + home-manager + WezTerm)

A one-command setup for a full agentic development environment on a Windows laptop. Clone the repo, run `./install.sh`, and you get WSL2 packages, shell, editor and agent tooling without working through a list of manual steps:

```bash
mkdir -p ~/github && cd ~/github
git clone git@github.com:g-rallo/dotfiles.git
cd dotfiles
./install.sh
```

## What this is

This is a Windows adaptation of Kun Chen's [nix-darwin dotfiles](https://github.com/kunchenguid/dotfiles) workflow, extended with the agent tooling that Kun ships separately (skills, `no-mistakes`, `gnhf`, `treehouse`, `firstmate`).

Kun's setup uses **nix-darwin**, which only runs on macOS: Nix has no native Windows build, and nix-darwin cannot run even under WSL2 because it targets Darwin specifically. The part that *is* portable is the **home-manager** layer (user-level packages, shell, editor, and agent configuration), which runs standalone on any Linux, WSL2 included, with no OS-level component required.

So this repo keeps that portable core and drops the rest:

- `flake.nix` wires up nixpkgs and home-manager.
- `home.nix` declares the environment: packages, zsh, starship, and edit-in-place config symlinks.
- `rebuild.sh` re-applies the configuration.
- `install.sh` bootstraps everything that is *not* a Nix package: Nix itself on a fresh machine, the zsh login shell, GitHub CLI authentication, and the agent skills and release-binary tools below.
- `windows/setup.ps1` handles the Windows side (WezTerm install and config symlink), which cannot run from WSL.

The repo is self-contained: cloning it and running `install.sh` is the whole install. The configuration auto-detects your username, home directory and clone location, so the same repo works on any WSL distro or Linux user without edits.

## Features

| Area | What you get |
| --- | --- |
| Reproducible packages | Nix + home-manager (`flake.nix`, `home.nix`) instead of ad-hoc `apt`/`winget` installs |
| Shell | zsh with autosuggestions and syntax highlighting, [starship](https://starship.rs) prompt |
| Editor | neovim + lazy.nvim, oil.nvim and snacks.nvim navigation, Windows clipboard via `win32yank` |
| Terminal | WezTerm, a native Windows GUI app launched from the Start menu into the WSL shell |
| Agent CLI | Claude Code (nixpkgs) and OpenCode (multi-provider CLI) |
| Shared agent config | One `AGENTS.md` symlinked to the path every tool checks (Claude, Codex, OpenCode) |
| Agent skills | [lavish](#agent-skills), [no-mistakes](#agent-skills), [find-skills](#agent-skills) |
| Agent tooling | `no-mistakes` (validation gate), `gnhf` (overnight agent loop), `treehouse` (worktree pool), `firstmate` (multi-repo crew), `gh` (GitHub CLI) |
| Re-runnable | `install.sh` is idempotent; `./rebuild.sh` re-applies after config edits |

### Agent skills

`install.sh` installs these user-level skills under `~/.agents/skills`, shared across every agent tool on the machine (Claude Code, Codex, OpenCode, and the rest):

- **[lavish](https://github.com/kunchenguid/lavish-axi)** - turns agent responses into rich, annotatable HTML pages (plans, comparisons, diagrams, tables, diffs) that you review in the browser and send feedback on. Invoked as `/lavish` or through the `lavish-axi` CLI.
- **[no-mistakes](https://github.com/kunchenguid/no-mistakes)** - the `/no-mistakes` skill: validates committed work through a local pipeline (AI review, tests, docs, lint) and only then pushes it to your real remote and opens a PR.
- **[find-skills](https://github.com/vercel-labs/skills)** - discovers and installs other skills from GitHub, so you can extend the setup with `npx skills find` and `npx skills add`.

## Quick start

### Requirements

- Windows 10 or 11 with WSL2 and an Ubuntu distro installed (`wsl -d Ubuntu`).
- Network access during install.
- Sudo/admin rights once: `install.sh` adds zsh to `/etc/shells` and installs Nix; the Windows script creates a symlink in your user profile.
- This repo cloned **inside the Linux filesystem** (for example `~/github/dotfiles`), never under `/mnt/c/...`.

Nix, zsh, the packages, the skills and the agent tools are all installed by `install.sh`; you do not need to install them first.

### Recommendations

- **WezTerm** on the Windows side for the intended experience. It is the terminal the config targets; a plain Windows Terminal works too, you just lose the tab-into-WSL setup.
- Keep project repos on the Linux side (`~/github`, `~/projects`), not under `/mnt/c/...`, for filesystem performance.
- A **Claude account** (subscription or Anthropic Console) and/or an OpenCode-compatible provider account, plus a GitHub account for the agent tooling. Logins are interactive and are the only manual steps.

### Install and launch

On the WSL side:

```bash
mkdir -p ~/github && cd ~/github
git clone git@github.com:g-rallo/dotfiles.git
cd dotfiles
./install.sh
exec zsh
```

`install.sh` installs Nix if missing, applies the home-manager configuration, sets zsh as the login shell, authenticates the GitHub CLI, and installs the non-Nix tooling. Re-running it is safe. To apply later changes to `home.nix`, use `./rebuild.sh`.

On the Windows side, once, in PowerShell:

```powershell
winget install wez.wezterm
cd "\\wsl$\Ubuntu\home\<your-wsl-user>\github\dotfiles"
powershell -ExecutionPolicy Bypass -File .\windows\setup.ps1
```

Then launch WezTerm from the Start menu. It opens straight into the WSL shell with everything on `PATH`.

### After install (manual steps)

These need interactive logins or Windows UI. `install.sh` already runs `gh auth login` when GitHub is not yet authenticated, so the only remaining steps are:

1. **Agent CLIs**: run `claude` and `opencode auth login` once and pick a subscription or API account
2. **Windows WezTerm**: run `windows/setup.ps1` as described above

For `firstmate` (multi-repo agent crews), see the [firstmate docs](https://github.com/kunchenguid/firstmate); it needs `gh` authenticated and is launched with `cd ~/github/firstmate && claude`.

## Repo layout

```
dotfiles/
├── flake.nix              # nixpkgs + home-manager inputs, per-user output
├── flake.lock
├── home.nix               # packages, zsh, starship, config symlinks
├── rebuild.sh             # re-apply home-manager after config edits
├── install.sh             # one-command bootstrap for a fresh machine
├── .gitignore
├── windows/
│   └── setup.ps1          # WezTerm install + config symlink (Windows side)
└── home/
    ├── AGENTS.md          # shared global agent instructions
    ├── CLAUDE.md
    ├── .claude/
    │   └── settings.json
    └── .config/
        ├── wezterm/wezterm.lua
        ├── herdr/
        └── nvim/
            ├── init.lua
            ├── lazy-lock.json
            └── lua/
                ├── vim_config.lua
                ├── keys.lua
                ├── plugin.lua
                └── plugins/
                    ├── git.lua
                    ├── navigation.lua
                    └── ui.lua
```

Everything installed by `install.sh` but not tracked here (`opencode`, the skills, `no-mistakes`, `gnhf`, `treehouse`, `firstmate`) lives outside the repo, in `~/.opencode/bin`, `~/.local/bin`, `~/.npm-global`, `~/.agents/skills`, or its own clone.

## Design notes

- **home-manager, not nix-darwin.** No `configuration.nix`, no Homebrew: this is the portable user-level layer only.
- **Auto-detected identity.** `flake.nix` reads `USER`, `HOME` and `DOTFILES_DIR` from the environment (`rebuild.sh` runs home-manager with `--impure`), so nothing is hardcoded to a particular user or clone path.
- **Edit-in-place configs.** `wezterm`, `nvim`, `herdr`, `.claude/settings.json` and the `AGENTS.md` symlinks use `config.lib.file.mkOutOfStoreSymlink`, a real symlink to the live files in this repo, so edits take effect immediately with no rebuild. `./rebuild.sh` is only for changes to `home.nix` itself.
- **WezTerm stays on Windows.** It is a native Windows GUI app; a Linux-built WezTerm inside headless WSL has no window to draw into. It reads `%USERPROFILE%\.wezterm.lua`, which `windows/setup.ps1` symlinks to the config in this repo.
- **External tools are deliberately not in Nix.** `opencode`, `gnhf`, `no-mistakes`, `treehouse` and `firstmate` are optional, fast-moving, or not packaged, so `install.sh` installs them into writable per-user locations instead of the read-only Nix store.

## Notes for future changes

- Edit `home.nix`, then run `./rebuild.sh`. New files added to the repo need `git add` before a rebuild will pick them up.
- **`~/.zshrc` is not directly editable.** home-manager generates it as a symlink into the read-only Nix store, so manual edits fail. Shell changes go through `home.nix` (`programs.zsh.shellAliases`, `home.sessionPath`), then `./rebuild.sh`.
- `~/.local/bin`, `~/.opencode/bin` and `~/.npm-global/bin` are on `PATH` via `home.sessionPath`. Release-binary tools and global npm packages land there. OpenCode's installer runs with `--no-modify-path` so it never touches `~/.zshrc`.
- `win32yank` is installed into `~/.local/bin`; `opencode` installs itself into `~/.opencode/bin`; `gnhf` is a global npm package under `~/.npm-global`; `no-mistakes` and `treehouse` prefer `~/.local/bin` when it is on `PATH`.
- `claude-code` is unfree, so `flake.nix` sets `config.allowUnfree = true;`.
- `/tmp` in WSL can be wiped if the distro restarts mid-task; run multi-step installs (like `install.sh`) as one uninterrupted block.
- herdr writes runtime logs and sockets into its config dir, which is symlinked into this repo; those paths are gitignored so the working tree stays clean.
