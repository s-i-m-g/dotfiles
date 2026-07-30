{ self, inputs, ... }: {
  flake.nixosModules.clipboard = { pkgs, lib, ... }:
  let
    preview = pkgs.writeShellScriptBin "clip-preview" ''
      printf '\033_Ga=d,d=A\033\\'
      id=$(printf '%s' "$1" | cut -f1)
      tmp=$(mktemp)
      printf '%s\t' "$id" | ${pkgs.cliphist}/bin/cliphist decode > "$tmp"
      mime=$(${pkgs.file}/bin/file --mime-type -b "$tmp")

      content=$(cat "$tmp")
      case "$content" in
        file://*)
          real=$(printf '%s' "$content" | head -1 | ${pkgs.gnused}/bin/sed 's|^file://||' | tr -d '\r')
          if [ -f "$real" ]; then
            rm -f "$tmp"
            tmp="$real"
            mime=$(${pkgs.file}/bin/file --mime-type -b "$tmp")
            KEEP=1
          fi
          ;;
      esac

      case "$mime" in
        image/gif)
          frame=$(mktemp).png
          ${pkgs.ffmpeg}/bin/ffmpeg -i "$tmp" -vframes 1 -f image2 "$frame" -y 2>/dev/null
          ${pkgs.chafa}/bin/chafa --format=kitty --size=80x40 "$frame"
          rm -f "$frame"
          ;;
        image/*)
          ${pkgs.chafa}/bin/chafa --format=kitty --size=80x40 "$tmp"
          ;;
        video/*)
          frame=$(mktemp).jpg
          ${pkgs.ffmpeg}/bin/ffmpeg -i "$tmp" -vframes 1 -f image2 "$frame" -y 2>/dev/null
          ${pkgs.chafa}/bin/chafa --format=kitty --size=80x40 "$frame"
          rm -f "$frame"
          ;;
        *)
          cat "$tmp"
          ;;
      esac

      [ -z "$KEEP" ] && rm -f "$tmp"
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
      # If the clip is a file:// uri-list (e.g. from clip-split/clip-to-gif),
      # re-copy it WITH -t text/uri-list — otherwise wl-copy re-advertises it as
      # text/plain and Discord pastes the path text instead of attaching the file.
      if ${pkgs.gnugrep}/bin/grep -q '^file://' "$tmp"; then
        ${pkgs.util-linux}/bin/setsid -f ${pkgs.bash}/bin/bash -c "${pkgs.wl-clipboard}/bin/wl-copy -t text/uri-list < '$tmp'; rm -f '$tmp'" </dev/null >/dev/null 2>&1
      else
        ${pkgs.util-linux}/bin/setsid -f ${pkgs.bash}/bin/bash -c "${pkgs.wl-clipboard}/bin/wl-copy < '$tmp'; rm -f '$tmp'" </dev/null >/dev/null 2>&1
      fi
      exit 0
    '';
  in {
    home-manager.users.sim = {
      services.cliphist = {
        enable = true;
        allowImages = true;
      };

      home.packages = [ clipPicker preview pkgs.fzf pkgs.chafa pkgs.file pkgs.ffmpeg pkgs.gnused pkgs.gnugrep ];
    };
  };
}
