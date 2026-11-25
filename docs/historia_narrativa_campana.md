# Concepto Narrativo y Modo Campaña — *Craft to Nation*

## 1. Visión General

El modo **Campaña** de *Craft to Nation* cumple una doble función: dar un marco narrativo coherente a todas las mecánicas del juego y servir como un **tutorial orgánico de ~1 hora** que enseña controles, flujo base, logística y el salto inicial hacia la industrialización sin sentirse como un manual aislado.

La historia parte de una premisa de tipo *isekai* con enfoque científico-filosófico: un ingeniero que busca salvar su mundo de un colapso ecológico proyecta una faceta de su consciencia hacia un universo virgen. Allí, lo que en el juego son mecánicas de supervivencia, construcción, vista cenital, logística, sucesión y evolución tecnológica, se integran como dones y aprendizajes reales dentro del relato.

---

## 2. Premisa y Prólogo: La Fractura Multiversal

### El Protagonista
Un ingeniero especializado en sistemas y desarrollo tecnológico vive en un mundo al borde de un cataclismo ecológico. Convencido de que la salida requiere comprender cómo evolucionan las civilizaciones, ha pasado años analizando las grandes rutas de desarrollo tecnológico —**steampunk, dieselpunk, cyberpunk y solarpunk**— intentando descifrar cómo levantar una sociedad próspera sin destruir el entorno que la sostiene.

### El Detonante
Tras varios días sin dormir, justo cuando su investigación parece acercarse a un punto de quiebre, el agotamiento lo vence. Decide descansar y cae en un sueño profundo y lúcido.

### La Visión del Multiverso
En el sueño aparece en medio de una **planicie completamente plana que se extiende hasta el infinito** en todas direcciones. De pronto, de su propio cuerpo emergen infinitas versiones de sí mismo que se multiplican, se expanden en todas direcciones y se separan unas de otras hasta dejarlo nuevamente solo en la inmensidad.

* **Vínculo con la jugabilidad:** Esta escena justifica dentro del universo narrativo por qué el jugador puede crear múltiples partidas y mundos distintos, y sienta la base para el **sistema multijugador**, donde distintas consciencias y ciudades pueden converger en un mismo escenario.

### La Génesis del Mundo y sus Pobladores Nativos
El vacío infinito comienza a transformarse ante sus ojos: se elevan montañas, brotan manantiales y cascadas, se hunden cuencas que se llenan de agua formando mares y canales que dan origen a ríos con corriente. Crecen bosques, aparece fauna y, dispersos en las lejanías de este nuevo plano, habitan **pequeños grupos humanos nómadas nativos**. El lienzo vacío se convierte en un ecosistema vivo y finito.

* **Vínculo con la jugabilidad:**
  * Introduce el mundo procedural finito y dinámico, donde el relieve, el agua, los bosques y los depósitos minerales son recursos reales y limitados que condicionan cada decisión.
  * Explica de forma orgánica tanto la llegada de los **primeros colonos** (nómadas que se acercan atraídos por el refugio, las camas, la comida y la buena moral del asentamiento) como la futura aparición de **grupos de pandilleros/bandidos** y **pueblos enemigos** que se organizan de forma hostil o rival en el continente.

### Formato de Presentación (Prólogo y Epílogo)
Para mantener una producción ágil y coherente con el estilo del juego, el Prólogo (*La Fractura Multiversal*) y el Epílogo (*El Despertar*) se presentan como **secuencias ilustradas en formato slideshow animado** (4–5 láminas con paneo/zoom suave, música de menú/exploración y narración) reutilizando la base de `VideoIntro.gd` / `Bienvenida.gd`, para fundirse directamente con el mundo procedural real en el instante en que el ingeniero despierta en el terreno.

---

## 3. La Voz Mística Interior y los Dones del Avatar

Cuando el mundo termina de tomar forma, el ingeniero percibe una **voz mística multiversal**. No suena como un ente externo tradicional, sino que se manifiesta **a través de sus propios pensamientos y su voz interior**, otorgándole lucidez en medio de la experiencia.

* **Presentación en partida:** La Voz Interior guía al jugador de forma no invasiva (sin congelar controles ni interrumpir el ritmo) mediante una **burbuja/panel de texto discreto en el HUD** acompañado de **locución con voz sintetizada** (pistas de audio pre-generadas offline e integradas con `Sonidos.gd`), junto a un listado breve de los objetivos activos del acto.

La Voz le revela cuatro verdades:
1. **Consciencia dividida:** Su cuerpo y su vida en su universo original continúan su curso; aquí ha despertado una proyección de su consciencia en una nueva realidad.
2. **Los dones del avatar:** Para cumplir su propósito en este plano, su consciencia recibe capacidades especiales que corresponden directamente a las mecánicas del juego:
   * **Proyección cenital y escaneo geológico:** La capacidad de desprender su percepción del cuerpo para elevarse siempre hasta la superficie y dirigir la ciudad desde el cielo (manteniendo túneles y cavernas ocultos a la vista aérea), además de percibir las vetas minerales del subsuelo al proyectar puestos de explotación.
   * **Almacén y materialización:** La habilidad de resguardar, organizar y materializar bloques, recursos y herramientas (pala, pico, hacha, lámpara, entre otras).
   * **Lectura estructural y planos (*Blueprints*):** La facultad de reconocer construcciones funcionales y convertirlas en plantillas reutilizables para escalar la arquitectura de su civilización.
3. **Continuidad de la consciencia (Sucesión y Elecciones):** Si su cuerpo físico cae por hambre o en combate, su consciencia proyectada no muere: queda suspendida sobre el **Núcleo Urbano** mientras el pueblo elige al habitante más apto para recibirla (considerando el rol, la moral y el rumbo de la ciudad, conectando a futuro con la personalización de unidades y el escuadrón de élite).
4. **El propósito:** Crear y desarrollar desde cero una civilización próspera y poderosa, capaz de gestionar los recursos de este mundo, integrar a los nómadas y superar los límites de la supervivencia primitiva.

---

## 4. Estructura de la Campaña-Tutorial (~1 hora)

La campaña se juega sobre una **semilla controlada** (que garantiza bosque, piedra, río, relieve moderado y vetas subterráneas accesibles cerca del punto de inicio) y se divide en **cuatro actos encadenados** que llevan al jugador desde la supervivencia individual hasta el inicio de la **industrialización (Era 2)**:

| Acto / Misión | Duración aprox. | Enfoque Narrativo | Mecánicas y Controles que Aprende el Jugador |
| :--- | :---: | :--- | :--- |
| **Acto I: El Primer Cimiento** | 10–15 min | El ingeniero enfrenta la vulnerabilidad física en un mundo virgen y comprende que sobrevivir no basta: necesita una base con propósito. | Movimiento y cámara en 1.ª persona, gestión del hambre, tala/minado/recolección manual, uso de herramientas, construcción bloque a bloque (puerta, ventana, cama, baúl, cerramiento y altura mínima) y declaración del **Núcleo Urbano**. |
| **Acto II: Mirar desde el Cielo** | 10–15 min | La Voz despierta la proyección cenital. Al ver fuego, refugio y orden, los primeros **nómadas nativos** comienzan a acercarse al asentamiento. | Alternancia entre 1.ª persona y **cámara cenital**, zonificación residencial dentro del área de influencia, uso de **plantillas (*blueprints*)**, nivelación de terreno, llegada de los primeros colonos y lectura de indicadores (población, camas, comida, moral). |
| **Acto III: El Pulso de los Recursos** | 15 min | Con los nuevos habitantes llegan las necesidades reales. El ingeniero aprende que el territorio debe organizarse y conectarse para sostener el crecimiento. | Emplazamiento de puestos periféricos (caza/recolección, maderero, mina, pesca), lectura de previsualización y entorno real, asignación de **recolectores y acarreadores**, trazado de vías para acelerar el tránsito y manejo del agotamiento de recursos. |
| **Acto IV: La Chispa Industrial y el Despertar** | 15 min | La aldea ya sobrevive, pero el ingeniero descubre que recolectar en la superficie tiene un techo. Debe mirar bajo tierra, formar mentes técnicas y encender la primera industria. | Exploración del **subsuelo con lámpara** y escaneo de vetas al proyectar un puesto de extracción, zonificación del **Polígono Industrial (Zona B)**, construcción de la **Escuela Técnica** (formación de los primeros `técnicos`) y puesta en marcha de la primera industria de transformación (**Aserradero** como hito principal; Carbonera, Siderúrgica o Acueducto como expansión opcional), logrando la transición orgánica hacia la **Era 2**. |

---

## 5. El Desenlace: Un Despertar con Propósito

Al encender los cimientos de la industrialización y comprobar que su civilización ha dado el salto hacia una sociedad técnica organizada, la experiencia llega a su punto de cierre. La voz interior se serena y se desvanece suavemente; el ingeniero **despierta en su vida "real"**, en el mismo lugar donde se había quedado dormido tras días de investigación.

Todo parece haber sido un sueño, pero la sensación no es de vacío, sino de **revelación práctica**:
* El agotamiento y el bloqueo mental han desaparecido.
* Aunque no trajo objetos físicos de aquel universo, despertó con **el conocimiento y el método claros** para comprender cómo nace, se organiza, se abastece, se industrializa y evoluciona una civilización frente a los límites de su entorno.
* Ahora sabe exactamente qué debe hacer.

### Pantalla de Cierre Post-Epílogo (Sin pérdida de progreso)
Al concluir la breve secuencia ilustrada del Despertar, el juego presenta dos opciones claras para que el jugador conserve todo su esfuerzo:
1. **«Continuar en esta ciudad (Modo Libre)»:** Regresa directamente al asentamiento ya industrializado del Acto IV, sin restricciones de tutorial, para expandirlo hacia las Eras 3 y 4 y enfrentar las amenazas del continente.
2. **«Iniciar una nueva nación»:** Abre la pantalla de Nueva Partida para comenzar desde cero con una semilla y parámetros personalizados.

---

## 6. Puente hacia el Juego Completo y el Largo Plazo

El final de la campaña-tutorial abre el resto de *Craft to Nation* de forma natural:
* **Continuidad táctica, industrial y militar:** Sobre su asentamiento o en una partida nueva, el jugador profundiza en cadenas industriales avanzadas, fluidos, redes eléctricas, defensa contra **pandilleros y pueblos enemigos** surgidos de los grupos nativos del continente, combate híbrido (cenital + primera persona) y sucesión de liderazgo.
* **Las Eras Tecnológicas como reflejo de su investigación:** Conforme la ciudad avanza más allá de la Era 2 hacia la industrialización plena, las decisiones reales de construcción, leyes, energía y doctrina militar moldean de forma emergente el destino de su civilización hacia **Dieselpunk**, **Cyberpunk** o **Solarpunk**, cerrando el círculo temático con la investigación original del ingeniero.
* **Multijugador multiversal:** Cada nueva partida y cada encuentro en red local o futuro entorno compartido retoma la metáfora del prólogo: distintas proyecciones de consciencia llevando sus núcleos soberanos y sus planos a nuevos mundos para cooperar o competir.


---

## 7. Guion de Campaña — *Craft to Nation*

> **Nota de producción:** Las láminas del Prólogo y Epílogo incluyen dirección visual, movimiento de cámara y locución; las líneas en partida son breves (5 a 10 segundos cada una) para funcionar en la burbuja discreta del HUD sin interrumpir el juego.

### Parte 1: Prólogo — *La Fractura Multiversal* (Slideshow ilustrado)

> **Dirección general:** 5 láminas con paneo/zoom lento (*Ken Burns*). La música inicia contenida y melancólica (Lámina 1), se abre a un ambiente etéreo (Lámina 2) y crece hacia un pulso orgánico y luminoso (Láminas 3–5) antes de fundirse con el sonido ambiente del mundo en vivo.

#### Lámina 1 — El límite del colapso

* **Visual:** Un escritorio saturado de planos, libretas y diagramas de ecosistemas al borde del colapso. En el fondo, tras una ventana nublada, una ciudad industrial agotada. El ingeniero apoya la cabeza sobre sus brazos, vencido por el cansancio.
* **Movimiento:** Zoom lento hacia los bocetos sobre la mesa (engranajes, redes, paneles, árboles).
* **Locución (Voz del ingeniero, cansada pero lúcida):**
  > *«Llevo años estudiando cómo nacen y caen las civilizaciones. Vapor, combustión, máquinas, ecología... Buscaba una fórmula para salvar nuestro mundo antes del colapso. Por primera vez, las piezas parecían encajar. Solo necesitaba cerrar los ojos un instante.»*

#### Lámina 2 — La planicie infinita

* **Visual:** Un horizonte blanco e infinito, completamente plano. El ingeniero de pie en el centro. De su silueta se desprenden ecos translúcidos de sí mismo que se multiplican en abanico y se alejan en todas direcciones hasta desvanecerse en la distancia.
* **Movimiento:** Alejamiento progresivo (*zoom out*) que resalta la inmensidad y la soledad al quedar de nuevo solo.
* **Locución (Voz del ingeniero, asombrada):**
  > *«Pero no desperté en mi cuarto. Desperté en un plano sin fin... y vi incontables versiones de mí separarse hacia horizontes distintos. Otros mundos. Otros comienzos. Hasta que volví a quedar solo.»*

#### Lámina 3 — La génesis del mundo

* **Visual:** La planicie se fractura y cobra vida: se alzan montañas, brotan cascadas que tallan ríos hacia el mar, emergen bosques densos y fauna silvestre. En la lejanía, siluetas diminutas de pequeños grupos nómadas cruzan una colina.
* **Movimiento:** Paneo horizontal lento recorriendo la transformación del relieve.
* **Locución (La Voz Interior comienza a superponerse con un eco sutil y sereno):**
  > *«Entonces el vacío tomó forma. Piedra, agua, madera, vida... Un mundo entero, real y finito. Y en sus lejanías, gentes errantes buscando un lugar donde echar raíces.»*

#### Lámina 4 — La Voz y los dones

* **Visual:** Vista elevada desde las nubes mirando hacia un valle virgen donde el ingeniero está de pie. A su alrededor flotan sutiles líneas geométricas de plano arquitectónico y destellos suaves de herramientas (pico, hacha, pala, lámpara).
* **Movimiento:** Descenso suave desde el cielo hacia el avatar.
* **Locución (Voz Mística Interior — clara, pausada, resonando como pensamiento propio):**
  > *«No temas. Tu cuerpo sigue respirando en tu mundo; aquí ha despertado una faceta de tu consciencia. Podrás elevar tu mirada al cielo, moldear la materia y leer planos de lo que construyas. Y si este cuerpo cae, tu voluntad aguardará sobre tu ciudad hasta que tu pueblo elija a su nuevo portador.»*

#### Lámina 5 — El propósito (Transición al juego)

* **Visual:** Primer plano del ingeniero mirando el valle virgen al amanecer. La luz se intensifica hasta fundirse directamente con la cámara en primera persona del mundo procedural.
* **Movimiento:** *Fade* luminoso directo al gameplay.
* **Locución (Voz Mística Interior):**
  > *«Tu misión es simple, pero colosal: levanta una civilización capaz de dominar estos recursos sin consumirse a sí misma. Empieza por el primer bloque.»*

---

### Parte 2: Guion en Partida — La Voz Interior (Actos I a IV)

> **Convención técnica:** Cada entrada tiene un `ID` para enlazar con el archivo de audio en `Sonidos.gd`, un `Disparador` lógico, el texto breve de la burbuja y el objetivo que se actualiza en la lista del HUD. Todas las teclas coinciden con `Player.gd`, `CamaraCenital.gd` y `BarraModos.gd`.

#### Acto I — El Primer Cimiento *(~10–15 min)*

| ID | Disparador | Línea de la Voz Interior (HUD + Audio) | Objetivo activo en HUD |
| --- | --- | --- | --- |
| `A1_01` | Al aparecer en el mundo | *«Primero, siente el terreno bajo tus pies. Aquí el hambre es real: reúne madera, piedra y algo de alimento antes de pensar en grande.»* | Muévete (`WASD`) y recolecta recursos básicos (clic izq. para minar/talar, `E` en árboles para frutos). |
| `A1_02` | Al completar la primera recolección | *«Bien. Tu almacén interior retiene lo que tomas, pero tiene un límite. Necesitas un refugio cerrado que sea el corazón de todo lo que vendrá.»* | Elige bloques en la hotbar (`1–0` o rueda) y construye con clic der. un refugio cerrado: piso, paredes, techo (altura mín. 3), puerta, ventana, cama y baúl. |
| `A1_03` | Al colocar la primera puerta o cama | *«Cada abertura respira hacia el exterior y cada habitación exige espacio. Construye con orden: lo que levantes hoy servirá de molde mañana.»* | Completa el cerramiento de tu refugio y verifica que tenga puerta, ventana, cama y baúl. |
| `A1_04` | Al declarar el **Núcleo Urbano** (`B` sobre la puerta en modo Construcción `T`) | *«Ahí está. Tu primer cimiento con propósito. El almacén se expande y el territorio reconoce tu presencia. Pero una sola casa no hace una nación.»* | **Acto I completado.** Prepárate para elevar tu mirada. |

---

#### Acto II — Mirar desde el Cielo *(~10–15 min)*

| ID | Disparador | Línea de la Voz Interior (HUD + Audio) | Objetivo activo en HUD |
| --- | --- | --- | --- |
| `A2_01` | Inicio del Acto II | *«Desprende tu mirada del suelo. Desde las alturas verás el terreno como un arquitecto, no solo como un sobreviviente.»* | Activa la **cámara cenital** (`C`) y explora tu área de influencia (`WASD`, `Q/E`). |
| `A2_02` | Al activar la cámara cenital por primera vez | *«El área alrededor de tu núcleo te pertenece. Delimita una zona residencial: será la señal para que otros sepan dónde echar raíces.»* | Activa **Zonificación** (`2`), elige **Zona A — Residencial e Investigación** (`1`) y pinta un área residencial. |
| `A2_03` | Al pintar la Zona A | *«No tienes que reinventar cada muro. Usa el plano de lo que ya construiste y proyéctalo sobre tu nueva zona; el terreno se nivelará para recibirlo.»* | Abre **Construir → Residencial** (`1` → `1` → `1`), emplaza una plantilla dentro de la Zona A y complétala. |
| `A2_04` | Al llegar el primer colono (nómada nativo) | *«Mira el horizonte... Los nómadas vieron refugio, orden y sustento. Ya no estás solo. Vigila sus camas, su comida y su ánimo en la barra superior.»* | **Acto II completado.** Revisa población, camas, comida y moral en el HUD. |

---

#### Acto III — El Pulso de los Recursos *(~15 min)*

| ID | Disparador | Línea de la Voz Interior (HUD + Audio) | Objetivo activo en HUD |
| --- | --- | --- | --- |
| `A3_01` | Inicio del Acto III | *«Más manos traen fuerza, pero también bocas que alimentar. Tus manos no bastarán: levanta puestos en la periferia donde abunde el recurso.»* | En cenital, abre **Construir → Periférico** (`1` → `2`) y emplaza un puesto de **Caza** (`1`) o **Pesca** (`4`) leyendo su previsualización. |
| `A3_02` | Al colocar el primer puesto de comida | *«Un edificio vacío no produce nada. Haz clic sobre el puesto y asigna tanto a quien extrae como a quien carga el fruto hasta el núcleo.»* | Haz clic en el puesto y asigna al menos 1 **Recolector** y 1 **Acarreador**. |
| `A3_03` | Al asignar los trabajadores | *«Ahora repite el pulso con la madera o la piedra. Y recuerda: aquí la tierra es real; si un bosque o una veta se agotan, el puesto callará.»* | Abre **Construir → Periférico** (`1` → `2`), coloca un puesto de **Madera** (`2`) o una **Mina** (`3`) y asigna personal. |
| `A3_04` | Al colocar el segundo puesto | *«El tiempo que se pierde caminando entre la maleza es progreso perdido. Traza un camino de tierra: verás cómo la ciudad acelera su latido.»* | Traza una **vía de tierra** (en cenital: `1` → `5` → `1`; o con `V` en 1.ª persona) conectando un puesto con el Núcleo Urbano. |
| `A3_05` | Al completar el tramo de vía | *«El flujo está vivo. Tu gente recolecta, transporta y se sostiene. Has superado la supervivencia básica.»* | **Acto III completado.** Es hora de mirar más profundo. |

---

#### Acto IV — La Chispa Industrial y el Despertar *(~15 min)*

| ID | Disparador | Línea de la Voz Interior (HUD + Audio) | Objetivo activo en HUD |
| --- | --- | --- | --- |
| `A4_01` | Inicio del Acto IV | *«Recoger lo que yace en la superficie tiene un techo. La verdadera transformación empieza bajo tierra y dentro de talleres organizados.»* | Enciende tu **lámpara** (`L` en 1.ª persona) para explorar el subsuelo o escanea vetas al proyectar un puesto de extracción. |
| `A4_02` | Tras explorar o escanear | *«Tu vista desde el cielo siempre vuelve a la luz de la superficie, pero al proyectar un puesto percibes lo que oculta la roca. Ahora prepara el terreno para la industria.»* | En cenital, activa **Zonificación** (`2`) → **Zona B — Fabricación y Militar** (`2`) y pinta un polígono industrial dentro de tu influencia. |
| `A4_03` | Al pintar la Zona B | *«Las máquinas no se operan solo con fuerza bruta. Levanta una Escuela Técnica en tu zona cívica para formar mentes capaces de transformar la materia prima.»* | En **Zona A (Residencial e Investigación)**, construye una **Escuela Técnica** (`1` → `4` → `1`) y espera la graduación de tus primeros **técnicos**. |
| `A4_04` | Al graduarse el primer técnico | *«Ya tienes el conocimiento humano. Enciende la primera industria: convierte troncos en tablas en un Aserradero y cruza el umbral de una nueva era.»* | En **Zona B (Industrial)**, construye un **Aserradero** (`1` → `3` → `3`) y asígnale personal técnico *(Opcional: Carbonera, Siderúrgica o Acueducto)*. |
| `A4_05` | Al entrar en producción el Aserradero (transición a Era 2) | *«Escucha ese ritmo... Ya no sobrevives al entorno: lo moldeas con propósito. Has comprendido el método. Es momento de regresar.»* | **Campaña completada.** *(Pausa de 4 segundos y fundido suave hacia el Epílogo)*. |

---

### Parte 3: Epílogo — *El Despertar* (Slideshow ilustrado)

> **Dirección general:** 4 láminas. La música pasa del pulso activo de la ciudad a un acorde cálido y sereno de piano/sintetizador suave, cerrando el arco emocional del prólogo.

#### Lámina 1 — La ciudad que respira

* **Visual:** Vista panorámica del asentamiento al atardecer: casas iluminadas, caminos transitados por colonos, el aserradero trabajando en la Zona B y montañas con ríos al fondo.
* **Movimiento:** Alejamiento lento (*zoom out*) hacia el cielo dorado.
* **Locución (Voz Mística Interior, cada vez más suave, fundiéndose en la voz normal del ingeniero):**
  > *«Del primer bloque a una comunidad viva. Has visto cómo cada recurso cuenta, cómo el orden atrae a la gente y cómo la industria exige equilibrio.»*

#### Lámina 2 — El repliegue del sueño

* **Visual:** La ciudad se descompone suavemente en líneas geométricas luminosas y partículas que ascienden, volviendo por un instante al reflejo de la planicie infinita antes de disiparse en luz cálida.
* **Movimiento:** Disolución suave con brillo ascendente.
* **Locución (Voz del ingeniero, serena):**
  > *«La voz se apaga sin ruido. No se va del todo... simplemente vuelve a ser parte de mí.»*

#### Lámina 3 — De vuelta en el mundo real

* **Visual:** El mismo escritorio de la Lámina 1 del Prólogo, pero ahora entra luz clara de la mañana por la ventana. El ingeniero levanta la cabeza, descansado y con la mirada despejada.
* **Movimiento:** Acercamiento sutil a su rostro y luego hacia los planos sobre la mesa.
* **Locución (Voz del ingeniero, firme y tranquila):**
  > *«Al abrir los ojos, todo parecía haber sido solo un sueño. No traje piedra, ni madera, ni herramientas de aquel universo...»*

#### Lámina 4 — El método claro

* **Visual:** Sus manos toman un lápiz y trazan con seguridad el primer esquema limpio sobre una hoja nueva: un núcleo, zonas conectadas, rutas y equilibrio con el entorno.
* **Movimiento:** Zoom leve hacia el trazo limpio mientras aparece el título *Craft to Nation*.
* **Locución (Voz del ingeniero, resuelta):**
  > *«...pero desperté con algo más valioso: el método. Ahora sé exactamente qué debo hacer.»*

---

### Pantalla Post-Epílogo (Transición sin pérdida de progreso)

Al terminar la Lámina 4, aparece un panel limpio sobre el fondo difuminado de la ciudad:

> **«Has completado el despertar de tu civilización. Tu ciudad sigue viva y el continente apenas comienza a revelarse.»**
> * **[ Continuar en esta ciudad (Modo Libre) ]** — *Vuelve a tu asentamiento en Era 2 para expandirlo, defenderlo y moldear su destino tecnológico.*
> * **[ Iniciar una nueva nación ]** — *Abre Nueva Partida con semilla y parámetros personalizados.*

---

## Notas de dirección para la síntesis de voz offline (`Sonidos.gd`)

* **Diferenciación sutil de timbre:** Usa la misma voz base para el ingeniero y la Voz Mística Interior, pero aplica a la Voz Interior un **reverb ligero y un filtro cálido** (muy sutil, para que suene como un eco dentro de su mente y no como un robot).
* **Ritmo:** Velocidad ~0.92x–0.95x en el Prólogo y Epílogo (pausado, cinematográfico) y ~1.0x en las burbujas del HUD (ágil, claro y natural).
* **Silencios clave:** Dejar 1 a 1.5 segundos de respiro entre láminas para que el jugador absorba la ilustración antes de que entre la siguiente frase.