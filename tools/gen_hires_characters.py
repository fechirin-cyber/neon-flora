#!/usr/bin/env python3
"""
NEON FLORA - High-Resolution Character Generator
Regenerates all 3 characters x all reactions at 1024x1024.
Stronger prompt consistency: explicit odd-eye colors, accessories, uniform details.

Output: assets/images/characters/*.png (1024x1024, no downscale — Godot handles scaling)
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

OUTPUT_DIR = "C:/xampp/htdocs/rpg_game/neon_flora/assets/images/characters"
BACKUP_DIR = "C:/xampp/htdocs/rpg_game/neon_flora/assets/images/characters/_backup_pre_hires"

GEN_SIZE = 1024
MAX_RETRIES = 3
RETRY_DELAY_503 = 30
RETRY_DELAY_429 = 60
INTER_IMAGE_DELAY = 5

# ---------------------------------------------------------------------------
# Character style definitions (strict consistency)
# ---------------------------------------------------------------------------

HIKARI_STYLE = (
    "anime VTuber portrait, bust shot, "
    "girl named Hikari age 17, "
    "MUST HAVE: neon pink to magenta gradient twin tails hair reaching shoulder length, "
    "MUST HAVE: heterochromia odd eyes left eye cyan blue right eye golden amber, "
    "MUST HAVE: LED ring hair accessories on both twin tails, "
    "MUST HAVE: black sailor uniform with glowing neon pink circuit lines, "
    "MUST HAVE: one white over-ear headphone on right ear, "
    "MUST HAVE: firework-shaped brooch on chest, "
    "dark navy background #0A0A1A, neon pink rim lighting, "
    "clean sharp anime linework, soft cel shading, high detail, 4K, "
    "no text, no watermark, centered composition"
)

LUNA_STYLE = (
    "anime VTuber portrait, bust shot, "
    "girl named Luna age 16, "
    "MUST HAVE: platinum silver bob cut hair with electric blue streaks underneath, "
    "MUST HAVE: both eyes electric blue with star-shaped pupils, "
    "MUST HAVE: small crescent moon hair clip on right side, "
    "MUST HAVE: dark navy blazer with silver moon embroidery and blue LED trim, "
    "MUST HAVE: blue crystal pendant necklace, "
    "dark navy background #0A0A1A, cool blue rim lighting, "
    "clean sharp anime linework, soft cel shading, high detail, 4K, "
    "no text, no watermark, centered composition"
)

KOHARU_STYLE = (
    "anime VTuber portrait, bust shot, "
    "girl named Koharu age 18, "
    "MUST HAVE: warm orange to coral gradient wavy hair in side ponytail on left side, "
    "MUST HAVE: both eyes warm amber golden with flower-shaped highlights, "
    "MUST HAVE: small cherry blossom hair ornament in hair, "
    "MUST HAVE: pastel pink cardigan over white lace blouse, "
    "MUST HAVE: warm pink crystal earrings, "
    "dark navy background #0A0A1A, warm pink-orange rim lighting, "
    "clean sharp anime linework, soft cel shading, high detail, 4K, "
    "no text, no watermark, centered composition"
)

CHARACTERS = [
    # --- Hikari (6 reactions) ---
    {
        "filename": "hikari_idle.png",
        "prompt": f"{HIKARI_STYLE}, neutral calm expression, gentle slight smile, relaxed pose, hand lightly touching headphone, peaceful serene atmosphere",
    },
    {
        "filename": "hikari_expect.png",
        "prompt": f"{HIKARI_STYLE}, excited anticipating expression, leaning forward eagerly, hands clasped together near chest, wide sparkling hopeful eyes, intense focused gaze, neon lines pulsing with energy",
    },
    {
        "filename": "hikari_happy.png",
        "prompt": f"{HIKARI_STYLE}, very happy celebrating, big radiant smile showing teeth, small fist pump with right hand, sparkling joyful eyes, neon pink glow intensified, firework sparkles around her",
    },
    {
        "filename": "hikari_sad.png",
        "prompt": f"{HIKARI_STYLE}, disappointed sad expression, shoulders slightly drooping, looking downward, dejected soft eyes, neon glow dimmed to softer tone, but subtle hint of determination remaining",
    },
    {
        "filename": "hikari_excited.png",
        "prompt": f"{HIKARI_STYLE}, extremely excited ecstatic, both arms raised up high, huge open-mouth grin, hair glowing maximum neon pink intensity, firework explosion effects behind her, jumping with electric energy and joy",
    },
    {
        "filename": "hikari_reach_me.png",
        "prompt": f"{HIKARI_STYLE}, shocked wide-eyed surprise, mouth open in disbelief, eyes very wide with contracted pupils, leaning back, hands raised in shock, dramatic neon glitch visual effects at edges, startled intense expression",
    },
    # --- Luna (2 reactions) ---
    {
        "filename": "luna_excited.png",
        "prompt": f"{LUNA_STYLE}, extremely excited triumphant expression, confident smirk with raised eyebrow, both hands up making victory V signs, electric blue energy crackling around her, cool confident celebration, blue neon intensified",
    },
    {
        "filename": "luna_bonus.png",
        "prompt": f"{LUNA_STYLE}, mysterious alluring smile, one hand extended forward invitingly, half-closed eyes with knowing expression, blue aura surrounding her, crescent moon glowing behind her head, mystical elegant bonus celebration pose",
    },
    # --- Koharu (2 reactions) ---
    {
        "filename": "koharu_happy.png",
        "prompt": f"{KOHARU_STYLE}, sweetly happy warm smile, both hands clasped together near cheek, tilted head, warm gentle sparkling eyes, cherry blossom petals floating around, warm pink aura, cozy heartwarming expression",
    },
    {
        "filename": "koharu_bonus.png",
        "prompt": f"{KOHARU_STYLE}, cheerful energetic celebration, waving happily with right hand, bright open smile, cherry blossoms blooming around her, warm golden and pink light effects, festive joyful bonus celebration atmosphere",
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
            with urllib.request.urlopen(req, timeout=180) as resp:
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
    # Save at full 1024x1024, Godot handles scaling
    img = img.convert("RGBA")
    img.save(output_path, "PNG")
    fsize = os.path.getsize(output_path)
    print(f"  Saved: {output_path} ({img.size[0]}x{img.size[1]}, {fsize:,} bytes)")
    return fsize


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true", help="Overwrite all (default: skip existing)")
    parser.add_argument("--char", type=str, help="Only generate for specific character (hikari/luna/koharu)")
    args = parser.parse_args()

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    os.makedirs(BACKUP_DIR, exist_ok=True)

    # Filter characters if --char specified
    targets = CHARACTERS
    if args.char:
        targets = [c for c in CHARACTERS if c["filename"].startswith(args.char)]
        if not targets:
            print(f"ERROR: No characters matching '{args.char}'")
            sys.exit(1)

    print("NEON FLORA - Hi-Res Character Generator")
    print(f"Output: {OUTPUT_DIR}")
    print(f"Generation: {GEN_SIZE}x{GEN_SIZE}")
    print(f"Targets: {len(targets)} images")
    print("=" * 60)

    # Backup existing files
    from shutil import copy2
    for char in targets:
        src = os.path.join(OUTPUT_DIR, char["filename"])
        if os.path.exists(src):
            dst = os.path.join(BACKUP_DIR, char["filename"])
            copy2(src, dst)
            print(f"  Backed up: {char['filename']}")

    results = []
    total = len(targets)

    for idx, char in enumerate(targets, 1):
        out_path = os.path.join(OUTPUT_DIR, char["filename"])
        print(f"\n[{idx}/{total}] {char['filename']}")

        if not args.force and os.path.exists(out_path):
            existing = os.path.getsize(out_path)
            # Skip only if already hi-res (> 500KB typically)
            if existing > 500 * 1024:
                print(f"  SKIP: already hi-res ({existing:,} bytes). Use --force to overwrite.")
                results.append((char["filename"], "skipped", existing))
                continue

        print(f"  Prompt: {char['prompt'][:120]}...")
        try:
            img_bytes = call_api(char["prompt"])
            fsize = save_image(img_bytes, out_path)
            results.append((char["filename"], "OK", fsize))
        except Exception as e:
            print(f"  FAILED: {e}")
            results.append((char["filename"], f"FAILED: {e}", 0))

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
        print(f"\nAll {total} character images processed.")
        print("Next step: run remove_bg.py to remove backgrounds.")


if __name__ == "__main__":
    main()
