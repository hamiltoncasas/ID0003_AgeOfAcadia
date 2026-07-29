class_name Arrow extends Area2D
## Proyectil de flecha isométrica — vuela en línea recta sobre el suelo
## con un arco de altura VISUAL que simula profundidad 3D.
##
## Estilo Age of Empires: la posición en el plano del suelo avanza
## linealmente, y la altura (offset visual en Y) sigue una parábola.
## La Y de pantalla NO es gravedad — el movimiento en el suelo no se
## curva, la altura es un efecto visual aparte.

## Velocidad horizontal sobre el suelo (px/s).
@export var speed: float = 400.0
## Altura máxima del arco en píxeles (offset visual en pantalla).
## Un valor de 25 = la flecha sube 25px sobre su posición de suelo.
@export var arc_height: float = 28.0
## Distancia máxima de vuelo (para disparo direccional sin objetivo).
@export var max_distance: float = 1000.0

## Vector de movimiento sobre el plano del suelo (NUNCA se acelera en Y).
## Lo setea UnitController para disparo direccional.
var velocity: Vector2 = Vector2.RIGHT * speed
## Posición objetivo (opcional). Si se setea, la flecha vuela hacia ahí.
var target_pos: Vector2 = Vector2.INF

var _start_pos: Vector2         # posición de lanzamiento
var _ground_pos: Vector2        # posición actual en el suelo
var _flight_progress: float = 0.0  # 0.0 → 1.0
var _total_distance: float = 0.0
var _flight_time: float = 0.0
var _elapsed: float = 0.0
var _use_procedural: bool = false

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_start_pos = global_position
	_ground_pos = _start_pos
	
	if target_pos != Vector2.INF:
		# Disparo dirigido: calcular velocidad hacia el objetivo
		var diff: Vector2 = target_pos - _start_pos
		_total_distance = diff.length()
		if _total_distance > 1.0:
			velocity = diff.normalized() * speed
		else:
			velocity = Vector2(sign(diff.x) * speed if abs(diff.x) > 0.0 else 0.0, \
				sign(diff.y) * speed if abs(diff.y) > 0.0 else 0.0)
	else:
		# Disparo direccional: usar la distancia máxima
		_total_distance = max_distance
	
	# Tiempo total de vuelo
	_flight_time = _total_distance / speed if speed > 0.0 else 1.0
	_flight_time = max(_flight_time, 0.016)  # mínimo 1 frame
	
	# Rotación inicial: dirección del movimiento en el suelo
	rotation = velocity.angle()
	
	# Cargar textura
	var tex_path := "res://sprites/entorno/flecha/base/flecha_sin.png"
	var tex: Texture2D = load(tex_path)
	if tex:
		_sprite.texture = tex
		_sprite.visible = true
	else:
		_use_procedural = true
		_sprite.visible = false
		queue_redraw()
	
	get_tree().create_timer(3.0).timeout.connect(queue_free)


func _draw() -> void:
	if not _use_procedural:
		return
	
	# Fallback procedural (solo si la textura no cargó)
	draw_line(Vector2(-8, 0), Vector2(8, 0), Color(0.65, 0.4, 0.15), 2.0)
	draw_colored_polygon(
		PackedVector2Array([Vector2(8, 0), Vector2(14, 0), Vector2(8, -2.5)]),
		Color(0.7, 0.7, 0.75)
	)
	draw_colored_polygon(
		PackedVector2Array([Vector2(8, 0), Vector2(14, 0), Vector2(8, 2.5)]),
		Color(0.7, 0.7, 0.75)
	)
	draw_colored_polygon(
		PackedVector2Array([Vector2(-8, 0), Vector2(-13, -3), Vector2(-5, -1)]),
		Color(0.8, 0.18, 0.12)
	)
	draw_colored_polygon(
		PackedVector2Array([Vector2(-8, 0), Vector2(-13, 3), Vector2(-5, 1)]),
		Color(0.8, 0.18, 0.12)
	)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_flight_progress = min(_elapsed / _flight_time, 1.0)
	var t: float = _flight_progress
	
	# Posición en el suelo: avance lineal desde el inicio
	_ground_pos = _start_pos + velocity * _elapsed
	
	# Altura del arco: parábola que va 0 → max → 0
	# Fórmula: 4 * H * t * (1 - t) → pico en t=0.5
	var height: float = 4.0 * arc_height * t * (1.0 - t)
	
	# Posición final en pantalla: suelo + altura visual
	# En isométrico, mayor altura = más arriba en pantalla (menor Y)
	global_position = _ground_pos + Vector2(0, -height)
	
	# Rotación: dirección del movimiento en el suelo + inclinación por altura
	# La inclinación sigue la velocidad vertical del arco
	var ground_angle: float = velocity.angle()
	var height_velocity: float = 4.0 * arc_height * (1.0 - 2.0 * t) / _flight_time
	var pitch_angle: float = atan(height_velocity / speed) if speed > 0.0 else 0.0
	rotation = ground_angle - pitch_angle  # negativa = inclinar arriba cuando sube
	
	# Fin del vuelo
	if _flight_progress >= 1.0:
		queue_free()
