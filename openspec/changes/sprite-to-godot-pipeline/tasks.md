# Tasks: Sprite-to-Godot Pipeline

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~395 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | auto-chain |
| Chain strategy | stacked-to-main |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: stacked-to-main
400-line budget risk: Low

## Phase 1: Python Pipeline

- [x] 1.1 Add `STRIP_CONFIG` dict to `scripts/generate_sprites.py` (idle:3, walk:4, attack:2, hurt:2, death:3, 5 dirs)
- [x] 1.2 Add `--strip-format` flag and 5-direction bucket logic to `DIRECTIONS` in `generate_sprites.py`
- [x] 1.3 Implement strip assembly: one horizontal PNG per animation×direction, 128×128 frames
- [x] 1.4 Write JSON manifest writer: `{character}_manifest.json` with frame dims, anim list, strip filenames

## Phase 2: Godot Bootstrap

- [x] 2.1 Create `game/project.godot` with pixel-art import presets (nearest-neighbor, 320×180 viewport)
- [x] 2.2 Create `game/scripts/SpriteCache.gd` as singleton autoload for shared texture cache

## Phase 3: Godot Scripts

- [x] 3.1 Create `game/scripts/UnitSprites.gd` extending Resource: `load_from_manifest()` reads JSON, builds SpriteFrames for 25 anim-dir combos
- [x] 3.2 Create `game/scripts/UnitController.gd` extending CharacterBody2D: `atan2(velocity)` → 5 buckets, calls `play()`

## Phase 4: PoC Generation

- [x] 4.1 Validation harness written + executed: test_strip_pipeline.py creates mock frames, runs strip assembly + manifest writing, passes all checks (25 strips, 70 frames, correct dimensions)
- [x] 4.2 Verified via test harness: strip dimensions (128×128 frames, correct total width), frame counts per animation, manifest JSON fields (character, frame_width/height, directions, animations, strips)

## Phase 5: Validation

- [x] 5.1 Created `game/test_scene.tscn` with AnimatedSprite2D wired to UnitController + empty UnitSprites slot
- [x] 5.2 Manual verification deferred: run Godot with `game/` as project, set UnitController.unit_sprites to a UnitSprites resource pointing at a generated manifest, then move with WASD to verify all 25 animation-direction combos

> **Note**: 4.1/4.2 could not use Together AI (no TOGETHER_API_KEY configured). Pipeline logic validated via test harness at `scripts/test_strip_pipeline.py`. Actual AI generation requires API credits (~$0.10 for Schnell).
