{ self, inputs, ... }:
{
  flake.nixosModules.speech-bubble = { pkgs, lib, ... }:
  let
    pickerRaw = pkgs.writers.writePython3Bin "speech-bubble-pick"
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

        # two clicks: 1st = tail base (start), 2nd = tail tip (end)
        clicks = []

        win = Gtk.Window(title="click 1: tail start   ·   click 2: tail end")
        win.set_default_size(dw, dh)
        win.set_resizable(False)

        ev = Gtk.EventBox()
        img = Gtk.Image.new_from_pixbuf(pb)
        ev.add(img)
        win.add(ev)


        def on_click(_w, e):
            ix = int(e.x / scale)
            iy = int(e.y / scale)
            ix = max(0, min(iw - 1, ix))
            iy = max(0, min(ih - 1, iy))
            clicks.append((ix, iy))
            if len(clicks) >= 2:
                Gtk.main_quit()


        def on_key(_w, e):
            if e.keyval == Gdk.KEY_Escape:
                Gtk.main_quit()


        ev.connect("button-press-event", on_click)
        win.connect("key-press-event", on_key)
        win.connect("destroy", Gtk.main_quit)
        win.show_all()
        Gtk.main()

        if len(clicks) < 2:
            sys.exit(1)
        print("%d %d %d %d" % (clicks[0][0], clicks[0][1], clicks[1][0], clicks[1][1]))
      '';

    # Wrap the raw script with wrapGAppsHook3, which auto-collects the full
    # GI_TYPELIB_PATH chain (Gtk, Gdk, Pango, HarfBuzz, cairo, ...) so
    # gi.require_version finds every namespace.
    picker = pkgs.stdenv.mkDerivation {
      name = "speech-bubble-pick";
      dontUnpack = true;
      nativeBuildInputs = [ pkgs.wrapGAppsHook3 pkgs.gobject-introspection ];
      buildInputs = [ pkgs.gtk3 pkgs.gdk-pixbuf pkgs.pango pkgs.glib pkgs.librsvg ];
      installPhase = ''
        mkdir -p $out/bin
        cp ${pickerRaw}/bin/speech-bubble-pick $out/bin/speech-bubble-pick
        chmod +x $out/bin/speech-bubble-pick
      '';
    };

    speech-bubble = pkgs.writeShellScriptBin "speech-bubble" ''
      set -euo pipefail
      export PATH=${lib.makeBinPath (with pkgs; [ imagemagick wl-clipboard coreutils findutils gnused gawk libnotify ])}:$PATH

      OUTDIR="$HOME/Media/speech"
      mkdir -p "$OUTDIR"

      TMP="$(mktemp -d)"
      trap 'rm -rf "$TMP"' EXIT

      # --- read gif from clipboard (raw image bytes, or uri-list path) ---
      types="$(wl-paste --list-types 2>/dev/null || true)"
      in_gif="$TMP/in.gif"

      if printf '%s\n' "$types" | grep -qi 'image/gif'; then
        wl-paste -t image/gif > "$in_gif"
      elif printf '%s\n' "$types" | grep -qi 'text/uri-list'; then
        uri="$(wl-paste -t text/uri-list | tr -d '\r' | head -1)"
        path="''${uri#file://}"
        path="$(printf '%b' "''${path//%/\\x}")"
        cp "$path" "$in_gif"
      else
        notify-send "speech-bubble" "clipboard has no gif (image/gif or uri-list)"
        exit 1
      fi

      if ! identify -format '%m\n' "$in_gif" 2>/dev/null | head -1 | grep -qi gif; then
        notify-send "speech-bubble" "clipboard content is not a gif"
        exit 1
      fi

      # --- dimensions (first frame only; \n so multi-frame gifs don't concatenate) ---
      W="$(identify -format '%W\n' "$in_gif" | head -1)"
      H="$(identify -format '%H\n' "$in_gif" | head -1)"

      if ! printf '%s' "$W" | grep -qE '^[0-9]+$' || ! printf '%s' "$H" | grep -qE '^[0-9]+$'; then
        notify-send "speech-bubble" "could not read gif dimensions ($W x $H)"
        exit 1
      fi

      # --- first frame -> picker, get TWO clicks:
      #     click 1 = tail start (base x on the arc), click 2 = tail end (tip x,y) ---
      magick "$in_gif[0]" "$TMP/frame0.png"
      if ! click="$(${picker}/bin/speech-bubble-pick "$TMP/frame0.png")"; then
        notify-send "speech-bubble" "cancelled"
        exit 0
      fi
      read BASE_X BASE_Y CLICK_X CLICK_Y <<< "$click"

      # --- full-width shallow arc; skinny tail. Base is centered on the FIRST
      #     click's x (clamped on-frame); tip is the SECOND click. ---
      CX=$(( W / 2 )); CY=0
      RX=$(( W * 62 / 100 ))
      RY=$(( H * 9 / 100 ))
      BASE_W=60

      read TAIL_AX TAIL_AY TAIL_BX TAIL_BY <<< "$(awk -v cx=$CX -v rx=$RX -v ry=$RY -v basex=$BASE_X -v bw=$BASE_W -v w=$W 'BEGIN{
        half=bw/2; margin=2;
        lo=margin+half; hi=w-margin-half;
        basec = basex;
        if(basec < lo) basec = lo;
        if(basec > hi) basec = hi;
        ax = basec - half; bx = basec + half;
        dxa=(ax-cx)/rx; va=1-dxa*dxa; if(va<0)va=0; ay=ry*sqrt(va);
        dxb=(bx-cx)/rx; vb=1-dxb*dxb; if(vb<0)vb=0; by=ry*sqrt(vb);
        printf "%d %d %d %d", ax, ay, bx, by;
      }')"

      # mask: black = carve to transparent, white = keep
      mask="$TMP/mask.png"
      magick -size "''${W}x''${H}" xc:white -fill black \
        -draw "ellipse $CX,$CY $RX,$RY 0,360" \
        -draw "polygon $TAIL_AX,$TAIL_AY $TAIL_BX,$TAIL_BY $CLICK_X,$CLICK_Y" \
        "$mask"

      # --- carve every frame in PARALLEL (IM6 -layers Composite can't apply
      #     CopyOpacity across a real multi-frame gif, so we carve per-frame;
      #     xargs -P$(nproc) spreads it across all cores instead of one at a time) ---
      magick "$in_gif" -coalesce "$TMP/f_%05d.png"
      printf '%s\n' "$TMP"/f_*.png | xargs -P"$(nproc)" -I{} \
        magick {} "$mask" -alpha off -compose CopyOpacity -composite {}

      out="$TMP/out.gif"
      magick -dispose Background "$TMP"/f_*.png -layers optimize "$out"

      # --- save into Media/speech with a timestamped name, then copy as uri-list ---
      final="$OUTDIR/speech-$(date +%Y%m%d-%H%M%S).gif"
      cp "$out" "$final"

      enc="$(printf '%s' "$final" | sed -e 's/%/%25/g' -e 's/ /%20/g')"
      uri="file://$enc"
      keep="$TMP/uri"
      printf '%s\r\n' "$uri" > "$keep"

      setsid -f bash -c "wl-copy -t text/uri-list < '$keep'" >/dev/null 2>&1

      notify-send "speech-bubble" "carved-bubble gif on clipboard"
    '';
  in
  {
    environment.systemPackages = [ speech-bubble ];
  };
}
