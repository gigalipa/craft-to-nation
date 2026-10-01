# Siderúrgica real (PoC 5, sub-proyecto 2C, parte 2 — primera refinería)

## Objetivo

Convertir la siderúrgica (hierro ×2 → acero ×1) de lógica pura en `CadenaMinerales.gd` a un **edificio real colocable**, con producción, acarreo de ida y vuelta y la primera fuente real de acero. Cierra el pendiente de `bloque_acero`.

Es la primera de cuatro refinerías (siderúrgica, refinería de tierras raras, aserradero, carbonera). Este spec cubre el mecanismo genérico más la siderúrgica de punta a punta; las demás serán entradas de datos sobre el mismo mecanismo, cada una con su propio spec.

## Decisiones del usuario (2026-09-30)

- **Enfoque A:** la siderúrgica es un `tipo` más de `Economia.puestos`; reutiliza registro, cupo, asignación, almacén local, baúl, desactivar al deconstruir, panel y colocación en la cenital.
- **Logística:** almacén local + acarreo, con **viaje de ida y vuelta** de un solo rol de acarreador.
- **Entrada y salida separadas:** las refinerías y edificios de fabricación tienen al menos una entrada y una salida, no una única puerta como los puestos de recolección, porque más adelante se alimentarán con cintas transportadoras y tuberías.
- **`bloque_acero`:** 3 acero por bloque colocado.

## Alcance

Dentro: tipo `siderurgica`, plantilla con entrada y salida, producción por receta, acarreo bidireccional, `bloque_acero`, pruebas, documentación.

Fuera: aserradero, carbonera, refinería de tierras raras, cintas y tuberías (solo se deja la separación entrada/salida preparada), arte definitivo, balance real, energía.

## 1. Edificio

- Tipo `siderurgica`, registrado en `PlantillasPuesto.PLANTILLAS`, con material de muro propio (`bloque_piedra`) y un baúl como almacén local.
- **Entrada y salida:** la plantilla marca dos puertas con caracteres distintos. `d`/`D` sigue siendo la puerta de los puestos; se agregan `e`/`E` (entrada) y `s`/`S` (salida), que producen los mismos bloques `puerta_inferior`/`puerta_superior`. Las puertas se ubican en lados opuestos del edificio.
- API de plantilla: `celda_de_entrada(tipo, giros)` y `celda_de_salida(tipo, giros)`. Para los tipos de recolección ambas devuelven la celda de servicio actual, así que su comportamiento no cambia.
- `Economia.registrar_puesto()` recibe, además de `servicio`, la celda de salida. Para los puestos de recolección entrada y salida coinciden.
- **Fachada y nivelación:** el despeje de puertas y la nivelación se aplican a cada lado donde haya una puerta (entrada y salida), con el mismo criterio de 2 columnas de `PlantillasPuesto.fachada()`. La previsualización marca ambas.
- Costo de construcción, personal máximo y almacén local: los placeholders ya definidos en `CadenaMinerales` (`COSTO_CONSTRUCCION_REFINERIA_HIERRO`, `PERSONAL_MAXIMO_REFINERIA_HIERRO` = 3, `CAPACIDAD_ALMACENAMIENTO_REFINERIA_HIERRO` = 100). Sin balance real todavía.
- Aparece en el submenú Construir de la cenital, con miniatura y la misma previsualización que los puestos.

## 2. Producción

- Cada hora de juego, `Economia.simular_hora()` procesa la siderúrgica activa con `CadenaMinerales.procesar_tick()` sobre su **almacén local**, usando como trabajadores los operarios presentes (rol `recolector`).
- Sin hierro suficiente trabaja menos; con el almacén lleno de acero se frena (el exceso no se produce). Nunca da error ni se bloquea.
- No tiene entorno ni área de acción: no extrae del mundo ni recalcula tasas por entorno. `_extraer()` ya devuelve el valor sin tocar nada para los tipos fuera de `TIPOS_QUE_CONSUMEN`.

## 3. Acarreo de ida y vuelta

Hoy el acarreo es de un solo sentido (puesto → núcleo). Para la siderúrgica el acarreador hace este ciclo:

1. En el núcleo urbano retira hierro del stock central: lo que falte hasta llenar el espacio libre del almacén local, con tope en `Economia.CAPACIDAD_CARGA` (150).
2. Camina a la **entrada** y deposita el hierro en el almacén local.
3. Rodea hasta la **salida** y recoge el acero disponible (con las mismas reglas de carga mínima que `Economia.recoger()`).
4. Vuelve al núcleo y entrega el acero a `Ciudad.almacen` (`Economia.entregar()`).

Si el stock central no tiene hierro, el acarreador igual recoge el acero pendiente. Si no hay nada que mover en ningún sentido, espera sin viajar en vacío.

Es la parte más delicada: extiende la máquina de estados de `Colonos.gd`. El plan debe leerla completa antes de fijar la forma exacta del cambio.

## 4. `bloque_acero`

Nuevo bloque colocable en `NiveladorTerreno.COSTO_POR_CELDA`: **3 acero por bloque**, cobrado de `Ciudad.almacen` al colocar y reembolsado al volver a minarlo, con el mismo mecanismo que `bloque_piedra`/`estructura_hierro`. Se agrega a la hotbar y a los materiales como los demás bloques estructurales.

## 5. Pruebas

- `EconomiaTest`: producción por receta (consume hierro, produce acero), límites (sin insumo, almacén lleno, sin trabajadores), entrada y salida distintas.
- `PlantillasPuestoTest`: celdas de entrada y salida con giros, fachada de ambos lados, tipos de recolección sin cambios.
- `ColonosTest`: ciclo de acarreo de ida y vuelta (retira hierro, deposita, recoge acero, entrega).
- Prueba del costo y reembolso de `bloque_acero`.
- Verificación: `godot/scenes/Test.tscn` más las `*Test.tscn` afectadas (según el criterio del proyecto, solo las relacionadas).

## 6. Documentación a actualizar

- `docs/Pendientes y próximos pasos.md`: ítem 4, parte 2 (siderúrgica hecha; quedan las otras tres).
- `docs/Fichas_Consumo_Produccion.md`: estado de la siderúrgica, `bloque_acero` y la regla de entrada/salida.
- `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Catálogo de Recursos y Cadenas de Producción.md`: decisión funcional (refinerías como puestos con entrada/salida).

## Riesgos

- El ciclo de acarreo bidireccional toca el comportamiento de colonos ya probado; el plan debe cubrirlo con pruebas antes de modificarlo.
- Un solo almacén local compartido por insumo y producto: ambos compiten por la misma capacidad de 100. Aceptado como simplificación inicial; se revisa jugando.
- Las puertas de entrada y salida se usan como puntos de servicio, no como flujo físico para cintas o tuberías; esa integración queda para la fase correspondiente.
