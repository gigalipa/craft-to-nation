# Pendientes y próximos pasos según el roadmap (GDD Sección 11)

## Ruta a seguir

### 1. PoC 5, sub-proyecto 2B — extracción física y agotamiento (siguiente pieza recomendada)

Los cuatro puestos de recolección ya asignan trabajadores, producen al almacén local y acarrean al núcleo (2A), pero las tasas se fijan al colocar el puesto y no se recalculan: los colonos no retiran bloques ni árboles reales, y el bosque/mina no se agota. Los puestos consumirían de verdad los bloques y árboles del mundo, y no solo producirían una tasa fija. Es previo a 2C porque la transformación necesita materia prima que de verdad se consuma.

- Recolección y consumo reales de parte del avatar (comparte mecánica de extracción con 2B; conviene diseñarlos juntos).

### 2. Edificios de recolección jugables reales

Diseño e implementación de edificios de recolección jugables reales (no solo un slab de bloques). Van tras 2B, cuando ya existe la extracción real, y antes de 2C, que necesita edificios de transformación de verdad.

### 3. HUD visual interactivo

Inspiración combinada de AoE y Minecraft. Se organiza por **modos** (construir, zonas, vías, etc.) con sus accesos directos, y no por edificios particulares: habrá demasiados como para asignar una tecla a cada uno. Va tras los edificios de recolección jugables para definir la interfaz con ellos ya presentes, y antes de 2C y de las demás mecánicas para no rehacerla.

### 4. Declaración de edificios por volumen interno

En este punto el jugador ya debe poder declarar y registrar distintos edificios residenciales. Pendiente de revisar: un edificio de dos niveles con una cama en cada nivel no fue reconocido por la declaración. El sistema debería cambiar a uno que detecte el **volumen interno** de una construcción, para permitir edificios personalizados de formas variadas (pirámides, cilindros, irregulares).

### 5. PoC 5, sub-proyecto 2C — transformación

Aserradero, carbonera, siderúrgica y refinería de tierras raras convertirían recursos crudos en procesados, con recetas.

### 6. Resto del catálogo general de PoC 5

Ver `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Catálogo de Recursos y Cadenas de Producción.md`: sub-proyecto 2 (madera), 3 (fluidos: agua/crudo/combustible) y 4 (energía). El sub-proyecto 1 (minerales) ya está completo.

### 7. Construcción/deconstrucción asistida por NPCs

Los colonos participan en construir y deconstruir. Se apoya en el acarreo (2A) y en la extracción real (2B).

### 8. Cola de pendientes menores de la Fase 3 (PoC 6) — no bloqueantes

Pueden intercalarse en cualquier momento.

- Cauces de río sinuosos (hoy solo ejes ortogonales del grid).
- Percentil de nivel de mar dependiente de un "tipo de mundo" (concepto sin diseñar aún).
- Revisar el dithering de Alpha Hash en ventanas cuando exista una textura real.

### Después de cerrar la Fase 3

- **Fase 4 (PoC 7):** cámara dual y selección de tropas.
- **Fase 5 (PoC 8-10):** pathfinding, cintas/tuberías y el Sistema de Puentes (que ya puede apoyarse en los cuerpos de agua reales de PoC 6). Las carretas (vehículos/unidades) también dependen de esta fase.

---

## Hecho

- ~~Fase 3 (PoC 6): efecto visual/de jugabilidad para cascadas (`es_cascada_en()`).~~
- ~~Fase 3 (PoC 6): reglas de flotación/natación.~~
- ~~Fase 3 (PoC 6): puesto maderero jugable y puesto de pesca/frutos del mar.~~
- ~~Fase 3 (PoC 6): escalar PROFUNDIDAD_SUBSUELO hacia los ~300 bloques finales del GDD.~~
- ~~Fase 3 (PoC 6): generación de otros recursos del subsuelo siguiendo el patrón de ruido del hierro con distintas concentraciones.~~
- ~~Fase 3 (PoC 6): puertas "a nivel de suelo" en el sistema de construcción (cavar o elevar el piso bajo la huella), necesario para que las puertas queden a la altura de la carretera y cuenten como "conectadas" a la red.~~
- ~~**Vías de "tierra pisada" (sub-proyecto 6).**~~ Implementado y verificado jugando en vivo (2026-09-22 a 2026-09-23): trazador en la cámara cenital (tecla `V`), overlay 2x2, cuñas para desnivel de 1, relleno para 2-3, sistema completo de rampa diagonal suave (7 piezas + `diag_lat` condicional), nivelación de tramos en V al nivel más alto en vez de dos rampas, bono de velocidad +35% para colonos y avatar, despeje/nivelación de blueprints que ignoran o levantan vías existentes, y overlays sin z-fighting entre la vía construida y las zonas A/B pintadas — ver `docs/superpowers/specs/2026-09-22-vias-tierra-pisada-design.md`. Las carretas quedan pendientes (ver Fase 5).
- ~~**Sub-proyecto 2A: puestos, producción y acarreo** (2026-09-21).~~ Los puestos asignan recolectores/acarreadores desde un panel, producen al almacén local y acarrean a pie hasta el núcleo urbano — ver `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Fase 2A - Puestos, Producción y Acarreo.md`.
