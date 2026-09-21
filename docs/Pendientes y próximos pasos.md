Pendientes y próximos pasos según el roadmap (GDD Sección 11)



Fase 3 (PoC 6) — cola de pendientes menores, ya no bloqueantes:

\- Cauces de río sinuosos (hoy solo ejes ortogonales del grid).

\- Percentil de nivel de mar dependiente de un "tipo de mundo" (concepto sin diseñar aún).

\- Revisar el dithering de Alpha Hash en ventanas cuando exista una textura real.

~~- Efecto visual/de jugabilidad para cascadas (hoy solo un dato, es\_cascada\_en()).~~

~~- Reglas de flotación/natación.~~

~~- Puesto maderero jugable (huella ya documentada, sin modo de colocación)~~; ~~puesto de pesca/frutos del mar (sin señal de peces aún)~~.

~~- Escalar PROFUNDIDAD\_SUBSUELO hacia los \~300 bloques finales del GDD.~~

~~- Generación de otros recursos del subsuelo siguiendo el patrón de ruido del hierro pero con diferentes concentraciones.~~

~~- Corrección del sistema de construcción, para que las puertas queden "a nivel de suelo" (se debe cavar o elevar el piso debajo de la huella según sea necesario para hacer la nivelación), esto es importante porque afectará la distribución de recursos, porque las puertas de los edificios deberán estar a la misma altura que la carretera para poder considerarse "conectadas" a la red.~~



Siguiente pieza recomendada — PoC 5 (Catálogo de Recursos y Cadenas de Producción):

Es la única pieza de la Fase 3 sin empezar (brainstorm/spec/plan propio). Define qué recursos existen, cantidades por bloque, velocidades de recolección/consumo/producción y recetas de refinerías — necesario antes de poder construir los edificios de producción reales (aserradero, refinerías, etc.) y antes de que la logística (Fase 5) tenga un catálogo formal detrás.



Después de cerrar la Fase 3:

\- Fase 4 (PoC 7): cámara dual y selección de tropas.

\- Fase 5 (PoC 8-10): pathfinding, cintas/tuberías, y el Sistema de Puentes (que ya puede apoyarse en los cuerpos de agua reales de PoC 6).





1\. Vías de "tierra pisada" y carretas (sub-proyecto 6).

&#x20;  - Por qué: es el cuello de botella de fondo. A 18–26 celdas el acarreo a pie limita todo.

&#x20;  - Qué haría: los colonos irían más rápido por las vías, y la distancia dejaría de castigar tanto.

&#x20;  - Cómo empezaría: con un brainstorming, porque toca pathfinding, construcción y economía.

2\. Sub-proyecto 2B: extracción física y agotamiento. Los puestos consumirían de verdad los bloques y árboles del mundo, y no solo producirían una tasa.

3\. Sub-proyecto 2C: transformación. Aserradero y refinerías convertirían recursos crudos en procesados, con recetas.



