# Hoja de Ruta (Roadmap) y Estado del Desarrollo (GDD v3.57)

![Vista táctica de defensa y expansión urbana](/assets/comparison-aerial.webp)

La evolución técnica de **Craft to Nation** sigue el plan de 7 fases definido en la **Sección 11 del GDD v3.57** y el protocolo de verificación en vivo ([`docs/Live_Verifications.md`](https://github.com/dperaza/craft-to-nation)), sustentado en **28 escenas de prueba automatizadas al 100 % en verde**.

---

## 1. Resumen de las 7 Fases del Proyecto

```
[Fase 0: Lógica Pura (PoC 1 & PoC 2)] ──────────────────────────────────> COMPLETADA ✅
[Fase 1: Prototipo Visual 1ra Persona y Validación de Volumen (PoC 3)] ─> VERIFICADA ✅
[Fase 2: Ciudad, Demografía, Zonificación y Colonos NPC (PoC 4 & 8)] ───> COMPLETA ✅
[Fase 3: Mundo 200×200, Industrias, Fluidos, Moral e Iconografía HUD] ──> EN CIERRE FINAL 🟢 (98%)
[Fase 4: Cámara Dual de Combate y Selección de Tropas (PoC 7)] ─────────> PLANIFICADA ⏳
[Fase 5: Logística Avanzada, Carretas, Ferrocarril y Puentes (PoC 8–10)]> PLANIFICADA ⏳
[Fase 6: Combate, Asedios, IA Enemiga y Sucesión de Avatar] ────────────> PLANIFICADA ⏳
[Fase 7: Multijugador LAN y Soberanía Portátil de Núcleos] ─────────────> HORIZONTE FUTURO 🚀
```

---

## 2. Hitos Completados (Fases 0 a 3 — GDD v3.57)

### Fase 0 y Fase 1: Motor Vóxel, Avatar en Primera Persona y Validación Volumétrica
- [x] Mundo procedural finito de **200×200 celdas** (`GeneradorMundo.gd`) con altura máxima `y = 130`, **24 capas de subsuelo** hasta la roca madre (`bedrock`), 2 picos montañosos, ríos con corriente y cascadas, lagos y mares.
- [x] Avatar en primera persona (`Player.gd`) con minado por barra de progreso e icono contextual (`herr_pala`, `herr_pico`, `herr_hacha`), recolección de frutos silvestres manteniendo <kbd>E</kbd> (`60 u` en `2,0 s`), natación en líquidos profundos (`>= 2` bloques) con barra de oxígeno (`10,0 s`), drenaje de líquidos con bloques sólidos (<kbd>Clic Derecho</kbd>), modo de deconstrucción a pie (<kbd>G</kbd>) y lámpara omnidireccional (<kbd>L</kbd>) en modo **Térmico** (`Combustible 10h`, `Carbón 6h`, `Madera 5h`) y **Eléctrico** (`Batería 72h` con recarga `+7,2 h/tick`).
- [x] Reconocimiento volumétrico de edificios herméticos (`ValidadorEdificios.gd`), puertas 3D con pomo de bronce y bisagras, declaración (<kbd>B</kbd>) y remodelación no destructiva (<kbd>Shift</kbd> + <kbd>B</kbd>).

### Fase 2: Fundación Cívica, Cámara Cenital y Demografía
- [x] Cámara cenital táctica (`CamaraCenital.gd`) con vuelo suave de transición (`0,6 s` con <kbd>C</kbd>), menú numérico jerárquico (`1` Construir, `2` Zonificar, `3` Demoler) con navegación y paginación <kbd>Z</kbd> / <kbd>X</kbd>, rotación `Ctrl + Rueda` y hasta 5 *blueprints* residenciales.
- [x] Ciclo residencial completo: 1er edificio funda el **Núcleo Urbano**, 1ra Residencia nace con `Colonizable: SÍ`, 2da Residencia en adelante nace como buffer `Colonizable: NO (24 h)`, casas adosadas pared con pared y reubicación del Núcleo Urbano (`5 h`).
- [x] Cadena académica estricta en Zona Residencial (`1 -> 4 -> 1..3`): `Escuela técnica` (`24 h` → 3 Técnicos) → `Escuela de especialistas` (`48 h` → 2 Especialistas) → `Universidad` interactiva con inicio manual, pausa y cancelación con reembolso del 100 %.

### Fase 3: Industrias, Fluidos, Moral Dinámica e Iconografía HUD (v3.56 – v3.57)
- [x] **Puestos Periféricos (`1 -> 2 -> 1..6`):** Caza, Maderero, Mina (prof. 8/16/24), Pesca, Estación de Bombeo (`>= 2` bloques de agua) y Centro de Extracción (columna física de perforación) con insignias romanas `I–III`, regla del rango mínimo de trabajadores y ventana `VentanaBaul` (<kbd>E</kbd>).
- [x] **Red Vial (`1 -> 5 -> 1`), Modo a Pie (<kbd>V</kbd>) y Demolición Guiada (<kbd>3</kbd>):** Construcción progresiva por colonos (`ViaObraOverlay`), intervención a pie en secciones `2×2` (<kbd>V</kbd>), demolición guiada en naranja alrededor de esquinas de 90° mediante Dijkstra (<kbd>3</kbd>) y jerarquía global de 5 niveles de prioridad de obra.
- [x] **Instalaciones Industriales y Energéticas (`1 -> 3 -> 1..9`):** Siderúrgica, Tierras Raras, Aserradero, Fábrica de Bloques, Carbonera, Refinería Petrolera (`400/600`), Productor de Combustible, Central Termoeléctrica (selector `[Carbón]`/`[Combustible]`/`[Crudo]`) y Almacén Industrial (`6` puertos de fluidos en `Y = 4`), con selector de **`Reserva central:`** (`0 / 50 / 100 / 250 / 500 u`).
- [x] **Canalizaciones Elevadas (`1 -> 6 -> 1..2`):** Acueductos y tuberías en `Y + 4` (pilares cada 5 bloques), cruces a desnivel entre dos conductos en **`Y + 6`** (`1` bloque de aire libre en `Y + 5`), derrames físicos (`🔴 Derrame`) con viscosidad `0,20` y reconexión desde columna.
- [x] **Moral Dinámica y `VentanaEnergia` con Teletransporte de Cámara:** Tasa diaria (`/día`), 3 regímenes migratorios escalonados (`<= 20%` éxodo, `20–50%` con camas, `> 50%` masiva) y vuelo suave (`Tween`) al hacer clic sobre edificios en `VentanaEnergia`.
- [x] **Iconografía Vectorial HUD y Miniaturas 3D (v3.57):** Más de **90 iconos SVG pixel-art** (`IconosHUD.gd`), miniaturas 3D en vivo (`MiniaturaRenderer.gd`) y botones de `104×76 px` con insignias en 3 esquinas.

---

## 3. Próximas Fases (Fases 4 a 7)

| Fase | Enfoque del Hito | Sistemas Clave |
| :--- | :--- | :--- |
| **Fase 4 (PoC 7)** | **Cámara Dual de Combate y Selección de Tropas** | Selección por recuadro y órdenes tácticas de escuadras militares (`militar`) desde la vista cenital combinadas con combate en 1ra persona. |
| **Fase 5 (PoC 8–10)** | **Logística Avanzada y Sistema de Puentes** | Carretas de carga terrestre, puentes modulares sobre ríos/cañones y líneas ferroviarias. |
| **Fase 6** | **Combate, Asedios, IA y Sucesión de Avatar** | Campamentos enemigos procedurales, incursiones a puestos periféricos, murallas y sucesión del avatar tras baja (`K` o ahogamiento). |
| **Fase 7** | **Multijugador LAN y Núcleos Portátiles** | Exportación del Núcleo Urbano y catálogo de *blueprints* hacia partidas multijugador competitivas y cooperativas. |
