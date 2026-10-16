import os
import sys

ICONS_DIR = os.path.join(os.path.dirname(__file__), "..", "godot", "assets", "icons")

def ensure_dir(path):
    os.makedirs(path, exist_ok=True)

def write_svg(filename, content):
    filepath = os.path.join(ICONS_DIR, filename)
    with open(filepath, "w", encoding="utf-8") as f:
        f.write(content.strip() + "\n")
    print(f"Written: {filename}")

def svg_wrap(w, h, body, viewbox=None):
    vb = viewbox if viewbox else f"0 0 {w} {h}"
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="{vb}" shape-rendering="crispEdges">
{body}
</svg>"""

# Colores comunes de paleta y HUD
DORADO = "#C79E40"
DORADO_CLARO = "#FFE082"
DORADO_OSCURO = "#8D6E1E"
VERDE_HUD = "#0D211A"
TEXTO_CREMA = "#F2EBD1"
VALIDO_VERDE = "#73E673"
INVALIDO_ROJO = "#FF5959"
AMBAR = "#FFA633"
GRIS_OSCURO = "#2B2D31"
GRIS_MEDIO = "#5A5D64"
GRIS_CLARO = "#9E9E9E"
BLANCO = "#FFFFFF"
AZUL_AGUA = "#42A5F5"
AZUL_CIAN = "#26C6DA"
MARRON_MADERA = "#8D6E63"
MARRON_CORTEZA = "#4E342E"
MARRON_TIERRA = "#5D4037"
MARRON_TIERRA_CLARA = "#795548"
COBRE = "#D87040"
COBRE_BRILLO = "#FFA07A"
HIERRO = "#546E7A"
OXIDO = "#A0522D"
ACERO = "#78909C"
ACERO_BRILLO = "#B0BEC5"
CARBON = "#1E2022"
CARBON_FACETA = "#37474F"
PURPURA_CRISTAL = "#AB47BC"
TURQUESA = "#26A69A"

# Base común para silueta humana (16x16)
# Cabeza: cx=8, cy=4. Torso: de y=8 a y=15
SILUETA_BASE_RECTS = """
  <!-- Cabeza -->
  <rect x="6" y="2" width="4" height="4" fill="{color}"/>
  <rect x="5" y="3" width="6" height="2" fill="{color}"/>
  <!-- Cuello y hombros -->
  <rect x="7" y="6" width="2" height="2" fill="{color}"/>
  <rect x="4" y="8" width="8" height="2" fill="{color}"/>
  <!-- Torso -->
  <rect x="3" y="10" width="10" height="5" fill="{color}"/>
"""

def generate_icons():
    ensure_dir(ICONS_DIR)

    # =========================================================================
    # 1. RECURSOS (15 recursos) - Retícula 20x20
    # =========================================================================

    # comida: Muslo de carne junto a una espiga de trigo
    write_svg("comida.svg", svg_wrap(20, 20, f"""
  <!-- Espiga de trigo (dorada, vertical/inclinada a la derecha) -->
  <rect x="13" y="3" width="2" height="3" fill="{DORADO_CLARO}"/>
  <rect x="11" y="5" width="2" height="3" fill="{DORADO}"/>
  <rect x="15" y="5" width="2" height="3" fill="{DORADO}"/>
  <rect x="12" y="8" width="2" height="3" fill="{DORADO_CLARO}"/>
  <rect x="10" y="9" width="2" height="3" fill="{DORADO}"/>
  <rect x="14" y="9" width="2" height="3" fill="{DORADO}"/>
  <rect x="12" y="11" width="2" height="7" fill="{DORADO_OSCURO}"/>

  <!-- Muslo de carne (marrón cálido / hueso blanco a la izquierda) -->
  <rect x="2" y="14" width="2" height="2" fill="{BLANCO}"/>
  <rect x="3" y="15" width="2" height="2" fill="{BLANCO}"/>
  <rect x="4" y="13" width="3" height="3" fill="{BLANCO}"/>
  <!-- Carne asada -->
  <rect x="6" y="9" width="5" height="6" fill="#A04020"/>
  <rect x="5" y="10" width="7" height="4" fill="#C05030"/>
  <rect x="7" y="10" width="4" height="3" fill="#D2691E"/>
  <rect x="7" y="8" width="3" height="2" fill="#8B2500"/>
"""))

    # madera: Troncos cilíndricos apilados con corteza marrón y anillos visibles
    write_svg("madera.svg", svg_wrap(20, 20, f"""
  <!-- Tronco inferior izquierdo -->
  <rect x="2" y="11" width="7" height="7" fill="{MARRON_CORTEZA}"/>
  <rect x="3" y="12" width="5" height="5" fill="{MARRON_MADERA}"/>
  <rect x="5" y="14" width="1" height="1" fill="{MARRON_CORTEZA}"/>
  <!-- Tronco inferior derecho -->
  <rect x="10" y="11" width="7" height="7" fill="{MARRON_CORTEZA}"/>
  <rect x="11" y="12" width="5" height="5" fill="{MARRON_MADERA}"/>
  <rect x="13" y="14" width="1" height="1" fill="{MARRON_CORTEZA}"/>
  <!-- Tronco superior central -->
  <rect x="6" y="4" width="7" height="7" fill="{MARRON_CORTEZA}"/>
  <rect x="7" y="5" width="5" height="5" fill="{MARRON_MADERA}"/>
  <rect x="9" y="7" width="1" height="1" fill="{MARRON_CORTEZA}"/>
"""))

    # tablas: Tablones rectangulares de madera clara apilados en diagonal
    write_svg("tablas.svg", svg_wrap(20, 20, f"""
  <!-- Tablón inferior -->
  <rect x="2" y="14" width="15" height="4" fill="{MARRON_MADERA}"/>
  <rect x="3" y="15" width="13" height="2" fill="#BA8C63"/>
  <rect x="2" y="14" width="1" height="4" fill="{MARRON_CORTEZA}"/>
  <!-- Tablón medio desplazado -->
  <rect x="4" y="9" width="14" height="4" fill="{MARRON_MADERA}"/>
  <rect x="5" y="10" width="12" height="2" fill="#CD9B6D"/>
  <rect x="4" y="9" width="1" height="4" fill="{MARRON_CORTEZA}"/>
  <!-- Tablón superior -->
  <rect x="3" y="4" width="13" height="4" fill="{MARRON_MADERA}"/>
  <rect x="4" y="5" width="11" height="2" fill="#DEC092"/>
  <rect x="3" y="4" width="1" height="4" fill="{MARRON_CORTEZA}"/>
"""))

    # tierra: Montículo de tierra marrón oscuro con terrones
    write_svg("tierra.svg", svg_wrap(20, 20, f"""
  <!-- Montículo base -->
  <rect x="2" y="15" width="16" height="4" fill="{MARRON_TIERRA}"/>
  <rect x="4" y="12" width="12" height="4" fill="{MARRON_TIERRA}"/>
  <rect x="6" y="9" width="8" height="4" fill="{MARRON_TIERRA}"/>
  <rect x="8" y="6" width="4" height="3" fill="{MARRON_TIERRA_CLARA}"/>
  <!-- Terrones y detalles de textura -->
  <rect x="5" y="13" width="2" height="2" fill="{MARRON_TIERRA_CLARA}"/>
  <rect x="11" y="11" width="3" height="2" fill="{MARRON_TIERRA_CLARA}"/>
  <rect x="13" y="14" width="2" height="2" fill="#42291F"/>
  <rect x="3" y="16" width="3" height="1" fill="#42291F"/>
"""))

    # piedra: Roca gris irregular angulosa con fragmentos
    write_svg("piedra.svg", svg_wrap(20, 20, f"""
  <!-- Bloque de roca principal -->
  <rect x="4" y="7" width="11" height="9" fill="{GRIS_MEDIO}"/>
  <rect x="6" y="5" width="8" height="12" fill="{GRIS_MEDIO}"/>
  <rect x="5" y="6" width="10" height="10" fill="{GRIS_MEDIO}"/>
  <!-- Facetas iluminadas (arriba/izquierda) -->
  <rect x="6" y="6" width="5" height="4" fill="{GRIS_CLARO}"/>
  <rect x="7" y="5" width="4" height="2" fill="{GRIS_CLARO}"/>
  <!-- Sombras (abajo/derecha) -->
  <rect x="11" y="12" width="4" height="4" fill="{GRIS_OSCURO}"/>
  <rect x="7" y="15" width="6" height="2" fill="{GRIS_OSCURO}"/>
  <!-- Fragmento suelto -->
  <rect x="16" y="14" width="2" height="2" fill="{GRIS_MEDIO}"/>
  <rect x="2" y="15" width="2" height="2" fill="{GRIS_OSCURO}"/>
"""))

    # bloques_piedra: Sillares/ladrillos de piedra gris tallados y apilados
    write_svg("bloques_piedra.svg", svg_wrap(20, 20, f"""
  <!-- Fila inferior: dos sillares -->
  <rect x="2" y="11" width="7" height="6" fill="{GRIS_MEDIO}"/>
  <rect x="3" y="12" width="5" height="4" fill="{GRIS_CLARO}"/>
  <rect x="10" y="11" width="8" height="6" fill="{GRIS_MEDIO}"/>
  <rect x="11" y="12" width="6" height="4" fill="{GRIS_CLARO}"/>
  <!-- Juntas de mortero -->
  <rect x="9" y="11" width="1" height="6" fill="{GRIS_OSCURO}"/>
  <rect x="2" y="10" width="16" height="1" fill="{GRIS_OSCURO}"/>
  <!-- Fila superior: sillar central desplazado -->
  <rect x="5" y="4" width="9" height="6" fill="{GRIS_MEDIO}"/>
  <rect x="6" y="5" width="7" height="4" fill="{GRIS_CLARO}"/>
"""))

    # hierro: Pila de 3 lingotes gris oscuro metalizado con marcas de óxido
    write_svg("hierro.svg", svg_wrap(20, 20, f"""
  <!-- Lingote inferior izquierdo -->
  <rect x="2" y="12" width="7" height="5" fill="{HIERRO}"/>
  <rect x="3" y="13" width="5" height="2" fill="{ACERO_BRILLO}"/>
  <rect x="5" y="15" width="2" height="2" fill="{OXIDO}"/>
  <!-- Lingote inferior derecho -->
  <rect x="10" y="12" width="8" height="5" fill="{HIERRO}"/>
  <rect x="11" y="13" width="5" height="2" fill="{ACERO_BRILLO}"/>
  <rect x="12" y="14" width="2" height="2" fill="{OXIDO}"/>
  <!-- Lingote superior centrado -->
  <rect x="5" y="6" width="9" height="5" fill="{HIERRO}"/>
  <rect x="6" y="7" width="6" height="2" fill="{ACERO_BRILLO}"/>
  <rect x="9" y="8" width="2" height="2" fill="{OXIDO}"/>
"""))

    # cobre: Pila de 3 lingotes cobrizo metalizado
    write_svg("cobre.svg", svg_wrap(20, 20, f"""
  <!-- Lingote inferior izquierdo -->
  <rect x="2" y="12" width="7" height="5" fill="{COBRE}"/>
  <rect x="3" y="13" width="5" height="2" fill="{COBRE_BRILLO}"/>
  <rect x="2" y="15" width="7" height="2" fill="#A04015"/>
  <!-- Lingote inferior derecho -->
  <rect x="10" y="12" width="8" height="5" fill="{COBRE}"/>
  <rect x="11" y="13" width="6" height="2" fill="{COBRE_BRILLO}"/>
  <rect x="10" y="15" width="8" height="2" fill="#A04015"/>
  <!-- Lingote superior -->
  <rect x="5" y="6" width="9" height="5" fill="{COBRE}"/>
  <rect x="6" y="7" width="7" height="2" fill="{COBRE_BRILLO}"/>
  <rect x="5" y="9" width="9" height="2" fill="#A04015"/>
"""))

    # carbon: Fragmentos de mineral negro brillante y facetado
    write_svg("carbon.svg", svg_wrap(20, 20, f"""
  <rect x="4" y="6" width="11" height="11" fill="{CARBON}"/>
  <rect x="6" y="4" width="8" height="13" fill="{CARBON}"/>
  <!-- Facetas brillantes antracita -->
  <rect x="6" y="6" width="4" height="4" fill="{CARBON_FACETA}"/>
  <rect x="7" y="7" width="2" height="2" fill="{GRIS_MEDIO}"/>
  <rect x="11" y="9" width="3" height="4" fill="{CARBON_FACETA}"/>
  <rect x="6" y="12" width="5" height="3" fill="#111315"/>
"""))

    # tierras_raras: Cristales minerales violeta/cian sobre base rocosa
    write_svg("tierras_raras.svg", svg_wrap(20, 20, f"""
  <!-- Base de roca -->
  <rect x="3" y="14" width="14" height="4" fill="{GRIS_OSCURO}"/>
  <rect x="5" y="12" width="10" height="3" fill="{GRIS_MEDIO}"/>
  <!-- Cristal cian central alto -->
  <rect x="8" y="3" width="3" height="10" fill="{AZUL_CIAN}"/>
  <rect x="9" y="4" width="1" height="8" fill="{BLANCO}"/>
  <rect x="9" y="2" width="1" height="2" fill="{AZUL_CIAN}"/>
  <!-- Cristal violeta izquierdo -->
  <rect x="5" y="6" width="3" height="7" fill="{PURPURA_CRISTAL}"/>
  <rect x="6" y="7" width="1" height="5" fill="#E1BEE7"/>
  <!-- Cristal violeta derecho -->
  <rect x="12" y="7" width="3" height="6" fill="{PURPURA_CRISTAL}"/>
  <rect x="13" y="8" width="1" height="4" fill="#E1BEE7"/>
"""))

    # acero: Par de lingotes pulidos gris azulado
    write_svg("acero.svg", svg_wrap(20, 20, f"""
  <!-- Lingote inferior -->
  <rect x="3" y="11" width="13" height="6" fill="{ACERO}"/>
  <rect x="4" y="12" width="11" height="2" fill="{ACERO_BRILLO}"/>
  <rect x="4" y="12" width="2" height="2" fill="{BLANCO}"/>
  <rect x="3" y="15" width="13" height="2" fill="#455A64"/>
  <!-- Lingote superior -->
  <rect x="5" y="5" width="12" height="5" fill="{ACERO}"/>
  <rect x="6" y="6" width="10" height="2" fill="{ACERO_BRILLO}"/>
  <rect x="7" y="6" width="3" height="1" fill="{BLANCO}"/>
  <rect x="5" y="8" width="12" height="2" fill="#455A64"/>
"""))

    # mineral_refinado: Prisma hexagonal esmeralda/turquesa con brillo
    write_svg("mineral_refinado.svg", svg_wrap(20, 20, f"""
  <!-- Forma hexagonal prisma -->
  <rect x="8" y="2" width="4" height="16" fill="{TURQUESA}"/>
  <rect x="6" y="4" width="8" height="12" fill="{TURQUESA}"/>
  <rect x="5" y="6" width="10" height="8" fill="{TURQUESA}"/>
  <!-- Faceta frontal iluminada -->
  <rect x="8" y="4" width="3" height="12" fill="#80CBC4"/>
  <rect x="9" y="5" width="1" height="10" fill="{BLANCO}"/>
  <!-- Sombras laterales -->
  <rect x="5" y="8" width="2" height="5" fill="#004D40"/>
  <rect x="13" y="8" width="2" height="5" fill="#00796B"/>
"""))

    # agua: Gota de agua cristalina azul claro con reflejo
    write_svg("agua.svg", svg_wrap(20, 20, f"""
  <!-- Gota apuntando arriba -->
  <rect x="9" y="3" width="2" height="2" fill="{AZUL_AGUA}"/>
  <rect x="8" y="5" width="4" height="2" fill="{AZUL_AGUA}"/>
  <rect x="7" y="7" width="6" height="3" fill="{AZUL_AGUA}"/>
  <rect x="6" y="10" width="8" height="5" fill="{AZUL_AGUA}"/>
  <rect x="7" y="15" width="6" height="2" fill="{AZUL_AGUA}"/>
  <rect x="8" y="17" width="4" height="1" fill="{AZUL_AGUA}"/>
  <!-- Reflejo blanco curvo -->
  <rect x="8" y="7" width="1" height="4" fill="{BLANCO}"/>
  <rect x="7" y="10" width="1" height="3" fill="{BLANCO}"/>
"""))

    # crudo: Barril industrial azul con gota de crudo negra brillante
    write_svg("crudo.svg", svg_wrap(20, 20, f"""
  <!-- Barril industrial azul -->
  <rect x="5" y="4" width="10" height="13" fill="#1D63B8"/>
  <rect x="4" y="6" width="12" height="9" fill="#2563EB"/>
  <!-- Flejes/aros oscuros -->
  <rect x="4" y="6" width="12" height="1" fill="#154785"/>
  <rect x="4" y="10" width="12" height="1" fill="#154785"/>
  <rect x="4" y="14" width="12" height="1" fill="#154785"/>
  <!-- Tapa -->
  <rect x="6" y="3" width="8" height="1" fill="#1E40AF"/>
  <!-- Gota de crudo negra brillante -->
  <rect x="9" y="8" width="3" height="4" fill="#000000"/>
  <rect x="10" y="7" width="1" height="6" fill="#000000"/>
  <rect x="10" y="8" width="1" height="2" fill="{BLANCO}"/>
"""))

    # combustible: Bidón rojo/ámbar con llama
    write_svg("combustible.svg", svg_wrap(20, 20, f"""
  <!-- Bidón jerrycan -->
  <rect x="4" y="5" width="11" height="12" fill="#D32F2F"/>
  <rect x="5" y="3" width="3" height="2" fill="#B71C1C"/>
  <rect x="9" y="3" width="4" height="2" fill="#B71C1C"/>
  <!-- Asa -->
  <rect x="7" y="3" width="3" height="1" fill="#B71C1C"/>
  <!-- Llama amarilla en el centro -->
  <rect x="9" y="8" width="2" height="4" fill="{AMBAR}"/>
  <rect x="8" y="10" width="4" height="3" fill="{AMBAR}"/>
  <rect x="9" y="11" width="2" height="2" fill="{DORADO_CLARO}"/>
"""))

    # =========================================================================
    # 2. DEMOGRAFÍA Y OFICIOS (Silueta unificada 16x16)
    # =========================================================================

    # ciudadano: Silueta simple de una persona en color crema
    write_svg("ciudadano.svg", svg_wrap(16, 16, SILUETA_BASE_RECTS.format(color=TEXTO_CREMA)))

    # censo: Triple silueta de personas
    write_svg("censo.svg", svg_wrap(20, 16, f"""
  <!-- Persona izquierda (fondo) -->
  <g opacity="0.6">
    <rect x="2" y="3" width="3" height="3" fill="{TEXTO_CREMA}"/>
    <rect x="1" y="6" width="5" height="7" fill="{TEXTO_CREMA}"/>
  </g>
  <!-- Persona derecha (fondo) -->
  <g opacity="0.6">
    <rect x="14" y="3" width="3" height="3" fill="{TEXTO_CREMA}"/>
    <rect x="13" y="6" width="5" height="7" fill="{TEXTO_CREMA}"/>
  </g>
  <!-- Persona central (frente) -->
  <rect x="7" y="1" width="4" height="4" fill="{DORADO}"/>
  <rect x="5" y="5" width="8" height="9" fill="{DORADO}"/>
"""))

    # desempleado: Silueta con brazos cruzados
    write_svg("desempleado.svg", svg_wrap(16, 16, f"""
{SILUETA_BASE_RECTS.format(color=TEXTO_CREMA)}
  <!-- Brazos cruzados sobre el pecho -->
  <rect x="3" y="11" width="10" height="2" fill="{GRIS_MEDIO}"/>
  <rect x="5" y="12" width="6" height="2" fill="{TEXTO_CREMA}"/>
"""))

    # obrero / recolector: Casco de obra amarillo/dorado
    write_svg("obrero.svg", svg_wrap(16, 16, f"""
{SILUETA_BASE_RECTS.format(color=TEXTO_CREMA)}
  <!-- Casco de obra -->
  <rect x="5" y="1" width="6" height="3" fill="{AMBAR}"/>
  <rect x="4" y="3" width="8" height="1" fill="{DORADO}"/>
"""))

    # tecnico: Gafas protectoras y engranaje pequeño
    write_svg("tecnico.svg", svg_wrap(16, 16, f"""
{SILUETA_BASE_RECTS.format(color=TEXTO_CREMA)}
  <!-- Gafas protectoras -->
  <rect x="5" y="3" width="6" height="2" fill="{AZUL_CIAN}"/>
  <rect x="7" y="3" width="2" height="1" fill="{GRIS_OSCURO}"/>
  <!-- Engranaje en el pecho -->
  <rect x="6" y="11" width="4" height="3" fill="{DORADO}"/>
  <rect x="7" y="10" width="2" height="5" fill="{DORADO}"/>
  <rect x="7" y="12" width="2" height="1" fill="{TEXTO_CREMA}"/>
"""))

    # especialista: Calibre de precisión
    write_svg("especialista.svg", svg_wrap(16, 16, f"""
{SILUETA_BASE_RECTS.format(color=TEXTO_CREMA)}
  <!-- Calibre / pie de rey en la mano/pecho -->
  <rect x="9" y="8" width="2" height="7" fill="{ACERO_BRILLO}"/>
  <rect x="8" y="8" width="4" height="2" fill="{DORADO}"/>
  <rect x="8" y="11" width="3" height="1" fill="{DORADO}"/>
"""))

    # investigador: Birrete y libro abierto
    write_svg("investigador.svg", svg_wrap(16, 16, f"""
{SILUETA_BASE_RECTS.format(color=TEXTO_CREMA)}
  <!-- Birrete académico -->
  <rect x="4" y="1" width="8" height="2" fill="{AZUL_CIAN}"/>
  <rect x="7" y="0" width="2" height="1" fill="{AZUL_CIAN}"/>
  <rect x="12" y="2" width="1" height="3" fill="{DORADO}"/>
  <!-- Libro abierto sobre el pecho -->
  <rect x="5" y="12" width="6" height="3" fill="{BLANCO}"/>
  <rect x="7" y="12" width="1" height="3" fill="{GRIS_MEDIO}"/>
"""))

    # militar: Escudo y espada cruzada
    write_svg("militar.svg", svg_wrap(16, 16, f"""
{SILUETA_BASE_RECTS.format(color=TEXTO_CREMA)}
  <!-- Escudo sobre el pecho -->
  <rect x="8" y="9" width="5" height="5" fill="{HIERRO}"/>
  <rect x="9" y="10" width="3" height="3" fill="{INVALIDO_ROJO}"/>
  <rect x="9" y="14" width="3" height="1" fill="{HIERRO}"/>
  <!-- Espada -->
  <rect x="4" y="8" width="2" height="7" fill="{ACERO_BRILLO}"/>
  <rect x="3" y="13" width="4" height="1" fill="{DORADO}"/>
"""))

    # aprendiz: Libro abierto y flecha ascendente
    write_svg("aprendiz.svg", svg_wrap(16, 16, f"""
{SILUETA_BASE_RECTS.format(color=TEXTO_CREMA)}
  <!-- Libro abierto -->
  <rect x="4" y="12" width="5" height="3" fill="{BLANCO}"/>
  <!-- Flecha verde ascendente -->
  <rect x="11" y="9" width="3" height="1" fill="{VALIDO_VERDE}"/>
  <rect x="12" y="8" width="1" height="5" fill="{VALIDO_VERDE}"/>
"""))

    # acarreador: Busto cargando caja de madera
    write_svg("acarreador.svg", svg_wrap(16, 16, f"""
{SILUETA_BASE_RECTS.format(color=TEXTO_CREMA)}
  <!-- Caja de madera en hombros/pecho -->
  <rect x="8" y="8" width="6" height="6" fill="{MARRON_MADERA}"/>
  <rect x="9" y="9" width="4" height="4" fill="#CD9B6D"/>
  <rect x="10" y="10" width="2" height="2" fill="{MARRON_CORTEZA}"/>
"""))

    # sin_techo: Desempleado con casita tachada delante
    write_svg("sin_techo.svg", svg_wrap(16, 16, f"""
  <!-- Silueta fondo -->
  <g opacity="0.7">
    {SILUETA_BASE_RECTS.format(color=GRIS_MEDIO)}
  </g>
  <!-- Casita tachada miniatura -->
  <rect x="1" y="10" width="7" height="5" fill="{MARRON_MADERA}"/>
  <rect x="2" y="8" width="5" height="2" fill="{DORADO_OSCURO}"/>
  <rect x="3" y="7" width="3" height="1" fill="{DORADO_OSCURO}"/>
  <!-- Aspa roja de tachado -->
  <rect x="0" y="7" width="2" height="2" fill="{INVALIDO_ROJO}"/>
  <rect x="2" y="9" width="2" height="2" fill="{INVALIDO_ROJO}"/>
  <rect x="4" y="11" width="2" height="2" fill="{INVALIDO_ROJO}"/>
  <rect x="6" y="13" width="2" height="2" fill="{INVALIDO_ROJO}"/>
  <rect x="6" y="7" width="2" height="2" fill="{INVALIDO_ROJO}"/>
  <rect x="0" y="13" width="2" height="2" fill="{INVALIDO_ROJO}"/>
"""))

    # =========================================================================
    # 3. BARRA SUPERIOR Y ESTADOS
    # =========================================================================

    # Cama (habitabilidad)
    write_svg("cama.svg", svg_wrap(16, 16, f"""
  <rect x="2" y="8" width="12" height="5" fill="{MARRON_MADERA}"/>
  <rect x="4" y="7" width="9" height="3" fill="{AZUL_AGUA}"/>
  <!-- Almohada -->
  <rect x="2" y="7" width="3" height="3" fill="{BLANCO}"/>
  <!-- Patas -->
  <rect x="2" y="13" width="2" height="2" fill="{MARRON_CORTEZA}"/>
  <rect x="12" y="13" width="2" height="2" fill="{MARRON_CORTEZA}"/>
"""))

    # Almacén (cajas apiladas)
    write_svg("almacen.svg", svg_wrap(16, 16, f"""
  <!-- Caja inferior izquierda -->
  <rect x="1" y="8" width="7" height="6" fill="{MARRON_MADERA}"/>
  <rect x="2" y="9" width="5" height="4" fill="#CD9B6D"/>
  <!-- Caja inferior derecha -->
  <rect x="8" y="8" width="7" height="6" fill="{MARRON_MADERA}"/>
  <rect x="9" y="9" width="5" height="4" fill="#CD9B6D"/>
  <!-- Caja superior central -->
  <rect x="4" y="2" width="7" height="6" fill="{MARRON_MADERA}"/>
  <rect x="5" y="3" width="5" height="4" fill="#CD9B6D"/>
"""))

    # 4 Caritas de moral pixel-art
    # Crítica (< 20%): Furia, roja
    write_svg("moral_critica.svg", svg_wrap(16, 16, f"""
  <rect x="3" y="1" width="10" height="14" fill="{INVALIDO_ROJO}"/>
  <rect x="1" y="3" width="14" height="10" fill="{INVALIDO_ROJO}"/>
  <!-- Ojos furiosos en diagonal hacia abajo -->
  <rect x="3" y="5" width="3" height="1" fill="#000"/>
  <rect x="4" y="6" width="3" height="2" fill="#000"/>
  <rect x="10" y="5" width="3" height="1" fill="#000"/>
  <rect x="9" y="6" width="3" height="2" fill="#000"/>
  <!-- Boca con dientes apretados / curva abajo -->
  <rect x="4" y="11" width="8" height="2" fill="#000"/>
  <rect x="5" y="11" width="2" height="2" fill="{BLANCO}"/>
  <rect x="9" y="11" width="2" height="2" fill="{BLANCO}"/>
"""))

    # Baja (20% - 35%): Triste, ámbar
    write_svg("moral_baja.svg", svg_wrap(16, 16, f"""
  <rect x="3" y="1" width="10" height="14" fill="{AMBAR}"/>
  <rect x="1" y="3" width="14" height="10" fill="{AMBAR}"/>
  <!-- Ojos caídos -->
  <rect x="4" y="5" width="2" height="3" fill="#000"/>
  <rect x="10" y="5" width="2" height="3" fill="#000"/>
  <!-- Boca triste -->
  <rect x="5" y="11" width="6" height="1" fill="#000"/>
  <rect x="4" y="12" width="2" height="2" fill="#000"/>
  <rect x="10" y="12" width="2" height="2" fill="#000"/>
"""))

    # Neutra (35% - 65%): Serena, crema
    write_svg("moral_neutra.svg", svg_wrap(16, 16, f"""
  <rect x="3" y="1" width="10" height="14" fill="{TEXTO_CREMA}"/>
  <rect x="1" y="3" width="14" height="10" fill="{TEXTO_CREMA}"/>
  <!-- Ojos redondos -->
  <rect x="4" y="5" width="2" height="3" fill="#000"/>
  <rect x="10" y="5" width="2" height="3" fill="#000"/>
  <!-- Boca recta horizontal -->
  <rect x="5" y="11" width="6" height="2" fill="#000"/>
"""))

    # Alta (>= 65%): Sonriente, verde/dorado
    write_svg("moral_alta.svg", svg_wrap(16, 16, f"""
  <rect x="3" y="1" width="10" height="14" fill="{VALIDO_VERDE}"/>
  <rect x="1" y="3" width="14" height="10" fill="{VALIDO_VERDE}"/>
  <!-- Ojos alegres / arqueados -->
  <rect x="4" y="6" width="3" height="2" fill="#000"/>
  <rect x="4" y="5" width="2" height="1" fill="#000"/>
  <rect x="9" y="6" width="3" height="2" fill="#000"/>
  <rect x="10" y="5" width="2" height="1" fill="#000"/>
  <!-- Sonrisa amplia -->
  <rect x="4" y="10" width="2" height="2" fill="#000"/>
  <rect x="10" y="10" width="2" height="2" fill="#000"/>
  <rect x="5" y="11" width="6" height="2" fill="#000"/>
"""))

    # Energía (Rayos en 3 estados)
    # Dorado (activo/suficiente)
    write_svg("energia_dorado.svg", svg_wrap(16, 16, f"""
  <path d="M9 1 L4 9 L8 9 L6 15 L13 7 L9 7 Z" fill="{DORADO}" stroke="{DORADO_CLARO}" stroke-width="1"/>
"""))
    # Gris (0/inactivo)
    write_svg("energia_gris.svg", svg_wrap(16, 16, f"""
  <path d="M9 1 L4 9 L8 9 L6 15 L13 7 L9 7 Z" fill="{GRIS_MEDIO}" stroke="{GRIS_CLARO}" stroke-width="1"/>
"""))
    # Rojo (déficit)
    write_svg("energia_rojo.svg", svg_wrap(16, 16, f"""
  <path d="M9 1 L4 9 L8 9 L6 15 L13 7 L9 7 Z" fill="{INVALIDO_ROJO}" stroke="#B71C1C" stroke-width="1"/>
"""))

    # Flechas de tendencia de tasas
    write_svg("tasa_arriba.svg", svg_wrap(12, 12, f"""
  <!-- Flecha verde ↗ -->
  <rect x="4" y="2" width="6" height="2" fill="{VALIDO_VERDE}"/>
  <rect x="8" y="4" width="2" height="4" fill="{VALIDO_VERDE}"/>
  <rect x="2" y="8" width="2" height="2" fill="{VALIDO_VERDE}"/>
  <rect x="4" y="6" width="2" height="2" fill="{VALIDO_VERDE}"/>
  <rect x="6" y="4" width="2" height="2" fill="{VALIDO_VERDE}"/>
"""))

    write_svg("tasa_neutra.svg", svg_wrap(12, 12, f"""
  <!-- Guión neutro gris — -->
  <rect x="2" y="5" width="8" height="2" fill="{GRIS_CLARO}"/>
"""))

    write_svg("tasa_abajo.svg", svg_wrap(12, 12, f"""
  <!-- Flecha roja ↘ -->
  <rect x="2" y="2" width="2" height="2" fill="{INVALIDO_ROJO}"/>
  <rect x="4" y="4" width="2" height="2" fill="{INVALIDO_ROJO}"/>
  <rect x="6" y="6" width="2" height="2" fill="{INVALIDO_ROJO}"/>
  <rect x="4" y="8" width="6" height="2" fill="{INVALIDO_ROJO}"/>
  <rect x="8" y="4" width="2" height="4" fill="{INVALIDO_ROJO}"/>
"""))

    # Números romanos para nivel (I, II, III) - 16x16
    write_svg("romano_1.svg", svg_wrap(16, 16, f"""
  <rect x="5" y="3" width="6" height="2" fill="{DORADO}"/>
  <rect x="7" y="5" width="2" height="6" fill="{DORADO}"/>
  <rect x="5" y="11" width="6" height="2" fill="{DORADO}"/>
"""))

    write_svg("romano_2.svg", svg_wrap(16, 16, f"""
  <rect x="2" y="3" width="5" height="2" fill="{DORADO}"/>
  <rect x="3" y="5" width="2" height="6" fill="{DORADO}"/>
  <rect x="2" y="11" width="5" height="2" fill="{DORADO}"/>

  <rect x="9" y="3" width="5" height="2" fill="{DORADO}"/>
  <rect x="10" y="5" width="2" height="6" fill="{DORADO}"/>
  <rect x="9" y="11" width="5" height="2" fill="{DORADO}"/>
"""))

    write_svg("romano_3.svg", svg_wrap(16, 16, f"""
  <rect x="1" y="3" width="4" height="2" fill="{DORADO}"/>
  <rect x="2" y="5" width="2" height="6" fill="{DORADO}"/>
  <rect x="1" y="11" width="4" height="2" fill="{DORADO}"/>

  <rect x="6" y="3" width="4" height="2" fill="{DORADO}"/>
  <rect x="7" y="5" width="2" height="6" fill="{DORADO}"/>
  <rect x="6" y="11" width="4" height="2" fill="{DORADO}"/>

  <rect x="11" y="3" width="4" height="2" fill="{DORADO}"/>
  <rect x="12" y="5" width="2" height="6" fill="{DORADO}"/>
  <rect x="11" y="11" width="4" height="2" fill="{DORADO}"/>
"""))

    # Advertencia / Alerta / Recurso crítico
    write_svg("alerta.svg", svg_wrap(16, 16, f"""
  <!-- Triángulo de advertencia -->
  <polygon points="8,1 15,14 1,14" fill="{AMBAR}" stroke="{GRIS_OSCURO}" stroke-width="1"/>
  <rect x="7" y="5" width="2" height="4" fill="{GRIS_OSCURO}"/>
  <rect x="7" y="11" width="2" height="2" fill="{GRIS_OSCURO}"/>
"""))

    # Era / Emblema histórico
    write_svg("era.svg", svg_wrap(16, 16, f"""
  <!-- Reloj de arena estilizado -->
  <rect x="4" y="2" width="8" height="2" fill="{DORADO}"/>
  <rect x="4" y="12" width="8" height="2" fill="{DORADO}"/>
  <polygon points="5,4 11,4 8,8" fill="{DORADO_CLARO}"/>
  <polygon points="5,12 11,12 8,8" fill="{DORADO_OSCURO}"/>
"""))

    # =========================================================================
    # 4. MODOS CENITALES Y HERRAMIENTAS
    # =========================================================================

    # Modo Ver: Cursor de flecha de selección
    write_svg("modo_ver.svg", svg_wrap(24, 24, f"""
  <polygon points="4,2 4,18 9,13 13,21 16,19 12,12 19,12" fill="{DORADO}" stroke="{GRIS_OSCURO}" stroke-width="1.5"/>
"""))

    # Modo Construir: Martillo y paleta de albañil
    write_svg("modo_construir.svg", svg_wrap(24, 24, f"""
  <!-- Paleta -->
  <polygon points="12,12 20,4 17,1 9,9" fill="{ACERO_BRILLO}"/>
  <rect x="6" y="12" width="5" height="2" fill="{MARRON_MADERA}"/>
  <!-- Martillo -->
  <rect x="4" y="4" width="7" height="4" fill="{HIERRO}"/>
  <rect x="7" y="7" width="2" height="12" fill="{MARRON_CORTEZA}"/>
"""))

    # Modo Zonificar: Cuadrícula dividida en sectores de color
    write_svg("modo_zonificar.svg", svg_wrap(24, 24, f"""
  <rect x="3" y="3" width="8" height="8" fill="{AZUL_AGUA}"/>
  <rect x="13" y="3" width="8" height="8" fill="{VALIDO_VERDE}"/>
  <rect x="3" y="13" width="8" height="8" fill="{AMBAR}"/>
  <rect x="13" y="13" width="8" height="8" fill="{DORADO}"/>
  <!-- Líneas de cuadrícula -->
  <rect x="11" y="2" width="2" height="20" fill="{GRIS_OSCURO}"/>
  <rect x="2" y="11" width="20" height="2" fill="{GRIS_OSCURO}"/>
"""))

    # Modo Demoler: Mazo pesado
    write_svg("modo_demoler.svg", svg_wrap(24, 24, f"""
  <!-- Cabeza de mazo -->
  <rect x="11" y="3" width="9" height="7" fill="{HIERRO}"/>
  <rect x="10" y="4" width="11" height="5" fill="{HIERRO}"/>
  <!-- Mango largo -->
  <line x1="12" y1="9" x2="3" y2="20" stroke="{MARRON_CORTEZA}" stroke-width="3"/>
"""))

    # Categorías de construcción:
    # Residencial: Casa con chimenea
    write_svg("cat_residencial.svg", svg_wrap(24, 24, f"""
  <polygon points="12,3 2,12 22,12" fill="{MARRON_MADERA}"/>
  <rect x="5" y="12" width="14" height="9" fill="#D7CCC8"/>
  <rect x="10" y="15" width="4" height="6" fill="{MARRON_CORTEZA}"/>
  <rect x="16" y="4" width="3" height="5" fill="{HIERRO}"/>
"""))

    # Periférico: Pico, hacha y hoja
    write_svg("cat_periferico.svg", svg_wrap(24, 24, f"""
  <!-- Pico curvo -->
  <path d="M4 6 Q12 2 20 6" stroke="{HIERRO}" stroke-width="3" fill="none"/>
  <rect x="11" y="6" width="2" height="14" fill="{MARRON_CORTEZA}"/>
  <!-- Hoja verde -->
  <circle cx="16" cy="14" r="4" fill="{VALIDO_VERDE}"/>
"""))

    # Industrial: Fábrica con chimeneas y engranaje
    write_svg("cat_industrial.svg", svg_wrap(24, 24, f"""
  <!-- Chimeneas -->
  <rect x="5" y="4" width="3" height="8" fill="{GRIS_MEDIO}"/>
  <rect x="10" y="6" width="3" height="6" fill="{GRIS_MEDIO}"/>
  <!-- Nave industrial -->
  <polygon points="3,12 8,9 8,12 14,9 14,20 3,20" fill="{HIERRO}"/>
  <!-- Engranaje -->
  <circle cx="17" cy="16" r="4" fill="{DORADO}"/>
  <circle cx="17" cy="16" r="1.5" fill="{GRIS_OSCURO}"/>
"""))

    # Investigación: Microscopio con libro
    write_svg("cat_investigacion.svg", svg_wrap(24, 24, f"""
  <!-- Microscopio -->
  <rect x="8" y="4" width="3" height="8" fill="{ACERO_BRILLO}"/>
  <rect x="6" y="12" width="7" height="2" fill="{HIERRO}"/>
  <path d="M11 7 Q16 10 13 16" stroke="{HIERRO}" stroke-width="2" fill="none"/>
  <rect x="6" y="18" width="12" height="3" fill="{GRIS_OSCURO}"/>
"""))

    # Vías: Cuadrícula con carretera de borde a borde
    write_svg("cat_vias.svg", svg_wrap(24, 24, f"""
  <rect x="2" y="2" width="20" height="20" fill="{MARRON_TIERRA}"/>
  <!-- Carretera diagonal o central -->
  <polygon points="8,2 16,2 16,22 8,22" fill="{GRIS_MEDIO}"/>
  <line x1="12" y1="4" x2="12" y2="20" stroke="{TEXTO_CREMA}" stroke-width="1" stroke-dasharray="2,2"/>
"""))

    # Ductos: Tubería con brida y válvula
    write_svg("cat_ductos.svg", svg_wrap(24, 24, f"""
  <rect x="2" y="9" width="20" height="6" fill="{HIERRO}"/>
  <rect x="5" y="7" width="2" height="10" fill="{ACERO_BRILLO}"/>
  <rect x="17" y="7" width="2" height="10" fill="{ACERO_BRILLO}"/>
  <!-- Válvula central -->
  <circle cx="11" cy="6" r="3" fill="{INVALIDO_ROJO}"/>
  <rect x="10" y="6" width="2" height="4" fill="{DORADO}"/>
"""))

    # Zonas
    write_svg("zona_residencial.svg", svg_wrap(20, 20, f"""
  <rect x="2" y="2" width="16" height="16" fill="{AZUL_AGUA}" opacity="0.4"/>
  <rect x="2" y="2" width="16" height="16" fill="none" stroke="{AZUL_AGUA}" stroke-width="2"/>
  <!-- Mini casita -->
  <polygon points="10,5 5,9 15,9" fill="{TEXTO_CREMA}"/>
  <rect x="6" y="9" width="8" height="6" fill="{TEXTO_CREMA}"/>
"""))

    write_svg("zona_industrial.svg", svg_wrap(20, 20, f"""
  <rect x="2" y="2" width="16" height="16" fill="{AMBAR}" opacity="0.4"/>
  <rect x="2" y="2" width="16" height="16" fill="none" stroke="{AMBAR}" stroke-width="2"/>
  <!-- Mini engranaje -->
  <rect x="7" y="7" width="6" height="6" fill="{TEXTO_CREMA}"/>
  <rect x="9" y="5" width="2" height="10" fill="{TEXTO_CREMA}"/>
  <rect x="5" y="9" width="10" height="2" fill="{TEXTO_CREMA}"/>
"""))

    write_svg("zona_borrar.svg", svg_wrap(20, 20, f"""
  <rect x="2" y="2" width="16" height="16" fill="{INVALIDO_ROJO}" opacity="0.3"/>
  <rect x="2" y="2" width="16" height="16" fill="none" stroke="{INVALIDO_ROJO}" stroke-width="2" stroke-dasharray="3,3"/>
  <!-- Aspa -->
  <line x1="5" y1="5" x2="15" y2="15" stroke="{INVALIDO_ROJO}" stroke-width="2"/>
  <line x1="15" y1="5" x2="5" y2="15" stroke="{INVALIDO_ROJO}" stroke-width="2"/>
"""))

    # =========================================================================
    # 5. PRIMERA PERSONA, LÁMPARA Y ACCIONES
    # =========================================================================

    # Bombilla encendida y apagada
    write_svg("lampara_electrica_on.svg", svg_wrap(16, 16, f"""
  <circle cx="8" cy="7" r="5" fill="{DORADO_CLARO}"/>
  <rect x="6" y="12" width="4" height="3" fill="{GRIS_MEDIO}"/>
  <!-- Rayos de luz -->
  <line x1="8" y1="0" x2="8" y2="2" stroke="{DORADO}" stroke-width="1.5"/>
  <line x1="2" y1="7" x2="0" y2="7" stroke="{DORADO}" stroke-width="1.5"/>
  <line x1="14" y1="7" x2="16" y2="7" stroke="{DORADO}" stroke-width="1.5"/>
"""))

    write_svg("lampara_electrica_off.svg", svg_wrap(16, 16, f"""
  <circle cx="8" cy="7" r="5" fill="{GRIS_OSCURO}"/>
  <rect x="6" y="12" width="4" height="3" fill="{GRIS_MEDIO}"/>
"""))

    # Farol térmico encendido y apagado
    write_svg("lampara_termica_on.svg", svg_wrap(16, 16, f"""
  <!-- Asa y tapa -->
  <path d="M5 4 Q8 1 11 4" stroke="{DORADO}" stroke-width="1" fill="none"/>
  <rect x="4" y="4" width="8" height="2" fill="{DORADO_OSCURO}"/>
  <!-- Vidrio y llama -->
  <rect x="4" y="6" width="8" height="7" fill="{AMBAR}" opacity="0.6"/>
  <polygon points="8,7 6,11 10,11" fill="{DORADO_CLARO}"/>
  <!-- Base -->
  <rect x="4" y="13" width="8" height="2" fill="{DORADO_OSCURO}"/>
"""))

    write_svg("lampara_termica_off.svg", svg_wrap(16, 16, f"""
  <path d="M5 4 Q8 1 11 4" stroke="{GRIS_MEDIO}" stroke-width="1" fill="none"/>
  <rect x="4" y="4" width="8" height="2" fill="{GRIS_OSCURO}"/>
  <rect x="4" y="6" width="8" height="7" fill="{GRIS_MEDIO}" opacity="0.4"/>
  <rect x="4" y="13" width="8" height="2" fill="{GRIS_OSCURO}"/>
"""))

    # Batería
    write_svg("bateria.svg", svg_wrap(16, 16, f"""
  <rect x="2" y="5" width="11" height="7" fill="{GRIS_OSCURO}"/>
  <rect x="3" y="6" width="9" height="5" fill="{VALIDO_VERDE}"/>
  <rect x="13" y="7" width="2" height="3" fill="{GRIS_MEDIO}"/>
"""))

    # Reloj de arena
    write_svg("reloj_arena.svg", svg_wrap(16, 16, f"""
  <rect x="3" y="2" width="10" height="2" fill="{DORADO}"/>
  <rect x="3" y="12" width="10" height="2" fill="{DORADO}"/>
  <polygon points="4,4 12,4 8,8" fill="{DORADO_CLARO}"/>
  <polygon points="4,12 12,12 8,8" fill="{DORADO_OSCURO}"/>
"""))

    # Oxígeno (burbujas ascendentes)
    write_svg("oxigeno.svg", svg_wrap(16, 16, f"""
  <circle cx="9" cy="11" r="3" fill="{AZUL_CIAN}"/>
  <circle cx="5" cy="6" r="2" fill="{AZUL_CIAN}"/>
  <circle cx="11" cy="4" r="1.5" fill="{AZUL_CIAN}"/>
"""))

    # Herramientas contextuales para barra de progreso (20x20)
    write_svg("herr_pico.svg", svg_wrap(20, 20, f"""
  <path d="M4 6 Q10 2 16 6" stroke="{HIERRO}" stroke-width="3" fill="none"/>
  <line x1="10" y1="5" x2="10" y2="18" stroke="{MARRON_CORTEZA}" stroke-width="2.5"/>
"""))

    write_svg("herr_pala.svg", svg_wrap(20, 20, f"""
  <rect x="7" y="11" width="6" height="6" fill="{HIERRO}"/>
  <line x1="10" y1="3" x2="10" y2="11" stroke="{MARRON_CORTEZA}" stroke-width="2"/>
  <rect x="8" y="2" width="4" height="2" fill="{MARRON_MADERA}"/>
"""))

    write_svg("herr_hacha.svg", svg_wrap(20, 20, f"""
  <line x1="8" y1="3" x2="8" y2="18" stroke="{MARRON_CORTEZA}" stroke-width="2.5"/>
  <path d="M8 5 L15 3 L15 11 L8 9 Z" fill="{ACERO_BRILLO}"/>
"""))

    write_svg("herr_cesta.svg", svg_wrap(20, 20, f"""
  <rect x="4" y="8" width="12" height="8" fill="{MARRON_MADERA}"/>
  <path d="M6 8 Q10 2 14 8" stroke="{MARRON_CORTEZA}" stroke-width="2" fill="none"/>
"""))

    write_svg("herr_mazo.svg", svg_wrap(20, 20, f"""
  <rect x="10" y="3" width="8" height="6" fill="{HIERRO}"/>
  <line x1="10" y1="7" x2="3" y2="17" stroke="{MARRON_CORTEZA}" stroke-width="2.5"/>
"""))

    write_svg("herr_vias.svg", svg_wrap(20, 20, f"""
  <line x1="3" y1="17" x2="17" y2="3" stroke="{GRIS_MEDIO}" stroke-width="4"/>
  <line x1="4" y1="9" x2="11" y2="16" stroke="{DORADO}" stroke-width="2"/>
"""))

    # =========================================================================
    # 6. PANEL CONTEXTUAL Y NAVEGACIÓN
    # =========================================================================

    write_svg("mouse_move.svg", svg_wrap(16, 16, f"""
  <!-- Silueta de ratón -->
  <rect x="5" y="3" width="6" height="10" rx="3" fill="{TEXTO_CREMA}" stroke="{GRIS_OSCURO}" stroke-width="1"/>
  <line x1="8" y1="3" x2="8" y2="7" stroke="{GRIS_OSCURO}" stroke-width="1"/>
  <!-- Flechas laterales -->
  <polygon points="2,8 4,6 4,10" fill="{DORADO}"/>
  <polygon points="14,8 12,6 12,10" fill="{DORADO}"/>
"""))

    # Check verde y Cruz roja
    write_svg("check.svg", svg_wrap(16, 16, f"""
  <circle cx="8" cy="8" r="7" fill="{VALIDO_VERDE}"/>
  <path d="M4 8 L7 11 L12 5" stroke="{BLANCO}" stroke-width="2" fill="none"/>
"""))

    write_svg("cruz.svg", svg_wrap(16, 16, f"""
  <circle cx="8" cy="8" r="7" fill="{INVALIDO_ROJO}"/>
  <line x1="5" y1="5" x2="11" y2="11" stroke="{BLANCO}" stroke-width="2"/>
  <line x1="11" y1="5" x2="5" y2="11" stroke="{BLANCO}" stroke-width="2"/>
"""))

    # Brújula (distancia al núcleo)
    write_svg("brujula.svg", svg_wrap(16, 16, f"""
  <circle cx="8" cy="8" r="7" fill="{DORADO}" stroke="{GRIS_OSCURO}" stroke-width="1"/>
  <circle cx="8" cy="8" r="5" fill="{TEXTO_CREMA}"/>
  <!-- Aguja norte (roja) / sur (azul) -->
  <polygon points="8,3 6,8 8,7 10,8" fill="{INVALIDO_ROJO}"/>
  <polygon points="8,13 6,8 8,9 10,8" fill="{AZUL_AGUA}"/>
"""))

    # Baúl
    write_svg("baul.svg", svg_wrap(16, 16, f"""
  <rect x="2" y="5" width="12" height="8" fill="{MARRON_MADERA}"/>
  <rect x="2" y="3" width="12" height="3" fill="{MARRON_CORTEZA}"/>
  <rect x="7" y="6" width="2" height="3" fill="{DORADO}"/>
"""))

    # =========================================================================
    # 7. VENTANAS GLOBALES Y PANELES
    # =========================================================================

    # Ojo (enfocar cámara)
    write_svg("ojo.svg", svg_wrap(16, 16, f"""
  <ellipse cx="8" cy="8" rx="7" ry="4" fill="{TEXTO_CREMA}" stroke="{GRIS_OSCURO}" stroke-width="1"/>
  <circle cx="8" cy="8" r="3" fill="{AZUL_AGUA}"/>
  <circle cx="8" cy="8" r="1.5" fill="{GRIS_OSCURO}"/>
"""))

    # Edificio con engranaje (Ocupaciones / Industria)
    write_svg("edificio_engranaje.svg", svg_wrap(16, 16, f"""
  <rect x="2" y="4" width="8" height="10" fill="{HIERRO}"/>
  <circle cx="11" cy="9" r="4" fill="{DORADO}"/>
  <circle cx="11" cy="9" r="1.5" fill="{GRIS_OSCURO}"/>
"""))

    # Corazón cívico (Moral)
    write_svg("corazon_civico.svg", svg_wrap(16, 16, f"""
  <path d="M8 14 L2 8 Q0 4 4 2 Q7 2 8 5 Q9 2 12 2 Q16 4 14 8 Z" fill="{INVALIDO_ROJO}" stroke="{DORADO}" stroke-width="1"/>
"""))

    # Productividad (engranaje con martillo)
    write_svg("productividad.svg", svg_wrap(16, 16, f"""
  <circle cx="8" cy="8" r="6" fill="{DORADO}"/>
  <circle cx="8" cy="8" r="3" fill="{GRIS_OSCURO}"/>
  <rect x="7" y="1" width="2" height="14" fill="{DORADO}"/>
  <rect x="1" y="7" width="14" height="2" fill="{DORADO}"/>
  <line x1="3" y1="13" x2="12" y2="4" stroke="{ACERO_BRILLO}" stroke-width="2"/>
"""))

    # Balanza (equilibrio moral)
    write_svg("balanza.svg", svg_wrap(16, 16, f"""
  <line x1="8" y1="2" x2="8" y2="14" stroke="{DORADO}" stroke-width="1.5"/>
  <line x1="3" y1="4" x2="13" y2="4" stroke="{DORADO}" stroke-width="1.5"/>
  <polygon points="2,8 5,8 3.5,5" fill="{DORADO_CLARO}"/>
  <polygon points="11,8 14,8 12.5,5" fill="{DORADO_CLARO}"/>
  <rect x="5" y="13" width="6" height="2" fill="{DORADO}"/>
"""))

    # Cornucopia llena y vacía
    write_svg("cornucopia_llena.svg", svg_wrap(16, 16, f"""
  <path d="M2 13 Q7 13 10 9 Q14 4 15 2" stroke="{MARRON_MADERA}" stroke-width="3" fill="none"/>
  <!-- Frutas rebosantes -->
  <circle cx="3" cy="11" r="2.5" fill="{INVALIDO_ROJO}"/>
  <circle cx="6" cy="10" r="2.5" fill="{AMBAR}"/>
  <circle cx="5" cy="13" r="2" fill="{VALIDO_VERDE}"/>
"""))

    write_svg("cornucopia_vacia.svg", svg_wrap(16, 16, f"""
  <path d="M2 13 Q7 13 10 9 Q14 4 15 2" stroke="{GRIS_MEDIO}" stroke-width="3" fill="none"/>
"""))

    # Escudo agrietado (peligrosidad)
    write_svg("escudo_agrietado.svg", svg_wrap(16, 16, f"""
  <path d="M3 2 L13 2 L13 8 Q13 13 8 15 Q3 13 3 8 Z" fill="{HIERRO}"/>
  <!-- Grieta central -->
  <path d="M8 3 L7 7 L9 10 L8 14" stroke="{INVALIDO_ROJO}" stroke-width="1.5" fill="none"/>
"""))

    # Enchufes para red eléctrica (conectado verde / desconectado rojo)
    write_svg("enchufe_verde.svg", svg_wrap(16, 16, f"""
  <rect x="4" y="6" width="8" height="6" fill="{VALIDO_VERDE}"/>
  <rect x="5" y="3" width="2" height="3" fill="{TEXTO_CREMA}"/>
  <rect x="9" y="3" width="2" height="3" fill="{TEXTO_CREMA}"/>
  <rect x="7" y="12" width="2" height="3" fill="{VALIDO_VERDE}"/>
"""))

    write_svg("enchufe_rojo.svg", svg_wrap(16, 16, f"""
  <rect x="4" y="6" width="8" height="6" fill="{INVALIDO_ROJO}"/>
  <rect x="5" y="3" width="2" height="3" fill="{TEXTO_CREMA}"/>
  <rect x="9" y="3" width="2" height="3" fill="{TEXTO_CREMA}"/>
  <line x1="2" y1="2" x2="14" y2="14" stroke="{INVALIDO_ROJO}" stroke-width="1.5"/>
"""))

    # Central Termoeléctrica estilizada
    write_svg("central_termoelectrica.svg", svg_wrap(16, 16, f"""
  <rect x="3" y="7" width="10" height="7" fill="{HIERRO}"/>
  <rect x="4" y="3" width="3" height="4" fill="{GRIS_MEDIO}"/>
  <rect x="9" y="3" width="3" height="4" fill="{GRIS_MEDIO}"/>
  <path d="M8 8 L6 11 L9 11 L7 13" stroke="{DORADO}" stroke-width="1" fill="none"/>
"""))

    # Ayuntamiento (Núcleo Urbano)
    write_svg("ayuntamiento.svg", svg_wrap(16, 16, f"""
  <!-- Columnas y frontón -->
  <polygon points="8,1 2,5 14,5" fill="{DORADO}"/>
  <rect x="3" y="5" width="2" height="7" fill="{TEXTO_CREMA}"/>
  <rect x="7" y="5" width="2" height="7" fill="{TEXTO_CREMA}"/>
  <rect x="11" y="5" width="2" height="7" fill="{TEXTO_CREMA}"/>
  <rect x="2" y="12" width="12" height="2" fill="{DORADO}"/>
"""))

    # Asignar núcleo (ayuntamiento con flecha verde)
    write_svg("asignar_nucleo.svg", svg_wrap(16, 16, f"""
  <polygon points="8,1 2,5 14,5" fill="{DORADO}"/>
  <rect x="3" y="5" width="2" height="7" fill="{TEXTO_CREMA}"/>
  <rect x="7" y="5" width="2" height="7" fill="{TEXTO_CREMA}"/>
  <rect x="11" y="5" width="2" height="7" fill="{TEXTO_CREMA}"/>
  <rect x="2" y="12" width="12" height="2" fill="{DORADO}"/>
  <!-- Flecha verde entrando -->
  <polygon points="12,12 16,12 14,8" fill="{VALIDO_VERDE}"/>
  <rect x="13" y="12" width="2" height="3" fill="{VALIDO_VERDE}"/>
"""))

    # Estados de colonizable
    write_svg("puerta_abierta.svg", svg_wrap(16, 16, f"""
  <rect x="3" y="2" width="10" height="12" fill="{MARRON_CORTEZA}"/>
  <polygon points="3,3 9,4 9,13 3,14" fill="{MARRON_MADERA}"/>
  <!-- Flecha verde -->
  <polygon points="11,8 15,8 13,5" fill="{VALIDO_VERDE}"/>
"""))

    write_svg("puerta_candado.svg", svg_wrap(16, 16, f"""
  <rect x="3" y="2" width="10" height="12" fill="{MARRON_CORTEZA}"/>
  <rect x="4" y="3" width="8" height="10" fill="{MARRON_MADERA}"/>
  <!-- Candado dorado -->
  <rect x="6" y="7" width="4" height="4" fill="{DORADO}"/>
  <path d="M7 7 L7 5 Q8 4 9 5 L9 7" stroke="{DORADO}" stroke-width="1" fill="none"/>
"""))

    write_svg("puerta_reloj.svg", svg_wrap(16, 16, f"""
  <rect x="3" y="2" width="10" height="12" fill="{MARRON_CORTEZA}"/>
  <rect x="4" y="3" width="8" height="10" fill="{MARRON_MADERA}"/>
  <!-- Reloj miniatura -->
  <circle cx="8" cy="8" r="3" fill="{AMBAR}"/>
  <line x1="8" y1="6" x2="8" y2="8" stroke="#000" stroke-width="0.8"/>
  <line x1="8" y1="8" x2="9" y2="8" stroke="#000" stroke-width="0.8"/>
"""))

    # Candado dorado
    write_svg("candado.svg", svg_wrap(16, 16, f"""
  <rect x="4" y="7" width="8" height="7" fill="{DORADO}"/>
  <path d="M6 7 L6 4 Q8 2 10 4 L10 7" stroke="{DORADO}" stroke-width="1.5" fill="none"/>
  <circle cx="8" cy="10" r="1" fill="{GRIS_OSCURO}"/>
"""))

    # Remodelar: Llave inglesa con martillo
    write_svg("remodelar.svg", svg_wrap(16, 16, f"""
  <line x1="3" y1="13" x2="11" y2="5" stroke="{HIERRO}" stroke-width="2"/>
  <line x1="13" y1="13" x2="5" y2="5" stroke="{ACERO_BRILLO}" stroke-width="2"/>
  <rect x="2" y="3" width="4" height="3" fill="{HIERRO}"/>
"""))

    # Prioridades (Chevrones azul, verde, dorado)
    write_svg("prio_baja.svg", svg_wrap(16, 16, f"""
  <!-- Un chevrón azul ▲ -->
  <polygon points="8,5 4,11 12,11" fill="{AZUL_AGUA}"/>
"""))

    write_svg("prio_normal.svg", svg_wrap(16, 16, f"""
  <!-- Dos chevrones verdes ▲▲ -->
  <polygon points="8,2 4,7 12,7" fill="{VALIDO_VERDE}"/>
  <polygon points="8,8 4,13 12,13" fill="{VALIDO_VERDE}"/>
"""))

    write_svg("prio_alta.svg", svg_wrap(16, 16, f"""
  <!-- Tres chevrones dorados ▲▲▲ -->
  <polygon points="8,1 5,5 11,5" fill="{DORADO}"/>
  <polygon points="8,6 5,10 11,10" fill="{DORADO}"/>
  <polygon points="8,11 5,15 11,15" fill="{DORADO}"/>
"""))

    # Tecnologías de Universidad
    write_svg("tec_metalurgia.svg", svg_wrap(16, 16, f"""
  <!-- Yunque -->
  <rect x="2" y="4" width="12" height="4" fill="{HIERRO}"/>
  <polygon points="2,4 0,4 2,6" fill="{HIERRO}"/>
  <rect x="6" y="8" width="4" height="3" fill="{HIERRO}"/>
  <rect x="4" y="11" width="8" height="2" fill="{HIERRO}"/>
"""))

    write_svg("tec_automatizacion.svg", svg_wrap(16, 16, f"""
  <!-- Brazo robótico -->
  <rect x="2" y="12" width="6" height="3" fill="{HIERRO}"/>
  <line x1="5" y1="12" x2="10" y2="7" stroke="{ACERO_BRILLO}" stroke-width="2"/>
  <circle cx="10" cy="7" r="2" fill="{DORADO}"/>
  <line x1="10" y1="7" x2="14" y2="4" stroke="{ACERO_BRILLO}" stroke-width="1.5"/>
  <rect x="13" y="3" width="2" height="2" fill="{INVALIDO_ROJO}"/>
"""))

    # Símbolos de Botones (+, -, Pausa, Play, Cancelar, Extraer todo)
    write_svg("btn_mas.svg", svg_wrap(14, 14, f"""
  <rect x="6" y="2" width="2" height="10" fill="{TEXTO_CREMA}"/>
  <rect x="2" y="6" width="10" height="2" fill="{TEXTO_CREMA}"/>
"""))

    write_svg("btn_menos.svg", svg_wrap(14, 14, f"""
  <rect x="2" y="6" width="10" height="2" fill="{TEXTO_CREMA}"/>
"""))

    write_svg("btn_pausa.svg", svg_wrap(14, 14, f"""
  <rect x="3" y="2" width="3" height="10" fill="{TEXTO_CREMA}"/>
  <rect x="8" y="2" width="3" height="10" fill="{TEXTO_CREMA}"/>
"""))

    write_svg("btn_play.svg", svg_wrap(14, 14, f"""
  <polygon points="3,2 12,7 3,12" fill="{TEXTO_CREMA}"/>
"""))

    write_svg("extraer_todo.svg", svg_wrap(16, 16, f"""
  <rect x="2" y="6" width="9" height="7" fill="{MARRON_MADERA}"/>
  <rect x="2" y="4" width="9" height="2" fill="{MARRON_CORTEZA}"/>
  <!-- Flecha hacia afuera -->
  <polygon points="13,3 16,6 10,6" fill="{VALIDO_VERDE}"/>
  <line x1="13" y1="6" x2="13" y2="11" stroke="{VALIDO_VERDE}" stroke-width="2"/>
"""))

    # LEDs de estado industrial (8x8)
    write_svg("led_verde.svg", svg_wrap(8, 8, f"""
  <circle cx="4" cy="4" r="3.5" fill="{VALIDO_VERDE}"/>
  <circle cx="3" cy="3" r="1" fill="{BLANCO}"/>
"""))

    write_svg("led_gris.svg", svg_wrap(8, 8, f"""
  <circle cx="4" cy="4" r="3.5" fill="{GRIS_MEDIO}"/>
"""))

    write_svg("led_rojo.svg", svg_wrap(8, 8, f"""
  <circle cx="4" cy="4" r="3.5" fill="{INVALIDO_ROJO}"/>
  <circle cx="3" cy="3" r="1" fill="{BLANCO}"/>
"""))

    print("Generación de SVGs completada con éxito.")

if __name__ == "__main__":
    generate_icons()
