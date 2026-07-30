# Proposal: Terrain Playable

## Intent

300×300 procedural terrain exists but empty — no environment objects, no player character, no interactive camera. Three complete systems (ObjectPlacer, UnitController, CameraController) are built but disconnected. This change wires them into a playable map.

## Scope

### In Scope
- ObjectPlacer integration into Llanura1.gd (trees, rocks, flowers, reeds per biome)
- Player character via UnitController (WASD move, click-to-shoot arrow)
- Arrow.tscn creation from existing Arrow.gd
- CameraController wired (zoom ~0.13, drag-scroll, character follow)
- CameraController map_size update: 120 → 300
- Input split: arrows = scroll map (when no follow), WASD = move character
- GameUI kept as-is (minimap + coordinates)

### Out of Scope
- Pathfinding / NavigationAgent2D
- Enemy AI or combat units
- Resource collection (trees/mines as interactables)
- Minimap player position dot
- Map save/load or seed input
- Multiplayer / network sync

## Capabilities

### New Capabilities
- `player-character`: Player entity with WASD movement, attack (click → ballistic arrow), team color shader, camera follow trigger

### Modified Capabilities
- `procedural-map`: Extend from 120×120 to 300×300; add ObjectPlacer + CameraController + UnitController wiring; remove stand-alone Camera2D
- `godot-project`: Input map — split arrow-keys (CameraController scroll) from WASD (player movement); add test_attack/hurt/die/zoom input actions

## Approach

Wire three existing systems into Llanura1.gd after terrain generation:
1. **ObjectPlacer**: `place_objects(biome_map, elev_map, rng, container)` — trees on grass, rocks on dirt, cacti/palms on sand, reeds at water edge
2. **UnitController**: Instance as player child, set UnitSprites from `arquero_manifest.json`, add to camera follow target
3. **CameraController**: Replace basic Camera2D in terrain_only.tscn; set `map_size = Vector2i(300, 300)`, `zoom = 0.13`
4. **Arrow.tscn**: Create scene root from Arrow.gd (exists as script)
5. **Input split**: CameraController reads arrow keys only when `follow_target = null`; WASD always reads as player movement

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `map/Llanura1.gd` | Modified | Add ObjectPlacer + UnitController calls |
| `terrain_only.tscn` | Modified | Camera2D → CameraController |
| `map/CameraController.gd` | Modified | map_size 300×300, arrow-key-only scroll |
| `scenes/Arrow.tscn` | New | Scene from existing Arrow.gd |
| `project.godot` | Modified | Input map actions |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Performance at 300×300 + objects | Med | Density tuning, visibility culling if needed |
| Arrow/WASD input overlap | Low | CameraController reads arrows only when no follow target |
| Arrow.gd expects different scene structure | Low | Verify before creating Arrow.tscn |

## Rollback Plan

`git checkout` Llanura1.gd, CameraController.gd, terrain_only.tscn, project.godot. Delete `scenes/Arrow.tscn` and `openspec/changes/terrain-playable/`.

## Dependencies

- ObjectPlacer → SpriteCache.get_entorno_textures() (already loaded at init)
- UnitController → `arquero_manifest.json` in `sprites/infanteria/arquero/`
- UnitController → Arrow.gd (scene creation from existing script)

## Success Criteria

- [ ] Map generates with environment objects per biome rules (trees, rocks, flowers, reeds)
- [ ] WASD moves character with 5-direction animation (idle/walk)
- [ ] Click shoots ballistic arrow toward mouse position
- [ ] Camera follows player; middle-drag scrolls; zoom ~0.13 works
- [ ] Arrow keys scroll map when camera has no follow target
- [ ] GameUI minimap + coordinate label functional without changes
