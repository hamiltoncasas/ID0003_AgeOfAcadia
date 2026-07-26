# Manual de Sprites — Age of Acadia

> Pipeline de generación de sprites para un juego RTS isométrico estilo Age of Empires 2.
> Basado en FLUX.1-schnell vía Together AI.

---

## Pipeline de generación

### Script principal

```bash
source venv/bin/activate
python scripts/generate_sprites.py \
  --character "nombre_unidad" \
  --prompt "descripción del sprite" \
  --width 512 \
  --height 512 \
  --steps 4 \
  --seed 42 \
  --spritesheet
```

### Generación individual con referencia visual

```python
from together import Together
from PIL import Image
import base64, io

client = Together()

# Cargar imagen de referencia para consistencia
with open("referencia.png", "rb") as f:
    ref = f"data:image/png;base64,{base64.b64encode(f.read()).decode('utf-8')}"

r = client.images.generate(
    model="black-forest-labs/FLUX.1-schnell",
    prompt="pixel art style, game sprite, descripción, ...",
    image_url=ref,  # <-- clave para homogeneidad visual
    width=512, height=512,
    steps=6, n=1,
    response_format="b64_json",
    guidance_scale=3.0,
    seed=555,
)
img = Image.open(io.BytesIO(base64.b64decode(r.data[0].b64_json)))
img.resize((128, 128), Image.LANCZOS).save("sprite_final.png")
```

---

## Post-procesado: remoción de fondo

Todas las imágenes generadas por FLUX traen fondo. Para integrarlas en Godot con transparencia, se procesan con **rembg** (U²-Net).

### Script

```bash
source venv/bin/activate
python scripts/remove_bg.py [-r] <ruta>
```

| Modo | Uso |
|------|-----|
| `python remove_bg.py sprites/entorno/alpaca/alpaca.png` | Imagen individual |
| `python remove_bg.py sprites/base/` | Todo un directorio (plano) |
| `python remove_bg.py -r sprites/` | **Todos** los sprites recursivamente |

### Qué hace

- Toma cualquier `.png` / `.jpg` del árbol
- Aplica U²-Net (modelo entrenado para separar personas, animales, objetos del fondo)
- Guarda `<nombre>_sin.png` en el mismo directorio con canal alfa (RGBA)
- Ignora automáticamente `_gen.png` (originales 4×), `_512.png` (upscales) y `_sin.png` ya existentes

### Ejemplo directo

```python
from rembg import remove
from PIL import Image

img = Image.open("caballero_final.png")
img_sin = remove(img)                # fondo transparente
img_sin.save("caballero_sin.png")
```

### Resultado

Las **222 imágenes** del proyecto se procesaron en un solo pase — 0 errores.

```
sprites/asedio/ariete/
├── ariete_final.png    # Original con fondo
├── ariete_gen.png      # Generación 4× (sin procesar)
├── ariete_sin.png      # ← Fondo removido, listo para Godot
└── prompt.md
```

---

## Escala base

| Elemento | Canvas | Proporción |
|----------|--------|------------|
| **Humano (referencia)** | 128×128 | 1× |
| Figura humana real | ~120px | — |
| Escala | 0.686 px/cm | 175cm reales |

### Derivado de la escala humana

| Categoría | Rango × humano | Ejemplo |
|-----------|---------------|---------|
| Plantas pequeñas | 0.2–0.4× | pasto 64×32, flores 48×32 |
| Animales pequeños | 0.3–0.5× | conejo 48×40, oveja 80×56 |
| Animales medianos | 0.5–0.7× | ciervo 96×80, lobo 112×72 |
| Animales grandes | 0.7–0.9× | león 128×88, oso 128×96 |
| Animales muy grandes | 1.1–1.3× | elefante 176×144 |
| Árboles | 1.4–2.0× | roble 160×208, palmera 128×224 |
| Edificios pequeños | 1.2–1.5× | casa 160×128, molino 176×160 |
| Edificios grandes | 2.0–3.0× | mercado 256×192, centro urbano 320×256 |
| Castillo | ~3× | castillo 368×336 |
| Maravilla | ~3× | maravilla 400×400 |

### Canvas especiales

| Tipo | Canvas | Generación 4× |
|------|--------|---------------|
| Infantería / Petardo | **128×128** | 512×512 |
| Arquero a pie | 128×128 | 512×512 |
| Caballería / Camellos | **184×176** | 736×704 |
| Carro (Ratha) | 208×192 | 800×768 |
| Elefantes | **256×224** | 1024×896 |
| Arietes | 240×160–272×192 | 960×640–1088×768 |
| Mangonel / Onagro | 208×192–240×208 | 832×768–960×832 |
| Trebuchet | 288×256 | 1152×1024 |
| Torre de asedio | 160×320 | 640×1280 |
| Muro (tileable) | **80×144** | 320×576 |
| Terreno (tiles) | 128×64 | 512×256 |

---

## Estructura de carpetas

```
sprites/
├── base/                 # Personajes base (referencia anatómica)
│   ├── base_human_128.png      ← Referencia para infantería
│   ├── base_mounted_v1_final.png ← Referencia para caballería
│   ├── base_human.md
│   └── base_mounted.md
│
├── aldeano/              # Aldeano (economía)
├── milicia/ ... arcabucero/     # 19 unidades de infantería y arqueros
│
├── caballeria/           # 30 unidades montadas
│   ├── caballeria_exploracion/ ... tarkan/
│   └── caballero/               ← Referencia visual para caballería
│
├── asedio/               # 12 máquinas de asedio
│   ├── ariete/ ... torre_asedio/
│
├── edificios/            # 29 edificios
│   ├── casa/                    ← Referencia visual para edificios y entorno
│   ├── centro_urbano/ ... maravilla/
│   └── muro_piedra/             # 3 piezas: muro (tileable) + inicio + fin
│
└── entorno/              # 81+ elementos del mapa
    ├── vegetacion/       # 12 especies de árboles + arbustos, plantas
    │   ├── roble/ pino/ arce/ abedul/ sauce/ cipres/ cerezo/
    │   ├── arbol_muerto/ pino_nieve/ palmera/ bambu/ manglar/
    │   └── arbustos/ pasto/ flores/ hongos/ cactus/ juncos/
    │
    ├── recursos_minerales/      # Oro, piedra, reliquias, ostras, ballenas
    ├── animales_terrestres/     # 23 especies (oveja a elefante)
    ├── depredadores/            # 10 especies (lobo a cocodrilo)
    ├── peces_vida_marina/       # 9 especies (perca a marlín)
    ├── aves_decorativas/        # 11 especies (gaviota a pavo real)
    ├── objetos_carretas/        # Carros, barriles, cajones, sacos
    ├── ruinas_decoracion/       # Estatuas, columnas, fogatas, puentes
    ├── terreno_obstaculos/      # Agua, hielo, nieve, arena, lava, caminos
    └── recursos_recolectables/  # Versiones recurso de árboles, peces, etc.
```

Cada subcarpeta contiene:
- `prompt.md` — prompt detallado del sprite
- `*.png` / `*_final.png` / `*_128.png` — sprite final (escala juego)
- `*_gen.png` — generación original 4× (opcional)
- `*_sin.png` — sprite sin fondo, listo para Godot (generado por `remove_bg.py`)

---

## Muros tileables para Godot

`edificios/muro_piedra/` contiene 3 piezas que encajan:

```
[INICIO] [MEDIO] [MEDIO] [MEDIO] [FINAL]
```

| Pieza | Archivo | Función |
|-------|---------|---------|
| Inicio | `muro_inicial.png` 80×144 | Borde izquierdo cerrado |
| Medio | `muro_piedra.png` 80×144 | Se repite (tileable) |
| Final | `muro_final.png` 80×144 | Borde derecho cerrado |

```gdscript
# Godot TileSet
# Crear 3 tiles de 80×144 en el TileSet
var tile_inicio = preload("res://sprites/edificios/muro_piedra/muro_inicial.png")
var tile_medio  = preload("res://sprites/edificios/muro_piedra/muro_piedra.png")
var tile_final  = preload("res://sprites/edificios/muro_piedra/muro_final.png")
```

---

## Parámetros de generación

| Parámetro | Schnell (rápido) | Pro (calidad) |
|-----------|-----------------|---------------|
| Modelo | `black-forest-labs/FLUX.1-schnell` | `black-forest-labs/FLUX.1-pro` |
| Steps | 4 (pruebas) / 6 (calidad) | 20–25 |
| Costo/img | ~$0.0027 | ~$0.04 |
| Guidance | 3.0 | 3.0 |
| Seed | Fijo para consistencia (42, 555) | — |

### Seeds recomendadas

| Seed | Uso |
|------|-----|
| **42** | Infantería, arqueros, edificios, asedio |
| **555** | Caballería, entorno, vegetación, animales |

---

## Modelos disponibles (Together AI)

| Modelo | Uso |
|--------|-----|
| `black-forest-labs/FLUX.1-schnell` | Generación principal (rápido, económico) |
| `black-forest-labs/FLUX.1-pro` | Calidad superior (más lento, más caro) |
| `black-forest-labs/FLUX.1-redux` | Imagen a imagen (si está disponible) |

### Parámetros adicionales del SDK

| Parámetro | Función |
|-----------|---------|
| `image_url` | Imagen de referencia para consistencia visual |
| `reference_images` | Array de imágenes de referencia alternativa |
| `seed` | Fijo para reproducibilidad entre generaciones |
| `guidance_scale` | Qué tanto sigue el prompt (3.0 recomendado) |

---

## Costos estimados por lote

| Lote | Cantidad | Schnell | Pro |
|------|----------|---------|-----|
| Infantería (1 personaje, spritesheet) | 58 imgs | ~$0.16 | ~$2.32 |
| Edificios (29) | 29 imgs | ~$0.08 | ~$1.16 |
| Entorno (81) | 81 imgs | ~$0.22 | ~$3.24 |
| Caballería (30) | 30 imgs | ~$0.08 | ~$1.20 |
| **Total proyecto** | **~200** | **~$0.54** | **~$8.00** |
