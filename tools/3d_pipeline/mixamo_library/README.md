# Biblioteca de Animaciones Mixamo (`.fbx`)

Coloca aquí los archivos `.fbx` descargados gratuitamente desde [mixamo.com](https://www.mixamo.com/) para transferirlos a cualquier personaje de *Craft to Nation*.

## Ajustes Recomendados al Descargar en Mixamo
- **Format:** `FBX Binary (.fbx)`
- **Skin:** `Without Skin` (solo esqueleto animado; más ligero y rápido)
- **Frames per Second:** `30`
- **In Place:** Activado para ciclos de movimiento (`Walking`, `Running`, `Crouch Walk`, etc.)

## Uso Rápido
```powershell
& "C:\Program Files\Blender Foundation\Blender 5.3\blender.exe" --background `
  --python tools/3d_pipeline/blender_mixamo_retarget.py -- `
  --input godot/assets/personajes/<nombre>/<nombre>.glb `
  --fbx-dir tools/3d_pipeline/mixamo_library `
  --in-place `
  --output godot/assets/personajes/<nombre>/<nombre>.glb
```
