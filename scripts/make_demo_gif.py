#!/usr/bin/env python3
"""Build demo media from real Finder + NyaTerm captures.

Outputs (under assets/):
  openinyaterm-demo.gif  — README default (ffmpeg palettegen, sharpest GIF)
  openinyaterm-demo.mp4  — true-color H.264 (for local / site use)
  openinyaterm-demo.png  — static 3-panel storyboard (always sharp)

Sources (assets/sources/):
  finder-window.png  — Finder with OpenInNyaTerm already on the toolbar
  nyaterm-window.png — NyaTerm at the same path

  python3 scripts/make_demo_gif.py

Note: do NOT composite a fake toolbar icon — the capture already includes it.
"""

from __future__ import annotations

import shutil
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "sources"
OUT_DIR = ROOT / "assets"
FINDER = SRC / "finder-window.png"
NYATERM = SRC / "nyaterm-window.png"

# Balance sharpness vs file size for GitHub README
CANVAS_W, CANVAS_H = 1100, 700
FPS = 12
HNE = "/System/Library/Fonts/HelveticaNeue.ttc"
SHADOW_PAD = 28


def load_font(size: int, index: int = 0) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(HNE, size, index=index)


F_CAP = load_font(18, 10)
F_FOOT = load_font(13, 0)
F_LABEL = load_font(14, 10)
F_PANEL = load_font(16, 10)


def tsize(d: ImageDraw.ImageDraw, text: str, f: ImageFont.ImageFont) -> tuple[int, int]:
    b = d.textbbox((0, 0), text, font=f)
    return b[2] - b[0], b[3] - b[1]


def trim_letterbox(im: Image.Image, threshold: int = 10) -> Image.Image:
    rgba = im.convert("RGBA")
    a = list(rgba.getchannel("A").get_flattened_data())
    g = list(rgba.convert("L").get_flattened_data())
    w, h = rgba.size
    xs: list[int] = []
    ys: list[int] = []
    for i, (av, gv) in enumerate(zip(a, g)):
        if av > 8 and gv > threshold:
            xs.append(i % w)
            ys.append(i // w)
    if not xs:
        return rgba
    pad = 6
    return rgba.crop(
        (
            max(0, min(xs) - pad),
            max(0, min(ys) - pad),
            min(w, max(xs) + 1 + pad),
            min(h, max(ys) + 1 + pad),
        )
    )


def round_mask(im: Image.Image, radius: int = 18) -> Image.Image:
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, im.size[0] - 1, im.size[1] - 1], radius=radius, fill=255
    )
    out = im.convert("RGBA")
    r, g, b, a = out.split()
    a = Image.composite(a, Image.new("L", im.size, 0), mask)
    return Image.merge("RGBA", (r, g, b, a))


def with_shadow(im: Image.Image, blur: int = 18) -> Image.Image:
    pad = SHADOW_PAD
    canvas = Image.new("RGBA", (im.size[0] + pad * 2, im.size[1] + pad * 2 + 10), (0, 0, 0, 0))
    sh = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle(
        [pad, pad + 8, pad + im.size[0], pad + 8 + im.size[1]],
        20,
        fill=(0, 0, 0, 120),
    )
    canvas = Image.alpha_composite(canvas, sh.filter(ImageFilter.GaussianBlur(blur)))
    canvas.paste(im, (pad, pad), im)
    return canvas


def fit(im: Image.Image, max_w: int, max_h: int) -> Image.Image:
    r = min(max_w / im.size[0], max_h / im.size[1], 1.0)  # never upscale
    if r >= 0.999:
        return im
    nw, nh = max(1, int(im.size[0] * r)), max(1, int(im.size[1] * r))
    return im.resize((nw, nh), Image.Resampling.LANCZOS)


def make_desktop() -> Image.Image:
    img = Image.new("RGB", (CANVAS_W, CANVAS_H), (24, 28, 26))
    d = ImageDraw.Draw(img)
    for y in range(CANVAS_H):
        t = y / max(CANVAS_H - 1, 1)
        c = int(18 + 12 * (1 - t))
        d.line([(0, y), (CANVAS_W, y)], fill=(c, c + 3, c + 1))
    return img.convert("RGBA")


def caption(base: Image.Image, text: str) -> None:
    d = ImageDraw.Draw(base)
    tw, th = tsize(d, text, F_CAP)
    x = (CANVAS_W - tw) // 2
    y = CANVAS_H - 48
    d.rounded_rectangle(
        [x - 18, y - 10, x + tw + 18, y + th + 10],
        16,
        fill=(12, 14, 18, 235),
    )
    d.text((x, y), text, font=F_CAP, fill=(240, 242, 246))


def footer(base: Image.Image) -> None:
    d = ImageDraw.Draw(base)
    text = "OpenInNyaTerm  |  Finder to NyaTerm"
    tw, th = tsize(d, text, F_FOOT)
    d.text((CANVAS_W - tw - 16, CANVAS_H - th - 12), text, font=F_FOOT, fill=(140, 146, 156))


def cursor(base: Image.Image, x: int, y: int, click: bool = False) -> None:
    d = ImageDraw.Draw(base)
    pts = [
        (x, y),
        (x, y + 20),
        (x + 5, y + 15),
        (x + 9, y + 24),
        (x + 13, y + 23),
        (x + 8, y + 13),
        (x + 16, y + 13),
    ]
    d.polygon([(a + 1, b + 2) for a, b in pts], fill=(0, 0, 0, 130))
    d.polygon(pts, fill=(255, 255, 255), outline=(16, 16, 18))
    if click:
        ov = Image.new("RGBA", base.size, (0, 0, 0, 0))
        od = ImageDraw.Draw(ov)
        od.ellipse([x - 20, y - 20, x + 20, y + 20], outline=(10, 132, 255, 210), width=3)
        od.ellipse([x - 10, y - 10, x + 10, y + 10], fill=(10, 132, 255, 70))
        base.alpha_composite(ov)


def find_openinyaterm_toolbar_icon(finder: Image.Image) -> tuple[int, int]:
    """Locate the real OpenInNyaTerm toolbar icon already present in the capture.

    On Sequoia Finder it is the first custom toolbar button after the window
    title — a rounded square with a ``>_`` glyph (template gray).
    """
    rgb = finder.convert("RGB")
    w, h = rgb.size
    # Title-bar strip
    y0, y1 = int(h * 0.02), int(h * 0.09)
    # Icons sit right of the path title (~45%..90% of width)
    x0, x1 = int(w * 0.45), int(w * 0.90)
    strip = rgb.crop((x0, y0, x1, y1))
    sw, sh = strip.size
    mid = sh // 2

    # Column "activity": brighter glyph pixels on dark bar
    scores: list[tuple[float, int]] = []
    for x in range(sw):
        col = [sum(strip.getpixel((x, y))) / 3 for y in range(max(0, mid - 18), min(sh, mid + 18))]
        if not col:
            continue
        mean = sum(col) / len(col)
        peak = max(col) - min(col)
        scores.append((peak + mean * 0.05, x))

    # Keep high-activity columns and cluster them into icon slots
    thr = sorted(s for s, _ in scores)[int(len(scores) * 0.82)] if scores else 0
    xs = [x for s, x in scores if s >= thr]
    if not xs:
        # Fallback: measured position for current finder-window.png
        return int(w * 0.514), int(h * 0.041)

    clusters: list[tuple[int, int]] = []
    start = prev = xs[0]
    for x in xs[1:]:
        if x - prev > 12:
            clusters.append((start, prev))
            start = x
        prev = x
    clusters.append((start, prev))

    # Prefer compact icon-sized clusters (~24–56 px at source scale)
    icon_clusters = [(a, b) for a, b in clusters if 18 <= (b - a) <= 70]
    if not icon_clusters:
        icon_clusters = clusters

    # First toolbar custom icon after the title = OpenInNyaTerm
    a, b = icon_clusters[0]
    cx = x0 + (a + b) // 2
    cy = y0 + mid
    return cx, cy


def draw_callout(base: Image.Image, cx: int, cy: int, text: str = "OpenInNyaTerm") -> None:
    """Label the existing toolbar icon (does not draw a fake icon)."""
    d = ImageDraw.Draw(base)
    tw, th = tsize(d, text, F_LABEL)
    x = cx - tw // 2
    y = cy + 26
    d.rounded_rectangle([x - 10, y - 5, x + tw + 10, y + th + 5], 9, fill=(10, 132, 255, 225))
    d.text((x, y), text, font=F_LABEL, fill=(255, 255, 255))
    d.polygon([(cx - 6, y - 5), (cx + 6, y - 5), (cx, y - 12)], fill=(10, 132, 255, 225))


def nf(ms: int) -> int:
    return max(1, round(ms * FPS / 1000))


def ease(t: float) -> float:
    return 1 - (1 - t) ** 3


def build_frames() -> list[Image.Image]:
    if not FINDER.exists() or not NYATERM.exists():
        raise SystemExit(
            f"Missing source captures.\n  expected: {FINDER}\n           {NYATERM}"
        )

    finder_raw = trim_letterbox(Image.open(FINDER))
    nyaterm_raw = trim_letterbox(Image.open(NYATERM), threshold=6)

    # Use the real toolbar icon already in the Finder capture — never paste a fake one
    icon_center = find_openinyaterm_toolbar_icon(finder_raw)

    finder = with_shadow(round_mask(finder_raw))
    nyaterm = with_shadow(round_mask(nyaterm_raw))
    # Keep windows large on canvas to preserve text sharpness
    finder_s = fit(finder, 780, 560)
    nyaterm_s = fit(nyaterm, 640, 520)
    desktop = make_desktop()

    scale_f = finder_s.size[0] / finder.size[0]
    fx0 = (CANVAS_W - finder_s.size[0]) // 2
    fy0 = (CANVAS_H - finder_s.size[1]) // 2 - 22
    icon_canvas = (
        fx0 + int((icon_center[0] + SHADOW_PAD) * scale_f),
        fy0 + int((icon_center[1] + SHADOW_PAD) * scale_f),
    )

    frames: list[Image.Image] = []

    def scene_finder(
        cx: int,
        cy: int,
        cap: str,
        *,
        click: bool = False,
        callout: bool = False,
    ) -> Image.Image:
        img = desktop.copy()
        img.paste(finder_s, (fx0, fy0), finder_s)
        if callout:
            draw_callout(img, icon_canvas[0], icon_canvas[1])
        caption(img, cap)
        footer(img)
        cursor(img, cx, cy, click=click)
        return img

    cx0 = fx0 + finder_s.size[0] // 2
    cy0 = fy0 + int(finder_s.size[1] * 0.50)
    frames.extend(
        [scene_finder(cx0, cy0, "Finder is on the project folder").convert("RGB")] * nf(1100)
    )

    tb_x, tb_y = icon_canvas
    steps = nf(850)
    for i in range(steps):
        t = ease(i / max(steps - 1, 1))
        x = int(cx0 + (tb_x - cx0) * t)
        y = int(cy0 + (tb_y - cy0) * t)
        frames.append(
            scene_finder(
                x, y, "Click OpenInNyaTerm on the Finder toolbar", callout=True
            ).convert("RGB")
        )

    frames.extend(
        [
            scene_finder(
                tb_x, tb_y, "Click OpenInNyaTerm on the Finder toolbar", callout=True
            ).convert("RGB")
        ]
        * nf(300)
    )
    for _ in range(nf(280)):
        frames.append(
            scene_finder(
                tb_x, tb_y, "One click opens NyaTerm here", click=True, callout=True
            ).convert("RGB")
        )
    frames.extend(
        [scene_finder(tb_x, tb_y, "One click opens NyaTerm here", callout=True).convert("RGB")]
        * nf(180)
    )

    steps = nf(800)
    for i in range(steps):
        t = ease(i / max(steps - 1, 1))
        img = desktop.copy()
        fl = fit(finder, int(620 + 240 * (1 - t)), int(500 + 140 * (1 - t)))
        fx2 = int(24 + 48 * (1 - t))
        fy2 = (CANVAS_H - fl.size[1]) // 2 - 18
        img.paste(fl, (fx2, fy2), fl)

        ot = fit(nyaterm, int(600 + 140 * t), int(480 + 100 * t))
        ox = int(CANVAS_W - ot.size[0] - 28 + 140 * (1 - t))
        oy = (CANVAS_H - ot.size[1]) // 2 - 8
        if t > 0.05:
            img.paste(ot, (ox, oy), ot)
        caption(img, "NyaTerm opens at the same path")
        footer(img)
        frames.append(img.convert("RGB"))

    fl = fit(finder, 580, 480)
    fx_hold, fy_hold = 28, (CANVAS_H - fl.size[1]) // 2 - 18
    ox_hold = CANVAS_W - nyaterm_s.size[0] - 28
    oy_hold = (CANVAS_H - nyaterm_s.size[1]) // 2 - 8

    for text, hold_ms in (
        ("cwd = ~/Documents/SideProjects/openinyaterm", 1500),
        ("Running: new tab  |  Not running: launch", 1600),
    ):
        img = desktop.copy()
        img.paste(fl, (fx_hold, fy_hold), fl)
        img.paste(nyaterm_s, (ox_hold, oy_hold), nyaterm_s)
        caption(img, text)
        footer(img)
        frames.extend([img.convert("RGB")] * nf(hold_ms))

    return frames


def key_story_frames(frames: list[Image.Image]) -> list[Image.Image]:
    """Three representative frames for the static storyboard."""
    n = len(frames)
    return [frames[0], frames[n // 3], frames[-1]]


def write_static_storyboard(frames: list[Image.Image], out: Path) -> None:
    """Always-sharp 3-panel PNG — best quality for GitHub README."""
    panels = key_story_frames(frames)
    labels = [
        "1. Finder on folder",
        "2. Click toolbar icon",
        "3. NyaTerm opens at path",
    ]
    gap = 16
    pad = 24
    label_h = 36
    # Shrink each panel to fit a wide banner without crushing text too hard
    pw = 720
    ph = int(pw * CANVAS_H / CANVAS_W)
    scaled = [p.resize((pw, ph), Image.Resampling.LANCZOS) for p in panels]

    w = pad * 2 + pw * 3 + gap * 2
    h = pad * 2 + ph + label_h + 8
    canvas = Image.new("RGB", (w, h), (22, 24, 26))
    d = ImageDraw.Draw(canvas)
    for i, (panel, label) in enumerate(zip(scaled, labels)):
        x = pad + i * (pw + gap)
        y = pad
        # subtle border
        d.rounded_rectangle(
            [x - 2, y - 2, x + pw + 2, y + ph + 2],
            12,
            outline=(60, 64, 70),
            width=2,
        )
        canvas.paste(panel, (x, y))
        tw, th = tsize(d, label, F_PANEL)
        d.text(
            (x + (pw - tw) // 2, y + ph + 10),
            label,
            font=F_PANEL,
            fill=(210, 214, 220),
        )
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out, "PNG", optimize=True)
    print(f"wrote {out}  ({out.stat().st_size / 1024:.0f} KB, {canvas.size[0]}x{canvas.size[1]})")


def export_png_sequence(frames: list[Image.Image], frame_dir: Path) -> Path:
    frame_dir.mkdir(parents=True, exist_ok=True)
    for i, fr in enumerate(frames):
        fr.save(frame_dir / f"frame_{i:04d}.png", "PNG", compress_level=3)
    print(f"  exported {len(frames)} PNG frames @ {CANVAS_W}x{CANVAS_H}")
    return frame_dir


def encode_gif_ffmpeg(frame_dir: Path, fps: int, out: Path) -> bool:
    """Two-pass palette GIF — much cleaner than single-pass PIL quantize."""
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        return False

    pattern = str(frame_dir / "frame_%04d.png")
    palette = frame_dir / "palette.png"
    tmp = out.with_suffix(".tmp.gif")

    # Pass 1: global palette from full sequence
    r1 = subprocess.run(
        [
            ffmpeg,
            "-y",
            "-hide_banner",
            "-loglevel",
            "error",
            "-framerate",
            str(fps),
            "-i",
            pattern,
            "-vf",
            "palettegen=max_colors=256:stats_mode=diff",
            str(palette),
        ],
        capture_output=True,
        text=True,
    )
    if r1.returncode != 0:
        print("ffmpeg palettegen failed:", (r1.stderr or r1.stdout)[-500:])
        return False

    # Pass 2: apply palette with high-quality dither
    r2 = subprocess.run(
        [
            ffmpeg,
            "-y",
            "-hide_banner",
            "-loglevel",
            "error",
            "-framerate",
            str(fps),
            "-i",
            pattern,
            "-i",
            str(palette),
            "-lavfi",
            "paletteuse=dither=sierra2_4a:diff_mode=rectangle",
            "-loop",
            "0",
            str(tmp),
        ],
        capture_output=True,
        text=True,
    )
    if r2.returncode != 0:
        print("ffmpeg paletteuse failed:", (r2.stderr or r2.stdout)[-500:])
        if tmp.exists():
            tmp.unlink()
        return False

    tmp.replace(out)
    print(f"wrote {out}  ({out.stat().st_size / 1024:.0f} KB)  [ffmpeg palette]")
    return True


def encode_mp4_ffmpeg(frame_dir: Path, fps: int, out: Path) -> bool:
    """True-color H.264 — sharpest animated preview (not autoplay in README img)."""
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        return False

    pattern = str(frame_dir / "frame_%04d.png")
    tmp = out.with_suffix(".tmp.mp4")
    r = subprocess.run(
        [
            ffmpeg,
            "-y",
            "-hide_banner",
            "-loglevel",
            "error",
            "-framerate",
            str(fps),
            "-i",
            pattern,
            "-c:v",
            "libx264",
            "-pix_fmt",
            "yuv420p",
            "-crf",
            "18",
            "-preset",
            "slow",
            "-movflags",
            "+faststart",
            str(tmp),
        ],
        capture_output=True,
        text=True,
    )
    if r.returncode != 0:
        print("ffmpeg mp4 failed:", (r.stderr or r.stdout)[-500:])
        if tmp.exists():
            tmp.unlink()
        return False

    tmp.replace(out)
    print(f"wrote {out}  ({out.stat().st_size / 1024:.0f} KB)  [h264 crf18]")
    return True


def encode_gif_pillow(frames: list[Image.Image], duration_ms: int, out: Path) -> None:
    """Last-resort GIF encoder if ffmpeg is missing."""
    sample = Image.new("RGB", (CANVAS_W, CANVAS_H * 3))
    for i, fi in enumerate([0, len(frames) // 2, len(frames) - 1]):
        sample.paste(frames[fi], (0, CANVAS_H * i))
    pal = sample.quantize(colors=192, method=Image.Quantize.MAXCOVERAGE)
    q = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in frames]
    q[0].save(
        out,
        save_all=True,
        append_images=q[1:],
        duration=duration_ms,
        loop=0,
        optimize=True,
        disposal=2,
    )
    print(f"wrote {out}  ({out.stat().st_size / 1024:.0f} KB)  [pillow fallback]")


def main() -> None:
    frames = build_frames()
    duration_ms = int(1000 / FPS)

    OUT_DIR.mkdir(parents=True, exist_ok=True)

    # Static storyboard — zero animation compression, always sharp
    write_static_storyboard(frames, OUT_DIR / "openinyaterm-demo.png")

    gif_out = OUT_DIR / "openinyaterm-demo.gif"
    mp4_out = OUT_DIR / "openinyaterm-demo.mp4"

    with tempfile.TemporaryDirectory(prefix="openinyaterm-demo-") as td:
        tdp = Path(td)
        export_png_sequence(frames, tdp)

        ok_gif = encode_gif_ffmpeg(tdp, FPS, gif_out)
        ok_mp4 = encode_mp4_ffmpeg(tdp, FPS, mp4_out)

        if not ok_gif:
            print("  ffmpeg GIF failed; falling back to Pillow")
            encode_gif_pillow(frames, duration_ms, gif_out)
        if not ok_mp4:
            print("  tip: install/fix ffmpeg for MP4 output (`brew reinstall ffmpeg`)")

    print(f"  {len(frames)} frames @ {FPS}fps, canvas {CANVAS_W}x{CANVAS_H}")
    print("  README: use assets/openinyaterm-demo.gif  |  sharp static: openinyaterm-demo.png")


if __name__ == "__main__":
    main()
