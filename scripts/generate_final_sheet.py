#!/usr/bin/env python3
"""
Generate the final sprite sheet for aldeano using FLUX.1-kontext-pro.
This model is designed for image-to-image with maximum consistency.
"""

import os, sys, base64, io
from pathlib import Path
from together import Together
from PIL import Image

DIRS = ['right', 'down-right', 'down', 'down-left', 'left']
ANIMS = [
    ('idle',     'standing still, idle pose'),
    ('walking',  'walking forward, mid-stride'),
    ('attacking','swinging hand axe, arm forward'),
    ('dying',    'falling backward, hurt'),
]

def main():
    ref_path = Path("sprites/infanteria/aldeano/aldeano_128_sin.png")
    out_path = Path("sprites/infanteria/aldeano/aldeano_spritesheet.png")

    api_key = os.environ.get("TOGETHER_API_KEY")
    if not api_key:
        print("ERROR: Set TOGETHER_API_KEY")
        sys.exit(1)

    client = Together(api_key=api_key)

    with open(ref_path, "rb") as f:
        ref_b64 = "data:image/png;base64," + base64.b64encode(f.read()).decode()

    # Get original reference color for comparison
    orig = Image.open(ref_path).convert('RGBA')
    ref_tunic = orig.getpixel((64, 64))

    frames = []
    total = len(DIRS) * len(ANIMS)
    idx = 0

    for anim_name, anim_desc in ANIMS:
        for dir_name in DIRS:
            idx += 1
            print(f"[{idx:2d}/{total}] {dir_name:12s} {anim_name:10s} ...", end=" ", flush=True)

            prompt = (
                f"Change the character pose to face {dir_name}, {anim_desc}. "
                f"Keep EXACTLY the same character, same blue tunic, same brown hair, "
                f"same proportions, same colors."
            )

            try:
                resp = client.images.generate(
                    model="black-forest-labs/FLUX.1-kontext-pro",
                    prompt=prompt,
                    image_url=ref_b64,
                    width=512, height=512, n=1,
                    response_format="b64_json",
                    steps=8, seed=200 + idx,
                )
                img = Image.open(io.BytesIO(base64.b64decode(resp.data[0].b64_json)))
                img = img.resize((128, 128), Image.LANCZOS).convert("RGBA")
                frames.append(img)

                tc = img.getpixel((64, 64))
                diff = sum(abs(tc[j] - ref_tunic[j]) for j in range(3))
                status = "✓" if diff < 100 else "~"
                print(f"{status} (diff={diff})")
            except Exception as e:
                print(f"✗ {e}")
                # Fill with a placeholder if it fails
                placeholder = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
                frames.append(placeholder)

    # Build sheet
    sheet = Image.new("RGBA", (640, 512), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        x = (i % 5) * 128
        y = (i // 5) * 128
        sheet.paste(f, (x, y), f)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out_path, "PNG")
    print(f"\n✓ Saved: {out_path}")
    print(f"  {len(frames)} frames · 640×512")

if __name__ == "__main__":
    main()
