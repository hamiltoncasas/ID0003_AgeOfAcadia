# Design: Sprite-to-Godot Pipeline

## Technical Approach

Modified A2 + B2: extend `generate_sprites.py` with `--strip-format` mode that produces per-animation×direction horizontal strips plus a JSON manifest. On the Godot side, bootstrap `game/` with pixel-art settings, a `UnitSprites.gd` resource script that reads the manifest and configures `AnimatedSprite2D`, and a `UnitController.gd` that picks the correct animation based on movement angle.

## Architecture Decisions

| Decision | Options | Tradeoffs | Choice |
|----------|---------|-----------|--------|
| **Strip assembly timing** | (a) During generation (b) Separate script (c) Both | (a) Single pass, simpler UX; (b) Decouples concerns, reusable; (c) Flexible but duplicated logic | **(a)** — integrated `--strip-format` flag in `generate_sprites.py`. Frame generation unchanged; strip mode adds post-processing. |
| **Frame count config** | (a) Update `SPRITE_SHEET_CONFIG` (b) New `STRIP_CONFIG` (c) CLI params | (a) Breaks old spritesheet; (b) Explicit, backward-safe; (c) Flexible but complex CLI | **(b)** — new `STRIP_CONFIG` with proposal values (idle:3, walk:4, attack:2, hurt:2, death:3). Old config kept for `--spritesheet` compat. |
| **Directions** | (a) 4 dirs (existing) (b) 5 dirs (proposal) (c) 8 dirs | (a) Existing compat; (b) Better isometric coverage; (c) Overkill, more API cost | **(b)** — 5 directions: front, front_angle, profile, back_angle, back. Update `DIRECTIONS` dict. |
| **Godot resource type** | (a) Custom Resource (b) Tool script (c) Autoload | (a) Self-contained, serializable; (b) Editor-integrated but heavier; (c) Global state, dirty | **(a)** — `UnitSprites.gd extends Resource`. Reads manifest JSON, builds SpriteFrames. |
| **Direction mapping** | (a) `atan2` bucket (b) 8-way snap (c) Vector dot | (a) Standard for movement direction; (b) Overkill; (c) Same result, more math | **(a)** — `atan2(velocity.y, velocity.x)` → 5 buckets. Left profile flips right profile texture. |

## Data Flow

```
generate_sprites.py
     │
     ├── (--spritesheet)  → combined grid PNG (backward compat)
     │
     └── (--strip-format)
          ├── strips/{char}_{anim}_{dir}.png   ← horizontal strips
          └── {char}_manifest.json             ← metadata

game/scripts/UnitSprites.gd  (Godot)
     │
     ├── reads {char}_manifest.json
     ├── loads strip PNGs via ResourceLoader
     └── builds SpriteFrames with 25 anim entries
          │
          └── AnimatedSprite2D.play("{anim}_{dir}")

game/scripts/UnitController.gd  (Godot)
     │
     ├── reads CharacterBody2D.velocity
     ├── atan2 → direction bucket
     └── calls play() with resolved animation name
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `scripts/generate_sprites.py` | Modify | Add `--strip-format` flag, `STRIP_CONFIG`, 5-direction support, strip assembly + JSON manifest writer |
| `game/project.godot` | Create | Godot 4 project with pixel-art import presets (nearest-neighbor, 320×180 viewport) |
| `game/scripts/UnitSprites.gd` | Create | Custom `Resource`: reads manifest JSON, loads strip textures via cache, builds `SpriteFrames` |
| `game/scripts/SpriteCache.gd` | Create | Singleton autoload: central texture cache, shared across all unit instances |
| `game/scripts/UnitController.gd` | Create | Basic `CharacterBody2D` with `atan2` direction mapping for PoC |
| `sprites/{character}/` | Modify | New strip PNGs and `{character}_manifest.json` output |

## Interfaces / Contracts

### Manifest Schema (`{character}_manifest.json`)

```json
{
  "character": "arquero",
  "frame_width": 128,
  "frame_height": 128,
  "directions": ["front", "front_angle", "profile", "back_angle", "back"],
  "animations": {
    "idle": { "frames": 3 },
    "walk": { "frames": 4 },
    "attack": { "frames": 2 },
    "hurt": { "frames": 2 },
    "death": { "frames": 3 }
  },
  "strips": [
    { "animation": "idle", "direction": "front", "file": "arquero_idle_front.png", "frames": 3 }
  ]
}
```

### Direction-Angle Mapping (GDScript)

```
-22.5°  to  22.5°    = profile (right)
 22.5°  to  67.5°    = front_angle (down-right)
 67.5°  to 112.5°    = front (down)
112.5°  to 157.5°    = front_angle (down-left)
157.5°  to 180/-180° = profile (left, flipped H)
-157.5° to -112.5°   = back_angle (up-left)
-112.5° to  -67.5°   = back (up)
 -67.5° to  -22.5°   = back_angle (up-right)
```

### UnitSprites.gd Interface

```gdscript
class_name UnitSprites extends Resource

var character: String
var animations: Dictionary  # anim → dir → animation_name
var frame_width: int
var frame_height: int

static func load_from_manifest(path: String) -> UnitSprites
func get_animation_name(anim: String, direction: String) -> String
```

### STRIP_CONFIG

```python
STRIP_CONFIG = {
    "idle":  {"frames": 3, "directions": 5},
    "walk":  {"frames": 4, "directions": 5},
    "attack":{"frames": 2, "directions": 5},
    "hurt":  {"frames": 2, "directions": 5},
    "death": {"frames": 3, "directions": 5},
}
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Visual | Strip assembly correctness | Manual: generate arquero strips, verify dimensions and frame alignment |
| Visual | Manifest JSON validity | Manual: inspect JSON fields, frame counts, strip list |
| Godot | `UnitSprites.gd` load | Manual: open Godot, confirm all 25 animations present |
| Godot | Direction switching | Manual: move character in test scene, confirm correct anim per angle |

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary changes.

## Migration / Rollout

No migration required. `--strip-format` is additive — existing `--spritesheet` and individual frame generation untouched. The `game/` directory is new with no prior consumers.

## Resolved Questions

| Question | Resolution |
|----------|-----------|
| Frame size for arquero | **128×128** — standard infantry size |
| Godot version pin | **Latest stable** at implementation time |
| Texture caching strategy | **Singleton global autoload** — central `SpriteCache` autoload manages all textures; `UnitSprites.gd` requests textures from cache |
