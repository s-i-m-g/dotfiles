{ self, inputs, ... }: {
  flake.nixosModules.screenshare = { pkgs, lib, ... }: {
    # xdg-desktop-portal-wlr hardcodes a 2-buffer pipewire pool
    # (XDPW_PWR_BUFFERS / XDPW_PWR_BUFFERS_MIN in
    # include/pipewire_screencast.h). Chromium/Electron consumers (Vesktop)
    # hold both buffers at once, so pw_stream_dequeue_buffer() never frees
    # one up and the stream dies after frame 1 with "pipewire: out of
    # buffers" / "unable to export buffer". Confirmed upstream on this
    # exact stack (mango + AMD + 0.8.3): emersion/xdg-desktop-portal-wlr#395.
    # Bumping both constants to 4 fixes it. (xdg-desktop-portal-luminous was
    # tried as an alternative backend but panics on this compositor with
    # "Cannot create layershell: ConnectError(NoCompositor)" - not usable.)
    nixpkgs.overlays = [
      (final: prev: {
        xdg-desktop-portal-wlr = prev.xdg-desktop-portal-wlr.overrideAttrs (old: {
          postPatch = (old.postPatch or "") + ''
            substituteInPlace include/pipewire_screencast.h \
              --replace-fail '#define XDPW_PWR_BUFFERS 2' '#define XDPW_PWR_BUFFERS 4' \
              --replace-fail '#define XDPW_PWR_BUFFERS_MIN 2' '#define XDPW_PWR_BUFFERS_MIN 4'
          '';
        });
      })
    ];

    xdg.portal = {
      enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-gtk
      ];
      config.common.default = [ "wlr" "gtk" ];
      wlr = {
        enable = true;
        settings.screencast = {
          chooser_type = "dmenu";
          chooser_cmd = "${pkgs.rofi}/bin/rofi -dmenu -p 'Select window/output to share'";
          force_mod_linear = true;
        };
      };
    };
  };
}
