# Craft to Nation

![Logotipo de Craft to Nation](docs/assets/craft-to-nation-logo.png)

**Craft to Nation** es un juego de supervivencia, construcción y estrategia en el que el jugador transforma un refugio en una nación industrial viva.

**Sitio web:** [crafttonation.netlify.app](https://crafttonation.netlify.app)

El proyecto está en etapa de pruebas de concepto. El desarrollo actual valida sus sistemas principales de forma incremental sobre un único proyecto de Godot, siguiendo el [GDD v3.41](Documento%20de%20Diseño%20de%20Juego%20%28GDD%29_%20Craft%20to%20Nation.md).

## Estado actual

- **Fase 0 — completada:** PoC 1 y 2 validan la lógica de recursos, demografía, nivel urbano, serialización y reglas de blueprints y zonas.
- **Fase 1 — verificada:** PoC 3 implementa el prototipo en primera persona sobre `GridMap`, minado y colocación, detección y validación de edificios, y objetos multicelda.
- **Fase 2 — completa:** PoC 4 integra `Ciudad` y `Avatar` como autoload, HUD, zonificación funcional y una cámara cenital navegable, y PoC 8 (parte a pie) añade colonos NPC con pathfinding propio que viven en las casas y migran según la vivienda y la comida.
- **Fase 3 — en progreso:** PoC 6 (mundo procedural, nivelación, puestos de recolección y cuerpos de agua) está completo con alcance reducido, y PoC 5 (catálogo de recursos y cadenas de producción) lleva el subproyecto de minerales y las fases 2A y 2B de la economía. El mundo procedural finito de 200×200 celdas incluye relieve con dos montañas, subsuelo con seis minerales, mares, lagos y ríos con corriente y cascadas, agua con niveles, señales de bioma y árboles talables. Los cuatro puestos de recolección (minas, caza y recolección, maderero, pesca y frutos del mar) se colocan desde la cámara cenital: se les asignan recolectores y acarreadores desde un panel, producen y acarrean a pie hasta el núcleo urbano, y minas y madereros consumen bloques y árboles reales, con tasas que se recalculan según su entorno. El avatar mina, tala y recolecta frutos con barra de avance sobre un inventario limitado. La construcción asistida guarda blueprints reutilizables y emplaza construcciones fantasma reversibles, y las vías de tierra pisada (tecla `V`) dan +35 % de velocidad. Siguen pendientes los edificios de recolección jugables reales, el HUD por modos, la declaración de edificios por volumen interno, los edificios de transformación (2C) y la construcción por NPCs.
- **Fases 4–7 — planeadas:** cámara dual y tropas, logística y puentes, combate e IA, y multijugador LAN.
- **Visión a largo plazo:** eras tecnológicas posteriores al nivel urbano actual y un servidor MMO por planetas, todavía sin PoC ni fase asignada.

El proyecto Godot cuenta actualmente con **343 bloques de prueba** (conteo de cabeceras `=== TEST` en los scripts) repartidos en 19 escenas `*Test.tscn`: validación de blueprints y construcción, ciudad, zonificación, mundo, árboles, nivelación, recolección, economía, extracción, colonos, rutas, vías, minerales, translúcidos y jugador.

## Ideas incorporadas al roadmap

- **Mundo procedural finito:** implementado como primer subproyecto de PoC 6.
- **Nivelación de terreno sobre relieve:** implementada y confirmada visualmente; los edificios con puerta toman como nivel el suelo natural frente a ella (excavación y relleno en una cola de preparación) y los puestos periféricos se nivelan al punto más alto de su huella. Sin costo de recursos todavía.
- **Puestos de recolección y previsualización en el HUD:** minas (seis minerales por profundidad), caza y recolección, maderero y pesca y frutos del mar, colocables desde la cámara cenital con estadísticas en vivo. Producen recursos reales con trabajadores asignados y alimentan el almacén central.
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
PoC_8/     Pathfinding a pie y colonos NPC
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
- `godot/scenes/BuscadorRutasTest.tscn`
- `godot/scenes/ColonosTest.tscn`
- `godot/scenes/FantasmasPermeablesTest.tscn`
- `godot/scenes/EconomiaTest.tscn`
- `godot/scenes/ExtraccionTest.tscn`
- `godot/scenes/ViasTest.tscn`

## Contribuir

Consulta [CONTRIBUTING.md](CONTRIBUTING.md) antes de enviar cambios. Se aceptan aportes humanos o asistidos por IA siempre que quien los envía los haya revisado y pueda responder por ellos.

## Licencias

- El código fuente se distribuye bajo la [licencia MIT](LICENSE).
- La documentación y los recursos originales se distribuyen bajo [CC BY 4.0](LICENSE-CONTENT.md).
- El nombre y los logotipos de Craft to Nation no quedan licenciados para identificar proyectos derivados.
