extends Node

## Pruebas de MiniaturaRenderer.gd (mismo patrón que BlueprintsTest.gd).
## Corre MiniaturaRendererTest.tscn y revisa el panel "Output": debe imprimir
## todas las pruebas y la línea final, sin ningún error de assert().

const MiniaturaRenderer = preload("res://scripts/MiniaturaRenderer.gd")


func _ready() -> void:
	ejecutar_pruebas()


func ejecutar_pruebas() -> void:
	print("=== TEST 1: malla_de_item() devuelve una malla real para un tipo conocido ===")
	var biblioteca: MeshLibrary = MiniaturaRenderer.cargar_biblioteca()
	assert(biblioteca != null, "BlockLibrary.res debe cargar")
	var malla: Mesh = MiniaturaRenderer.malla_de_item(biblioteca, "bloque_piedra")
	assert(malla != null, "bloque_piedra tiene malla real")

	print("\n=== TEST 2: malla_de_item() resuelve el alias adobe -> tierra_compactada ===")
	var malla_adobe: Mesh = MiniaturaRenderer.malla_de_item(biblioteca, "adobe")
	var malla_directa: Mesh = MiniaturaRenderer.malla_de_item(biblioteca, "tierra_compactada")
	assert(malla_adobe != null and malla_adobe == malla_directa, "adobe usa la misma malla que tierra_compactada")

	print("\n=== TEST 3: malla_de_item() devuelve null para un ítem que no existe en la biblioteca ===")
	assert(MiniaturaRenderer.malla_de_item(biblioteca, "no_existe_este_tipo") == null)

	print("\n=== TEST 4: renderizar() con una sola pieza devuelve una textura no nula ===")
	var padre := Node.new()
	add_child(padre)
	var pieza: Array = [[malla, Vector3.ZERO, null]]
	var textura: Texture2D = MiniaturaRenderer.renderizar(pieza, Vector3(1, 1, 1), padre)
	assert(textura != null, "renderizar() con una pieza real devuelve una Texture2D")

	print("\n=== TEST 5: renderizar() con varias piezas en distintas posiciones no revienta ===")
	var piezas: Array = [
		[malla, Vector3.ZERO, null],
		[malla, Vector3(1, 0, 0), null],
		[malla, Vector3(0, 1, 0), null],
	]
	var textura_multi: Texture2D = MiniaturaRenderer.renderizar(piezas, Vector3(1, 1, -1), padre)
	assert(textura_multi != null, "renderizar() con varias piezas devuelve una Texture2D")

	print("\n=== Las 5 pruebas de MiniaturaRenderer pasaron correctamente ===")
