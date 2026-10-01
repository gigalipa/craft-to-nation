# Escuela técnica (PoC 5, sub-proyecto 2C, formación de técnicos)

## Objetivo

Reemplazar la conversión provisional "desempleado → técnico al asignarlo a una refinería" por una **formación real**: un edificio nuevo, la **Escuela técnica**, donde obreros estudian y salen técnicos. Es el primer edificio de la categoría Investigación (menú Construir, hoy vacía).

## Decisiones del usuario (2026-10-01)

- **Edificio real** con plantilla de bloques, como la siderúrgica: un `tipo` más de `Economia.puestos`, que reutiliza registro, cupo, asignación, presencia, panel y colocación en la cenital.
- **Zona:** se coloca dentro de la zona de influencia y con toda la huella sobre **zona residencial** (`residencial_investigacion`), no sobre industrial. Es el primer edificio de investigación.
- **Rol `aprendiz`:** se asigna desde el panel del puesto («Aprendices»). Camina a la escuela y, mientras está presente, acumula horas de juego; a las **24 h** (placeholder) queda listo.
- **Conversión no 1:1:** cada jerarquía ocupa más espacio habitable (`Ciudad.TIPOS_POBLACION[...]["x_cama"]`), así que la formación conserva la vivienda ocupada para no desahuciar a nadie. Una **cohorte de 4 obreros** (1/4 de vivienda cada uno = 1 unidad) sale como **3 técnicos** (1/3 cada uno = 1 unidad); el cuarto colono sale de la ciudad. La población baja en 1, pero no hace falta construir vivienda nueva. Cohorte de entrada = `x_cama` del origen; salida = `x_cama` del destino.
- **Técnico libre:** un técnico sin empleo sigue siendo técnico (no vuelve a desempleado) al despedirlo o al deconstruir su refinería. Las refinerías contratan solo técnicos libres; ya no convierten desempleados.
- **Trabajo de obra:** los técnicos libres podrán trabajar en obras de construcción, demolición y tendido de vías como los obreros desempleados. Hoy esos trabajos no los hacen colonos (punto 6 de los pendientes); la regla aplica cuando exista. Sin código nuevo en este sub-proyecto.
- **Alcance:** solo la escuela técnica. Especialistas, niveles de edificio, jerarquía de empleo y universidad quedan en `docs/ideas-backlog.md`.

## Alcance

Dentro: tipo `escuela_tecnica`, plantilla, rol `aprendiz`, formación por presencia, graduación por cohorte, técnico libre, notificación, miniatura y botón en Construir → Investigación, pruebas, documentación.

Fuera: especialistas y su escuela (que solo admitirá técnicos desempleados), consumo de recursos para formar, arte definitivo, niveles de edificio, universidad, trabajo de obra de colonos.

## 1. Edificio

- Tipo `escuela_tecnica` en `PlantillasPuesto.PLANTILLAS`: una sola puerta (`d`/`D`, como los puestos), espacio interior para 4 aprendices y un baúl que no se usa (mismo contrato de plantilla). Material de muro propio provisional. El tamaño y la forma se fijan en el plan, con la plantilla actual de la siderúrgica o de un puesto como punto de partida.
- Cupo: **4** (`Recoleccion.cupo_de`). Almacén local: no aplica; se registra con la capacidad mínima que el contrato exige.
- **Zona:** la validación de `CamaraCenital._evaluar_puesto()` hoy distingue «refinería» de «puesto periférico». Se añade el caso escuela: dentro de la zona de influencia (`Zonificacion.dentro_de_influencia`) y huella sobre `ZONAS_PINTABLES[0]` (residencial), con mensajes de rechazo propios. `_huella_en_zona_correcta()` ya recibe la zona como parámetro.
- **Costo de construcción:** placeholder en materiales crudos, definido en el plan (sin balance real).
- Aparece en la categoría Investigación de `BarraModos.gd` (hoy `[]`), con miniatura (`TIPOS_CON_MINIATURA`) y la misma previsualización que los demás puestos.
- Deconstruirla libera a sus aprendices: vuelven a obrero sin formar (ver §3). Pierden el progreso.

## 2. Formación

- `Economia.ROLES` gana `aprendiz`. Como el técnico, comparte la lista `recolectores` del puesto (presencia y cupo funcionan igual). `asignar()` solo admite `aprendiz` en una escuela y rechaza `recolector` y `tecnico` ahí.
- Cada puesto escuela guarda `progreso`: id de aprendiz → horas acumuladas. `Economia.simular_hora()` suma 1 hora a cada aprendiz **presente**; fuera de la escuela no avanza. A `HORAS_FORMACION` (24) el aprendiz queda **listo**: sigue ocupando su plaza y esperando dentro, sin avanzar más.
- **Graduación por cohorte:** cuando hay tantos aprendices listos como `x_cama` del origen (4), se gradúa la cohorte: 3 pasan a técnico libre y el cuarto sale de la ciudad. Esto toca `Ciudad.demografia` (`obrero` −4, `tecnico` +3) y los colonos a la vez (ver §3); los tres técnicos nuevos quedan sin empleo y sus plazas se liberan. Se emite una notificación «Se formaron 3 técnicos» (vía el panel de notificaciones existente).
- Con menos de 4 aprendices listos no se gradúa nadie y esperan; el panel muestra «listos / cohorte».
- Datos en una constante junto a `CadenaMinerales`/`Economia` (`ESCUELAS := {"escuela_tecnica": {"origen": "obrero", "destino": "tecnico"}}`), de modo que una escuela de especialistas sea una entrada más (`tecnico` → `especialista`, 3 → 2). `HORAS_FORMACION` es común por ahora.

## 3. Técnico libre y colonos

- **Contratar aprendiz:** `Colonos.contratar(esquina, "aprendiz")` toma un desempleado, lo pasa a obrero (como el acarreador) y lo asigna a la escuela.
- **Contratar técnico (refinería):** `Colonos.contratar(esquina, "tecnico")` toma un **técnico libre** (tipo `tecnico`, sin trabajo; el de id menor) en vez de un desempleado, y ya no llama a `ciudad.reasignar_tipo`. Sin técnicos libres devuelve falso; el panel muestra «No hay técnicos libres» en vez del mensaje de falta de desempleados.
- **Despedir y deconstruir:** `_volver_a_desempleado()` conserva el tipo `tecnico` cuando el colono ya era técnico (no llama a `reasignar_tipo`); los obreros siguen volviendo a desempleado. Aplica a `despedir()`, `_on_puesto_quitado()` y `_on_trabajadores_liberados()`.
- **Graduación en colonos:** `Colonos` recibe la cohorte, cambia 3 colonos a `tecnico` (sin trabajo ni carga, `economia.liberar`) y retira el cuarto con `_retirar()`; `Ciudad.demografia` se ajusta en el mismo paso para que `reconciliar()` no cree ni retire colonos de más.
- **Despedir un aprendiz** (listo o no) lo devuelve a desempleado sin formación y reinicia su progreso.
- **Alimentación:** un técnico libre consume lo mismo que un técnico empleado (la tabla de población ya no distingue empleo).

## 4. Panel y ventanas

- `PanelPuesto.gd`: para una escuela, el rol de producción es «Aprendices» y muestra el progreso de cada uno (horas / 24) y «listos / cohorte»; el panel de refinería «Técnicos» muestra la falta de técnicos libres.
- `VentanaPoblacion.gd`: la fila del puesto escuela dice «aprendices».
- `ColonosRenderer.gd`: el color de `tecnico` ya existe; un aprendiz usa el de `obrero`.

## 5. Pruebas

- `EconomiaTest`: el progreso solo avanza con el aprendiz presente; a 24 h queda listo; con 4 listos se gradúa la cohorte (obrero −4, tecnico +3, vivienda ocupada igual); con menos de 4 no hay graduación; cupo 4; rol `aprendiz` solo en escuela, `tecnico` solo en refinería.
- `ColonosTest`: contratar aprendiz; contratar técnico exige un técnico libre y no convierte desempleados; despedir o deconstruir una refinería deja al técnico como técnico libre; despedir un aprendiz vuelve a desempleado; graduación (3 técnicos, 1 retirado, `Ciudad.demografia` coherente).
- `PlantillasPuestoTest`: plantilla, puerta, fachada y giros de la escuela.
- Prueba de zona en la evaluación de colocación (residencial dentro de la influencia; rechazo fuera de la influencia y sobre industrial).
- Verificación: `godot/scenes/Test.tscn` más las `*Test.tscn` afectadas (solo las relacionadas, según el criterio del proyecto).

## 6. Documentación a actualizar

- `docs/Pendientes y próximos pasos.md`: ítem 4 (formación de técnicos hecha); el ítem de «Construcción asistida por NPCs» anota que los técnicos libres también hacen obras.
- `docs/Fichas_Consumo_Produccion.md`: origen de los técnicos (ya no provisional), regla de conversión por `x_cama`.
- `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Catálogo de Recursos y Cadenas de Producción.md`: decisión funcional (escuela, técnico libre, cohorte).
- `docs/ideas-backlog.md`: jerarquía de empleo, niveles de edificio y universidad (ya añadido).

## Riesgos

- **Cohortes incompletas:** si el jugador asigna menos de 4 aprendices, esperan indefinidamente. Se acepta; el panel lo muestra. Alternativa futura: graduar fracciones acumulando vivienda.
- **Pozo de desempleados:** los aprendices salen del mismo pozo que los obreros y, mientras estudian, no producen; formar muchos puede dejar sin colonos a los puestos. Y cada cohorte reduce la población en 1.
- **Sin escuela no hay refinerías operando:** a diferencia del placeholder anterior, es una dependencia nueva a propósito (el jugador debe construir la escuela y formar antes de operar una siderúrgica). Las partidas ya empezadas con refinerías ocupadas conservan sus técnicos actuales; un técnico despedido pasa a técnico libre.
- **Plantilla y costo** son provisionales hasta el arte de SketchUp.
