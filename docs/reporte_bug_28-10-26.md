# BUGS (TODOS CORREGIDOS):
1. [x] La ventana se ve sobre el overlay de bloque apuntado cuando se visualiza de lado. De frente no se ve el bug.
   - *Solución:* En `godot/scripts/CaraApuntada.gd` se configuró `render_priority = 3` para garantizar el renderizado del overlay sobre mallas translúcidas.
2. [x] Si un edificio residencial está declarado como No colonizable y llegan ciudadanos nuevos por encima del límite de camas disponibles, los nuevos ciudadanos pasan a ser "Sin techo", sin embargo, en el edificio se muestra como que tiene un residente y al activarle el estado de colonización el colono no cambia de estado a "Desempleado".
   - *Solución:* En `godot/scripts/Ciudad.gd` se implementó `_alojar_sin_techo()` en `alternar_colonizable()` y al vencer la cuenta de 24h. En `godot/scripts/Colonos.gd` los nuevos colonos sin cama inician con hogar `-1` sin ocupar edificios no colonizables.
3. [x] Al activar el modo de remodelación de un edificio habitado, sin suficientes camas disponibles, los residentes fueron deshauciados y marcados como "Sin techo" por lo que no pudieron trabajar, sin embargo, al revisar el puesto periférico donde estaban empleados seguían apareciendo como empleados. Luego, al redeclarar el edificio residencial como habitable, el puesto mostraba 2 ciudadanos libres (desempleados) pero no descontó a los que habían sido desahauciados en un principio. Es necesario que al actualizarse el estado de un colono, también se actualice el estado del puesto o industria en el que esté contratado.
   - *Solución:* En `godot/scripts/FinalizacionObras.gd` se invoca `Colonos.reconciliar()` tras `reubicar_por_remodelacion()`. En `godot/scripts/Colonos.gd` se libera automáticamente el puesto con `Economia.liberar()` al pasar a desempleado o perder el hogar.
4. [x] Al construir un edificio con ventanas de techo a partir del blueprint, las ventanas no se colocan automáticamente en el estado de "techo" sino que quedan en formato vertical.
   - *Solución:* Captura, rotación y aplicación de `orientaciones_3d` en `BlueprintValidator.gd`, `CamaraCenital.gd`, `Player.gd` y `VoxelWorld.gd` (`_reemplazar_celda()` con orientación persistida).
5. [x] La herramienta de demolición desde la vista cenital no tiene función de desmarcar una vía que haya sido marcada para demolición.
   - *Solución:* En `godot/scripts/CamaraCenital.gd` y `godot/scripts/Obras.gd` se agregó `cancelar_demolicion_via()` permitiendo alternar y desmarcar vías en demolición al hacer clic.
6. [x] La herramienta de interacción con vías de la 1era persona no permite interactuar con el marcaje de las vías en demolición.
   - *Solución:* En `godot/scripts/Player.gd` (modo V) clic izquierdo avanza la demolición si la celda está en demolición y clic derecho alterna la marca de demolición de la vía.
7. [x] Al marcar un edificio para demolición desde la vista cenital, o desde la herramienta de deconstrucción en 1era persona, se activa inmediatamente la demolición, no tiene el tiempo previo de espera para confirmación, este tiempo de confirmación solo se activa al usar el botón de demolición desde la ventana de interacción del edificio.
   - *Solución:* En `godot/scripts/Obras.gd` se implementó `alternar_demolicion()` utilizando `programar_demolicion()` con cuenta regresiva configurable de confirmación para cenital y primera persona.
8. [x] Al modificar la prioridad de un edificio en construcción, los obreros que ya habían sido asignados no son reasignados a una construcción con mayor prioridad.
   - *Solución:* Señal `prioridad_obra_cambiada` en `Obras.gd` conectada a `Colonos.gd` para liberar tareas en curso de menor prioridad y redirigir inmediatamente a los obreros hacia la obra prioritaria.
9. [x] En la ventana del almacén, al presionar en el botón de contraer todo, la ventana no regresa al tamaño correspondiente, es decir, no se adapta al contenido.
   - *Solución:* Invocación de `reset_size()` en `godot/scripts/VentanaAlmacen.gd` al contraer categorías y al colapsar el panel.


# SUGGESTIONS (IMPLEMENTADA):
1. [x] Aumentar la tasa de inmigrasión en valores altos de moral ciudadana.
   - *Solución:* En `godot/scripts/ajustes.gd` se recalibraron los tramos de `CIUDAD_TRAMOS_MIGRACION`: moral 75 -> 5.0/mes, moral 90 -> 7.0/mes, moral 100 -> 10.0/mes.
