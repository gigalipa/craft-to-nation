# Hoja de Ruta (Roadmap) y Estado del Desarrollo (GDD v3.57)

![Vista táctica de defensa y expansión urbana](/assets/comparison-aerial.webp)

La evolución técnica de **Craft to Nation** sigue el plan de 7 fases definido en la **Sección 11 del GDD v3.57**, sustentado en **28 escenas de prueba automatizadas al 100 % en verde** y validación directa en partida.

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
- [x] Avatar en primera persona (`Player.gd`) con minado por grietas progresivas, recolección de frutos (`60 u` en `2,0 s`), natación con barra de oxígeno (`10,0 s`) y linterna frontal de minero (<kbd>L</kbd>).
- [x] Reconocimiento volumétrico de edificios herméticos (`ValidadorEdificios.gd`), declaración (<kbd>B</kbd>) y remodelación no destructiva (<kbd>Shift</kbd> + <kbd>B</kbd>).

### Fase 2: Fundación Cívica, Cámara Cenital y Demografía
- [x] Cámara cenital táctica (`CamaraCenital.gd`) con vuelo suave de transición (`0,6 s` con <kbd>C</kbd>), rotación de plantillas (`Ctrl + Rueda`) y catálogo de hasta 5 *blueprints* persistentes.
- [x] Delimitación de **Zona A** y **Zona B** dentro del radio de influencia (`30` celdas) del Núcleo Urbano (`Zonificacion.gd`).
- [x] Niveles Urbanos `1–3` (`2×2`, `4×4` y `8×4` pisos/camas), buffers de colonizabilidad de `24 h`, escuelas de cohorte (`escuela_tecnica`, `escuela_especialistas`) y `universidad`.

### Fase 3: Industrias, Fluidos, Moral Dinámica e Iconografía HUD (v3.56 – v3.57)
- [x] **Puestos Periféricos con Niveles `I–III` y Agotamiento Físico:** `maderero`, `mina` (profundidades 8/16/24), `caza_recoleccion`, `pesca_frutos_mar`, `estacion_bombeo` y `centro_extraccion` con regresión automática de nivel.
- [x] **Trazado y Construcción de Vías por Colonos (`ConstructorVias.gd`):** Carreteras de tierra pisada (`+35 %` velocidad, coste A* `3` vs `8`), construidas por cuadrillas de colonos con selector de prioridades (**Alta `▲▲▲`**, **Normal `▲▲`**, **Baja `▲`**) y demolición guiada.
- [x] **Las 8 Instalaciones Industriales y Energéticas:** `aserradero`, `fabrica_bloques`, `carbonera`, `siderurgica`, `refineria_tierras_raras`, `refineria_petrolera` (tope 400/600), `productor_combustible` y `central_termoelectrica` (`20 E/h`, reserva de `500 Carbón`).
- [x] **Cuotas de Reserva de Materia Prima (`[0, 50, 100, 250, 500] u`):** Protección de stock de madera y piedra en bruto en `VentanaAlmacen.gd` y fábricas.
- [x] **Canalizaciones Aéreas Modulares (`Y + 6`):** Acueductos y tuberías con gálibo libre `Y + 5`, física de derrames por viscosidad y diagnóstico visual en `PanelCanalizacion.gd`.
- [x] **Moral Dinámica y Migración Mensual Escalonada (`Ciudad.gd`):** Curva continua de productividad (`0,5 × 2^(Moral / 50)`), tasa diaria aplicada por hora (`/ 24,0`) y 9 tramos escalonados de migración mensual (`-5` a `+5 colonos/mes`).
- [x] **Iconografía Vectorial HUD y Miniaturas 3D (v3.57):** Más de **90 iconos SVG pixel-art** (`IconosHUD.gd`), miniaturas 3D en vivo (`MiniaturaRenderer.gd`), botones de `104×76 px` en `BarraModos.gd` y balance eléctrico en `kW / MW` (`BarraSuperior.gd`).

---

## 3. Pendientes Inmediatos para el Cierre de Fase 3

1. **Ajuste Fino de Balance en Sesión Larga:** Validación en partida prolongada de los tiempos de transición de Nivel Urbano 1 → 2 → 3 con la nueva tabla de migración mensual escalonada.
2. **Consumo Universal de Energía de Era 3:** Extensión opcional del consumo eléctrico a edificios civiles avanzados al alcanzar la Era 3.

---

## 4. Próximas Fases (Fases 4 a 7)

### Fase 4: Cámara Dual de Combate y Selección de Tropas (PoC 7)
- Selección por recuadro (*box-select*) y comando táctico de escuadras militares (`militar`) desde la cámara cenital, alternando en tiempo real con el combate directo en primera persona.

### Fase 5: Logística Avanzada y Sistema de Puentes (PoC 8–10)
- Carretas de carga terrestre, puentes modulares sobre ríos/cañones y líneas ferroviarias para transporte masivo a larga distancia.

### Fase 6: Combate, Asedios, IA y Sucesión de Avatar
- Campamentos enemigos procedurales, incursiones a puestos periféricos, murallas y torretas defensivas, y sistema de sucesión del avatar tras baja en combate (tecla de prueba `K` ya integrada en base).

### Fase 7: Multijugador LAN y Núcleos Portátiles
- Exportación del Núcleo Urbano y catálogo de *blueprints* hacia partidas multijugador competitivas y cooperativas en red local (LAN) y servidores dedicados.
