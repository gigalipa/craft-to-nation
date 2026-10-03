# Niveles de puesto y empleo por tipo — Especificación de diseño

Fecha: 2026-10-02. Puntos 2, 3 y 6 de la sección 4b de `docs/Pendientes y próximos pasos.md`. Idea de origen: «Jerarquía de empleo, niveles de edificio e investigación en universidad» de `docs/ideas-backlog.md` (aquí solo la parte de empleo y niveles; la universidad y la investigación quedan fuera).

## Objetivo

Que un puesto de recolección siga siendo útil tras agotar su volumen básico, y que el jugador elija qué tipo de colono trabaja en él. Hoy el panel solo habla de «desempleados libres», aunque haya técnicos sin empleo.

## Decisiones del usuario

- El nivel **sube solo según quién trabaja** (sin costo ni investigación; la universidad se añadirá después sin rehacer esto).
- El panel del puesto tiene **una fila -/+ por tipo admitido** (Obreros, Técnicos, Especialistas) más Acarreadores.
- Tienen niveles solo los 4 puestos de recolección: mina, caza y recolección, maderero y pesca y frutos del mar. Refinerías, aserradero, carbonera y escuela siguen sin niveles.
- Mina: franjas volumétricas por nivel. Caza, maderero y pesca: franjas de área (anillos) y multiplicador de velocidad.
- Anillos de +50 % del radio base por nivel; velocidad ×1 / ×1,5 / ×2.
- La mina no tiene multiplicador de velocidad.

## Modelo de niveles

- **Rango de oficio:** obrero = 1, técnico = 2, especialista = 3.
- **Nivel del puesto** = rango mínimo entre sus **recolectores**. Los acarreadores no cuentan (son siempre obreros y fijarían todos los puestos en nivel 1). Sin recolectores, el puesto conserva su último nivel; el inicial es 1.
- **Admisión:** se puede contratar un tipo de rango igual o superior al nivel actual. Un obrero no entra a un puesto de nivel 2. Los especialistas entran a un puesto de nivel 1 (un puesto con solo especialistas arranca en nivel 3).
- **Recálculo inmediato:** contratar o despedir recalcula el nivel y, si cambia, reevalúa de inmediato el área, la tasa y el agotamiento (sin esperar el recálculo de 6 h).
- **Agotamiento «a su nivel actual»:**
  - Al agotarse, se despide solo a los recolectores del rango mínimo; los demás siguen y el nivel sube (con técnicos restantes, a nivel 2), el área crece y se reevalúa el agotamiento.
  - Un puesto agotado sin recolectores conserva su nivel y solo admite rangos superiores a él.
  - Agotado en nivel 3: despide a todos, como hoy.
  - Se conserva el umbral de madereros agotados (`UMBRAL_AGOTADO_MADERERO`, 0,5 madera/h).

### Franjas y velocidad

| Puesto | Nivel 1 | Nivel 2 | Nivel 3 | Velocidad |
|---|---|---|---|---|
| Mina | profundidad 0–8 | 8–16 | 16–24 | sin multiplicador |
| Caza y recolección, maderero | radio 12 | anillo 12–18 | anillo 18–24 | ×1 / ×1,5 / ×2 |
| Pesca y frutos del mar | radio 25 | anillo 25–37 | anillo 37–50 | ×1 / ×1,5 / ×2 |

- La mina ya define estas profundidades (`Recoleccion.PROFUNDIDAD_MINA_NIVEL_1/2/3`) y `detectar_recursos(..., profundidad, profundidad_minima)` ya acepta una franja.
- **Área de trabajo acumulada:** en nivel N el puesto trabaja la unión de las franjas 1..N. Las franjas por separado solo se usan para mostrar información (tarjeta de la mina).
- El multiplicador de velocidad escala la tasa de producción del puesto; no cambia el cupo.

## Empleo por tipo (`PanelPuesto`)

- Una fila -/+ por tipo: Obreros, Técnicos, Especialistas; la de Acarreadores se conserva.
- Cada fila muestra cuántos libres de ese tipo hay y se deshabilita si el nivel actual no admite el tipo, si no hay cupo, o si el puesto está inactivo.
- Libres: desempleados (se convierten en obreros al contratarlos), `Colonos.tecnicos_libres()` y especialistas libres (0 hasta que exista su escuela).
- La fila de Especialistas solo aparece si hay alguno, empleado o libre.
- El título muestra el nivel («Mina, nivel 2»); la línea «Desempleados libres» desaparece.
- `Colonos.contratar(esquina, rol)` y `Economia.asignar` aceptan el tipo; `Economia.roles_de` incluye «especialista» en los puestos con niveles.
- Las refinerías siguen exigiendo técnicos libres y no cambian.

## Tarjeta de la mina (punto 6)

Al activar la herramienta de la mina, la tarjeta lista los recursos aproximados por nivel con la franja de ese nivel únicamente (sin sumar los anteriores), omitiendo los que den menos de 0,3/h. Se calcula como diferencia de `detectar_recursos_extraibles` entre profundidades consecutivas (`Recoleccion.tasas_mina_por_nivel`). Motivo: minas sobre trazas de hierro tan bajas que no recolectan nada.

## Casos límite

- Puesto con obreros y un técnico: nivel 1 (manda el mínimo); para subir hay que despedir a los obreros.
- Despedir al último técnico de un puesto de nivel 2 sin más recolectores: conserva el nivel 2.
- Subir de nivel por contratar: la tasa y el área se recalculan en ese momento.
- Una partida guardada o puesto existente sin nivel se trata como nivel 1.

## Pruebas

- `EconomiaTest`: nivel derivado del personal, admisión por rango, agotamiento por nivel (se despide al rango mínimo y el nivel sube), multiplicador y franjas por puesto.
- `ColonosTest`: contratar por tipo (obrero desde desempleados, técnico desde libres) y rechazo de un tipo no admitido.
- `HUDTest`: filas del panel por tipo y nivel en el título; tarjeta de la mina con franjas por nivel.

## Fuera de alcance

Escuela de especialistas, universidad e investigación, niveles de refinerías y demás edificios, bloques de trabajo por oficio, y multiplicador de velocidad en la mina.

## Documentación a actualizar al implementar

`docs/Pendientes y próximos pasos.md` (marcar los puntos 2, 3 y 6 de la sección 4b), el documento técnico de PoC 5 (Fase 2A: puestos) y la entrada correspondiente de `docs/ideas-backlog.md`.
