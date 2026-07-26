#!/usr/bin/env python3
"""Generate ALL 20 frames in one continuous run - no mixing."""
import base64, io, os, sys
from PIL import Image
from together import Together

def main():
    api_key = os.environ.get("TOGETHER_API_KEY")
    if not api_key:
        print("ERROR: Set TOGETHER_API_KEY")
        sys.exit(1)

    client = Together(api_key=api_key)

    with open("sprites/infanteria/aldeano/aldeano_128_sin.png", "rb") as f:
        ref = "data:image/png;base64," + base64.b64encode(f.read()).decode()

    dirs = ["right", "down-right", "down", "down-left", "left"]
    anims = [
        ("idle",     "standing still, idle pose"),
        ("walking",  "walking forward with a stride, one leg forward"),
        ("attacking","swinging a hand axe, arm raised forward"),
        ("dying",    "falling backward, hurt, losing balance"),
    ]

    frames = []
    total = 20
    idx = 0

    for anim_name, anim_desc in anims:
        for d in dirs:
            idx += 1
            print(f"[{idx}/{total}] {d} {anim_name}...", end=" ", flush=True)
            try:
                r = client.images.generate(
                    model="black-forest-labs/FLUX.1-kontext-pro",
                    prompt=(
                        f"Change the character pose to face {d}, {anim_desc}. "
                        f"Keep EXACTLY the same character, "
                        f"same blue tunic, same brown hair, same proportions."
                    ),
                    image_url=ref,
                    width=512, height=512, n=1,
                    response_format="b64_json", steps=8,
                    seed=1000 + idx,
                )
                img = Image.open(io.BytesIO(base64.b64decode(r.data[0].b64_json)))
                img = img.resize((128, 128), Image.LANCZOS).convert("RGBA")
                frames.append(img)
                # Save each frame immediately
                img.save(f"/tmp/_s_{idx}.png")
                print("ok")
            except Exception as e:
                print(f"FAIL: {e}")
                frames.append(Image.new("RGBA", (128, 128), (255, 0, 0, 128)))

    # Build sheet
    sheet = Image.new("RGBA", (640, 512), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, ((i % 5) * 128, (i // 5) * 128), f)

    out = "sprites/infanteria/aldeano/aldeano_spritesheet.png"
    sheet.save(out, "PNG")
    print(f"\n✓ {out} ({len(frames)} frames)")

if __name__ == "__main__":
    main()
