# Design: Llanura1 — Procedural Isometric Map

## Technical Approach

Generate a 120×120 isometric map via FastNoiseLite heightmap → biome/cliff assignment → TileMapLayer per elevation → Sprite2D decoration pass. MapManager owns the tree; UnitController becomes a child. Each Sprite2D remains individually addressable for future animation/destruction.

## Architecture Decisions

### Decision: World Tile Size
| | Option | Tradeoff |
|---|---|---|
| **Choice** | 128×64 (standard isometric diamond) | Grass (64×32) needs compositing into 128×64 via two halves per cell |
| Rejected | 64×32 grid cell | Water/sand/dirt (128×64) would need 2×2 multi-tile grouping, complicates TileSet |
| Rejected | Single tile size per TileMapLayer | Forces multiple TileMapLayers per size class, overkill for MVP |

**Rationale**: 128×64 matches most terrain assets natively. Grass is the only odd size — handled at generation time by placing two 64×32 sprites per cell (left/right half) or extracting 128×64 regions from `pasto_gen.png` (256×256 = 2×2 tiles of 128×64). The TileSet uses `tile_size = Vector2i(128, 64)` in diamond layout.

### Decision: Elevation Model
| | Option | Tradeoff |
|---|---|---|
| **Choice** | TileMapLayer per height level | Clean separation, each layer gets its own y-offset for visual stacking |
| Rejected | Single TileMapLayer with z-offset | Godot TileMapLayer doesn't support per-cell z-offset natively |
| Rejected | Sprite2D for every tile | 14,400 sprite nodes kills performance |

**Rationale**: 3 elevation levels (0=base, 1=mid, 2=high). Each TileMapLayer offset upward by 32px × level. Cliffs rendered at edges where adjacent cells differ in height — uses `acantilados.png` (128×128) placed as a separate TileMapLayer or Sprite2D instances at transition boundaries.

### Decision: Object Placement
| | Option | Tradeoff |
|---|---|---|
| **Choice** | Sprite2D instances in y-sorted Node2D | Each object independently animatable, destroyable, queryable |
| Rejected | Bake into TileMap | Objects become static tiles — can't animate or destroy later |
| Rejected | GPUParticles2D for decorations | Overkill, no per-object control |

**Rationale**: Proposal explicitly requires future animation/destruction. ObjectContainer (Node2D, `y_sort_enabled = true`) holds 500–1500 Sprite2D children. Biome-specific placement rules: trees on grass, rocks on dirt, water lilies on water, etc.

### Decision: Procedural Generation
| | Option | Tradeoff |
|---|---|---|
| **Choice** | FastNoiseLite → heightmap → biome thresholds → tile map → decoration pass | Full control, deterministic per seed |
| Rejected | Pre-made hand-crafted map | 120×120 can't be hand-crafted at this stage |
| Rejected | Cellular automata | Unpredictable results, harder to tune |

**Rationale**: Single FastNoiseLite with seed parameter. Height threshold: <0.3 = water, 0.3–0.45 = sand, 0.45–0.7 = grass, 0.7–0.85 = dirt, >0.85 = mountain (cliff + rock cap). Object density varies per biome (grass: dense trees, dirt: sparse rocks, sand: cacti/palms, water: lilies).

### Decision: Camera
| | Option | Tradeoff |
|---|---|---|
| **Choice** | Independent Camera2D at MapManager level | Unit no longer owns camera; drag-scroll + pinch-zoom added |
| Rejected | Camera stays as UnitController child | Can't zoom out to see map without losing unit |
| Rejected | No camera controller | Map too large to play without scrolling |

**Rationale**: CameraController.gd as child of MapManager. Middle-mouse/edge-pan drag. Clamped to map bounds. Zoom preserved from UnitController (0.3–3.0). Follows unit when unit moves outside center 50% viewport.

## Data Flow

```
MapManager._ready()
  │
  ├─ ProceduralGeneration.generate(seed, 120, 120)
  │    │
  │    ├─ FastNoiseLite → heightmap[120][120]
  │    │
  │    ├─ For each cell (x, y):
  │    │    height = heightmap[x][y]
  │    │    biome = thresholds(height)  →  WATER | SAND | GRASS | DIRT | MOUNTAIN
  │    │    elevation = floor(height * 3)
  │    │    store to biome_map[x][y], elev_map[x][y]
  │    │
  │    ├─ For each elevation level (0, 1, 2):
  │    │    tile_layer = TileMapLayer.new()
  │    │    tile_layer.position.y = -elevation * 32
  │    │    For each cell matching this elevation:
  │    │       tile_layer.set_cell(coords, biome_to_tileset_source(biome))
  │    │    add_child(tile_layer)
  │    │
  │    ├─ For each cell where elev_map differs from neighbor:
  │    │    place cliff sprite at boundary edge
  │    │
  │    └─ Return biome_map, elev_map
  │
  ├─ ObjectPlacer.place_objects(biome_map, elev_map, rng)
  │    │
  │    ├─ For each biome region:
  │    │    density = placement_rules[biome].density
  │    │    pool = placement_rules[biome].candidates (from entorno/)
  │    │    For each eligible cell:
  │    │       if rng.randf() < density:
  │    │           pick random sprite from pool
  │    │           Sprite2D instance at cell center + random jitter
  │    │           add_child to ObjectContainer
  │    │
  │    └─ Return void (side-effect: populates ObjectContainer)
  │
  └─ Add UnitController as child
       └─ CameraController references UnitController for follow
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `game/map/Llanura1.tscn` | Create | Root scene: MapManager + CameraController + unit placeholder |
| `game/map/MapManager.gd` | Create | Holds map state, orchestrates generation, exposes `get_cell(x,y)` |
| `game/map/ProceduralGeneration.gd` | Create | FastNoiseLite → heightmap → biome → TileMapLayer population |
| `game/map/ObjectPlacer.gd` | Create | Biome placement rules → Sprite2D instances in y-sorted container |
| `game/map/CameraController.gd` | Create | Drag-scroll, map bounds clamp, unit-follow logic |
| `game/scripts/SpriteCache.gd` | Modify | Add `load_env_textures()` method for entorno/ sprites |
| `project.godot` | Modify | `run/main_scene="res://map/Llanura1.tscn"`, enable y-sort |
| `game/test_scene.tscn` | Keep | Not deleted; `project.godot` points to map instead |

## Interfaces / Contracts

```gdscript
# ProceduralGeneration.gd
func generate(seed_val: int, width: int, height: int) -> Dictionary:
    # Returns { biome_map: Array[][], elev_map: Array[][], trees: Array[Vector2i] }

# MapManager.gd public API
func get_biome(cell: Vector2i) -> int            # biome enum at cell
func get_elevation(cell: Vector2i) -> int         # height level at cell
func world_to_cell(pos: Vector2) -> Vector2i      # screen space → grid
func cell_to_world(cell: Vector2i) -> Vector2     # grid → screen center

# ObjectPlacer.gd
func place_objects(biome_map: Array, elev_map: Array, rng: RandomNumberGenerator, container: Node)

# CameraController.gd
@export var map_size: Vector2i = Vector2i(120, 120)
@export var follow_target: Node2D = null
@export var drag_button: int = MOUSE_BUTTON_MIDDLE

# SpriteCache.gd (addition)
func get_entorno_textures() -> Dictionary  # biome → Array[Texture2D]
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | Heightmap generation | Run generate() with known seed, verify biome_map shape = 120×120 |
| Unit | Biome thresholds | Mock FastNoiseLite output, verify correct biome for each height band |
| Unit | No duplicate placements | count unique cell positions in ObjectContainer — verify no duplicates |
| Integration | Full Llanura1 load | SceneTree.load("res://map/Llanura1.tscn") — assert no errors, TileMapLayers populated |
| Visual | Manual validation | Load scene, verify terrain/cliffs/objects render correctly at various zoom levels |
| E2E | Unit walks on map | Place UnitController, simulate WASD input, verify position changes without errors |

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary.

## Migration / Rollout

No migration required. Map is fully procedural — no saved state, no data migration. `project.godot` main scene path changes from `test_scene.tscn` to `map/Llanura1.tscn`.

## Open Questions

- [ ] Cliff sprite placement: as TileMapLayer layer (cliff-blended tiles) or individual Sprite2D instances? Individual sprites are easier for edge cases but worse for editing.
- [ ] TileSet resource: a single `.tres` file with all terrain tiles (grass, water, sand, dirt, cliff) or separate TileSets per biome? Single TileSet is simpler.
- [ ] Grass tile texture: composite two 64×32 halves at runtime in code, or pre-create 128×64 texture assets? Runtime compositing avoids asset pipeline changes.
