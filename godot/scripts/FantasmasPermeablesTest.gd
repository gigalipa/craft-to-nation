extends Node

## Pruebas de los fantasmas de obra permeables hacia afuera: CuerposObra (con
## física real: un CharacterBody3D contra el cuerpo de la obra) y, desde la
## Tarea 3, los permisos y la puerta de inicio de obra de VoxelWorld. Esta
## escena espera fotogramas de física, así que se ejecuta con
## --quit-after 3000 y termina sola con get_tree().quit().

const CuerposObra = preload("res://scripts/CuerposObra.gd")
const VoxelWorld = preload("res://scripts/VoxelWorld.gd")


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

	print("\n=== TEST 3: el ítem fantasma de la MeshLibrary ya no lleva colisión ===")
	var mundo3 := _mundo()
	assert(mundo3.mesh_library.get_item_shapes(mundo3._id_por_tipo["fantasma"]).is_empty(), "la colisión la dan los cuerpos por obra")

	print("\n=== TEST 4: cada obra tiene un cuerpo con una caja por fantasma pendiente ===")
	var mundo4 := _mundo()
	var c1 := Vector3i(10, 1, 10)
	var c2 := Vector3i(11, 1, 10)
	var id4: int = mundo4.iniciar_construccion_fantasma([], {}, [c1, c2], {c1: "pared", c2: "pared"})
	assert(mundo4.cuerpos_obra().cantidad_formas(id4) == 2)
	assert(mundo4.cuerpo_de_obra(id4) != null)
	mundo4.surtir_construccion(c1)  # convierte la primera celda pendiente (c1) en pared
	assert(mundo4.cuerpos_obra().cantidad_formas(id4) == 1, "un fantasma menos, una caja menos")
	mundo4.surtir_construccion(c1)  # convierte c2: la obra queda completa
	assert(mundo4.cuerpo_de_obra(id4) == null, "sin fantasmas pendientes, el cuerpo se libera")

	print("\n=== TEST 5: el volumen de la obra es la caja envolvente de sus celdas ===")
	var mundo5 := _mundo()
	var id5: int = mundo5.iniciar_construccion_fantasma([], {}, [c1, c2], {c1: "pared", c2: "pared"})
	assert(mundo5.volumen_de_obra(id5) == {"min": Vector3i(10, 1, 10), "max": Vector3i(11, 1, 10)})
	assert(mundo5.celda_en_volumen(id5, Vector3i(10, 1, 10)) and mundo5.celda_en_volumen(id5, Vector3i(11, 1, 10)))
	assert(not mundo5.celda_en_volumen(id5, Vector3i(12, 1, 10)) and not mundo5.celda_en_volumen(id5, Vector3i(10, 2, 10)))
	assert(not mundo5.celda_en_volumen(999, c1), "una obra que no existe no tiene volumen")

	print("\n=== TEST 6: los permisos de salida bloquean el inicio de la obra hasta que se revocan ===")
	var mundo6 := _mundo()
	var id6: int = mundo6.iniciar_construccion_fantasma([], {}, [c1, c2], {c1: "pared", c2: "pared"})
	assert(not mundo6.hay_ocupantes(id6))
	mundo6.otorgar_permiso_salida(id6, 42)
	mundo6.otorgar_permiso_salida(id6, "avatar")
	assert(mundo6.tiene_permiso_salida(id6, 42) and mundo6.hay_ocupantes(id6))
	assert(mundo6.obras_con_permiso("avatar") == [id6] and mundo6.obras_con_permiso(7).is_empty())
	var rechazo: Dictionary = mundo6.surtir_construccion(c1)
	assert(rechazo.get("bloqueada", false), "con alguien dentro no se puede iniciar")
	assert(mundo6.obtener_tipo(c1) == "fantasma", "y no cambia nada")
	mundo6.revocar_permiso_salida(id6, 42)
	assert(mundo6.hay_ocupantes(id6), "aún queda el avatar")
	mundo6.revocar_permiso_salida(id6, "avatar")
	assert(not mundo6.hay_ocupantes(id6))
	var avance: Dictionary = mundo6.surtir_construccion(c1)
	assert(not avance.has("bloqueada") and mundo6.obtener_tipo(c1) == "pared", "sin ocupantes, la obra avanza")

	print("\n=== TEST 7: obra_a_fantasma se emite al emplazar y al empezar a deconstruir un edificio completo ===")
	var mundo7 := _mundo()
	var emitidas: Array[int] = []
	mundo7.obra_a_fantasma.connect(func(id: int) -> void: emitidas.append(id))
	var id7: int = mundo7.iniciar_construccion_fantasma([], {}, [c1, c2], {c1: "pared", c2: "pared"})
	assert(emitidas == [id7], "al emplazar")
	mundo7.surtir_construccion(c1)
	mundo7.surtir_construccion(c1)  # completa
	assert(emitidas == [id7], "completar no lo emite")
	mundo7.procesar_deconstruccion(c1)  # primer paso con el edificio entero: c2 vuelve a fantasma
	assert(emitidas == [id7, id7], "al empezar a deconstruir un edificio completo")
	assert(mundo7.cuerpos_obra().cantidad_formas(id7) == 1, "el fantasma revertido tiene su caja")
	mundo7.procesar_deconstruccion(c1)  # segundo paso: el edificio ya no estaba entero
	assert(emitidas == [id7, id7], "solo se emite una vez por deconstrucción")

	print("\n=== TEST 8: eliminar el edificio libera su cuerpo, su volumen y sus permisos ===")
	var mundo8 := _mundo()
	var id8: int = mundo8.iniciar_construccion_fantasma([], {}, [c1], {c1: "pared"})
	mundo8.otorgar_permiso_salida(id8, 42)
	mundo8.procesar_deconstruccion(c1)  # sin nada construido: lista para remoción
	mundo8.eliminar_edificio(id8)
	assert(mundo8.cuerpo_de_obra(id8) == null)
	assert(mundo8.volumen_de_obra(id8).is_empty() and not mundo8.hay_ocupantes(id8))

	print("\n=== Las 8 pruebas de fantasmas permeables pasaron correctamente ===")


func _mundo() -> Node:
	var mundo: Node = VoxelWorld.new()
	mundo.mesh_library = load("res://assets/BlockLibrary.res")
	mundo.cell_size = Vector3.ONE
	mundo._indexar_biblioteca()
	return mundo
