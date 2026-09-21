extends Node3D

## Dibuja a los colonos (una cápsula placeholder por colono) y les da un cuerpo
## físico para que el avatar no pueda atravesarlos. Toda la lógica vive en el
## autoload Colonos; esto solo refleja su estado. Las unidades definitivas
## (Quaternius/KayKit, GDD Sección 11) solo cambiarían la malla.
## ponytail: un MeshInstance3D + AnimatableBody3D por colono; pasar a
## MultiMesh si la población llega a miles.

const ALTURA_COLONO := 1.8
const RADIO_COLONO := 0.3

const COLORES_TIPO := {
	"ciudadano": Color(0.85, 0.85, 0.85),
	"desempleado": Color(0.75, 0.6, 0.4),
	"obrero": Color(0.9, 0.6, 0.2),
	"tecnico": Color(0.3, 0.6, 0.9),
	"especialista": Color(0.6, 0.4, 0.9),
	"investigador": Color(0.3, 0.8, 0.5),
	"militar": Color(0.8, 0.25, 0.25),
}

var _cuerpos: Dictionary = {}  # int (id de colono) -> AnimatableBody3D


func _ready() -> void:
	Colonos.colono_creado.connect(_on_colono_creado)
	Colonos.colono_retirado.connect(_on_colono_retirado)
	for id in Colonos.colonos:
		_on_colono_creado(id)


func _on_colono_creado(id: int) -> void:
	var tipo: String = Colonos.colonos[id]["tipo"]
	var cuerpo := AnimatableBody3D.new()
	# Capa 2: solo el avatar (Player.collision_mask = 3) choca con los colonos;
	# el raycast del jugador y el picking de CamaraCenital (máscara 1) los
	# atraviesan, así un clic sobre un colono elige el terreno de debajo.
	cuerpo.collision_layer = 2
	cuerpo.collision_mask = 0

	var malla := MeshInstance3D.new()
	var capsula := CapsuleMesh.new()
	capsula.radius = RADIO_COLONO
	capsula.height = ALTURA_COLONO
	var material := StandardMaterial3D.new()
	material.albedo_color = COLORES_TIPO.get(tipo, Color.WHITE)
	capsula.material = material
	malla.mesh = capsula
	malla.position = Vector3(0, ALTURA_COLONO / 2.0, 0)
	cuerpo.add_child(malla)

	var forma := CollisionShape3D.new()
	var capsula_fisica := CapsuleShape3D.new()
	capsula_fisica.radius = RADIO_COLONO
	capsula_fisica.height = ALTURA_COLONO
	forma.shape = capsula_fisica
	forma.position = Vector3(0, ALTURA_COLONO / 2.0, 0)
	cuerpo.add_child(forma)

	add_child(cuerpo)
	_cuerpos[id] = cuerpo
	cuerpo.global_position = Colonos.colonos[id]["posicion"]


func _on_colono_retirado(id: int) -> void:
	if _cuerpos.has(id):
		_cuerpos[id].queue_free()
		_cuerpos.erase(id)


func _physics_process(_delta: float) -> void:
	for id in _cuerpos:
		if Colonos.colonos.has(id):
			_cuerpos[id].global_position = Colonos.colonos[id]["posicion"]
