# Age of Acadia — ID0003

Pipeline de generación de sprites para videojuegos usando ComfyUI + Together AI + FLUX.1.

## Arquitectura

ComfyUI (local) ←→ Together AI API (nube, GPU)

## Cosas a instalar

- Python 3.12 (ya instalado)
- ComfyUI (ya instalado en `comfyui/`)
- custom node `ComfyUI-FLUX-TOGETHER-API` (ya instalado)
- Cuenta en [Together AI](https://together.ai) con saldo
- API key de Together AI

## Setup

1. Crear cuenta en https://together.ai
2. Agregar saldo (mínimo $5)
3. Copiar tu API key
4. Editá el archivo:
   `comfyui/custom_nodes/ComfyUI-FLUX-TOGETHER-API/config.ini`
   Reemplazá `tu_api_key_de_together_aqui` con tu API key

## Uso

### Opción 1 — ComfyUI (visual)
```bash
./scripts/run_comfyui.sh
```
Abrí http://localhost:8188 en el navegador.
Buscá los nodos "Flux Dev (TOGETHER)" o "Flux Pro (TOGETHER)" en el menú derecho.

### Opción 2 — Script Python (batch automation)
```bash
source venv/bin/activate
python scripts/generate_sprites.py \
  --character "mage" \
  --prompt "wizard with blue robes and staff, medieval fantasy" \
  --spritesheet
```

## Modelos disponibles

| Nombre | Costo | Calidad |
|--------|-------|---------|
| FLUX.1-schnell-Free | $0.0027/img | Buena, 4 pasos |
| FLUX.1-pro | $0.04/img | Excelente |
| FLUX.1.1-pro | $0.04/img | Excelente |

## Costo estimado para Age of Acadia

| Concepto | Imágenes | Schnell | Dev/Pro |
|----------|----------|---------|---------|
| Personajes (6 × 40 sprites) | 240 | $0.65 | $9.60 |
| Enemigos (10 × 16 sprites) | 160 | $0.43 | $6.40 |
| Props/tiles | 100 | $0.27 | $4.00 |
| **Total** | **~500** | **~$1.35** | **~$20** |

## Estructura del proyecto

```
ID0003_AgeOfAcadia/
├── comfyui/           # ComfyUI instalado
├── workflows/         # Workflows .json de ComfyUI
├── sprites/           # Sprites generados
├── scripts/           # Scripts de automation
│   ├── run_comfyui.sh       # Iniciar ComfyUI
│   └── generate_sprites.py  # Batch generation
├── docs/              # Documentación adicional
├── screenshots/       # Capturas del proceso
├── venv/              # Entorno virtual Python
└── README.md
```
