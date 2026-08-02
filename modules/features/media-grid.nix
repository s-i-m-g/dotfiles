{ self, inputs, ... }: {
  flake.nixosModules.media-grid = { pkgs, lib, ... }:
  let
    mediaGridPy = pkgs.writeText "media-grid.py" ''
#!/usr/bin/env python3
"""
media-grid: Discord-gif-picker-style justified rows of media thumbnails.
Images keep their aspect ratio at a fixed row height and pack left-to-right,
wrapping to fill the window width; rows and the whole block are centered.
Faint truncated filename under each. Kitty Unicode-placeholder graphics.

FILTER mode: type to narrow — a query containing '/' matches the path
relative to the scanned root (e.g. 'gifs/' shows only that subfolder),
otherwise it matches filenames. Enter -> NAV (hjkl/arrows). Enter -> copy
highlighted file to clipboard as text/uri-list and quit. '/'/Esc back to
FILTER; Esc in empty FILTER quits; q quits in NAV. In NAV: r renames the
highlighted file (type the new name; the extension is kept automatically),
D (shift+d) deletes it immediately. Scans CWD recursively.
"""
import os, sys, hashlib, subprocess, shutil, termios, tty, select, base64, fcntl, struct

CACHE = os.path.expanduser("~/.cache/media-grid")
THUMB_H = 300          # thumbnail pixel height (width follows aspect)
EXTS   = ("png","jpg","jpeg","webp","bmp","gif","mp4","mkv","webm","mov","avi","m4v")
VIDEXT = ("mp4","mkv","webm","mov","avi","gif","m4v")
IMAGEMAGICK = "magick" if shutil.which("magick") else "convert"

IMG_ROWS = 12      # cells tall per image row
LABEL_ROWS = 1
GAP_W = 1
GAP_H = 1
ROW_H = IMG_ROWS + LABEL_ROWS + GAP_H

PLACEHOLDER = "\U0010EEEE"
# full official kitty rowcolumn-diacritics list (297 entries)
DIAC = [
        0x0305,0x030D,0x030E,0x0310,0x0312,0x033D,0x033E,0x033F,0x0346,0x034A,
        0x034B,0x034C,0x0350,0x0351,0x0352,0x0357,0x035B,0x0363,0x0364,0x0365,
        0x0366,0x0367,0x0368,0x0369,0x036A,0x036B,0x036C,0x036D,0x036E,0x036F,
        0x0483,0x0484,0x0485,0x0486,0x0487,0x0592,0x0593,0x0594,0x0595,0x0597,
        0x0598,0x0599,0x059C,0x059D,0x059E,0x059F,0x05A0,0x05A1,0x05A8,0x05A9,
        0x05AB,0x05AC,0x05AF,0x05C4,0x0610,0x0611,0x0612,0x0613,0x0614,0x0615,
        0x0616,0x0617,0x0657,0x0658,0x0659,0x065A,0x065B,0x065D,0x065E,0x06D6,
        0x06D7,0x06D8,0x06D9,0x06DA,0x06DB,0x06DC,0x06DF,0x06E0,0x06E1,0x06E2,
        0x06E4,0x06E7,0x06E8,0x06EB,0x06EC,0x0730,0x0732,0x0733,0x0735,0x0736,
        0x073A,0x073D,0x073F,0x0740,0x0741,0x0743,0x0745,0x0747,0x0749,0x074A,
        0x07EB,0x07EC,0x07ED,0x07EE,0x07EF,0x07F0,0x07F1,0x07F3,0x0816,0x0817,
        0x0818,0x0819,0x081B,0x081C,0x081D,0x081E,0x081F,0x0820,0x0821,0x0822,
        0x0823,0x0825,0x0826,0x0827,0x0829,0x082A,0x082B,0x082C,0x082D,0x0951,
        0x0953,0x0954,0x0F82,0x0F83,0x0F86,0x0F87,0x135D,0x135E,0x135F,0x17DD,
        0x193A,0x1A17,0x1A75,0x1A76,0x1A77,0x1A78,0x1A79,0x1A7A,0x1A7B,0x1A7C,
        0x1B6B,0x1B6D,0x1B6E,0x1B6F,0x1B70,0x1B71,0x1B72,0x1B73,0x1CD0,0x1CD1,
        0x1CD2,0x1CDA,0x1CDB,0x1CE0,0x1DC0,0x1DC1,0x1DC3,0x1DC4,0x1DC5,0x1DC6,
        0x1DC7,0x1DC8,0x1DC9,0x1DCB,0x1DCC,0x1DD1,0x1DD2,0x1DD3,0x1DD4,0x1DD5,
        0x1DD6,0x1DD7,0x1DD8,0x1DD9,0x1DDA,0x1DDB,0x1DDC,0x1DDD,0x1DDE,0x1DDF,
        0x1DE0,0x1DE1,0x1DE2,0x1DE3,0x1DE4,0x1DE5,0x1DE6,0x1DFE,0x20D0,0x20D1,
        0x20D4,0x20D5,0x20D6,0x20D7,0x20DB,0x20DC,0x20E1,0x20E7,0x20E9,0x20F0,
        0x2CEF,0x2CF0,0x2CF1,0x2DE0,0x2DE1,0x2DE2,0x2DE3,0x2DE4,0x2DE5,0x2DE6,
        0x2DE7,0x2DE8,0x2DE9,0x2DEA,0x2DEB,0x2DEC,0x2DED,0x2DEE,0x2DEF,0x2DF0,
        0x2DF1,0x2DF2,0x2DF3,0x2DF4,0x2DF5,0x2DF6,0x2DF7,0x2DF8,0x2DF9,0x2DFA,
        0x2DFB,0x2DFC,0x2DFD,0x2DFE,0x2DFF,0xA66F,0xA67C,0xA67D,0xA6F0,0xA6F1,
        0xA8E0,0xA8E1,0xA8E2,0xA8E3,0xA8E4,0xA8E5,0xA8E6,0xA8E7,0xA8E8,0xA8E9,
        0xA8EA,0xA8EB,0xA8EC,0xA8ED,0xA8EE,0xA8EF,0xA8F0,0xA8F1,0xAAB0,0xAAB2,
        0xAAB3,0xAAB7,0xAAB8,0xAABE,0xAABF,0xAAC1,0xFE20,0xFE21,0xFE22,0xFE23,
        0xFE24,0xFE25,0xFE26,0x10A0F,0x10A38,0x1D185,0x1D186,0x1D187,0x1D188,
        0x1D189,0x1D1AA,0x1D1AB,0x1D1AC,0x1D1AD,0x1D242,0x1D243,0x1D244]

CSI="\033["
def w(s): sys.stdout.write(s)
def move(r,c): w(f"{CSI}{r};{c}H")
def clear_all(): w(f"{CSI}2J{CSI}H")
def delete_all_images(): w("\033_Ga=d,d=A\033\\")
def hide_cursor(): w(f"{CSI}?25l")
def show_cursor(): w(f"{CSI}?25h")

def cache_path(path):
    st=os.stat(path)
    key=f"{os.path.abspath(path)}:{st.st_mtime_ns}:h{THUMB_H}"
    return os.path.join(CACHE,hashlib.sha1(key.encode()).hexdigest()+".png")

def make_thumb(path):
    os.makedirs(CACHE,exist_ok=True)
    out=cache_path(path)
    if os.path.exists(out): return out
    tmp=out+".tmp.png"
    ext=path.lower().rsplit(".",1)[-1]
    try:
        if ext in VIDEXT:
            # ffmpeg exits 0 even when -ss seeks past the end of a short gif and
            # nothing was encoded — check the output file, not the exit code.
            subprocess.run(["ffmpeg","-y","-ss","0.5","-i",path,"-frames:v","1",
                            "-vf",f"scale=-2:{THUMB_H}",tmp],capture_output=True)
            if not (os.path.exists(tmp) and os.path.getsize(tmp) > 0):
                subprocess.run(["ffmpeg","-y","-i",path,"-frames:v","1",
                                "-vf",f"scale=-2:{THUMB_H}",tmp],
                               check=True,capture_output=True)
        else:
            subprocess.run([IMAGEMAGICK,path+"[0]","-thumbnail",f"x{THUMB_H}",tmp],
                           check=True,capture_output=True)
        os.replace(tmp,out); return out
    except Exception:
        if os.path.exists(tmp): os.remove(tmp)
        return None

def png_size(p):
    try:
        with open(p,"rb") as f: h=f.read(24)
        if h[:8]==b"\x89PNG\r\n\x1a\n":
            return struct.unpack(">II",h[16:24])
    except Exception: pass
    return None

def scan(root):
    out=[]
    for dp,_,fns in os.walk(root):
        if "/." in dp: continue
        for fn in sorted(fns):
            if fn.lower().rsplit(".",1)[-1] in EXTS:
                out.append(os.path.join(dp,fn))
    return out

def term_size():
    ts=shutil.get_terminal_size((80,24))
    return ts.columns, ts.lines

def cell_px(fd):
    """Pixel size of one terminal cell, from TIOCGWINSZ. Fallback 10x20."""
    try:
        buf=fcntl.ioctl(fd, termios.TIOCGWINSZ, b"\0"*8)
        r,c,xp,yp=struct.unpack("HHHH",buf)
        if r and c and xp and yp: return xp/c, yp/r
    except Exception: pass
    return 10.0, 20.0

def transmit(img_id, png, cols, rows):
    """Transmit data (q=2, no placement), then the a=p,U=1 virtual placement
    the placeholder cells reference."""
    with open(png,"rb") as f: data=f.read()
    b64=base64.standard_b64encode(data)
    chunks=[b64[i:i+4096] for i in range(0,len(b64),4096)]
    for i,ch in enumerate(chunks):
        more=1 if i<len(chunks)-1 else 0
        ctrl=(f"a=t,t=d,f=100,i={img_id},q=2,m={more}" if i==0 else f"m={more}")
        w("\033_G"+ctrl+";"+ch.decode("ascii")+"\033\\")
    w(f"\033_Ga=p,U=1,i={img_id},c={cols},r={rows},q=2\033\\")

def draw_placeholder(img_id, base_row, base_col, rows, cols):
    for r in range(rows):
        move(base_row+r, base_col)
        w(f"{CSI}38;5;{img_id}m")
        for c in range(cols):
            w(PLACEHOLDER+chr(DIAC[r])+chr(DIAC[c]))
        w(f"{CSI}39m")

def copy_uri(path):
    uri="file://"+"".join(ch if ch.isalnum() or ch in "._~/-" else "%%%02X"%ord(ch)
                          for ch in os.path.abspath(path))
    # DEVNULL for stdout/stderr: otherwise the lingering wl-copy holds kitty's
    # pty open and `kitty -e media-grid` never closes after selection.
    p=subprocess.Popen(["setsid","-f","wl-copy","-t","text/uri-list"],
                       stdin=subprocess.PIPE,
                       stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    p.stdin.write((uri+"\n").encode()); p.stdin.close()

def prompt_line(fd, rows_ln, label, initial=""):
    """Blocking one-line editor on the bottom row. Returns the string on Enter,
    or None on Esc. Reuses read_key so raw mode stays intact."""
    buf=list(initial)
    show_cursor()
    while True:
        body="".join(buf)
        move(rows_ln,1)
        w(f"{CSI}2K{label}{body}")
        sys.stdout.flush()
        k=read_key(fd)
        if k=="ENTER":
            hide_cursor(); return "".join(buf).strip()
        if k=="ESC":
            hide_cursor(); return None
        if k=="BACKSPACE":
            if buf: buf.pop()
        elif k and len(k)==1 and k.isprintable():
            buf.append(k)

def do_rename(path, newname):
    """Rename within the same directory. Returns (newpath, msg). newpath is
    None on failure/cancel."""
    if not newname or newname in (".",".."):
        return None,"rename cancelled"
    if "/" in newname:
        return None,"rename: no slashes allowed"
    dst=os.path.join(os.path.dirname(path), newname)
    if os.path.abspath(dst)==os.path.abspath(path):
        return path,"unchanged"
    if os.path.exists(dst):
        return None,"rename: target exists"
    try:
        os.rename(path,dst); return dst,"renamed"
    except Exception as e:
        return None,f"rename failed: {e}"

def rename_newname(path, typed):
    """Turn what the user typed (stem only, usually) into a full filename.
    If they typed their own '.', respect it; otherwise reappend the original
    extension so they never have to retype it."""
    typed=typed.strip()
    if not typed: return None
    if "." in typed: return typed
    _root, ext = os.path.splitext(os.path.basename(path))
    return typed + ext

def do_delete(path):
    try:
        os.remove(path); return True,"deleted"
    except Exception as e:
        return False,f"delete failed: {e}"

def read_key(fd):
    ch=os.read(fd,1)
    if ch==b"\033":
        r,_,_=select.select([fd],[],[],0.05)
        if not r: return "ESC"
        seq=os.read(fd,2)
        return {b"[A":"UP",b"[B":"DOWN",b"[C":"RIGHT",b"[D":"LEFT"}.get(seq,"ESC")
    if ch in (b"\r",b"\n"): return "ENTER"
    if ch==b"\x7f": return "BACKSPACE"
    try: return ch.decode()
    except: return None

def label_at(name, row, col, width, selected, navmode):
    if len(name)>width: name=(name[:max(1,width-3)]+"...")[:width]
    name=name.ljust(width)
    move(row,col)
    if selected and navmode: w(f"{CSI}7m{name}{CSI}0m")
    elif selected:           w(f"{CSI}4m{name}{CSI}0m")
    else:                    w(f"{CSI}2m{name}{CSI}0m")   # faint

def build_rows(files, total_cols, cw, ch):
    """Justified layout: pack images left-to-right at fixed IMG_ROWS height,
    width from each thumb's aspect ratio; wrap when the row is full.
    Returns list of rows; each row is a list of (file_index, x_col, w_cells)."""
    rows=[]; cur=[]; x=1
    for i,f in enumerate(files):
        th=cache_path(f)
        if not os.path.exists(th): th=make_thumb(f)
        dims=png_size(th) if th else None
        ar=(dims[0]/dims[1]) if dims and dims[1] else 16/9
        wc=max(6,int(round(ar*IMG_ROWS*ch/cw)))
        wc=min(wc,total_cols,len(DIAC))
        if cur and x+wc-1>total_cols:
            rows.append(cur); cur=[]; x=1
        cur.append((i,x,wc)); x+=wc+GAP_W
    if cur: rows.append(cur)
    return rows

def row_offset(row, total_cols):
    """Horizontal offset to center this row: half the unused width."""
    used=row[-1][1]+row[-1][2]-1
    return max(0,(total_cols-used)//2)

def row_of(rows, sel):
    for ri,row in enumerate(rows):
        for i,x,wc in row:
            if i==sel: return ri,x+wc/2
    return 0,0

def run():
    root=os.getcwd()
    allfiles=scan(root)
    query=""; sel=0; mode="filter"; top=0
    fd=sys.stdin.fileno(); old=termios.tcgetattr(fd)
    transmitted=set()
    prev_state=None
    status=""      # transient message shown after rename/delete
    try:
        tty.setraw(fd); hide_cursor()
        while True:
            cols_ln,rows_ln=term_size()
            cw,chh=cell_px(fd)
            # path-aware filter: a query containing '/' matches against the
            # path relative to root (so 'gifs/' narrows to that subfolder);
            # otherwise match filenames only.
            q=query.lower()
            if "/" in q:
                files=[f for f in allfiles
                       if q in os.path.relpath(f,root).lower()]
            else:
                files=[f for f in allfiles
                       if q in os.path.basename(f).lower()]
            if sel>=len(files): sel=max(0,len(files)-1)
            if sel<0: sel=0
            rows=build_rows(files,cols_ln,cw,chh)
            vis=max(1,(rows_ln-1)//ROW_H)
            sel_row,_=row_of(rows,sel)
            if sel_row<top: top=sel_row
            if sel_row>=top+vis: top=sel_row-vis+1
            if top>max(0,len(rows)-vis): top=max(0,len(rows)-vis)

            shown=rows[top:top+vis]
            # vertical offset to center the block of visible rows: half the
            # unused height (last row needs no trailing gap)
            used_h=len(shown)*ROW_H-GAP_H if shown else 0
            voff=max(0,((rows_ln-1)-used_h)//2)

            state=(query,top,cols_ln,rows_ln,len(files),sel if mode=="nav" else -1)
            full = state!=prev_state
            prev_state=state

            if full:
                clear_all(); delete_all_images()
                transmitted.clear()   # d=A wiped image data; must retransmit
                for vr,row in enumerate(shown):
                    base_row=voff+vr*ROW_H+1
                    hoff=row_offset(row,cols_ln)
                    for i,x,wc in row:
                        th=cache_path(files[i])
                        if not os.path.exists(th): th=make_thumb(files[i])
                        img_id=(i%255)+1
                        if th and os.path.exists(th):
                            if img_id not in transmitted:
                                transmit(img_id,th,wc,IMG_ROWS); transmitted.add(img_id)
                            draw_placeholder(img_id,base_row,x+hoff,IMG_ROWS,wc)
                        label_at(os.path.basename(files[i]),base_row+IMG_ROWS,x+hoff,wc,
                                 i==sel,mode=="nav")
            else:
                for vr,row in enumerate(shown):
                    base_row=voff+vr*ROW_H+1
                    hoff=row_offset(row,cols_ln)
                    for i,x,wc in row:
                        label_at(os.path.basename(files[i]),base_row+IMG_ROWS,x+hoff,wc,
                                 i==sel,mode=="nav")

            move(rows_ln,1)
            if mode=="filter":
                tag="type"
            else:
                tag="NAV hjkl · Enter=copy · r=rename · D=delete · / =filter"
            statusmsg=(" — "+status) if status else ""
            w(f"{CSI}2K[{tag}]{statusmsg} > {query}")
            sys.stdout.flush()
            status=""

            def vmove(d):
                nonlocal sel
                ri,cx=row_of(rows,sel)
                ti=ri+d
                if 0<=ti<len(rows):
                    best=min(rows[ti],key=lambda t:abs((t[1]+t[2]/2)-cx))
                    sel=best[0]

            k=read_key(fd)
            if mode=="filter":
                if k=="ENTER":
                    if files: mode="nav"; prev_state=None
                elif k=="ESC": break
                elif k=="BACKSPACE": query=query[:-1]; sel=0; top=0
                elif k and len(k)==1 and k.isprintable(): query+=k; sel=0; top=0
                elif k=="LEFT": sel=max(0,sel-1)
                elif k=="RIGHT": sel=min(len(files)-1,sel+1)
                elif k=="UP": vmove(-1)
                elif k=="DOWN": vmove(1)
            else:
                if k=="ENTER":
                    if files: copy_uri(files[sel]); break
                elif k in ("ESC","/"): mode="filter"; prev_state=None
                elif k=="q": break
                elif k in ("LEFT","h"): sel=max(0,sel-1)
                elif k in ("RIGHT","l"): sel=min(len(files)-1,sel+1)
                elif k in ("UP","k"): vmove(-1)
                elif k in ("DOWN","j"): vmove(1)
                elif k=="r":
                    if files:
                        cur=files[sel]
                        # empty prompt (name cleared); the extension label shows
                        # what will be appended so you only type the new stem.
                        _root,ext=os.path.splitext(os.path.basename(cur))
                        typed=prompt_line(fd,rows_ln,f"rename> (keeps {ext or 'no ext'}) ","")
                        if typed is not None:
                            newname=rename_newname(cur,typed)
                            if newname is None:
                                status="rename cancelled"
                            else:
                                newpath,msg=do_rename(cur,newname)
                                allfiles=scan(root)
                                if newpath and os.path.exists(newpath):
                                    try: sel=allfiles.index(newpath)
                                    except ValueError: pass
                                status=msg
                        else:
                            status="rename cancelled"
                        prev_state=None
                elif k=="D":
                    if files:
                        ok,msg=do_delete(files[sel])
                        allfiles=scan(root)
                        status=msg
                        prev_state=None
    finally:
        show_cursor(); termios.tcsetattr(fd,termios.TCSADRAIN,old)
        clear_all(); delete_all_images(); move(1,1); sys.stdout.flush()

if __name__=="__main__":
    run()

    '';

    mediaGrid = pkgs.writeShellScriptBin "media-grid" ''
      # media-grid: Discord-gif-picker-style justified rows of media thumbnails
      # with a type-to-filter box, using kitty's Unicode placeholder graphics.
      # Type to filter; Enter -> hjkl nav; Enter again -> copy as uri-list & close.
      # In nav: r renames (extension kept automatically), D (shift+d) deletes now.
      export PATH="${lib.makeBinPath [
        pkgs.ffmpeg pkgs.imagemagick pkgs.wl-clipboard pkgs.util-linux pkgs.kitty pkgs.coreutils
      ]}:$PATH"
      exec ${pkgs.python3}/bin/python3 ${mediaGridPy}
    '';

    mediaGridFloat = pkgs.writeShellScriptBin "media-grid-float" ''
      dir="''${1:-$HOME/Media}"
      exec ${pkgs.kitty}/bin/kitty --class mediagrid --directory "$dir" \
        -e ${mediaGrid}/bin/media-grid
    '';
  in {
    environment.systemPackages = [
      mediaGrid mediaGridFloat
      pkgs.ffmpeg pkgs.imagemagick pkgs.wl-clipboard pkgs.util-linux pkgs.kitty pkgs.python3
    ];
  };
}
