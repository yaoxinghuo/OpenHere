#!/usr/bin/env python3
"""Generate OpenHere AppIcon and FinderSync toolbar icon from source PNGs.

Usage:
  python3 scripts/make_app_icon.py
  python3 scripts/make_app_icon.py --app-icon /path/to/icon.png --toolbar-icon /path/to/toolbar.png
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ICONSET = ROOT / "OpenHere" / "Assets.xcassets" / "AppIcon.appiconset"
TOOLBAR = ROOT / "FinderSyncExtension" / "Assets.xcassets" / "ToolbarIcon.imageset"
APP_ICON_SIZES = {
    "icon_16x16.png": 16,
    "icon_32x32.png": 32,
    "icon_64x64.png": 64,
    "icon_128x128.png": 128,
    "icon_256x256.png": 256,
    "icon_512x512.png": 512,
    "icon_1024x1024.png": 1024,
}
TOOLBAR_SIZES = {
    "toolbar_icon_16.png": 16,
    "toolbar_icon_32.png": 32,
}


def write_icons(src: Image.Image, sizes: dict[str, int], dest_dir: Path, auto_crop: bool = False, pad_square: bool = False) -> None:
    dest_dir.mkdir(parents=True, exist_ok=True)
    # Auto-crop transparent padding — only for toolbar icons where we want
    # the content to fill the small 16x16 canvas. macOS app icons should
    # keep their built-in padding per Apple's icon design guidelines.
    if auto_crop:
        bbox = src.getbbox()
        if bbox and bbox != (0, 0, src.width, src.height):
            src = src.crop(bbox)
            print(f"  auto-cropped to {src.size}")
    # Pad to square to preserve aspect ratio when resizing to square icons.
    if pad_square and src.width != src.height:
        max_dim = max(src.width, src.height)
        padded = Image.new("RGBA", (max_dim, max_dim), (0, 0, 0, 0))
        padded.paste(src, ((max_dim - src.width) // 2, (max_dim - src.height) // 2))
        src = padded
        print(f"  padded to square {src.size}")
    for name, size in sizes.items():
        src.resize((size, size), Image.Resampling.LANCZOS).save(dest_dir / name)
        print(f"  wrote {name}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--app-icon",
        type=Path,
        default=ROOT / "assets" / "openhere_app_icon.png",
        help="Path to 1024x1024 app icon PNG",
    )
    ap.add_argument(
        "--toolbar-icon",
        type=Path,
        default=ROOT / "assets" / "openhere_toolbar_monochrome_icon.png",
        help="Path to monochrome toolbar icon PNG (template rendering)",
    )
    args = ap.parse_args()

    if not args.app_icon.is_file():
        raise SystemExit(f"App icon not found: {args.app_icon}")
    if not args.toolbar_icon.is_file():
        raise SystemExit(f"Toolbar icon not found: {args.toolbar_icon}")

    app_src = Image.open(args.app_icon).convert("RGBA")
    print(f"App icon source: {app_src.size}")
    print(f"Writing AppIcon → {ICONSET}")
    write_icons(app_src, APP_ICON_SIZES, ICONSET)

    tb_src = Image.open(args.toolbar_icon).convert("RGBA")
    print(f"Toolbar icon source: {tb_src.size}")
    print(f"Writing ToolbarIcon → {TOOLBAR}")
    write_icons(tb_src, TOOLBAR_SIZES, TOOLBAR, auto_crop=True, pad_square=True)

    print("done")


if __name__ == "__main__":
    main()
