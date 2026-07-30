# Age of Acadia — Development Log

> **Estado actual**: Prototipo jugable con mapa procedural isométrico, personaje seleccionable con control RTS, pathfinding A* y 3 biomas.
>
> **Stack**: Godot 4.7.1 (GDScript), Python 3.12 (scripts de generación), Together AI / FLUX.2 pro (sprites)

---

## Índice

1. [Arquitectura General](#1-arquitectura-general)
2. [Sistema de Terreno](#2-sistema-de-terreno)
3. [Sistema de Navegación](#3-sistema-de-navegación)
4. [Sistema de Unidades](#4-sistema-de-unidades)
5. [Controles](#5-controles)
6. [Sistema de Objetos](#6-sistema-de-objetos)
7. [Interfaz de Usuario](#7-interfaz-de-usuario)
8. [Asset Pipeline](#8-asset-pipeline)
9. [SDD Changes](#9-sdd-changes)
10. [Cómo Probar](#10-cómo-probar)

---

## 1. Arquitectura General

### Escenas y Flujo

```
Menu.tscn ──"Start Game"──► terrain_only.tscn
                                │
                                ├─ Root (Node2D)
                                │   ├─ CameraController (Camera2D + gd)
                                │   └─ Terrain (Node2D + Llanura1.gd)
                                │       ├─ TileMapLayer (terreno)
                                │       ├─ Contours (Node2D)
                                │       ├─ HeightOverlay (Node2D)
                                │       ├─ EnvironmentObjects (Node2D)
                                │       ├─ PlayerUnit (CharacterBody2D)
                                │       └─ GameUI (CanvasLayer)
```

### Archivos Clave

| Archivo | Rol |
|---------|-----|
| `game/map/Llanura1.gd` | Orquestador principal — genera terreno, objetos, personaje, UI |
| `game/map/ProceduralGeneration.gd` | Generación procedural de terreno, ríos, elevación |
| `game/map/NavigationSystem.gd` | Pathfinding A* sobre grid de biomas |
| `game/map/ObjectPlacer.gd` | Colocación procedural de objetos decorativos |
| `game/map/CameraController.gd` | Cámara con drag, zoom, follow, scroll |
| `game/scripts/UnitController.gd` | Personaje jugador con state machine y RTS |
| `game/map/GameUI.gd` | Minimapa, panel de acciones, overlay de coordenadas |
| `game/scripts/SpriteCache.gd` | Caché de texturas (autoload) |
| `game/scripts/UnitSprites.gd` | Constructor de SpriteFrames desde manifiestos JSON |
| `game/scripts/Arrow.gd` | Proyectil con arco balístico |

### Autoloads

```gdscript
# project.godot
SpriteCache="*res://scripts/SpriteCache.gd"
```

---

## 2. Sistema de Terreno

### Generación Procedural

El terreno se genera en `ProceduralGeneration.gd` con 3 capas de ruido Perlin:

| Noise | Frecuencia | Octavas | Propósito |
|-------|-----------|---------|-----------|
| height_noise | 0.015 | 3 | Forma base del valle |
| detail_noise | 0.04 | 2 | Detalle fino de biomas |
| moisture_noise | 0.025 | 2 | Humedad (desierto vs llano) |

**Valley bias**: las orillas del mapa son +0.3 más altas que el centro, creando un valle natural donde el agua se acumula en el centro.

### 3 Biomas

| Bioma | Source ID | Strip | Threshold |
|-------|-----------|-------|-----------|
| **Agua profunda** | 6 | deep_water.png | hval < -0.15 |
| **Agua somera** | 5 | shallow_water.png | hval < 0.0 |
| **Orilla/Playa** | 0 | grass.png (plain) | hval < 0.06 |
| **Desierto** | 2 | sand.png | moist < -0.2 y hval < 0.4 |
| **Llanura** | 0 | grass.png | todo lo demás |

### Elevación

- 8 niveles suaves (0-7) mapeados desde el noise de altura
- Overlay con gradiente circular: verde oscuro (bajo) → dorado (alto)
- Contornos solo en cambios ≥ 3 niveles (acantilados)

### Ríos

- Pathfinding con ruido Perlin desde un borde a otro
- Ancho variable (radio 1-3 celdas)
- Usan tiles de shallow_water

### Tile Variants

Cada strip tiene 8 variantes de tile seleccionadas por hash de posición:
```gdscript
var variant = (x * 7 + y * 13 + sid * 31) % 8
```

---

## 3. Sistema de Navegación

### NavigationSystem.gd

Pathfinding A* sobre el grid de biomas (300×300 celdas):

- **Walkable**: biome != 0 (desierto y llanura)
- **Obstáculos**: agua (bioma 0)
- **Conexiones**: 8 direcciones (incluyendo diagonales)
- **Búsqueda de destino**: si el destino está en agua, busca la celda caminable más cercana (búsqueda en espiral hasta radio 20)

### Integración con UnitController

1. Click derecho → `_move_to(target)`
2. Construye NavigationSystem lazy (una vez, con biome_data)
3. `find_path(from, to)` devuelve Array de waypoints en coordenadas world
4. `_physics_process` sigue waypoints uno por uno
5. `_advance_path()` avanza al siguiente waypoint al llegar
6. Si encuentra agua, salta al siguiente waypoint

```gdscript
# Ejemplo de path
_path = _nav.find_path(global_position, target)
_path_index = 1  # saltar posición actual
_move_target = _path[_path_index]
```

---

## 4. Sistema de Unidades

### UnitController.gd (CharacterBody2D)

**State Machine**:

```
IDLE ──► WALK ──► ATTACK ──► IDLE
  │         │        │
  │         └──► HURT ──► IDLE
  │                │
  └──────────► DEATH (terminal, revive con E)
```

**Health System**:
- `health` / `max_health` (100/100)
- Barra de vida visual sobre el personaje
- `get_health()` / `get_max_health()` para UI

**Selection**:
- `_selected: bool` — toggle con click izquierdo
- `_selection_ring` — aro verde alrededor del personaje
- `is_selected()` — consulta para GameUI

**Movement Pointer** (AoE2 style):
- Aro dorado que aparece en el destino al click derecho
- Se encoge y desvanece en 0.8s vía Tween
- `_spawn_move_pointer(pos)` → `_make_pointer_ring()`

**Attack**:
- Tecla F → dispara flecha hacia la última dirección
- Detiene el movimiento al atacar
- Usa `Arrow.tscn` (Area2D con trayectoria balística)

---

## 5. Controles

### Esquema RTS (Age of Empires 2 style)

| Acción | Control | Implementación |
|--------|---------|----------------|
| **Seleccionar** | Click izquierdo cerca del personaje | UnitController._input() |
| **Mover** | Click derecho en el mapa | UnitController._move_to() → A* pathfinding |
| **Atacar** | Tecla **F** | UnitController.attack() |
| **Daño (test)** | Tecla **H** | UnitController.hurt() |
| **Muerte (test)** | Tecla **R** | UnitController.die() |
| **Revivir** | Tecla **E** | UnitController._revive() |
| **Mover cámara** | Click izquierdo/medio + arrastre | CameraController._unhandled_input |
| **Scroll cámara** | Flechas del teclado | CameraController._process |
| **Zoom** | Rueda del mouse | CameraController._unhandled_input |
| **Minimapa** | Click izquierdo → teleport cámara | GameUI._on_minimap_click |
| **Cancelar follow** | Click en minimapa | CameraController.follow_target = null |

### Input Actions (project.godot)

| Acción | Teclas |
|--------|--------|
| ui_left | A + ← |
| ui_right | D + → |
| ui_up | W + ↑ |
| ui_down | S + ↓ |
| test_attack | F |
| test_hurt | H |
| test_die | R |
| test_revive | E |
| zoom_in | = |
| zoom_out | - |

---

## 6. Sistema de Objetos

### ObjectPlacer.gd

Coloca objetos decorativos (árboles, rocas, cactus, flores) según el bioma:

| Bioma | Objetos | Densidad |
|-------|---------|----------|
| Agua (0) | ❌ Ninguno | 0% |
| Desierto (1) | cactus, palmeras, rocas | 0.8-1.5% |
| Llanura (2) | robles, pinos, flores, arbustos | 2.5-5% |

**Características**:
- Sprites con sombras elípticas procedurales
- Collision shapes (StaticBody2D)
- Escala variable: árboles 2.5×, rocas 2×, flores 1×
- Jitter de posición (±8px, ±4px)
- Ground cover: flores/hongos sin colisión en llanura
- No-duplicate guard por celda
- Mínimo espaciado de 1 celda entre objetos

### Llamado desde Llanura1.gd

```gdscript
var object_container = Node2D.new()
object_container.name = "EnvironmentObjects"
object_container.y_sort_enabled = true

var placer = ObjectPlacer.new()
placer.place_objects(_biome_map, _elev_map, rng, object_container)
add_child(object_container)
```

---

## 7. Interfaz de Usuario

### GameUI.gd (CanvasLayer, layer=100)

**Minimapa** (esquina inferior derecha):
- 160×160 pixels, muestra biomas coloreados
- Agua = azul, Desierto = beige, Llanura = verde
- Marcador dorado del jugador (se actualiza cada frame)
- Click izquierdo → teleporta cámara (+ cancela follow)

**Panel de Acciones** (abajo-centro, visible al seleccionar):
- Título "ARCHER"
- Barra de vida (verde/amarillo/rojo) con texto "HP/MAX"
- Botones: ⚔ Attack, ✋ Stop, 🏹 Fire

**Overlay de coordenadas** (abajo):
- Muestra celda y elevación bajo el mouse
- Formato: "Cell (x,y) Elevation: N"

### Actualización en _process

```gdscript
func _process(_delta):
    # Redimensionar bordes al cambiar ventana
    # Reposicionar minimapa + click area
    # Actualizar marcador del jugador
    # Actualizar panel de acciones (vida, visibilidad)
```

---

## 8. Asset Pipeline

### Sprites de Personajes

Los sprites se generan con Together AI / FLUX.2 pro y se organizan como strips horizontales:

```
sprites/infanteria/arquero/
├── arquero_manifest.json      # Metadatos: frames, direcciones, animaciones
├── arquero_idle_front.png     # Strip: 128×128, 2 frames
├── arquero_idle_profile.png   # Strip: 128×128, 1 frame
├── arquero_walk_front.png     # etc.
├── arquero_attack_front.png
└── ...
```

25 strips por personaje (5 animaciones × 5 direcciones).

### Sprites de Terreno

Generados con FLUX.2 pro, 11 tilesheets a $0.03 c/u:

```
sprites/terrain/strips/
├── grass.png          # 1024×64, 8 tiles de 128×64
├── dirt.png
├── sand.png
├── shallow_water.png
├── deep_water.png
└── ...
```

### Procesamiento

`UnitSprites.gd` lee el manifiesto JSON y construye `SpriteFrames` con `AtlasTexture` slices de cada strip.

---

## 9. SDD Changes

### Change: terrain-playable (ACTIVO)

Integración de objetos, personaje y cámara en el mapa procedural.

**Archivos SDD**: `openspec/changes/terrain-playable/`

| Fase | Archivo | Estado |
|------|---------|--------|
| Propuesta | proposal.md | ✅ |
| Specs | spec.md | ✅ |
| Diseño | design.md | ✅ |
| Tareas | tasks.md | ✅ |
| Apply | — | ✅ Implementado |
| Verify | — | Pendiente |

### Historial de Changes Archivados

- `sprite-to-godot-pipeline` — Pipeline de sprites desde Together AI a Godot
- `crear-pasto` — Mejora de texturas de pasto
- `Llanura1` — Mapa procedural 120×120 (reemplazado por terrain-playable)

---

## 10. Cómo Probar

1. Abrí Godot 4.7.1 y cargá `game/project.godot`
2. Ejecutá (F5) — debería mostrar el menú principal
3. Click "Start Game" → se genera el valle procedural
4. Click izquierdo cerca del arquero → aro verde de selección
5. Click derecho en el mapa → el arquero camina (rodea agua)
6. Click en el minimapa → la cámara se mueve
7. Arrastrar con click izquierdo/medio → mueve la cámara
8. Rueda del mouse → zoom
9. Tecla F → dispara flecha

### Controles de Test

| Tecla | Acción |
|-------|--------|
| H | Daño al arquero (baja la vida) |
| R | Muerte |
| E | Revivir |
| F | Atacar (disparar flecha) |

---

## Próximos Pasos (Roadmap)

- [ ] Click-to-move con selección de múltiples unidades
- [ ] UI de recursos (comida, oro, madera)
- [ ] Edificios colocables
- [ ] IA enemiga básica
- [ ] Cámara que sigue automáticamente al personaje
- [ ] Sonidos y música
- [ ] Pantalla de carga mientras se genera el terreno
- [ ] Guardar/ Cargar partida
