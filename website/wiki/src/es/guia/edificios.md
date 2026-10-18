# Edificios, Niveles Urbanos y Almacenamiento

![Vista táctica cenital y planificación de distritos](/assets/hud-camara-cenital.png)

En **Craft to Nation**, las estructuras constituyen el corazón funcional de la civilización. Cada edificación se rige por validación volumétrica interior (`ValidadorEdificios.gd`), densidad demográfica por cama (`x_cama`), límites de altura según el **Nivel Urbano**, cadena estricta de desbloqueo académico y prioridades de obra configurables.

---

## 1. Clasificación Territorial de Edificios y Menús (`1 -> 1..4`)

El sistema organiza las construcciones en tres zonas excluyentes dentro del mundo de `200×200` celdas:

| Distrito (`Menú Zonificar`) | Categoría de Edificio (`Menú Construir`) | Ejemplos en el Motor | Regla de Emplazamiento |
| :--- | :--- | :--- | :--- |
| **Zona Residencial (`2 -> 1`)** | **Residencial (`1 -> 1`)** e **Investigación (`1 -> 4`)** | Viviendas (`Residencia [camas]x[baúles]`, ranuras `1`–`5`), `escuela_tecnica` (`1-4-1`), `escuela_especialistas` (`1-4-2`), `universidad` (`1-4-3`) | Dentro del Área de Influencia (`Radio 30`, `61×61` celdas) del Núcleo Urbano |
| **Zona Industrial (`2 -> 2`)** | **Industrial (`1 -> 3`)** | `siderurgica` (`1`), `refineria_tierras_raras` (`2`), `aserradero` (`3`), `fabrica_bloques` (`4`), `carbonera` (`5`), `refineria_petrolera` (`6`), `productor_combustible` (`7`), `central_termoelectrica` (`8`), **`almacen` (`9`)** | Sector industrial pintado dentro del Área de Influencia |
| **Periferia Silvestre** | **Periférico (`1 -> 2`)** | `caza_recoleccion` (`1`), `maderero` (`2`), `mina` (`3`), `pesca_frutos_mar` (`4`), `estacion_bombeo` (`5`), `centro_extraccion` (`6`) | **Fuera del Área de Influencia** (la huella se muestra roja si intentas colocarlos dentro de la ciudad) |

---

## 2. Niveles Urbanos (1 a 3) y Cadena Estricta de Educación e Investigación

| Nivel Urbano | Nombre de Etapa | Máx. Pisos por Vivienda | Máx. Camas por Piso | Tope por Edificio | Consumo Avatar | Requisitos de Desbloqueo (`Ciudad.gd`) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Nivel 1** | Asentamiento Rudimentario | **2 pisos** | **2 camas/piso** | **4 camas** | `5,0 comida/h` | Nivel inicial de partida |
| **Nivel 2** | Asentamiento Productivo | **4 pisos** | **4 camas/piso** | **16 camas** | `4,0 comida/h` | Sofisticación media `>= 1,7` + mín. `3` plantas Tipo 2 + Tecnología **Metalurgia Aplicada** (`300 Hierro`, `200 Madera`, `20 h_inv`) |
| **Nivel 3** | Metrópolis Tecnificada | **8 pisos** | **4 camas/piso** | **32 camas** | `3,0 comida/h` (`2,0` en alcaldía) | Sofisticación media `>= 2,5` + mín. `3` plantas Tipo 3 + Tecnología **Automatización Industrial** (`800 Hierro`, `100 Madera`, `50 h_inv`) |

### Orden Estricto de Desbloqueo Académico (`Zona Residencial: 1 -> 4 -> 1..3`)
1. **Escuela Técnica (`1 -> 4 -> 1`, `5×5` adobe):** Requiere contratar el cupo completo de **4 Aprendices** (tomados de `Obreros`/`Desempleados`). Una vez que los 4 están presentes en sus pupitres, el estudio avanza `1 h` por tick (si se despide a uno antes de terminar, el progreso se reinicia a `0`). Al cumplir **24 horas**, gradúa **3 Técnicos libres** (ocupando exactamente 1 cama).
2. **Escuela de Especialistas (`1 -> 4 -> 2`, `5×5` piedra):** Exige tener al menos **1 Escuela Técnica construida**. Entrena una cohorte completa de **3 Aprendices Técnicos** durante **48 horas** para graduar **2 Especialistas libres** (3 técnicos = 2 especialistas = 1 cama).
3. **Universidad Interactiva (`1 -> 4 -> 3`, `5×5` piedra):** Exige tener al menos **1 Escuela de Especialistas construida**. Contrata hasta **3 Especialistas libres**, quienes pasan al oficio de **Investigadores** (`investigador`):
   - **Inicio Manual:** No arranca sola; debes pulsar **`[Iniciar Investigación]`** y confirmar el pago de materiales en el diálogo modal (`300 Hierro + 200 Madera` para *Metalurgia Aplicada*).
   - **Pausa y Cancelación con Reembolso del 100 %:** Permite **`[Pausar]`** / **`[Reanudar]`** en cualquier momento o **`[Cancelar]`** devolviendo el **100 % del hierro y madera** al almacén central.
   - Al completar las `20 horas-investigador` de **Metalurgia Aplicada**, se desbloquean en el menú Industrial (`1 -> 3`) la **Refinería Petrolera (`6`)**, el **Productor de Combustible (`7`)** y la **Central Termoeléctrica (`8`)**.

---

## 3. Puestos Periféricos, Niveles Romanos (`I`, `II`, `III`) y Baúl Local (`VentanaBaul`)

- **Encabezado Limpio e Insignia Romana:** En `PanelPuesto.gd`, el nivel del puesto se muestra mediante la insignia vectorial en números romanos (`romano_1.svg`, `romano_2.svg`, `romano_3.svg`) junto al icono del edificio, y la fila `"Producción:"` muestra el icono vectorial SVG de `16 px` de cada recurso seguido de su tasa horaria.
- **Regla del Rango Mínimo de Trabajadores:** Si contratas a 1 Técnico en una Mina (sin obreros), el puesto sube a **Nivel II**; si además contratas a 1 Obrero en esa misma mina, el puesto **permite contratarlo y baja limpiamente a Nivel I** (el rango mínimo entre sus trabajadores activos).
- **Interacción en 1ra Persona con el Baúl de Puesto (`VentanaBaul` — Tecla <kbd>E</kbd>):** Al entrar a pie a un puesto periférico activo y pulsar <kbd>E</kbd> apuntando a su baúl interior, se abre la ventana centrada **`VentanaBaul` (`320×260`)** que permite transferir recursos entre el depósito local del puesto y el almacén central mediante **`-`**, **`+`** o **`"Extraer todo"`** (y cerrarla al instante con <kbd>E</kbd> o <kbd>Esc</kbd>).

---

## 4. Jerarquía de Almacenamiento y el Almacén Industrial (`1 -> 3 -> 9`)

- **Almacén Central (`Ciudad.almacen`):** Parte con capacidad base de `500 u` general / `5.000 u` comida, que se **duplica (`×2`)** al declarar el Núcleo Urbano (`1.000 u` / `10.000 u`). Cada baúl colocado en viviendas residenciales suma **`+100 u` general** y **`+400 u` comida**.
- **Almacén Industrial (`1 -> 3 -> 9` en Zona Industrial):** Edificio de piedra de `5×5` celdas que añade **`+3.000 u`** de capacidad sólida y cuenta con **6 puertos exteriores de fluidos en elevación `Y = 4`** (pared izquierda con 3 entradas y pared derecha con 3 salidas para `agua`, `crudo` y `combustible`). En su `PanelPuesto`, los 6 puertos aparecen agrupados por recurso en desplegables colapsables con indicadores `⚪ Desconectado`, `🟢 Conectado` o `🔴 Derrame`, compartiendo un **pool global instantáneo de fluidos (`1.000 u` por almacén)**.

---

## 5. Prioridades de Construcción (`PanelEdificio`) y Jerarquía de Despacho

En cualquier edificio en construcción puedes hacer clic sobre el botón **`[Prioridad: Normal]`** para ciclar entre **`Normal` → `Alta` → `Baja` → `Normal`**. Los colonos libres (hasta **4 constructores por obra**) se despachan siguiendo estrictamente este orden global de prioridad:

1. **Construcción de Prioridad Alta** (`Prioridad Alta ▲▲▲`)
2. **Construcción de Prioridad Normal** (`Prioridad Normal ▲▲`)
3. **Demoliciones de edificios y vías** (Modo `3`)
4. **Tendido de vías** (`1 -> 5 -> 1`)
5. **Construcción de Prioridad Baja** (`Prioridad Baja ▲`)
