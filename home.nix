{ config, pkgs, username, homeDirectory, dotfilesDir, ... }:

{
  home.username = username;
  home.homeDirectory = homeDirectory;
  home.stateVersion = "24.05";

  home.packages = with pkgs; [
    git
    gh
    ripgrep
    fzf
    tmux
    neovim
    nodejs_22
    unzip
    herdr
    claude-code
  ];

  # Writable per-user bin dirs outside the Nix store. ~/.local/bin holds
  # release-binary tools (win32yank, no-mistakes, treehouse),
  # ~/.opencode/bin is OpenCode's own installer location, and
  # ~/.npm-global/bin holds global npm packages (gnhf); install.sh seeds them.
  home.sessionPath = [
    "${homeDirectory}/.local/bin"
    "${homeDirectory}/.opencode/bin"
    "${homeDirectory}/.npm-global/bin"
  ];

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;      # ghost text from history
    syntaxHighlighting.enable = true;  # commands turn green when valid
    initContent = ''
      bindkey '^f' autosuggest-accept
    '';
    # shellAliases = {
    #  ".." = "cd ..";
    #  add = "git add .";
    #  push = "git push";
    #  pull = "git pull";
    #  m = "git switch main";
    #  cc = "claude --dangerously-skip-permissions";
    #  co = "codex --full-auto";
    #};
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$cmd_duration$line_break$character";
      character = {
        success_symbol = "[❯](purple)";
        error_symbol = "[❯](red)";
      };
      cmd_duration.format = "[$duration]($style) ";
    };
  };

  # Edit-in-place: the real file stays in this repo, ~/.config just points at it.
  # dotfilesDir is resolved from the environment at switch time (see flake.nix),
  # so the repo can live anywhere and the config still links to the live files.
  home.file.".config/wezterm".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/home/.config/wezterm";
  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/home/.config/nvim";
  home.file.".config/herdr".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/home/.config/herdr";
  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/home/.claude/settings.json";

  home.file."AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/home/AGENTS.md";
  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/home/AGENTS.md";
  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/home/AGENTS.md";
  home.file.".config/opencode/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/home/AGENTS.md";

  programs.home-manager.enable = true;
}
