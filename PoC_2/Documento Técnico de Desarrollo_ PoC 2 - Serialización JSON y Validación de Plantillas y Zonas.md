# **Documento Técnico de Desarrollo: PoC 2 - Serialización JSON y Validación de Plantillas y Zonas**

**Identificador del Módulo:** POC-02-BLUEPRINT-VALIDATION

**Lenguaje:** Python 3.10+ (Entorno estándar sin librerías externas)

**Dependencias de Diseño:** Secciones 3 y 5 del GDD v3.0 (Zonificación Urbana, Mecánica de Plantillas y Construcción Asistida).

**Dependencia Técnica:** Ninguna sobre PoC 1 — esta PoC valida datos estructurales de un Blueprint de forma aislada; la integración con `Ciudad` (para descontar recursos al construir, por ejemplo) queda para una fase posterior de integración, no para esta PoC.

---

## **FASE 1: IDEACIÓN**

### **1.1 Alcance y Objetivos de la PoC**

El propósito de esta prueba de concepto es validar, sin motor gráfico ni mundo 3D real, que un Blueprint serializado en JSON cumple las reglas de construcción reglamentadas del GDD antes de permitir su emplazamiento:

* **Serialización:** Definir un esquema JSON capaz de representar un edificio multinivel (paredes, puertas, ventanas, camas, baúles, techo) y su metadato de zona permitida.
* **Validación de Cerramiento Hermético:** Detectar huecos en el perímetro de cada piso, incluyendo el caso de esquinas en edificios no rectangulares.
* **Validación de Aberturas Reglamentarias:** Confirmar la existencia de al menos una puerta y una ventana.
* **Validación de Volumen Vital y Almacenamiento:** Confirmar que cada cama tiene un baúl emparejado.
* **Validación de Zonificación:** Rechazar el emplazamiento de un Blueprint en una zona territorial distinta a su `zona_permitida`.
* **Validación de Evolución de Edificaciones:** Confirmar que la huella de una nueva versión no exceda la huella de la planta base de la versión anterior.
* **Validación de Personalización de Producción:** Confirmar que una plantilla de edificio prediseñado, al ser personalizada, no altera su huella ni su número de conexiones (entradas/salidas).

### **1.2 Fuera de Alcance**

Detección de habitaciones individuales para exigir ventana "por habitación" (se simplifica a mínimo global en esta PoC — ver nota de simplificación en 2.2), colocación física en el mundo 3D, integración con recursos/obreros de `Ciudad` (PoC 1), módulos de producción multi-edificio (grupos de edificios + vías), y persistencia de partida. Estas quedan para PoC 3 en adelante (ver Sección 11 del GDD).

---

## **FASE 2: PLANEACIÓN**

### **2.1 Esquema de Datos JSON de un Blueprint**

Un Blueprint se modela como una planta baja obligatoria más pisos superiores opcionales. Cada piso es una grilla 2D de celdas (`"x,y"` → tipo), donde el conjunto de claves de `celdas` define la huella (footprint) de ese piso:

```json
{
  "nombre": "Cabana_Colono_v1",
  "tipo": "residencial",
  "zona_permitida": "residencial_investigacion",
  "conexiones": [],
  "pisos": [
    {
      "nivel": 0,
      "celdas": {
        "0,0": "pared", "1,0": "puerta", "2,0": "pared",
        "0,1": "pared", "1,1": "piso",   "2,1": "pared",
        "0,2": "pared", "1,2": "ventana","2,2": "pared"
      },
      "camas": [
        {"pos": "1,1", "baul": true}
      ]
    }
  ]
}
```

Campos clave:

* **`tipo`**: categoría del edificio (`residencial`, `investigacion`, `produccion`, `militar`, `extraccion`, `almacen`). Determina si aplica la validación de personalización de producción (2.6).
* **`zona_permitida`**: uno de `"residencial_investigacion"`, `"fabricacion_militar"`, `"periferia"` (mismos identificadores de la Sección 3 del GDD).
* **`conexiones`**: solo relevante en plantillas de producción prediseñadas; lista de puntos de entrada/salida de bienes.
* **`celdas`**: tipo de cada celda ocupada del piso — `pared`, `puerta`, `ventana` o `piso` (interior transitable). Una celda ausente del diccionario está fuera de la huella (vacío/exterior).
* **`camas`**: cada entrada referencia una celda `piso` y declara si tiene `baul` emparejado.

### **2.2 Reglas de Validación Estructural**

> * **Cerramiento Hermético (sin huecos):** Para cada piso, se calculan las *celdas de borde* — celdas de la huella con al menos un vecino ortogonal (arriba/abajo/izquierda/derecha) fuera de la huella. Toda celda de borde debe ser `pared`, `puerta` o `ventana`; si es `piso`, es un hueco no reglamentario.
> * **Esquinas Sólidas:** Una celda de borde es *esquina* si tiene exactamente dos vecinos ortogonales perpendiculares ausentes (ej. falta el vecino de arriba y el de la derecha). Las esquinas deben ser específicamente `pared` (una puerta o ventana no puede hacer de esquina — replica la regla del GDD de que las esquinas deben unir dos paredes).
> * **Aberturas Reglamentarias:** El piso debe contener al menos una celda `puerta` y al menos una celda `ventana`. *(Simplificación de PoC: se valida a nivel de piso completo, no por habitación individual — requiere detección de habitaciones, fuera de alcance según 1.2).*
> * **Volumen Vital y Camas:** El Blueprint completo debe tener al menos una cama. *(El volumen libre de 3 bloques de altura y la casilla lateral accesible son responsabilidad del motor 3D en PoC 3, no de esta validación de datos).*
> * **Almacenamiento Individual:** Cada entrada de `camas` debe tener `"baul": true`. Una cama sin baúl invalida el Blueprint.
> * **Etiquetado de Zona:** `zona_permitida` es obligatorio y debe pertenecer al conjunto de zonas válidas.

### **2.3 Validación de Colocación por Zona**

Dado un Blueprint y una `zona_destino` (la zona territorial donde el jugador intenta construir), la colocación se rechaza si `blueprint.zona_permitida != zona_destino`.

### **2.4 Validación de Evolución de Edificaciones**

Al reemplazar un Blueprint por una nueva versión sobre la misma huella:

**Huella(piso N de la nueva versión) ⊆ Huella(piso 0 de la versión anterior), para todo N**

Ningún piso de la nueva versión —ni siquiera los superiores— puede ocupar celdas fuera de la huella de la planta base original.

### **2.5 Validación de Personalización de Producción**

Para Blueprints de `tipo: "produccion"`, comparar la versión personalizada contra la plantilla original:

* La huella del piso 0 debe ser idéntica (mismo conjunto de celdas).
* El número de `conexiones` debe ser idéntico (misma cantidad de entradas/salidas, sin importar su disposición exacta dentro de la huella).

### **2.6 Arquitectura de Clases**

* **`Piso`**: `nivel: int`, `celdas: dict[str, str]`, `camas: list[dict]`.
* **`Blueprint`**: `nombre: str`, `tipo: str`, `zona_permitida: str`, `conexiones: list`, `pisos: list[Piso]`.
* **`ResultadoValidacion`**: `valido: bool`, `errores: list[str]` — cada función de validación retorna una lista de errores (vacía si pasa), y un agregador las combina.
* Funciones puras de validación (sin estado compartido), cada una responsable de una sola regla — facilita probarlas de forma aislada y localizar qué regla falló.

---

## **FASE 3: DESARROLLO**

### **3.1 Implementación**

```python
"""
PoC 2: Serialización JSON y Validación de Plantillas y Zonas
Craft to Nation
"""

import json
from dataclasses import dataclass, field

ZONAS_VALIDAS = {"residencial_investigacion", "fabricacion_militar", "periferia"}
TIPOS_CELDA_SOLIDA = {"pared", "puerta", "ventana"}
VECINOS_ORTOGONALES = [(0, 1), (0, -1), (1, 0), (-1, 0)]


@dataclass
class Piso:
    nivel: int
    celdas: dict  # "x,y" -> "pared" | "puerta" | "ventana" | "piso"
    camas: list = field(default_factory=list)  # [{"pos": "x,y", "baul": bool}]

    def huella(self) -> set:
        return set(self.celdas.keys())


@dataclass
class Blueprint:
    nombre: str
    tipo: str
    zona_permitida: str
    pisos: list  # list[Piso]
    conexiones: list = field(default_factory=list)

    @staticmethod
    def desde_json(texto_json: str) -> "Blueprint":
        data = json.loads(texto_json)
        pisos = [
            Piso(nivel=p["nivel"], celdas=p["celdas"], camas=p.get("camas", []))
            for p in data["pisos"]
        ]
        return Blueprint(
            nombre=data["nombre"],
            tipo=data["tipo"],
            zona_permitida=data.get("zona_permitida", ""),
            pisos=pisos,
            conexiones=data.get("conexiones", []),
        )


@dataclass
class ResultadoValidacion:
    valido: bool
    errores: list


def _parsear_celda(clave: str) -> tuple:
    x, y = clave.split(",")
    return int(x), int(y)


def validar_cerramiento(piso: Piso) -> list:
    """Detecta huecos en el perímetro y exige paredes sólidas en las esquinas."""
    errores = []
    huella = piso.huella()
    celdas_ocupadas = {_parsear_celda(c): tipo for c, tipo in piso.celdas.items()}

    for (x, y), tipo in celdas_ocupadas.items():
        vecinos_ausentes = [
            (dx, dy) for dx, dy in VECINOS_ORTOGONALES
            if (x + dx, y + dy) not in {_parsear_celda(c) for c in huella}
        ]
        if not vecinos_ausentes:
            continue  # celda interior, no es borde

        if tipo not in TIPOS_CELDA_SOLIDA:
            errores.append(f"Piso {piso.nivel}: hueco en el perímetro en la celda ({x},{y}), tipo '{tipo}'")
            continue

        # Esquina: exactamente dos vecinos ausentes y perpendiculares entre sí
        if len(vecinos_ausentes) == 2:
            (dx1, dy1), (dx2, dy2) = vecinos_ausentes
            es_perpendicular = (dx1, dy1) != (-dx2, -dy2)
            if es_perpendicular and tipo != "pared":
                errores.append(
                    f"Piso {piso.nivel}: la esquina ({x},{y}) debe ser 'pared', no '{tipo}'"
                )

    return errores


def validar_aberturas(piso: Piso) -> list:
    """Exige al menos una puerta y una ventana por piso (simplificado a nivel global, ver 2.2)."""
    tipos_presentes = set(piso.celdas.values())
    errores = []
    if "puerta" not in tipos_presentes:
        errores.append(f"Piso {piso.nivel}: falta al menos una puerta")
    if "ventana" not in tipos_presentes:
        errores.append(f"Piso {piso.nivel}: falta al menos una ventana")
    return errores


def validar_camas_y_almacenamiento(blueprint: Blueprint) -> list:
    """Exige al menos una cama en todo el Blueprint, cada una con baúl emparejado."""
    errores = []
    total_camas = sum(len(piso.camas) for piso in blueprint.pisos)
    if total_camas == 0:
        errores.append("El Blueprint no tiene ninguna cama")
        return errores

    for piso in blueprint.pisos:
        for cama in piso.camas:
            if not cama.get("baul", False):
                errores.append(f"Piso {piso.nivel}: la cama en {cama['pos']} no tiene baúl emparejado")
    return errores


def validar_zona_permitida(blueprint: Blueprint) -> list:
    if blueprint.zona_permitida not in ZONAS_VALIDAS:
        return [f"zona_permitida inválida o ausente: '{blueprint.zona_permitida}'"]
    return []


def validar_colocacion(blueprint: Blueprint, zona_destino: str) -> list:
    if blueprint.zona_permitida != zona_destino:
        return [
            f"El Blueprint '{blueprint.nombre}' (zona: {blueprint.zona_permitida}) "
            f"no puede colocarse en la zona '{zona_destino}'"
        ]
    return []


def validar_evolucion(blueprint_nuevo: Blueprint, blueprint_anterior: Blueprint) -> list:
    huella_base_anterior = blueprint_anterior.pisos[0].huella()
    errores = []
    for piso in blueprint_nuevo.pisos:
        if not piso.huella().issubset(huella_base_anterior):
            errores.append(
                f"Piso {piso.nivel} de la nueva versión excede la huella de la planta base original"
            )
    return errores


def validar_personalizacion_produccion(blueprint_modificado: Blueprint, blueprint_original: Blueprint) -> list:
    errores = []
    huella_mod = blueprint_modificado.pisos[0].huella()
    huella_orig = blueprint_original.pisos[0].huella()
    if huella_mod != huella_orig:
        errores.append("La personalización modificó la huella del edificio de producción")
    if len(blueprint_modificado.conexiones) != len(blueprint_original.conexiones):
        errores.append("La personalización modificó el número de conexiones (entradas/salidas)")
    return errores


def validar_blueprint(
    blueprint: Blueprint,
    zona_destino: str = None,
    blueprint_anterior: Blueprint = None,
    blueprint_original_produccion: Blueprint = None,
) -> ResultadoValidacion:
    """Agregador: aplica las reglas estructurales siempre, y las reglas contextuales solo si aplican."""
    errores = []

    for piso in blueprint.pisos:
        errores += validar_cerramiento(piso)
        errores += validar_aberturas(piso)

    errores += validar_camas_y_almacenamiento(blueprint)
    errores += validar_zona_permitida(blueprint)

    if zona_destino is not None:
        errores += validar_colocacion(blueprint, zona_destino)
    if blueprint_anterior is not None:
        errores += validar_evolucion(blueprint, blueprint_anterior)
    if blueprint.tipo == "produccion" and blueprint_original_produccion is not None:
        errores += validar_personalizacion_produccion(blueprint, blueprint_original_produccion)

    return ResultadoValidacion(valido=(len(errores) == 0), errores=errores)
```

### **3.2 Bucle de Integración y Pruebas Unitarias**

```python
BLUEPRINT_VALIDO = """
{
  "nombre": "Cabana_Colono_v1",
  "tipo": "residencial",
  "zona_permitida": "residencial_investigacion",
  "pisos": [
    {
      "nivel": 0,
      "celdas": {
        "0,0": "pared", "1,0": "puerta", "2,0": "pared",
        "0,1": "pared", "1,1": "piso",   "2,1": "pared",
        "0,2": "pared", "1,2": "ventana","2,2": "pared"
      },
      "camas": [{"pos": "1,1", "baul": true}]
    }
  ]
}
"""


def ejecutar_pruebas():
    print("=== TEST 1: Blueprint Válido (debe pasar sin errores) ===")
    bp_valido = Blueprint.desde_json(BLUEPRINT_VALIDO)
    resultado = validar_blueprint(bp_valido, zona_destino="residencial_investigacion")
    print(f"Válido: {resultado.valido} | Errores: {resultado.errores}")
    assert resultado.valido

    print("\n=== TEST 2: Hueco en el Perímetro (celda de borde tipo 'piso') ===")
    bp_con_hueco = Blueprint.desde_json(BLUEPRINT_VALIDO)
    bp_con_hueco.pisos[0].celdas["2,1"] = "piso"  # se reemplaza una pared de borde por un hueco
    resultado = validar_blueprint(bp_con_hueco)
    print(f"Válido: {resultado.valido} | Errores: {resultado.errores}")
    assert not resultado.valido
    assert any("hueco en el perímetro" in e for e in resultado.errores)

    print("\n=== TEST 3: Esquina Reemplazada por Ventana (debe ser pared) ===")
    bp_esquina_invalida = Blueprint.desde_json(BLUEPRINT_VALIDO)
    bp_esquina_invalida.pisos[0].celdas["0,0"] = "ventana"  # (0,0) es esquina
    resultado = validar_blueprint(bp_esquina_invalida)
    print(f"Válido: {resultado.valido} | Errores: {resultado.errores}")
    assert not resultado.valido
    assert any("esquina" in e for e in resultado.errores)

    print("\n=== TEST 4: Sin Ventana ===")
    bp_sin_ventana = Blueprint.desde_json(BLUEPRINT_VALIDO)
    bp_sin_ventana.pisos[0].celdas["1,2"] = "pared"  # se elimina la única ventana
    resultado = validar_blueprint(bp_sin_ventana)
    print(f"Válido: {resultado.valido} | Errores: {resultado.errores}")
    assert not resultado.valido
    assert any("falta al menos una ventana" in e for e in resultado.errores)

    print("\n=== TEST 5: Cama sin Baúl ===")
    bp_sin_baul = Blueprint.desde_json(BLUEPRINT_VALIDO)
    bp_sin_baul.pisos[0].camas[0]["baul"] = False
    resultado = validar_blueprint(bp_sin_baul)
    print(f"Válido: {resultado.valido} | Errores: {resultado.errores}")
    assert not resultado.valido
    assert any("no tiene baúl emparejado" in e for e in resultado.errores)

    print("\n=== TEST 6: Colocación en Zona Incorrecta ===")
    resultado = validar_blueprint(bp_valido, zona_destino="fabricacion_militar")
    print(f"Válido: {resultado.valido} | Errores: {resultado.errores}")
    assert not resultado.valido
    assert any("no puede colocarse en la zona" in e for e in resultado.errores)

    print("\n=== TEST 7: Evolución con Huella Superior Excedida ===")
    bp_version_2 = Blueprint.desde_json(BLUEPRINT_VALIDO)
    piso_superior = Piso(
        nivel=1,
        celdas={**bp_version_2.pisos[0].celdas, "3,1": "pared"},  # celda fuera de la huella original
    )
    bp_version_2.pisos.append(piso_superior)
    resultado = validar_blueprint(bp_version_2, blueprint_anterior=bp_valido)
    print(f"Válido: {resultado.valido} | Errores: {resultado.errores}")
    assert not resultado.valido
    assert any("excede la huella" in e for e in resultado.errores)

    print("\n=== TEST 8: Personalización de Producción Cambia Conexiones ===")
    bp_produccion_original = Blueprint(
        nombre="Horno_Fundicion",
        tipo="produccion",
        zona_permitida="fabricacion_militar",
        pisos=[Piso(nivel=0, celdas=bp_valido.pisos[0].celdas)],
        conexiones=[{"tipo": "entrada", "pos": "0,1"}, {"tipo": "salida", "pos": "2,1"}],
    )
    bp_produccion_modificado = Blueprint(
        nombre="Horno_Fundicion_Custom",
        tipo="produccion",
        zona_permitida="fabricacion_militar",
        pisos=[Piso(nivel=0, celdas=bp_valido.pisos[0].celdas)],
        conexiones=[{"tipo": "entrada", "pos": "0,1"}],  # se eliminó una conexión
    )
    resultado = validar_blueprint(
        bp_produccion_modificado, blueprint_original_produccion=bp_produccion_original
    )
    print(f"Válido: {resultado.valido} | Errores: {resultado.errores}")
    assert not resultado.valido
    assert any("número de conexiones" in e for e in resultado.errores)


if __name__ == "__main__":
    ejecutar_pruebas()
```

### **3.3 Criterios de Aceptación Técnicos**

1. **Detección Exhaustiva de Huecos:** Ninguna celda de borde con tipo `piso` debe pasar la validación de cerramiento, sin importar la forma del edificio.
2. **Esquinas Estrictas:** Una esquina identificada por vecinos perpendiculares ausentes debe ser rechazada si no es `pared`, incluso si es `puerta` o `ventana`.
3. **Independencia de Reglas:** Cada función de validación (`validar_*`) debe poder ejecutarse y probarse de forma aislada, sin depender de que otras hayan pasado antes.
4. **Zona Obligatoria:** Un Blueprint sin `zona_permitida` válida nunca debe reportarse como válido, independientemente de su estructura.
5. **Evolución No Retroactiva:** `validar_evolucion` debe comparar siempre contra el piso 0 (planta base) de la versión anterior, nunca contra un piso superior.
6. **Agregación Sin Falsos Negativos:** `validar_blueprint()` debe acumular errores de **todas** las reglas aplicables en una sola pasada, no detenerse en el primer error encontrado.

---

## **Próximos Pasos de esta PoC**

> 1. Ejecutar `ejecutar_pruebas()` y confirmar que los 8 asserts pasan sin error.
> 2. Evaluar si la simplificación de "aberturas por piso completo" (en vez de por habitación) es aceptable para el prototipo visual de PoC 3, o si conviene resolver la detección de habitaciones antes.
> 3. Diseñar en PoC 3 cómo un Blueprint validado aquí se traduce a bloques reales sobre un `GridMap` de Godot.
