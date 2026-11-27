extends Node

const Ajustes = preload("res://scripts/ajustes.gd")
const AtmosferaScript = preload("res://scripts/AtmosferaCiclo.gd")
const AlumbradoScript = preload("res://scripts/AlumbradoUrbano.gd")
const VoxelWorldScript = preload("res://scripts/VoxelWorld.gd")
const BuscadorRutas = preload("res://scripts/BuscadorRutas.gd")


class FakeRecurso:
	var cantidad: float = 0.0
	func _init(c: float) -> void:
		cantidad = c
	func consumir(m: float) -> bool:
		if cantidad < m:
			return false
		cantidad -= m
		return true


class FakeCiudad:
	signal tick_simulado
	var horas_juego: int = 0
	var almacen: Dictionary = {}


class FakeEconomia:
	var balance_energia: Dictionary = {}


class FakeZonificacion:
	var zonas_activas: Dictionary = {}
	func dentro_de_influencia(col: Vector2i) -> bool:
		return zonas_activas.get(col, false)


class FakeVias:
	signal vias_cambiadas(celdas: Array)
	var celdas: Dictionary = {}
	func es_via(soporte: Vector3i) -> bool:
		return celdas.has(soporte)
	func coste_ruta(_soporte: Vector3i) -> int:
		return 3
	func es_borde_derecho(_s: Vector3i, _d: Vector2i, _a: int = 1) -> bool:
		return true


func _ready() -> void:
	_test_ciclo_y_clima()
	_test_alumbrado_colocacion_fuente_y_consumo()
	print("AtmosferaAlumbradoTest: todas las pruebas pasaron")
	get_tree().quit()


func _test_ciclo_y_clima() -> void:
	var atm := AtmosferaScript.new()
	add_child(atm)

	# 360h dia / 360h noche
	assert(not atm.es_de_noche(0.0), "0h debe ser dia")
	assert(not atm.es_de_noche(180.0), "180h debe ser dia")
	assert(not atm.es_de_noche(359.0), "359h debe ser dia")
	assert(atm.es_de_noche(360.0), "360h debe ser noche")
	assert(atm.es_de_noche(540.0), "540h debe ser noche")
	assert(atm.es_de_noche(719.0), "719h debe ser noche")
	assert(not atm.es_de_noche(720.0), "720h inicia nuevo mes de dia")

	assert(is_equal_approx(atm.factor_luz_diurna(180.0), 1.0), "Mediodia debe tener factor 1.0")
	assert(is_equal_approx(atm.factor_luz_diurna(540.0), 0.0), "Medianoche debe tener factor 0.0")

	atm.establecer_clima(AtmosferaScript.EstadoClima.NIEVE, true)
	assert(atm.estado_clima == AtmosferaScript.EstadoClima.NIEVE)
	assert(is_equal_approx(atm.intensidad_nieve_actual, 1.0))

	var est := atm.exportar_estado()
	var atm2 := AtmosferaScript.new()
	add_child(atm2)
	atm2.importar_estado(est)
	assert(atm2.estado_clima == AtmosferaScript.EstadoClima.NIEVE)
	assert(is_equal_approx(atm2.intensidad_nieve_actual, 1.0))

	atm.queue_free()
	atm2.queue_free()


func _test_alumbrado_colocacion_fuente_y_consumo() -> void:
	var lib: MeshLibrary = load("res://assets/BlockLibrary.res")
	var mundo := VoxelWorldScript.new()
	mundo.mesh_library = lib
	mundo._indexar_biblioteca()

	# Suelo plano 20x1x20 en y=0
	for x in range(20):
		for z in range(20):
			mundo.colocar_bloque(Vector3i(x, 0, z), "tierra", false)

	# Edificio declarado simple 5x5x5 en (1..5, 1..5, 1..5) con puerta en (3,1..2,1),
	# ventana junto a la puerta en (2,2,1) y ventana en el centro del techo (3,5,3)
	var edif := {}
	for x in range(1, 6):
		for z in range(1, 6):
			for y in range(1, 6):
				if x == 3 and z == 1 and y == 1:
					edif[Vector3i(x, y, z)] = "puerta_inferior"
				elif x == 3 and z == 1 and y == 2:
					edif[Vector3i(x, y, z)] = "puerta_superior"
				elif x == 2 and z == 1 and y == 2:
					edif[Vector3i(x, y, z)] = "vidrio"
				elif x == 3 and z == 3 and y == 5:
					edif[Vector3i(x, y, z)] = "vidrio"
				elif x == 1 or x == 5 or z == 1 or z == 5 or y == 5:
					edif[Vector3i(x, y, z)] = "bloque_piedra"
	for c in edif:
		mundo.colocar_bloque(c, edif[c], true)
	mundo.registrar_edificio_completo(edif)

	# Vía desde z=1 hasta z=15 pasando frente al edificio y en tramo abierto
	var vias := FakeVias.new()
	for z in range(1, 16):
		vias.celdas[Vector3i(6, 0, z)] = "tierra_pisada"

	var ciu := FakeCiudad.new()
	ciu.almacen = {
		"combustible": FakeRecurso.new(0.0),
		"carbon": FakeRecurso.new(10.0),
		"madera": FakeRecurso.new(10.0),
	}
	var econ := FakeEconomia.new()
	econ.balance_energia = {"capacidad": 50.0, "demanda": 10.0, "factor": 1.0}
	var zon := FakeZonificacion.new()
	zon.zonas_activas[Vector2i(3, 3)] = true

	var atm := AtmosferaScript.new()
	add_child(atm)
	atm.sincronizar_hora(180.0)  # Dia

	var alu := AlumbradoScript.new()
	alu.mundo = mundo
	alu.atmosfera = atm
	alu.ciudad_ref = ciu
	alu.economia_ref = econ
	alu.vias_ref = vias
	alu.zonificacion_ref = zon
	add_child(alu)
	alu.reconstruir_luminarias()

	for lum in alu.luminarias:
		if int(lum["tipo"]) == AlumbradoScript.TipoLuminaria.APLIQUE:
			var lc: Vector3i = lum["celda"]
			var dentro_huella: bool = lc.x >= 1 and lc.x <= 5 and lc.z >= 1 and lc.z <= 5 and lc.y >= 1 and lc.y <= 5
			assert(not dentro_huella, "Ningun aplique puede colocarse dentro del edificio: %s" % str(lc))

	for m_alu: ArrayMesh in [alu._mesh_techo, alu._mesh_aplique, alu._mesh_poste]:
		for s in range(m_alu.get_surface_count()):
			var arrs: Array = m_alu.surface_get_arrays(s)
			var verts: PackedVector3Array = arrs[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arrs[Mesh.ARRAY_NORMAL]
			var idxs: PackedInt32Array = arrs[Mesh.ARRAY_INDEX] if arrs[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var tri_count: int = idxs.size() / 3 if not idxs.is_empty() else verts.size() / 3
			for t in range(tri_count):
				var i0: int = idxs[t * 3] if not idxs.is_empty() else t * 3
				var i1: int = idxs[t * 3 + 1] if not idxs.is_empty() else t * 3 + 1
				var i2: int = idxs[t * 3 + 2] if not idxs.is_empty() else t * 3 + 2
				var orient: float = (verts[i1] - verts[i0]).cross(verts[i2] - verts[i0]).dot(norms[i0])
				assert(orient < 0.0, "Winding invertido en malla AlumbradoUrbano sup %d tri %d" % [s, t])

	var conteo_techo := 0
	var tiene_aplique := false
	var tiene_poste := false
	for lum in alu.luminarias:
		match lum["tipo"]:
			AlumbradoScript.TipoLuminaria.TECHO:
				conteo_techo += 1
				var c_t := Vector3i(floori(lum["pos"].x), int(lum["pos"].y), floori(lum["pos"].z))
				assert(mundo.obtener_tipo(c_t) != "vidrio", "Lampara de techo no debe colocarse sobre ventana de techo")
			AlumbradoScript.TipoLuminaria.APLIQUE:
				tiene_aplique = true
				assert(lum["celda"] != Vector3i(3, 2, 0), "Aplique no debe colocarse sobre puerta_superior")
				assert(lum["celda"] != Vector3i(2, 2, 0), "Aplique no debe colocarse sobre vidrio")
			AlumbradoScript.TipoLuminaria.POSTE:
				tiene_poste = true
	assert(conteo_techo == 1, "Debe colocar exactamente 1 lampara_techo por techo interno")
	assert(tiene_aplique, "Debe colocar aplique_pared en edificio/fachada")
	assert(tiene_poste, "Debe colocar poste_luz en via abierta")

	# Verificar que el poste no bloquea BuscadorRutas
	var buscador := BuscadorRutas.new(mundo)
	var camino := buscador.buscar_ruta(Vector3i(6, 1, 1), Vector3i(6, 1, 15))
	assert(not camino.is_empty(), "Poste de luz en borde libre no debe bloquear pathfinding en la via")

	# Fuente electrica activa vs apagon
	assert(alu.resolver_fuente_en(Vector3i(3, 3, 3)) == "electrica", "Zona con energia debe ser electrica")
	econ.balance_energia = {"capacidad": 0.0, "demanda": 10.0, "factor": 0.0}
	assert(alu.resolver_fuente_en(Vector3i(3, 3, 3)) == "carbon", "En apagon debe caer a carbon disponible")

	# Consumo diurno == 0
	var carbon_antes: float = ciu.almacen["carbon"].cantidad
	alu.simular_hora()
	assert(is_equal_approx(ciu.almacen["carbon"].cantidad, carbon_antes), "De dia no debe consumir recursos")

	# Consumo nocturno == 1 / (horas_por_unidad * 100) por lampara no electrica
	atm.sincronizar_hora(400.0)  # Noche
	alu.simular_hora()
	var n_lums := alu.luminarias.size()
	var esperado_gasto: float = float(n_lums) / (6.0 * Ajustes.ALUMBRADO_RATIO_CONSUMO_AVATAR)
	assert(is_equal_approx(carbon_antes - ciu.almacen["carbon"].cantidad, esperado_gasto), "Consumo nocturno debe ser 1/100 de lampara del Avatar por luminaria")

	# Clima nevando durante el dia (180h): debe encenderse y consumir el doble (calefaccion)
	atm.establecer_clima(AtmosferaScript.EstadoClima.NIEVE, true)
	atm.sincronizar_hora(180.0)
	assert(alu.debe_estar_encendido(), "Nevando de dia debe mantener el alumbrado encendido")
	var carbon_antes_nieve: float = ciu.almacen["carbon"].cantidad
	alu.simular_hora()
	assert(is_equal_approx(carbon_antes_nieve - ciu.almacen["carbon"].cantidad, esperado_gasto * 2.0), "Nevando debe consumir el doble")

	# Iluminacion cenital vs 1a persona: cenital usa clusters+halos y apaga luces puntuales
	alu.modo_cenital = true
	alu.actualizar_pool_luces(Vector3(6.0, 20.0, 6.0))
	assert(alu._pool_clusters[0].visible, "Cenital debe encender cluster general")
	assert(alu._pool_halos[0].visible, "Cenital debe encender halo de dispersion")
	assert(not alu._pool_luces[0].visible, "Cenital no debe usar luces puntuales cercanas")

	alu.modo_cenital = false
	alu.actualizar_pool_luces(Vector3(6.0, 2.0, 6.0))
	assert(alu._pool_clusters[0].visible, "1P debe mantener cluster general para distancia")
	assert(alu._pool_halos[0].visible, "1P debe mantener halo de dispersion")
	assert(alu._pool_luces[0].visible, "1P debe encender luces cercanas al avatar")

	alu.queue_free()
	atm.queue_free()
	mundo.free()
