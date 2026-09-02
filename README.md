# Reproducible Dev Environment (WSL2 + home-manager + WezTerm)

Windows adaptation of Kun Chen's [nix-darwin dotfiles](https://github.com/kunchenguid/dotfiles) workflow.

## Why this shape

Kun's setup uses **nix-darwin**, which only runs on macOS — Nix has no native Windows build, and nix-darwin can't run even under WSL2 (it targets Darwin specifically). The part that *is* portable is the **home-manager** layer (user-level packages, shell, and agentic-workflow config) — home-manager runs standalone on any Linux, including WSL2, with no OS-level (nix-darwin/Homebrew) component required.

So this setup drops `configuration.nix` entirely (nothing on Windows for it to configure — no macOS defaults, no Homebrew) and keeps only:
- **`flake.nix`** — wires up nixpkgs + home-manager (no nix-darwin, no nix-homebrew)
- **`home.nix`** — the actual environment: packages, zsh, starship, dotfile symlinks
- **`rebuild.sh`** — re-applies the config, equivalent to Kun's `darwin-rebuild switch`

**WezTerm split:** WezTerm is a native Windows GUI app, installed via `winget`, not through `home.nix`. It launches a tab running `wsl.exe`, which drops you into the Nix-managed WSL shell. A Linux-built WezTerm inside WSL has no window to draw into (WSL is headless by default) and can't be the thing you launch from the Windows taskbar — so it stays on the Windows side, config symlinked in from the repo, same way Kun's `home/.config/wezterm/wezterm.lua` is symlinked into place on macOS.

**Edit-in-place configs (`wezterm`, `nvim`, `herdr`, `claude`):** rather than `home.file` copying config into the Nix store at build time (which would need a rebuild after every edit), these use `config.lib.file.mkOutOfStoreSymlink` — a real symlink straight to the live files in this repo, so edits take effect immediately with no `./rebuild.sh` needed. The WezTerm one (`~/.config/wezterm`) only matters if some WSL-side tool reads it — the app itself runs on Windows and reads `%USERPROFILE%\.wezterm.lua` (a separate, manually-created Windows symlink). The rest are fully active, since those tools run inside WSL.

## Prerequisites

- WSL2 already set up, with an Ubuntu distro installed (`wsl -d Ubuntu`)
- Windows 10/11 with `winget` available

## Steps (fresh machine)

### 1. Install Nix inside WSL Ubuntu
```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
```
Restart the WSL shell afterward so Nix is on `PATH`.

### 2. Clone this repo inside the Linux filesystem
Keep it native to WSL — not under `/mnt/c/...` — for filesystem performance:
```bash
mkdir -p ~/github
cd ~/github
git clone <this-repo-url> dotfiles
cd dotfiles
```

### 3. Check `home.nix` matches your actual Linux username
`whoami` in WSL gives the real value — `home.username`, `home.homeDirectory`, and the `dotfiles` path in `home.nix` must all match exactly, and `flake.nix`'s `homeConfigurations` key must match the username too. Edit if needed.

### 4. Stage the files in git
Nix flakes only see files tracked by git (staged is enough, doesn't need to be committed):
```bash
git add -A
git commit -m "initial home-manager setup"
```

### 5. First-run home-manager
```bash
nix run home-manager/master -- switch --flake .#<your-username>
```

### 6. From now on, apply changes with
```bash
./rebuild.sh
```

### 6a. Make zsh your login shell
home-manager installs zsh but doesn't change which shell WSL logs you into — that's a system-level setting outside its reach, set once per distro:
```bash
which zsh   # confirm it's on PATH
chsh -s $(which zsh)
```
If it errors that the path isn't a valid shell:
```bash
echo $(which zsh) | sudo tee -a /etc/shells
chsh -s $(which zsh)
```
Restart the WezTerm tab afterward. `echo $SHELL` should print the zsh path.

### 7. Install WezTerm on Windows
In PowerShell (Windows side, not WSL):
```powershell
winget install wez.wezterm
```

### 8. Symlink the WezTerm config from the repo
PowerShell as Administrator (or with Developer Mode enabled):
```powershell
New-Item -ItemType SymbolicLink -Path "$env:USERPROFILE\.wezterm.lua" -Target "\\wsl$\Ubuntu\home\<your-username>\github\dotfiles\home\.config\wezterm\wezterm.lua"
```
Adjust the distro name/path if different on the new machine. Verify with:
```powershell
Get-Item "$env:USERPROFILE\.wezterm.lua" | Select-Object FullName, LinkType, Target
```
The config sets `default_prog` to `wsl.exe` with `--cd '~'` — without that flag, WezTerm passes its own working directory through and you land in `/mnt/c/Users/...` instead of the Linux home.

### 9. Put project repos on the Linux side
```bash
mkdir -p ~/projects
cd ~/projects
git clone <your-repo-url>
```
Not under `/mnt/c/...` — same performance reason as step 2.

### 10. Install win32yank (WSL clipboard bridge for nvim)
`unnamedplus` in nvim does nothing on WSL by itself — no X11/Wayland clipboard provider like on native Linux or macOS's `pbcopy`. `win32yank` bridges it to the real Windows clipboard. Not in nixpkgs, installed manually — run as one block so `/tmp` doesn't get wiped mid-way by a session restart:
```bash
curl -sLo /tmp/win32yank.zip https://github.com/equalsraf/win32yank/releases/latest/download/win32yank-x64.zip
rm -rf /tmp/win32yank_extracted
mkdir /tmp/win32yank_extracted
unzip -o /tmp/win32yank.zip -d /tmp/win32yank_extracted
sudo mv /tmp/win32yank_extracted/win32yank.exe /usr/local/bin/win32yank.exe
sudo chmod +x /usr/local/bin/win32yank.exe
win32yank.exe -h
```
Last line should print help/usage text (not `-v`, unsupported) — confirms it's installed and executable.

### 11. nvim config
Already in the repo (`home/.config/nvim/`), symlinked automatically via `home.nix`. No rebuild needed for edits — it's an out-of-store symlink, live immediately. Verify with `nvim` → `:checkhealth` (clipboard section should show `win32yank.exe` as the provider) → test `yy` then paste into a Windows app.

### 12. lazy.nvim plugin manager
Already wired in the repo (`home/.config/nvim/lua/plugin.lua`) — only real dependency is `git` on `PATH`, already covered. First `nvim` launch after cloning bootstraps lazy.nvim itself; confirm with `:Lazy` (`q` to close).

### 13. Navigation plugins (oil.nvim, snacks.nvim)
Already in the repo (`home/.config/nvim/lua/plugins/navigation.lua`). `snacks.picker.grep()` uses **ripgrep** under the hood — already in `home.packages`. lazy.nvim auto-installs both on next `nvim` launch. Test: `<leader>e` file browser, `<leader>f` find files, `<leader>s` grep, `<leader>b` buffers.

### 14. Install herdr
Herdr is an agent-orchestration terminal tool Kun installs via Homebrew in `configuration.nix` (macOS-only, no equivalent here). It's packaged directly in nixpkgs, so it's just in `home.packages` — no separate flake input needed (a Herdr-maintained flake builds from source and is slow/fragile; a community `herdr-nix` flake hit a registry resolution error; plain nixpkgs was the reliable path). Covered by `./rebuild.sh`. Verify: `herdr --version`.

### 15. Install Claude Code
Also via Homebrew in Kun's `configuration.nix` — no equivalent here either. Packaged in nixpkgs, but it's an **unfree** package, so `flake.nix` needs `config.allowUnfree = true;` in its `import nixpkgs { ... }` call, or the build refuses it outright. Already set in this repo's `flake.nix`. Covered by `./rebuild.sh`. Verify: `claude --version`, then `cc` (the alias) to launch it.

On first launch, choose between:
- **Claude account with subscription** — uses an existing claude.ai Pro/Max/Team plan, no separate billing.
- **Anthropic Console account** — separate pay-as-you-go API billing, independent of any claude.ai subscription.

Claude Code only ever talks to Claude models — neither login option changes that. For genuine multi-provider flexibility, see step 17 (Kilo Code).

### 16. Symlink herdr config and Claude settings
Already declared in `home.nix`, but the target paths must exist in the repo *before* rebuilding, or home-manager errors with a dangling-symlink/clobber message. If herdr already created a real `~/.config/herdr` before the symlink existed (e.g. from running it once before this step), home-manager will refuse to overwrite it — back it up first:
```bash
[ -L ~/.config/herdr ] || mv ~/.config/herdr ~/.config/herdr.bak
```
Then `./rebuild.sh`.

### 17. Kilo Code CLI (optional, non-essential)
Multi-model agentic CLI (500+ providers, unlike Claude Code which is Claude-only) — kept **outside** `home.nix` deliberately, since it's not essential and doesn't need to be reproducible. Installed via the project's own script rather than `npm install -g`, since npm's global installs fail with `EACCES` when `node` comes from the read-only Nix store:
```bash
curl -fsSL https://kilo.ai/cli/install | bash
```
This installs a standalone binary (commonly to `~/.local/bin` or `~/.kilo/bin`) and normally updates shell config itself — but if `which kilo` comes up empty afterward, **do not** try editing `~/.zshrc` directly: home-manager generates it as a symlink into the read-only Nix store, so any write to it fails with permission denied. Symlink the binary into a standard system `PATH` location instead:
```bash
find ~ -maxdepth 4 -iname "kilo" -type f 2>/dev/null   # find where it actually landed
sudo ln -s <path from above> /usr/local/bin/kilo
```
Verify: `which kilo`, then `kilo` → `/connect` inside it to add provider API keys.

### 18. Launch WezTerm
It should open directly into the WSL shell, with home-manager's packages and aliases (`cc`, `co`) already on `PATH`.

## Repo layout

```
dotfiles/
├── flake.nix
├── home.nix
├── rebuild.sh
└── home/
    ├── .claude/
    │   └── settings.json
    └── .config/
        ├── wezterm/
        │   └── wezterm.lua
        ├── herdr/
        └── nvim/
            ├── init.lua
            └── lua/
                ├── vim_config.lua
                ├── plugin.lua
                └── plugins/
                    └── navigation.lua
```
`kilo` (step 17) is intentionally **not** in this repo — installed manually outside Nix, doesn't reappear automatically on a fresh machine.

## Notes for future changes

- Edit `home.nix`, then run `./rebuild.sh` — same workflow as Kun's mac setup, just Linux underneath.
- New files added to the repo need `git add` before a rebuild will pick them up.
- `wezterm`, `nvim`, `herdr`, and `.claude/settings.json` are all out-of-store symlinks — edits are picked up immediately, no rebuild needed. `./rebuild.sh` is only for changes to `home.nix` itself.
- Shell is zsh, not the WSL/Ubuntu default bash — `chsh -s $(which zsh)` (step 6a) only needs to run once per machine/distro.
- **`~/.zshrc` is not directly editable.** home-manager generates it as a symlink into the read-only Nix store — any manual edit fails with permission denied. Shell config changes must go through `home.nix` (`programs.zsh.shellAliases`, `home.sessionPath`), then `./rebuild.sh`.
- Pasting into vim works out of the box via WezTerm's bracketed paste (`Ctrl+Shift+V`); copying *out* of vim to the Windows clipboard goes through `win32yank` (step 10) — not a Nix package, installed manually, doesn't survive a fresh machine automatically.
- `/tmp` in WSL can get wiped if the distro/session restarts mid-task — run multi-step installs (like win32yank) as one uninterrupted block, verifying output at each step.
- `claude-code` requires `config.allowUnfree = true;` in `flake.nix` — already set, but worth knowing if the build ever refuses it after an edit.
- `kilo` (step 17) is deliberately outside Nix entirely — reinstall manually on a fresh machine if wanted.
