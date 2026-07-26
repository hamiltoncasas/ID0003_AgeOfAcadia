#!/usr/bin/env python3
"""
Generate a sprite sheet using Kie.ai API.

Usage:
    export KIE_API_KEY="sk-..."

    # Image-to-image (with reference sprite):
    python scripts/generate_spritesheet_kie.py \
      --input sprites/infanteria/aldeano/aldeano_128_sin.png \
      --prompt "Age of Empires 2 isometric pixel art, male villager in blue tunic" \
      --output sprites/infanteria/aldeano/aldeano_spritesheet.png \
      --rows 4 --cols 5

    # Text-to-image (no reference):
    python scripts/generate_spritesheet_kie.py \
      --prompt "Age of Empires 2 isometric pixel art, male villager" \
      --output sprites/infanteria/aldeano/aldeano_spritesheet.png \
      --rows 4 --cols 5
"""

import os
import sys
import json
import time
import argparse
import base64
from pathlib import Path
from io import BytesIO

import requests
from PIL import Image


# API endpoints
UPLOAD_BASE = "https://kieai.redpandaai.co"
API_BASE = "https://api.kie.ai"
CREATE_URL = f"{API_BASE}/api/v1/jobs/createTask"
POLL_URL = f"{API_BASE}/api/v1/jobs/recordInfo"

ASPECT_RATIO = "1:1"
RESOLUTION = "1K"

DIRECTIONS = ["right", "down-right", "down", "down-left", "left"]
FRAME_TYPES = ["idle", "walking", "attacking", "dying"]


def upload_image(api_key: str, image_path: Path) -> str | None:
    """Upload image to Kie.ai file server and return public URL."""
    headers = {"Authorization": f"Bearer {api_key}"}
    url = f"{UPLOAD_BASE}/api/file-stream-upload"

    try:
        with open(image_path, "rb") as f:
            files = {
                "file": (image_path.name, f, "image/png"),
                "uploadPath": (None, "sprites"),
            }
            resp = requests.post(url, headers=headers, files=files, timeout=60)
    except Exception as e:
        print(f"  ✗ Upload error: {e}")
        return None

    if resp.status_code != 200:
        print(f"  ✗ Upload failed (HTTP {resp.status_code})")
        return None

    data = resp.json()
    if data.get("code") != 200:
        print(f"  ✗ Upload API error: {data.get('msg', 'unknown')}")
        return None

    file_url = data.get("data", {}).get("downloadUrl") or data.get("data", {}).get("fileUrl")
    if file_url:
        print(f"  ✓ Uploaded → {file_url}")
    return file_url


def generate_variant(api_key: str, model: str, prompt: str,
                     seed: int, ref_url: str | None = None) -> Image.Image | None:
    """Generate one image variant via Kie.ai API."""
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }

    payload = {
        "model": model,
        "input": {
            "prompt": prompt,
            "aspect_ratio": ASPECT_RATIO,
            "resolution": RESOLUTION,
        }
    }

    if ref_url and "image-to-image" in model:
        payload["input"]["input_urls"] = [ref_url]

    try:
        resp = requests.post(CREATE_URL, headers=headers, json=payload, timeout=30)
    except requests.RequestException as e:
        print(f"✗ Network: {e}")
        return None

    if resp.status_code != 200:
        print(f"✗ HTTP {resp.status_code}")
        return None

    body = resp.json()
    if body.get("code") != 200:
        print(f"✗ API: {body.get('msg', '?')}")
        return None

    task_id = body.get("data", {}).get("taskId")
    if not task_id:
        print(f"✗ No taskId")
        return None

    for attempt in range(60):
        time.sleep(2)
        try:
            poll = requests.get(POLL_URL, headers=headers,
                                params={"taskId": task_id}, timeout=15)
        except requests.RequestException:
            continue

        if poll.status_code != 200:
            continue

        data = poll.json().get("data", {})
        state = data.get("state")

        if state == "success":
            result_raw = data.get("resultJson", "{}")
            try:
                result = json.loads(result_raw)
            except json.JSONDecodeError:
                print(f"✗ Bad JSON")
                return None

            img_urls = result.get("resultUrls", [])
            if not img_urls:
                print(f"✗ No URLs")
                return None

            try:
                img_resp = requests.get(img_urls[0], timeout=30)
                if img_resp.status_code == 200:
                    return Image.open(BytesIO(img_resp.content))
            except Exception as e:
                print(f"✗ Download: {e}")
                return None

        elif state == "fail":
            err = data.get("failMsg", "unknown")
            print(f"✗ Failed: {err}")
            return None

        if attempt == 0:
            print(".", end="", flush=True)

    print(f"✗ Timeout")
    return None


def build_prompt(base: str, direction: str, frame_type: str) -> str:
    return (f"{base}, isometric pixel art game sprite, "
            f"facing {direction}, {frame_type} frame, "
            f"AoE2 style, 128x128 game character, transparent background")


def main():
    parser = argparse.ArgumentParser(description="Sprite sheet via Kie.ai")
    parser.add_argument("--input", type=Path,
                        help="Reference _sin.png (optional)")
    parser.add_argument("--output", required=True, type=Path,
                        help="Output sprite sheet PNG")
    parser.add_argument("--prompt", required=True, help="Base prompt")
    parser.add_argument("--rows", type=int, default=4)
    parser.add_argument("--cols", type=int, default=5)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    api_key = os.environ.get("KIE_API_KEY")
    if not api_key:
        print("ERROR: Set KIE_API_KEY")
        sys.exit(1)

    model = "gpt-image-2-image-to-image" if args.input else "gpt-image-2-text-to-image"

    # Upload reference if needed
    ref_url = None
    if args.input:
        if not args.input.exists():
            print(f"ERROR: {args.input} not found")
            sys.exit(1)
        print(f"Uploading reference image...")
        ref_url = upload_image(api_key, args.input)
        if not ref_url:
            print("ERROR: Upload failed, falling back to text-to-image")
            model = "gpt-image-2-text-to-image"

    total = args.rows * args.cols
    frame_size = None
    frames = []

    print(f"\nGenerating {total} frames...")
    print(f"  Model: {model}")
    if ref_url:
        print(f"  Reference: {args.input.name}")
    print()

    for i in range(total):
        direction = DIRECTIONS[i % len(DIRECTIONS)]
        frame_type = FRAME_TYPES[(i // len(DIRECTIONS)) % len(FRAME_TYPES)]
        prompt = build_prompt(args.prompt, direction, frame_type)
        seed = args.seed + i

        print(f"  [{i+1}/{total}] {direction} {frame_type} ...", end=" ", flush=True)

        img = generate_variant(api_key, model, prompt, seed, ref_url)
        if img is None:
            print("  SKIPPED")
            continue

        if frame_size is None:
            frame_size = img.size
        else:
            img = img.resize(frame_size, Image.LANCZOS)

        if img.mode != "RGBA":
            img = img.convert("RGBA")

        frames.append(img)
        print("✓")

    if not frames:
        print("\nERROR: No frames generated.")
        sys.exit(1)

    actual = len(frames)
    cols = min(args.cols, actual)
    rows = (actual + cols - 1) // cols
    fw, fh = frame_size

    sheet = Image.new("RGBA", (cols * fw, rows * fh), (0, 0, 0, 0))
    for idx, frame in enumerate(frames):
        x = (idx % cols) * fw
        y = (idx // cols) * fh
        sheet.paste(frame, (x, y), frame if frame.mode == "RGBA" else None)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.output, "PNG")
    print(f"\n✓ Saved: {args.output}")
    print(f"  {actual} frames · {cols}×{rows} · {fw}×{fh}")


if __name__ == "__main__":
    main()
