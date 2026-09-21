extends Node

## Pruebas de los fantasmas de obra permeables hacia afuera: CuerposObra (con
## física real: un CharacterBody3D contra el cuerpo de la obra) y, desde la
## Tarea 3, los permisos y la puerta de inicio de obra de VoxelWorld. Esta
## escena espera fotogramas de física, así que se ejecuta con
## --quit-after 3000 y termina sola con get_tree().quit().

const CuerposObra = preload("res://scripts/CuerposObra.gd")


func _ready() -> void:
	await ejecutar_pruebas()
	get_tree().quit()


func ejecutar_pruebas() -> void:
	print("=== TEST 1: sincronizar() deja una caja por celda distinta y libera al quedar vacío ===")
	var cuerpos := CuerposObra.new()
	add_child(cuerpos)
	cuerpos.sincronizar(1, [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(1, 0, 0)])  # repetida: cuenta una vez
	assert(cuerpos.cantidad_formas(1) == 2)
	assert(cuerpos.cuerpo_de(1) != null)
	cuerpos.sincronizar(1, [Vector3i(1, 0, 0)])
	assert(cuerpos.cantidad_formas(1) == 1, "quita las cajas de las celdas que ya no son fantasma")
	cuerpos.sincronizar(2, [Vector3i(5, 0, 0)])
	assert(cuerpos.cuerpo_de(1) != cuerpos.cuerpo_de(2), "cada obra tiene su propio cuerpo")
	cuerpos.sincronizar(1, [])
	assert(cuerpos.cuerpo_de(1) == null and cuerpos.cantidad_formas(1) == 0, "sin fantasmas, el cuerpo se libera")
	assert(cuerpos.cuerpo_de(2) != null, "la otra obra no se toca")
	cuerpos.liberar(2)
	assert(cuerpos.cuerpo_de(2) == null)

	print("\n=== TEST 2: un CharacterBody3D choca con el cuerpo de la obra salvo con una excepción ===")
	cuerpos.sincronizar(3, [Vector3i(0, 0, 0)])  # una caja en [0,1]^3
	var jugador := CharacterBody3D.new()
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.4
	capsula.height = 1.8
	forma.shape = capsula
	forma.position = Vector3(0, 0.9, 0)
	jugador.add_child(forma)
	add_child(jugador)
	jugador.global_position = Vector3(3.5, 0.0, 0.5)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var camino := Vector3(-3.0, 0.0, 0.0)  # cruza la caja
	assert(jugador.move_and_collide(camino, true) != null, "sin excepción, choca con el fantasma")
	jugador.add_collision_exception_with(cuerpos.cuerpo_de(3))
	assert(jugador.move_and_collide(camino, true) == null, "con la excepción de esa obra, la atraviesa")
	jugador.remove_collision_exception_with(cuerpos.cuerpo_de(3))
	assert(jugador.move_and_collide(camino, true) != null, "al quitarla, vuelve a chocar")
	cuerpos.sincronizar(4, [Vector3i(0, 0, 0)])  # otra obra, en el mismo sitio
	await get_tree().physics_frame
	await get_tree().physics_frame
	jugador.add_collision_exception_with(cuerpos.cuerpo_de(3))
	assert(jugador.move_and_collide(camino, true) != null, "la excepción de una obra no vale para otra")

	print("\n=== Las 2 pruebas de CuerposObra pasaron correctamente ===")
