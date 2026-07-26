#!/usr/bin/env python3
"""
Generate ONLY the 5 idle directions (one row) using FLUX.1.1-pro.
Each frame uses the ORIGINAL reference image with high guidance.
"""

import os, sys, base64, io
from pathlib import Path
from together import Together
from PIL import Image

DIRS = [
    ("right",     "facing right, profile view, feet pointing right"),
    ("down-right","facing down-right, 3/4 view, feet pointing down-right"),
    ("down",      "facing down, front view, both feet planted, looking at camera"),
    ("down-left", "facing down-left, 3/4 view, feet pointing down-left"),
    ("left",      "facing left, profile view, feet pointing left"),
]

def main():
    ref_path = Path("sprites/infanteria/aldeano/aldeano_128_sin.png")
    out_path = Path("sprites/infanteria/aldeano/aldeano_spritesheet.png")

    api_key = os.environ.get("TOGETHER_API_KEY")
    if not api_key:
        print("ERROR: Set TOGETHER_API_KEY")
        sys.exit(1)

    if not ref_path.exists():
        print(f"ERROR: {ref_path} not found")
        sys.exit(1)

    client = Together(api_key=api_key)

    with open(ref_path, "rb") as f:
        ref_b64 = "data:image/png;base64," + base64.b64encode(f.read()).decode()

    # Load original to get exact character colors for prompt
    orig = Image.open(ref_path)
    cx, cy = 64, 90  # center of tunic area
    tunic_color = orig.getpixel((cx, cy))
    hair_pixel = orig.getpixel((40, 30))
    pants_pixel = orig.getpixel((55, 105))
    print(f"Reference: tunic=({tunic_color[0]},{tunic_color[1]},{tunic_color[2]}) "
          f"hair=({hair_pixel[0]},{hair_pixel[1]},{hair_pixel[2]}) "
          f"pants=({pants_pixel[0]},{pants_pixel[1]},{pants_pixel[2]})")

    frames = []
    total = len(DIRS)

    for i, (name, desc) in enumerate(DIRS):
        print(f"\n  [{i+1}/{total}] {name} ...", end=" ", flush=True)

        prompt = (
            f"pixel art game sprite, EXACT same character as reference image, "
            f"IDENTICAL blue tunic rgb({tunic_color[0]},{tunic_color[1]},{tunic_color[2]}), "
            f"IDENTICAL brown hair, IDENTICAL proportions, "
            f"{desc}, standing idle, "
            f"AoE2 isometric style, 128x128 game character"
        )

        try:
            resp = client.images.generate(
                model="black-forest-labs/FLUX.1.1-pro",
                prompt=prompt,
                image_url=ref_b64,
                width=512, height=512, n=1,
                response_format="b64_json",
                guidance_scale=10.0, steps=10,
                seed=42 + i,
            )
            img = Image.open(io.BytesIO(base64.b64decode(resp.data[0].b64_json)))
            img = img.resize((128, 128), Image.LANCZOS)
            if img.mode != "RGBA":
                img = img.convert("RGBA")

            # Check center tunic color
            gc = img.getpixel((cx, cy))
            diff = sum(abs(gc[j] - tunic_color[j]) for j in range(3))
            print(f"✓ tunic_diff={diff}", end="")
            frames.append(img)
        except Exception as e:
            print(f"✗ {e}")

    if not frames:
        print("\nERROR: No frames")
        sys.exit(1)

    # Build strip
    fw, fh = 128, 128
    sheet = Image.new("RGBA", (len(frames) * fw, fh), (0, 0, 0, 0))
    for idx, frame in enumerate(frames):
        sheet.paste(frame, (idx * fw, 0), frame)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out_path, "PNG")
    print(f"\n\n✓ Saved: {out_path}")
    print(f"  {len(frames)} idle frames · {sheet.size[0]}×{sheet.size[1]}")

if __name__ == "__main__":
    main()
