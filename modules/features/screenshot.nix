{ self, inputs, ... }: {
  flake.nixosModules.screenshot = { pkgs, lib, ... }:
  let
    shot = pkgs.writeShellScriptBin "shot-region" ''
      ${pkgs.wayfreeze}/bin/wayfreeze &
      FP=$!
      sleep 0.1
      ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" - | ${pkgs.wl-clipboard}/bin/wl-copy
      kill $FP
    '';
  in {
    environment.systemPackages = [ shot pkgs.grim pkgs.slurp pkgs.wl-clipboard pkgs.wayfreeze ];
  };
}
