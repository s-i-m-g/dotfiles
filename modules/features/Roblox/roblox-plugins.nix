{ self, inputs, ... }: {
  flake.nixosModules.roblox-plugins =
    { pkgs, lib, ... }:
    let
      # Fetch the PREBUILT Rojo Studio plugin from the GitHub release —
      # the complete artifact the Rojo team ships (with bundled deps).
      # Building from source produced an incomplete plugin that Studio
      # silently ignored, so we use the release .rbxm directly.
      # Version-matched to pkgs.rojo via the tag.
      rojoPlugin = pkgs.fetchurl {
        url = "https://github.com/rojo-rbx/rojo/releases/download/v${pkgs.rojo.version}/Rojo.rbxm";
        hash = "sha256-IU5a2EzNyI+HPgRntnJOTqmtqOo0D8udQ5fLiZpnyD8=";
      };

      # Build the luau-lsp companion plugin from source.
      # (If this one also fails to load in Studio, we'll switch it to a
      #  prebuilt fetch too — but its build has no Wally deps to bundle.)
      luauCompanionSrc = pkgs.fetchFromGitHub {
        owner = "JohnnyMorganz";
        repo = "luau-lsp";
        rev = "main";
        hash = "sha256-oK1b1s+0YftWzYH+OWN4b4L0jPax8AKZ+8PFfS7fd5E=";
      };

      luauCompanionPlugin = pkgs.runCommand "luau-lsp-companion.rbxm" { } ''
        ${pkgs.rojo}/bin/rojo build ${luauCompanionSrc}/plugin/default.project.json --output $out
      '';
    in
    {
      home-manager.users.sim =
        { config, lib, ... }:
        let
          pluginDir = "${config.home.homeDirectory}/.local/share/vinegar/prefixes/studio/drive_c/users/${config.home.username}/AppData/Local/Roblox/Plugins";
        in
        {
          home.activation.robloxPlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            run mkdir -p "${pluginDir}"
            run cp -f "${rojoPlugin}" "${pluginDir}/Rojo.rbxm"
            run cp -f "${luauCompanionPlugin}" "${pluginDir}/LuauLSP-Companion.rbxm"
            run chmod u+w "${pluginDir}/Rojo.rbxm" "${pluginDir}/LuauLSP-Companion.rbxm"
          '';
        };
    };
}
