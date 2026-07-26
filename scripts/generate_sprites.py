import os
import json
import time
import argparse
from together import Together
from PIL import Image
import base64
import io
import glob

client = Together()


def encode_img(img):
    """Convert a PIL Image to a base64 data URI for img2img reference."""
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode("utf-8")


def generate_base_frame(character_name, prompt, output_dir, steps=4, seed=None):
    """Generate a single high-quality base frame using FLUX.1.1-pro.

    This frame serves as the visual reference for ALL subsequent frames,
    ensuring character consistency across animations and directions.
    Produces a 512x512 image, resized to 128x128 and saved as reference.
    """
    full_prompt = (
        f"pixel art style, game sprite, {prompt}, "
        f"facing front, standing idle, looking at camera, "
        f"both feet planted, arms relaxed, symmetrical pose, "
        f"retro RTS game character, AoE2 style, clean silhouette"
    )

    print(f"  Generating base frame (FLUX.1.1-pro, {steps} steps, guidance 7.0)...")
    arguments = {
        "model": "black-forest-labs/FLUX.1.1-pro",
        "prompt": full_prompt,
        "width": 512,
        "height": 512,
        "steps": steps,
        "n": 1,
        "response_format": "b64_json",
        "guidance_scale": 7.0,
    }
    if seed is not None:
        arguments["seed"] = seed

    response = client.images.generate(**arguments)
    img_data = response.data[0].b64_json
    img = Image.open(io.BytesIO(base64.b64decode(img_data)))
    img = img.convert("RGBA")

    # Save reference at 128x128
    ref = img.resize((128, 128), Image.LANCZOS)
    os.makedirs(os.path.join(output_dir, character_name), exist_ok=True)
    ref_path = os.path.join(output_dir, character_name, f"{character_name}_base.png")
    ref.save(ref_path, "PNG")
    print(f"  Base frame saved: {ref_path}")
    return ref

SPRITE_SHEET_CONFIG = {
    "idle": {"frames": 4, "directions": 4},
    "walk": {"frames": 6, "directions": 4},
    "attack": {"frames": 4, "directions": 4},
    "hurt": {"frames": 2, "directions": 1},
}

STRIP_CONFIG = {
    "idle": {"frames": 3, "directions": 5},
    "walk": {"frames": 4, "directions": 5},
    "attack": {"frames": 2, "directions": 5},
    "hurt": {"frames": 2, "directions": 5},
    "death": {"frames": 3, "directions": 5},
}

DIRECTIONS = {
    0: "front",
    1: "front_angle",
    2: "profile",
    3: "back_angle",
    4: "back",
}

def generate_sprite(
    prompt,
    character_name,
    animation,
    direction,
    frame,
    output_dir,
    width=512,
    height=512,
    steps=4,
    seed=None,
    reference_image=None,
    consistent=False,
):
    full_prompt = f"pixel art style, game sprite, {prompt}, {animation} animation frame {frame}, {direction} view, transparent background, 512x512, retro game character, isolated"
    negative = "photorealistic, 3d, blurry, distorted, low quality, bad anatomy, extra limbs"

    model = "black-forest-labs/FLUX.1-schnell"
    guidance = 3.0

    if consistent:
        model = "black-forest-labs/FLUX.1-schnell"
        guidance = 7.0
        full_prompt = (
            f"pixel art, game sprite, {prompt}, "
            f"EXACT same character as reference image, same clothes, same colors, same proportions, "
            f"{direction} view, {animation} animation, frame {frame}, "
            f"AoE2 isometric style, retro game character, consistent design"
        )

    arguments = {
        "model": model,
        "prompt": full_prompt,
        "width": width,
        "height": height,
        "steps": steps,
        "n": 1,
        "response_format": "b64_json",
        "guidance_scale": guidance,
    }

    if seed is not None:
        arguments["seed"] = seed
    if reference_image is not None:
        arguments["image_url"] = encode_img(reference_image)

    response = client.images.generate(**arguments)
    img_data = response.data[0].b64_json
    img_bytes = base64.b64decode(img_data)
    img = Image.open(io.BytesIO(img_bytes))
    img = img.convert("RGBA")

    character_dir = os.path.join(output_dir, character_name, animation, direction)
    os.makedirs(character_dir, exist_ok=True)
    filename = f"{character_name}_{animation}_{direction}_frame{frame:02d}.png"
    img.save(os.path.join(character_dir, filename), "PNG")
    return filename


def generate_character_sheet(
    character_name,
    prompt,
    output_dir,
    steps=4,
    seed=None,
    animations=None,
    reference_image=None,
    consistent=False,
):
    if animations is None:
        animations = SPRITE_SHEET_CONFIG

    total_frames = sum(c["frames"] * c["directions"] for c in animations.values())
    generated = []
    for anim_name, config in animations.items():
        dir_count = config["directions"]
        frame_count = config["frames"]
        for d in range(dir_count):
            direction = DIRECTIONS[d]
            for f in range(frame_count):
                current_seed = seed + len(generated) if seed else None
                filename = generate_sprite(
                    prompt=prompt,
                    character_name=character_name,
                    animation=anim_name,
                    direction=direction,
                    frame=f,
                    output_dir=output_dir,
                    width=512,
                    height=512,
                    steps=steps,
                    seed=current_seed,
                    reference_image=reference_image,
                    consistent=consistent,
                )
                generated.append(filename)
                print(f"  [{len(generated)}/{total_frames}] {filename}")

    return generated


def create_sprite_sheet(character_name, output_dir, animations=None):
    if animations is None:
        animations = SPRITE_SHEET_CONFIG

    frames = []
    for anim_name, config in animations.items():
        dir_count = config["directions"]
        frame_count = config["frames"]
        for d in range(dir_count):
            direction = DIRECTIONS[d]
            for f in range(frame_count):
                path = os.path.join(output_dir, character_name, anim_name, direction, f"{character_name}_{anim_name}_{direction}_frame{f:02d}.png")
                if os.path.exists(path):
                    frames.append(Image.open(path))

    if not frames:
        return

    cols = max(8, len(frames))
    frame_w, frame_h = frames[0].size
    sheet = Image.new("RGBA", (cols * frame_w, ((len(frames) // cols) + 1) * frame_h), (0, 0, 0, 0))
    for i, frame in enumerate(frames):
        x = (i % cols) * frame_w
        y = (i // cols) * frame_h
        sheet.paste(frame, (x, y), frame if frame.mode == "RGBA" else None)

    os.makedirs(os.path.join(output_dir, character_name), exist_ok=True)
    sheet.save(os.path.join(output_dir, f"{character_name}_spritesheet.png"), "PNG")
    print(f"Created sprite sheet: {character_name}_spritesheet.png")


def create_strips(character_name, output_dir, animations=None):
    """Create horizontal strips from generated frames, one per animation x direction.

    For each animation-direction combo, assembles frames into a horizontal strip
    with each frame resized to 128x128 pixels.
    Strip filename: {character}_{animation}_{direction}.png
    """
    if animations is None:
        animations = STRIP_CONFIG

    target_size = (128, 128)
    strips = []

    for anim_name, config in animations.items():
        dir_count = config["directions"]
        frame_count = config["frames"]
        for d in range(dir_count):
            direction = DIRECTIONS[d]
            frames = []
            for f in range(frame_count):
                path = os.path.join(
                    output_dir, character_name, anim_name, direction,
                    f"{character_name}_{anim_name}_{direction}_frame{f:02d}.png",
                )
                if os.path.exists(path):
                    img = Image.open(path).convert("RGBA")
                    img = img.resize(target_size, Image.NEAREST)
                    frames.append(img)

            if frames:
                strip = Image.new(
                    "RGBA",
                    (target_size[0] * len(frames), target_size[1]),
                    (0, 0, 0, 0),
                )
                for i, frame in enumerate(frames):
                    strip.paste(frame, (i * target_size[0], 0), frame)

                strip_filename = f"{character_name}_{anim_name}_{direction}.png"
                strip_path = os.path.join(output_dir, character_name, strip_filename)
                strip.save(strip_path, "PNG")
                strips.append({
                    "animation": anim_name,
                    "direction": direction,
                    "file": strip_filename,
                    "frames": frame_count,
                })
                print(f"  Strip: {strip_filename} ({len(frames)} frames)")

    return strips


def write_manifest(character_name, output_dir, strips, animations=None):
    """Write {character}_manifest.json with frame dims, anim list, and strip metadata."""
    if animations is None:
        animations = STRIP_CONFIG

    manifest = {
        "character": character_name,
        "frame_width": 128,
        "frame_height": 128,
        "directions": [DIRECTIONS[i] for i in range(5)],
        "animations": {
            name: {"frames": cfg["frames"]}
            for name, cfg in animations.items()
        },
        "strips": strips,
    }

    manifest_path = os.path.join(output_dir, f"{character_name}_manifest.json")
    with open(manifest_path, "w") as f:
        json.dump(manifest, f, indent=2)
    print(f"Manifest: {manifest_path}")
    return manifest_path


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate game sprites via Together AI")
    parser.add_argument("--character", required=True, help="Character name")
    parser.add_argument("--prompt", required=True, help="Character description")
    parser.add_argument("--output", default="/home/vboxuser/Documents/ID0003_AgeOfAcadia/sprites", help="Output directory")
    parser.add_argument("--steps", type=int, default=4, help="Generation steps (default: 4)")
    parser.add_argument("--seed", type=int, default=None, help="Base seed for reproducibility")
    parser.add_argument("--spritesheet", action="store_true", help="Generate combined sprite sheet after generation")
    parser.add_argument("--strip-format", action="store_true", help="Generate per-animation strips + JSON manifest")
    parser.add_argument("--consistent", action="store_true", help="Use img2img consistency: generate base frame first, use as reference for all frames")
    parser.add_argument("--output-path", default=None, help="Subpath under output dir (e.g. 'infanteria')")

    args = parser.parse_args()

    if args.strip_format:
        animations = STRIP_CONFIG
    else:
        animations = SPRITE_SHEET_CONFIG

    # Resolve output directory with optional subpath
    output_dir = args.output
    if args.output_path:
        output_dir = os.path.join(args.output, args.output_path)
    os.makedirs(output_dir, exist_ok=True)

    print(f"Generating sprites for: {args.character}")
    print(f"Prompt: {args.prompt}")
    print(f"Output: {output_dir}")
    if args.consistent:
        print(f"Mode: CONSISTENT — base frame with FLUX.1.1-pro + img2img reference")

    reference_image = None
    gen_steps = args.steps

    if args.consistent:
        # Step 1: generate a high-quality base frame
        base_ref = generate_base_frame(
            character_name=args.character,
            prompt=args.prompt,
            output_dir=output_dir,
            steps=12,
            seed=args.seed or 42,
        )
        reference_image = base_ref
        gen_steps = 8  # more steps for consistent frames

    generated = generate_character_sheet(
        character_name=args.character,
        prompt=args.prompt,
        output_dir=output_dir,
        steps=gen_steps,
        seed=args.seed,
        animations=animations,
        reference_image=reference_image,
        consistent=args.consistent,
    )
    print(f"\nDone! Generated {len(generated)} sprites.")

    if args.spritesheet:
        create_sprite_sheet(args.character, output_dir)

    if args.strip_format:
        strips = create_strips(args.character, output_dir, animations)
        write_manifest(args.character, output_dir, strips, animations)
