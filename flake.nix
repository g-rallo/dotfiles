{
  description = "Gil's reproducible agentic dev environment (WSL2 + home-manager)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      # Resolved from the environment at switch time. rebuild.sh runs
      # home-manager with --impure, so these reflect the current machine and
      # clone location; the fallbacks only apply under pure evaluation.
      rawUser = builtins.getEnv "USER";
      rawHome = builtins.getEnv "HOME";
      rawDotfiles = builtins.getEnv "DOTFILES_DIR";

      username = if rawUser == "" then "user" else rawUser;
      homeDirectory = if rawHome == "" then "/home/${username}" else rawHome;
      dotfilesDir =
        if rawDotfiles == "" then "${homeDirectory}/github/dotfiles" else rawDotfiles;
    in
    {
      homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit username homeDirectory dotfilesDir; };
        modules = [ ./home.nix ];
      };
    };
}
