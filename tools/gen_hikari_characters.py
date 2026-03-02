"""
NEON FLORA — Hikari character reaction image generator
Generates 6 portrait images via HuggingFace FLUX.1-schnell API.

Output: neon_flora/assets/images/character/hikari_*.png
Size: 400x400 pixels (generated at higher res then resized)
Style: Anime/VTuber cyberpunk — neon pink/magenta hair, odd eyes (cyan+gold), dark bg
"""

import os
import sys
import time
import io
import requests
from PIL import Image

# --- Config ---
API_URL = "https://router.huggingface.co/hf-inference/models/black-forest-labs/FLUX.1-schnell"
OUTPUT_DIR = r"C:\xampp\htdocs\rpg_game\neon_flora\assets\images\characters"
TARGET_SIZE = (400, 400)
MAX_RETRIES = 3

# Common style prefix matching the proposal design
STYLE_PREFIX = (
    "anime style, VTuber, portrait, bust shot, "
    "girl named Hikari, 17 years old, "
    "neon pink to magenta gradient twin tails hair with glowing tips, "
    "LED ring hair accessories, "
    "odd eyes left eye cyan blue right eye gold, fireworks in pupils, "
    "black sailor uniform with neon pink light lines and firework embroidery, "
    "one-ear headphones, firework ball brooch, "
    "cyberpunk neon aesthetic, cyber-japanesque, "
    "dark navy background #0A0A1A, neon pink glow rim lighting, "
    "high quality, detailed, clean linework, soft shading, "
    "4K, masterpiece"
)

STYLE_SUFFIX = (
    ", no text, no watermark, no signature, centered composition"
)

IMAGES = [
    {
        "filename": "hikari_idle.png",
        "prompt": (
            f"{STYLE_PREFIX}, "
            "neutral calm expression, slight gentle smile, relaxed pose, "
            "hand lightly touching headphones, slight body sway, "
            "soft neon pink glow, peaceful, cozy atmosphere"
            f"{STYLE_SUFFIX}"
        ),
    },
    {
        "filename": "hikari_expect.png",
        "prompt": (
            f"{STYLE_PREFIX}, "
            "excited anticipating expression, leaning forward slightly, "
            "hands clasped together, wide hopeful eyes, "
            "holding breath in anticipation, intense focused gaze, "
            "neon lines pulsing with energy"
            f"{STYLE_SUFFIX}"
        ),
    },
    {
        "filename": "hikari_happy.png",
        "prompt": (
            f"{STYLE_PREFIX}, "
            "very happy celebrating expression, big bright smile, "
            "small fist pump gesture, triumphant pose, "
            "sparkling happy eyes, neon pink glow intensified, "
            "joyful energy, firework sparkles in background"
            f"{STYLE_SUFFIX}"
        ),
    },
    {
        "filename": "hikari_sad.png",
        "prompt": (
            f"{STYLE_PREFIX}, "
            "disappointed sad expression, shoulders drooping, "
            "looking slightly downward, dejected pose, "
            "soft sad eyes with slight tears, neon glow dimmed, "
            "but still a hint of determination to try again"
            f"{STYLE_SUFFIX}"
        ),
    },
    {
        "filename": "hikari_excited.png",
        "prompt": (
            f"{STYLE_PREFIX}, "
            "extremely excited expression, both arms raised up in the air, "
            "jumping pose, ecstatic huge grin, "
            "hair glowing at maximum intensity neon pink magenta, "
            "firework explosion effects around her, "
            "screaming with joy tamaya, electric energy"
            f"{STYLE_SUFFIX}"
        ),
    },
    {
        "filename": "hikari_reach_me.png",
        "prompt": (
            f"{STYLE_PREFIX}, "
            "shocked surprised wide-eyed expression, mouth open in surprise, "
            "eyes very wide, leaning back slightly, "
            "hands raised in shock, dramatic reaction, "
            "neon glitch effect around edges, intense dramatic lighting, "
            "startled disbelief"
            f"{STYLE_SUFFIX}"
        ),
    },
]


def generate_image(prompt: str, output_path: str) -> bool:
    """Generate an image via HuggingFace API and save to output_path."""
    api_key = os.environ.get("HF_API_KEY")
    if not api_key:
        print("ERROR: HF_API_KEY environment variable not set.")
        sys.exit(1)

    headers = {"Authorization": f"Bearer {api_key}"}
    payload = {
        "inputs": prompt,
        "parameters": {
            "width": 768,
            "height": 768,
        },
    }

    for attempt in range(1, MAX_RETRIES + 1):
        print(f"  Attempt {attempt}/{MAX_RETRIES}...")
        try:
            response = requests.post(API_URL, headers=headers, json=payload, timeout=120)

            if response.status_code == 200:
                # FLUX sometimes returns JPEG with PNG content-type; handle both
                image_data = response.content
                img = Image.open(io.BytesIO(image_data))
                img = img.convert("RGBA")
                img = img.resize(TARGET_SIZE, Image.LANCZOS)
                img.save(output_path, "PNG")
                print(f"  Saved: {output_path} ({TARGET_SIZE[0]}x{TARGET_SIZE[1]})")
                return True

            elif response.status_code == 503:
                wait_time = 30 if attempt < 3 else 60
                print(f"  503 Model loading — waiting {wait_time}s...")
                time.sleep(wait_time)

            elif response.status_code == 429:
                print(f"  429 Rate limit — waiting 60s...")
                time.sleep(60)

            else:
                print(f"  HTTP {response.status_code}: {response.text[:200]}")
                if attempt < MAX_RETRIES:
                    time.sleep(10)

        except requests.exceptions.Timeout:
            print(f"  Request timed out.")
            if attempt < MAX_RETRIES:
                time.sleep(15)
        except Exception as e:
            print(f"  Unexpected error: {e}")
            if attempt < MAX_RETRIES:
                time.sleep(10)

    print(f"  FAILED after {MAX_RETRIES} attempts.")
    return False


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print(f"Output directory: {OUTPUT_DIR}")
    print(f"Target size: {TARGET_SIZE[0]}x{TARGET_SIZE[1]}")
    print(f"Total images to generate: {len(IMAGES)}")
    print("=" * 60)

    results = []
    for i, img_spec in enumerate(IMAGES, 1):
        filename = img_spec["filename"]
        output_path = os.path.join(OUTPUT_DIR, filename)
        print(f"\n[{i}/{len(IMAGES)}] Generating: {filename}")

        if os.path.exists(output_path):
            print(f"  Already exists — skipping (delete to regenerate)")
            results.append((filename, "skipped"))
            continue

        success = generate_image(img_spec["prompt"], output_path)
        results.append((filename, "OK" if success else "FAILED"))

        # Brief pause between requests to avoid rate limiting
        if i < len(IMAGES) and success:
            time.sleep(3)

    print("\n" + "=" * 60)
    print("Results:")
    for filename, status in results:
        print(f"  {status:8s}  {filename}")

    failed = [r for r in results if r[1] == "FAILED"]
    if failed:
        print(f"\nWARNING: {len(failed)} image(s) failed to generate.")
        sys.exit(1)
    else:
        print(f"\nAll {len(IMAGES)} images processed successfully.")


if __name__ == "__main__":
    main()
