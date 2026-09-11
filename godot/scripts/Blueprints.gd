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

var _por_zona: Dictionary = {}  # String (zona_permitida) -> Dictionary (blueprint)


func guardar(blueprint: Dictionary) -> void:
	_por_zona[blueprint["zona_permitida"]] = blueprint


func obtener(zona_permitida: String) -> Dictionary:
	return _por_zona.get(zona_permitida, {})
