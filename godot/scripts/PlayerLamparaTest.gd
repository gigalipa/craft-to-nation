extends Node

## Pruebas de la lámpara del jugador (tecla L, iluminación, jerarquía de recursos,
## consumo, recarga y textos informativos del PanelLampara).

const PlayerScript = preload("res://scripts/Player.gd")
const PanelLamparaScript = preload("res://scripts/PanelLampara.gd")

class AlmacenMock:
	var _datos: Dictionary = {}

	func has(k: String) -> bool:
		return _datos.has(k)

	func get_item(k: String):
		return _datos.get(k)

	func fijar(k: String, cant: float) -> void:
		_datos[k] = RecursoMock.new(cant)


class RecursoMock:
	var cantidad: float = 0.0

	func _init(c: float) -> void:
		cantidad = c

	func consumir(m: float) -> float:
		var c := minf(cantidad, m)
		cantidad -= c
		return c


func _ready() -> void:
	ejecutar_pruebas()


func ejecutar_pruebas() -> void:
	print("=== LAMPARA TEST 1: Formatos de texto de PanelLampara ===")
	# Eléctrica encendida descargando
	assert(PanelLamparaScript.texto_titulo("electrica", true) == "LÁMPARA ELÉCTRICA🟡")
	assert(PanelLamparaScript.texto_detalle_electrica(false, true, 78, 56) == "Batería: -78% | 56 h")

	# Eléctrica apagada recargando
	assert(PanelLamparaScript.texto_titulo("electrica", false) == "LÁMPARA ELÉCTRICA⚫")
	assert(PanelLamparaScript.texto_detalle_electrica(true, false, 3, 2) == "Batería: +3% | 2 h")

	# Eléctrica en zona al 100%
	assert(PanelLamparaScript.texto_detalle_electrica(false, false, 100, 72) == "Batería: 100% | 72 h")

	# Térmica encendida
	assert(PanelLamparaScript.texto_titulo("termica", true) == "LÁMPARA TÉRMICA🟡")
	assert(PanelLamparaScript.texto_detalle_termica(15, 90, "Carbón") == "Tiempo restante: 15 h | 90 Carbón")
	print("OK: Formatos de texto de PanelLampara verificados.")

	print("\n=== LAMPARA TEST 2: Jerarquía de recursos en evaluar_fuente_lampara ===")
	Zonificacion.declarar_nucleo([Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)], 1)
	var player = PlayerScript.new()
	player.position = Vector3(0, 10, 0)
	# Simular dependencias
	Economia.balance_energia = { "capacidad": 50.0, "entregada": 50.0 }
	Ciudad.almacen["combustible"].cantidad = 100.0
	Ciudad.almacen["carbon"].cantidad = 100.0
	Ciudad.almacen["madera"].cantidad = 100.0

	# 1. Con energía disponible y en zona -> eléctrica
	assert(player.evaluar_fuente_lampara() == "electrica")

	# 2. Sin energía -> combustible > carbón > madera
	Economia.balance_energia = { "capacidad": 0.0, "entregada": 0.0 }
	assert(player.evaluar_fuente_lampara() == "combustible")

	Ciudad.almacen["combustible"].cantidad = 0.0
	assert(player.evaluar_fuente_lampara() == "carbon")

	Ciudad.almacen["carbon"].cantidad = 0.0
	assert(player.evaluar_fuente_lampara() == "madera")

	Ciudad.almacen["madera"].cantidad = 0.0
	assert(player.evaluar_fuente_lampara() == "")
	print("OK: Jerarquía eléctrica > combustible > carbón > madera verificada.")

	print("\n=== LAMPARA TEST 3: Descarga de batería fuera de zona y transición automática ===")
	# Restaurar energía y carbón
	Economia.balance_energia = { "capacidad": 50.0, "entregada": 50.0 }
	Ciudad.almacen["carbon"].cantidad = 10.0
	player.bateria_lampara = 3.0
	player.encender_lampara()
	assert(player.lampara_encendida)
	assert(player.fuente_lampara_actual == "electrica")

	# Simular que está fuera de zona moviendo posición lejos
	player.position = Vector3(500, 10, 500)
	assert(not player._esta_en_zona_influencia(), "debe estar fuera de la zona de influencia")

	# Hora 1: batería baja a 2.0
	player.simular_hora_lampara()
	assert(is_equal_approx(player.bateria_lampara, 2.0))
	assert(player.fuente_lampara_actual == "electrica")

	# Hora 2: batería baja a 1.0
	player.simular_hora_lampara()
	assert(is_equal_approx(player.bateria_lampara, 1.0))

	# Hora 3: batería llega a 0.0 -> transición automática a carbón
	player.simular_hora_lampara()
	assert(is_equal_approx(player.bateria_lampara, 0.0))
	assert(player.fuente_lampara_actual == "carbon", "al agotarse la batería conmuta a carbón: %s" % player.fuente_lampara_actual)
	assert(player.lampara_encendida, "la lámpara sigue encendida tras la transición")
	print("OK: Descarga fuera de zona y transición automática a carbón verificada.")

	print("\n=== LAMPARA TEST 4: Recarga automática al reingresar a zona de influencia ===")
	# Regresar a zona (origen 0,0)
	player.position = Vector3(0, 10, 0)
	# Promueve de inmediato a eléctrica al procesar zona
	player._procesar_zona_lampara()
	assert(player.fuente_lampara_actual == "electrica", "reingreso a zona con energía promueve a eléctrica")
	assert(is_equal_approx(player.bateria_lampara, 0.0))

	# Simular 1 hora de recarga: +7.2h (10%)
	player.simular_hora_lampara()
	assert(is_equal_approx(player.bateria_lampara, 7.2))
	# Simular 1 hora más: +7.2h -> 14.4h
	player.simular_hora_lampara()
	assert(is_equal_approx(player.bateria_lampara, 14.4))

	# Si se apaga la lámpara dentro de zona, sigue recargando
	player.apagar_lampara()
	assert(not player.lampara_encendida)
	player.simular_hora_lampara()
	assert(is_equal_approx(player.bateria_lampara, 21.6))
	print("OK: Recarga del 10%/hora verificada con lámpara encendida y apagada.")

	print("\n=== LAMPARA TEST 5: Consumo de combustibles térmicos ===")
	Economia.balance_energia = { "capacidad": 0.0, "entregada": 0.0 }
	Ciudad.almacen["carbon"].cantidad = 5.0
	player.horas_quemadas_lampara = 0.0
	player.encender_lampara()
	assert(player.fuente_lampara_actual == "carbon")

	# Carbón dura 6 horas por unidad
	for h in range(5):
		player.simular_hora_lampara()
		assert(Ciudad.almacen["carbon"].cantidad == 5.0, "primeras 5 horas no han descontado aún")

	# En la 6ª hora debe descontar 1 unidad
	player.simular_hora_lampara()
	assert(Ciudad.almacen["carbon"].cantidad == 4.0, "a la 6ª hora se consume 1 carbón")
	print("OK: Consumo de carbón cada 6 horas verificado.")

	print("\n=== LAMPARA TEST 6: Estado para PanelLampara ===")
	# Térmica encendida con 4 carbón restante
	var st = player.obtener_estado_lampara()
	assert(st.visible)
	assert(st.tipo == "termica")
	assert(st.encendida)
	assert(st.recurso_nombre == "Carbón")
	assert(st.recurso_cantidad == 4)
	assert(st.tiempo_restante_h == 24) # 4 * 6h

	# Apagar lámpara y batería llena al 100% -> panel oculto
	player.apagar_lampara()
	player.bateria_lampara = 72.0
	var st_apagada = player.obtener_estado_lampara()
	assert(not st_apagada.visible, "con lámpara apagada y batería al 100%, el panel no debe mostrarse")

	# Apagada pero recargando (batería < 72 en zona con energía) -> panel visible
	Economia.balance_energia = { "capacidad": 50.0, "entregada": 50.0 }
	player.position = Vector3(0, 10, 0)
	player.bateria_lampara = 2.0
	var st_recarga = player.obtener_estado_lampara()
	assert(st_recarga.visible, "con batería recargando, el panel debe mostrarse aunque esté apagada")
	assert(st_recarga.tipo == "electrica")
	assert(not st_recarga.encendida)
	assert(st_recarga.recargando)
	assert(st_recarga.bateria_horas == 2)
	assert(st_recarga.bateria_pct == 3) # 2/72 = 2.77% -> 3%
	print("OK: Estados y visibilidad de PanelLampara verificados.")

	player.free()
	print("\n=== Todas las pruebas de la lámpara del jugador pasaron correctamente ===")
