{ self, inputs, ... }: {
  flake.nixosModules.remove-caption = { pkgs, lib, ... }:
  let
    removeCaptionPy = pkgs.writeText "remove-caption.py" ''
#!/usr/bin/env python3
"""
remove-caption: strip a top caption bar added by caption-gif.

The caption bar is a flat background (white) with centered, padded text, so the
LEFT edge of every caption row is pure background — the text never reaches x=0.
We read the first pixel of each row top-down on frame 0; while it matches the
top-left pixel (within a small tolerance for GIF quantization), we're still in
the caption. The first row whose left pixel differs is where the real gif begins.
Crop every frame from that row down.
"""
import os, sys, subprocess, re, tempfile
from datetime import datetime

def sh(*a, **k): return subprocess.run(a, capture_output=True, text=True, **k)

def notify(msg):
    subprocess.run(["notify-send", "remove-caption", msg],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def die(msg):
    notify(msg); print("remove-caption:", msg, file=sys.stderr); sys.exit(1)

def clip_src():
    """Resolve a gif path from the clipboard: uri-list first, then raw image."""
    types = sh("wl-paste", "--list-types").stdout
    if "text/uri-list" in types:
        lines = sh("wl-paste", "-t", "text/uri-list").stdout.replace("\r", "").splitlines()
        first = lines[0] if lines else ""
        if not first:
            die("empty uri-list on clipboard")
        p = first[len("file://"):] if first.startswith("file://") else first
        p = re.sub(r"%([0-9A-Fa-f]{2})", lambda m: chr(int(m.group(1), 16)), p)
        return p
    for line in types.splitlines():
        if line.startswith("image/"):
            ext = line.split("/", 1)[1].strip()
            tmp = tempfile.mktemp(suffix="." + ext)
            with open(tmp, "wb") as f:
                f.write(subprocess.run(["wl-paste", "-t", line.strip()],
                                       capture_output=True).stdout)
            return tmp
    die("clipboard has no gif (uri-list or image/*)")

def left_column(path):
    """Return {y: (r,g,b)} for x=0 of frame 0, at full resolution."""
    out = sh("convert", f"{path}[0]", "-depth", "8", "txt:-").stdout
    left = {}
    for line in out.splitlines():
        m = re.match(r"\s*(\d+),(\d+):\s*\(([^)]+)\)", line)
        if not m:
            continue
        x, y = int(m.group(1)), int(m.group(2))
        if x == 0:
            vals = [int(v) for v in m.group(3).split(",")[:3]]
            left[y] = tuple(vals)
    return left

def content_start(left, tol=18):
    ys = sorted(left)
    if not ys:
        return None
    top = left[ys[0]]
    for y in ys:
        if any(abs(a - b) > tol for a, b in zip(left[y], top)):
            return y
    return None

def urlencode(path):
    keep = "._~/-"
    return "".join(c if c.isalnum() or c in keep else "%%%02X" % ord(c) for c in path)

def main():
    src = clip_src()
    if not os.path.isfile(src):
        die(f"not a file: {src}")

    Wh = sh("identify", "-format", "%W %H", f"{src}[0]").stdout.split()
    if len(Wh) < 2:
        die("couldn't read dimensions")
    W, H = int(Wh[0]), int(Wh[1])

    left = left_column(src)
    y0 = content_start(left)
    if not y0 or y0 <= 0:
        die("no caption detected (top row already differs)")
    if y0 >= H - 2:
        die("detected caption fills the image? aborting")

    outdir = os.path.expanduser("~/Media/uncaptioned")
    os.makedirs(outdir, exist_ok=True)
    out = os.path.join(outdir, "uncap-" + datetime.now().strftime("%Y%m%d-%H%M%S") + ".gif")

    ch = H - y0
    r = sh("convert", src, "-coalesce",
           "-crop", f"{W}x{ch}+0+{y0}", "+repage",
           "-layers", "optimize", out)
    if r.returncode != 0 or not os.path.isfile(out):
        die("crop failed")

    uri = "file://" + urlencode(os.path.abspath(out))
    urifile = tempfile.mktemp()
    with open(urifile, "w") as f:
        f.write(uri + "\r\n")
    subprocess.Popen(
        ["setsid", "-f", "bash", "-c",
         f"wl-copy -t text/uri-list < '{urifile}'; rm -f '{urifile}'"],
        stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    notify(f"caption removed ({y0}px)")

if __name__ == "__main__":
    main()
    '';

    removeCaption = pkgs.writeShellScriptBin "remove-caption" ''
      export PATH="${lib.makeBinPath [
        pkgs.imagemagick pkgs.wl-clipboard pkgs.util-linux pkgs.bash
        pkgs.libnotify pkgs.coreutils
      ]}:$PATH"
      exec ${pkgs.python3}/bin/python3 ${removeCaptionPy}
    '';
  in {
    environment.systemPackages = [
      removeCaption
      pkgs.imagemagick pkgs.wl-clipboard pkgs.util-linux pkgs.bash
      pkgs.libnotify pkgs.python3
    ];
  };
}
