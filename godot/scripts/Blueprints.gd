extends Node

## Autoload "Blueprints": registro de blueprints reutilizables, uno por
## zona_permitida (el último declarado de esa zona sobrescribe al
## anterior — sin catálogo ni selección manual todavía, ver spec:
## docs/superpowers/specs/2026-09-10-blueprints-construccion-fantasma-design.md).
## Mismo patrón que Recoleccion.gd/Zonificacion.gd: estado puro, sin nodos
## de escena, sin class_name (evita el bug de caché de clases globales).
##
## Todo blueprint pasado a guardar() que vaya a usarse para colocación (vía
## CamaraCenital.gd) debe incluir el campo "huella_relativa": Array[Vector2i]
## (lo produce BlueprintValidator.estructura_a_blueprint()) — un blueprint
## armado a mano sin esta clave falla con "Invalid access to key" al
## intentar colocar una copia.

const MAX_RESIDENCIALES := 5

var _por_zona: Dictionary = {}  # String (zona_permitida) -> Dictionary (blueprint)
var _residenciales: Array[Dictionary] = []


func guardar(blueprint: Dictionary) -> void:
	var zona: String = str(blueprint.get("zona_permitida", ""))
	_por_zona[zona] = blueprint
	if zona == "residencial_investigacion" or str(blueprint.get("categoria", "")) == "residencial":
		var idx := _residenciales.find(blueprint)
		if idx != -1:
			_residenciales.remove_at(idx)
		_residenciales.push_front(blueprint)
		if _residenciales.size() > MAX_RESIDENCIALES:
			_residenciales.resize(MAX_RESIDENCIALES)


func obtener(zona_permitida: String, indice: int = 0) -> Dictionary:
	if (zona_permitida == "residencial_investigacion" or zona_permitida == "residencial") and not _residenciales.is_empty():
		if indice >= 0 and indice < _residenciales.size():
			return _residenciales[indice]
		return {}
	return _por_zona.get(zona_permitida, {})


func obtener_residencial(indice: int = 0) -> Dictionary:
	if indice >= 0 and indice < _residenciales.size():
		return _residenciales[indice]
	return {}


func cantidad_residenciales() -> int:
	return _residenciales.size()


func todos_residenciales() -> Array:
	return _residenciales.duplicate()


func limpiar() -> void:
	_por_zona.clear()
	_residenciales.clear()
