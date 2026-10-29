# BUGS:
1. La ventana se ve sobre el overlay de bloque apuntado cuando se visualiza de lado. De frente no se ve el bug.
2. Si un edificio residencial está declarado como No colonizable y llegan ciudadanos nuevos por encima del límite de camas disponibles, los nuevos ciudadanos pasan a ser "Sin techo", sin embargo, en el edificio se muestra como que tiene un residente y al activarle el estado de colonización el colono no cambia de estado a "Desempleado".
3. Al activar el modo de remodelación de un edificio habitado, sin suficientes camas disponibles, los residentes fueron deshauciados y marcados como "Sin techo" por lo que no pudieron trabajar, sin embargo, al revisar el puesto periférico donde estaban empleados seguían apareciendo como empleados. Luego, al redeclarar el edificio residencial como habitable, el puesto mostraba 2 ciudadanos libres (desempleados) pero no descontó a los que habían sido desahauciados en un principio. Es necesario que al actualizarse el estado de un colono, también se actualice el estado del puesto o industria en el que esté contratado.
4. Al construir un edificio con ventanas de techo a partir del blueprint, las ventanas no se colocan automáticamente en el estado de "techo" sino que quedan en formato vertical.
5. La herramienta de demolición desde la vista cenital no tiene función de desmarcar una vía que haya sido marcada para demolición.
6. La herramienta de interacción con vías de la 1era persona no permite interactuar con el marcaje de las vías en demolición.
7. Al marcar un edificio para demolición desde la vista cenital, o desde la herramienta de deconstrucción en 1era persona, se activa inmediatamente la demolición, no tiene el tiempo previo de espera para confirmación, este tiempo de confirmación solo se activa al usar el botón de demolición desde la ventana de interacción del edificio.
8. Al modificar la prioridad de un edificio en construcción, los obreros que ya habían sido asignados no son reasignados a una construcción con mayor prioridad.
9. En la ventana del almacén, al presionar en el botón de contraer todo, la ventana no regresa al tamaño correspondiente, es decir, no se adapta al contenido.


# SUGGESTIONS:
1. Aumentar la tasa de inmigrasión en valores altos de moral ciudadana.