#!/usr/bin/env python3
"""
NEON FLORA - Unified Symbol Generator (CHR / BEL / ICE / RPL)
Non-text symbols regenerated via FLUX.1-schnell with a strict unified style prefix.
BAR/7 are excluded (handled by gen_programmatic_symbols.py).

Output: assets/images/symbols/symbol_chr.png, symbol_bel.png, symbol_ice.png, symbol_rpl.png
Size: 768x768 generated -> 200x160 final
"""

import os
import sys
import time
import io
import base64
import json
import urllib.request
import urllib.error

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

API_URL = "https://router.huggingface.co/hf-inference/models/black-forest-labs/FLUX.1-schnell"
API_KEY = os.environ.get("HF_API_KEY", "")

OUTPUT_DIR = "C:/xampp/htdocs/rpg_game/neon_flora/assets/images/symbols"

GEN_SIZE = 768
FINAL_W = 200
FINAL_H = 160

MAX_RETRIES = 3
RETRY_DELAY_503 = 30
RETRY_DELAY_429 = 60
INTER_IMAGE_DELAY = 5

# ---------------------------------------------------------------------------
# Unified style prefix — all non-text symbols share this exact style
# ---------------------------------------------------------------------------

STYLE_PREFIX = (
    "single isolated game icon on solid very dark navy background #0A0A1A, "
    "neon cyberpunk Japanese aesthetic, "
    "vibrant neon glow halo around the object, high contrast, sharp edges, "
    "clean vector-like rendering with soft neon light bloom, "
    "slot machine symbol, centered composition, "
    "no text, no letters, no watermark, no additional objects, "
)

SYMBOLS = [
    {
        "filename": "symbol_chr.png",
        "prompt": (
            STYLE_PREFIX +
            "pair of glossy red cherries on a short green stem with one small leaf, "
            "rich ruby red surface reflecting neon pink light, juicy translucent fruit, "
            "warm neon magenta-pink glow halo around the cherries, "
            "classic slot machine cherry symbol"
        ),
    },
    {
        "filename": "symbol_bel.png",
        "prompt": (
            STYLE_PREFIX +
            "classic golden liberty bell, polished gold metal surface, "
            "small clapper visible inside, slightly tilted to show 3D depth, "
            "warm golden-yellow neon glow halo, "
            "classic slot machine bell symbol, retro casino golden bell"
        ),
    },
    {
        "filename": "symbol_ice.png",
        "prompt": (
            STYLE_PREFIX +
            "hexagonal ice crystal, translucent cyan-blue facets with sharp geometric edges, "
            "frozen crystalline structure, internal light refraction, "
            "cold cyan-blue neon glow halo, frost particles around edges, "
            "ice diamond crystal symbol"
        ),
    },
    {
        "filename": "symbol_rpl.png",
        "prompt": (
            STYLE_PREFIX +
            "two curved arrows forming a circular loop cycle, refresh/replay icon, "
            "smooth rounded arrow shapes with arrowheads, "
            "glowing mint green neon color, electric green illumination, "
            "rotation recycle replay symbol, simple clean geometric design"
        ),
    },
]

# ---------------------------------------------------------------------------
# API helper (same pattern as gen_alpha_symbols.py)
# ---------------------------------------------------------------------------

def call_api(prompt: str) -> bytes:
    payload = json.dumps({
        "inputs": prompt,
        "parameters": {
            "width": GEN_SIZE,
            "height": GEN_SIZE,
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
            else:
                if attempt < MAX_RETRIES:
                    time.sleep(10)
                else:
                    raise
        except Exception as e:
            print(f"  Error: {e}")
            if attempt < MAX_RETRIES:
                time.sleep(10)
            else:
                raise

    raise RuntimeError(f"All {MAX_RETRIES} attempts failed")


def save_image(img_bytes: bytes, output_path: str) -> int:
    from PIL import Image
    img = Image.open(io.BytesIO(img_bytes))
    print(f"  Source: {img.size} mode={img.mode}")
    resized = img.resize((FINAL_W, FINAL_H), Image.LANCZOS)
    resized.save(output_path, "PNG")
    fsize = os.path.getsize(output_path)
    print(f"  Saved: {output_path} ({FINAL_W}x{FINAL_H}, {fsize:,} bytes)")
    return fsize


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true", help="Overwrite existing files")
    args = parser.parse_args()

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print(f"Output: {OUTPUT_DIR}")
    print(f"Generation: {GEN_SIZE}x{GEN_SIZE} -> Final: {FINAL_W}x{FINAL_H}")
    print("=" * 60)

    results = []
    total = len(SYMBOLS)

    for idx, sym in enumerate(SYMBOLS, 1):
        out_path = os.path.join(OUTPUT_DIR, sym["filename"])
        print(f"\n[{idx}/{total}] {sym['filename']}")

        if not args.force and os.path.exists(out_path):
            existing = os.path.getsize(out_path)
            if existing > 50 * 1024:
                print(f"  SKIP: exists ({existing:,} bytes). Use --force to overwrite.")
                results.append((sym["filename"], "skipped", existing))
                continue

        print(f"  Prompt: {sym['prompt'][:100]}...")
        try:
            img_bytes = call_api(sym["prompt"])
            fsize = save_image(img_bytes, out_path)
            results.append((sym["filename"], "OK", fsize))
        except Exception as e:
            print(f"  FAILED: {e}")
            results.append((sym["filename"], f"FAILED: {e}", 0))

        if idx < total:
            print(f"  Waiting {INTER_IMAGE_DELAY}s...")
            time.sleep(INTER_IMAGE_DELAY)

    # Summary
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    for fname, status, size in results:
        print(f"  {fname:<25} {size:>10,} bytes  {status}")

    failed = [r for r in results if "FAILED" in r[1]]
    if failed:
        print(f"\n{len(failed)} file(s) FAILED.")
        sys.exit(1)
    else:
        print(f"\nAll {total} symbols processed.")


if __name__ == "__main__":
    main()
