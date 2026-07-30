#!/usr/bin/env python3
"""
Generate a complete isometric 2:1 terrain tileset using FLUX.2 pro via Together AI.

Strategy:
  Phase 1 — Generate 11 texture swatches (1024x1024) via FLUX.2 pro ($0.03 each = $0.33)
  Phase 2 — Slice each swatch into 128x64 isometric tiles, create center variants
  Phase 3 — Generate edge/corner transitions by blending terrain textures
  Phase 4 — Organize into Godot-ready tile directories

Output: game/sprites/terrain/
"""

import os, io, base64, time, json, sys
from pathlib import Path
from together import Together
from PIL import Image, ImageFilter

# ── Config ──────────────────────────────────────────────────────
BASE_DIR = Path("/home/vboxuser/Documents/ID0003_AgeOfAcadia")
TERRAIN_DIR = BASE_DIR / "game" / "sprites" / "terrain"
TILESHEETS_DIR = TERRAIN_DIR / "tilesheets"
TILES_DIR = TERRAIN_DIR / "tiles"

API_KEY = os.environ.get("TOGETHER_API_KEY", "")
MODEL = "black-forest-labs/FLUX.2-pro"
TILE_W, TILE_H = 128, 64  # Isometric 2:1 tile size
SHEET_SIZE = 1024          # 1024x1024 tilesheets

# NOTE: Each terrain generates a COHERENT texture swatch. Transition tiles
# (edges, corners) are created in code by blending two terrain textures.

TERRAINS = [
    {
        "id": "grass",
        "name": "Grass",
        "prompt": (
            "Isometric 2:1 game terrain texture, 1024x1024 seamless tileable, "
            "hand-painted medieval grass ground, vibrant green grass with subtle yellow-green variation, "
            "small clovers and grass tufts, rich meadow texture, "
            "Age of Empires 2 style isometric ground tile, "
            "clean readable top-down isometric view, pixel art style, "
            "no objects, no characters, no shadows, no buildings"
        ),
    },
    {
        "id": "dirt",
        "name": "Dirt",
        "prompt": (
            "Isometric 2:1 game terrain texture, 1024x1024 seamless tileable, "
            "hand-painted medieval dirt ground, warm brown earth, "
            "packed soil with small pebbles and cracks, "
            "Age of Empires 2 style isometric ground tile, "
            "clean readable top-down isometric view, pixel art style, "
            "no objects, no characters, no shadows"
        ),
    },
    {
        "id": "sand",
        "name": "Sand",
        "prompt": (
            "Isometric 2:1 game terrain texture, 1024x1024 seamless tileable, "
            "hand-painted medieval sand ground, warm golden-beige sand, "
            "small sand ripples and grains, beach texture, "
            "Age of Empires 2 style isometric ground tile, "
            "clean readable top-down isometric view, pixel art style, "
            "no objects, no characters, no shadows"
        ),
    },
    {
        "id": "path",
        "name": "Stone Path",
        "prompt": (
            "Isometric 2:1 game terrain texture, 1024x1024 seamless tileable, "
            "hand-painted medieval cobblestone path, grey stone blocks, "
            "flat worn cobblestones with moss between cracks, "
            "Age of Empires 2 style isometric ground tile, "
            "clean readable top-down isometric view, pixel art style, "
            "no objects, no characters, no shadows"
        ),
    },
    {
        "id": "shallow_water",
        "name": "Shallow Water",
        "prompt": (
            "Isometric 2:1 game terrain texture, 1024x1024 seamless tileable, "
            "hand-painted shallow clear water, turquoise-blue translucent water, "
            "sandy bottom visible through water, gentle water ripple texture, "
            "Age of Empires 2 style isometric water tile, "
            "clean readable top-down isometric view, pixel art style, "
            "no objects, no characters, no shadows"
        ),
    },
    {
        "id": "deep_water",
        "name": "Deep Water",
        "prompt": (
            "Isometric 2:1 game terrain texture, 1024x1024 seamless tileable, "
            "hand-painted deep ocean water, dark blue-teal water, "
            "deep water with wave patterns and depth gradient, "
            "Age of Empires 2 style isometric water tile, "
            "clean readable top-down isometric view, pixel art style, "
            "no objects, no characters, no shadows"
        ),
    },
    {
        "id": "forest_floor",
        "name": "Forest Floor",
        "prompt": (
            "Isometric 2:1 game terrain texture, 1024x1024 seamless tileable, "
            "hand-painted medieval forest floor, dark rich earth with scattered leaves, "
            "pine needles and small roots, shaded woodland ground, "
            "Age of Empires 2 style isometric ground tile, "
            "clean readable top-down isometric view, pixel art style, "
            "no objects, no characters, no trees, no shadows"
        ),
    },
    {
        "id": "cliff_face",
        "name": "Cliff Face",
        "prompt": (
            "Isometric 2:1 game terrain texture, 1024x1024 seamless tileable, "
            "hand-painted medieval cliff rock face, grey-brown rock wall, "
            "vertical rock strata with cracks and moss patches, "
            "Age of Empires 2 style isometric cliff tile, "
            "clean readable side-view isometric, pixel art style, "
            "no objects, no characters, no shadows, no sky"
        ),
    },
    {
        "id": "cliff_rock",
        "name": "Cliff Rock Top",
        "prompt": (
            "Isometric 2:1 game terrain texture, 1024x1024 seamless tileable, "
            "hand-painted rocky mountain terrain, grey-brown stone surface, "
            "craggy rock texture with small crevices and lichen, "
            "Age of Empires 2 style isometric ground tile, "
            "clean readable top-down isometric view, pixel art style, "
            "no objects, no characters, no shadows"
        ),
    },
    {
        "id": "river_water",
        "name": "River Water",
        "prompt": (
            "Isometric 2:1 game terrain texture, 1024x1024 seamless tileable, "
            "hand-painted flowing river water, bright blue-green water, "
            "water flow lines and gentle current patterns, "
            "Age of Empires 2 style isometric water tile, "
            "clean readable top-down isometric view, pixel art style, "
            "no objects, no characters, no shadows"
        ),
    },
    {
        "id": "shore_sand",
        "name": "Shore / Wet Sand",
        "prompt": (
            "Isometric 2:1 game terrain texture, 1024x1024 seamless tileable, "
            "hand-painted wet sand shoreline, beige-brown damp sand, "
            "water's edge texture with small wave marks, "
            "Age of Empires 2 style isometric ground tile, "
            "clean readable top-down isometric view, pixel art style, "
            "no objects, no characters, no shadows"
        ),
    },
]

# Terrain pairs that need transition tiles (grass connects to most)
TRANSITION_PAIRS = [
    ("grass", "dirt"),
    ("grass", "sand"),
    ("grass", "path"),
    ("grass", "forest_floor"),
    ("dirt", "path"),
    ("dirt", "sand"),
    ("sand", "shallow_water"),
    ("sand", "shore_sand"),
    ("shallow_water", "deep_water"),
    ("shallow_water", "shore_sand"),
    ("shallow_water", "river_water"),
]


# ── Phase 1: Generate tilesheets ─────────────────────────────────

def generate_tilesheet(terrain: dict, client: Together) -> Path:
    """Generate one 1024x1024 texture swatch via FLUX.2 pro.
    Returns path to saved PNG.
    """
    output_path = TILESHEETS_DIR / f"{terrain['id']}.png"
    if output_path.exists():
        print(f"  ⏭️  Already exists: {terrain['id']}.png")
        return output_path

    print(f"  🎨 Generating {terrain['name']}...", end=" ", flush=True)
    try:
        resp = client.images.generate(
            model=MODEL,
            prompt=terrain["prompt"],
            width=SHEET_SIZE,
            height=SHEET_SIZE,
            n=1,
            response_format="b64_json",
        )
        img_data = resp.data[0].b64_json
        img_bytes = base64.b64decode(img_data)
        img = Image.open(io.BytesIO(img_bytes))
        img = img.convert("RGBA")
        img.save(output_path, "PNG")
        print(f"✅ ({img.size[0]}x{img.size[1]})")
        return output_path
    except Exception as e:
        print(f"❌ {e}")
        return None


def generate_all_tilesheets():
    """Generate all 11 terrain tilesheets sequentially."""
    os.environ["TOGETHER_API_KEY"] = API_KEY
    client = Together()

    TILESHEETS_DIR.mkdir(parents=True, exist_ok=True)

    print(f"\n{'='*60}")
    print(f"Phase 1: Generating {len(TERRAINS)} tilesheets with {MODEL}")
    print(f"Cost estimate: {len(TERRAINS)} × $0.03 = ${len(TERRAINS)*0.03:.2f}")
    print(f"{'='*60}\n")

    results = {}
    for i, terrain in enumerate(TERRAINS, 1):
        print(f"[{i}/{len(TERRAINS)}]", end=" ")
        path = generate_tilesheet(terrain, client)
        results[terrain["id"]] = path
        if path:
            # Delay between API calls to avoid rate limiting
            time.sleep(2)

    print(f"\n✅ Phase 1 complete: {sum(1 for v in results.values() if v)}/{len(TERRAINS)} generated\n")
    return results


# ── Phase 2: Slice tilesheets into variants ──────────────────────

def slice_texture_swatch(texture_path: Path, terrain_id: str, num_variants: int = 8):
    """Slice a 1024x1024 texture swatch into 128x64 isometric tiles.
    Samples num_variants different 128x64 regions as center tile variants.
    """
    out_dir = TILES_DIR / terrain_id
    out_dir.mkdir(parents=True, exist_ok=True)

    img = Image.open(texture_path).convert("RGBA")
    swatch_w, swatch_h = img.size

    # How many complete 128x64 tiles fit in the swatch
    cols = swatch_w // TILE_W   # 1024/128 = 8
    rows = swatch_h // TILE_H   # 1024/64 = 16

    variants = []
    idx = 0
    for r in range(rows):
        for c in range(cols):
            if idx >= num_variants:
                break
            x, y = c * TILE_W, r * TILE_H
            tile = img.crop((x, y, x + TILE_W, y + TILE_H))
            fname = f"{terrain_id}_center_{idx:02d}.png"
            tile.save(out_dir / fname, "PNG")
            variants.append(fname)
            idx += 1
        if idx >= num_variants:
            break

    print(f"  📦 {terrain_id}: {len(variants)} center variants")
    return out_dir, variants


def create_transition_tiles(terrain_a: str, terrain_b: str, a_dir: Path, b_dir: Path):
    """Create edge and corner transition tiles between two terrain types.
    Blends a 128x64 region from terrain A with terrain B using an alpha mask.
    
    Edge N: terrain B at top half, terrain A at bottom half
    Edge S: terrain A at top half, terrain B at bottom half  
    Edge E: terrain B at right half, terrain A at left half
    Edge W: terrain A at right half, terrain B at left half
    
    Corners use diagonal blending patterns.
    """
    # Use first center variant as base texture for each terrain
    a_variants = sorted(a_dir.glob("*_center_*.png"))
    b_variants = sorted(b_dir.glob("*_center_*.png"))
    if not a_variants or not b_variants:
        return []

    a_img = Image.open(a_variants[0]).convert("RGBA")
    b_img = Image.open(b_variants[0]).convert("RGBA")

    pair_id = f"{terrain_a}_to_{terrain_b}"
    out_dir = TILES_DIR / pair_id
    out_dir.mkdir(parents=True, exist_ok=True)

    generated = []

    # Edge transitions (4 directions)
    edges = {
        f"edge_n_{pair_id}": _make_edge_blend(a_img, b_img, "n"),
        f"edge_e_{pair_id}": _make_edge_blend(a_img, b_img, "e"),
        f"edge_s_{pair_id}": _make_edge_blend(a_img, b_img, "s"),
        f"edge_w_{pair_id}": _make_edge_blend(a_img, b_img, "w"),
    }
    for fname, tile in edges.items():
        path = out_dir / f"{fname}.png"
        tile.save(path, "PNG")
        generated.append(str(path))

    # Outer corners (4 directions) — convex
    outer = {
        f"corner_out_ne_{pair_id}": _make_corner_blend(a_img, b_img, "ne"),
        f"corner_out_se_{pair_id}": _make_corner_blend(a_img, b_img, "se"),
        f"corner_out_sw_{pair_id}": _make_corner_blend(a_img, b_img, "sw"),
        f"corner_out_nw_{pair_id}": _make_corner_blend(a_img, b_img, "nw"),
    }
    for fname, tile in outer.items():
        path = out_dir / f"{fname}.png"
        tile.save(path, "PNG")
        generated.append(str(path))

    # Inner corners (4 directions) — concave
    inner = {
        f"corner_in_ne_{pair_id}": _make_inner_corner_blend(a_img, b_img, "ne"),
        f"corner_in_se_{pair_id}": _make_inner_corner_blend(a_img, b_img, "se"),
        f"corner_in_sw_{pair_id}": _make_inner_corner_blend(a_img, b_img, "sw"),
        f"corner_in_nw_{pair_id}": _make_inner_corner_blend(a_img, b_img, "nw"),
    }
    for fname, tile in inner.items():
        path = out_dir / f"{fname}.png"
        tile.save(path, "PNG")
        generated.append(str(path))

    print(f"  🔄 {pair_id}: 12 transition tiles")
    return generated


def _make_edge_blend(a: Image.Image, b: Image.Image, direction: str) -> Image.Image:
    """Blend two terrain tiles with a smooth edge transition."""
    w, h = a.size
    result = Image.new("RGBA", (w, h))
    mask = Image.new("L", (w, h), 0)

    pix_a = a.load()
    pix_b = b.load()

    for y in range(h):
        for x in range(w):
            # Calculate blend factor based on direction
            if direction == "n":
                factor = 1.0 - y / h  # B at top (y=0), A at bottom (y=h)
            elif direction == "s":
                factor = y / h         # A at top, B at bottom
            elif direction == "e":
                factor = x / w         # A at left, B at right
            elif direction == "w":
                factor = 1.0 - x / w   # B at left, A at right
            else:
                factor = 0.5

            # Apply a slight curve to make transition natural
            if factor < 0.15:
                fa, fb = 1.0, 0.0
            elif factor > 0.85:
                fa, fb = 0.0, 1.0
            else:
                # Smooth step
                t = (factor - 0.15) / 0.7
                t = t * t * (3 - 2 * t)  # smoothstep
                fa, fb = 1.0 - t, t

            ca = pix_a[x, y]
            cb = pix_b[x, y]
            result.putpixel((x, y), (
                int(ca[0] * fa + cb[0] * fb),
                int(ca[1] * fa + cb[1] * fb),
                int(ca[2] * fa + cb[2] * fb),
                255,
            ))
    return result


def _make_corner_blend(a: Image.Image, b: Image.Image, corner: str) -> Image.Image:
    """Blend two terrains with a diagonal corner pattern (convex)."""
    w, h = a.size
    result = Image.new("RGBA", (w, h))
    pix_a = a.load()
    pix_b = b.load()

    for y in range(h):
        for x in range(w):
            # Normalize coordinates [0,1]
            nx, ny = x / w, y / h

            # Diagonal distance based on corner
            if corner == "ne":
                d = 1.0 - max(nx, 1.0 - ny)
            elif corner == "se":
                d = 1.0 - max(nx, ny)
            elif corner == "sw":
                d = 1.0 - max(1.0 - nx, ny)
            elif corner == "nw":
                d = 1.0 - max(1.0 - nx, 1.0 - ny)
            else:
                d = 0.5

            # Smooth blend
            t = max(0.0, min(1.0, d))
            t = t * t * (3 - 2 * t)

            ca = pix_a[x, y]
            cb = pix_b[x, y]
            result.putpixel((x, y), (
                int(ca[0] * (1 - t) + cb[0] * t),
                int(ca[1] * (1 - t) + cb[1] * t),
                int(ca[2] * (1 - t) + cb[2] * t),
                255,
            ))
    return result


def _make_inner_corner_blend(a: Image.Image, b: Image.Image, corner: str) -> Image.Image:
    """Blend two terrains with inverted diagonal pattern (concave)."""
    w, h = a.size
    result = Image.new("RGBA", (w, h))
    pix_a = a.load()
    pix_b = b.load()

    for y in range(h):
        for x in range(w):
            nx, ny = x / w, y / h

            if corner == "ne":
                d = max(nx, 1.0 - ny)
                side_a = nx > 1.0 - ny  # A takes the larger wedge
            elif corner == "se":
                d = max(nx, ny)
                side_a = nx > ny
            elif corner == "sw":
                d = max(1.0 - nx, ny)
                side_a = 1.0 - nx > ny
            elif corner == "nw":
                d = max(1.0 - nx, 1.0 - ny)
                side_a = 1.0 - nx > 1.0 - ny
            else:
                d, side_a = 0.5, True

            t = max(0.0, min(1.0, d * 1.5 - 0.25))
            t = t * t * (3 - 2 * t)

            ca = pix_a[x, y]
            cb = pix_b[x, y]
            # inner corner: A dominates the corner, B fills the rest
            if side_a:
                fa, fb = 1.0 - t, t
            else:
                fa, fb = t, 1.0 - t

            result.putpixel((x, y), (
                int(ca[0] * fa + cb[0] * fb),
                int(ca[1] * fa + cb[1] * fb),
                int(ca[2] * fa + cb[2] * fb),
                255,
            ))
    return result


# ── Phase 3: Process all — slice + transitions ───────────────────

def process_all(tilesheet_paths: dict):
    """Phase 2+3: Slice all tilesheets, create transitions."""
    print(f"\n{'='*60}")
    print("Phase 2: Slicing tilesheets into center variants")
    print(f"{'='*60}\n")

    terrain_dirs = {}
    for tid, path in tilesheet_paths.items():
        if path and path.exists():
            out_dir, variants = slice_texture_swatch(path, tid, num_variants=8)
            terrain_dirs[tid] = out_dir

    print(f"\n{'='*60}")
    print("Phase 3: Creating transition tiles (edges + corners)")
    print(f"{'='*60}\n")

    all_transitions = 0
    for a_id, b_id in TRANSITION_PAIRS:
        if a_id in terrain_dirs and b_id in terrain_dirs:
            tiles = create_transition_tiles(a_id, b_id, terrain_dirs[a_id], terrain_dirs[b_id])
            all_transitions += len(tiles)

    print(f"\n✅ Total: {all_transitions} transition tiles created")
    return terrain_dirs


# ── Phase 4: Generate terrain.tres file ──────────────────────────

def generate_terrain_tres(terrain_dirs: dict):
    """Generate a Godot terrain.tres with proper Terrain Set configuration.
    
    Creates a TileSet with:
    - 7 terrain types in TerrainSet 0 (base terrains)
    - Isometric diamond tile shape (128x64)
    - Atlas sources with proper terrain bitmasks for auto-transitions
    """
    print(f"\n{'='*60}")
    print("Phase 4: Generating terrain.tres")
    print(f"{'='*60}\n")

    # Map terrain IDs to terrain set indices
    terrain_order = ["grass", "dirt", "sand", "path", "forest_floor", "shallow_water", "deep_water"]

    tres_path = BASE_DIR / "game" / "map" / "terrain.tres"

    # Build terrain set string
    terrain_set_lines = []
    for i, tid in enumerate(terrain_order):
        terrain_set_lines.append(f"\tterrain/{i}/name = \"{tid.capitalize()}\"")
        terrain_set_lines.append(f"\tterrain/{i}/color = {_terrain_color(tid)}")

    # Build atlas sources for each terrain
    atlas_lines = []
    source_id = 0
    for tid in terrain_order:
        dir_path = terrain_dirs.get(tid)
        if not dir_path:
            continue

        variants = sorted(dir_path.glob("*_center_*.png"))
        if not variants:
            continue

        # Each variant gets an entry in the atlas
        for vi, vpath in enumerate(variants):
            rel_path = f"res://sprites/terrain/tiles/{tid}/{vpath.name}"
            atlas_lines.append(f"\n[sub_resource type=\"TileSetAtlasSource\" id=\"TileSetAtlasSource_{tid}_{vi}\"]")
            atlas_lines.append(f"texture = ExtResource(\"{tid}_{vi}\")")
            atlas_lines.append(f"texture_region_size = Vector2i(128, 64)")
            atlas_lines.append(f"0:0/0 = 0")
            atlas_lines.append(f"0:0/0:terrain_set = 0")
            atlas_lines.append(f"0:0/0:terrain = {terrain_order.index(tid)}")
            atlas_lines.append(f"0:0/0:next_alternative_id = 0")

        source_id += 1

    # Resource references
    ext_resources = []
    for i, tid in enumerate(terrain_order):
        dir_path = terrain_dirs.get(tid)
        if not dir_path:
            continue
        variants = sorted(dir_path.glob("*_center_*.png"))
        for vi, vpath in enumerate(variants):
            rel_path = f"res://sprites/terrain/tiles/{tid}/{vpath.name}"
            ext_resources.append(f"\n[ext_resource type=\"Texture2D\" path=\"{rel_path}\" id=\"{tid}_{vi}\"]")

    # Write terrain.tres
    with open(tres_path, "w") as f:
        f.write("[gd_resource type=\"TileSet\" load_steps={} format=3]\n".format(
            len(ext_resources) + 1))

        for res in ext_resources:
            f.write(res)

        f.write("\n\n[resource]\n")
        f.write(f"tile_size = Vector2i(128, 64)\n")
        f.write("tile_shape = 1  # Isometric\n")
        f.write("tile_layout = 1  # Diamond\n")
        f.write("tile_offset_axis = 0\n\n")

        # Terrain set
        f.write("# Terrain Set 0 — Base Terrains\n")
        for line in terrain_set_lines:
            f.write(line + "\n")

        # Atlas sources
        f.write("\n# Atlas Sources\n")
        source_id = 0
        for tid in terrain_order:
            dir_path = terrain_dirs.get(tid)
            if not dir_path:
                continue
            variants = sorted(dir_path.glob("*_center_*.png"))
            for vi, vpath in enumerate(variants):
                f.write(f"sources/{source_id} = SubResource(\"TileSetAtlasSource_{tid}_{vi}\")\n")
                source_id += 1

    print(f"  📄 terrain.tres written with {len(terrain_order)} terrain types")
    print(f"  Sources: {source_id} atlas entries")

    return tres_path


def _terrain_color(tid: str) -> str:
    colors = {
        "grass": "Color(0.3, 0.6, 0.2)",
        "dirt": "Color(0.5, 0.4, 0.3)",
        "sand": "Color(0.76, 0.7, 0.5)",
        "path": "Color(0.5, 0.5, 0.5)",
        "forest_floor": "Color(0.25, 0.35, 0.2)",
        "shallow_water": "Color(0.2, 0.6, 0.7)",
        "deep_water": "Color(0.1, 0.2, 0.5)",
    }
    return colors.get(tid, "Color(0.5, 0.5, 0.5)")


# ── Main ─────────────────────────────────────────────────────────

def main():
    if not API_KEY:
        print("ERROR: Set TOGETHER_API_KEY environment variable")
        sys.exit(1)

    print(f"\n{'='*60}")
    print(f"🏗️  Isometric Terrain Tile Generator")
    print(f"Model: {MODEL}")
    print(f"Tiles: {len(TERRAINS)} terrain types × 8 variants = {len(TERRAINS)*8} base tiles")
    print(f"Transitions: {len(TRANSITION_PAIRS)} pairs × 12 tiles = {len(TRANSITION_PAIRS)*12} transition tiles")
    print(f"Estimated cost: ${len(TERRAINS)*0.03:.2f}")
    print(f"{'='*60}\n")

    # Phase 1
    tilesheet_paths = generate_all_tilesheets()
    if not any(tilesheet_paths.values()):
        print("❌ No tilesheets generated. Aborting.")
        sys.exit(1)

    # Phase 2 + 3
    terrain_dirs = process_all(tilesheet_paths)

    # Phase 4
    tres_path = generate_terrain_tres(terrain_dirs)

    print(f"\n{'='*60}")
    print(f"✅ COMPLETE!")
    print(f"Tilesheets: {TILESHEETS_DIR}/")
    print(f"Tile variants: {TILES_DIR}/")
    print(f"Terrain config: {tres_path}")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
