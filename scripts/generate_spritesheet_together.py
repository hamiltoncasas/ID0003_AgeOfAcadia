#!/usr/bin/env python3
"""
Generate a sprite sheet using Together AI (FLUX.1-schnell) with image-to-image.
Takes the reference _sin.png and generates multiple frames/directions,
compiling them into a sprite sheet.

Usage:
    export TOGETHER_API_KEY="tgp_v1_..."
    python scripts/generate_spritesheet_together.py \
      --input sprites/infanteria/aldeano/aldeano_128_sin.png \
      --prompt "Age of Empires 2 isometric pixel art, male villager..." \
      --output sprites/infanteria/aldeano/aldeano_spritesheet.png \
      --rows 4 --cols 5
"""

import os
import sys
import base64
import io
import argparse
import time
from pathlib import Path
from together import Together
from PIL import Image

DIRECTIONS = [
    ("right", "facing right"),
    ("down-right", "facing down-right"),
    ("down", "facing down"),
    ("down-left", "facing down-left"),
    ("left", "facing left"),
]

FRAME_TYPES = ["idle", "walking", "attacking", "dying"]

STEP_COUNTS = {
    "idle": 4,
    "walking": 6,
    "attacking": 6,
    "dying": 4,
}

def encode_image(image_path: Path) -> str:
    """Read image and return base64 data URI."""
    with open(image_path, "rb") as f:
        data = base64.b64encode(f.read()).decode("utf-8")
    return f"data:image/png;base64,{data}"


def generate_frame(client: Together, ref_b64: str, prompt: str,
                   direction_desc: str, frame_type: str, seed: int,
                   index: int, total: int) -> Image.Image | None:
    """Generate one frame using Together AI FLUX image-to-image."""

    full_prompt = (
        f"pixel art style, game sprite, {prompt}, "
        f"{direction_desc}, {frame_type} frame, "
        f"transparent background, 512x512, retro game character, isolated, "
        f"AoE2 style, game asset"
    )

    print(f"  [{index}/{total}] {direction_desc} {frame_type} ...", end=" ", flush=True)

    try:
        steps = STEP_COUNTS.get(frame_type, 4)
        resp = client.images.generate(
            model="black-forest-labs/FLUX.1-schnell",
            prompt=full_prompt,
            image_url=ref_b64,
            width=512,
            height=512,
            steps=steps,
            n=1,
            response_format="b64_json",
            guidance_scale=3.0,
            seed=seed,
        )

        img_data = resp.data[0].b64_json
        img = Image.open(io.BytesIO(base64.b64decode(img_data)))

        # Resize to 128x128 (game size)
        img = img.resize((128, 128), Image.LANCZOS)

        # Convert to RGBA
        if img.mode != "RGBA":
            img = img.convert("RGBA")

        print("✓")
        return img

    except Exception as e:
        print(f"✗ {e}")
        return None


def main():
    parser = argparse.ArgumentParser(description="Sprite sheet via Together AI")
    parser.add_argument("--input", required=True, type=Path,
                        help="Reference _sin.png sprite")
    parser.add_argument("--output", required=True, type=Path,
                        help="Output sprite sheet PNG")
    parser.add_argument("--prompt", required=True,
                        help="Base prompt describing the character")
    parser.add_argument("--rows", type=int, default=4)
    parser.add_argument("--cols", type=int, default=5)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    api_key = os.environ.get("TOGETHER_API_KEY")
    if not api_key:
        print("ERROR: Set TOGETHER_API_KEY")
        sys.exit(1)

    if not args.input.exists():
        print(f"ERROR: {args.input} not found")
        sys.exit(1)

    client = Together(api_key=api_key)

    # Encode reference image
    print("Loading reference image...")
    ref_b64 = encode_image(args.input)

    total = args.rows * args.cols
    frames = []

    print(f"\nGenerating {total} frames...")
    print(f"  Model: black-forest-labs/FLUX.1-schnell")
    print(f"  Reference: {args.input.name}")
    print()

    for i in range(total):
        direction_name, direction_desc = DIRECTIONS[i % len(DIRECTIONS)]
        frame_type = FRAME_TYPES[(i // len(DIRECTIONS)) % len(FRAME_TYPES)]
        seed = args.seed + i

        img = generate_frame(client, ref_b64, args.prompt,
                            direction_desc, frame_type,
                            seed, i + 1, total)
        if img:
            frames.append(img)

    if not frames:
        print("\nERROR: No frames generated.")
        sys.exit(1)

    actual = len(frames)
    cols = min(args.cols, actual)
    rows = (actual + cols - 1) // cols
    fw, fh = 128, 128

    sheet = Image.new("RGBA", (cols * fw, rows * fh), (0, 0, 0, 0))
    for idx, frame in enumerate(frames):
        x = (idx % cols) * fw
        y = (idx // cols) * fh
        sheet.paste(frame, (x, y), frame)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.output, "PNG")
    print(f"\n✓ Sprite sheet saved: {args.output}")
    print(f"  {actual} frames · {cols}×{rows} grid · 128×128 each")
    print(f"  Final size: {sheet.size[0]}×{sheet.size[1]} px")


if __name__ == "__main__":
    main()
