{ self, inputs, ... }: {
  flake.nixosModules.fade = { pkgs, lib, ... }:
  let
    fade = pkgs.writeShellScriptBin "fade" ''
      # fade: esmBot-style fade-in that holds on the final image.
      # Forces truecolor sRGB at every stage because IM7 can otherwise quantize
      # the fade frames to a shared/greyscale palette during -layers optimize.
      set -euo pipefail

      OUTDIR="''${HOME}/Media/fade"; mkdir -p "$OUTDIR"
      FRAMES=24
      DELAY=15
      HOLD=1000

      notify() { ${pkgs.libnotify}/bin/notify-send "fade" "$1" 2>/dev/null || true; }
      die()    { notify "$1"; echo "fade: $1" >&2; exit 1; }

      mode="black"
      for a in "$@"; do
        case "$a" in
          transparent|t|trans) mode="transparent" ;;
          black|b|blk)         mode="black" ;;
          *) if printf '%s' "$a" | grep -qE '^[0-9]+$'; then FRAMES="$a"; fi ;;
        esac
      done
      [ "$FRAMES" -ge 2 ] 2>/dev/null || FRAMES=12

      TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

      types="$(${pkgs.wl-clipboard}/bin/wl-paste --list-types 2>/dev/null || true)"
      in="$TMP/in"; src=""
      if printf '%s\n' "$types" | grep -qi 'image/gif'; then
        ${pkgs.wl-clipboard}/bin/wl-paste -t image/gif > "$in.gif"; src="$in.gif"
      elif printf '%s\n' "$types" | grep -q '^text/uri-list$'; then
        first="$(${pkgs.wl-clipboard}/bin/wl-paste -t text/uri-list 2>/dev/null \
                  | tr -d '\r' | sed 's|^file://||' | head -1)"
        [ -n "$first" ] || die "empty uri-list"
        src="$(printf '%b' "''${first//%/\\x}")"
      else
        for t in image/png image/jpeg image/webp; do
          if printf '%s\n' "$types" | grep -qi "$t"; then
            ext="''${t#image/}"; ${pkgs.wl-clipboard}/bin/wl-paste -t "$t" > "$in.$ext"; src="$in.$ext"; break
          fi
        done
        [ -n "$src" ] || die "clipboard has no image or gif"
      fi
      [ -f "$src" ] || die "source not found"

      # Extract first frame and FORCE it to truecolor sRGB PNG. This strips any
      # indexed/greyscale palette the gif frame carried.
      still="$TMP/still.png"
      ${pkgs.imagemagick}/bin/magick "$src[0]" \
        -colorspace sRGB -type TrueColor -depth 8 "$still"
      W="$(${pkgs.imagemagick}/bin/identify -format '%W' "$still")"
      H="$(${pkgs.imagemagick}/bin/identify -format '%H' "$still")"

      stamp="$(date +%Y%m%d-%H%M%S)"
      out="$OUTDIR/fade-''${stamp}.gif"
      notify "fading in ($mode, $FRAMES frames)..."

      # generate frames, each explicitly truecolor sRGB
      i=0
      while [ "$i" -lt "$FRAMES" ]; do
        pct="$(${pkgs.gawk}/bin/awk -v i=$i -v n=$FRAMES 'BEGIN{printf "%d", 100*i/(n-1)}')"
        f="$TMP/f_$(printf '%04d' "$i").png"
        if [ "$mode" = "black" ]; then
          ${pkgs.imagemagick}/bin/magick -size "''${W}x''${H}" xc:black "$still" \
            -compose blend -define compose:args="$pct" -composite \
            -colorspace sRGB -type TrueColor "$f"
        else
          ${pkgs.imagemagick}/bin/magick -size "''${W}x''${H}" xc:none "$still" \
            -compose dissolve -define compose:args="$pct" -composite \
            -colorspace sRGB -type TrueColorAlpha "$f"
        fi
        i=$((i+1))
      done

      # assemble with per-frame delay; force a full 256-color palette PER FRAME
      # (not a shared greyscale one) via +map, and keep sRGB.
      lastidx=$((FRAMES-1))
      args=()
      i=0
      while [ "$i" -lt "$FRAMES" ]; do
        f="$TMP/f_$(printf '%04d' "$i").png"
        if [ "$i" -eq "$lastidx" ]; then args+=( -delay "$HOLD" "$f" )
        else args+=( -delay "$DELAY" "$f" ); fi
        i=$((i+1))
      done

      if [ "$mode" = "black" ]; then
        ${pkgs.imagemagick}/bin/magick -loop 0 "''${args[@]}" \
          -colorspace sRGB -layers optimize +map "$out" >/dev/null 2>&1 || die "assemble failed"
      else
        ${pkgs.imagemagick}/bin/magick -loop 0 -dispose Background "''${args[@]}" \
          -colorspace sRGB -layers optimize +map "$out" >/dev/null 2>&1 || die "assemble failed"
      fi
      [ -f "$out" ] || die "output not produced"

      urlencode_path() {
        local p="$1" o="" c i h
        for (( i=0; i<''${#p}; i++ )); do
          c="''${p:i:1}"
          case "$c" in
            [a-zA-Z0-9._~/-]) o+="$c" ;;
            *) printf -v h '%%%02X' "'$c"; o+="$h" ;;
          esac
        done
        printf '%s' "$o"
      }
      urifile="$(mktemp)"
      printf 'file://%s\r\n' "$(urlencode_path "$out")" > "$urifile"
      ${pkgs.util-linux}/bin/setsid -f ${pkgs.bash}/bin/bash -c \
        "${pkgs.wl-clipboard}/bin/wl-copy -t text/uri-list < '$urifile'; rm -f '$urifile'" \
        </dev/null >/dev/null 2>&1 || true

      notify "done: $(basename "$out") — copied to clipboard"
    '';
  in {
    environment.systemPackages = [
      fade
      pkgs.imagemagick pkgs.file pkgs.wl-clipboard pkgs.libnotify
      pkgs.util-linux pkgs.bash pkgs.coreutils pkgs.gnused pkgs.gawk
    ];
  };
}
