extends RefCounted

## Lógica de fin de obra y de demolición compartida por Player (jugador) y Obras
## (colonos): registrar lo construido, retirar lo demolido y medir cuánto dura un
## paso. Solo estáticos y sin estado; los mensajes se devuelven para que cada
## llamador los muestre a su manera (Player al HUD, Obras por su señal "aviso").

## Intervalo (s) entre pasos de colocar/surtir/deconstruir: el mismo para el jugador y los colonos.
const INTERVALO_PASO := 0.20


## Se llama cuando VoxelWorld.surtir_construccion() indica que una construcción
## fantasma quedó completa. "metadata" es la que se pasó a
## VoxelWorld.iniciar_construccion_fantasma() al colocarla: un edificio
## residencial, un puesto nuevo ("puesto_nuevo") o un puesto que se volvió a
## completar tras deconstruirse ("puesto"; solo reactiva su Economia). Devuelve
## el mensaje para notificar ("" si no hay).
static func completar_construccion(mundo: Object, metadata: Dictionary) -> String:
	if metadata.is_empty():
		return ""
	if metadata.has("puesto_nuevo"):
		var info: Dictionary = metadata["puesto_nuevo"]
		var entorno: Dictionary = {}
		var tasas: Dictionary = {}
		if not CadenaMinerales.REFINERIAS.has(info["tipo"]) and not Recoleccion.ESCUELAS.has(info["tipo"]) and info["tipo"] != "universidad":
			var centro: Vector2i = info["centro"]
			var altura: int = mundo.altura_en(centro.x, centro.y)
			entorno = Recoleccion.entorno_de_puesto(info["tipo"], mundo, centro, altura, info["centro_agua"])
			tasas = Recoleccion.tasas_de_entorno(info["tipo"], mundo, entorno)
		Recoleccion.colocar_puesto(info["esquina"], info["tipo"], info["ancho"], info["alto"])
		# info["y_base"] es la Y de la losa de piso (capa 0, ver PlantillasPuesto.gd);
		# el piso interior TRANSITABLE (donde vive la puerta) es una capa arriba.
		Economia.registrar_puesto(info["esquina"], info["tipo"], info["ancho"], info["alto"], tasas, entorno, info["servicio"], info["deposito"], info["y_base"] + 1, info.get("salida", Economia.SIN_SERVICIO), info.get("chimenea", Economia.SIN_DEPOSITO))
		if metadata.has("id_edificio"):
			Ciudad.registrar_instalacion(metadata["id_edificio"], info["tipo"])
		print("Puesto '%s' construido en (%d, %d)." % [info["tipo"], info["esquina"].x, info["esquina"].y])
		metadata.erase("puesto_nuevo")  # a partir de aquí, un reconstruir cae en la rama "puesto" (reactivar), no en esta (evita re-registrar y huérfanos en _puesto_de — revisión de código, 2026-09-29).
		return "Puesto construido."
	if metadata.has("puesto"):
		Economia.reactivar_puesto(metadata["puesto"])
		print("Puesto reactivado en ", metadata["puesto"], ".")
		return "Puesto reactivado."
	var blueprint: Dictionary = metadata["blueprint"]

	# El primer edificio declarado es el núcleo urbano: no es habitable, así que
	# no suma camas (no llegan colonos todavía) ni baúles al tope del almacén; en
	# cambio, declararlo duplica los topes del inventario.
	if not Zonificacion.nucleo_declarado:
		Zonificacion.declarar_nucleo(metadata["huella_xz"])
		Ciudad.ampliar_almacen()
		print("Núcleo urbano declarado (no habitable: no llegan colonos todavía). Zona de influencia: ", Zonificacion.influencia_min, " a ", Zonificacion.influencia_max, ". Topes del inventario duplicados.")
		Recoleccion.colocar_puesto(metadata["esquina"], "blueprint", metadata["ancho"], metadata["profundidad"])
		return "Núcleo urbano declarado."

	var camas_por_piso: Array[int] = []
	var total_camas := 0
	for piso in blueprint["pisos"]:
		var camas: int = (piso.get("camas", []) as Array).size()
		camas_por_piso.append(camas)
		total_camas += camas
	var baules: int = BlueprintValidator.contar_baules(blueprint)
	Ciudad.registrar_edificio_residencial(metadata["id_edificio"], camas_por_piso, baules)
	print("Construcción completa: camas registradas en Ciudad: ", total_camas, " (capacidad de camas actual: ", Ciudad.capacidad_camas_construida, "), baúles: ", baules)

	Zonificacion.ampliar_influencia(metadata.get("id_edificio", -1), metadata["huella_xz"], blueprint["categoria"])
	print("Zona de influencia ampliada: ", Zonificacion.influencia_min, " a ", Zonificacion.influencia_max)

	Recoleccion.colocar_puesto(metadata["esquina"], "blueprint", metadata["ancho"], metadata["profundidad"])
	return "Edificio construido."


## Efectos de revertir una celda de un edificio ("resultado" es lo que devuelve
## VoxelWorld.procesar_deconstruccion()): retirar sus camas de Ciudad (idempotente)
## y dejar de producir si es un puesto (idempotente).
static func al_deconstruir(mundo: Object, resultado: Dictionary) -> void:
	Ciudad.retirar_edificio_residencial(resultado["id"])
	Ciudad.desregistrar_instalacion(resultado["id"])
	var metadata_obra: Dictionary = mundo.edificio_metadata.get(resultado["id"], {})
	if metadata_obra.has("puesto"):
		Economia.desactivar_puesto(metadata_obra["puesto"])
	if resultado["total_camas"] > 0:
		print("Deconstrucción iniciada: ", resultado["total_camas"], " cama(s) retiradas de Ciudad.")


## Elimina por completo un edificio ya reducido a fantasma vacío y limpia lo que
## dependía de él.
static func retirar_edificio(mundo: Object, id: int) -> void:
	Ciudad.desregistrar_instalacion(id)
	var metadata_final: Dictionary = mundo.edificio_metadata.get(id, {})  # eliminar_edificio() la borra
	var esquina: Vector2i = mundo.eliminar_edificio(id)
	if metadata_final.has("puesto"):
		esquina = metadata_final["puesto"]  # la esquina del puesto, no la de las celdas de la plantilla
	Zonificacion.retirar_contribucion(id)
	Recoleccion.quitar_puesto(esquina)
	Economia.quitar_puesto(esquina)  # libera a sus trabajadores (no-op si era un edificio)
	Obras.olvidar(id)  # sin marca ni estado de obra: el edificio ya no existe
	print("Edificio deconstruido por completo.")


## Intervalo hasta el próximo paso de la obra a la que pertenece "celda": el mismo
## tiempo que minar a mano el material si el paso es de EXCAVACIÓN (ver
## VoxelWorld.proximo_paso_pendiente()), y INTERVALO_PASO en el resto (colocar,
## relleno, estructura) — nivelar un sitio no debe vaciar una veta más rápido que
## minarla uno mismo (decisión del usuario, 2026-09-29).
static func intervalo_del_paso(mundo: Object, celda: Vector3i) -> float:
	var paso: Dictionary = mundo.proximo_paso_pendiente(celda)
	if paso.is_empty() or (paso["tipo"] != "aire" and paso["tipo"] != "fantasma"):
		return INTERVALO_PASO
	var material: String = mundo.material_real(mundo.obtener_tipo(paso["celda"]))
	return Recoleccion.tiempo_minado_de(material)
