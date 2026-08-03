{ self, inputs, ... }: {
  flake.nixosModules.zen = { pkgs, lib, ... }:
  let
    # the shortcuts JSON lives next to this module; Nix copies it into the store
    shortcutsFile = ./zen-keyboard-shortcuts.json;
    shortcutsTarget = "zen-keyboard-shortcuts.json";
  in {
    environment.systemPackages = [
      inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    home-manager.users.sim = { config, lib, ... }: {
      # On every rebuild, drop the shortcuts file into EVERY Zen profile under
      # ~/.config/zen, overwriting whatever's there — nothing about the profile
      # name is hardcoded. A copy (not home.file's read-only store symlink) is
      # used because Zen rewrites this file itself when you edit shortcuts in its
      # UI, so it must stay writable. Rebuild resets it to the declared version.
      home.activation.zenShortcuts =
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          zen_dir="''${HOME}/.config/zen"
          if [ -d "$zen_dir" ]; then
            for d in "$zen_dir"/*/; do
              [ -d "$d" ] || continue
              base="$(basename "$d")"
              # skip Zen's non-profile support directories
              case "$base" in
                "Profile Groups"|"Crash Reports"|"Pending Pings") continue ;;
              esac
              run cp -f ${shortcutsFile} "$d/${shortcutsTarget}"
              run chmod u+w "$d/${shortcutsTarget}"
            done
          else
            echo "zen: config dir not found ($zen_dir) — skipping shortcuts copy" >&2
          fi
        '';
    };
  };
}
