# Tasks: Llanura1 — Procedural Isometric Map

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 450–590 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR1 (foundation) → PR2 (generation) → PR3 (objects) → PR4 (integration) |
| Delivery strategy | auto-chain |
| Chain strategy | stacked-to-main |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Focused test | Runtime harness | Rollback |
|------|------|-------------|----------------|----------|
| 1 (PR1) | SpriteCache env textures + TileSet resource + `game/map/` dir | Load scene with empty TileMapLayer | Open scene in editor, verify no errors | Delete `game/map/`, revert SpriteCache |
| 2 (PR2) | ProceduralGeneration.gd + basic flat terrain | `generate()` returns correct `biome_map` shape | Run from test scene, inspect console output | Revert ProceduralGeneration.gd |
| 3 (PR3) | ObjectPlacer, cliff detection, y-sort | Place objects on map, verify count ≥ 127 | Load generated map, scroll around | Revert ObjectPlacer.gd, cliff files |
| 4 (PR4) | CameraController, MapManager, main scene swap | Drag scroll within map bounds, unit moves on map | Load Llanura1.tscn as main, play | Revert project.godot, remove CameraController |

## Phase 1: Foundation

- [x] 1.1 Create `game/map/` directory structure
- [x] 1.2 Modify `game/scripts/SpriteCache.gd` — add `load_env_textures()` loading all `game/sprites/entorno/` sprites by biome category; implement `get_entorno_textures()` Dictionary
- [x] 1.3 Create `game/map/terrain.tres` TileSet resource with `tile_size = Vector2i(128, 64)`, diamond layout, and atlas sources for grass, water, sand, dirt, cliff tiles
- [x] 1.4 Create empty `game/map/Llanura1.tscn` with Node2D root and a single TileMapLayer

## Phase 2: Core Generation

- [x] 2.1 Create `game/map/ProceduralGeneration.gd` — FastNoiseLite with seed param, generates 120×120 heightmap; `extends RefCounted`, returns Dictionary with biome_map, elev_map, success, error
- [x] 2.2 Implement biome thresholds from -1..1 heightmap: < -0.3 WATER (0), -0.3–0.1 SAND (1), 0.1–0.5 GRASS (2), 0.5–0.75 DIRT (3), > 0.75 MOUNTAIN (4); elevation = floor((height+1)×1.5) → 0, 1, 2; stored to biome_map[y][x], elev_map[y][x]
- [x] 2.3 Implement TileMapLayer population per elevation (0/1/2), each offset -elevation × 32 on y; uses terrain.tres atlas sources (0=grass, 1=water, 2=sand, 3=dirt, 6=deep_water); mountain uses cliff_rock (source 5)
- [x] 2.4 Implement cliff sprite placement at cells where any 4-direction neighbor has lower elevation; uses `acantilados.png`/`acantilados_roca.png` textures via Sprite2D instances; positioned at cell world coords + elevation offset
- [x] 2.5 Return Dictionary with: biome_map, elev_map, layers (TileMapLayer[]), cliff_node, tile_count, success, error

## Phase 3: Objects & Elevation

- [x] 3.1 Create `game/map/ObjectPlacer.gd` — `place_objects(biome_map, elev_map, rng, container)` with per-biome density rules (grass: dense trees, dirt: sparse rocks, sand: cacti/palms, water: lilies)
- [x] 3.2 Implement cell eligibility check — skip water cells, skip cells with cliff sprites, apply jittered position within cell
- [x] 3.3 Implement no-duplicate guard — track placed cell positions in a Dictionary, reject collisions
- [x] 3.4 Handle empty entorno directory — warn and return gracefully, generation continues
- [x] 3.5 Wire ObjectContainer (Node2D, `y_sort_enabled = true`) as child of the map tree

## Phase 4: Camera & Integration

- [x] 4.1 Create `game/map/CameraController.gd` — Camera2D with drag-scroll (middle-mouse), zoom (0.3–3.0), map bounds clamping
- [x] 4.2 Implement unit-follow mode: when unit exits center 50% viewport, camera lerps to keep unit visible
- [x] 4.3 Create `game/map/MapManager.gd` — `_ready()` orchestrates generation (ProceduralGeneration → ObjectPlacer → UnitController child), exposes `get_biome()`, `get_elevation()`, `world_to_cell()`, `cell_to_world()`
- [x] 4.4 Wire `Llanura1.tscn` — MapManager root + CameraController + placeholders for unit
- [x] 4.5 Modify `project.godot` — set `run/main_scene="res://map/Llanura1.tscn"`
- [x] 4.6 Verify: load Llanura1.tscn, confirm no errors, all biomes present, 127+ objects, y-sort correct, camera drag/zoom works
