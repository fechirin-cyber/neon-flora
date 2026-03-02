#!/usr/bin/env python3
"""
NEON FLORA - Programmatic Symbol Generator (BAR / Red7 / Blue7)
AI cannot reliably render text, so these text-bearing symbols are generated
programmatically using Pillow + system fonts + multi-layer neon glow.

Output: assets/images/symbols/symbol_bar.png, symbol_s7r.png, symbol_s7b.png
Size: 512x412 rendered -> 200x160 final
"""

import os
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

OUTPUT_DIR = "C:/xampp/htdocs/rpg_game/neon_flora/assets/images/symbols"

# Render at high res then downsample for quality
RENDER_W = 512
RENDER_H = 412
FINAL_W = 200
FINAL_H = 160

# Background color (dark navy to match game theme)
BG_COLOR = (10, 10, 26, 255)  # #0A0A1A

# Font path (Impact is available on all Windows)
FONT_PATH = "C:/Windows/Fonts/impact.ttf"
FONT_PATH_BOLD = "C:/Windows/Fonts/arialbd.ttf"  # fallback

# ---------------------------------------------------------------------------
# Neon glow rendering
# ---------------------------------------------------------------------------

def create_neon_text(
    text: str,
    font_size: int,
    text_color: tuple,
    glow_color: tuple,
    outline_color: tuple = None,
    font_path: str = FONT_PATH,
) -> Image.Image:
    """
    Render text with multi-layer neon glow effect.
    Layers (bottom to top):
      1. Wide gaussian blur glow (large radius, low opacity)
      2. Medium gaussian blur glow (medium radius)
      3. Tight outline glow
      4. Solid text (bright center)
    """
    canvas = Image.new("RGBA", (RENDER_W, RENDER_H), BG_COLOR)

    try:
        font = ImageFont.truetype(font_path, font_size)
    except (OSError, IOError):
        try:
            font = ImageFont.truetype(FONT_PATH_BOLD, font_size)
        except (OSError, IOError):
            print(f"  WARNING: Cannot load font, using default")
            font = ImageFont.load_default()

    # Get text bounding box for centering
    temp_draw = ImageDraw.Draw(canvas)
    bbox = temp_draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    tx = (RENDER_W - tw) // 2 - bbox[0]
    ty = (RENDER_H - th) // 2 - bbox[1]

    if outline_color is None:
        outline_color = glow_color

    # Layer 1: Wide glow (radius 20)
    layer_wide = Image.new("RGBA", (RENDER_W, RENDER_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer_wide)
    d.text((tx, ty), text, font=font, fill=(*glow_color[:3], 100))
    layer_wide = layer_wide.filter(ImageFilter.GaussianBlur(radius=20))
    canvas = Image.alpha_composite(canvas, layer_wide)

    # Layer 2: Medium glow (radius 10)
    layer_med = Image.new("RGBA", (RENDER_W, RENDER_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer_med)
    d.text((tx, ty), text, font=font, fill=(*glow_color[:3], 160))
    layer_med = layer_med.filter(ImageFilter.GaussianBlur(radius=10))
    canvas = Image.alpha_composite(canvas, layer_med)

    # Layer 3: Tight outline glow (radius 4)
    layer_outline = Image.new("RGBA", (RENDER_W, RENDER_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer_outline)
    # Draw outline by offsetting text in all directions
    for dx in range(-3, 4):
        for dy in range(-3, 4):
            if dx * dx + dy * dy <= 9:
                d.text((tx + dx, ty + dy), text, font=font, fill=(*outline_color[:3], 200))
    layer_outline = layer_outline.filter(ImageFilter.GaussianBlur(radius=4))
    canvas = Image.alpha_composite(canvas, layer_outline)

    # Layer 4: Solid center text (bright white-tinted core)
    layer_text = Image.new("RGBA", (RENDER_W, RENDER_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer_text)
    # Bright outline
    for dx in range(-2, 3):
        for dy in range(-2, 3):
            if dx * dx + dy * dy <= 4:
                d.text((tx + dx, ty + dy), text, font=font, fill=(*text_color[:3], 255))
    # White-hot center
    bright = tuple(min(255, c + 80) for c in text_color[:3])
    d.text((tx, ty), text, font=font, fill=(*bright, 255))
    canvas = Image.alpha_composite(canvas, layer_text)

    return canvas


def add_metallic_sheen(img: Image.Image) -> Image.Image:
    """Add subtle horizontal metallic sheen gradient."""
    sheen = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(sheen)
    w, h = img.size
    # Top-to-bottom gradient: bright at 30% height, dark at bottom
    for y in range(h):
        ratio = y / h
        if ratio < 0.3:
            alpha = int(40 * (ratio / 0.3))
        elif ratio < 0.5:
            alpha = int(40 * (1.0 - (ratio - 0.3) / 0.2))
        else:
            alpha = 0
        d.line([(0, y), (w, y)], fill=(255, 255, 255, alpha))
    return Image.alpha_composite(img, sheen)


# ---------------------------------------------------------------------------
# Symbol definitions
# ---------------------------------------------------------------------------

SYMBOLS = [
    {
        "filename": "symbol_bar.png",
        "text": "BAR",
        "font_size": 160,
        "text_color": (255, 100, 200),     # hot pink
        "glow_color": (255, 50, 150),       # magenta glow
        "outline_color": (255, 150, 220),   # light pink outline
    },
    {
        "filename": "symbol_s7r.png",
        "text": "7",
        "font_size": 280,
        "text_color": (255, 20, 60),        # red
        "glow_color": (255, 0, 50),         # deep red glow
        "outline_color": (255, 100, 100),   # lighter red outline
    },
    {
        "filename": "symbol_s7b.png",
        "text": "7",
        "font_size": 280,
        "text_color": (0, 150, 255),        # blue
        "glow_color": (0, 100, 255),        # deep blue glow
        "outline_color": (100, 180, 255),   # lighter blue outline
    },
]


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print(f"Output: {OUTPUT_DIR}")
    print(f"Render: {RENDER_W}x{RENDER_H} -> Final: {FINAL_W}x{FINAL_H}")
    print("=" * 60)

    for i, sym in enumerate(SYMBOLS, 1):
        out_path = os.path.join(OUTPUT_DIR, sym["filename"])
        print(f"\n[{i}/{len(SYMBOLS)}] {sym['filename']} (text='{sym['text']}')")

        img = create_neon_text(
            text=sym["text"],
            font_size=sym["font_size"],
            text_color=sym["text_color"],
            glow_color=sym["glow_color"],
            outline_color=sym["outline_color"],
        )
        img = add_metallic_sheen(img)

        # Downsample with LANCZOS
        final = img.resize((FINAL_W, FINAL_H), Image.LANCZOS)
        final.save(out_path, "PNG")
        fsize = os.path.getsize(out_path)
        print(f"  Saved: {out_path} ({fsize:,} bytes)")

    print("\n" + "=" * 60)
    print(f"All {len(SYMBOLS)} programmatic symbols generated.")


if __name__ == "__main__":
    main()
