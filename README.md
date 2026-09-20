# Craft to Nation

![Logotipo de Craft to Nation](docs/assets/craft-to-nation-logo.png)

**Craft to Nation** es un juego de supervivencia, construcción y estrategia en el que el jugador transforma un refugio en una nación industrial viva.

**Sitio web:** [crafttonation.netlify.app](https://crafttonation.netlify.app)

El proyecto está en etapa de pruebas de concepto. El desarrollo actual valida sus sistemas principales de forma incremental sobre un único proyecto de Godot, siguiendo el [GDD v3.29](Documento%20de%20Diseño%20de%20Juego%20%28GDD%29_%20Craft%20to%20Nation.md).

## Estado actual

- **Fase 0 — completada:** PoC 1 y 2 validan la lógica de recursos, demografía, nivel urbano, serialización y reglas de blueprints y zonas.
- **Fase 1 — verificada:** PoC 3 implementa el prototipo en primera persona sobre `GridMap`, minado y colocación, detección y validación de edificios, y objetos multicelda.
- **Fase 2 — en progreso:** PoC 4 integra `Ciudad` y `Avatar` como autoload, HUD, zonificación funcional y una cámara cenital navegable. El vínculo con el jugador es parcial y los colonos NPC siguen pendientes.
- **Fase 3 — en progreso:** los cuatro subproyectos de PoC 6 están completos con alcance reducido, y PoC 5 (catálogo de recursos y cadenas de producción) avanzó su subproyecto 1 de 4 (minerales, como lógica pura con escena de demostración; madera, fluidos y energía siguen pendientes). El mundo procedural finito de 200×200 celdas incluye relieve con dos montañas explícitas, subsuelo con seis minerales (tierra, piedra, hierro, cobre, carbón y tierras raras), mares, lagos y ríos con corriente y cascadas, agua con niveles que escurre y se seca, señales de bioma y árboles procedurales talables. El jugador nada y tiene oxígeno. La cámara cenital permite colocar los cuatro puestos de recolección (minas, caza y recolección, maderero, pesca y frutos del mar) con previsualización y estadísticas en vivo. La construcción asistida ya guarda blueprints reutilizables, emplaza construcciones fantasma reversibles y deja las puertas a nivel de suelo. Siguen pendientes la producción real de los puestos (no hay inventario), los edificios de refinado colocables y los colonos NPC.
- **Fases 4–7 — planeadas:** cámara dual y tropas, logística y puentes, combate e IA, y multijugador LAN.
- **Visión a largo plazo:** eras tecnológicas posteriores al nivel urbano actual y un servidor MMO por planetas, todavía sin PoC ni fase asignada.

El proyecto Godot cuenta actualmente con **191 bloques de prueba** (conteo de cabeceras `=== TEST` en los scripts): 64 de blueprints y construcción, 8 de ciudad, 12 de zonificación, 33 de generación del mundo, 11 de árboles procedurales, 15 de nivelación de terreno, 19 de recolección, 8 de cadena de minerales, 9 de render de translúcidos y 12 del jugador (natación y oxígeno).

## Ideas incorporadas al roadmap

- **Mundo procedural finito:** implementado como primer subproyecto de PoC 6.
- **Nivelación de terreno sobre relieve:** implementada y confirmada visualmente; los edificios con puerta toman como nivel el suelo natural frente a ella (excavación y relleno en una cola de preparación) y los puestos periféricos se nivelan al punto más alto de su huella. Sin costo de recursos todavía.
- **Puestos de recolección y previsualización en el HUD:** minas (seis minerales por profundidad), caza y recolección, maderero y pesca y frutos del mar, colocables desde la cámara cenital con estadísticas en vivo. Son marcadores: aún no alimentan un inventario.
- **Bioma y vegetación:** implementadas las señales de fauna, frutales y árboles; el mundo genera árboles procedurales talables y el jugador puede talarlos mediante acciones repetidas.
- **Catálogo de recursos y cadenas de producción:** el subproyecto de minerales (recetas placeholder hierro→acero y tierras raras→mineral refinado) está implementado como lógica pura; el resto del catálogo sigue pendiente.
- **Cuerpos de agua:** implementados (mares, lagos y ríos con corriente y cascadas, agua transparente y no sólida, natación con oxígeno, escurrimiento con niveles y secado). Cauces sinuosos y un nivel de mar que dependa del tipo de mundo siguen pendientes.
- **Puentes:** previstos como PoC 10 en la Fase 5, reutilizando el trazado de las redes de transporte.
- **Tallado cosmético por celda:** previsto como pulido visual, sin fase propia.
- **Túneles y cavernas:** previstos a futuro; dependen de la generación de terreno y de las mecánicas de combate.

El contexto y la ubicación de estas ideas se conservan en [docs/ideas-backlog.md](docs/ideas-backlog.md).

## Estructura

```text
PoC_1/     Motor lógico de recursos y demografía
PoC_2/     Serialización y validación de blueprints
PoC_3/     Documento técnico del prototipo visual
PoC_4/     Documentos técnicos de ciudad y zonificación
PoC_5/     Catálogo de recursos y cadenas de producción
PoC_6/     Documentos técnicos del mundo y recolección
godot/     Proyecto compartido desde PoC 3
docs/      Especificaciones, planes e ideas del backlog
```

## Ejecutar el prototipo

1. Instala Godot 4.7.
2. Importa `godot/project.godot` (proyecto Godot compartido, usado por PoC_3 en adelante).
3. Ejecuta el proyecto con **F5**.

Para correr las pruebas de Godot, abre cada escena y usa **F6**:

- `godot/scenes/Test.tscn`
- `godot/scenes/BlueprintsTest.tscn`
- `godot/scenes/ConstruccionTest.tscn`
- `godot/scenes/CiudadTest.tscn`
- `godot/scenes/ZonificacionTest.tscn`
- `godot/scenes/GeneradorMundoTest.tscn`
- `godot/scenes/GeneradorArbolTest.tscn`
- `godot/scenes/NiveladorTerrenoTest.tscn`
- `godot/scenes/RecoleccionTest.tscn`
- `godot/scenes/CadenaMineralesTest.tscn`
- `godot/scenes/TranslucidosRendererTest.tscn`
- `godot/scenes/PlayerNatacionTest.tscn`
- `godot/scenes/PlayerOxigenoTest.tscn`

## Contribuir

Consulta [CONTRIBUTING.md](CONTRIBUTING.md) antes de enviar cambios. Se aceptan aportes humanos o asistidos por IA siempre que quien los envía los haya revisado y pueda responder por ellos.

## Licencias

- El código fuente se distribuye bajo la [licencia MIT](LICENSE).
- La documentación y los recursos originales se distribuyen bajo [CC BY 4.0](LICENSE-CONTENT.md).
- El nombre y los logotipos de Craft to Nation no quedan licenciados para identificar proyectos derivados.
