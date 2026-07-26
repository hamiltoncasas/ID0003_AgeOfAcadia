#!/usr/bin/env python3
"""Generate 20-frame sprite sheet with FLUX.1-schnell (cheapest model)."""
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
    anims = ["idle", "walking", "attacking", "dying"]
    descs = ["standing idle", "walking stride", "swinging axe", "falling hurt"]
    frames = []
    total = 20
    idx = 0

    for ai, anim in enumerate(anims):
        for di, d in enumerate(dirs):
            idx += 1
            print(f"[{idx}/{total}] {d} {anim}...", end=" ", flush=True)
            try:
                r = client.images.generate(
                    model="black-forest-labs/FLUX.1-schnell",
                    prompt=f"pixel art game sprite, AoE2 isometric villager blue tunic, facing {d}, {descs[ai]}, same character as reference",
                    image_url=ref,
                    width=512, height=512, n=1,
                    response_format="b64_json", steps=4, seed=100 + idx,
                )
                img = Image.open(io.BytesIO(base64.b64decode(r.data[0].b64_json)))
                img = img.resize((128, 128), Image.LANCZOS).convert("RGBA")
                frames.append(img)
                print("ok")
            except Exception as e:
                print(f"FAIL: {e}")
                frames.append(Image.new("RGBA", (128, 128), (255, 0, 0, 128)))

    sheet = Image.new("RGBA", (640, 512), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, ((i % 5) * 128, (i // 5) * 128), f)

    out = "sprites/infanteria/aldeano/aldeano_spritesheet.png"
    sheet.save(out, "PNG")
    print(f"\nDone: {out} ({len(frames)} frames, ~${len(frames)*0.0027:.3f})")

if __name__ == "__main__":
    main()
