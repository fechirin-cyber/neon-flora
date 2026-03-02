#!/usr/bin/env python3
"""
NEON FLORA - Alpha Phase Asset Generator
Generates 7 symbol images and game background via HuggingFace FLUX.1-schnell API.

Usage:
  python gen_alpha_symbols.py
  python gen_alpha_symbols.py --skip-existing  (skip files that already exist > 50KB)
  python gen_alpha_symbols.py --force          (overwrite all, default behavior)

API response format: JSON with a quoted base64-encoded PNG string.
"""

import os
import sys
import time
import argparse
import base64
import json
import urllib.request
import urllib.error

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

API_URL = "https://router.huggingface.co/hf-inference/models/black-forest-labs/FLUX.1-schnell"
API_KEY = os.environ.get("HF_API_KEY", "")

SYMBOLS_DIR = "C:/xampp/htdocs/rpg_game/neon_flora/assets/images/symbols"
IMAGES_DIR  = "C:/xampp/htdocs/rpg_game/neon_flora/assets/images"

# Generation size
GEN_WIDTH  = 512
GEN_HEIGHT = 512

# Symbol target size
SYM_WIDTH  = 200
SYM_HEIGHT = 160

# Background target size
BG_WIDTH  = 900
BG_HEIGHT = 1600

MAX_RETRIES        = 3
RETRY_DELAY_503    = 30   # seconds on 503 (model loading)
RETRY_DELAY_429    = 60   # seconds on 429 (rate limit)
INTER_IMAGE_DELAY  = 5    # seconds between images

# ---------------------------------------------------------------------------
# Image definitions
# ---------------------------------------------------------------------------

STYLE_PREFIX = (
    "slot machine symbol, isolated on very dark background #0A0A1A, "
    "neon glow effect, cyberpunk Japanese aesthetic, "
    "vibrant colors, sharp edges, high contrast, "
    "centered composition, game asset, "
)

SYMBOLS = [
    {
        "filename": "symbol_s7r.png",
        "prompt": (
            STYLE_PREFIX +
            "large bold metallic red number 7, chrome surface with deep red neon glow halo, "
            "glossy metallic sheen with gold trim outline, "
            "the numeral seven dominates the frame, electric scarlet red illumination, "
            "slot machine red seven icon"
        ),
        "target_size": (SYM_WIDTH, SYM_HEIGHT),
    },
    {
        "filename": "symbol_s7b.png",
        "prompt": (
            STYLE_PREFIX +
            "large bold metallic blue number 7, chrome surface with electric cyan-blue neon glow halo, "
            "glossy metallic sheen with silver trim outline, "
            "the numeral seven dominates the frame, electric cobalt blue illumination, "
            "slot machine blue seven icon"
        ),
        "target_size": (SYM_WIDTH, SYM_HEIGHT),
    },
    {
        "filename": "symbol_bar.png",
        "prompt": (
            STYLE_PREFIX +
            "classic slot machine BAR logo, bold chrome metallic letters B-A-R, "
            "neon pink magenta outline glow, retro casino BAR symbol, "
            "heavy blocky typeface with electric pink neon illumination, "
            "cyberpunk BAR slot symbol on dark background"
        ),
        "target_size": (SYM_WIDTH, SYM_HEIGHT),
    },
    {
        "filename": "symbol_chr.png",
        "prompt": (
            STYLE_PREFIX +
            "pair of glossy red cherries on a green stem with leaf, "
            "neon pink and red glowing outline, juicy glossy fruit surface, "
            "retro slot machine cherry symbol with neon light effect, "
            "cherry fruit pair radiating warm neon pink light on dark background"
        ),
        "target_size": (SYM_WIDTH, SYM_HEIGHT),
    },
    {
        "filename": "symbol_bel.png",
        "prompt": (
            STYLE_PREFIX +
            "shiny golden bell shape with warm golden neon glow halo, "
            "polished gold bell, bright yellow neon outline, "
            "retro slot machine bell symbol with cyberpunk gold illumination, "
            "classic liberty bell radiating warm golden neon light"
        ),
        "target_size": (SYM_WIDTH, SYM_HEIGHT),
    },
    {
        "filename": "symbol_ice.png",
        "prompt": (
            STYLE_PREFIX +
            "ice crystal snowflake with cyan blue neon glow, "
            "sharp geometric hexagonal ice crystal, translucent light blue facets, "
            "electric cyan illumination, ice and frost effect, "
            "slot machine ice symbol radiating cold neon cyan-blue light"
        ),
        "target_size": (SYM_WIDTH, SYM_HEIGHT),
    },
    {
        "filename": "symbol_rpl.png",
        "prompt": (
            STYLE_PREFIX +
            "circular replay cycle arrow symbol, two curved arrows forming a loop, "
            "mint green neon glow, electric green illumination, rotation cycle icon, "
            "slot machine replay symbol with glowing mint green neon light, "
            "refresh arrows in neon green on dark background"
        ),
        "target_size": (SYM_WIDTH, SYM_HEIGHT),
    },
]

BACKGROUND = {
    "filename": "game_bg.png",
    "prompt": (
        "dark nighttime rooftop view in a neon cyberpunk Japanese city, "
        "very dark sky, distant skyscrapers with colorful neon signs, "
        "purple and deep blue night atmosphere, neon lights reflecting below, "
        "moody dark ambiance suitable as background for slot machine UI, "
        "very dark overall with muted tones so UI overlay stands out, "
        "portrait orientation, vertical composition, no characters, no people"
    ),
    "target_size": (BG_WIDTH, BG_HEIGHT),
    "output_dir": IMAGES_DIR,
}

# ---------------------------------------------------------------------------
# API helper
# ---------------------------------------------------------------------------

def call_api(prompt: str) -> bytes:
    """
    Call FLUX.1-schnell, return decoded PNG bytes.
    The API returns a JSON string containing a base64-encoded PNG.
    """
    payload = json.dumps({
        "inputs": prompt,
        "parameters": {
            "width": GEN_WIDTH,
            "height": GEN_HEIGHT,
            "num_inference_steps": 4,
        }
    }).encode("utf-8")

    for attempt in range(1, MAX_RETRIES + 1):
        print(f"  Attempt {attempt}/{MAX_RETRIES}...")
        req = urllib.request.Request(
            API_URL,
            data=payload,
            headers={
                "Authorization": f"Bearer {API_KEY}",
                "Content-Type": "application/json",
                "Accept": "application/json",
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                raw = resp.read()
                ct = resp.headers.get("Content-Type", "")
                print(f"  HTTP 200, Content-Type: {ct}, raw bytes: {len(raw)}")

                # The response is a JSON-quoted base64 string:  "iVBORw0K..."
                # Strip surrounding quotes and decode base64
                text = raw.decode("utf-8").strip()
                if text.startswith('"') and text.endswith('"'):
                    b64 = text[1:-1]
                else:
                    b64 = text
                img_bytes = base64.b64decode(b64)
                print(f"  Decoded image: {len(img_bytes):,} bytes")
                return img_bytes

        except urllib.error.HTTPError as e:
            body = e.read().decode("utf-8", errors="replace")[:400]
            print(f"  HTTP {e.code}: {body}")
            if e.code == 503:
                print(f"  Model loading — waiting {RETRY_DELAY_503}s...")
                time.sleep(RETRY_DELAY_503)
            elif e.code == 429:
                print(f"  Rate limited — waiting {RETRY_DELAY_429}s...")
                time.sleep(RETRY_DELAY_429)
            elif e.code == 410:
                print("  FATAL: 410 Gone — wrong endpoint URL")
                sys.exit(1)
            else:
                if attempt < MAX_RETRIES:
                    print("  Retrying in 10s...")
                    time.sleep(10)
                else:
                    raise
        except Exception as e:
            print(f"  Request error: {e}")
            if attempt < MAX_RETRIES:
                print("  Retrying in 10s...")
                time.sleep(10)
            else:
                raise

    raise RuntimeError(f"All {MAX_RETRIES} attempts failed")


# ---------------------------------------------------------------------------
# Save with resize
# ---------------------------------------------------------------------------

def save_image(img_bytes: bytes, output_path: str, target_size: tuple) -> int:
    """Resize image to target_size and save as PNG. Returns file size."""
    from PIL import Image
    import io
    img = Image.open(io.BytesIO(img_bytes))
    print(f"  Source: {img.size} mode={img.mode}")
    resized = img.resize(target_size, Image.LANCZOS)
    resized.save(output_path, "PNG")
    fsize = os.path.getsize(output_path)
    print(f"  Saved: {output_path} ({target_size[0]}x{target_size[1]}, {fsize:,} bytes)")
    return fsize


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--skip-existing", action="store_true",
                        help="Skip files that already exist with size > 50KB")
    args = parser.parse_args()

    os.makedirs(SYMBOLS_DIR, exist_ok=True)
    os.makedirs(IMAGES_DIR, exist_ok=True)

    # Build full task list
    tasks = []
    for sym in SYMBOLS:
        tasks.append(dict(sym, output_dir=SYMBOLS_DIR))
    tasks.append(BACKGROUND)

    results = []
    total = len(tasks)

    for idx, task in enumerate(tasks, 1):
        out_path = os.path.join(task["output_dir"], task["filename"])
        target   = task["target_size"]

        print(f"\n[{idx}/{total}] {task['filename']}  ({target[0]}x{target[1]})")

        # Check skip
        if args.skip_existing and os.path.exists(out_path):
            existing = os.path.getsize(out_path)
            if existing > 50 * 1024:
                print(f"  SKIP: exists and is {existing:,} bytes (> 50KB)")
                results.append({"file": out_path, "size": f"{target[0]}x{target[1]}",
                                 "bytes": existing, "status": "skipped"})
                continue
            else:
                print(f"  Existing file only {existing} bytes — regenerating")

        print(f"  Prompt: {task['prompt'][:80]}...")
        try:
            img_bytes = call_api(task["prompt"])
            fsize = save_image(img_bytes, out_path, target)
            results.append({"file": out_path, "size": f"{target[0]}x{target[1]}",
                             "bytes": fsize, "status": "OK"})
        except Exception as e:
            print(f"  FAILED: {e}")
            results.append({"file": out_path, "size": f"{target[0]}x{target[1]}",
                             "bytes": 0, "status": f"FAILED: {e}"})

        if idx < total:
            print(f"  Waiting {INTER_IMAGE_DELAY}s...")
            time.sleep(INTER_IMAGE_DELAY)

    # Summary
    print("\n" + "=" * 65)
    print("SUMMARY")
    print("=" * 65)
    print(f"{'Filename':<35} {'Dimensions':>12} {'Bytes':>10}  Status")
    print("-" * 65)
    for r in results:
        fname = os.path.basename(r["file"])
        print(f"{fname:<35} {r['size']:>12} {r['bytes']:>10,}  {r['status']}")

    failed = [r for r in results if "FAILED" in r["status"]]
    if failed:
        print(f"\n{len(failed)} file(s) FAILED.")
        sys.exit(1)
    else:
        print(f"\nAll {len(results)} assets processed.")


if __name__ == "__main__":
    main()
