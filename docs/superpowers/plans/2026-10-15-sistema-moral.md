# Plan de Implementación: Sistema de Moral y Dinámica Poblacional (GDD v3.56)

**Fecha:** 2026-10-15  
**Especificación:** [`docs/superpowers/specs/2026-10-15-sistema-moral-design.md`](docs/superpowers/specs/2026-10-15-sistema-moral-design.md)  
**Rama de trabajo sugerida:** `feature/sistema-moral`

---

## Resumen del Trabajo

Implementar el sistema integral de Moral ($0$ a $100$) como simulación dinámica continua, vinculando la salud económica y residencial con la productividad laboral (fórmula continua), el flujo de población (inmigración continua, sobrepoblación en 'sin techo', éxodo jerárquico por moral crítica $<20$, éxodo por desempleo $>10$ días y tolerancia de $72$ horas para sin techo), y su correspondiente interfaz visual (botón interactivo con emojis 😡/🙁/😐/🙂 en `BarraSuperior.gd` y nueva modal `VentanaMoral.gd`).

---

## Línea A: Núcleo de Moral, Dinámica de Recursos y Población (`Ciudad.gd`)

### Task 1: Estado, Tasa de Cambio Horaria y Multiplicador de Productividad
- **Archivos:**
  - `godot/scripts/Ciudad.gd`
  - `godot/scripts/CiudadTest.gd`
- **Paso 1 (Test en rojo):**
  - En `CiudadTest.gd`, agregar prueba para:
    - `moral` inicial en $75.0$ (optimismo).
    - Cálculo de `calcular_multiplicador_productividad(moral)` con la fórmula:
      $$X = 0.5 + 0.5 \times (1.33256)^{\left(\frac{Y}{50}\right)} \times (1.25052)^{\left(\frac{Y}{50}\right)^2}$$
    - Simulación de ticks: caída de moral ante hambruna / comida agotada ($-3.0/\text{h}$), alerta ante tasa negativa ($-0.6/\text{h}$), incremento por variedad de dieta ($+0.5/\text{h}$ con 6 grupos), inercia suave hacia $50.0$, y desgaste por colonos sin techo.
    - Buffer móvil de peligrosidad (`registro_seguridad_168h` acumulando 0).
- **Paso 2 (Implementación mínima):**
  - En `Ciudad.gd`:
    - Declarar constantes de moral (`MORAL_INICIAL = 75.0`, `MORAL_NEUTRAL = 50.0`, `INERCIA_MORAL = 0.02`).
    - Declarar variables `moral: float = MORAL_INICIAL`, `tasa_cambio_moral: float = 0.0`.
    - Implementar `static func calcular_multiplicador_productividad(p_moral: float) -> float`.
    - Implementar buffer circular o acumulador `registro_seguridad_168h` y métodos de registro (heridos, caídos, robos).
    - En `simular_tick()`, calcular la tasa de cambio $\Delta M$ sumando inercia, dieta, balance/escasez de recursos, sin techo y peligrosidad, actualizando `moral = clampf(moral + tasa_cambio_moral, 0.0, 100.0)`.
- **Paso 3 (Verificación):**
  - Ejecutar: `powershell -ExecutionPolicy Bypass -File tools/run-single-test.ps1 -Scene CiudadTest.tscn`

---

### Task 2: Flujo Migratorio (Umbral 20), Éxodo Jerárquico, Desempleo y Tolerancia 72h
- **Archivos:**
  - `godot/scripts/Ciudad.gd`
  - `godot/scripts/CiudadTest.gd`
- **Paso 1 (Test en rojo):**
  - En `CiudadTest.gd`, agregar prueba para:
    - Moral $> 20$: inmigración continua tras fundar núcleo; los que excedan camas entran como `sin_techo`.
    - Moral $< 20$: éxodo de ciudadanos con jerarquía de fuga de cerebros (`investigador > especialista > tecnico > militar > obrero`).
    - Desempleo $> 240$ horas ($10$ días): emigración voluntaria por falta de trabajo.
    - Tolerancia de `sin_techo`: tolerancia ampliada a $72$ horas antes del exilio.
- **Paso 2 (Implementación mínima):**
  - En `Ciudad.gd`:
    - Ampliar el límite de tiempo sin techo a $72$ ticks (`tiempo_sin_techo >= 72`).
    - Añadir tracking de horas de desempleo (cola o contador global/por habitante) para emigración a las $240$ h.
    - En `_migrar()`, condicionar el flujo al umbral de moral $20.0$:
      - Si `moral > 20.0`: tasa positiva de llegada hacia `sin_techo` si no hay camas libres.
      - Si `moral < 20.0`: retirar habitantes en orden `ORDEN_EXODO_MORAL = ["investigador", "especialista", "tecnico", "militar", "obrero"]`.
- **Paso 3 (Verificación):**
  - Ejecutar: `powershell -ExecutionPolicy Bypass -File tools/run-single-test.ps1 -Scene CiudadTest.tscn`
- **Commit:**
  - `git commit -m "feat(demografia): simulacion dinamica de moral, productividad no lineal y flujo migratorio por umbral 20"`

---

## Línea B: Productividad Laboral en Economía (`Economia.gd`)

### Task 3: Integración del Multiplicador de Moral en Tasas de Producción y Refinado
- **Archivos:**
  - `godot/scripts/Economia.gd`
  - `godot/scripts/EconomiaTest.gd`
- **Paso 1 (Test en rojo):**
  - En `EconomiaTest.gd`, agregar prueba verificando que las tasas de producción de puestos (`produccion_por_hora`, `recalcular_tasas`) y el procesamiento en refinerías (`_refinar`) se escalan por `Ciudad.calcular_multiplicador_productividad(Ciudad.moral)`.
- **Paso 2 (Implementación mínima):**
  - En `Economia.gd`:
    - Obtener `factor_moral = Ciudad.calcular_multiplicador_productividad(ciudad.moral) if ciudad != null else 1.0`.
    - Multiplicar las tasas horarias de extracción y producción por `factor_moral`.
    - En `_refinar()`, escalar la velocidad efectiva de procesamiento por `factor_moral * factor_energia`.
- **Paso 3 (Verificación):**
  - Ejecutar: `powershell -ExecutionPolicy Bypass -File tools/run-single-test.ps1 -Scene EconomiaTest.tscn`
- **Commit:**
  - `git commit -m "feat(economia): modulacion de tasas de produccion y refinado segun moral ciudadana"`

---

## Línea C: Interfaz Visual y Modal Informativo (`BarraSuperior.gd`, `VentanaMoral.gd`, `HUD.gd`)

### Task 4: Botón de Estado Anímico en Barra Superior, VentanaModal y HUD
- **Archivos:**
  - `godot/scripts/BarraSuperior.gd`
  - `godot/scripts/VentanaMoral.gd` *(Nuevo script)*
  - `godot/scripts/HUD.gd`
  - `godot/scripts/HUDTest.gd`
- **Paso 1 (Test en rojo):**
  - En `HUDTest.gd`, agregar pruebas para:
    - `BarraSuperior` muestra emoji correspondiente (`moral < 20` 😡, `20 <= moral < 35` 🙁, `35 <= moral <= 65` 😐, `moral > 65` 🙂).
    - Clic en el botón de moral emite señal `dato_pedido("moral")`.
    - `VentanaMoral` se abre, refleja el desglose de factores (dieta, recursos, sin techo, peligro) y se cierra con `Escape` o tecla `E`.
- **Paso 2 (Implementación mínima):**
  - En `BarraSuperior.gd`:
    - Reemplazar etiqueta estática de moral por botón interactivo con estilo `TemaHUD`.
    - Actualizar texto del botón: `"%s %.0f%%" % [emoji, moral]`.
  - Crear `godot/scripts/VentanaMoral.gd`:
    - Ventana modal centrada con estilo `TemaHUD`.
    - Secciones:
      - Encabezado: Valor actual de moral, tendencia horaria ($\Delta M/\text{h}$) y estado emocional.
      - Productividad laboral: Multiplicador actual ($X$).
      - Migración: Estado (inmigración activa o éxodo de cerebros si $<20$).
      - Desglose analítico de factores: balance de recursos, variedad de alimentos, penalización por sin techo, estabilidad de empleo y seguridad.
  - En `HUD.gd`:
    - Instanciar `VentanaMoral` y abrirla al recibir `dato_pedido("moral")`.
- **Paso 3 (Verificación):**
  - Ejecutar: `powershell -ExecutionPolicy Bypass -File tools/run-single-test.ps1 -Scene HUDTest.tscn`
- **Commit:**
  - `git commit -m "feat(hud): boton interactivo de estado animico y modal explicativo VentanaMoral"`

---

## Verificación Global Final

- Ejecutar la suite completa de pruebas:
  `powershell -ExecutionPolicy Bypass -File tools/run-godot-tests.ps1`
- Confirmar que las 28+ escenas pasen limpiamente sin regresiones.
- Actualizar `Documento de Diseño de Juego (GDD)_ Craft to Nation.md` a v3.56 y `docs/Pendientes y próximos pasos.md`.
- Fusionar la rama a `main` y hacer push a GitHub.
