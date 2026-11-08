# Menú de Inicio, Guardado de Partida, Menú de Pausa (F11) y Configuración — Plan de Implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar un Menú de Inicio como escena principal del juego, un sistema de guardado y carga de partidas completo (con nombres personalizados y slot de Guardado Rápido), un Menú Contextual de Pausa en Juego accesible con la tecla F11 con configuración en caliente, y gestión de música ambiental (BGM) y efectos (SFX) con persistencia de variables en `user://configuracion.json`.

**Architecture:** 
- Singleton `Configuracion.gd` gestiona y persiste preferencias (volúmenes SFX/BGM, sensibilidad, FOV) en `user://configuracion.json`.
- `Sonidos.gd` integra un reproductor de música de fondo en bucle con rotación de pistas de `res://assets/musica/` y control independiente de volumen SFX y BGM.
- Singleton `GestorPartida.gd` serializa atómicamente el estado del juego (`Ciudad`, `Economia`, `Colonos`, `VoxelWorld`, `Vias`, `Canalizaciones`, `Player`, `Zonificacion`) en `user://saves/*.json`.
- `MenuPausa.gd` se integra en `Main.tscn` en un `CanvasLayer` con `process_mode = PROCESS_MODE_ALWAYS` pausando el árbol con `get_tree().paused = true` al presionar F11.
- `MenuInicio.tscn` se establece como `run/main_scene` en `project.godot` ofreciendo Nueva Partida, Cargar Partida, Configuración y Salir.

**Tech Stack:** Godot 4.7.2 (GDScript), JSON FileAccess, AudioStreamPlayer (BGM), AudioServer/decibels, TemaHUD.

**Spec:** [`spec_menu_guardado_configuracion.md`](file:///C:/Users/peraz/.gemini/antigravity/brain/cfb4640e-bfaa-457c-a8c1-8af6ce7d574c/spec_menu_guardado_configuracion.md)

---

## Global Constraints

- Compatibilidad estricta con Godot 4.7.2 en modo headless y exportado.
- Seguir principios de diseño *Ponytail*: código mínimo, limpio, sin abstracciones innecesarias y reutilizando utilidades existentes (`TemaHUD`, `Ajustes`, `Sonidos`).
- No romper ninguna de las 29 escenas de pruebas existentes en `tools/run-godot-tests.ps1`.
- Mantener la integridad de la documentación y comentarios explicativos en los scripts modificados.

---

## Execution Lines & Dependency Matrix

- **Line 1: Configuración & Música BGM (`Configuracion.gd` + `Sonidos.gd`)**
  - Files: `godot/scripts/Configuracion.gd`, `godot/scripts/Sonidos.gd`, `godot/scripts/ConfiguracionTest.gd`, `godot/scenes/ConfiguracionTest.tscn`, `godot/assets/musica/*`
  - Local Test: `pwsh -File tools/run-single-test.ps1 ConfiguracionTest.tscn`
- **Line 2: Sistema de Guardado y Carga (`GestorPartida.gd` + Métodos de Serialización)**
  - Files: `godot/scripts/GestorPartida.gd`, `godot/scripts/Ciudad.gd`, `godot/scripts/Economia.gd`, `godot/scripts/Colonos.gd`, `godot/scripts/VoxelWorld.gd`, `godot/scripts/Player.gd`, `godot/scripts/Zonificacion.gd`, `godot/scripts/Vias.gd`, `godot/scripts/Canalizaciones.gd`, `godot/scripts/GestorPartidaTest.gd`, `godot/scenes/GestorPartidaTest.tscn`
  - Local Test: `pwsh -File tools/run-single-test.ps1 GestorPartidaTest.tscn`
- **Line 3: Menú de Pausa en Juego (Tecla F11) (`MenuPausa.gd` + `Main.gd`)**
  - Files: `godot/scripts/MenuPausa.gd`, `godot/scripts/Main.gd`, `godot/scenes/Main.tscn`, `godot/scripts/MenuPausaTest.gd`, `godot/scenes/MenuPausaTest.tscn`
  - Local Test: `pwsh -File tools/run-single-test.ps1 MenuPausaTest.tscn`
- **Line 4: Menú de Inicio (`MenuInicio.tscn` + `MenuInicio.gd` + `project.godot`)**
  - Files: `godot/scenes/MenuInicio.tscn`, `godot/scripts/MenuInicio.gd`, `godot/project.godot`, `godot/scripts/MenuInicioTest.gd`, `godot/scenes/MenuInicioTest.tscn`
  - Local Test: `pwsh -File tools/run-single-test.ps1 MenuInicioTest.tscn`
- **Line 5: Verificación Global y Actualización de Grafo**
  - Local Test: `pwsh -File tools/run-godot-tests.ps1` (todas las escenas pasan limpias)
  - Graph update: `graphify update .`

---

## Review Focus

1. **Restauración de Modificaciones del Terreno:** Al cargar una partida, las celdas minadas o colocadas deben reflejarse fielmente en el `GridMap` sin duplicar colisiones ni corromper el árbol de nodos.
2. **Pausa Absoluta en F11:** La simulación, horas de juego y movimiento de colonos deben detenerse totalmente mientras el menú de pausa esté abierto (`paused = true`).
3. **Persistencia de Variables de Audio y Controles:** Modificar los sliders en el menú de pausa o menú principal debe persistirse en `user://configuracion.json` y mantenerse al reiniciar el juego.
4. **Sobrescritura Segura de Partidas:** Si el usuario guarda con un nombre ya existente, debe solicitarse confirmación o actualizar el archivo atómicamente sin pérdida de datos.
5. **Autocierre de Herramientas y Liberación de Ratón:** Al abrir el menú de pausa o volver al menú principal, el cursor debe estar visible y desbloqueado; al reanudar, debe volver a capturarse si la cámara activa es en 1ª persona.

---

## Detailed Tasks

### Task 1: Subsistema de Configuración y Música BGM
- [x] Copiar las pistas de música (`The_Architect_s_Decree (menu).mp3`, `Cozy_colony (loop).mp3`, `Morning_at_the_Steel_Spire (loop).mp3`, `Clockwork_logistics (loop).mp3`) desde `arte/mp3/` a `godot/assets/musica/`.
- [x] Crear el script singleton `godot/scripts/Configuracion.gd` que carga y guarda en `user://configuracion.json`:
  - `volumen_sfx`: float (por defecto 1.0)
  - `volumen_musica`: float (por defecto 0.8)
  - `sensibilidad_mouse`: float (por defecto 0.003)
  - `fov_camara`: float (por defecto 70.0)
  - `idioma`: String (por defecto "es")
  - Métodos: `cargar()`, `guardar()`, señales `configuracion_cambiada`.
- [x] Registrar `Configuracion="*res://scripts/Configuracion.gd"` en `godot/project.godot`.
- [x] Actualizar `godot/scripts/Sonidos.gd` para incorporar:
  - `_player_musica: AudioStreamPlayer`
  - Métodos `reproducir_musica(ruta)`, `detener_musica()`, `reproducir_musica_menu()`, `reproducir_musica_juego()`.
  - Aplicar volumen independiente a SFX y Música según `Configuracion`.
- [x] Crear la suite de pruebas `godot/scripts/ConfiguracionTest.gd` y `godot/scenes/ConfiguracionTest.tscn`.
- [x] Ejecutar `pwsh -File tools/run-single-test.ps1 ConfiguracionTest.tscn` y verificar aprobación.

---

### Task 2: Subsistema de Serialización y Guardado (`GestorPartida.gd`)
- [x] Implementar métodos de exportación e importación de estado en los singletons y componentes clave:
  - `Ciudad.gd`: `exportar_estado() -> Dictionary`, `importar_estado(d: Dictionary)`
  - `Economia.gd`: `exportar_estado() -> Dictionary`, `importar_estado(d: Dictionary)`
  - `Colonos.gd`: `exportar_estado() -> Dictionary`, `importar_estado(d: Dictionary)`
  - `Zonificacion.gd`: `exportar_estado() -> Dictionary`, `importar_estado(d: Dictionary)`
  - `Vias.gd`: `exportar_estado() -> Dictionary`, `importar_estado(d: Dictionary)`
  - `Canalizaciones.gd`: `exportar_estado() -> Dictionary`, `importar_estado(d: Dictionary)`
  - `VoxelWorld.gd`: `exportar_estado() -> Dictionary`, `importar_estado(d: Dictionary)`
  - `Player.gd`: `exportar_estado() -> Dictionary`, `importar_estado(d: Dictionary)`
- [x] Crear `godot/scripts/GestorPartida.gd`:
  - `guardar_partida(nombre_archivo: String, nombre_legible: String = "") -> bool`
  - `cargar_partida(nombre_archivo: String) -> bool`
  - `guardado_rapido() -> bool`
  - `listar_partidas() -> Array[Dictionary]`
  - `eliminar_partida(nombre_archivo: String) -> bool`
  - `obtener_ruta_partida(nombre_archivo: String) -> String`
- [x] Registrar `GestorPartida="*res://scripts/GestorPartida.gd"` en `godot/project.godot`.
- [x] Crear la escena de pruebas `godot/scripts/GestorPartidaTest.gd` y `godot/scenes/GestorPartidaTest.tscn`.
- [x] Ejecutar `pwsh -File tools/run-single-test.ps1 GestorPartidaTest.tscn` y verificar aprobación.

---

### Task 3: Menú Contextual de Pausa en Juego (Tecla F11)
- [x] Crear `godot/scripts/MenuPausa.gd`:
  - Diseño visual con `TemaHUD` centrado en pantalla.
  - Opciones:
    - Botón "Regresar a la partida"
    - Botón "Guardado Rápido"
    - Botón "Guardar Partida..." (con diálogo de texto para nombre)
    - Botón "Cargar Partida..." (con lista de guardados)
    - Botón "Configuración" (sliders para SFX, Música, Sensibilidad y FOV)
    - Botón "Salir al Menú Principal"
  - Configurar `process_mode = Node.PROCESS_MODE_ALWAYS`.
- [x] Integrar `MenuPausa` en `godot/scenes/Main.tscn` dentro de un nodo `CanvasLayer` superior (`MenuPausaLayer`).
- [x] Conectar la tecla **F11** en `godot/scripts/Main.gd` para abrir/cerrar el menú de pausa:
  - Al abrir: `get_tree().paused = true`, `Input.mouse_mode = Input.MOUSE_MODE_VISIBLE`.
  - Al cerrar: `get_tree().paused = false`, restaurar captura del ratón si el avatar está activo.
- [x] Iniciar la rotación de música ambiental de fondo en `Main.gd: _ready()` (`Sonidos.reproducir_musica_juego()`).
- [x] Crear `godot/scripts/MenuPausaTest.gd` y `godot/scenes/MenuPausaTest.tscn`.
- [x] Ejecutar `pwsh -File tools/run-single-test.ps1 MenuPausaTest.tscn` y verificar aprobación.

---

### Task 4: Menú de Inicio (`MenuInicio.tscn` / `MenuInicio.gd`)
- [x] Crear `godot/scenes/MenuInicio.tscn` y `godot/scripts/MenuInicio.gd`:
  - Panel principal temático con título estilizado, versión y botones:
    - "Nueva Partida": Inicia `Main.tscn` limpiando el estado previo.
    - "Cargar Partida": Abre modal de selección de partida guardada (nombre, fecha, nivel, tiempo jugado), con botón Cargar y Eliminar.
    - "Configuración": Abre modal de ajustes (SFX, Música, Sensibilidad, FOV, Idioma).
    - "Salir": `get_tree().quit()`.
  - Reproducir `The_Architect_s_Decree (menu).mp3` en bucle al abrir el menú de inicio.
- [x] Configurar `run/main_scene="res://scenes/MenuInicio.tscn"` en `godot/project.godot`.
- [x] Crear `godot/scripts/MenuInicioTest.gd` y `godot/scenes/MenuInicioTest.tscn`.
- [x] Ejecutar `pwsh -File tools/run-single-test.ps1 MenuInicioTest.tscn` y verificar aprobación.

---

### Task 5: Validación Global de Pruebas y Grafo de Conocimiento
- [x] Añadir las 4 nuevas escenas de prueba (`ConfiguracionTest.tscn`, `GestorPartidaTest.tscn`, `MenuPausaTest.tscn`, `MenuInicioTest.tscn`) a `tools/run-godot-tests.ps1`.
- [x] Ejecutar la suite completa `tools/run-godot-tests.ps1` verificando que las 33 escenas de prueba pasen al 100% sin errores.
- [x] Ejecutar `graphify update .` para actualizar el grafo de conocimiento del proyecto.
