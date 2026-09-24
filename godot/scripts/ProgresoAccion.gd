extends RefCounted

## Avance de una acción sostenida del avatar (minar un bloque, talar, recolectar
## frutos) con reinicio, como Minecraft: si se suelta o se cambia de objetivo,
## el avance vuelve a 0. Puro y sin escena (mismo patrón que
## GeneradorArbol.gd); Player.gd lo usa y HUD.gd dibuja la barra. Sin
## class_name: se usa vía preload().new().

var _clave := ""
var _acumulado := 0.0
var _duracion := 1.0


## Suma "delta" segundos al avance sobre "clave" (p. ej. "celda:(1, 2, 3)" o
## "arbol:7"). Si la clave cambió, empieza de cero. Devuelve true al completarse
## "duracion" y reinicia el acumulado (la clave se conserva, para seguir con el
## mismo árbol).
func avanzar(clave: String, duracion: float, delta: float) -> bool:
	if clave != _clave:
		_clave = clave
		_acumulado = 0.0
	_duracion = duracion
	_acumulado += delta
	if _acumulado >= _duracion:
		_acumulado = 0.0
		return true
	return false


## Se soltó el clic o ya no hay objetivo: el avance se pierde.
func soltar() -> void:
	_clave = ""
	_acumulado = 0.0


## Avance actual entre 0 y 1.
func fraccion() -> float:
	if _duracion <= 0.0:
		return 0.0
	return clampf(_acumulado / _duracion, 0.0, 1.0)
