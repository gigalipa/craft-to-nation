# Assets de Personajes 3D — Guía Drop-In (`Craft to Nation`)

El motor carga automáticamente los archivos `.glb` que coloques en estas subcarpetas **sin necesidad de editar código GDScript**. Mientras un archivo no exista aún, el juego utiliza automáticamente el cuerpo base o el placeholder de cápsula sin errores.

## Estructura de Carpetas

```text
godot/assets/personajes/
├── avatar/
│   ├── avatar.glb                 # ✅ Avatar masculino jugable (existente)
│   └── avatar_f.glb               # ⏳ Futuro avatar femenino jugable
├── base/
│   ├── cuerpo_m.glb               # ⏳ Cuerpo base masculino humanoide
│   └── cuerpo_f.glb               # ⏳ Cuerpo base femenino humanoide
├── animaciones/
│   └── humanoide_base.glb         # ⏳ Biblioteca opcional de clips compartidos (Idle, Walking, Mining_Swing)
├── atuendos/                      # ⏳ Capa 1: <rango>_<m|f>.glb
│   ├── ciudadano_m.glb / ciudadano_f.glb
│   ├── desempleado_m.glb / desempleado_f.glb
│   ├── obrero_m.glb / obrero_f.glb
│   ├── tecnico_m.glb / tecnico_f.glb
│   ├── especialista_m.glb / especialista_f.glb
│   ├── investigador_m.glb / investigador_f.glb
│   └── militar_m.glb / militar_f.glb
└── equipamiento/                  # ⏳ Capa 2: <pieza>.glb (compartida por M y F)
    ├── martillo.glb               # Obras / extracción / refinerías (RightHand)
    ├── pico.glb                   # Mina (RightHand)
    ├── casco_minero.glb           # Mina / centro de extracción (Head)
    ├── hacha.glb                  # Maderero / aserradero (RightHand)
    ├── canasta_acarreo.glb        # Acarreador / almacén (Chest)
    ├── arco_caza.glb              # Caza y recolección (LeftHand)
    ├── cana_pesca.glb             # Pesca (RightHand)
    ├── gafas_industriales.glb     # Refinerías / fábricas / central / taller (Head)
    ├── maletin_ciencia.glb        # Escuelas / universidad / investigador itinerante (LeftHand)
    ├── casco_militar.glb          # Militar / cuartel (Head)
    ├── espada.glb                 # Militar / Avatar batalla (RightHand)
    ├── escudo.glb                 # Militar (LeftHand)
    └── arco.glb                   # Militar arquero / Avatar batalla (LeftHand)
```

## Convenciones Técnicas Obligatorias

1. **Altura y origen:** `1.80 m` de altura, origen `(0, 0, 0)` exactamente entre los pies, frente mirando hacia `+Z` (el mismo estándar que aplica `tools/3d_pipeline/blender_godot_prepare.py`).
2. **Esqueleto:** `SkeletonProfileHumanoid` de Godot 4. Los huesos usados para anclajes (`BoneAttachment3D`) son: `Head`, `Chest` (o `UpperChest`/`Spine`), `RightHand` y `LeftHand`.
3. **Materiales dinámicos (nombres de material en Blender):**
   - Piel (`0..3`, 4 tonos automáticos): nombrar el material comenzando por **`mat_piel`** (o `skin`).
   - Distintivo de equipo/facción: nombrar el material comenzando por **`mat_color_equipo`** (o `team_color`). Se recomienda textura blanca/neutra en ese slot para que el tinte dinámico del equipo se vea limpio.
4. **Triángulos:** `3,000 – 6,000` triángulos por cuerpo/atuendo de colono y texturas `512×512` o `1024×1024`.
