# Edificios de recolección jugables reales (plantillas) — diseño

Fecha: 2026-09-24. Paso 1 de `docs/Pendientes y próximos pasos.md`. Continúa 2A (puestos, producción, acarreo) y 2B (extracción física); precede al HUD y a 2C.

## Objetivo

Que un puesto de recolección deje de ser un slab de bloques marcador y pase a ser un **edificio de bloques con forma propia, puerta de servicio y depósito físico**, que se desactiva al empezar a deconstruirse (igual que un residencial) y que despide a sus recolectores cuando se agota.

Decisiones del usuario (2026-09-24):
- Plantillas **prediseñadas**, una por tipo, colocadas al instante y sin costo (la construcción con costo/obreros es el punto 6 del roadmap).
- Elementos funcionales: forma propia por tipo, puerta de servicio, depósito físico y deconstruible por bloques.
- El arte lo hará el usuario en SketchUp y lo exportará a `.obj`; un conversor offline (paso aparte, fuera de esta spec) generará el mismo formato de datos que las plantillas provisionales escritas a mano aquí.
- Deconstruir: el puesto se **desactiva** en cuanto empieza a deconstruirse, como los residenciales.
- Agotamiento: un puesto sin recurso despide a sus recolectores y conserva a los acarreadores hasta vaciar su almacén local.

Fuera de alcance: costo de construcción y obreros NPC, conversor `.obj`, HUD, edificios de transformación (2C).

## 1. Plantillas (`godot/scripts/PlantillasPuesto.gd`)

Script sin autoload y sin `class_name` (se carga con `preload`), con datos y funciones estáticas. Por tipo (`mina`, `caza_recoleccion`, `maderero`, `pesca_frutos_mar`) guarda **capas** de texto de abajo hacia arriba (la primera es `objetivo + 1`). Cada capa es una lista de filas (eje Z), cada fila un texto con un carácter por columna (eje X):

| Carácter | Bloque |
|---|---|
| `#` | `pared` |
| `V` | `ventana` |
| `B` | `baul` (depósito) |
| `d` / `D` | `puerta_inferior` / `puerta_superior` |
| `.` | vacío |

- Convención: en la plantilla base la puerta mira a −Z (fila superior). `rotar(k)` da la plantilla girada k cuartos de vuelta; el ancho y el alto de la huella se intercambian con k impar.
- Funciones: `celdas(tipo, giros)` → `Dictionary` Vector3i local → tipo de bloque; `huella(tipo, giros)` → `Vector2i` (ancho, alto); `celda_de_servicio(tipo, giros)` → celda exterior (X, Z) local justo frente a la puerta; `celda_deposito(tipo, giros)` → celda local del baúl.
- Validación en la carga (assert en la prueba): la huella coincide con la del tipo (mina 5×5; caza/recolección, maderero y pesca según las constantes vigentes de `CamaraCenital`), hay exactamente una puerta (inferior + superior) y al menos un baúl.
- Plantillas provisionales: una cabaña por tipo sobre su huella actual. En pesca, el edificio ocupa el extremo de tierra y el extremo muelle queda abierto, respetando las dos alturas actuales del extremo edificio.

## 2. Colocación (`CamaraCenital._procesar_clic_puesto`)

- La rotación pasa de un intercambio ancho/alto a un contador de **4 giros** (`Ctrl` + rueda avanza uno). Ancho y alto se derivan de la plantilla girada. La pesca fija su giro para que el edificio caiga en el extremo de tierra (el extremo de agua ya se calcula hoy); el resto de tipos gira libremente.
- Nivelado, drenaje, pilotes, relleno, huella e influencia no cambian.
- El paso que hoy estampa el bloque marcador estampa la plantilla girada sobre `objetivo + 1`.
- **Validación nueva:** cada celda de la plantilla debe estar libre (aire o follaje; el follaje se elimina como hoy). Se reutiliza `verificar_huella_libre` con la altura de la plantilla más `NiveladorTerreno.LIMITE_PENDIENTE`, porque el terreno puede quedar hasta 2 bloques por debajo del nivel objetivo. Corrección del 2026-09-24 tras jugar: los puestos siguen el estilo de los edificios declarados. **Fachada** = las 2 columnas delante de TODO el lado de la puerta (`PlantillasPuesto.fachada()`), que se validan (pendiente sobre huella + fachada, `verificar_huella_libre` a `ALTURA_PUERTA`, sin choque con otros puestos, vías ignoradas) y se **nivelan a la altura del piso de la puerta** al confirmar; y se aplica `verificar_despejes(celdas_plantilla, fachada)`: se reserva el despeje frente a puertas y ventanas y no se invade el de otro edificio.
- El fantasma de colocación sigue mostrando la huella actual; no se previsualizan los bloques de la plantilla.
- Se registra con `mundo.registrar_edificio_completo(celdas_mundo, metadata)` con `metadata = {"puesto": esquina}`, de modo que el puesto tiene `edificio_orden`/`edificio_progreso` y se deconstruye bloque a bloque por el mismo camino que un residencial (revierte a fantasma, se retira al llegar a 0).
- Verificado leyendo el código: hoy un puesto se registra con `registrar_edificio()` sin `edificio_orden`, así que `procesar_deconstruccion` devuelve `{}` y un puesto no se puede deconstruir. Con el registro completo sí. Como `eliminar_edificio` devuelve la esquina mínima de las celdas registradas (que en la pesca puede no ser la esquina del puesto), `Player` toma la esquina de `metadata["puesto"]` antes de eliminar el edificio.

## 3. Desactivar y reactivar por deconstrucción

- `Economia.puestos[esquina]` gana `"activo": true` y `"servicio"` (celda de servicio en el mundo) y `"deposito"` (celda del baúl).
- `Economia.desactivar_puesto(esquina)`: `activo = false`, libera a todos los trabajadores (los devuelve a desempleado, emitiendo la señal de liberación, ver §5) y conserva el almacén local. Se llama desde `Player._procesar_deconstruccion` en el mismo punto y con la misma idempotencia que `Ciudad.retirar_edificio_residencial`, cuando `procesar_deconstruccion` cruza «edificio completo → incompleto» y `metadata["puesto"]` existe.
- `Economia.reactivar_puesto(esquina)`: `activo = true`; se llama al volver a completarse la obra (`_completar_construccion`). Los trabajadores se reasignan a mano desde el panel.
- Mientras `activo == false`: `simular_hora` no produce, `contratar` falla y el panel muestra «Puesto inactivo» con `[+]` deshabilitados.
- Al llegar a 0 bloques se sigue llamando a `Economia.quitar_puesto` (el almacén local se pierde) y a `Recoleccion.quitar_puesto`, como hoy.

## 4. Agotamiento

- Un puesto está **agotado** cuando, tras recalcular sus tasas (`recalcular_tasas`, cada 6 h de juego), todas son 0. Aplica a cualquier tipo, no solo a minas y madereros.
- Al agotarse: se liberan **todos los recolectores** (vuelven a desempleado) y se conservan los acarreadores.
- Los acarreadores siguen ciclando mientras quede algo en el almacén local. Cuando el almacén local queda vacío (y el puesto está agotado), se liberan también.
- El puesto agotado no se elimina: sigue en pie, con `[+]` de recolectores deshabilitado, y el panel indica «Agotado». Si más adelante la tasa vuelve a ser mayor que 0 (p. ej. crece un árbol), deja de estar agotado y el jugador contrata a mano.
- `Economia.recoger` ya devuelve el resto de un puesto que no produce (carga parcial sin recolectores presentes), así que un almacén con resto sale sin cambios en esa función.
- Un acarreador que ya lleva carga al núcleo termina su viaje y entrega antes de quedar libre (no se le retira la carga), aunque el puesto se desactive o desaparezca entretanto.
- Los acarreadores se liberan al vaciarse el almacén local en el siguiente `simular_hora` (no dentro de `recoger`, para no soltar a quien acaba de recibir su carga).

## 5. Puerta de servicio y depósito

- `Economia.registrar_puesto` recibe `servicio` (celda X,Z de servicio en el mundo) y `deposito` (celda 3D del baúl).
- Los colonos **entran al edificio por la puerta** (corrección del 2026-09-24 tras jugar: la primera versión los dejaba esperando fuera). Prefieren las celdas libres del piso interior (`suelo` = altura de la capa 0; las más alejadas de la puerta primero, para no taponar la entrada) y, si no caben, esperan en una **zona de servicio**: las celdas transitables a distancia de Chebyshev ≤ 2 de la celda de servicio, fuera de la huella y sin contar la propia celda frente a la puerta (constante `RADIO_SERVICIO`). Una sola celda no basta: `Colonos.ocupadas` no admite dos colonos en la misma celda y un puesto tiene hasta 7 trabajadores. Recolector «presente» = en el piso interior (no parado en la puerta) o en esa zona. Si no es alcanzable, espera y reintenta como hoy. La celda de servicio debe estar a la altura de la puerta o 1 bloque más abajo (validado al colocar).
- Nueva señal `Economia.trabajadores_liberados(ids)`, conectada al mismo `_on_puesto_quitado` de `Colonos` (que ya devuelve a desempleado a cada id). La usan la desactivación y el agotamiento.
- **Depósito interactivo:** la tecla `E` (que ya recolecta frutos) apuntando al baúl del puesto transfiere al inventario del avatar lo que quepa del almacén local; lo que no cabe se queda en el puesto (nada se pierde).

## 6. Pruebas y documentación

Pruebas (GDScript, en español, con tabulaciones):
- `PlantillasPuestoTest` (nueva): huella por tipo, puerta y baúl presentes, rotación de 4 giros, celda de servicio fuera de la huella y frente a la puerta.
- `EconomiaTest` (ampliada): desactivar/reactivar, sin producción inactivo, agotamiento libera recolectores y conserva acarreadores, libera acarreadores al vaciarse el almacén, un puesto no agotado no libera a nadie.
- `ColonosTest` (ampliada): destino = celda de servicio; recolectores liberados por agotamiento vuelven a desempleado.

Ejecución obligatoria: `godot/scenes/Test.tscn` más las `*Test.tscn` afectadas, con Godot 4.7.

Documentación: nuevo documento técnico `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Edificios de Recolección.md`; actualizar la Sección 3 del GDD («Área de Acción de los Puestos de Recolección») y `docs/Pendientes y próximos pasos.md` (mover el punto 1 a «Hecho»).

## Riesgos y supuestos

- Altura de las plantillas sobre terreno accidentado: se valida que sus celdas estén libres tras nivelar; si choca con relieve, la colocación se rechaza con mensaje.
- Los puestos ya colocados antes de este cambio (guardados en escena) siguen siendo el slab antiguo: `Economia` acepta puestos sin `servicio`, en cuyo caso `Colonos` usa el anillo como hasta ahora.
- Balance, cupos y tasas no cambian.
