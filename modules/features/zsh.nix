{ self, inputs, ... }: {
  flake.nixosModules.zsh = { pkgs, lib, ... }: {
    # system-level: needed to set zsh as a login shell
    programs.zsh.enable = true;
    users.users.sim.shell = pkgs.zsh;

    home-manager.users.sim = {
      programs.zsh = {
        enable = true;
        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;
        enableCompletion = true;

        shellAliases = {
          rebuild = "sudo nixos-rebuild switch --flake /home/myNixOS#myMachine";
          ll = "ls -la";
        };

        history = {
          size = 10000;
          ignoreDups = true;
          share = true;
        };
      };
    };
  };
}
