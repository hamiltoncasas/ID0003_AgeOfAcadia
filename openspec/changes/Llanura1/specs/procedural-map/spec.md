# procedural-map Specification

## Purpose

Generate a 120×120 isometric terrain grid with multi-height elevation, biome-based decoration, and camera controls. All generation is deterministic per seed; objects are Sprite2D instances for future animation/destruction.

## Requirements

### Requirement: Terrain Generation

The system MUST generate a 120×120 isometric tile grid (128×64 diamond). MUST support five biomes: grass, water, sand, dirt, mountain. Grass cells MUST composite two 64×32 half-tiles.

#### Scenario: Full grid with all biomes

- GIVEN a seed and dimensions 120×120
- WHEN `ProceduralGeneration.generate(seed, 120, 120)` runs
- THEN `biome_map` is exactly 120×120
- AND all five biome constants appear at least once

#### Scenario: Single-biome extreme

- GIVEN noise thresholds clamped to one biome
- WHEN the heightmap stays in one band
- THEN every cell maps to that biome
- AND generation completes without errors

#### Error: Invalid dimensions

- GIVEN width or height ≤ 0
- WHEN `generate(seed, 0, 120)` is called
- THEN the result is `{ success: false, error: "Invalid dimensions" }`

### Requirement: Elevation

MUST support three height levels (0–2). Each level on a separate TileMapLayer offset by `-elevation × 32` on y. Cliff sprites placed at cells where adjacent cells differ in elevation.

#### Scenario: Cliff at boundary

- GIVEN adjacent cells with different elevation
- WHEN generation completes
- THEN a cliff sprite exists at that boundary
- AND same-elevation neighbors have no cliff

#### Edge case: Flat map

- GIVEN a heightmap with all cells at elevation 0
- WHEN generation completes
- THEN only one TileMapLayer is populated
- AND no cliff sprites exist

### Requirement: Object Placement

MUST place ≥127 objects from `game/sprites/entorno/` as Sprite2D children of a y-sorted Node2D. MUST NOT place on water. Density and sprite pools vary per biome.

#### Scenario: Per-biome rules applied

- GIVEN a biome map with grass, dirt, sand, water
- WHEN `ObjectPlacer.place_objects()` runs
- THEN trees on grass, rocks on dirt, cacti/palms on sand
- AND zero objects on water cells
- AND total count ≥ 127

#### Error: Empty entorno directory

- GIVEN `SpriteCache.get_entorno_textures()` returns empty
- WHEN `place_objects()` runs
- THEN it logs a warning and returns without objects
- AND map generation still completes

### Requirement: Deterministic Generation

MUST produce identical `biome_map`, `elev_map`, and object positions for the same seed. SHOULD accept seed parameter; omit = random.

#### Scenario: Identical re-generation

- GIVEN a fixed seed
- WHEN `generate()` and `place_objects()` run twice with it
- THEN both runs produce identical maps and object positions

#### Error: Negative seed

- GIVEN a negative seed
- WHEN `generate(-1, 120, 120)` is called
- THEN the system uses `abs(-1)` as effective seed
- AND generation completes normally

### Requirement: Performance

SHOULD maintain 60 FPS on medium hardware at full map + 1500 objects. MUST use TileMapLayer visibility culling. SHOULD cull off-screen Sprite2D objects.

#### Scenario: Frame rate baseline

- GIVEN full 120×120 map with 1500 objects
- WHEN running on a dedicated GPU / 16 GB RAM machine
- THEN frame rate stays ≥60 FPS during drag-scroll and idle

### Requirement: Camera

MUST support drag scrolling within map bounds. MUST support zoom 0.3×–3.0×. SHOULD optionally follow unit outside center 50% viewport.

#### Scenario: Clamped drag-scroll

- GIVEN camera at default zoom
- WHEN user drags past map edge
- THEN camera is clamped so map edge stays visible

#### Scenario: Zoom boundaries

- GIVEN active camera
- WHEN user zooms to 0.3× or 3.0×
- THEN zoom is clamped at those limits

### Requirement: Y-Sort

MUST render Sprite2D objects with correct isometric depth. ObjectContainer MUST have `y_sort_enabled = true`. TileMapLayers ordered by elevation back-to-front.

#### Scenario: Depth ordering

- GIVEN two Sprite2D objects at different y-coordinates
- WHEN the scene renders
- THEN the object with higher y renders in front
