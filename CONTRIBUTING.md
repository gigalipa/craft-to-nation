# Contribuir a Craft to Nation

Gracias por ayudar a construir Craft to Nation.

## Antes de empezar

- Abre un issue antes de realizar cambios grandes o modificar decisiones del GDD.
- Mantén cada cambio enfocado y evita dependencias nuevas si la plataforma o el código existente ya resuelven el problema.
- No incluyas secretos, cachés, exportaciones ni estado local de herramientas.

## Flujo de trabajo

1. Crea una rama desde `main`.
2. Implementa un cambio pequeño y comprobable.
3. Ejecuta las pruebas relacionadas.
4. Describe en el pull request qué cambió, por qué y cómo lo verificaste.

Para verificar el sitio:

```shell
python -m unittest discover -s website -p "test_*.py"
```

Las pruebas de Godot están en `PoC_3/scenes/Test.tscn` y deben ejecutarse desde Godot 4.7.

## Aportes asistidos por IA

Puedes usar herramientas como Claude Code CLI. Debes revisar y entender el resultado, comprobar que funciona y asegurarte de que no copie material incompatible ni exponga información confidencial. La responsabilidad del aporte sigue siendo de quien lo envía.

## Condiciones de licencia

Al contribuir confirmas que tienes derecho a publicar el aporte y aceptas que:

- el código se distribuya bajo la licencia MIT del repositorio;
- la documentación y los recursos originales se distribuyan bajo CC BY 4.0.
