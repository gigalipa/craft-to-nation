extends Node3D

## Tinte rojo translúcido sobre los edificios marcados para demolición (ver Obras.gd): una caja
## por celda del edificio, reconstruida entera cada vez que cambia una marca (hay pocos edificios
## marcados). Mismo patrón que ZonaOverlay.gd y NivelacionOverlay.gd; no toca el mundo.

const COLOR := Color(1.0, 0.15, 0.15, 0.35)
const COLOR_DEMOLICION := Color(1.0, 0.15, 0.15, 0.35)
const COLOR_PROGRAMADA := Color(1.0, 0.6, 0.1, 0.35)
const DESF := 0.5  # una celda ocupa [celda, celda+1]: su centro está en celda + DESF
const PRIORIDAD := 3

## Quién dice qué edificios están marcados (Obras en el juego) y de qué celdas se compone cada uno.
var obras: Object = null:
	set(valor):
		if obras != null and obras.marca_cambiada.is_connected(_on_marca_cambiada):
			obras.marca_cambiada.disconnect(_on_marca_cambiada)
		obras = valor
		if obras != null:
			obras.marca_cambiada.connect(_on_marca_cambiada)

var _malla: BoxMesh
var _material_demolicion: StandardMaterial3D
var _material_programada: StandardMaterial3D


func _init() -> void:
	_malla = BoxMesh.new()
	_malla.size = Vector3.ONE * 1.02  # un pelo más grande: evita el z-fighting con las caras del edificio
	_material_demolicion = StandardMaterial3D.new()
	_material_demolicion.albedo_color = COLOR_DEMOLICION
	_material_demolicion.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material_demolicion.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material_demolicion.render_priority = PRIORIDAD

	_material_programada = StandardMaterial3D.new()
	_material_programada.albedo_color = COLOR_PROGRAMADA
	_material_programada.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material_programada.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material_programada.render_priority = PRIORIDAD


func _on_marca_cambiada(_id: int, _marcado: bool) -> void:
	reconstruir()


func reconstruir() -> void:
	for hijo in get_children():
		hijo.queue_free()
		remove_child(hijo)
	if obras == null:
		return
	for id: int in obras.marcados:
		for celda: Vector3i in obras.celdas_de(id):
			var caja := MeshInstance3D.new()
			caja.mesh = _malla
			caja.material_override = _material_demolicion
			caja.position = Vector3(celda) + Vector3(DESF, DESF, DESF)
			add_child(caja)
	if "demolicion_programada" in obras:
		for id: int in obras.demolicion_programada:
			for celda: Vector3i in obras.celdas_de(id):
				var caja := MeshInstance3D.new()
				caja.mesh = _malla
				caja.material_override = _material_programada
				caja.position = Vector3(celda) + Vector3(DESF, DESF, DESF)
				add_child(caja)
