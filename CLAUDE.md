# Guía para Claude Code

## Contexto

Craft to Nation está validando sus sistemas mediante PoC independientes. No conviertas todavía estas pruebas en una arquitectura definitiva ni mezcles las PoC sin una decisión explícita.

## Mapa del repositorio

- `Documento de Diseño de Juego (GDD)_ Craft to Nation.md`: visión y reglas del juego.
- `PoC_1/` y `PoC_2/`: documentos técnicos con implementaciones de referencia.
- `PoC_3/`: prototipo actual en Godot 4.7 y pruebas GDScript.
- `docs/`: especificaciones y planes de trabajo.

`website/` (sitio de presentación) existe en disco pero no está versionado (no forma parte del desarrollo del juego) — ignorarlo.

## Reglas de trabajo

- Lee el GDD y el documento técnico de la PoC afectada antes de cambiar comportamiento.
- Reutiliza el código existente y evita dependencias o abstracciones especulativas.
- Mantén cambios pequeños; no reformatees archivos ajenos al objetivo.
- Conserva el español en documentación, mensajes del juego y pruebas existentes.
- Usa tabulaciones en GDScript, como exige Godot.
- No edites ni agregues `.godot/`, `.godot-mcp/`, `.superpowers/` o cachés de Python.
- Actualiza el documento técnico cuando cambie una decisión funcional de una PoC.

## Verificación

Para cambios en el proyecto Godot compartido (`godot/`, usado por PoC_3 en adelante), ejecuta `godot/scenes/Test.tscn` con Godot 4.7 (además de las demás escenas `*Test.tscn` afectadas) y confirma que todas las aserciones pasan.
