# Materiales CC0 Puntuales para Personajes y Equipamiento

Esta carpeta contiene 3 sets PBR ligeros (`512×512` `.png`, normales **OpenGL +Y**, licencia **CC0 1.0** de Poly Haven) para detalles de atuendos Capa 1 y props rígidos Capa 2 (`craft-character-3d`):

| Set | Archivos | Fuente CC0 | Uso sugerido |
| :--- | :--- | :--- | :--- |
| **Tela neutra** | `tex_tela_neutra.png`, `_normal.png`, `_roughness.png` | `Poly Haven: rough_linen` | Prendas textiles y acentos neutros tintables con `mat_color_equipo`. |
| **Cuero** | `tex_cuero.png`, `_normal.png`, `_roughness.png` | `Poly Haven: brown_leather` | Correas, botas, empuñaduras, `maletin_ciencia.glb`, `canasta_acarreo.glb`. |
| **Metal** | `tex_metal.png`, `_normal.png`, `_roughness.png` | `Poly Haven: metal_plate_02` | Hojas y cabezas metálicas de `pico.glb`, `hacha.glb`, `martillo.glb`, `espada.glb`, `casco_militar.glb`, `escudo.glb`. |

> **Convención obligatoria (`godot/assets/personajes/README.md`):** los materiales dinámicos de piel y facción deben seguir nombrándose **`mat_piel`** (o `skin`) y **`mat_color_equipo`** (o `team_color`) en Blender para que `CatalogoPersonajes.aplicar_materiales_identidad()` aplique los tintes automáticos en tiempo de ejecución.
