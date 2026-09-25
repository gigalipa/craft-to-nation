extends Node

## Pruebas aisladas de la señal VoxelWorld.puerta_cambiada y de Puertas.gd
## (mismo patrón que TranslucidosRendererTest.gd). Corre esta escena
## (PuertasTest.tscn) y revisa el panel "Output": debe imprimir todas las
## pruebas y no lanzar ningún error de assert().
## Ver docs/superpowers/specs/2026-09-25-puertas-interactivas-design.md.

const VoxelWorld = preload("res://scripts/VoxelWorld.gd")
const PuertasScript = preload("res://scripts/Puertas.gd")
const LAMINA := Vector3(1, 2, 0.1)


func _ready() -> void:
	ejecutar_pruebas()


func _mundo() -> Node:
	var mundo: Node = VoxelWorld.new()
	mundo.mesh_library = load("res://assets/BlockLibrary.res")
	mundo.cell_size = Vector3.ONE * 1.0
	mundo._indexar_biblioteca()
	return mundo


## Mundo + Puertas conectados como en Main.tscn (VoxelWorld._ready() no corre
## fuera del árbol, así que el cableado se repite a mano).
func _mundo_con_puertas() -> Array:
	var mundo: Node = _mundo()
	var puertas: Node3D = PuertasScript.new()
	puertas.voxel_world = mundo
	mundo.puertas = puertas
	mundo.puerta_cambiada.connect(puertas._on_puerta_cambiada)
	return [mundo, puertas]


func _liberar(par: Array) -> void:
	par[1].free()
	par[0].free()


func ejecutar_pruebas() -> void:
	print("=== TEST 1: puerta_cambiada se emite solo para celdas de puerta ===")
	var mundo: Node = _mundo()
	var emitidas: Array[Vector3i] = []
	mundo.puerta_cambiada.connect(func(celda: Vector3i) -> void:
		emitidas.append(celda)
	)
	var base := Vector3i(0, 0, 0)
	var arriba := Vector3i(0, 1, 0)

	# Una pared no emite.
	mundo.colocar_bloque(Vector3i(5, 0, 0), "pared", true)
	assert(emitidas.is_empty(), "colocar una pared no debe emitir puerta_cambiada")

	# colocar_puerta(): emite las dos celdas, inferior primero.
	assert(mundo.colocar_puerta(base))
	assert(emitidas == [base, arriba], "colocar_puerta() debe emitir base y luego arriba, salió %s" % [emitidas])

	# Minar una de las dos celdas retira las dos y emite las dos.
	emitidas.clear()
	assert(mundo.minar_bloque(base))
	assert(emitidas.has(base) and emitidas.has(arriba), "minar una puerta debe emitir ambas celdas, salió %s" % [emitidas])

	# _revertir_celda(): la celda pasa a fantasma y emite.
	assert(mundo.colocar_puerta(base))
	emitidas.clear()
	mundo._revertir_celda(base)
	assert(emitidas == [base], "revertir a fantasma una celda de puerta debe emitirla, salió %s" % [emitidas])

	# Las celdas de puerta ya no dibujan ni colisionan por GridMap.
	var id_puerta: int = mundo.id_de_tipo("puerta_inferior")
	assert(mundo.mesh_library.get_item_mesh(id_puerta) == null, "el ítem de puerta no debe tener malla")
	assert(mundo.mesh_library.get_item_shapes(id_puerta).is_empty(), "el ítem de puerta no debe tener formas")

	print("OK: puerta_cambiada() se emite exactamente cuando una celda de puerta entra o sale.")
	mundo.free()

	print("=== TEST 2: registro, orientación, lámina y colisión de una puerta cerrada ===")
	var par: Array = _mundo_con_puertas()
	var m: Node = par[0]
	var p: Node3D = par[1]
	# Pared que corre por X: paredes en (base ± X).
	var b_x := Vector3i(10, 5, 10)
	m.colocar_bloque(b_x + Vector3i(-1, 0, 0), "pared", true)
	m.colocar_bloque(b_x + Vector3i(1, 0, 0), "pared", true)
	assert(m.colocar_puerta(b_x))
	assert(p.existe(b_x), "la puerta colocada debe registrarse")
	assert(not p.esta_abierta(b_x), "nace cerrada")
	var cuerpo: StaticBody3D = p.cuerpo_de(b_x)
	assert(cuerpo.collision_layer == 1 and cuerpo.collision_mask == 0, "cerrada: capa 1 (mundo)")
	assert(cuerpo.position.is_equal_approx(Vector3(b_x) + Vector3(0.5, 1.0, 0.5)), "centrada en las 2 celdas")
	assert(is_equal_approx(cuerpo.rotation.y, 0.0), "pared por X: sin giro")
	var forma: CollisionShape3D = cuerpo.get_child(1)
	assert((forma.shape as BoxShape3D).size.is_equal_approx(LAMINA), "la lámina mide 1 x 2 x 0.1")
	# Pared que corre por Z: paredes en (base ± Z).
	var b_z := Vector3i(20, 5, 10)
	m.colocar_bloque(b_z + Vector3i(0, 0, -1), "pared", true)
	m.colocar_bloque(b_z + Vector3i(0, 0, 1), "pared", true)
	assert(m.colocar_puerta(b_z))
	assert(is_equal_approx(p.cuerpo_de(b_z).rotation.y, PI / 2.0), "pared por Z: giro de 90°")
	# Puerta suelta (sin paredes): toma el eje X y no falla.
	var b_s := Vector3i(30, 5, 10)
	assert(m.colocar_puerta(b_s))
	assert(is_equal_approx(p.cuerpo_de(b_s).rotation.y, 0.0), "puerta suelta: eje X")
	print("OK: registro, orientación, lámina y colisión.")
	_liberar(par)

	print("=== TEST 3: alternar() abre y cierra, cambia capa y giro ===")
	par = _mundo_con_puertas()
	m = par[0]
	p = par[1]
	m.colocar_bloque(b_x + Vector3i(-1, 0, 0), "pared", true)
	m.colocar_bloque(b_x + Vector3i(1, 0, 0), "pared", true)
	assert(m.colocar_puerta(b_x))
	cuerpo = p.cuerpo_de(b_x)
	assert(p.alternar(b_x))
	assert(p.esta_abierta(b_x))
	assert(cuerpo.collision_layer == 8, "abierta: capa 4 (el avatar no la colisiona)")
	assert(is_equal_approx(cuerpo.rotation.y, PI / 2.0), "abrir gira 90° sobre el eje vertical")
	assert(p.alternar(b_x))
	assert(not p.esta_abierta(b_x))
	assert(cuerpo.collision_layer == 1)
	assert(is_equal_approx(cuerpo.rotation.y, 0.0))
	assert(not p.alternar(Vector3i(99, 5, 99)), "alternar() sobre una celda sin puerta devuelve false")
	assert(p.celda_de_colisionador(cuerpo) == b_x, "el cuerpo se identifica con su celda inferior")
	var ajeno := StaticBody3D.new()
	assert(p.celda_de_colisionador(ajeno) == Vector3i.MAX, "otro cuerpo no es una puerta")
	ajeno.free()
	assert(p.celda_de_colisionador(null) == Vector3i.MAX, "null no es una puerta")
	print("OK: alternar(), capa, giro e identificación por colisionador.")
	_liberar(par)

	print("=== TEST 4: ciclo de vida (mitades sueltas, minar, revertir, eliminar) ===")
	par = _mundo_con_puertas()
	m = par[0]
	p = par[1]
	var base_4 := Vector3i(0, 5, 0)
	var sobre := Vector3i(0, 6, 0)
	# Solo la mitad inferior: no se registra.
	m.colocar_bloque(base_4, "puerta_inferior", true)
	assert(not p.existe(base_4), "una sola mitad no registra la puerta")
	# Se completa con la superior: se registra.
	m.colocar_bloque(sobre, "puerta_superior", true)
	assert(p.existe(base_4), "con ambas mitades sí")
	assert(p.get_child_count() == 1)
	# Orden inverso: primero la superior, luego la inferior.
	var base2 := Vector3i(4, 5, 0)
	m.colocar_bloque(base2 + Vector3i(0, 1, 0), "puerta_superior", true)
	assert(not p.existe(base2))
	m.colocar_bloque(base2, "puerta_inferior", true)
	assert(p.existe(base2), "el registro no depende del orden de colocación")
	# Minar una puerta ABIERTA libera su nodo y no deja colisión.
	p.alternar(base2)
	m.pareja[base2] = base2 + Vector3i(0, 1, 0)
	m.pareja[base2 + Vector3i(0, 1, 0)] = base2
	assert(m.minar_bloque(base2))
	assert(not p.existe(base2), "minar la puerta destruye su entrada")
	assert(p.get_child_count() == 1, "y libera su cuerpo (queda solo el de la otra puerta)")
	# Revertir a fantasma una celda de la otra puerta la destruye.
	m._revertir_celda(sobre)
	assert(not p.existe(base_4), "revertir a fantasma una celda destruye la puerta")
	assert(p.get_child_count() == 0)
	# eliminar_edificio(): una puerta de un edificio registrado desaparece con él.
	m.colocar_bloque(Vector3i(8, 5, 0), "pared", true)
	m.colocar_puerta(Vector3i(9, 5, 0))
	assert(p.existe(Vector3i(9, 5, 0)))
	var id: int = m.registrar_edificio_completo({
		Vector3i(8, 5, 0): "pared",
		Vector3i(9, 5, 0): "puerta_inferior",
		Vector3i(9, 6, 0): "puerta_superior",
	})
	m.eliminar_edificio(id)
	assert(not p.existe(Vector3i(9, 5, 0)), "eliminar el edificio destruye su puerta")
	print("OK: ciclo de vida.")
	_liberar(par)

	print("\n=== Las pruebas de puertas pasaron correctamente ===")
