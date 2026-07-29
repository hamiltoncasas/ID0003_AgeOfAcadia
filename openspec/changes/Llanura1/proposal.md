# Proposal: Llanura1 — Procedural Isometric Map

## Intent

Add a playable 120×120 isometric map with multi-height terrain, procedural generation, and environment objects. The project currently has no map system — only unit animation prototypes on a debug grid. Unblocks gameplay.

## Scope

### In Scope
- Procedural terrain generation: grass, water, sand, dirt paths, mountains, cliffs
- Multi-height elevation with cliff transitions (AoE2-style)
- 120×120 tile grid, isometric diamond layout (128×64 world tile)
- Environment object placement from `game/sprites/entorno/` (all 127+ items)
- Y-sorted depth rendering for isometric layering
- MapManager node as procedural generation entry point

### Out of Scope
- Unit pathfinding / navigation — separate change
- Minimap or camera controls — separate change
- Resource nodes (mines, trees as collectables) — future
- Object animation, destruction, or interaction — future
- Saved/loaded maps — all procedural per session
- Day/night cycle or weather

## Capabilities

### New Capabilities
- `procedural-map`: Terrain generation and object placement for a fully playable isometric map

### Modified Capabilities
- `godot-project`: Viewport size increases from 320×180 to 640×360; y-sort enabled globally; new `MapManager.tscn` entry scene replaces `test_scene.tscn`

## Approach

1. **MapManager** (Node2D, entry scene `game/map/Llanura1.tscn`): owns the map tree with TileMapLayer nodes per elevation level and an ObjectContainer for sprites.
2. **ProceduralGeneration.gd**: FastNoiseLite heightmap → biome assignment → tile placement → cliff detection → object placement (trees on grass, rocks on dirt, water lilies on water, etc.).
3. **TileMapLayer per elevation**: base terrain tiles (grass, dirt, sand, water). Cliff sprites placed at elevation edges as separate TileMapLayer or Sprite2D nodes.
4. **ObjectContainer** (Node2D with y-sort enabled): Sprite2D instances loaded via `SpriteCache`, positioned using biome-specific placement rules.
5. **UnitController** added as child of MapManager so unit navigates the generated world.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `game/map/` | New | MapManager, Llanura1 scene, generation scripts |
| `game/scripts/` | New | `ProceduralGeneration.gd`, `TileManager.gd`, `ObjectPlacer.gd` |
| `project.godot` | Modified | Viewport 640×360, y-sort project setting |
| `test_scene.tscn` | Removed | Replaced by map entry scene |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Performance with 120×120 tiles + 1000+ objects | Med | Visibility culling; use TileMapLayer built-in culling |
| Tile alignment with mixed asset sizes (64×32 grass vs 128×64 water) | Med | Define world tile as 128×64; half-tiles as sub-tile offsets |
| Cliff transitions look wrong at elevation boundaries | Med | Reference AoE2 cliff patterns; visual iteration passes |

## Rollback Plan

Restore `project.godot` from git, delete `game/map/`, restore `test_scene.tscn`. Project reverts to pre-map state.

## Dependencies

- `SpriteCache` autoload must support loading environment sprites from `game/sprites/entorno/` (currently unit-strip-only)

## Success Criteria

- [ ] Map generates without errors on scene load
- [ ] All 5 terrain types appear with correct tiles
- [ ] Cliff sprites render at elevation transitions
- [ ] 127+ environment objects placed from `entorno/`
- [ ] Y-sort produces correct visual depth for overlapping sprites
- [ ] Unit can be placed on map and moved via keyboard
