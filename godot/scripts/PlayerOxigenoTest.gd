extends Node

## Pruebas aisladas de Player._calcular_oxigeno() (mismo patrón que
## NiveladorTerrenoTest.gd): función estática pura, sin nodos ni cámara, así
## que no depende de una escena de Player real ni de VoxelWorld. Corre esta
## escena (PlayerOxigenoTest.tscn) con F6 y revisa el panel "Output": debe
## imprimir las 4 pruebas y no debe lanzar ningún error de assert().

const Player = preload("res://scripts/Player.gd")
const HUD = preload("res://scripts/HUD.gd")

func _ready() -> void:
	ejecutar_pruebas()


func ejecutar_pruebas() -> void:
	print("=== TEST 1: sumergido consume oxígeno a TASA_CONSUMO_OXIGENO ===")
	var resultado := Player._calcular_oxigeno(10.0, true, 1.0)
	print("Oxígeno tras 1s sumergido desde 10.0: ", resultado, " (esperado: 9.0)")
	assert(resultado == 9.0)

	print("\n=== TEST 2: sumergido no baja de 0 (clamp) ===")
	resultado = Player._calcular_oxigeno(0.5, true, 1.0)
	print("Oxígeno tras 1s sumergido desde 0.5: ", resultado, " (esperado: 0.0)")
	assert(resultado == 0.0)

	print("\n=== TEST 3: fuera del agua recupera a TASA_RECUPERACION_OXIGENO ===")
	resultado = Player._calcular_oxigeno(5.0, false, 1.0)
	print("Oxígeno tras 1s fuera del agua desde 5.0: ", resultado, " (esperado: 7.0)")
	assert(resultado == 7.0)

	print("\n=== TEST 4: fuera del agua no pasa de OXIGENO_MAXIMO (clamp) ===")
	resultado = Player._calcular_oxigeno(9.5, false, 1.0)
	print("Oxígeno tras 1s fuera del agua desde 9.5: ", resultado, " (esperado: ", Player.OXIGENO_MAXIMO, ")")
	assert(resultado == Player.OXIGENO_MAXIMO)

	print("\n=== TEST 5: HUD.texto_oxigeno() formato consumo y recuperación ===")
	assert(HUD.texto_oxigeno(90, true) == "Oxígeno: -90%")
	assert(HUD.texto_oxigeno(30, false) == "Oxígeno: +30%")
	assert(HUD.texto_oxigeno(0, true) == "Oxígeno: -0%")
	assert(HUD.texto_oxigeno(100, false) == "Oxígeno: +100%")

	print("\n=== TEST 6: HUD panel de oxígeno y apilamiento con lámpara ===")
	var hud := HUD.new()
	add_child(hud)
	assert(not hud._panel_oxigeno.visible)
	assert(not hud._panel_lampara.visible)
	hud.actualizar_oxigeno(0.9, true)
	assert(hud._panel_oxigeno.visible)
	assert(hud._oxigeno_texto.text == "Oxígeno: -90%")
	hud.actualizar_panel_lampara({"visible": true, "tipo": "electrica", "encendida": true, "bateria_pct": 80, "bateria_horas": 50, "descarga": true})
	assert(hud._panel_lampara.visible)
	assert(hud._panel_lampara.get_index() < hud._panel_oxigeno.get_index(), "el panel de lámpara debe estar arriba del panel de oxígeno")
	hud.ocultar_oxigeno()
	assert(not hud._panel_oxigeno.visible)
	hud.queue_free()

	print("\n=== Las pruebas de Player y HUD de oxígeno pasaron correctamente ===")
