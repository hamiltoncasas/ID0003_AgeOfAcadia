#!/usr/bin/env python3
"""
Test harness for the strip-format pipeline.
Creates mock frames, runs strip assembly + manifest writing,
then verifies dimensions, frame counts, and manifest structure.

This validates tasks 1.1-1.4 and 4.2 without requiring
Together AI API credits.
"""

import os
import sys
import json
import tempfile
import shutil

# Import generate_sprites with a mock Together client to avoid API key requirement
import importlib
import types

# Create a mock Together module
mock_together = types.ModuleType("together")
mock_client = types.SimpleNamespace()
mock_response = types.SimpleNamespace()

class MockTogether:
    def __init__(self, *args, **kwargs):
        pass

mock_together.Together = MockTogether
sys.modules["together"] = mock_together

# Now safe to import generate_sprites — Together() is mocked
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image
from generate_sprites import (
    STRIP_CONFIG,
    DIRECTIONS,
    create_strips,
    write_manifest,
)

CHARACTER = "test_char"
TARGET_SIZE = (128, 128)
FRAME_SIZE = (512, 512)  # Generated frame size (before strip resize)


def create_mock_frames(output_dir, animations):
    """Create minimal RGBA PNG frames simulating AI output."""
    total = 0
    for anim_name, config in animations.items():
        dir_count = config["directions"]
        frame_count = config["frames"]
        for d in range(dir_count):
            direction = DIRECTIONS[d]
            for f in range(frame_count):
                frame_dir = os.path.join(output_dir, CHARACTER, anim_name, direction)
                os.makedirs(frame_dir, exist_ok=True)
                img = Image.new("RGBA", FRAME_SIZE, (64, 128, 200, 255))
                filename = f"{CHARACTER}_{anim_name}_{direction}_frame{f:02d}.png"
                img.save(os.path.join(frame_dir, filename), "PNG")
                total += 1
    return total


def verify_strips(output_dir, strips, animations):
    """Verify strip files exist, have correct dimensions, and frame counts."""
    errors = []
    total_frames = 0

    # Check all expected strips were created
    expected_count = sum(c["directions"] * 1 for c in animations.values())
    if len(strips) != expected_count:
        errors.append(
            f"Expected {expected_count} strips, got {len(strips)}"
        )

    for strip in strips:
        strip_path = os.path.join(output_dir, CHARACTER, strip["file"])

        # Strip file exists
        if not os.path.exists(strip_path):
            errors.append(f"Missing strip: {strip['file']}")
            continue

        # Dimension check: width = frames * 128, height = 128
        img = Image.open(strip_path)
        expected_width = strip["frames"] * TARGET_SIZE[0]
        if img.size != (expected_width, TARGET_SIZE[1]):
            errors.append(
                f"{strip['file']}: expected ({expected_width},{TARGET_SIZE[1]}), "
                f"got {img.size}"
            )

        total_frames += strip["frames"]

    # Verify frame count per animation
    anim_map = {}
    for strip in strips:
        anim_map.setdefault(strip["animation"], 0)
        anim_map[strip["animation"]] += strip["frames"]

    for anim_name, config in animations.items():
        expected = config["frames"] * config["directions"]
        actual = anim_map.get(anim_name, 0)
        if actual != expected:
            errors.append(
                f"{anim_name}: expected {expected} frames, got {actual}"
            )

    return errors, total_frames


def verify_manifest(manifest_path, strips, animations):
    """Verify manifest JSON structure and content."""
    errors = []

    if not os.path.exists(manifest_path):
        return ["Manifest file not found"], 0

    with open(manifest_path) as f:
        data = json.load(f)

    # Check top-level fields
    for field in ("character", "frame_width", "frame_height", "directions", "animations", "strips"):
        if field not in data:
            errors.append(f"Manifest missing field: {field}")

    if data.get("character") != CHARACTER:
        errors.append(f"Character mismatch: {data.get('character')} != {CHARACTER}")

    if data.get("frame_width") != TARGET_SIZE[0]:
        errors.append(f"frame_width mismatch: {data.get('frame_width')} != {TARGET_SIZE[0]}")

    if data.get("frame_height") != TARGET_SIZE[1]:
        errors.append(f"frame_height mismatch: {data.get('frame_height')} != {TARGET_SIZE[1]}")

    # Check directions list
    expected_dirs = [DIRECTIONS[i] for i in range(5)]
    if data.get("directions") != expected_dirs:
        errors.append(f"Directions mismatch: {data.get('directions')} != {expected_dirs}")

    # Check animations
    for anim_name, config in animations.items():
        if anim_name not in data.get("animations", {}):
            errors.append(f"Missing animation in manifest: {anim_name}")
        elif data["animations"][anim_name]["frames"] != config["frames"]:
            errors.append(
                f"{anim_name} frame count: {data['animations'][anim_name]['frames']} "
                f"!= {config['frames']}"
            )

    # Check strips match
    if len(data.get("strips", [])) != len(strips):
        errors.append(
            f"Strips count: {len(data.get('strips', []))} != {len(strips)}"
        )

    return errors, 0


def main():
    print("=" * 60)
    print("Strip Pipeline Test Harness")
    print("=" * 60)

    # Use temp directory to avoid polluting real sprites
    test_dir = tempfile.mkdtemp(prefix="strip_test_")
    try:
        # Step 1: Create mock frames
        print(f"\n[1/4] Creating mock frames...")
        total_frames = create_mock_frames(test_dir, STRIP_CONFIG)
        expected_total = sum(c["frames"] * c["directions"] for c in STRIP_CONFIG.values())
        print(f"  Created {total_frames}/{expected_total} frames")
        assert total_frames == expected_total, f"Frame count mismatch"

        # Step 2: Create strips
        print(f"\n[2/4] Assembling strips...")
        strips = create_strips(CHARACTER, test_dir, STRIP_CONFIG)
        print(f"  Created {len(strips)} strips")

        # Step 3: Write manifest
        print(f"\n[3/4] Writing manifest...")
        manifest_path = write_manifest(CHARACTER, test_dir, strips, STRIP_CONFIG)

        # Step 4: Verify everything
        print(f"\n[4/4] Verifying output...")
        strip_errors, frame_total = verify_strips(test_dir, strips, STRIP_CONFIG)
        manifest_errors, _ = verify_manifest(manifest_path, strips, STRIP_CONFIG)

        print(f"\n  Strips: {len(strips)} ({frame_total} total frames)")
        print(f"  Manifest: {'OK' if not manifest_errors else 'ERRORS'}")

        if strip_errors:
            print(f"\n  STRIP ERRORS:")
            for e in strip_errors:
                print(f"    - {e}")

        if manifest_errors:
            print(f"\n  MANIFEST ERRORS:")
            for e in manifest_errors:
                print(f"    - {e}")

        # Summary
        print(f"\n{'=' * 60}")
        if not strip_errors and not manifest_errors:
            print("  RESULT: ALL CHECKS PASSED")
            print(f"\n  Strip count: {len(strips)} (expected {sum(c['directions'] for c in STRIP_CONFIG.values())})")
            print(f"  Frame count: {frame_total} (expected {expected_total})")

            # Animation breakdown
            print(f"\n  Animation breakdown:")
            for s in strips:
                print(f"    {s['file']}: {s['frames']} frame(s)")

            # Files produced
            manifest_data = json.load(open(manifest_path))
            print(f"\n  Files produced:")
            for s in strips:
                s_path = os.path.join(test_dir, CHARACTER, s["file"])
                img = Image.open(s_path)
                print(f"    {s['file']}: {img.size[0]}x{img.size[1]}")
            print(f"    {os.path.basename(manifest_path)}: {len(manifest_data['strips'])} strips")
        else:
            print(f"  RESULT: CHECKS FAILED")
            sys.exit(1)

    finally:
        shutil.rmtree(test_dir)

    print(f"\n  Done (temp dir cleaned up)")


if __name__ == "__main__":
    main()
