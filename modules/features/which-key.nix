{ self, inputs, ... }: {
  flake.nixosModules.which-key = { pkgs, lib, ... }:
  let
    # wlr-which-key reads ~/.config/wlr-which-key/config.yaml
    config = ''
      # Theming
      font: JetBrainsMono Nerd Font 12
      background: "#1e1e2ed0"
      color: "#cdd6f4"
      border: "#89b4fa"
      separator: " → "
      border_width: 2
      corner_r: 10
      padding: 15
      rows_per_column: 8

      anchor: center

      menu:
        - key: "g"
          desc: "Clip / GIF"
          submenu:
            - key: "g"
              desc: "Clip → GIF"
              cmd: clip-to-gif
            - key: "c"
              desc: "Caption GIF"
              cmd: caption-gif
            - key: "s"
              desc: "Speech bubble"
              cmd: speech-bubble
            - key: "r"
              desc: "Remove caption"
              cmd: remove-caption
            - key: "p"
              desc: "Split long video"
              cmd: clip-split
            - key: "m"
              desc: "Convert to MP4"
              cmd: to-mp4

        - key: "r"
          desc: "Record"
          submenu:
            - key: "r"
              desc: "Fullscreen"
              cmd: rec-start
            - key: "l"
              desc: "Zone / region"
              cmd: rec-start-region
            - key: "s"
              desc: "Stop"
              cmd: rec-stop

        - key: "m"
          desc: "Media"
          submenu:
            - key: "g"
              desc: "Media grid"
              cmd: media-grid-float
            - key: "c"
              desc: "Clipboard picker"
              cmd: clip-picker

        - key: "d"
          desc: "Download / Upload"
          submenu:
            - key: "d"
              desc: "Download media"
              cmd: dl-media
            - key: "u"
              desc: "Upload video"
              cmd: upload-video
    '';
  in {
    home-manager.users.sim = {
      home.packages = [ pkgs.wlr-which-key ];
      xdg.configFile."wlr-which-key/config.yaml".text = config;
    };
  };
}
