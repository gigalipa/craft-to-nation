# Especificación Técnica: Sistema Militar, Doctrinas Asimétricas ($D / C / S$), Logística de Campaña y Batalla Híbrida

**Estado:** Aprobado para implementación  
**Fecha:** 2026-10-26 (Actualización v2.0)  
**Módulos Afectados:** `godot/scripts/ajustes.gd`, `godot/scripts/Ciudad.gd`, `godot/scripts/Colonos.gd`, `godot/scripts/PanelEdificio.gd`, `godot/scripts/Zonificacion.gd`, `godot/scripts/BuscadorRutas.gd`, `godot/scripts/Player.gd`, `godot/scripts/CaraApuntada.gd`.

---

## 1. Resumen Ejecutivo y Filosofía del Sistema

Este documento formaliza la arquitectura militar integral de *Craft to Nation*, combinando la visión estratégica macroscópica («El General» en cámara cenital) con el combate y liderazgo táctico visceral («El Comandante de Campo» en primera persona):

1. **Taxonomía de 4 Edificios de Producción Evolutivos:** Cuartel de Infantería (humana), Fábrica de Unidades Móviles Terrestres (caballería $\to$ blindados/asedio), Hangar de Unidades Voladoras y Complejo de Robótica Terrestre No Tripulada.
2. **Escuadrones Mixtos al estilo *0 A.D.* (hasta 20 unidades):** Control por batallón con ordenamiento automático en tres capas: *Vanguardia* (blindados y choque), *Línea Media* (tiradores, mechas y especialistas) y *Retaguardia Protegida* (asedio y soporte).
3. **Unidades de Soporte y Mitigación de Bajas Cívicas:** Médicos de campaña e Ingenieros reparadores que estabilizan heridos in-situ y evitan que computen como bajas definitivas en `bajas_7d` (protegiendo la moral cívica en `Ciudad.gd`).
4. **Cuatro Posturas Tácticas Cenitales:** *Guarnición / Mantener Posición*, *Avance de Asalto*, *Hostigamiento (Hit & Run)* y *Patrullaje Estricto con Disciplina de Ruta* (rondas entre waypoints sin desviarse a perseguir cebos).
5. **Logística de Campaña y Base de Operaciones Avanzada (FOB / Extensión de Comando):** Puesto periférico que proyecta una zona de influencia secundaria y reduce el consumo de campaña de $5.0$ a $3.0\text{ u/h}$, supeditado estrictamente a una vía activa conectada con el Núcleo Urbano (`_calcular_vias_conectadas`).
6. **Puntos Ciegos Cenitales y Batalla Híbrida en 1ª Persona:** Túneles subterráneos, unidades en sigilo en vegetación y domos de bruma Solarpunk son invisibles a la vista cenital. El Avatar comanda físicamente en el frente con su **Aura de Liderazgo** ($15\text{ m}$) y su **Escuadrón de Élite Personal** (hasta 5 guardaespaldas comandados con la mira y teclas `1–5`).

---

## 2. Taxonomía de Edificios de Producción Militar (Zona B)

Todos los edificios militares se emplazan en el **Polígono Industrial y Militar (Núcleo B)** y evolucionan por etapas:

```
┌────────────────────────────────────────────────────────────────────────┐
│ 1. CUARTEL DE INFANTERÍA (Humana)                                      │
│  - Era 1: Puesto de Armas (Milicianos con lanza, Arqueros rústicos).   │
│  - Era 2: Cuartel Militar de Línea (Infantería de espada, Ballesteros, │
│           Curandero de Campaña).                                       │
│  - Era 3-4 (según doctrina activa):                                    │
│     * D: Academia Acorazada (Lanzallamas, zapadores, Médicos Trinchera)│
│     * C: Centro de Especialistas PEM (Guerra electrónica, ciber-tropa) │
│     * S: Refugio de Guerrilla (Cazadores de sigilo, Bio-Sanadores)     │
├────────────────────────────────────────────────────────────────────────┤
│ 2. FÁBRICA DE UNIDADES MÓVILES TERRESTRES (Tripuladas)                 │
│  - Era 2: Establos de Batalla (Caballería ligera y de choque).         │
│  - Era 3-4 (según doctrina activa):                                    │
│     * D: Fábrica de Blindados (Tanque Leviatán, Artillería pesada,     │
│          Ingeniero Mecánico, Camión Cisterna Blindado).                │
│     * S: Taller Bio-Solar (Proyector Solar Móvil / Heliostato Asedio)  │
│     * C: Carros de Mando Móviles con Blindaje Faraday                  │
├────────────────────────────────────────────────────────────────────────┤
│ 3. HANGAR DE UNIDADES VOLADORAS (Era 3+)                               │
│  - D: Hangar de Zepelines Acorazados y Bombarderos Diésel pesados.     │
│  - C: Nido de Drones Aéreos de Asalto (Enjambres autónomos).           │
│  - S: Plataforma de Planeadores y Alas Solares (Bombas de resina).     │
├────────────────────────────────────────────────────────────────────────┤
│ 4. COMPLEJO DE ROBÓTICA TERRESTRE NO TRIPULADA (Era 3+)                │
│  - Exclusivo para máquinas autónomas terrestres (0 humanos).           │
│  - Produce: Mechas Bípedos Tácticos, Drones Nanorreparadores.          │
│  - Consumen energía de la red (`Energia.gd`), no comida ni camas.      │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Catálogo de Tropas y Unidades de Soporte (`Ajustes.gd`)

```gdscript
# ==============================================================================
# COMBATE, FORMACIONES Y UNIDADES MILITARES
# ==============================================================================
static var MILITAR_MAX_UNIDADES_ESCUADRON: int = 20
static var MILITAR_MAX_ESCUADRON_ELITE_AVATAR: int = 5
static var MILITAR_CONSUMO_BASE_INTERIOR: float = 3.0
static var MILITAR_CONSUMO_CAMPANA_EXTERIOR: float = 5.0
static var MILITAR_AURA_LIDERAZGO_RADIO: float = 15.0
static var MILITAR_AURA_BONO_RESISTENCIA_PANICO: float = 0.20
static var MILITAR_AURA_BONO_CADENCIA: float = 0.10
static var MILITAR_VENTANA_REANIMACION_S: float = 10.0 # Segundos antes de muerte definitiva

static var MILITAR_CATALOGO_UNIDADES: Dictionary = {
	# --- ERA 1 & 2 (TRONCO COMÚN) ---
	"miliciano_lanza": {
		"nombre": "Miliciano con Lanza",
		"capa_formacion": "vanguardia",
		"edificio": "cuartel_infanteria",
		"era_minima": 1,
		"hp": 100.0, "blindaje": 0.0, "dano": 12.0, "tipo_dano": "balistico",
		"rango": 2.0, "cadencia_s": 1.2, "velocidad": 2.5,
		"coste_humano": "obrero", "coste_materiales": {"madera": 20.0},
		"consumo_combustible": 0.0, "consumo_energia": 0.0, "es_maquina": false,
	},
	"arquero_rustico": {
		"nombre": "Arquero Rústico",
		"capa_formacion": "linea_media",
		"edificio": "cuartel_infanteria",
		"era_minima": 1,
		"hp": 70.0, "blindaje": 0.0, "dano": 15.0, "tipo_dano": "balistico",
		"rango": 25.0, "cadencia_s": 2.0, "velocidad": 2.5,
		"coste_humano": "obrero", "coste_materiales": {"madera": 30.0},
		"consumo_combustible": 0.0, "consumo_energia": 0.0, "es_maquina": false,
	},
	"infanteria_linea": {
		"nombre": "Infantería de Línea",
		"capa_formacion": "vanguardia",
		"edificio": "cuartel_infanteria",
		"era_minima": 2,
		"hp": 180.0, "blindaje": 5.0, "dano": 22.0, "tipo_dano": "balistico",
		"rango": 2.0, "cadencia_s": 1.0, "velocidad": 2.4,
		"coste_humano": "obrero", "coste_materiales": {"hierro": 30.0, "madera": 10.0},
		"consumo_combustible": 0.0, "consumo_energia": 0.0, "es_maquina": false,
	},
	"jinete_caballeria": {
		"nombre": "Jinete de Caballería",
		"capa_formacion": "vanguardia",
		"edificio": "fabrica_moviles",
		"era_minima": 2,
		"hp": 250.0, "blindaje": 4.0, "dano": 28.0, "tipo_dano": "balistico",
		"rango": 3.0, "cadencia_s": 1.4, "velocidad": 5.0,
		"coste_humano": "obrero", "coste_materiales": {"hierro": 25.0, "tablas": 20.0, "caballo": 1},
		"consumo_combustible": 0.0, "consumo_energia": 0.0, "es_maquina": false,
	},
	"curandero_campana": {
		"nombre": "Curandero de Campaña",
		"capa_formacion": "retaguardia",
		"edificio": "cuartel_infanteria",
		"era_minima": 2,
		"hp": 80.0, "blindaje": 0.0, "dano": 0.0, "tipo_dano": "",
		"rango": 6.0, "cadencia_s": 1.0, "velocidad": 2.5,
		"curacion_s": 15.0, # Cura infantería orgánica y reanima heridos
		"coste_humano": "obrero", "coste_materiales": {"madera": 20.0, "hierro": 10.0},
		"consumo_combustible": 0.0, "consumo_energia": 0.0, "es_maquina": false,
	},

	# --- DIESELPUNK (OFENSIVA PESADA / ASEDIO) ---
	"infanteria_lanzallamas": {
		"nombre": "Infantería Lanzallamas",
		"doctrina": "dieselpunk", "capa_formacion": "vanguardia",
		"edificio": "cuartel_infanteria", "era_minima": 3,
		"hp": 220.0, "blindaje": 8.0, "dano": 35.0, "tipo_dano": "termico",
		"rango": 8.0, "cadencia_s": 0.5, "velocidad": 2.0,
		"coste_humano": "obrero", "coste_materiales": {"acero": 40.0, "combustible": 30.0},
		"consumo_combustible": 1.0, "consumo_energia": 0.0, "es_maquina": false,
	},
	"tanque_leviatan": {
		"nombre": "Tanque Diésel Leviatán",
		"doctrina": "dieselpunk", "capa_formacion": "vanguardia",
		"edificio": "fabrica_moviles", "era_minima": 3,
		"hp": 1500.0, "blindaje": 25.0, "dano": 120.0, "tipo_dano": "balistico",
		"rango": 30.0, "cadencia_s": 3.5, "velocidad": 3.8,
		"coste_humano": "obrero", "coste_materiales": {"acero": 150.0, "combustible": 80.0},
		"consumo_combustible": 3.0, "consumo_energia": 0.0, "es_maquina": false,
	},
	"artilleria_autopropulsada": {
		"nombre": "Artillería Pesada",
		"doctrina": "dieselpunk", "capa_formacion": "retaguardia",
		"edificio": "fabrica_moviles", "era_minima": 4,
		"hp": 600.0, "blindaje": 10.0, "dano": 300.0, "tipo_dano": "balistico",
		"rango": 80.0, "cadencia_s": 6.0, "velocidad": 2.5,
		"coste_humano": "obrero", "coste_materiales": {"acero": 200.0, "combustible": 100.0},
		"consumo_combustible": 2.0, "consumo_energia": 0.0, "es_maquina": false,
	},
	"ingeniero_mecanico": {
		"nombre": "Ingeniero Mecánico de Campaña",
		"doctrina": "dieselpunk", "capa_formacion": "retaguardia",
		"edificio": "fabrica_moviles", "era_minima": 3,
		"hp": 120.0, "blindaje": 4.0, "dano": 0.0, "tipo_dano": "",
		"rango": 5.0, "cadencia_s": 1.0, "velocidad": 2.5,
		"reparacion_s": 40.0, # Repara tanques Leviatán, artillería y búnkeres
		"coste_humano": "obrero", "coste_materiales": {"acero": 50.0, "hierro": 30.0},
		"consumo_combustible": 0.5, "consumo_energia": 0.0, "es_maquina": false,
	},

	# --- CYBERPUNK (AUTÓMATAS / PRECISIÓN) ---
	"especialista_pem": {
		"nombre": "Especialista Guerra Electrónica",
		"doctrina": "cyberpunk", "capa_formacion": "linea_media",
		"edificio": "cuartel_infanteria", "era_minima": 3,
		"hp": 120.0, "blindaje": 3.0, "dano": 10.0, "tipo_dano": "pem",
		"rango": 20.0, "cadencia_s": 4.0, "velocidad": 2.5,
		"coste_humano": "especialista", "coste_materiales": {"cobre": 40.0, "tierras_raras": 20.0},
		"consumo_combustible": 0.0, "consumo_energia": 1.0, "es_maquina": false,
	},
	"dron_asalto": {
		"nombre": "Dron Aéreo de Asalto",
		"doctrina": "cyberpunk", "capa_formacion": "linea_media",
		"edificio": "hangar_voladoras", "era_minima": 3,
		"hp": 150.0, "blindaje": 2.0, "dano": 25.0, "tipo_dano": "termico",
		"rango": 22.0, "cadencia_s": 0.8, "velocidad": 7.0,
		"coste_humano": "", "coste_materiales": {"cobre": 35.0, "tierras_raras": 15.0, "acero": 20.0},
		"consumo_combustible": 0.0, "consumo_energia": 3.0, "es_maquina": true,
	},
	"mecha_bipedo": {
		"nombre": "Mecha Bípedo de Riel",
		"doctrina": "cyberpunk", "capa_formacion": "linea_media",
		"edificio": "complejo_robotica", "era_minima": 4,
		"hp": 900.0, "blindaje": 15.0, "dano": 140.0, "tipo_dano": "balistico",
		"rango": 45.0, "cadencia_s": 2.5, "velocidad": 4.2,
		"coste_humano": "", "coste_materiales": {"acero": 120.0, "tierras_raras": 40.0, "cobre": 60.0},
		"consumo_combustible": 0.0, "consumo_energia": 6.0, "es_maquina": true,
	},
	"dron_nanoreparador": {
		"nombre": "Dron de Nanorreparación",
		"doctrina": "cyberpunk", "capa_formacion": "retaguardia",
		"edificio": "complejo_robotica", "era_minima": 3,
		"hp": 100.0, "blindaje": 1.0, "dano": 0.0, "tipo_dano": "",
		"rango": 8.0, "cadencia_s": 1.0, "velocidad": 6.0,
		"reparacion_s": 50.0, # Repara mechas, drones y torretas láser
		"coste_humano": "", "coste_materiales": {"cobre": 30.0, "tierras_raras": 20.0},
		"consumo_combustible": 0.0, "consumo_energia": 2.5, "es_maquina": true,
	},

	# --- SOLARPUNK (GUERRILLA / BIO-FORTALEZA / ASEDIO TÉRMICO) ---
	"guerrillero_sigilo": {
		"nombre": "Cazador de Sigilo Bio-Vía",
		"doctrina": "solarpunk", "capa_formacion": "linea_media",
		"edificio": "cuartel_infanteria", "era_minima": 3,
		"hp": 110.0, "blindaje": 2.0, "dano": 32.0, "tipo_dano": "biologico",
		"rango": 28.0, "cadencia_s": 1.5, "velocidad": 3.8,
		"coste_humano": "obrero", "coste_materiales": {"madera": 40.0, "vidrio": 10.0},
		"consumo_combustible": 0.0, "consumo_energia": 0.0, "es_maquina": false,
		"sigilo": true,
	},
	"proyector_solar_movil": {
		"nombre": "Proyector Solar de Asedio",
		"doctrina": "solarpunk", "capa_formacion": "retaguardia",
		"edificio": "fabrica_moviles", "era_minima": 3,
		"hp": 550.0, "blindaje": 6.0, "dano": 75.0, "tipo_dano": "termico",
		"rango": 35.0, "cadencia_s": 1.0, "velocidad": 3.2,
		"coste_humano": "obrero", "coste_materiales": {"tablas": 60.0, "vidrio": 40.0, "cobre": 20.0},
		"consumo_combustible": 0.0, "consumo_energia": 0.0, "es_maquina": false,
		"requiere_luz_solar": true,
	},
	"bio_sanador": {
		"nombre": "Bio-Sanador de Esporas",
		"doctrina": "solarpunk", "capa_formacion": "retaguardia",
		"edificio": "cuartel_infanteria", "era_minima": 3,
		"hp": 90.0, "blindaje": 1.0, "dano": 0.0, "tipo_dano": "",
		"rango": 8.0, "cadencia_s": 1.0, "velocidad": 3.2,
		"curacion_s": 25.0, # Aura regenerativa en área
		"coste_humano": "obrero", "coste_materiales": {"madera": 30.0, "vidrio": 20.0},
		"consumo_combustible": 0.0, "consumo_energia": 0.0, "es_maquina": false,
	},
	"planeador_solar": {
		"nombre": "Planeador Solar Bio-Bomba",
		"doctrina": "solarpunk", "capa_formacion": "linea_media",
		"edificio": "hangar_voladoras", "era_minima": 4,
		"hp": 180.0, "blindaje": 1.0, "dano": 60.0, "tipo_dano": "biologico",
		"rango": 15.0, "cadencia_s": 3.0, "velocidad": 6.5,
		"coste_humano": "obrero", "coste_materiales": {"tablas": 40.0, "vidrio": 25.0},
		"consumo_combustible": 0.0, "consumo_energia": 0.0, "es_maquina": false,
	},
}
```

---

## 4. Dinámicas de Manejo de Tropas en Vista Cenital

### 4.1 Escuadrones Mixtos (hasta 20 unidades)
- El jugador selecciona unidades arrastrando un recuadro en vista cenital y presiona `Ctrl + 1..9` para consolidar un escuadrón.
- **Formación Automática por Capas (`BuscadorRutas.gd`):**
  - **Fila 1 (Vanguardia):** Se colocan al frente para absorber el primer impacto.
  - **Fila 2 (Línea Media):** Se alinean a 2–3 celdas detrás de la vanguardia para disparar por encima/flancos.
  - **Fila 3 (Retaguardia Protegida):** Se mantienen a 4–6 celdas detrás.
- **Velocidad del Escuadrón:**
  $$v_{\text{escuadron}} = \min(v_i) \times 1.05 \quad (\text{con límite mínimo de } 2.0\text{ m/s})$$
  *(El escuadrón mantiene la cohesión marchando al paso del integrante más lento).*

### 4.2 Las Cuatro Posturas Tácticas
En la barra de interfaz inferior en cámara cenital:
1. **🛡️ Guarnición / Mantener Posición:**
   - Desplazamiento = 0. No persiguen bajo ninguna circunstancia.
   - Atacan a cualquier enemigo que entre en su rango. Ideal para apostar arqueros en murallas y tanques en bocacalles.
2. **⚔️ Avance de Asalto:**
   - El escuadrón avanza hacia el punto marcado; si detecta enemigos a menos de 20 celdas, interrumpe la marcha y entabla combate hasta destruirlos, reanudando el avance después.
3. **🏹 Hostigamiento (Hit & Run):**
   - El escuadrón mantiene la distancia de su rango máximo. Si un enemigo avanza y acorta la distancia a menos del $60\%$ del rango, las unidades retroceden disparando.
4. **🔄 Patrullaje Estricto con Disciplina de Ruta:**
   - El jugador marca waypoints continuos ($A \to B \to C \to A$).
   - Las unidades hacen rondas en bucle. Si divisan enemigos, disparan fuego de oportunidad **sin desviarse más de 1 celda de la línea de patrulla**.
   - **Propósito clave:** Evita que unidades enemigas rápidas atraigan y alejen a la guardia para dejar indefensos oleoductos o acueductos.

---

## 5. Logística de Campaña, FOB («Extensión de Comando») y Ciclo Día/Noche

### 5.1 Base de Operaciones Avanzada (FOB / Extensión de Comando)
- **Tipo de Edificio:** Militar / Periferia.
- **Coste:** 80 Piedra/Hormigón + 40 Hierro + 20 Tablas.
- **Propagación Vial Activa:**
  - Evalúa continuamente la conectividad hacia el Núcleo Urbano mediante `_calcular_vias_conectadas`.
  - **Si la vía está íntegra:**
    - Proyecta un radio de influencia secundaria de **20 bloques**.
    - Permite emplazar torretas, murallas y puestos de auxilio en el frente.
    - Reduce el consumo de tropas acantonadas de $5.0$ a **$3.0\text{ u/h}$**.
  - **Si la vía se destruye/corta:**
    - La FOB entra en estado `AISLADA`.
    - La zona de influencia secundaria se desvanece; las torretas se apagan y las tropas pasan a consumir $5.0\text{ u/h}$.

### 5.2 Impacto del Ciclo Día/Noche (Solarpunk)
- **Fase Diurna:**
  - `proyector_solar_movil` y torres heliostatos operan al $100\%$ de potencia.
  - Eficiencia óptima para asedios térmicos y demolición de murallas.
- **Fase Nocturna:**
  - Proyectores solares se apagan o reducen su daño al $20\%$ (consumiendo reservas térmicas).
  - Las unidades en sigilo (`guerrillero_sigilo`) ganan **$+25\%$ de velocidad y evasión**.
  - Las murallas vivas duplican su tasa de regeneración ($+10\%$ HP/tick).

---

## 6. Puntos Ciegos Cenitales y Batalla Híbrida en 1ª Persona

### 6.1 Puntos Ciegos de la Vista Cenital
La cámara cenital queda inhabilitada para mostrar o fijar objetivos sobre:
1. **Túneles subterráneos y trincheras techadas:** El jugador en vista aérea solo ve el suelo superior; no puede ver tropas enemigas infiltrándose bajo tierra.
2. **Unidades con `"sigilo": true`:** Invisibles en vista cenital si están bajo follaje o dentro de bosques.
3. **Domo de Bruma y Esporas (Solarpunk):** Un domo opaco oculta todas las unidades y edificios dentro de su radio. La artillería que dispare hacia allí sufre una dispersión del $+80\%$.

### 6.2 Modo «Comandante de Campo» (1ª Persona)
Al alternar a primera persona con la tecla `C`:
1. **Aura de Liderazgo Físico:**
   - Radio de $15.0\text{ m}$ alrededor del Avatar.
   - Otorga $+10\%$ cadencia y $+20\%$ resistencia al pánico a todas las tropas aliadas cercanas.
2. **Escuadrón de Élite Personal (hasta 5 guardaespaldas directos):**
   - El jugador asigna hasta 5 unidades seleccionadas a su guardia personal.
   - **Comando Grupal (con la mira / `CaraApuntada.gd`):**
     - Clic derecho o tecla contextual sin seleccionar número: emite órdenes colectivas («¡Conmigo!», «¡Fuego concentrado al objetivo!», «¡Apostarse aquí!»).
   - **Comando Quirúrgico por Unidad (`Teclas 1 a 5` + Apuntar):**
     - Seleccionar la tecla de una unidad específica (ej. `Tecla 3: Especialista PEM`), apuntar con la mira a un mecha enemigo y ordenar: **solo esa unidad ejecuta la orden sobre ese objetivo puntual**.
     - Seleccionar al `Médico` y apuntar a un tanque averiado: el médico acude a repararlo inmediatamente.
3. **Intervención Manual:**
   - El Avatar puede disparar sus propias armas personales según su Era (arco, mosquete, rifle de asalto o lanzador de savia).
   - Puede interactuar con piezas de artillería, torretas o búnkeres para apuntar y disparar manualmente con mayor precisión.

---

## 7. Criterios de Aceptación y Pruebas Unitarias

1. **Prueba de Formación por Capas:** Crear un escuadrón con 2 tanques, 3 arqueros y 1 médico; ordenar avance y verificar que los tanques marchen al frente, los arqueros en el centro y el médico en la retaguardia.
2. **Prueba de Disciplina de Patrulla:** Asignar una ruta de 3 waypoints a un escuadrón con postura `PATRULLAJE_ESTRICTO`; hacer que un enemigo hostil dispare a 15 celdas y verificar que el escuadrón dispare sin salir de su traza vial.
3. **Prueba de Reanimación Médica:** Dañar a un soldado de infantería a 0 HP; comprobar que entre en estado `HERIDO` durante 10 segundos y que la llegada de un médico evite que sume a `bajas_7d`.
4. **Prueba de Conectividad FOB:** Construir una Base de Operaciones Avanzada fuera de la zona de influencia; comprobar que el consumo sea 3.0 u/h mientras la vía esté intacta, y que suba a 5.0 u/h al demoler un tramo intermedio de la carretera.
5. **Prueba de Puntos Ciegos:** Ubicar un escuadrón en un túnel subterráneo; verificar que la cámara cenital no dibuje las siluetas ni permita seleccionarlas desde el aire, requiriendo descender a 1ª persona.
6. **Prueba de Comando Quirúrgico 1ª Persona:** Asignar un especialista PEM al slot 2 del Escuadrón de Élite; presionar `2`, apuntar a un vehículo y verificar que únicamente el especialista PEM ejecute el ataque.
