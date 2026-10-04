# Formación avanzada, investigación y energía — Especificación de diseño

Fecha: 2026-10-04. Cierra las decisiones que bloquean la Fase 3 indicadas en `docs/Pendientes y próximos pasos.md`: escuela de especialistas, universidad e investigaciones de activación, refinería petrolera, productor de combustible, central termoeléctrica, transmisión y déficit de energía.

## Objetivo y alcance

Esta entrega conecta la progresión demográfica existente (`obrero → técnico → especialista`), las investigaciones de nivel ya modeladas en `Ciudad.gd` y la parte de combustible/energía del catálogo de PoC 5. El resultado debe poder jugarse con los recursos crudos inyectados por pruebas; la extracción física de agua y crudo mediante bombas pertenece al siguiente subproyecto de fluidos.

Quedan fuera: bombas de agua/crudo, tuberías y cintas, energía obligatoria para todos los edificios desde la Era 3, investigadores como tipo demográfico formado, niveles de refinerías, recetas seleccionables por el jugador y balance final.

## Reglas transversales

- Los valores de esta especificación son el balance inicial de Fase 3, no marcadores pendientes.
- Cada edificio tiene una función y, salvo la excepción explícita de la central, una receta fija.
- El costo de construcción se cobra bloque a bloque con el mecanismo existente. La ficha fija un presupuesto material objetivo; la plantilla debe respetarlo exactamente.
- Las escuelas y la universidad no tienen almacén ni acarreadores.
- Los edificios industriales usan almacén local compartido entre entradas y salidas y un acarreador, igual que las refinerías actuales.
- Técnicos y especialistas libres conservan su oficio al ser despedidos o al deconstruirse su lugar de trabajo.
- Especialistas pueden ocupar cualquier plaza que acepte técnicos. Para investigación y formación se aplica el mínimo indicado por la ficha.
- La energía se mide en `E/h`, no se guarda en `Ciudad.almacen`, no viaja en manos de acarreadores y no deja remanentes entre ticks.

## Fichas cerradas

| Edificio | Zona / desbloqueo | Personal | Almacén | Ciclo | Presupuesto de construcción |
|---|---|---:|---:|---|---|
| Escuela de especialistas | Residencial/investigación; requiere nivel investigado 2 | cohorte de 3 técnicos | ninguno | 48 h de presencia completa → 2 especialistas | 120 piedra, 40 madera, 30 hierro, 8 tierra |
| Universidad | Residencial/investigación; disponible en nivel 1 | 3 investigadores presentes | ninguno | horas-investigador según proyecto | 200 piedra, 80 madera, 60 hierro, 12 tierra |
| Refinería petrolera | Industrial; requiere nivel investigado 2 | 4 técnicos/especialistas + 1 acarreador dentro del cupo | 1000 total | por trabajador y hora: 2 crudo + 1 E → 1 combustible | 180 piedra, 40 madera, 100 hierro, 30 acero, 8 tierra |
| Productor de combustible | Industrial; requiere nivel investigado 2 | 4 técnicos/especialistas + 1 acarreador dentro del cupo | 1000 total | por trabajador y hora: 3 carbón + 1 agua + 1 E → 2 combustible | 160 piedra, 50 madera, 80 hierro, 20 acero, 8 tierra |
| Central termoeléctrica | Industrial; requiere nivel investigado 2 | 3 técnicos/especialistas + 1 acarreador dentro del cupo | 300 de combustible total | por trabajador y hora: 1 carbón **o** 1 crudo **o** 1 combustible → capacidad de 20 E/h | 250 piedra, 50 madera, 150 hierro, 60 acero, 10 tierra |

`madera` en los presupuestos puede pagarse con tablas mediante `Ciudad.consumir_costo()`. Los presupuestos no son un cobro adicional: son la suma exacta de los bloques de cada plantilla.

## Escuela de especialistas

- Tipo técnico: `escuela_especialistas`.
- Reutiliza el rol `aprendiz`; `Recoleccion.ESCUELAS` declara `origen = "tecnico"`, `destino = "especialista"`, `horas = 48`.
- El cupo se deriva de `x_cama` del origen: 3 técnicos. Al graduarse salen 2 especialistas, conservando vivienda: `3 × 1/3 = 2 × 1/2 = 1 cama`.
- La cohorte empieza a acumular solo con los 3 asignados y presentes. Una ausencia pausa; despedir a uno reinicia el progreso a cero.
- Los aprendices siguen siendo `tecnico` en demografía y color. Al graduarse, dos ids pasan a `especialista`; el tercero abandona la ciudad.
- Usa tres `mesa_estudio`; no se crea otro bloque funcional. La diferencia visual está en la plantilla.
- No consume energía durante esta fase: la cadena puede arrancar con técnicos aunque todavía no exista generación.
- El panel muestra `Técnicos en formación: n/3` y `Progreso: h/48 h`.

## Universidad e investigaciones de activación

### Personal

- Tipo técnico: `universidad`.
- Cupo 3, rol laboral `investigador`, sin conversión demográfica permanente.
- Para `Metalurgia Aplicada` admite técnicos o especialistas libres; para `Automatización Industrial` admite solo especialistas libres.
- El colono conserva su tipo demográfico mientras investiga y al ser despedido. La entrada demográfica `investigador` permanece reservada para una fase futura y no participa en esta implementación.
- Solo investigadores presentes aportan progreso.

### Proyectos

| Id | Nombre | Prerrequisitos | Costo al iniciar | Trabajo | Energía | Desbloqueo |
|---|---|---|---|---:|---:|---|
| `nivel_2` | Metalurgia Aplicada | nivel potencial 2; nivel investigado 1 | 300 hierro + 200 madera | 20 h-investigador | 0 E/h | nivel investigado 2; escuela de especialistas; edificios de combustible y energía |
| `nivel_3` | Automatización Industrial | nivel potencial 3; `nivel_2` completa | 800 hierro + 100 madera | 50 h-investigador | 2 E por investigador y hora | nivel investigado 3 |

- Hay un solo proyecto activo para toda la ciudad; varias universidades suman sus investigadores presentes.
- Como solo existe una ruta lineal, la universidad trabaja automáticamente en el siguiente proyecto elegible; no se crea un selector de investigación.
- Los recursos se validan y cobran de forma atómica al completar el umbral. Si faltan, el progreso queda topado en el umbral y reintenta en horas posteriores sin perder trabajo ni cobrar parcialmente.
- Si el nivel potencial cae, si faltan investigadores o si el edificio queda desconectado de energía para `nivel_3`, el progreso se pausa y se conserva.
- El progreso horario es `investigadores_presentes × factor_energia`. Para `nivel_2`, `factor_energia = 1`. Para `nivel_3`, es la fracción de energía entregada a la universidad.
- Al completar se actualiza `Ciudad.nivel_investigado`, se emite una notificación y se liberan los investigadores del proyecto; conservan su oficio.
- No hay cancelación ni reembolso porque no existe selección manual y el pago ocurre al completar.

### Sofisticación física

`Ciudad.instalaciones` deja de depender de datos puestos a mano y se sincroniza con edificios completos, no marcados para demolición:

- Tipo 2: `siderurgica`, `refineria_tierras_raras`, `aserradero`, `carbonera`.
- Tipo 3: `refineria_petrolera`, `productor_combustible`, `central_termoelectrica`.
- Puestos de extracción, escuelas, universidad y residenciales no cuentan.
- Una instalación cuenta aunque temporalmente no tenga personal o insumo; deja de contar al iniciar su deconstrucción y vuelve a contar si se reconstruye. Esto evita oscilaciones de nivel y vivienda por una entrega tardía.

Se conservan la fórmula y umbrales actuales: nivel potencial 2 con índice ≥ 1,7 y al menos 3 instalaciones tipo 2; nivel potencial 3 con índice ≥ 2,5 y al menos 3 instalaciones tipo 3.

## Producción de combustible

- Recursos nuevos del stock central: `agua`, `crudo`, `combustible`; capacidad base 500, igual que los demás recursos no alimentarios, e inicio en cero.
- La refinería petrolera y el productor reutilizan entrada/salida, acarreo, carga mínima, presencia, humo y panel de las refinerías actuales.
- La tasa nominal se escala por la fracción de energía recibida. Con 4 trabajadores, energía completa e insumo suficiente:
  - refinería petrolera: consume 8 crudo/h y 4 E/h; produce 4 combustible/h;
  - productor: consume 12 carbón/h, 4 agua/h y 4 E/h; produce 8 combustible/h.
- Con energía al 40 %, todos los flujos de la receta quedan al 40 %; no se consume un lote entero para producir una fracción menor.
- La capacidad local de 1000 se reparte dinámicamente: las entradas pueden ocupar como máximo la proporción de su receta y el producto usa el resto. El acarreador nunca transporta energía.

## Generación termoeléctrica

- La central es una excepción deliberada a la regla de receta fija: su única función es `generar_energia`, pero acepta tres combustibles equivalentes para asegurar el arranque de la red.
- Orden automático de consumo: `combustible`, luego `crudo`, luego `carbon`. No hay selector en esta fase.
- Cada trabajador presente habilita hasta un lote/h. Cada lote consume una unidad del primer insumo disponible y ofrece 20 E/h.
- La central solo quema lo necesario para la demanda conectada. Si la demanda es 15 E y hay capacidad para 60 E, consume 0,75 unidades, no 3.
- Varias centrales comparten la carga proporcionalmente a su capacidad disponible después de aplicar sus límites de personal e insumo.
- Con demanda cero no consumen combustible. Sin insumo o sin trabajadores su capacidad es cero.
- La energía nunca alimenta a la propia central.

## Transmisión

Existe una sola red urbana:

1. Todo edificio cuya huella toque la zona de influencia está conectado.
2. Una vía transmite energía si su componente ortogonal XZ toca al menos una celda de la zona de influencia.
3. Un edificio fuera de la influencia está conectado si una celda de su huella está dentro de distancia Manhattan 1 de una vía energizada.
4. Las diferencias de altura, rampas y cuñas no cortan la conexión: la topología usa columnas XZ de `Vias`.
5. Quitar un tramo recalcula la conexión antes del siguiente tick.

La API se prepara para añadir ferrocarriles, cintas y tuberías como más columnas conductoras, pero en esta fase la única fuente fuera de la influencia es `Vias`.

## Balance y déficit de energía

En cada hora simulada:

1. Se reúnen consumidores conectados y su demanda nominal.
2. Se calcula la capacidad de las centrales a partir de personal e insumo local.
3. `entregada = min(demanda, capacidad)`.
4. `factor = 1` si la demanda es cero; de lo contrario `entregada / demanda`.
5. Todos los consumidores conectados reciben el mismo factor; los desconectados reciben cero.
6. Las centrales consumen `entregada / 20` unidades de combustible, repartidas proporcionalmente.
7. Refinerías y universidad procesan el tick usando su factor.

No hay prioridades configurables en esta fase. El reparto proporcional evita que el orden de los diccionarios decida qué edificio funciona.

Estados visibles:

- `Sin conexión`: demanda potencial, entrega cero por topología.
- `Sin generación`: conectado, demanda positiva y capacidad cero.
- `Déficit`: conectado y `0 < factor < 1`.
- `Con energía`: `factor = 1`.
- `Sin demanda`: no consume ni provoca quema.

La barra superior muestra `Energía: entregada/demanda E/h` y se pone roja en déficit. El panel de cada consumidor muestra su estado y porcentaje; la central muestra capacidad, generación usada y combustible actual.

## Orden del tick

Para evitar dependencia del orden de señales:

1. `Ciudad.simular_tick()` procesa comida, vivienda y migración y emite `tick_simulado`, como hoy.
2. `Economia.simular_hora()` recibe esa señal y, dentro de una sola función, calcula primero energía y después formación, investigación y recetas.
3. `Economia` entrega las horas-investigador agregadas a `Ciudad.actualizar_investigacion(horas)`.

No se introduce un coordinador nuevo: mantener energía y consumidores dentro del mismo tick de `Economia` hace explícito el orden relevante sin duplicar el reloj existente.

## Casos límite cerrados

- Recursos de una investigación insuficientes al alcanzar el umbral: no se cobra nada, el progreso queda topado y se reintenta en la hora siguiente.
- Universidad demolida: el proyecto global y lo pagado se conservan; el aporte de esa universidad desaparece.
- Técnico/especialista contratado por otro puesto mientras investigaba: deja de aportar inmediatamente.
- Graduación sin vivienda extra: siempre conserva exactamente una cama ocupada por cohorte.
- Déficit variable: admite progreso y producción fraccionarios; nunca reinicia cohortes ni proyectos.
- Red cortada: factor cero desde el siguiente tick, sin consumir entradas industriales.
- Producto llena el almacén: la receta se limita por espacio antes de consumir entradas o energía.
- Central con mezcla de combustibles: agota por orden automático y puede completar una fracción con el siguiente combustible.
- Instalación en demolición: deja de contar para sofisticación al primer paso; reconstruirla la registra una sola vez.

## Criterios de aceptación

- Una cohorte de 3 técnicos presentes durante 48 h produce 2 especialistas y retira 1 colono sin cambiar la vivienda ocupada.
- Metalurgia acumula automáticamente 20 h-investigador de técnicos presentes, cobra de forma atómica al completar y desbloquea nivel 2, la escuela de especialistas y las tres industrias energéticas.
- Automatización solo admite especialistas, demanda 2 E por investigador, conserva progreso en déficit y completa a 50 h-investigador.
- Ambas recetas de combustible producen exactamente las tasas de la ficha con energía completa y proporcionalmente con déficit.
- Una central con un trabajador y una unidad de cualquier combustible puede entregar hasta 20 E durante una hora y no quema excedentes.
- Dos consumidores reciben el mismo porcentaje de energía con independencia de su orden de registro.
- Un edificio conectado por vía pierde energía al cortar el único tramo y la recupera al restaurarlo.
- El HUD y los paneles distinguen desconexión, ausencia de generación y déficit.
- La suite completa de escenas Godot termina limpia mediante `tools/run-godot-tests.ps1`.
