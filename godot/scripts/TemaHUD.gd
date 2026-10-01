extends RefCounted

## Estilo común del HUD (verde oscuro con marco dorado, ver
## arte/conceptos-hud/). Solo estáticos: cada widget lo usa al construirse.

const VERDE := Color(0.05, 0.13, 0.10, 0.92)
const VERDE_CLARO := Color(0.13, 0.30, 0.21, 0.95)
const DORADO := Color(0.78, 0.62, 0.25)
const TEXTO := Color(0.95, 0.92, 0.82)
const VALIDO := Color(0.45, 0.90, 0.45)
const INVALIDO := Color(1.0, 0.35, 0.35)

## Margen (px) de los textos de esquina de un botón o casilla (acceso directo y disponibilidad, ver
## poner_en_esquina_inferior()): MARGEN_X va del borde lateral al primer/último carácter del texto,
## y MARGEN_Y, del borde inferior al pie del texto. Ajustar solo estos dos valores.
const MARGEN_X := 5.0
const MARGEN_Y := 2.0

## Margen interno del estilo de caja(): un PanelContainer lo reserva alrededor de sus hijos.
const MARGEN_CONTENIDO := 8


static func caja(fondo: Color = VERDE, borde: Color = DORADO) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = fondo
	estilo.border_color = borde
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(4)
	estilo.set_content_margin_all(MARGEN_CONTENIDO)
	return estilo


## Fondo del widget con marco dorado. No captura el ratón: los clics siguen
## llegando a la cámara salvo sobre los botones.
static func aplicar_panel(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override("panel", caja())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE


static func etiqueta(texto: String = "") -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_color_override("font_color", TEXTO)
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return etiqueta


static func estilizar_boton(boton: Button) -> void:
	boton.add_theme_stylebox_override("normal", caja())
	boton.add_theme_stylebox_override("hover", caja(VERDE_CLARO))
	boton.add_theme_stylebox_override("pressed", caja(VERDE_CLARO, Color(1.0, 0.8, 0.3)))
	boton.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	boton.add_theme_color_override("font_color", TEXTO)
	boton.add_theme_color_override("font_pressed_color", Color(1.0, 0.85, 0.4))
	boton.focus_mode = Control.FOCUS_NONE


## Ancla "etiqueta" a la esquina inferior izquierda (o derecha) de su padre, que debe ser un Control
## simple (un Container pisaría las anclas), a MARGEN_X / MARGEN_Y del marco. Crece hacia adentro,
## así que sirve para textos que cambian de ancho. Los márgenes se miden desde el borde exterior del
## marco; si el padre queda dentro del margen interno de un PanelContainer, pasar ese margen en "inset".
static func poner_en_esquina_inferior(etiqueta: Label, derecha: bool = false, inset: float = 0.0) -> void:
	var x: float = 1.0 if derecha else 0.0
	etiqueta.anchor_left = x
	etiqueta.anchor_right = x
	etiqueta.anchor_top = 1.0
	etiqueta.anchor_bottom = 1.0
	etiqueta.grow_horizontal = Control.GROW_DIRECTION_BEGIN if derecha else Control.GROW_DIRECTION_END
	etiqueta.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var mx: float = MARGEN_X - inset
	var my: float = MARGEN_Y - inset
	var lado: float = -mx if derecha else mx
	etiqueta.offset_left = lado
	etiqueta.offset_right = lado
	etiqueta.offset_top = -my
	etiqueta.offset_bottom = -my
