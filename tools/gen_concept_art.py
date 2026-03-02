#!/usr/bin/env python3
"""
NEON FLORA - Concept Art & Title Background Generator
Generates proper concept art and title background via FLUX.1-schnell.

Output:
  assets/images/concept_art.png  (1024x1024 -> 900x900)
  assets/images/title_bg.png     (1024x1024 -> 900x1600 center crop)
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

IMAGES_DIR = "C:/xampp/htdocs/rpg_game/neon_flora/assets/images"

GEN_SIZE = 1024
MAX_RETRIES = 3
RETRY_DELAY_503 = 30
RETRY_DELAY_429 = 60

# ---------------------------------------------------------------------------
# Image definitions
# ---------------------------------------------------------------------------

IMAGES = [
    {
        "filename": "concept_art.png",
        "prompt": (
            "concept art poster for a Japanese pachislot game called NEON FLORA, "
            "dark cyberpunk nighttime cityscape with neon signs and cherry blossom trees, "
            "futuristic Akihabara district with glowing slot machine cabinets on the street, "
            "cyber-japanesque fusion aesthetic, neon pink and cyan and magenta color palette, "
            "a ghostly silhouette of an anime girl with twin tails visible in neon reflections, "
            "firework bursts in the distant sky above the city, "
            "atmospheric fog and volumetric neon light rays, "
            "highly detailed digital art, cinematic composition, "
            "no text, no watermark, no signature, professional game concept art"
        ),
        "final_size": (900, 900),
        "crop_mode": "center_square",
    },
    {
        "filename": "title_bg.png",
        "prompt": (
            "dark moody cyberpunk Japanese alleyway at night, vertical portrait composition, "
            "looking upward at tall buildings with neon signs in Japanese, "
            "cherry blossom petals floating in the air, soft pink and magenta neon glow, "
            "wet street reflecting colorful neon lights, light fog and atmosphere, "
            "dark at the bottom fading to neon-lit sky above, "
            "suitable as background for game title text overlay, "
            "very dark lower third for text readability, "
            "cyberpunk Japanese aesthetic, moody cinematic lighting, "
            "no text, no watermark, no characters, "
            "professional game background art, 4K quality"
        ),
        "final_size": (900, 1600),
        "crop_mode": "portrait_crop",
    },
]

# ---------------------------------------------------------------------------
# API helper
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


def save_image(img_bytes: bytes, output_path: str, final_size: tuple, crop_mode: str) -> int:
    from PIL import Image
    img = Image.open(io.BytesIO(img_bytes))
    print(f"  Source: {img.size} mode={img.mode}")

    fw, fh = final_size

    if crop_mode == "center_square":
        # Simple resize
        result = img.resize((fw, fh), Image.LANCZOS)

    elif crop_mode == "portrait_crop":
        # For portrait: first resize to width=fw maintaining aspect, then crop height
        # Since source is 1024x1024 (square), we need to scale up to at least fh tall
        # Scale to fit width, then pad/crop vertically
        scale = max(fw / img.width, fh / img.height)
        new_w = int(img.width * scale)
        new_h = int(img.height * scale)
        scaled = img.resize((new_w, new_h), Image.LANCZOS)

        # Center crop to final size
        left = (new_w - fw) // 2
        top = (new_h - fh) // 2
        result = scaled.crop((left, top, left + fw, top + fh))

    else:
        result = img.resize((fw, fh), Image.LANCZOS)

    result.save(output_path, "PNG")
    fsize = os.path.getsize(output_path)
    print(f"  Saved: {output_path} ({fw}x{fh}, {fsize:,} bytes)")
    return fsize


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true", help="Overwrite existing files")
    args = parser.parse_args()

    os.makedirs(IMAGES_DIR, exist_ok=True)
    print("NEON FLORA - Concept Art & Title BG Generator")
    print(f"Output: {IMAGES_DIR}")
    print(f"Generation: {GEN_SIZE}x{GEN_SIZE}")
    print("=" * 60)

    results = []
    total = len(IMAGES)

    for idx, img_def in enumerate(IMAGES, 1):
        out_path = os.path.join(IMAGES_DIR, img_def["filename"])
        fw, fh = img_def["final_size"]
        print(f"\n[{idx}/{total}] {img_def['filename']} ({fw}x{fh})")

        if not args.force and os.path.exists(out_path):
            existing = os.path.getsize(out_path)
            if existing > 50 * 1024:
                print(f"  SKIP: exists ({existing:,} bytes). Use --force to overwrite.")
                results.append((img_def["filename"], "skipped", existing))
                continue

        print(f"  Prompt: {img_def['prompt'][:100]}...")
        try:
            img_bytes = call_api(img_def["prompt"])
            fsize = save_image(
                img_bytes, out_path,
                img_def["final_size"], img_def["crop_mode"]
            )
            results.append((img_def["filename"], "OK", fsize))
        except Exception as e:
            print(f"  FAILED: {e}")
            results.append((img_def["filename"], f"FAILED: {e}", 0))

        if idx < total:
            print("  Waiting 5s...")
            time.sleep(5)

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
        print(f"\nAll {total} images processed.")


if __name__ == "__main__":
    main()
