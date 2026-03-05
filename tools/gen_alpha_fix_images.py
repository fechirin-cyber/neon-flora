"""
NEON FLORA - Alpha Fix Image Generation
M-2: game_bg.png (dark navy, less purple)
M-3: luna_excited.png, luna_bonus.png
M-4: koharu_happy.png, koharu_bonus.png
"""
import os
import io
import time
import requests
from PIL import Image

HF_API_KEY = os.environ.get("HF_API_KEY", "")
API_URL = "https://router.huggingface.co/hf-inference/models/black-forest-labs/FLUX.1-schnell"

ASSETS_BASE = "C:/xampp/htdocs/rpg_game/neon_flora/assets/images"

TASKS = [
    {
        "id": "M-2",
        "name": "game_bg",
        "output": f"{ASSETS_BASE}/game_bg.png",
        "api_width": 768,
        "api_height": 1344,
        "final_size": (900, 1600),
        "prompt": (
            "Dark navy (#0A0A1A to #1A1A2E gradient) cyberpunk cityscape at night, "
            "neon signs glowing in pink and cyan scattered throughout, "
            "Japanese lanterns and cherry blossom neon decorations, "
            "very dark background with pinpoints of neon light, "
            "portrait orientation, minimal purple, emphasis on dark navy and black tones, "
            "no characters, no people, atmospheric depth, ultra detailed, cinematic"
        ),
    },
    {
        "id": "M-3a",
        "name": "luna_excited",
        "output": f"{ASSETS_BASE}/characters/luna_excited.png",
        "api_width": 1024,
        "api_height": 1024,
        "final_size": (1024, 1024),
        "prompt": (
            "MUST HAVE: deep blue to purple gradient long straight hair, cat ear LED headset glowing blue, "
            "gothic cyber outfit with black base and blue neon glowing accents, "
            "excited ecstatic expression shouting with joy, eyes wide open with star sparkles, "
            "neon blue (#00BFFF) rim lighting from behind, "
            "anime VTuber portrait style, bust shot, upper body, "
            "dark navy background (#0A0A1A), clean sharp anime linework, soft cel shading, "
            "high detail, 4K, no text, no watermark, "
            "amethyst purple eyes glowing with stars when excited"
        ),
    },
    {
        "id": "M-3b",
        "name": "luna_bonus",
        "output": f"{ASSETS_BASE}/characters/luna_bonus.png",
        "api_width": 1024,
        "api_height": 1024,
        "final_size": (1024, 1024),
        "prompt": (
            "MUST HAVE: deep blue to purple gradient long straight hair, cat ear LED headset glowing blue, "
            "gothic cyber outfit with black base and blue neon glowing accents, "
            "smug confident bonus expression, slight smile, eyes gleaming, "
            "neon blue (#00BFFF) rim lighting from behind, "
            "anime VTuber portrait style, bust shot, upper body, "
            "dark navy background (#0A0A1A), clean sharp anime linework, soft cel shading, "
            "high detail, 4K, no text, no watermark, "
            "amethyst purple eyes with subtle glow"
        ),
    },
    {
        "id": "M-4a",
        "name": "koharu_happy",
        "output": f"{ASSETS_BASE}/characters/koharu_happy.png",
        "api_width": 1024,
        "api_height": 1024,
        "final_size": (1024, 1024),
        "prompt": (
            "MUST HAVE: pastel orange to peach pink wavy hair, flower hairpin microphone headset with glowing petals, "
            "white base outfit with orange and gold accents and Japanese obi ribbon bow, "
            "cheerful happy expression with big warm smile, eyes curved joyfully, "
            "neon amber (#FFB347) rim lighting from behind, "
            "anime VTuber portrait style, bust shot, upper body, "
            "dark navy background (#0A0A1A), clean sharp anime linework, soft cel shading, "
            "high detail, 4K, no text, no watermark, "
            "amber colored eyes warm and gentle"
        ),
    },
    {
        "id": "M-4b",
        "name": "koharu_bonus",
        "output": f"{ASSETS_BASE}/characters/koharu_bonus.png",
        "api_width": 1024,
        "api_height": 1024,
        "final_size": (1024, 1024),
        "prompt": (
            "MUST HAVE: pastel orange to peach pink wavy hair, flower hairpin microphone headset with glowing petals, "
            "white base outfit with orange and gold accents and Japanese obi ribbon bow, "
            "gentle happy bonus expression, soft smile, slightly surprised but pleased, "
            "neon amber (#FFB347) rim lighting from behind, "
            "anime VTuber portrait style, bust shot, upper body, "
            "dark navy background (#0A0A1A), clean sharp anime linework, soft cel shading, "
            "high detail, 4K, no text, no watermark, "
            "amber colored eyes warm and glowing with happiness"
        ),
    },
]


def generate_image(prompt: str, width: int, height: int, max_retries: int = 3) -> bytes:
    headers = {
        "Authorization": f"Bearer {HF_API_KEY}",
        "Content-Type": "application/json",
    }
    payload = {
        "inputs": prompt,
        "parameters": {
            "width": width,
            "height": height,
            "num_inference_steps": 4,
        },
    }

    for attempt in range(1, max_retries + 1):
        print(f"  API call attempt {attempt}/{max_retries}...")
        try:
            resp = requests.post(API_URL, headers=headers, json=payload, timeout=120)
            if resp.status_code == 200:
                print(f"  Success ({len(resp.content)} bytes)")
                return resp.content
            elif resp.status_code == 503:
                wait = 40 if attempt < 3 else 60
                print(f"  503 Model loading, waiting {wait}s...")
                time.sleep(wait)
            elif resp.status_code == 429:
                print(f"  429 Rate limit, waiting 60s...")
                time.sleep(60)
            else:
                print(f"  Error {resp.status_code}: {resp.text[:200]}")
                if attempt < max_retries:
                    time.sleep(10)
        except requests.exceptions.Timeout:
            print(f"  Timeout on attempt {attempt}")
            if attempt < max_retries:
                time.sleep(15)
        except Exception as e:
            print(f"  Exception: {e}")
            if attempt < max_retries:
                time.sleep(10)

    raise RuntimeError(f"Failed after {max_retries} attempts")


def save_image(raw_bytes: bytes, output_path: str, final_size: tuple) -> dict:
    # FLUX sometimes returns JPEG bytes with PNG extension
    img = Image.open(io.BytesIO(raw_bytes))
    print(f"  Raw format: {img.format}, size: {img.size}, mode: {img.mode}")

    # Resize to final size if needed
    if img.size != final_size:
        img = img.resize(final_size, Image.LANCZOS)
        print(f"  Resized to: {final_size}")

    # Convert to RGBA for PNG with transparency support (characters)
    # Keep RGB for backgrounds to reduce file size
    if "characters" in output_path:
        if img.mode != "RGBA":
            img = img.convert("RGBA")
    else:
        if img.mode not in ("RGB", "RGBA"):
            img = img.convert("RGB")

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    img.save(output_path, "PNG")

    file_size_kb = os.path.getsize(output_path) // 1024
    return {
        "path": output_path,
        "size": img.size,
        "mode": img.mode,
        "file_kb": file_size_kb,
    }


def main():
    if not HF_API_KEY:
        print("ERROR: HF_API_KEY environment variable is not set")
        return

    print(f"HF_API_KEY: {'*' * (len(HF_API_KEY) - 4)}{HF_API_KEY[-4:]}")
    print(f"Total tasks: {len(TASKS)}")
    print()

    results = []

    for task in TASKS:
        print(f"[{task['id']}] Generating: {task['name']}")
        print(f"  Output: {task['output']}")
        print(f"  API size: {task['api_width']}x{task['api_height']}")
        print(f"  Final size: {task['final_size']}")

        try:
            raw = generate_image(task["prompt"], task["api_width"], task["api_height"])
            info = save_image(raw, task["output"], task["final_size"])
            print(f"  Saved: {info['size']} {info['mode']} {info['file_kb']}KB")
            results.append({"task": task["id"], "name": task["name"], "status": "OK", **info})
        except Exception as e:
            print(f"  FAILED: {e}")
            results.append({"task": task["id"], "name": task["name"], "status": "FAILED", "error": str(e)})

        print()

    print("=" * 60)
    print("RESULTS SUMMARY")
    print("=" * 60)
    for r in results:
        if r["status"] == "OK":
            print(f"  [OK]     {r['name']:20s} {r['size'][0]}x{r['size'][1]}  {r['file_kb']}KB  {r['path']}")
        else:
            print(f"  [FAILED] {r['name']:20s} {r.get('error', '')}")


if __name__ == "__main__":
    main()
