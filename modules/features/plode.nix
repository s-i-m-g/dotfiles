{ self, inputs, ... }: {
  flake.nixosModules.plode = { pkgs, lib, ... }:
  let
    # Window 1: bare image, click the plode center. Prints "IMGX IMGY".
    clickRaw = pkgs.writers.writePython3Bin "plode-click"
      { libraries = with pkgs.python3Packages; [ pygobject3 ];
        flakeIgnore = [ "E501" "E402" "E265" "E302" "E305" "E303" ]; }
      ''
        import sys
        import gi
        gi.require_version("Gtk", "3.0")
        gi.require_version("GdkPixbuf", "2.0")
        from gi.repository import Gtk, GdkPixbuf, Gdk


        src = sys.argv[1]
        pb_full = GdkPixbuf.Pixbuf.new_from_file(src)
        iw, ih = pb_full.get_width(), pb_full.get_height()

        disp = Gdk.Display.get_default()
        mon = disp.get_monitor(0).get_geometry()
        maxw, maxh = int(mon.width * 0.8), int(mon.height * 0.8)
        scale = min(maxw / iw, maxh / ih, 1.0)
        dw, dh = int(iw * scale), int(ih * scale)
        pb = pb_full.scale_simple(dw, dh, GdkPixbuf.InterpType.BILINEAR)

        result = {"xy": None}

        win = Gtk.Window(title="click the plode center")
        win.set_default_size(dw, dh)
        win.set_resizable(False)

        ev = Gtk.EventBox()
        img = Gtk.Image.new_from_pixbuf(pb)
        ev.add(img)
        win.add(ev)


        def on_click(_w, e):
            ix = max(0, min(iw - 1, int(e.x / scale)))
            iy = max(0, min(ih - 1, int(e.y / scale)))
            result["xy"] = (ix, iy)
            Gtk.main_quit()


        def on_key(_w, e):
            if e.keyval == Gdk.KEY_Escape:
                Gtk.main_quit()


        ev.connect("button-press-event", on_click)
        win.connect("key-press-event", on_key)
        win.connect("destroy", Gtk.main_quit)
        win.show_all()
        Gtk.main()

        if result["xy"] is None:
            sys.exit(1)
        print("%d %d" % result["xy"])
      '';

    clickPicker = pkgs.stdenv.mkDerivation {
      name = "plode-click";
      dontUnpack = true;
      nativeBuildInputs = [ pkgs.wrapGAppsHook3 pkgs.gobject-introspection ];
      buildInputs = [ pkgs.gtk3 pkgs.gdk-pixbuf pkgs.pango pkgs.glib pkgs.librsvg ];
      installPhase = ''
        mkdir -p $out/bin
        cp ${clickRaw}/bin/plode-click $out/bin/plode-click
        chmod +x $out/bin/plode-click
      '';
    };

    # Value reader inside the kitty terminal. Blank window — just reads a line and
    # writes it to $1 (kitty -e can't return stdout, so we pass it via a file).
    valueReader = pkgs.writeShellScriptBin "plode-value-reader" ''
      set -euo pipefail
      outfile="$1"
      IFS= read -r value || exit 0
      printf '%s' "$value" > "$outfile"
    '';

    plode = pkgs.writeShellScriptBin "plode" ''
      # plode: esmBot-style implode/explode with a CLICKED center.
      # Window 1 (bare GTK image): click where the effect originates.
      # Window 2 (blank floating kitty): type strength — POSITIVE = explode
      # (bulge out), NEGATIVE = implode (suck in).
      # We composite the frame onto a transparent canvas sized so the click becomes
      # the center, run -implode (negated for our sign), then crop back.
      set -euo pipefail

      OUTDIR="''${HOME}/Media/plode"; mkdir -p "$OUTDIR"
      notify() { ${pkgs.libnotify}/bin/notify-send "plode" "$1" 2>/dev/null || true; }
      die()    { notify "$1"; echo "plode: $1" >&2; exit 1; }

      TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

      # --- read gif/image from clipboard ---
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

      # --- window 1: click center (GTK) ---
      ${pkgs.imagemagick}/bin/magick "$src[0]" "$TMP/frame0.png"
      if ! xy="$(${clickPicker}/bin/plode-click "$TMP/frame0.png")"; then
        notify "cancelled"; exit 0
      fi
      read CX CY <<< "$xy"

      # --- window 2: value (blank floating kitty). kitty -e can't return stdout,
      # so the reader writes the value into $valfile, read after kitty exits. ---
      valfile="$TMP/value"
      : > "$valfile"
      ${pkgs.kitty}/bin/kitty --class plodevalue \
        -o initial_window_width=20c -o initial_window_height=3c \
        -e ${valueReader}/bin/plode-value-reader "$valfile" || true
      VAL="$(cat "$valfile" 2>/dev/null || true)"
      [ -n "$VAL" ] || { notify "cancelled"; exit 0; }
      printf '%s' "$VAL" | grep -qE '^-?[0-9]+(\.[0-9]+)?$' || die "invalid value: '$VAL'"

      # sign convention: positive=explode -> negative -implode
      amt="$(${pkgs.gawk}/bin/awk "BEGIN{printf \"%.4f\", -1*$VAL}")"

      W="$(${pkgs.imagemagick}/bin/identify -format '%W' "$src[0]")"
      H="$(${pkgs.imagemagick}/bin/identify -format '%H' "$src[0]")"

      hw="$(${pkgs.gawk}/bin/awk -v c=$CX -v w=$W 'BEGIN{a=c;b=w-c;print (a>b)?a:b}')"
      hh="$(${pkgs.gawk}/bin/awk -v c=$CY -v h=$H 'BEGIN{a=c;b=h-c;print (a>b)?a:b}')"
      newW=$((2*hw)); newH=$((2*hh))
      px="$(${pkgs.gawk}/bin/awk -v n=$newW -v c=$CX 'BEGIN{print int(n/2 - c)}')"
      py="$(${pkgs.gawk}/bin/awk -v n=$newH -v c=$CY 'BEGIN{print int(n/2 - c)}')"

      mime="$(${pkgs.file}/bin/file --mime-type -b "$src")"
      stamp="$(date +%Y%m%d-%H%M%S)"

      if ${pkgs.gawk}/bin/awk "BEGIN{exit !($VAL>0)}"; then eff="explode $VAL"
      elif ${pkgs.gawk}/bin/awk "BEGIN{exit !($VAL<0)}"; then eff="implode $VAL"
      else eff="none"; fi

      case "$mime" in
        image/gif)
          out="$OUTDIR/plode-''${stamp}.gif"
          notify "$eff at $CX,$CY on gif..."
          ${pkgs.imagemagick}/bin/magick "$src" -coalesce "$TMP/f_%04d.png"
          for f in "$TMP"/f_*.png; do
            ${pkgs.imagemagick}/bin/magick \
              \( -size "''${newW}x''${newH}" xc:none \) "$f" -geometry "+''${px}+''${py}" -composite \
              -virtual-pixel none -implode "$amt" \
              -crop "''${W}x''${H}+''${px}+''${py}" +repage "$f" >/dev/null 2>&1
          done
          ${pkgs.imagemagick}/bin/magick -dispose Background "$TMP"/f_*.png -layers optimize "$out" \
            >/dev/null 2>&1 || die "plode failed"
          ;;
        image/*)
          out="$OUTDIR/plode-''${stamp}.png"
          notify "$eff at $CX,$CY on image..."
          ${pkgs.imagemagick}/bin/magick \
            \( -size "''${newW}x''${newH}" xc:none \) "$src" -geometry "+''${px}+''${py}" -composite \
            -virtual-pixel none -implode "$amt" \
            -crop "''${W}x''${H}+''${px}+''${py}" +repage \
            "$out" >/dev/null 2>&1 || die "plode failed"
          ;;
        *) die "not an image or gif: $mime" ;;
      esac
      [ -f "$out" ] || die "output not produced"

      # --- write back as percent-encoded uri-list ---
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
      plode
      pkgs.imagemagick pkgs.file pkgs.wl-clipboard pkgs.libnotify
      pkgs.util-linux pkgs.bash pkgs.coreutils pkgs.gnused pkgs.gawk pkgs.kitty
    ];
  };
}
