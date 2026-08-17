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
        - key: "t"
          desc: "To"
          submenu:
            - key: "g"
              desc: "Gif"
              cmd: clip-to-gif
            - key: "s"
              desc: "Split"
              cmd: clip-split
            - key: "v"
              desc: "MP4"
              cmd: to-mp4
            - key: "a"
              desc: "MP3"
              cmd: to-mp3
            - key: "b"
              desc: "Bin"
              cmd: to-bin
            - key: "l"
              desc: "Link"
              cmd: upload-video
            - key: "k"
              desc: "kdenlive"
              cmd: to-kdenlive

        - key: "g"
          desc: "Clip / GIF"
          submenu:
            - key: "c"
              desc: "Caption"
              cmd: caption-gif
            - key: "s"
              desc: "Speech bubble"
              cmd: speech-bubble
            - key: "r"
              desc: "Remove caption"
              cmd: remove-caption
            - key: "p"
              desc: "Plode"
              cmd: plode
            - key: "f"
              desc: "Fade"
              cmd: fade
            - key: "t"
              desc: "Trim"
              cmd: trim-top

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

        - key: "d"
          desc: "Download / Upload"
          submenu:
            - key: "d"
              desc: "Download media"
              cmd: dl-media
   '';
  in {
    home-manager.users.sim = {
      home.packages = [ pkgs.wlr-which-key ];
      xdg.configFile."wlr-which-key/config.yaml".text = config;
    };
  };
}
