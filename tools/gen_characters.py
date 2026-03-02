"""
NEON FLORA — Secondary Character Image Generator
Generates luna and koharu character images via HuggingFace FLUX.1-schnell.
Output: 400x400 PNG, bust/portrait, cyberpunk anime style.
"""

import requests
import os
import time
import sys
from io import BytesIO

try:
    from PIL import Image
except ImportError:
    print("Installing Pillow...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "Pillow"])
    from PIL import Image

API_URL = "https://router.huggingface.co/hf-inference/models/black-forest-labs/FLUX.1-schnell"
HF_API_KEY = os.environ.get("HF_API_KEY", "")

if not HF_API_KEY:
    print("ERROR: HF_API_KEY environment variable not set.")
    sys.exit(1)

HEADERS = {"Authorization": f"Bearer {HF_API_KEY}"}

OUTPUT_DIR = r"C:\xampp\htdocs\rpg_game\neon_flora\assets\images\characters"
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Base style tokens shared across all characters
BASE_STYLE = (
    "anime style, VTuber, bust portrait, upper body, cyberpunk neon aesthetics, "
    "dark background #0A0A1E midnight blue, glowing neon lights, "
    "high quality illustration, vivid colors, sharp lineart, "
    "no watermark, no text"
)

CHARACTERS = [
    {
        "filename": "luna_excited.png",
        "prompt": (
            f"{BASE_STYLE}, "
            "anime girl named Luna, 16 years old, cool confident expression turning excited and triumphant, "
            "eyes wide with stars, slight smirk becoming a grin, fist raised in victory, "
            "long straight deep blue to purple gradient hair with glowing tips, "
            "amethyst deep violet eyes with star reflections, "
            "gothic cyberpunk outfit black and dark navy with glowing blue neon lines, "
            "cat-ear headset with glowing red neon accents, "
            "red and cyan neon light rim lighting on face and hair, "
            "dynamic confident pose, electricity sparks around her"
        ),
    },
    {
        "filename": "luna_bonus.png",
        "prompt": (
            f"{BASE_STYLE}, "
            "anime girl named Luna, 16 years old, explosive celebrating pose, "
            "both arms raised triumphantly 'KITA KITA KITA!' energy, "
            "huge excited grin breaking from usual cool demeanor, "
            "long straight deep blue to purple gradient hair flying dramatically, "
            "amethyst violet eyes blazing with neon star light, "
            "gothic cyberpunk outfit black and dark navy with blazing blue neon lines, "
            "cat-ear headset sparking with red neon electricity, "
            "surrounded by dazzling neon sparks and digital fireworks blue purple red, "
            "flashy bonus celebration, dramatic lighting, particle effects"
        ),
    },
    {
        "filename": "koharu_happy.png",
        "prompt": (
            f"{BASE_STYLE}, "
            "anime girl named Koharu, 18 years old, warm gentle happy smile, "
            "soft kind expression like a caring older sister, "
            "medium-length pastel orange to peach pink wavy hair, loose fluffy waves, "
            "amber honey-colored eyes warm and gentle, "
            "white-based outfit with orange and gold accents, Japanese-style obi ribbon, "
            "floral kanzashi hair ornament that doubles as a microphone, "
            "pink neon soft glow rim lighting, warm orange neon light accents, "
            "relaxed gentle pose, soft bokeh background neon lights"
        ),
    },
    {
        "filename": "koharu_bonus.png",
        "prompt": (
            f"{BASE_STYLE}, "
            "anime girl named Koharu, 18 years old, cute gentle celebrating pose, "
            "soft delighted expression, happy surprised eyes, both hands clasped together, "
            "medium-length pastel orange to peach pink wavy hair with glowing tips, "
            "amber warm eyes sparkling with joy, "
            "white-based outfit with glowing orange and gold neon accents, Japanese-style obi ribbon glowing, "
            "floral kanzashi hair ornament sparkling, "
            "surrounded by soft pink and orange digital cherry blossoms and neon firefly lights, "
            "warm bonus celebration, gentle glowing particle effects, joyful energy"
        ),
    },
]

TARGET_W, TARGET_H = 400, 400
# Request a taller portrait so face/bust fills it well, then center-crop to square
GEN_W, GEN_H = 512, 768
MAX_RETRIES = 3


def generate_image(prompt: str, output_path: str) -> bool:
    """Call FLUX API, save result as PNG at 400x400."""
    payload = {
        "inputs": prompt,
        "parameters": {
            "width": GEN_W,
            "height": GEN_H,
        },
    }

    for attempt in range(1, MAX_RETRIES + 1):
        print(f"  Attempt {attempt}/{MAX_RETRIES}...")
        try:
            resp = requests.post(API_URL, headers=HEADERS, json=payload, timeout=120)
        except requests.exceptions.Timeout:
            print("  Timeout. Retrying...")
            time.sleep(20)
            continue
        except requests.exceptions.RequestException as e:
            print(f"  Request error: {e}")
            time.sleep(20)
            continue

        if resp.status_code == 200:
            # FLUX returns JPEG bytes even with PNG extension — use Pillow to re-save
            try:
                img = Image.open(BytesIO(resp.content)).convert("RGBA")
                # Center-crop to square then resize to 400x400
                w, h = img.size
                side = min(w, h)
                left = (w - side) // 2
                top = 0  # portrait: keep top (face area)
                img_cropped = img.crop((left, top, left + side, top + side))
                img_resized = img_cropped.resize((TARGET_W, TARGET_H), Image.LANCZOS)
                img_resized.save(output_path, "PNG")
                size_kb = os.path.getsize(output_path) // 1024
                print(f"  Saved: {output_path} ({TARGET_W}x{TARGET_H}, {size_kb} KB)")
                return True
            except Exception as e:
                print(f"  Image processing error: {e}")
                # Save raw bytes for inspection
                raw_path = output_path.replace(".png", "_raw.bin")
                with open(raw_path, "wb") as f:
                    f.write(resp.content)
                print(f"  Raw response saved to: {raw_path}")
                return False

        elif resp.status_code == 503:
            wait = 40 if attempt < MAX_RETRIES else 0
            print(f"  503 Model loading. Waiting {wait}s...")
            if wait:
                time.sleep(wait)
        elif resp.status_code == 429:
            wait = 60 if attempt < MAX_RETRIES else 0
            print(f"  429 Rate limit. Waiting {wait}s...")
            if wait:
                time.sleep(wait)
        else:
            print(f"  HTTP {resp.status_code}: {resp.text[:200]}")
            if attempt < MAX_RETRIES:
                time.sleep(15)

    print(f"  FAILED after {MAX_RETRIES} attempts.")
    return False


def main():
    print("=== NEON FLORA Character Image Generator ===")
    print(f"Output dir: {OUTPUT_DIR}")
    print()

    results = []
    for char in CHARACTERS:
        out_path = os.path.join(OUTPUT_DIR, char["filename"])

        if os.path.exists(out_path):
            size_kb = os.path.getsize(out_path) // 1024
            print(f"[SKIP] {char['filename']} already exists ({size_kb} KB)")
            results.append((char["filename"], "SKIPPED", size_kb))
            continue

        print(f"[GEN]  {char['filename']}")
        ok = generate_image(char["prompt"], out_path)
        if ok:
            size_kb = os.path.getsize(out_path) // 1024
            results.append((char["filename"], "OK", size_kb))
        else:
            results.append((char["filename"], "FAILED", 0))
        # Brief pause between requests to be polite to the API
        if char != CHARACTERS[-1]:
            time.sleep(3)

    print()
    print("=== Results ===")
    for fname, status, size_kb in results:
        print(f"  {status:8s}  {fname}  ({size_kb} KB)")
    print()
    failed = [r for r in results if r[1] == "FAILED"]
    if failed:
        print(f"WARNING: {len(failed)} image(s) failed to generate.")
        sys.exit(1)
    else:
        print("All images generated successfully.")


if __name__ == "__main__":
    main()
