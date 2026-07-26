#!/usr/bin/env python3
"""
Generate a CONSISTENT sprite sheet. Creates one perfect base frame with AI,
then uses it as reference for ALL frames. Higher guidance + same reference
= way more consistency across directions AND animations.
"""

import os, sys, base64, io, argparse
from pathlib import Path
from together import Together
from PIL import Image

DIRECTIONS = [
    ("right", "facing right, profile view"),
    ("down-right", "facing down-right, 3/4 view"),
    ("down", "facing down, front view"),
    ("down-left", "facing down-left, 3/4 view"),
    ("left", "facing left, profile view"),
]

FRAME_TYPES = ["idle", "walking", "attacking", "dying"]

STEP_MAP = {"idle": 8, "walking": 6, "attacking": 6, "dying": 4}

def encode(path):
    with open(path, "rb") as f:
        return "data:image/png;base64," + base64.b64encode(f.read()).decode("utf-8")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--prompt", required=True)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    api_key = os.environ.get("TOGETHER_API_KEY")
    if not api_key:
        print("ERROR: Set TOGETHER_API_KEY")
        sys.exit(1)

    client = Together(api_key=api_key)
    ref_b64 = encode(args.input)

    # Step 1: Generate ONE rock-solid base frame
    print("Generating base frame...")
    base_prompt = (
        f"pixel art style, game sprite, {args.prompt}, "
        f"facing down, standing idle, looking at camera, "
        f"both feet planted, arms relaxed, symmetrical pose, "
        f"AoE2 style, retro game character"
    )
    resp = client.images.generate(
        model="black-forest-labs/FLUX.1-schnell",
        prompt=base_prompt,
        image_url=ref_b64,
        width=512, height=512, steps=8, n=1,
        response_format="b64_json", guidance_scale=7.0,
        seed=args.seed,
    )
    base = Image.open(io.BytesIO(base64.b64decode(resp.data[0].b64_json)))
    base = base.resize((128, 128), Image.LANCZOS)
    if base.mode != "RGBA":
        base = base.convert("RGBA")
    base.save("/tmp/_base_frame.png")
    print(f"  ✓ Base frame (128x128)\n")

    # Use base frame as reference for ALL subsequent frames
    base_ref = encode(Path("/tmp/_base_frame.png"))
    frames = []
    total = len(DIRECTIONS) * len(FRAME_TYPES)

    for fi, (frame_type) in enumerate(FRAME_TYPES):
        for di, (dir_name, dir_desc) in enumerate(DIRECTIONS):
            idx = fi * len(DIRECTIONS) + di + 1
            steps = STEP_MAP.get(frame_type, 6)

            print(f"  [{idx:2d}/{total}] {dir_name:12s} {frame_type:10s} ...", end=" ", flush=True)

            motion_desc = {
                "idle": "standing still, idle pose, feet planted, arms at sides",
                "walking": "walking forward, one leg forward, arms swinging naturally, mid-stride pose",
                "attacking": "swinging hand axe, action pose, arm raised with weapon",
                "dying": "falling backward, hurt, arms flailing, losing balance",
            }.get(frame_type, frame_type)

            prompt = (
                f"pixel art, game sprite, {args.prompt}, "
                f"EXACT same character as reference image, same clothes, same colors, same proportions, "
                f"{dir_desc}, {motion_desc}, "
                f"AoE2 isometric style, retro game character, consistent design"
            )

            try:
                resp = client.images.generate(
                    model="black-forest-labs/FLUX.1-schnell",
                    prompt=prompt,
                    image_url=base_ref,
                    width=512, height=512, steps=steps, n=1,
                    response_format="b64_json", guidance_scale=7.0,
                    seed=args.seed + idx,
                )
                img = Image.open(io.BytesIO(base64.b64decode(resp.data[0].b64_json)))
                img = img.resize((128, 128), Image.LANCZOS)
                if img.mode != "RGBA":
                    img = img.convert("RGBA")
                frames.append(img)
                print("✓")
            except Exception as e:
                print(f"✗ {e}")

    if not frames:
        print("ERROR: No frames")
        sys.exit(1)

    fw, fh = 128, 128
    cols, rows = 5, (len(frames) + 4) // 5
    sheet = Image.new("RGBA", (cols * fw, rows * fh), (0, 0, 0, 0))
    for idx, frame in enumerate(frames):
        x = (idx % cols) * fw
        y = (idx // cols) * fh
        sheet.paste(frame, (x, y), frame)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.output, "PNG")
    print(f"\n✓ Saved: {args.output}")
    print(f"  {len(frames)} frames · {cols}×{rows} · {sheet.size[0]}×{sheet.size[1]} px")

if __name__ == "__main__":
    main()
