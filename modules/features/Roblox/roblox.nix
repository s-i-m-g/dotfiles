{ self, inputs, ... }: {
  flake.nixosModules.roblox = { pkgs, lib, ... }: {
    home-manager.users.sim = {
      home.packages = [
        pkgs.rojo
        pkgs.wally
        pkgs.selene          # luau linter (optional but common in templates)
      ];
    };
  };
}
