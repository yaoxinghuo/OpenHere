#!/usr/bin/env python3
"""Build OpenInNyaTerm AppIcon set from the installed NyaTerm.app icon.

Pipeline:
  1. Extract a 1024×1024 render via NSWorkspace (Swift helper) or fall back to icns.
  2. Keep only the NyaTerm icon (drop black canvas + white macOS squircle plate).
  3. Transparent background; write all macOS AppIcon sizes.

Usage:
  python3 scripts/make_app_icon.py
  python3 scripts/make_app_icon.py --nyaterm /Applications/NyaTerm.app
"""

from __future__ import annotations

import argparse
import subprocess
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ICONSET = ROOT / "OpenInNyaTerm" / "Assets.xcassets" / "AppIcon.appiconset"
SIZES = {
    "icon_16x16.png": 16,
    "icon_32x32.png": 32,
    "icon_64x64.png": 64,
    "icon_128x128.png": 128,
    "icon_256x256.png": 256,
    "icon_512x512.png": 512,
    "icon_1024x1024.png": 1024,
}


def extract_via_swift(nyaterm_app: Path, out_png: Path) -> None:
    """Render NyaTerm.app's icon at 1024×1024 with AppKit."""
    swift_src = out_png.with_suffix(".swift")
    bin_path = out_png.with_suffix("")
    swift_src.write_text(
        f"""
import AppKit
let path = "{nyaterm_app}"
let icon = NSWorkspace.shared.icon(forFile: path)
let size: CGFloat = 1024
let rect = NSRect(x: 0, y: 0, width: size, height: size)
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
) else {{ fputs("rep fail\\n", stderr); exit(1) }}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor.clear.setFill(); rect.fill()
icon.size = NSSize(width: size, height: size)
icon.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
NSGraphicsContext.restoreGraphicsState()
guard let png = rep.representation(using: .png, properties: [:]) else {{
    fputs("png fail\\n", stderr); exit(1)
}}
try png.write(to: URL(fileURLWithPath: "{out_png}"))
print("extracted \\(png.count) bytes")
""",
        encoding="utf-8",
    )
    subprocess.check_call(
        ["swiftc", str(swift_src), "-o", str(bin_path), "-framework", "AppKit"],
        stdout=subprocess.DEVNULL,
    )
    subprocess.check_call([str(bin_path)])


def process_icon(src: Image.Image) -> Image.Image:
    """Crop to the icon's visible bounds (via alpha), center on a square canvas."""
    src = src.convert("RGBA")
    w, h = src.size

    bbox = src.getbbox()
    if not bbox:
        raise RuntimeError("could not find visible icon content")

    l, t, r, b = bbox
    pad = int(max(r - l, b - t) * 0.06)
    l, t = max(0, l - pad), max(0, t - pad)
    r, b = min(w, r + pad), min(h, b + pad)
    cropped = src.crop((l, t, r, b))

    cw, ch = cropped.size
    side = max(cw, ch)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(cropped, ((side - cw) // 2, (side - ch) // 2), cropped)
    return canvas.resize((1024, 1024), Image.Resampling.LANCZOS)


def write_iconset(master: Image.Image, dest: Path) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    for name, size in SIZES.items():
        master.resize((size, size), Image.Resampling.LANCZOS).save(dest / name)
        print(f"  wrote {name}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--nyaterm",
        type=Path,
        default=Path("/Applications/NyaTerm.app"),
        help="Path to NyaTerm.app",
    )
    ap.add_argument(
        "--out",
        type=Path,
        default=ICONSET,
        help="AppIcon.appiconset directory",
    )
    args = ap.parse_args()
    if not args.nyaterm.is_dir():
        raise SystemExit(f"NyaTerm.app not found: {args.nyaterm}")

    with tempfile.TemporaryDirectory(prefix="openinyaterm-icon-") as tmp:
        raw = Path(tmp) / "nyaterm_raw_1024.png"
        print(f"extracting icon from {args.nyaterm} …")
        extract_via_swift(args.nyaterm, raw)
        print("clipping to NyaTerm icon (transparent background) …")
        master = process_icon(Image.open(raw))
        a_min, a_max = master.getchannel("A").getextrema()
        if a_min != 0 or a_max != 255:
            print(f"warning: unexpected alpha extrema {(a_min, a_max)}")
        print(f"writing iconset → {args.out}")
        write_iconset(master, args.out)
    print("done")


if __name__ == "__main__":
    main()
