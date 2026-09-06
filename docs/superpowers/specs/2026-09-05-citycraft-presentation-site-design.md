# Diseño del sitio de presentación de CityCraft

**Fecha:** 2026-09-05  
**Estado:** Aprobado para revisión final  
**Ubicación prevista:** `website/`

## Objetivo

Presentar CityCraft a familiares, amigos y posibles colaboradores de forma atractiva y comprensible. El sitio debe comunicar primero la visión completa del juego, mostrar después el avance real del desarrollo e invitar a ayudar mediante difusión, retroalimentación, programación o financiación.

## Audiencia y mensaje

El contenido estará escrito en español para personas con y sin experiencia técnica. La idea central será: el jugador comienza sobreviviendo y construyendo con sus propias manos, y termina liderando una ciudad industrial viva desde primera persona y desde una vista estratégica.

El sitio distinguirá claramente entre la visión futura y el estado actual para no presentar funciones planeadas como si ya estuvieran implementadas.

## Dirección visual

La dirección aprobada se llama **Frontera viva**, una combinación de:

- Materiales oscuros, madera, piedra, metal y luz ámbar para transmitir construcción artesanal e industrialización.
- Vegetación, iluminación natural y tonos tierra para mantener una sensación cercana, viva y esperanzadora.
- Geometría de bloques con acabado PBR y personajes low-poly, coherente con Poly Haven, 3dtextures.me, Quaternius y KayKit mencionados en el GDD.

Las imágenes conceptuales originales se identificarán como tales. Las capturas del prototipo se identificarán como imágenes reales del desarrollo.

## Estructura de la página

1. **Encabezado y hero:** nombre, propuesta central, resumen corto y botones hacia la visión y las formas de ayudar.
2. **El viaje del jugador:** sobrevivir, fundar, automatizar y liderar.
3. **Identidad del juego:** cámara dual, blueprints, ciudad viva, logística, combate y núcleos portátiles multijugador.
4. **Visión del mundo:** composición visual de la ciudad y texto que conecte sus sistemas.
5. **Estado del desarrollo:** progreso actual tomado del GDD, organizado por PoC o fase y fácil de editar directamente en HTML.
6. **Formas de ayudar:** difusión, ideas y pruebas, desarrollo/programación y apoyo económico.
7. **Contacto:** WhatsApp y correo electrónico.
8. **Pie:** aclaración de proyecto independiente y estado de desarrollo.

## Contacto

El botón de WhatsApp abrirá `wa.me` para el número `+57 320 877 2240` con este mensaje codificado:

> Hola, vi el sitio de CityCraft y me gustaría conocer más sobre el proyecto y cómo puedo ayudar.

El correo usará `mailto:gigalipa@gmail.com` con asunto y cuerpo prediseñados equivalentes.

No habrá formulario ni servidor: ambos añadirían mantenimiento sin mejorar el contacto inicial.

## Implementación

El sitio será estático y estará contenido en `website/`:

- `index.html`: estructura y contenido.
- `styles.css`: diseño adaptable, animaciones discretas y estados de interacción.
- `assets/`: imágenes optimizadas y recursos locales.

No se usará framework, gestor de paquetes, backend ni JavaScript salvo que una interacción indispensable lo requiera durante la implementación. La navegación será por anclas nativas y los contactos serán enlaces normales.

## Adaptación y accesibilidad

- Diseño usable desde 320 px hasta escritorio amplio.
- HTML semántico, jerarquía correcta de encabezados y navegación por teclado.
- Contraste legible, foco visible y textos alternativos para imágenes.
- Animaciones desactivadas cuando el sistema solicite movimiento reducido.
- Botones de contacto suficientemente grandes para pantallas táctiles.

## Actualización del progreso

La sección de desarrollo no calculará porcentajes inventados. Cada elemento mostrará un estado textual verificable: completado, en validación, en desarrollo o planeado. Al completar una PoC o fase bastará con editar un bloque de contenido en `index.html`.

## Verificación

- Abrir el sitio mediante un servidor HTTP local y comprobar que no haya errores de carga.
- Revisar visualmente escritorio y móvil.
- Comprobar enlaces internos, WhatsApp y correo sin enviar mensajes.
- Confirmar que el contenido de progreso coincide con el GDD actualizado.
- Validar que el sitio sigue siendo comprensible si las imágenes no cargan.

## Fuera de alcance

Publicación en hosting, dominio, analítica, donaciones integradas, CMS, formulario de contacto, cuentas de usuario, traducción y panel administrativo. Se añadirán únicamente cuando exista una necesidad concreta.
