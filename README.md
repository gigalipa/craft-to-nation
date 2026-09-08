# Craft to Nation

![Logotipo de Craft to Nation](docs/assets/craft-to-nation-logo.png)

**Craft to Nation** es un juego de supervivencia, construcción y estrategia en el que el jugador transforma un refugio en una nación industrial viva.

El proyecto está en etapa de pruebas de concepto. El desarrollo actual valida sus sistemas principales de forma incremental sobre un único proyecto de Godot, siguiendo el [GDD v3.21](Documento%20de%20Diseño%20de%20Juego%20%28GDD%29_%20Craft%20to%20Nation.md).

## Estado actual

- **Fase 0 — completada:** PoC 1 y 2 validan la lógica de recursos, demografía, nivel urbano, serialización y reglas de blueprints y zonas.
- **Fase 1 — verificada:** PoC 3 implementa el prototipo en primera persona sobre `GridMap`, minado y colocación, detección y validación de edificios, y objetos multicelda.
- **Fase 2 — en progreso:** PoC 4 integra `Ciudad` y `Avatar` como autoload, HUD, zonificación funcional y una cámara cenital navegable. El vínculo con el jugador es parcial y los colonos NPC siguen pendientes.
- **Fase 3 — en progreso:** PoC 5 genera un mundo procedural finito de 200×200 celdas con relieve, subsuelo y vetas de hierro; permite nivelar una huella de terreno y colocar minas desde la cámara cenital, con previsualización del área de acción y estadísticas en vivo en el HUD. Siguen pendientes los demás puestos de recolección y los cuerpos de agua.
- **Fases 4–7 — planeadas:** cámara dual y tropas, logística y puentes, combate e IA, y multijugador LAN.

El proyecto Godot cuenta actualmente con **43 pruebas**: 14 de blueprints y construcción, 7 de ciudad, 8 de zonificación, 6 de generación del mundo, 4 de nivelación de terreno y 4 de recolección.

## Ideas incorporadas al roadmap

- **Mundo procedural finito:** implementado como primer subproyecto de PoC 5.
- **Nivelación de terreno sobre relieve:** implementada con una huella manual de 5×5 y sin costo de recursos; su integración con edificios reales queda pendiente.
- **Minas y previsualización en el HUD:** implementadas con vetas de hierro, detección de recursos, colocación desde la cámara cenital y estadísticas en vivo; queda pendiente confirmar visualmente la interacción completa en el editor.
- **Puestos de caza y recolección vegetal:** pendientes de biomas, vegetación, fauna y agua reales.
- **Cuerpos de agua:** pendientes como cuarto subproyecto de PoC 5.
- **Puentes:** previstos como PoC 9 en la Fase 5, reutilizando el trazado de las redes de transporte.
- **Tallado cosmético por celda:** previsto como pulido visual, sin fase propia.
- **Túneles y cavernas:** previstos a futuro; dependen de la generación de terreno y de las mecánicas de combate.

El contexto y la ubicación de estas ideas se conservan en [docs/ideas-backlog.md](docs/ideas-backlog.md).

## Estructura

```text
PoC_1/     Motor lógico de recursos y demografía
PoC_2/     Serialización y validación de blueprints
PoC_3/     Documento técnico del prototipo visual
PoC_4/     Documentos técnicos de ciudad y zonificación
PoC_5/     Documentos técnicos del mundo y recolección
godot/     Proyecto compartido desde PoC 3
docs/      Especificaciones, planes e ideas del backlog
```

## Ejecutar el prototipo

1. Instala Godot 4.7.
2. Importa `godot/project.godot` (proyecto Godot compartido, usado por PoC_3 en adelante).
3. Ejecuta el proyecto con **F5**.

Para correr las pruebas de Godot, abre cada escena y usa **F6**:

- `godot/scenes/Test.tscn`
- `godot/scenes/CiudadTest.tscn`
- `godot/scenes/ZonificacionTest.tscn`
- `godot/scenes/GeneradorMundoTest.tscn`
- `godot/scenes/NiveladorTerrenoTest.tscn`
- `godot/scenes/RecoleccionTest.tscn`

## Contribuir

Consulta [CONTRIBUTING.md](CONTRIBUTING.md) antes de enviar cambios. Se aceptan aportes humanos o asistidos por IA siempre que quien los envía los haya revisado y pueda responder por ellos.

## Licencias

- El código fuente se distribuye bajo la [licencia MIT](LICENSE).
- La documentación y los recursos originales se distribuyen bajo [CC BY 4.0](LICENSE-CONTENT.md).
- El nombre y los logotipos de Craft to Nation no quedan licenciados para identificar proyectos derivados.
