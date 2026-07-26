# Proposal: Sprite-to-Godot Pipeline

## Intent

Bridge the gap between the existing sprite generation pipeline and the Godot game engine. Today the pipeline stops at raw PNGs — no metadata, no Godot-readable format, no game integration. This change adds a structured output layer (per-animation strips + JSON) and a Godot resource importer so generated sprites are immediately usable in-game.

## Scope

### In Scope
1. **Python script enhancement** — `generate_sprites.py` outputs per-animation×direction strips (instead of one combined spritesheet) with a JSON sidecar describing the structure.
2. **JSON metadata schema** — per-character manifest: frame count per strip, animation→direction→frames mapping.
3. **Godot resource script** (`UnitSprites.gd`) — custom `Resource` that reads the JSON manifest and auto-configures `SpriteFrames` on `AnimatedSprite2D`.
4. **Godot project bootstrap** — `game/project.godot` with pixel-art import presets.
5. **PoC character (Arquero)** — generate full set (5 dirs × idle:3/walk:4/attack:2/hurt:2/death:3 = 70 frames), validate end-to-end.

### Out of Scope
- Full 91-unit generation (separate change)
- AnimationTree state machines (MVP uses simple AnimatedSprite2D)
- UI, map, fog of war, network multiplayer
- AI behavior trees, sound effects, or music

## Capabilities

### New Capabilities
- `sprite-generation`: Structured spritesheet generation with per-animation strips and JSON metadata sidecar; configurable frame counts per animation.
- `sprite-import`: Godot-side custom resource (`UnitSprites.gd`) that reads JSON manifests and auto-configures per-direction animations on AnimatedSprite2D.
- `godot-project`: Godot 4 project bootstrap with pixel-art import settings at `game/`.

### Modified Capabilities
None — no existing specs to change.

## Approach

**Modified A2 + B2** (per-animation strips + scripted resource importer):

1. Modify `create_sprite_sheet()` to generate one horizontal strip per animation×direction — e.g., `arquero_idle_front.png` (3 frames), `arquero_walk_profile.png` (4 frames). Strips use a fixed frame width/height per character.
2. Write `{character}_manifest.json` mapping each animation→direction→strip filename, frame dimensions, and frame count.
3. Create `game/` Godot project root with `project.godot` and import defaults (nearest-neighbor, no filter).
4. Implement `UnitSprites.gd` that loads the manifest JSON, locates strip textures, and builds `SpriteFrames` with per-direction animation names (`idle_front`, `walk_back`, etc.).
5. Validate with Arquero: generate → import → playable AnimatedSprite2D in a test scene.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `scripts/generate_sprites.py` | Modified | Strip output + JSON metadata sidecar |
| `scripts/` (new script) | New | Optional: strip combiner for final atlas |
| `game/` | New | Godot 4 project root |
| `game/scripts/UnitSprites.gd` | New | Custom resource importer |
| `sprites/` | Modified | Per-character strip files + manifest JSON |
| `openspec/specs/sprite-generation/` | New | Spec for generation pipeline |
| `openspec/specs/sprite-import/` | New | Spec for Godot-side import |
| `openspec/specs/godot-project/` | New | Spec for project bootstrap |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Frame-to-frame visual drift (Schnell) | High | Consistent base-frame approach; upgrade to Pro for final |
| rembg artifacts on transparent strips | Medium | Manual QA pass on PoC; add trim/margin to strip generator |
| No existing Godot conventions | Medium | Establish pixel-art presets upfront in bootstrap |
| Cost overrun (full 91-unit run) | Low | Schnell for iteration; explicit Pro-only gate |

## Rollback Plan

- Python change: revert `generate_sprites.py` to last commit; old per-frame output is untouched.
- Godot project: delete `game/` directory — no other code depends on it yet.
- JSON manifest: no consumers exist outside this change; remove if rollback needed.

## Dependencies

- Godot 4.x (not yet installed — must be available for import validation)
- Existing `generate_sprites.py`, Pillow, Together AI API
- PoC generation: ~$0.10 in Schnell API credits

## Success Criteria

- [ ] Arquero sprites generated as per-animation strips (70 frames, 25 strip files) with valid `arquero_manifest.json`
- [ ] `game/` bootstrapped Godot 4 project opens without import errors
- [ ] `UnitSprites.gd` loads manifest, configures AnimatedSprite2D with all 25 animation-direction combos
- [ ] Test scene shows Arquero with direction-aware animations switching on movement
