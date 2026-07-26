## Exploration: Sprites → Spritesheet → Godot Pipeline

### Current State

The project has a mature sprite generation pipeline using ComfyUI (local) + Together AI (cloud) + FLUX.1 models, but the pipeline stops at PNG generation — there is **zero integration** with the Godot game engine yet.

**What exists today:**

- `scripts/generate_sprites.py` — main batch generator: generates 58 individual frames per character (4 animations × 4/1 directions) organized as `{character}/{animation}/{direction}/frame.png`. Optionally builds a combined spritesheet PNG via `--spritesheet` flag, but **outputs no JSON metadata** about frame positions or layout.
- 8 additional experimental scripts in `scripts/` — `build_sheet_clean.py`, `build_sheet_fast.py`, `generate_spritesheet_consistent.py`, `generate_spritesheet_together.py`, `generate_spritesheet_kie.py`, `generate_idle_strip.py`, `generate_final_sheet.py`, `remove_bg.py`. These explored different approaches: image-to-image with kontext-pro, consistent base-frame-first, Kie.ai API, etc.
- `scripts/remove_bg.py` — background removal via rembg (U²-Net), creates `_sin.png` variants with transparency.
- **218 `prompt.md` files** documenting each character/unit concept.
- **~91 character concepts** organized in `sprites/` by category (infanteria=20, caballeria=30, asedio=12, edificios=29, entorno=81+).
- **Only 1 spritesheet exists**: `aldeano_spritesheet.png` (640×512, 5×4 grid = 20 frames). Generated via kontext-pro, not the main script.
- **Canvas sizes vary**: infantry 128×128, cavalry 184×176, elephants 256×224, buildings up to 400×400.
- **No Godot project** exists yet — zero `.godot`, `.tscn`, `.gd`, or `project.godot` files.
- **Dependencies active**: `together==2.24.1`, `pillow==12.2.0`, `rembg` available.
- **openspec** initialized with SDD conventions but no changes or specs yet.

**Key gap**: The `create_sprite_sheet()` function in `generate_sprites.py` (line 106) assembles frames into a flat grid but:
1. Uses variable-width columns (max 8, not 5 directions)
2. The 58 frames don't evenly divide into a clean grid
3. No JSON/metadata sidecar is written
4. Frame ordering animation-by-animation (idle frames first, then walk, etc.) but this isn't documented for downstream consumption

### Affected Areas

- `scripts/generate_sprites.py` — main generator; needs metadata output and consistent grid layout
- `sprites/` directory — all character folders; will receive generated spritesheets
- `workflows/` — currently empty; could store ComfyUI workflow JSONs
- `openspec/specs/` — needs delta specs for the pipeline extension
- (new) Godot project files — `project.godot`, unit scenes, sprite resources
- `docs/MANUAL_SPRITES.md` — would need Godot integration docs

### Approaches

#### A. Spritesheet Generation Approaches

**A1. Enhanced spritesheet with JSON metadata sidecar — RECOMMENDED**
Modify `generate_sprites.py` to output a JSON sidecar alongside each spritesheet describing frame layout.

| Field | Value |
|-------|-------|
| `frame_width` | 128 (or per-unit) |
| `frame_height` | 128 (or per-unit) |
| `columns` | 5 (directions) |
| `rows` | 12 (ceil(58/5)) |
| `animations` | Array of `{name, start_row, frame_count, directions}` |
| `direction_order` | `["front", "front_angle", "profile", "back"]` |

The spritesheet layout would be:
- Each row = one animation
- Columns = direction frames (4 directions × N frames per direction)
- Metadata JSON tells Godot exactly where each frame lives

**Cons**: Need to change the script's layout from "all of animation A first" to "each row is one animation with all directions"
**Effort**: Medium (moderate Python + Pillow)

**A2. Per-animation spritesheets (multiple sheets per character)**
One spritesheet per animation type (idle.png, walk.png, attack.png, hurt.png), each with all directions in a row.

**Pros**: Smaller individual textures, easier to manage in Godot, natural mapping to AnimatedSprite2D animations
**Cons**: More files per character (4+ PNGs), harder to batch
**Effort**: Medium

**A3. Keep individual frames, skip combined spritesheet**
Use the current per-file frame structure directly in Godot by loading individual PNGs into SpriteFrames.

**Pros**: Zero changes to generation script, maximum flexibility
**Cons**: ~5,278 loose files for all characters, harder to manage in Godot's filesystem, no texture atlas benefits
**Effort**: Low (but high management overhead)

#### B. Godot Integration Approaches

**B1. AnimatedSprite2D + SpriteFrames.from_grid() — RECOMMENDED**
Godot 4's `SpriteFrames` has `add_frame()` and can work with `AtlasTexture`. Load spritesheet as one texture, create a `SpriteFrames` resource using the JSON metadata, and assign to `AnimatedSprite2D`.

**Pattern**:
```
Character ──► AnimatedSprite2D
                └── SpriteFrames (from .tres resource)
                      ├── "idle_front"     [frames 0..3]
                      ├── "idle_front_angle" [frames 4..7]
                      ├── "idle_profile"   [frames 8..11]
                      ├── "idle_back"      [frames 12..15]
                      ├── "walk_front"     [frames 16..21]
                      └── ...
```

Animation names follow `{state}_{direction}` convention. A `UnitController` script determines facing direction from movement vector and selects the correct animation.

**For RTS direction handling**:
- 4 directions: front, front_angle, profile, back
- Calculate facing from movement: `atan2(velocity.y, velocity.x)` → map to nearest direction
- Set `animated_sprite.animation = f"{state}_{direction}"`

**Pros**: Built-in Godot, no plugins, clean separation, works with AnimationTree
**Cons**: Manual configuration of SpriteFrames per unit (can be scripted)
**Effort**: Medium

**B2. Scripted Resource Importer (GD extension)**
Create a `UnitSprites.gd` custom resource that reads the JSON sidecar and auto-configures everything.

```gdscript
# UnitSprites.gd (custom resource)
extends Resource
class_name UnitSprites

@export var spritesheet: Texture2D
@export var metadata: Dictionary

func configure_animated_sprite(anim_sprite: AnimatedSprite2D) -> void:
    var sf = SpriteFrames.new()
    for anim in metadata.animations:
        for dir in anim.directions:
            var anim_name = anim.name + "_" + dir.name
            sf.add_animation(anim_name)
            for frame_idx in range(dir.frame_count):
                var region = AtlasTexture.new()
                region.atlas = spritesheet
                region.region = Rect2(
                    dir.col * frame_width,
                    anim.row * frame_height,
                    frame_width, frame_height
                )
                sf.add_frame(anim_name, region)
    anim_sprite.sprite_frames = sf
```

**Pros**: Fully automated, one `.tres` file per unit, scriptable setup
**Cons**: Requires GDScript tooling, more complex
**Effort**: High

**B3. Pre-split spritesheets with external Python script**
External script that takes spritesheet + JSON metadata and outputs individual frame PNGs. Godot imports each as a separate texture.

**Pros**: Simplest Godot-side (just load PNGs), works with Godot's default import pipeline
**Cons**: 5,278 individual files, Godot scene tree becomes cluttered, no texture atlas benefits
**Effort**: Medium (split script) + Low (Godot side)

**B4. AnimationTree + StateMachine for RTS unit states**
An `AnimationTree` with `AnimationNodeStateMachine` managing state transitions: idle → walk → attack → hurt → idle.

Each state contains sub-animations for directions. The state machine handles blending between states.

**Pros**: Professional RTS animation control, smooth transitions, scalable
**Cons**: Over-engineered for simple pixel art with few frames; better for 3D or skeletal animation
**Effort**: High

### Recommendation

**Combine A1 (enhanced spritesheet + JSON metadata) + B2 (scripted resource importer).**

Rationale:
1. **A1 is the minimal change to the existing pipeline**: modify `create_sprite_sheet()` to use a fixed 5-column (direction) grid, layout animations as rows, and write a `{character}_spritesheet.json` sidecar. The existing per-frame generation stays unchanged — only the assembly step changes.
2. **B2 eliminates repetition for 91 units**: writing SpriteFrames by hand for 91 units × 58 frames is impractical. A `UnitSprites.gd` resource that reads JSON metadata and auto-configures AnimatedSprite2D is the only scalable approach.
3. **Together they form a clean pipeline**: generate → assemble + metadata → Godot reads metadata → auto-configures animations.

**Concrete proposal for the modified spritesheet layout**:

Simplify `SPRITE_SHEET_CONFIG` to produce a clean grid:
- Each animation becomes one row (or two for walk's 6 frames)
- Each row has 4 columns for the 4 direction variants
- If a direction has multiple frames (e.g., walk's 6), use multiple cells within that direction's block
- Pad unused cells with empty space

**Or even simpler**: use `SpriteFrames.add_frame()` in Godot per individual frame loaded from the per-file structure (Approach B3), skipping the combined spritesheet entirely. This avoids the grid layout problem and each frame is independently usable. The tradeoff is ~5,278 files, but Godot's filesystem handles this fine with proper organization.

Actually, the **best middle-ground**: generate per-animation-direction strips. Each strip is one direction of one animation (e.g., "walk_front.png" with 6 frames in a row). This gives:
- 16 strips per character (4 animations × 4 directions)
- Clean 1-row strips → easy to use in Godot
- Each strip maps directly to one `SpriteFrames` animation
- ~1,456 files total for all characters (vs 5,278 individual frames)

### Risks

- **Cost overrun**: Generating full spritesheets for all 91 units at $0.04/frame (Pro) = 91 × 58 × $0.04 = ~$211. Using Schnell ($0.0027) = ~$14. The user should batch with Schnell for iteration, Pro only for final quality.
- **Consistency across frames**: FLUX.1-schnell at 4 steps produces variable results per frame. The aldeano experiment showed this (kontext-pro + image-to-image gave better consistency). Even with fixed seeds, character appearance drifts between frames. The `generate_spritesheet_consistent.py` approach (base frame → reference for all others) mitigates this.
- **Different canvas sizes**: Not all units use 128×128. Cavalry (184×176), elephants (256×224), buildings (up to 400×400) need different spritesheet dimensions. The metadata JSON MUST include per-unit frame dimensions.
- **No Godot project exists**: Starting from zero means establishing Godot project conventions, resolution settings, and import defaults alongside the sprite pipeline. This is scope creep but necessary.
- **Animation direction mapping**: The script uses 4 directions (front, front_angle, profile, back). The aldeano spritesheet used 5 (right, down-right, down, down-left, left). Inconsistency in direction conventions between scripts needs resolution.
- **Grid layout complexity**: 58 frames don't divide evenly into a 5-column grid. 58 / 5 = 11.6 rows. The last row would be partially filled. Cleaner to reorganize to a multiple of 5 or use per-animation strips.
- **rembg quality**: The `_sin.png` backgrounds may have artifacts (halos, cut-off details) that affect Godot rendering, especially on transparent tiles.

### Ready for Proposal

**Yes** — the exploration is complete and the key decisions are clear. The orchestrator should tell the user:

1. The existing generation pipeline is solid but needs a JSON metadata output layer to be Godot-consumable
2. The recommended approach is: modify `generate_sprites.py` to output per-character spritesheets + JSON metadata → create a `UnitSprites.gd` custom resource that reads the JSON and auto-configures AnimatedSprite2D
3. The main open question is **spritesheet layout strategy**: (a) single combined sheet per character, (b) per-animation strips, or (c) individual frames — this affects both the generation script and Godot integration
4. A proposal/SDD change should be created for "sprite-to-godot-pipeline" covering: script modifications, JSON schema, Godot resource script, and initial project setup
