{ self, inputs, ... }: {
  flake.nixosModules.zsh = { pkgs, lib, ... }: {
    programs.zsh.enable = true;
    users.users.sim.shell = pkgs.zsh;

    home-manager.users.sim = {
      programs.zsh = {
        enable = true;
        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;
        enableCompletion = true;

        defaultKeymap = "viins";

        shellAliases = {
          rebuild = "sudo nixos-rebuild switch --flake /home/myNixOS#myMachine";
          ll = "ls -la";
        };

        history = {
          size = 10000;
          ignoreDups = true;
          share = true;
        };

        initContent = ''
          unsetopt BEEP
          KEYTIMEOUT=1

          typeset -gA ZSH_HIGHLIGHT_STYLES
          ZSH_HIGHLIGHT_STYLES[path]=none
          ZSH_HIGHLIGHT_STYLES[path_prefix]=none

          bindkey -M viins '^R' history-incremental-search-backward
          bindkey -M viins '^A' beginning-of-line
          bindkey -M viins '^E' end-of-line

          bindkey '^ ' autosuggest-accept
        '';
      };
    };
  };
}
