# Design: terrain-playable

## Technical Approach

Wire three existing but disconnected systems (ObjectPlacer, UnitController, CameraController) into `Llanura1.gd` after terrain generation. The current flow is:

```
Menu → terrain_only.tscn → Llanura1.gd._ready()
  └─ call_deferred("_generate")
       ├─ _build_tileset() → 7 strip textures × 8 tiles
       ├─ ProceduralGeneration.generate(seed, 300, 300, ts)
       │    └─ Returns [layer(TileMapLayer), contours(Node2D), heights(Node2D), elev_map, biome_map]
       ├─ add_child(layer), add_child(contours), add_child(heights)
       ├─ GameUI (CanvasLayer with minimap + coordinates)
       └─ _add_mouse_overlay()
```

New flow:

```
Menu → terrain_only.tscn → Llanura1.gd._ready()
  └─ call_deferred("_generate")
       ├─ _build_tileset()
       ├─ ProceduralGeneration.generate(seed, 300, 300, ts)
       ├─ add_child(layer), add_child(contours), add_child(heights)
       ├─ ObjectPlacer.place_objects(biome_map, elev_map, rng, object_container)
       ├─ CameraController setup (from terrain_only.tscn scene)
       ├─ UnitController as player child
       ├─ GameUI (CanvasLayer with minimap + coordinates)
       └─ _add_mouse_overlay()
```

## Architecture Decisions

### Decision: Integration Point

| | Option | Tradeoff |
|---|---|---|
| **Choice** | Modify Llanura1.gd directly | Single entry point, keeps terrain_only.tscn as main scene. All integration in one place. |
| Rejected | Switch to MapManager.gd flow | MapManager uses 120×120 and different ProceduralGeneration return format. Would require rewriting terrain generation. Current Llanura1.gd works. |
| Rejected | Create new orchestrator script | Adds indirection. The existing Llanura1.gd already works as orchestrator. |

**Rationale**: Llanura1.gd is the existing orchestrator. Adding ObjectPlacer + UnitController calls after terrain gen is the minimal change.

### Decision: Player Character

| | Option | Tradeoff |
|---|---|---|
| **Choice** | UnitController instantiated in Llanura1.gd | Full state machine (IDLE/WALK/ATTACK/HURT/DEATH), arquero animations, ballistic arrows, team color. Already exists and is tested. |
| Rejected | PlayerUnit.gd | Simpler but lacks attack/hurt/death states, arrow projectile, and team color. Would need to duplicate UnitController features. |

**Rationale**: UnitController.gd is 356 lines of complete state machine with 5-direction isometric animations, arrow prefab, team color shader, and WASD movement. Using it directly avoids rewriting.

### Decision: Camera Wiring

| | Option | Tradeoff |
|---|---|---|
| **Choice** | Replace Camera2D in terrain_only.tscn with CameraController | CameraController has follow-target, drag-scroll, zoom range, map bounds clamping. Already exists with those features. |
| Rejected | Keep Camera2D and add scripts | Would duplicate CameraController features. |

**Rationale**: CameraController.gd exists, works, supports follow mode, drag with middle mouse, zoom clamp, and WASD scroll.

### Decision: Input Split

| | Option | Tradeoff |
|---|---|---|
| **Choice** | UnitController uses WASD, CameraController uses arrow keys | Clean separation. Arrow keys scroll map when no follow target. WASD always moves character. |
| Rejected | Both use same actions | Camera scroll would fight with character movement. |

**Rationale**: UnitController already reads `ui_left/right/up/down` for movement. CameraController reads the same. Solution: CameraController checks `follow_target == null` before consuming arrow input; when following, arrow keys are ignored and camera follows the target. Alternatively, CameraController maps to separate `camera_*` input actions. The cleanest approach: CameraController uses `ui_*` actions ONLY when no `follow_target` is set. If a `follow_target` exists and the player presses WASD, the camera follows the target — no scroll conflict.

### Decision: Arrow.tscn Creation

| | Option | Tradeoff |
|---|---|---|
| **Choice** | Create Arrow.tscn from Arrow.gd script | Arrow.gd expects a specific scene structure (Area2D root with collision shape, visible sprite). Creating the scene once avoids runtime errors. |
| Rejected | Reference Arrow.gd directly | UnitController uses `preload("res://scenes/Arrow.tscn")`, so a .tscn file must exist. |

**Rationale**: Arrow.gd is `class_name Arrow extends Area2D`. The scene needs: Area2D root → Arrow.gd script, CollisionShape2D (circle), Sprite2D child (for the arrow texture).

### Decision: Map Size & Offset

| | Option | Tradeoff |
|---|---|---|
| **Choice** | Keep 300×300 with ox=-100, oy=-100 | Maintains current terrain generation and camera position. Objects and player are placed in same coordinate space. |
| Rejected | Change to 120×120 | Would lose the larger map the user chose. |

**Rationale**: User explicitly chose 300×300. ObjectPlacer works with any map size — it iterates biome_map/elev_map arrays.

## Data Flow

```
Llanura1.gd._ready()
  └─ call_deferred("_generate")
       │
       ├─ _build_tileset()
       │    └─ returns TileSet (7 sources × 8 tiles each)
       │
       ├─ ProceduralGeneration.generate(randi(), 300, 300, ts)
       │    └─ returns [layer, contours, heights, elev_map, biome_map]
       │
       ├─ add_child(layer)       # TileMapLayer
       ├─ add_child(contours)    # Node2D (contour line sprites)
       ├─ add_child(heights)     # Node2D (elevation overlay sprites)
       │
       ├─ ObjectContainer setup
       │    ├─ Node2D.new() → name="Objects", y_sort_enabled=true
       │    ├─ ObjectPlacer.place_objects(biome_map, elev_map, rng, container)
       │    └─ add_child(container)
       │
       ├─ UnitController instance
       │    ├─ load("res://scripts/UnitController.gd").new()
       │    ├─ Load sprites from arquero_manifest.json
       │    ├─ Position at map center
       │    ├─ Set camera follow target
       │    └─ add_child(unit)
       │
       ├─ CameraController is already in terrain_only.tscn
       │    └─ map_size = Vector2i(300, 300)
       │    └─ follow_target = unit
       │
       ├─ GameUI (CanvasLayer) — minimap + coordinates
       └─ _add_mouse_overlay() — bottom bar with cell/elevation info
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `map/Llanura1.gd` | **Modify** | Add ObjectPlacer integration, UnitController instantiation, ObjectContainer setup after terrain generation. Store elev_map/biome_map for ObjectPlacer access. |
| `terrain_only.tscn` | **Modify** | Replace basic Camera2D with CameraController (set map_size=300×300, zoom=0.13). |
| `map/CameraController.gd` | **Modify** | Add null-guard for arrow-key scroll when follow_target is set. Set default map_size to 300×300. |
| `scenes/Arrow.tscn` | **Create** | Area2D + CollisionShape2D + Sprite2D from Arrow.gd script. |
| `project.godot` | **Modify** | Ensure input actions exist (ui_left/right/up/down for WASD, test_attack/hurt/die/zoom_in/zoom_out). |

## Interfaces / Contracts

```gdscript
# Llanura1.gd modifications
# After terrain generation:
var object_container = Node2D.new()
object_container.name = "Objects"
object_container.y_sort_enabled = true

var placer = load("res://map/ObjectPlacer.gd").new()
placer.place_objects(_biome_map, _elev_map, rng, object_container)
add_child(object_container)

# Player unit setup
var unit = load("res://scripts/UnitController.gd").new()
unit.position = Vector2(0, 0)  # map center
unit.name = "PlayerUnit"
add_child(unit)

# Camera follows player
var camera = $CameraController
camera.map_size = Vector2i(300, 300)
camera.follow_target = unit

# ObjectPlacer.gd (existing - no changes needed)
func place_objects(
    biome_map: Array,     # Array[Array] of float noise values
    elev_map: Array,       # Array[Array] of int elevation (0-3)
    rng: RandomNumberGenerator,
    container: Node2D      # y-sorted Node2D to hold sprites
) -> void

# CameraController.gd (modification)
# In _process or _input:
# If follow_target != null, ignore arrow-key scroll input
# Arrow keys only scroll map when no target is being followed

# UnitController.gd (existing - no changes needed)
# WASD movement, click to shoot, F/H/R/E test keys
# Uses arquero_manifest.json for sprites
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Integration | Map loads without errors | Launch terrain_only.tscn, check output log for errors |
| Visual | Objects appear per biome | Scroll map, verify trees on grass, rocks on dirt, cacti on sand, reeds on water edge |
| Visual | Character visible with animations | WASD moves character, attack shows arrow, hurt/death animations play |
| Visual | Camera follows character | Move character, camera lerps to keep in center 50% viewport |
| Input | Arrow keys scroll without follow | Right-click to cancel follow, arrow keys scroll map |
| Input | WASD moves character | Press WASD, character position changes with correct animation |
| Performance | Stable FPS with 300×300 + objects | Monitor FPS during gameplay, no freezing or stuttering |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| 300×300 + 5000+ objects causes lag | Medium | Start with conservative density; reduce if needed. ObjectPlacer has density params. |
| Arrow.tscn scene structure wrong | Low | Verify Arrow.gd requirements, test arrow creation immediately |
| Input overlap between UnitController and CameraController | Low | CameraController checks follow_target before consuming arrow input |
| UnitController expects different parent/camera structure | Low | UnitController is self-contained CharacterBody2D; positioning as child of root Node2D works |
