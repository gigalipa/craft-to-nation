# Diseño: economía de construcción para puestos periféricos

Extiende a los puestos de recolección (mina, maderero, caza y recolección, pesca y frutos del mar) el mismo mecanismo de construcción gradual y pagada que ya tienen los edificios residenciales — ver `docs/superpowers/specs/2026-09-29-costo-colocacion-bloques-design.md` (costo de colocación de bloques) y el trabajo de esta misma rama que conectó `VoxelWorld.surtir_construccion()`/`_aplicar_paso_cola()` a `Ciudad.almacen` (excavar acredita, rellenar/surtir estructura cobra, `celdas_pagadas` habilita el reembolso simétrico ya existente).

Decisiones confirmadas con el usuario (2026-09-29), en orden de aparición durante el brainstorming.

## 1. Alcance

**Dentro:**
- `CamaraCenital._procesar_clic_puesto()` deja de estampar el puesto al instante (`VoxelWorld.estampar_puesto()`) y en su lugar coloca un fantasma con `iniciar_construccion_fantasma()`, exactamente como `_procesar_clic_blueprint()` hace hoy para un residencial.
- Toda la nivelación del puesto (relleno del footprint, pilotes de piedra de pesca, cava-rellena de la fachada) entra en la cola de construcción pagada: excavar terreno natural acredita su rendimiento normal (`Recoleccion.rendimiento_de()`, como minar a mano); rellenar cobra 1 tierra por celda; un pilote cobra 5 piedra por celda (es un `bloque_piedra`).
- La plantilla del puesto (`PlantillasPuesto.en_mundo()`, ya con materiales reales — mina en `tierra_compactada`, maderero/caza en `bloque_madera`, pesca en `bloque_piedra`) se surte gradualmente igual que la estructura de un residencial: cada muro/puerta/baúl cobra su costo individual (`NiveladorTerreno.COSTO_POR_CELDA`) al surtirse.
- El puesto se activa (`Recoleccion.colocar_puesto()`/`Economia.registrar_puesto()`) solo al completarse la construcción, no al colocar el fantasma — mientras está a medias no produce ni acepta personal.
- `Player._intervalo_accion_actual()` (el tiempo de excavación igual que minar a mano, ya implementado en esta rama) se aplica igual aquí sin ningún cambio: no distingue puesto de residencial, solo mira el tipo del paso pendiente.
- El drenado de agua bajo la huella sigue siendo instantáneo y gratis al colocar el fantasma (el agua no es un recurso — decisión del usuario).

**Fuera (sin cambios, ya funciona o no aplica):**
- El reembolso al deconstruir un puesto ya completado: `celdas_pagadas` se llena igual que en un residencial durante la construcción, así que `procesar_deconstruccion()`/`_revertir_celda()` (ya arreglado en esta rama) lo reembolsa sin tocar nada más.
- El mecanismo existente de `Economia.desactivar_puesto()`/`reactivar_puesto()` para un puesto YA construido que se empieza a deconstruir y se vuelve a completar antes de terminar de quitarlo (metadata `{"puesto": esquina}`, `Player._completar_construccion()` línea ~1087) — es un camino distinto (puesto preexistente, pausa/reanuda), no se toca.
- La validación de colocación (`_evaluar_puesto()`/`_mensaje_rechazo_puesto()`): sin cambios, sigue corriendo antes de iniciar la construcción fantasma, igual que hoy corre antes de estampar.
- Puestos no soportan excavar terreno alto bajo su propia huella hoy (solo relleno, `nivelador_puesto.calcular_relleno()`, no `calcular_relleno_hasta()` con excavación) — eso no cambia; la excavación pagada solo entra en juego para la fachada (que sí cava/rellena hoy) y para cualquier terreno natural que el pilote/relleno tenga que atravesar.

## 2. `_procesar_clic_puesto()`: de estampado instantáneo a fantasma

Mismo patrón que `_procesar_clic_blueprint()` (`CamaraCenital.gd:2102-2180`):

1. Validar con `_evaluar_puesto()`/`_mensaje_rechazo_puesto()` — sin cambios.
2. Drenar agua bajo la huella y bajo la fachada — instantáneo, gratis, sin cambios.
3. Construir `relleno_orden: Array[Vector3i]` y `tipos_relleno: Dictionary` combinando:
   - El relleno del footprint: para `pesca_frutos_mar`, la lógica actual de pilotes/relleno por columna (`bloque_piedra` en las 2 columnas de pilote, `tierra` en el resto, saltando columnas con agua real) — mismo cálculo de hoy, pero en vez de `mundo.colocar_bloque()` inmediato, cada celda calculada se agrega a `relleno_orden` con su tipo (`"bloque_piedra"` o `"tierra"`). Para los demás puestos, `nivelador_puesto.calcular_relleno(esquina, columnas)` igual que hoy, convertido a `tipos_relleno[celda] = "tierra"` por cada bloque, mismo patrón que usa `_procesar_clic_blueprint()` para su propio relleno.
   - La nivelación de la fachada: mismo cálculo cava-rellena que ya usa `_plan_nivelacion()`/`_despejar_vias_de_fachada()` para un residencial — para un puesto no existe hoy una función compartida, así que se replica el mismo patrón (`_celdas_excavacion`-equivalente para la fachada + `calcular_nivelacion_fachada()`), con `tipos_relleno[celda] = "fantasma"` si la celda cavada también es parte de la plantilla del puesto (no debería ocurrir en la práctica dado que la fachada queda fuera de la huella, pero se mantiene el mismo criterio que residencial por consistencia) o `"aire"` en cualquier otro caso.
4. `orden_estructura`/`tipos_estructura` = `PlantillasPuesto.en_mundo(tipo, giros, esquina, y_base)`, ordenado con `mundo.ordenar_celdas_edificio()` — mismo patrón que residencial.
5. `metadata = {"puesto_nuevo": {"tipo": _tipo_puesto_activo, "esquina": esquina, "ancho": _ancho_puesto_activo, "alto": _alto_puesto_activo, "centro": centro, "centro_agua": centro_agua, "servicio": servicio, "deposito": deposito, "y_base": y_base}}`.
6. `mundo.iniciar_construccion_fantasma(relleno_orden, tipos_relleno, orden_estructura, tipos_estructura, metadata)`.
7. `mundo.registrar_follaje_pendiente(id_edificio, follaje)` con el follaje de huella + fachada (igual que residencial: ya no se borra al instante, desaparece columna por columna según avanza la cola).
8. Notificar "Construcción fantasma del puesto iniciada..." (mismo estilo que el mensaje de residencial).

`Recoleccion.colocar_puesto()`/`Economia.registrar_puesto()` YA NO se llaman aquí.

## 3. Activación al completar (`Player._completar_construccion()`)

Nueva rama, revisada ANTES que la existente `metadata.has("puesto")` (que sigue intacta para el camino de reactivación):

```
if metadata.has("puesto_nuevo"):
	var info: Dictionary = metadata["puesto_nuevo"]
	var centro_agua: Vector2i = info["centro_agua"]
	var entorno: Dictionary = Recoleccion.entorno_de_puesto(info["tipo"], mundo, info["centro"], mundo.altura_en(info["centro"].x, info["centro"].y), centro_agua)
	var tasas: Dictionary = Recoleccion.tasas_de_entorno(info["tipo"], mundo, entorno)
	Recoleccion.colocar_puesto(info["esquina"], info["tipo"], info["ancho"], info["alto"])
	Economia.registrar_puesto(info["esquina"], info["tipo"], info["ancho"], info["alto"], tasas, entorno, info["servicio"], info["deposito"], info["y_base"])
	print("Puesto '%s' construido en (%d, %d)." % [info["tipo"], info["esquina"].x, info["esquina"].y])
	hud.notificar("Puesto construido.")
	return
```

`entorno`/`tasas` se recalculan en este punto (terreno ya construido de verdad), no se guardan del momento de colocar el fantasma — igual de todas formas se recalculan solos cada `TICKS_RECALCULO` (`Economia.gd`), así que el valor inicial no es crítico.

## 4. Pruebas

- `VoxelWorld`/`Construccion`: sin cambios de API, todo lo nuevo aquí es orquestación en `CamaraCenital.gd`/`Player.gd` sobre piezas ya probadas (`_bloqueado_por_falta_de`, `_acreditar_excavacion`, `proximo_paso_pendiente`, `celdas_pagadas`).
- Nueva prueba de integración (estilo `PuestosPrevisualizacionTest.gd`, mundo/cámara sin árbol): construir un puesto simple (p. ej. `maderero`) paso a paso con `iniciar_construccion_fantasma()` + `surtir_construccion()` llamando directo a las piezas de `CamaraCenital`, con fondos limitados, verificando: (a) el puesto NO aparece en `Recoleccion`/`Economia` hasta completarse, (b) cada paso cobra/acredita lo esperado, (c) al completarse, `Recoleccion.colocar_puesto()`/`Economia.registrar_puesto()` corrieron con los datos correctos.
- Verificación manual (Godot 4.7): colocar un puesto de cada tipo (incluida pesca, con pilotes) y confirmar que aparece como fantasma, que hay que surtirlo con clic sostenido, que el almacén sube/baja como se espera, y que el panel de personal no deja asignar trabajadores hasta terminarlo.

## 5. Documentación

Actualizar `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Edificios de Recolección.md` (la construcción instantánea vía `estampar_puesto()` que describe ese documento deja de ser el comportamiento real) y `docs/Fichas_Consumo_Produccion.md` si corresponde alguna nota sobre el costo de construcción de puestos.
