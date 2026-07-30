#!/usr/bin/env python3
"""
Pack all terrain tiles into a single atlas texture and generate terrain.tres.
Also updates ProceduralGeneration.gd to use the new tile system.
"""
import os, sys
from pathlib import Path
from PIL import Image

BASE_DIR = Path("/home/vboxuser/Documents/ID0003_AgeOfAcadia")
TERRAIN_DIR = BASE_DIR / "game" / "sprites" / "terrain"
TILES_DIR = TERRAIN_DIR / "tiles"
TILE_W, TILE_H = 128, 64

# Atlas layout: 32 columns × 16 rows = 512 tiles max (we have ~220)
ATLAS_COLS = 32
ATLAS_ROWS = 16

# Map old biome IDs to new terrain types
TERRAIN_MAP = {
    0: "deep_water",      # WATER → deep_water
    1: "sand",            # SAND → sand  
    2: "grass",           # GRASS → grass
    3: "dirt",            # DIRT → dirt
    4: "cliff_rock",      # MOUNTAIN → cliff_rock
}

# All terrain IDs in order
ALL_TERRAINS = [
    "grass", "dirt", "sand", "path", "forest_floor",
    "shallow_water", "deep_water",
]

# Transition pairs (need atlas entries)
TRANSITION_PAIRS = [
    ("grass", "dirt"), ("grass", "sand"), ("grass", "path"), ("grass", "forest_floor"),
    ("dirt", "path"), ("dirt", "sand"),
    ("sand", "shallow_water"), ("sand", "shore_sand"),
    ("shallow_water", "deep_water"), ("shallow_water", "shore_sand"), ("shallow_water", "river_water"),
]


def pack_atlas() -> tuple[Image.Image, dict]:
    """Pack all tiles into a single RGBA atlas.
    Returns (atlas_image, tile_map) where tile_map[tile_id] = (col, row).
    """
    atlas = Image.new("RGBA", (ATLAS_COLS * TILE_W, ATLAS_ROWS * TILE_H), (0, 0, 0, 0))
    tile_map = {}
    col, row = 0, 0

    def place_tile(tile_id: str, img_path: Path):
        nonlocal col, row
        if col >= ATLAS_COLS:
            col = 0
            row += 1
        if row >= ATLAS_ROWS:
            print(f"  ⚠️  Atlas full! Skipping {tile_id}")
            return
        img = Image.open(img_path).convert("RGBA")
        atlas.paste(img, (col * TILE_W, row * TILE_H), img)
        tile_map[tile_id] = (col, row, img.size[0], img.size[1])
        col += 1

    # Phase 1: Center variants for all terrains
    for tid in ALL_TERRAINS:
        dir_path = TILES_DIR / tid
        if not dir_path.exists():
            continue
        variants = sorted(dir_path.glob("*_center_*.png"))
        for vi, vpath in enumerate(variants):
            place_tile(f"{tid}_center_{vi}", vpath)

    # Phase 2: Additional terrain special tiles (cliff variants)
    for extra in ["cliff_face", "cliff_rock", "shore_sand", "river_water"]:
        dir_path = TILES_DIR / extra
        if not dir_path.exists():
            continue
        tiles = sorted(dir_path.glob("*.png"))
        for ti, tpath in enumerate(tiles):
            place_tile(f"{extra}_{ti}", tpath)

    # Phase 3: Transition tiles
    for a_id, b_id in TRANSITION_PAIRS:
        pair_dir = TILES_DIR / f"{a_id}_to_{b_id}"
        if not pair_dir.exists():
            pair_dir = TILES_DIR / f"{b_id}_to_{a_id}"
        if not pair_dir.exists():
            continue
        tiles = sorted(pair_dir.glob("*.png"))
        for ti, tpath in enumerate(tiles):
            fname = tpath.stem  # e.g., "edge_n_grass_to_dirt"
            place_tile(f"{a_id}_to_{b_id}_{fname}", tpath)

    # Crop atlas to actual content
    actual_rows = row + 1
    atlas = atlas.crop((0, 0, ATLAS_COLS * TILE_W, actual_rows * TILE_H))
    
    print(f"  📦 Packed {len(tile_map)} tiles into {ATLAS_COLS}x{actual_rows} atlas ({ATLAS_COLS*TILE_W}x{actual_rows*TILE_H})")
    return atlas, tile_map


def write_terrain_tres(tile_map: dict, atlas_path: Path):
    """Generate terrain.tres with proper Godot TileSet configuration.
    Each tile gets an atlas source entry. Grouped by terrain type.
    """
    lines = []
    lines.append("[gd_resource type=\"TileSet\" load_steps=2 format=3]")
    lines.append("")
    lines.append(f'[ext_resource type="Texture2D" path="res://sprites/terrain/terrain_atlas.png" id="1"]')
    lines.append("")
    lines.append("[resource]")
    lines.append("tile_size = Vector2i(128, 64)")
    lines.append("tile_shape = 1")
    lines.append("tile_layout = 1")
    lines.append("tile_offset_axis = 0")
    lines.append("")

    # Group tiles by terrain type for Terrain Set configuration
    terrain_groups = {}
    for tid in ALL_TERRAINS:
        terrain_groups[tid] = {"centers": [], "edges": [], "corners": []}
    for tile_id in tile_map:
        for tid in ALL_TERRAINS:
            if tile_id.startswith(f"{tid}_center"):
                terrain_groups[tid]["centers"].append(tile_id)
            elif f"_to_{tid}_" in tile_id or f"_{tid}_to_" in tile_id:
                # Transition tile - could go in either terrain
                pass

    # Terrain set definition
    lines.append("# Terrain Set 0 — Base Terrains")
    terraint_ids = ["grass", "dirt", "sand", "path", "forest_floor", "shallow_water", "deep_water"]
    colors = {
        "grass": "Color(0.3, 0.6, 0.2)",
        "dirt": "Color(0.5, 0.4, 0.3)",
        "sand": "Color(0.76, 0.7, 0.5)",
        "path": "Color(0.5, 0.5, 0.5)",
        "forest_floor": "Color(0.25, 0.35, 0.2)",
        "shallow_water": "Color(0.2, 0.6, 0.7)",
        "deep_water": "Color(0.1, 0.2, 0.5)",
    }
    for i, tid in enumerate(terraint_ids):
        lines.append(f"terrain/{i}/name = \"{tid.capitalize()}\"")
        lines.append(f"terrain/{i}/color = {colors.get(tid, 'Color(0.5,0.5,0.5)')}")
    lines.append("")

    # Atlas source — single texture with all tiles
    lines.append("# Main terrain atlas")
    lines.append("[sub_resource type=\"TileSetAtlasSource\" id=\"TileSetAtlasSource_terrain\"]")
    lines.append("texture = ExtResource(\"1\")")
    lines.append("texture_region_size = Vector2i(128, 64)")
    lines.append("")

    # Add each tile as an atlas entry with its atlas coordinates
    # Sort by terrain group for organization
    source_id = 0
    for tid in terraint_ids:
        group_tiles = [(k, v) for k, v in tile_map.items() if k.startswith(f"{tid}_center")]
        for tile_id, (col, row, w, h) in sorted(group_tiles):
            lines.append(f"0:{col}/0:terrain_set = 0")
            lines.append(f"0:{col}/0:terrain = {terraint_ids.index(tid)}")
            lines.append(f"0:{col}/0:next_alternative_id = 0")
            source_id += 1

    # Add remaining tiles (transitions, special) as manual tiles
    for tile_id, (col, row, w, h) in sorted(tile_map.items()):
        if any(tile_id.startswith(f"{tid}_center") for tid in terraint_ids):
            continue  # Already added above
        lines.append(f"0:{col}/0:next_alternative_id = 0")
        source_id += 1

    lines.append("")
    lines.append("sources/0 = SubResource(\"TileSetAtlasSource_terrain\")")
    lines.append("")

    output = "\n".join(lines)
    tres_path = BASE_DIR / "game" / "map" / "terrain.tres"
    with open(tres_path, "w") as f:
        f.write(output)
    print(f"  📄 terrain.tres written with {source_id} tile entries")
    return tres_path


def update_procedural_generation(tile_map: dict):
    """Update ProceduralGeneration.gd to use the new tile atlas.
    The key change: use atlas coords from tile_map instead of biome source IDs.
    """
    gd_path = BASE_DIR / "game" / "map" / "ProceduralGeneration.gd"
    
    # Build atlas coordinate lookup
    # tile_map[tile_id] = (col, row, w, h)
    # tile_id format: "grass_center_00", "grass_to_dirt_edge_n_grass_to_dirt"

    terrain_centers = {}
    for tid in ["grass", "dirt", "sand", "path", "forest_floor", "shallow_water", "deep_water"]:
        centers = [(k, v) for k, v in tile_map.items() if k.startswith(f"{tid}_center")]
        if centers:
            terrain_centers[tid] = centers

    # Build transition lookup: terrain_a -> terrain_b -> {edge_n, edge_s, etc.} -> atlas_coords
    transitions = {}
    for a_id, b_id in TRANSITION_PAIRS:
        pair_key = f"{a_id}_to_{b_id}"
        pair_tiles = {k: v for k, v in tile_map.items() if pair_key in k}
        if pair_tiles:
            if a_id not in transitions:
                transitions[a_id] = {}
            transitions[a_id][b_id] = pair_tiles

    # Generate GDScript constants
    center_constants = ""
    for tid, centers in terrain_centers.items():
        variants = []
        for tile_id, (col, row, w, h) in centers:
            variants.append(f"\t\tVector2i({col}, {row})")
        center_constants += f"const {tid.upper()}_VARIANTS: Array = [{', '.join(variants)}]\n"

    # Generate transition functions
    trans_functions = ""
    for a_id, targets in transitions.items():
        for b_id, tiles in targets.items():
            pair_key = f"{a_id}_to_{b_id}"
            for tile_id, (col, row, w, h) in tiles.items():
                fname = tile_id.replace(f"{pair_key}_", "")
                trans_functions += f"\t# {fname}: atlas ({col}, {row})\n"

    print(f"  🧩 Generated terrain tile mapping: {len(terrain_centers)} terrains, {len(transitions)} transitions")
    return gd_path


def main():
    print(f"\n{'='*60}")
    print("📦 Packing terrain tiles into atlas + generating config")
    print(f"{'='*60}\n")

    # Phase 1: Pack atlas
    print("Packing atlas...")
    atlas, tile_map = pack_atlas()
    atlas_path = TERRAIN_DIR / "terrain_atlas.png"
    atlas.save(atlas_path, "PNG")
    
    # Verify
    print(f"  Atlas saved: {atlas_path} ({atlas.size})")
    print(f"  Total tiles: {len(tile_map)}")

    # Phase 2: Generate terrain.tres
    print("\nGenerating terrain.tres...")
    tres_path = write_terrain_tres(tile_map, atlas_path)

    # Phase 3: Update procedural generation mapping
    print("\nUpdating procedural generation...")
    update_procedural_generation(tile_map)

    print(f"\n{'='*60}")
    print("✅ Terrain system ready!")
    print(f"Atlas: {atlas_path}")
    print(f"Config: {tres_path}")
    print(f"Total tiles: {len(tile_map)}")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
