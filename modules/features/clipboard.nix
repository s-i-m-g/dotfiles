{ self, inputs, ... }: {
  flake.nixosModules.clipboard = { pkgs, lib, ... }:
  let
    preview = pkgs.writeShellScriptBin "clip-preview" ''
      printf '\033_Ga=d,d=A\033\\'
      id=$(printf '%s' "$1" | cut -f1)
      tmp=$(mktemp)
      printf '%s\t' "$id" | ${pkgs.cliphist}/bin/cliphist decode > "$tmp"
      mime=$(${pkgs.file}/bin/file --mime-type -b "$tmp")
      case "$mime" in
        image/*)
          ${pkgs.chafa}/bin/chafa --format=kitty --size=80x40 "$tmp"
          ;;
        video/*)
          ${pkgs.ffmpeg}/bin/ffmpeg -i "$tmp" -vframes 1 -f image2 "$tmp.jpg" -y 2>/dev/null
          ${pkgs.chafa}/bin/chafa --format=kitty --size=80x40 "$tmp.jpg"
          rm -f "$tmp.jpg"
          ;;
        *)
          cat "$tmp"
          ;;
      esac
      rm -f "$tmp"
    '';

    clipPicker = pkgs.writeShellScriptBin "clip-picker" ''
      sel=$(${pkgs.cliphist}/bin/cliphist list \
        | ${pkgs.fzf}/bin/fzf --with-nth 2 --delimiter '\t' \
              --bind 'j:down,k:up' --no-sort --prompt 'clip> ' \
              --preview '${preview}/bin/clip-preview {}' \
              --preview-window 'right:60%')
      [ -z "$sel" ] && exit 0
      tmp=$(mktemp)
      printf '%s' "$sel" | ${pkgs.cliphist}/bin/cliphist decode > "$tmp"
      ${pkgs.util-linux}/bin/setsid -f ${pkgs.bash}/bin/bash -c "${pkgs.wl-clipboard}/bin/wl-copy < '$tmp'; rm -f '$tmp'" </dev/null >/dev/null 2>&1
      exit 0
    '';
  in {
    home-manager.users.sim = {
      services.cliphist = {
        enable = true;
        allowImages = true;
      };

      home.packages = [ clipPicker preview pkgs.fzf pkgs.chafa pkgs.file pkgs.ffmpeg ];
    };
  };
}
