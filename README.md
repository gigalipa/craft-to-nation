# Craft to Nation

![Logotipo de Craft to Nation](website/assets/craft-to-nation-logo.png)

**Craft to Nation** es un juego de supervivencia, construcción y estrategia en el que el jugador transforma un refugio en una nación industrial viva.

El proyecto está en etapa de pruebas de concepto. El desarrollo actual valida sus sistemas principales antes de consolidarlos en una arquitectura definitiva.

## Estado actual

- GDD inicial y hoja de ruta técnica.
- PoC 1: recursos, demografía y nivel urbano.
- PoC 2: serialización y validación de blueprints y zonas.
- PoC 3: prototipo visual mínimo en Godot 4.7.
- Sitio de presentación estático.

## Estructura

```text
PoC_1/     Documentación del motor lógico
PoC_2/     Documentación de serialización y validación
PoC_3/     Proyecto y pruebas en Godot
website/   Sitio de presentación
docs/      Especificaciones y planes de desarrollo
```

El documento [GDD](Documento%20de%20Diseño%20de%20Juego%20%28GDD%29_%20Craft%20to%20Nation.md) contiene la visión completa del juego.

## Ejecutar el prototipo

1. Instala Godot 4.7.
2. Importa `PoC_3/project.godot`.
3. Ejecuta el proyecto con **F5**. Para correr las pruebas, abre `PoC_3/scenes/Test.tscn` y usa **F6**.

Las verificaciones del sitio solo requieren Python 3:

```shell
python -m unittest discover -s website -p "test_*.py"
```

El sitio también puede abrirse directamente desde `website/index.html`.

## Contribuir

Consulta [CONTRIBUTING.md](CONTRIBUTING.md) antes de enviar cambios. Se aceptan aportes humanos o asistidos por IA siempre que quien los envía los haya revisado y pueda responder por ellos.

## Licencias

- El código fuente se distribuye bajo la [licencia MIT](LICENSE).
- La documentación y los recursos originales se distribuyen bajo [CC BY 4.0](LICENSE-CONTENT.md).
- El nombre y los logotipos de Craft to Nation no quedan licenciados para identificar proyectos derivados.
