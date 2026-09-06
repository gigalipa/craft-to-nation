# **Documento Técnico de Desarrollo: PoC 1 - Motor Lógico de Recursos, Demografía y Nivel Urbano**

**Identificador del Módulo:** POC-01-CORE-LOGIC

**Lenguaje:** Python 3.10+ (Entorno estándar sin librerías externas)

**Dependencias de Diseño:** Secciones 6, 7 y 9 del GDD v3.0 (Demografía, Alimentación, Nivel Urbano e Investigación, Sucesión de Avatar).

## **Metodología: Cada PoC como Proyecto Independiente**

A partir de este documento, cada PoC se gestiona como un mini-proyecto autocontenido con tres fases secuenciales, replicables para PoC 2 en adelante:

> * **Fase de Ideación:** Qué problema resuelve la PoC y qué secciones del GDD cubre.
> * **Fase de Planeación:** Modelado matemático/lógico y arquitectura de clases antes de escribir código de producción.
> * **Fase de Desarrollo:** Implementación, pruebas de integración y criterios de aceptación verificables.

---

## **FASE 1: IDEACIÓN**

### **1.1 Alcance y Objetivos de la PoC**

El propósito de esta prueba de concepto es aislar la matemática transaccional del juego de cualquier motor gráfico o sistema de físicas:

* **Simulación de Ciclos Horarios (Ticks):** Procesar el paso del tiempo mediante unidades discretas de ejecución.
* **Balance Metabólico de Alimentos:** Deducir reservas de comida considerando los 7 roles demográficos y el estado de actividad del avatar.
* **Cálculo Dinámico de Nivel Urbano:** Evaluar la proporción de instalaciones industriales operativas para determinar el estatus tecnológico potencial (Nivel 1 al 3).
* **Investigación de Nivel:** Modelar el costo de activación (Sección 7 del GDD) que desbloquea el nivel potencial calculado por ratio de instalaciones.
* **Variedad de Fuentes Alimentarias:** Modelar el bono de moral por diversidad de fuentes de comida *activas*, con decaimiento gradual (Sección 6 del GDD).
* **Sucesión del Avatar:** Modelar la elegibilidad militar y el "período de elecciones" al morir el avatar (Sección 9 del GDD).
* **Gestión de Excepciones Económicas:** Resolver eventos de hambruna (reserva de comida a cero) y desahucio poblacional derivado de la pérdida de infraestructura vertical.

### **1.2 Fuera de Alcance**

Blueprints, zonificación espacial, pathfinding, render y multijugador quedan fuera de esta PoC — se cubren en PoC 2 en adelante (ver Sección 11 del GDD).

---

## **FASE 2: PLANEACIÓN**

### **2.1 Tasas de Consumo Calórico**

Cada tick simula una hora dentro del juego. El gasto energético colectivo se calcula mediante la suma ponderada del censo y el esfuerzo del jugador:

**Gasto Total = Consumo_Avatar + Suma(Población_rol \* Tasa_rol)**

| Entidad / Rol | Consumo Base | Justificación Operativa |
| :---- | :---- | :---- |
| **Jóvenes** | 2 / tick | Población inactiva en formación. |
| **Trabajadores Tipo 1** | 5 / tick | Fuerza bruta y recolección manual de superficie. |
| **Trabajadores Tipo 2** | 4 / tick | Operarios en manufactura primaria. |
| **Trabajadores Tipo 3** | 3 / tick | Técnicos en industrias automatizadas. |
| **Investigadores** | 2 / tick | Trabajo intelectual en laboratorios. |
| **Militares** | 4 / tick | Infantería activa y defensa perimetral. |
| **Ancianos** | 2 / tick | Sector retirado. |
| **Avatar (Jugador)** | 5 / tick a 3 / tick | Varía dinámicamente según el nivel tecnológico *efectivo* de la urbe. |

### **2.2 Algoritmo del Índice de Sofisticación y Nivel Potencial**

El nivel **potencial** de la urbe no se basa en experiencia fija, sino en el ratio ponderado de sus fábricas activas del Núcleo B:

**Índice = \[(N_tipo_1 \* 1) + (N_tipo_2 \* 2) + (N_tipo_3 \* 3)\] / Total de Instalaciones**

* **Nivel 1:** Índice < 1.7 o sin industrias especializadas. Límite de pisos habitables: **Suelo + 1**.
* **Nivel 2:** 1.7 ≤ Índice < 2.5 y mínimo 3 instalaciones Tipo 2. Límite de pisos: **Suelo + 3**.
* **Nivel 3:** Índice ≥ 2.5 y mínimo 3 instalaciones Tipo 3. Límite de pisos: **Suelo + 5**.

Este es el **nivel potencial** (`nivel_potencial`): lo que el ratio de instalaciones *permite*. El **nivel efectivo** (`nivel`, usado para el gasto del avatar y la capacidad habitacional) queda limitado por la investigación de activación (2.3):

**nivel_efectivo = min(nivel_potencial, nivel_investigado)**

### **2.3 Investigación de Nivel: Costo de Activación**

Modela la Sección 7 del GDD ("Investigación de Nivel: Requisito de Activación"). Cada salto de nivel requiere consumir recursos una vez y acumular horas-investigador hasta un umbral:

| Investigación | Desbloquea Nivel | Costo de Recursos | Horas-Investigador Requeridas |
| :---- | :---- | :---- | :---- |
| **Metalurgia Aplicada** | 2 | 300 hierro + 200 madera | 20 |
| **Automatización Industrial** | 3 | 800 hierro + 100 madera | 50 |

Las horas-investigador se acumulan a razón de `demografia["investigador"]` por tick (más investigadores asignados = investigación más rápida). El costo de recursos se descuenta una sola vez, al completarse el umbral de horas, y solo si el nivel potencial (2.2) ya permite ese nivel.

### **2.4 Variedad de Fuentes Alimentarias y Bono de Moral**

Modela la Sección 6 del GDD. Existen 6 categorías de fuente de comida; el bono de moral depende de cuántas están **activas** (con producción \> 0/tick) en el tick actual, no de cuántas existen construidas:

**Bono Objetivo = (Categorías Activas / Total Categorías) \* Bono Máximo**

El bono real (`bono_moral_variedad`) no salta directamente al objetivo: se desplaza gradualmente hacia él cada tick (suavizado), para que desactivar una categoría cueste moral progresivamente y no de golpe.

### **2.5 Sucesión del Avatar**

Modela la Sección 9 del GDD:

* Si `censo_total == 0` al morir el avatar → Game Over (sin sucesor posible).
* Si hay al menos un ciudadano con rol `militar` → ese ciudadano sucede al avatar (censo militar -1), se activa un "período de elecciones" (penalización temporal, modelada aquí como N ticks de gasto de comida incrementado en un 10% por interrupción de liderazgo).
* Si hay ciudadanos pero ninguno es militar → no hay sucesor elegible; la partida queda bloqueada hasta formar al menos un militar (regla de diseño abierta a validar en PoC 5, cuando exista combate real).

### **2.6 Arquitectura de Clases**

* **`Recurso`**: sin cambios respecto a la versión anterior (almacén con límite superior).
* **`Ciudad`**: se le añade `nivel_investigado`, `progreso_investigacion`, `fuentes_comida_activas`, `bono_moral_variedad` y `periodo_elecciones_restante`; gana los métodos `actualizar_investigacion()`, `actualizar_bono_variedad()` y `suceder_avatar()`.
* **`Avatar`**: sin cambios estructurales; `tasa_hambre` ahora lee `ciudad.nivel` (el nivel efectivo, no el potencial).

---

## **FASE 3: DESARROLLO**

### **3.1 Implementación**

```python
"""
PoC 1: Simulador de Núcleo Lógico de Recursos, Demografía e Investigación
Craft to Nation
"""

class Recurso:
    def __init__(self, nombre: str, cantidad: float, limite: float):
        self.nombre = nombre
        self.cantidad = max(0.0, float(cantidad))
        self.limite = float(limite)

    def agregar(self, monto: float) -> float:
        espacio_libre = self.limite - self.cantidad
        ingreso_real = min(espacio_libre, monto)
        self.cantidad += ingreso_real
        return ingreso_real

    def consumir(self, monto: float) -> bool:
        if self.cantidad >= monto:
            self.cantidad -= monto
            return True
        return False


class Ciudad:
    CONSUMO_POR_ROL = {
        "jovenes": 2,
        "trabajador_tipo_1": 5,
        "trabajador_tipo_2": 4,
        "trabajador_tipo_3": 3,
        "investigador": 2,
        "militar": 4,
        "ancianos": 2,
    }

    # Habitabilidad base por piso disponible según nivel EFECTIVO de ciudad
    CAMAS_POR_PISO_PERMITIDO = {
        1: 4,   # Nivel 1: Suelo + 1 piso = 2 niveles (4 camas)
        2: 8,   # Nivel 2: Suelo + 3 pisos = 4 niveles (8 camas)
        3: 12,  # Nivel 3: Suelo + 5 pisos = 6 niveles (12 camas)
    }

    # Costo de activación por nivel (Sección 7 del GDD)
    COSTOS_INVESTIGACION = {
        2: {"nombre": "Metalurgia Aplicada", "hierro": 300, "madera": 200, "horas_investigador": 20},
        3: {"nombre": "Automatización Industrial", "hierro": 800, "madera": 100, "horas_investigador": 50},
    }

    CATEGORIAS_COMIDA = [
        "sembradios", "granjas_animales", "recoleccion_caza",
        "hidroponia", "pesca", "sintetico",
    ]
    BONO_MORAL_MAXIMO = 15.0  # puntos de moral con las 6 categorías activas
    VELOCIDAD_SUAVIZADO_MORAL = 0.15  # fracción del faltante que se cierra por tick

    def __init__(self):
        # Núcleo B: Estructuras industriales activas
        self.instalaciones = {"tipo_1": 0, "tipo_2": 0, "tipo_3": 0}

        # Núcleo A: Censo poblacional
        self.demografia = {rol: 0 for rol in self.CONSUMO_POR_ROL}

        # Almacenes
        self.almacen = {
            "madera": Recurso("Madera", 200, 1000),
            "comida": Recurso("Comida", 150, 2000),
            "hierro": Recurso("Hierro", 50, 1000),
        }

        self.desahuciados = 0

        # Investigación de nivel
        self.nivel_investigado = 1
        self.progreso_investigacion = {2: 0.0, 3: 0.0}

        # Variedad alimentaria
        self.fuentes_comida_activas = {cat: 0.0 for cat in self.CATEGORIAS_COMIDA}
        self.bono_moral_variedad = 0.0

        # Sucesión del avatar
        self.periodo_elecciones_restante = 0

    @property
    def total_instalaciones(self) -> int:
        return sum(self.instalaciones.values())

    @property
    def censo_total(self) -> int:
        return sum(self.demografia.values())

    @property
    def indice_sofisticacion(self) -> float:
        total = self.total_instalaciones
        if total == 0:
            return 1.0
        puntos = (
            self.instalaciones["tipo_1"] * 1
            + self.instalaciones["tipo_2"] * 2
            + self.instalaciones["tipo_3"] * 3
        )
        return puntos / total

    @property
    def nivel_potencial(self) -> int:
        """Nivel que el ratio de instalaciones PERMITE, antes de investigación."""
        idx = self.indice_sofisticacion
        if idx >= 2.5 and self.instalaciones["tipo_3"] >= 3:
            return 3
        elif idx >= 1.7 and self.instalaciones["tipo_2"] >= 3:
            return 2
        return 1

    @property
    def nivel(self) -> int:
        """Nivel EFECTIVO: el potencial, acotado por lo ya investigado."""
        return min(self.nivel_potencial, self.nivel_investigado)

    @property
    def capacidad_habitacional(self) -> int:
        return self.CAMAS_POR_PISO_PERMITIDO.get(self.nivel, 4)

    def actualizar_investigacion(self):
        """Acumula horas-investigador y activa el siguiente nivel al completar el umbral."""
        siguiente = self.nivel_investigado + 1
        costo = self.COSTOS_INVESTIGACION.get(siguiente)
        if costo is None:
            return
        if self.nivel_potencial < siguiente:
            return  # el ratio de instalaciones aún no habilita esta investigación
        if self.demografia["investigador"] <= 0:
            return

        self.progreso_investigacion[siguiente] += self.demografia["investigador"]
        if self.progreso_investigacion[siguiente] >= costo["horas_investigador"]:
            hierro_ok = self.almacen["hierro"].consumir(costo["hierro"])
            madera_ok = self.almacen["madera"].consumir(costo["madera"])
            if hierro_ok and madera_ok:
                self.nivel_investigado = siguiente

    def actualizar_bono_variedad(self):
        """Desplaza el bono de moral gradualmente hacia el objetivo de diversidad activa."""
        activas = sum(1 for v in self.fuentes_comida_activas.values() if v > 0)
        objetivo = (activas / len(self.CATEGORIAS_COMIDA)) * self.BONO_MORAL_MAXIMO
        diferencia = objetivo - self.bono_moral_variedad
        self.bono_moral_variedad += diferencia * self.VELOCIDAD_SUAVIZADO_MORAL

    def regular_densidad_vertical(self):
        """Verifica si la población excede el límite permitido por el nivel EFECTIVO de la ciudad."""
        limite = self.capacidad_habitacional
        if self.censo_total > limite:
            exceso = self.censo_total - limite
            self.desahuciados += exceso

            # Expulsar prioritariamente trabajadores no especializados
            orden_recorte = ["trabajador_tipo_1", "jovenes", "trabajador_tipo_2", "ancianos"]
            for rol in orden_recorte:
                if exceso <= 0:
                    break
                disponibles = self.demografia[rol]
                a_remover = min(disponibles, exceso)
                self.demografia[rol] -= a_remover
                exceso -= a_remover

    def suceder_avatar(self) -> str:
        """Aplica la sucesión del avatar tras su muerte (Sección 9 del GDD)."""
        if self.censo_total == 0:
            return "game_over"
        if self.demografia["militar"] <= 0:
            return "sin_sucesor_elegible"

        self.demografia["militar"] -= 1
        self.periodo_elecciones_restante = 5  # ticks de penalización de liderazgo
        return "sucesion_exitosa"

    def simular_tick(self, avatar_consumo: float) -> dict:
        """Ejecuta un ciclo horario verificando alimentación, habitabilidad e investigación."""
        # 1. Ajustar densidad por posible pérdida de nivel
        self.regular_densidad_vertical()

        # 2. Avanzar investigación y bono de variedad alimentaria
        self.actualizar_investigacion()
        self.actualizar_bono_variedad()

        # 3. Computar demanda calórica
        gasto_poblacion = sum(
            cant * self.CONSUMO_POR_ROL[rol]
            for rol, cant in self.demografia.items()
        )
        gasto_total = gasto_poblacion + avatar_consumo

        # 4. Penalización por período de elecciones (interrupción de liderazgo)
        if self.periodo_elecciones_restante > 0:
            gasto_total *= 1.10
            self.periodo_elecciones_restante -= 1

        # 5. Transacción sobre el almacén
        exito_comida = self.almacen["comida"].consumir(gasto_total)

        # 6. Manejo de Hambruna si el stock es insuficiente
        bajas_inanicion = 0
        if not exito_comida:
            bajas_inanicion = max(1, int(self.censo_total * 0.25))
            self.almacen["comida"].cantidad = 0.0
            for rol in ["militar", "trabajador_tipo_1", "trabajador_tipo_2"]:
                if self.demografia[rol] > 0 and bajas_inanicion > 0:
                    quitar = min(self.demografia[rol], bajas_inanicion)
                    self.demografia[rol] -= quitar
                    bajas_inanicion -= quitar

        return {
            "gasto_comida": gasto_total,
            "hambruna": not exito_comida,
            "bajas": bajas_inanicion,
            "nivel_ciudad": self.nivel,
            "nivel_potencial": self.nivel_potencial,
            "bono_moral_variedad": round(self.bono_moral_variedad, 2),
        }


class Avatar:
    def __init__(self, ciudad_vinculada: Ciudad):
        self.ciudad = ciudad_vinculada
        self.salud = 100.0

    @property
    def tasa_hambre(self) -> float:
        # El consumo se reduce a medida que la urbe se tecnifica (nivel EFECTIVO, no potencial)
        tabla_hambre = {1: 5.0, 2: 4.0, 3: 3.0}
        return tabla_hambre.get(self.ciudad.nivel, 5.0)

    def aplicar_estado(self, hambruna_activa: bool):
        if hambruna_activa:
            self.salud = max(0.0, self.salud - 15.0)
        else:
            self.salud = min(100.0, self.salud + 2.0)
```

### **3.2 Bucle de Integración y Pruebas Unitarias**

Para validar la lógica sin interfaz, se debe utilizar el siguiente ejecutable de pruebas que reproduce los seis escenarios críticos de diseño:

```python
def ejecutar_pruebas():
    urbe = Ciudad()
    jugador = Avatar(urbe)

    print("=== TEST 1: Estado Inicial (Supervivencia Nivel 1) ===")
    urbe.instalaciones["tipo_1"] = 2
    urbe.demografia["trabajador_tipo_1"] = 2
    urbe.demografia["jovenes"] = 1
    print(f"Nivel Potencial: {urbe.nivel_potencial} | Nivel Efectivo: {urbe.nivel}")
    print(f"Hambre del Avatar: {jugador.tasa_hambre}/tick")
    res = urbe.simular_tick(jugador.tasa_hambre)
    print(f"Gasto Comida: {res['gasto_comida']} | Stock Restante: {urbe.almacen['comida'].cantidad}\n")

    print("=== TEST 2: Ratio Permite Nivel 3, pero Investigación Bloquea el Nivel Efectivo ===")
    urbe.instalaciones["tipo_3"] = 7  # con tipo_1=2 y tipo_2=1 ya presentes, esto lleva el índice a 2.5
    urbe.instalaciones["tipo_2"] = 1
    urbe.demografia["investigador"] = 0  # sin investigadores asignados, la investigación no avanza
    res = urbe.simular_tick(jugador.tasa_hambre)
    print(f"Nivel Potencial: {res['nivel_potencial']} | Nivel Efectivo: {res['nivel_ciudad']} (debe seguir en 1 sin investigadores)")
    assert res["nivel_ciudad"] == 1, "El nivel efectivo no debe adelantarse a la investigación completada"

    print("\n=== TEST 3: Investigación Completa 'Metalurgia Aplicada' con Investigadores Asignados ===")
    urbe.demografia["investigador"] = 5
    urbe.almacen["hierro"].cantidad = 1000
    urbe.almacen["madera"].cantidad = 1000
    for _ in range(10):  # 5 investigadores * 10 ticks = 50 horas-investigador > umbral de Nivel 2 (20) y Nivel 3 (50)
        urbe.simular_tick(jugador.tasa_hambre)
    print(f"Nivel Investigado: {urbe.nivel_investigado} | Nivel Efectivo: {urbe.nivel}")
    assert urbe.nivel_investigado >= 2, "Con suficientes horas-investigador y recursos, el Nivel 2 debe activarse"

    print("\n=== TEST 4: Variedad de Fuentes Alimentarias y Bono de Moral Gradual ===")
    for cat in urbe.CATEGORIAS_COMIDA:
        urbe.fuentes_comida_activas[cat] = 10.0  # las 6 categorías activas
    for _ in range(30):  # suficientes ticks para converger cerca del bono máximo
        urbe.simular_tick(jugador.tasa_hambre)
    bono_con_variedad = urbe.bono_moral_variedad
    print(f"Bono de moral tras activar las 6 categorías (30 ticks): {bono_con_variedad:.2f}")
    urbe.fuentes_comida_activas["sintetico"] = 0.0  # se desactiva una categoría
    urbe.simular_tick(jugador.tasa_hambre)
    print(f"Bono inmediatamente tras desactivar una categoría: {urbe.bono_moral_variedad:.2f} (debe decaer gradualmente, no a 0)")
    assert 0 < urbe.bono_moral_variedad < bono_con_variedad

    print("\n=== TEST 5: Asedio Militar y Degradación por Destrucción ===")
    print(">> El enemigo destruye todas las plantas Tipo 3...")
    urbe.instalaciones["tipo_3"] = 0
    urbe.demografia["trabajador_tipo_1"] = 6
    res = urbe.simular_tick(jugador.tasa_hambre)
    print(f"Nivel Potencial Tras Ataque: {res['nivel_potencial']} | Nivel Efectivo: {res['nivel_ciudad']}")
    print(f"Ciudadanos Desahuciados: {urbe.desahuciados}")
    print(f"Censo Restante en Viviendas Legales: {urbe.censo_total}")

    print("\n=== TEST 6: Sucesión del Avatar ===")
    urbe.demografia["militar"] = 2
    resultado = urbe.suceder_avatar()
    print(f"Resultado de sucesión con militares disponibles: {resultado}")
    assert resultado == "sucesion_exitosa"
    assert urbe.periodo_elecciones_restante == 5

    urbe.demografia["militar"] = 0
    resultado_sin_sucesor = urbe.suceder_avatar()
    print(f"Resultado de sucesión sin militares disponibles: {resultado_sin_sucesor}")
    assert resultado_sin_sucesor == "sin_sucesor_elegible"


if __name__ == "__main__":
    ejecutar_pruebas()
```

### **3.3 Criterios de Aceptación Técnicos**

1. **Consistencia Invariable:** La función `simular_tick()` no debe arrojar stocks de comida negativos bajo ninguna condición.
2. **Transición Reactiva:** La propiedad `jugador.tasa_hambre` debe responder de inmediato a los cambios en `urbe.nivel` (nivel efectivo) sin requerir variables en caché desactualizadas.
3. **Control de Integridad Vertical:** Al pasar de Nivel 3 a Nivel 1, la variable `urbe.censo_total` no debe exceder las 4 unidades base; el remanente debe contabilizarse como desahuciados.
4. **Nivel Efectivo Nunca Adelanta al Potencial ni a la Investigación:** `urbe.nivel` debe ser siempre `min(nivel_potencial, nivel_investigado)`, nunca mayor a ninguno de los dos.
5. **Bono de Moral por Variedad es Gradual:** al desactivar una categoría de comida, `bono_moral_variedad` no debe caer a su valor final en un solo tick.
6. **Sucesión Respeta Elegibilidad Militar:** `suceder_avatar()` solo debe retornar `"sucesion_exitosa"` si `demografia["militar"] > 0` antes de la llamada; en caso contrario debe retornar `"sin_sucesor_elegible"` (o `"game_over"` si el censo total es 0) sin modificar el censo.

---

## **Próximos Pasos de esta PoC**

> 1. Ejecutar `ejecutar_pruebas()` y confirmar que los 6 asserts pasan sin error.
> 2. Ajustar los valores de `COSTOS_INVESTIGACION` y `BONO_MORAL_MAXIMO` tras una primera sesión de playtesting informal (son estimaciones iniciales, no balanceadas).
> 3. Definir en PoC 2 cómo las categorías de `fuentes_comida_activas` se alimentan desde edificios reales (por ahora se manipulan directamente en las pruebas).
