extends RefCounted

## Estilo común del HUD (verde oscuro con marco dorado, ver
## arte/conceptos-hud/). Solo estáticos: cada widget lo usa al construirse.

const VERDE := Color(0.05, 0.13, 0.10, 0.92)
const VERDE_CLARO := Color(0.13, 0.30, 0.21, 0.95)
const DORADO := Color(0.78, 0.62, 0.25)
const TEXTO := Color(0.95, 0.92, 0.82)
const VALIDO := Color(0.45, 0.90, 0.45)
const INVALIDO := Color(1.0, 0.35, 0.35)


static func caja(fondo: Color = VERDE, borde: Color = DORADO) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = fondo
	estilo.border_color = borde
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(4)
	estilo.set_content_margin_all(8)
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
