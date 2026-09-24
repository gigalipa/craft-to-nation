# Diseño: PoC 5, sub-proyecto 2B — Extracción física y agotamiento

Contexto: GDD Sección 3 ("Área de Acción de los Puestos de Recolección") y Sección 4 (catálogo de recursos). La fase 2A (`PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Fase 2A - Puestos, Producción y Acarreo.md`) hizo que los cuatro puestos produzcan y acarreen recursos, pero sus tasas se fijan al colocar el puesto: el entorno nunca se consume. 2B hace que los puestos consuman de verdad el mundo, recalcula sus tasas, y le da al avatar una recolección propia (minado con tiempo, tala, frutos) con un inventario limitado que arranca la partida.

Decisiones confirmadas con el usuario (2026-09-24), en orden de aparición durante el brainstorming.

## 1. Alcance

**Dentro:**
1. Extracción física por los puestos (consumo abstracto por tick) y agotamiento.
2. Recálculo periódico de las tasas de cada puesto según el entorno.
3. Recolección del avatar: minado con tiempo por bloque, tala, recolección de frutos, y un indicador de avance en el HUD.
4. Inventario del avatar (= `Ciudad.almacen`) con topes iniciales bajos, ampliación al declarar el núcleo y ampliación por baúles de los edificios residenciales.
5. Arranque de partida: el primer edificio declarado es el núcleo urbano y no cuenta camas; llegan colonos con el siguiente edificio residencial.

**Fuera (documentado, no se construye):**
- Bomba extractora y petróleo: ni el edificio ni el recurso existen en el mundo (sub-proyecto de fluidos, punto 6 de `docs/Pendientes y próximos pasos.md`). Solo queda la regla.
- Costo de construcción en unidades de recurso (por ejemplo 5 de piedra por pared) y el consumo de tierra 1-1-1 al construir. La distinción de tres capas (bloque de extracción → unidades de recurso → bloque de construcción) se documenta para cuando exista ese cobro.
- Herramientas del avatar (el multiplicador de herramienta queda fijo en 1).
- Caza y pesca manual del avatar (solo frutos por ahora).
- Conexión del indicador de avance con la **construcción** por fantasmas (flujo por fases, aparte).
- Animación del colono junto al bloque que se agota, y arte del indicador (barra plana en HUD, sin shader de grietas).

## 2. Modelo de recursos

Tres capas: **bloque de extracción** (lo que se retira del mundo), **unidades de recurso** (lo que entra al almacén) y **bloque de construcción** (lo que se coloca; su cobro queda fuera de 2B).

`Recoleccion.RENDIMIENTO_POR_BLOQUE` (placeholder, ajustable):

| Bloque | Unidades |
|---|---|
| Piedra, hierro, cobre, carbón, tierras raras | 10 |
| Tronco (por celda de tronco, ya coincide con la salud del árbol) | 10 |
| Tierra (incluye la capa `piso`, ver `VoxelWorld.material_real`) | 1 |
| Agua y petróleo | 2 (reservado, sin uso en 2B) |

La hoja `Relacion` de `docs/Recursos.xlsx` guardaba 5 por bloque (líquidos 2, tierra 1). Ya se actualizó (2026-09-24, con autorización del usuario): sólidos y tronco a 10 en las columnas O a T, tierra 1 y líquidos 2 sin cambios. Además hay una hoja nueva, `Extraccion`, con la tabla por recurso de las tres capas (bloque de extracción → unidades por bloque extraído → unidades que consume el bloque de construcción, con la piedra a 5 y la tierra 1-1-1 como propuesta y el resto por definir) y su explicación. La hoja `Economia` (límites y comida inicial) se actualiza al implementar la sección 6, cuando se fijen los valores.

## 3. Extracción de los puestos (consumo abstracto)

La producción sigue como en 2A (recolectores presentes × tasa por hora). Lo nuevo es que cada unidad producida se descuenta del entorno:

- Cada puesto guarda, por recurso, un **bloque en curso** `{celda, restante}`. Cada hora, las unidades producidas se restan de `restante`. Al llegar a 0 el bloque se retira del mundo (`VoxelWorld._retirar_bloque`, sin las guardas de `minar_bloque`) y se elige el siguiente. Un tick puede agotar varios bloques.
- Si el área no tiene más material de ese recurso, el puesto deja de producirlo (la producción se acota a lo disponible).
- Los bloques puestos por el jugador y los de un edificio nunca cuentan (`es_terreno_natural`).

Por tipo:

- **Mina.** Solo bloques del mineral correspondiente dentro de su elipsoide (`detectar_recursos`), a partir de la profundidad `GROSOR_TIERRA - 2` bajo la superficie de cada columna (con `GROSOR_TIERRA = 4`: profundidad 2 en adelante). Las profundidades 0 y 1 quedan intactas para que el terreno no quede flotando. Se elige primero el bloque más cercano al centro del puesto y, a igual distancia, el menos profundo.
- **Maderero.** Tala árboles enteros dentro de su radio (12). Reutiliza `GeneradorArbol.danar`: la salud del árbol es su cantidad de celdas de tronco y cada punto rinde 10 de madera. Al agotarse se borra el árbol completo (`talar_bloque_de_arbol`).
- **Caza/recolección.** No consume nada. Su tasa (fauna y frutos) se multiplica por `árboles vivos en el área / árboles al colocar el puesto`, con tope 1: la fauna y los frutos dependen del bosque, así que talarlo los reduce. El puesto guarda el número de referencia al colocarse.
- **Pesca.** No consume bloques. Se recalcula con `celdas_agua_conectadas` y su escala por tamaño. Nota: en 2B el recálculo lee el mapa de agua generado, no el agua real; que drenar o conectar agua cambie la tasa queda pendiente (la plataforma y los pilotes del propio puesto están sobre su agua y confundirían a un lector de vóxeles).
- **Bomba extractora (futuro).** Su tasa dependerá de los bloques de petróleo del pozo bajo ella.

## 4. Recálculo periódico

`Economia` recalcula las tasas de cada puesto cada `TICKS_RECALCULO` ticks (placeholder: 6 horas de juego), con las funciones `detectar_*` de `Recoleccion`.

- La lógica de `CamaraCenital._tasas_de_puesto` (`CamaraCenital.gd:1759`) pasa a `Recoleccion`, para que la usen la cenital (al previsualizar y colocar) y `Economia` (al recalcular). La cenital pasa a llamar a esa función.
- `Economia` recibe el mundo por inyección (como hoy recibe `ciudad`), para probarla sin escena.

## 5. Recolección del avatar

Una sola función de extracción en `VoxelWorld` (`{recurso, unidades}` de una celda según la tabla) la usan el avatar y los puestos.

- **Minado con tiempo.** Tiempo = `TIEMPO_MINADO[tipo] × multiplicador_herramienta` (constante 1). Se completa manteniendo el clic sobre el mismo bloque; si se suelta o se apunta a otro, el avance vuelve a 0 (como Minecraft). Al completarse, el bloque se retira y sus unidades entran al inventario. Se puede minar en cualquier profundidad (la restricción de subsuelo es solo de las minas).
- **Bloques colocados por el jugador y agua/bedrock/edificios:** sin rendimiento (para que colocar y minar en bucle no cree recursos, hoy colocar es gratis) o no minables como hasta ahora.
- **Tala.** Cada `TIEMPO_TALA_POR_SALUD` segundos de golpes sostenidos resta 1 de salud al árbol y rinde 10 de madera. El daño se conserva al soltar (la salud del árbol ya persiste); el indicador muestra la salud restante. Al llegar a 0 cae el árbol entero.
- **Frutos.** Acción de interactuar sobre un árbol (la tecla se define en el plan, sin chocar con minar/colocar). Muestra el indicador y rinde `COMIDA_POR_RECOLECCION × densidad_frutal_en(x,z)`. No consume el árbol: queda sin frutos `HORAS_REBROTE` horas de juego (diccionario id de árbol → hora de rebrote en `VoxelWorld`).
- **Indicador de avance.** Nodo en el HUD con `mostrar(fraccion, sentido)` y `ocultar()`, reutilizable. En 2B lo usan el minado, la tala, los frutos y la deconstrucción (reutiliza el contador de `TICKS_REMOCION_FINAL`, que hoy ya existe).

Todos los tiempos, `COMIDA_POR_RECOLECCION` y `HORAS_REBROTE` son placeholders de balance.

## 6. Inventario y arranque de partida

El inventario del avatar es `Ciudad.almacen`, sin estructura nueva.

**Límite de un recurso** = `(base × factor_nucleo) + baúles_registrados × BONO_BAUL`.

| Concepto | Recursos | Comida |
|---|---|---|
| Base inicial | 500 | 5000 |
| Factor tras declarar el núcleo | ×2 | ×2 |
| Bono por baúl de un edificio residencial | +100 | +400 |

- El límite se recalcula al declarar el núcleo (`Ciudad.ampliar_almacen()`, idempotente, llamado desde donde hoy se llama `Zonificacion.declarar_nucleo`) y cuando se registra o retira un edificio con baúles. Los baúles de cada edificio se cuentan al completarse y se restan al empezar su deconstrucción, igual que las camas (`registrar_edificio_residencial`/`retirar_edificio_residencial`).
- Si el límite baja por deconstruir, el stock que ya excede se conserva (no se destruye), pero no entra nada nuevo hasta bajar del límite.
- Stock inicial: madera 200 y hierro 50 se mantienen; la comida baja de 10000 (placeholder documentado hasta que hubiera producción de comida) a un valor `COMIDA_INICIAL` acorde al tope de 5000. Como el avatar consume 5/h y un tick de 2 s es 1 h, cada 1000 de comida duran ~7 minutos reales, así que este número es la principal perilla del arranque.

**Núcleo y colonos.**
- El primer edificio declarado (`Player._declarar_edificio`) crea el núcleo urbano (`Zonificacion.declarar_nucleo`) y **no** registra camas: el núcleo no es habitable, así que no llegan colonos.
- El siguiente edificio residencial declarado (zona A, blueprint, construido) es el primero que registra camas, y con él llegan los primeros colonos.
- **Baúles del núcleo:** no suman al límite (confirmado 2026-09-24). Solo cuentan los baúles de los edificios residenciales posteriores al núcleo.

## 7. Componentes y archivos

- `Recoleccion.gd`: `RENDIMIENTO_POR_BLOQUE`, funciones de tasas trasladadas desde `CamaraCenital`, selección de bloques de una mina, `TICKS_RECALCULO`.
- `Economia.gd`: bloque en curso por recurso, consumo, recálculo periódico, mundo inyectable.
- `Ciudad.gd`: topes y stock iniciales, `ampliar_almacen()`, baúles por edificio, núcleo sin camas.
- `VoxelWorld.gd`: función de extracción compartida, rebrote de frutos, minado y tala por tiempo.
- `Player.gd`: minado/tala/frutos por tiempo con reinicio, núcleo sin camas, deconstrucción con indicador.
- `CamaraCenital.gd`: usa las funciones de tasas de `Recoleccion`.
- `HUD.gd` + nodo nuevo para el indicador de avance.

Cada archivo conserva sus responsabilidades actuales (`Economia` no toca el mundo directamente: pide a `Recoleccion`/`VoxelWorld` a través de la inyección). No se mezclan PoC ni se reformatea código ajeno.

## 8. Pruebas

Se siguen los patrones existentes (escenas `*Test.tscn` con dobles falsos donde ya se usan). Se ejecuta `godot/scenes/Test.tscn` y solo las escenas afectadas.

- `EconomiaTest`: descuento del bloque en curso, un tick que agota varios bloques, agotamiento total (producción 0), recálculo cada `TICKS_RECALCULO`, caza/recolección que baja con menos árboles (la pesca contra el agua real no se probó en 2B).
- `RecoleccionTest`: rendimiento por bloque, selección de mina desde profundidad 2 (nunca 0 ni 1), orden de elección (cercano y menos profundo), bloques puestos por el jugador excluidos.
- `CiudadTest`: topes iniciales, `ampliar_almacen()` idempotente, bono por baúles al registrar y retirar, stock que excede el límite tras bajar (núcleo sin camas y primer residencial con camas: solo verificación manual).
- Pruebas de mundo: extracción por tipo, tala parcial con daño conservado, rebrote de frutos.
- Prueba del contador de progreso (avance, reinicio al soltar o cambiar de bloque, indicador hacia atrás en la deconstrucción).
- Verificación manual (Godot 4.7): minar y talar con barra, frutos, jugada completa desde la partida vacía hasta la llegada de los primeros colonos, y ver bajar la tasa de un maderero al talar su bosque.

## 9. Documentación

- Documento técnico nuevo `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Fase 2B - Extracción Física y Agotamiento.md`.
- Ajustes al de la fase 2A (deja de ser cierto que las tasas no se recalculan), al GDD (Sección 3, el aviso de "sin extracción física ni agotamiento", y el arranque de partida de la Fase 1) y a `docs/Pendientes y próximos pasos.md`, que se marca como hecho al terminar y solo entonces (hoy tiene cambios sin commitear del usuario).

## 10. Orden de implementación sugerido

Si el plan resulta largo, se divide en tandas dentro de este mismo spec:
1. Modelo de recursos, extracción y recálculo de los puestos (secciones 2 a 4).
2. Inventario, baúles y arranque de partida (sección 6).
3. Indicador de avance, minado/tala por tiempo y frutos del avatar (sección 5).
