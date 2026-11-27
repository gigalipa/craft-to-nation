extends RefCounted

## Catálogo ordenado de los 4 actos y 18 hitos narrativos de la Campaña-Tutorial
## («La Fractura Multiversal»). Ver docs/historia_narrativa_campana.md.

const PASOS: Array[Dictionary] = [
	{
		"id": "A1_01", "acto": 1, "acto_key": "CAMPANA_ACTO_1", "voz_key": "CAMPANA_VOZ_A1_01",
		"obj_key": "CAMPANA_OBJ_A1_01", "guia_key": "CAMPANA_GUIA_A1_01",
		"hitos": ["CAMPANA_HITO_A1_01_1", "CAMPANA_HITO_A1_01_2", "CAMPANA_HITO_A1_01_3", "CAMPANA_HITO_A1_01_4"],
	},
	{
		"id": "A1_02", "acto": 1, "acto_key": "CAMPANA_ACTO_1", "voz_key": "CAMPANA_VOZ_A1_02",
		"obj_key": "CAMPANA_OBJ_A1_02", "guia_key": "CAMPANA_GUIA_A1_02",
		"hitos": ["CAMPANA_HITO_A1_02_1", "CAMPANA_HITO_A1_02_2", "CAMPANA_HITO_A1_02_3", "CAMPANA_HITO_A1_02_4", "CAMPANA_HITO_A1_02_5"],
	},
	{
		"id": "A1_03", "acto": 1, "acto_key": "CAMPANA_ACTO_1", "voz_key": "CAMPANA_VOZ_A1_03",
		"obj_key": "CAMPANA_OBJ_A1_03", "guia_key": "CAMPANA_GUIA_A1_03",
		"hitos": ["CAMPANA_HITO_A1_03_1", "CAMPANA_HITO_A1_03_2"],
	},
	{
		"id": "A1_04", "acto": 1, "acto_key": "CAMPANA_ACTO_1", "voz_key": "CAMPANA_VOZ_A1_04",
		"obj_key": "CAMPANA_OBJ_A1_04", "guia_key": "CAMPANA_GUIA_A1_04",
		"hitos": [],
	},
	{
		"id": "A2_01", "acto": 2, "acto_key": "CAMPANA_ACTO_2", "voz_key": "CAMPANA_VOZ_A2_01",
		"obj_key": "CAMPANA_OBJ_A2_01", "guia_key": "CAMPANA_GUIA_A2_01",
		"hitos": ["CAMPANA_HITO_A2_01_1"],
	},
	{
		"id": "A2_02", "acto": 2, "acto_key": "CAMPANA_ACTO_2", "voz_key": "CAMPANA_VOZ_A2_02",
		"obj_key": "CAMPANA_OBJ_A2_02", "guia_key": "CAMPANA_GUIA_A2_02",
		"hitos": ["CAMPANA_HITO_A2_02_1"],
	},
	{
		"id": "A2_03", "acto": 2, "acto_key": "CAMPANA_ACTO_2", "voz_key": "CAMPANA_VOZ_A2_03",
		"obj_key": "CAMPANA_OBJ_A2_03", "guia_key": "CAMPANA_GUIA_A2_03",
		"hitos": ["CAMPANA_HITO_A2_03_1", "CAMPANA_HITO_A2_03_2"],
	},
	{
		"id": "A2_04", "acto": 2, "acto_key": "CAMPANA_ACTO_2", "voz_key": "CAMPANA_VOZ_A2_04",
		"obj_key": "CAMPANA_OBJ_A2_04", "guia_key": "CAMPANA_GUIA_A2_04",
		"hitos": [],
	},
	{
		"id": "A3_01", "acto": 3, "acto_key": "CAMPANA_ACTO_3", "voz_key": "CAMPANA_VOZ_A3_01",
		"obj_key": "CAMPANA_OBJ_A3_01", "guia_key": "CAMPANA_GUIA_A3_01",
		"hitos": ["CAMPANA_HITO_A3_01_1", "CAMPANA_HITO_A3_01_2"],
	},
	{
		"id": "A3_02", "acto": 3, "acto_key": "CAMPANA_ACTO_3", "voz_key": "CAMPANA_VOZ_A3_02",
		"obj_key": "CAMPANA_OBJ_A3_02", "guia_key": "CAMPANA_GUIA_A3_02",
		"hitos": ["CAMPANA_HITO_A3_02_1", "CAMPANA_HITO_A3_02_2"],
	},
	{
		"id": "A3_03", "acto": 3, "acto_key": "CAMPANA_ACTO_3", "voz_key": "CAMPANA_VOZ_A3_03",
		"obj_key": "CAMPANA_OBJ_A3_03", "guia_key": "CAMPANA_GUIA_A3_03",
		"hitos": ["CAMPANA_HITO_A3_03_1", "CAMPANA_HITO_A3_03_2", "CAMPANA_HITO_A3_03_3"],
	},
	{
		"id": "A3_04", "acto": 3, "acto_key": "CAMPANA_ACTO_3", "voz_key": "CAMPANA_VOZ_A3_04",
		"obj_key": "CAMPANA_OBJ_A3_04", "guia_key": "CAMPANA_GUIA_A3_04",
		"hitos": ["CAMPANA_HITO_A3_04_1"],
	},
	{
		"id": "A3_05", "acto": 3, "acto_key": "CAMPANA_ACTO_3", "voz_key": "CAMPANA_VOZ_A3_05",
		"obj_key": "CAMPANA_OBJ_A3_05", "guia_key": "CAMPANA_GUIA_A3_05",
		"hitos": [],
	},
	{
		"id": "A4_01", "acto": 4, "acto_key": "CAMPANA_ACTO_4", "voz_key": "CAMPANA_VOZ_A4_01",
		"obj_key": "CAMPANA_OBJ_A4_01", "guia_key": "CAMPANA_GUIA_A4_01",
		"hitos": ["CAMPANA_HITO_A4_01_1"],
	},
	{
		"id": "A4_02", "acto": 4, "acto_key": "CAMPANA_ACTO_4", "voz_key": "CAMPANA_VOZ_A4_02",
		"obj_key": "CAMPANA_OBJ_A4_02", "guia_key": "CAMPANA_GUIA_A4_02",
		"hitos": ["CAMPANA_HITO_A4_02_1"],
	},
	{
		"id": "A4_03", "acto": 4, "acto_key": "CAMPANA_ACTO_4", "voz_key": "CAMPANA_VOZ_A4_03",
		"obj_key": "CAMPANA_OBJ_A4_03", "guia_key": "CAMPANA_GUIA_A4_03",
		"hitos": ["CAMPANA_HITO_A4_03_1", "CAMPANA_HITO_A4_03_2"],
	},
	{
		"id": "A4_04", "acto": 4, "acto_key": "CAMPANA_ACTO_4", "voz_key": "CAMPANA_VOZ_A4_04",
		"obj_key": "CAMPANA_OBJ_A4_04", "guia_key": "CAMPANA_GUIA_A4_04",
		"hitos": ["CAMPANA_HITO_A4_04_1", "CAMPANA_HITO_A4_04_2", "CAMPANA_HITO_A4_04_3"],
	},
	{
		"id": "A4_05", "acto": 4, "acto_key": "CAMPANA_ACTO_4", "voz_key": "CAMPANA_VOZ_A4_05",
		"obj_key": "CAMPANA_OBJ_A4_05", "guia_key": "CAMPANA_GUIA_A4_05",
		"hitos": [],
	},
]


static func total_pasos() -> int:
	return PASOS.size()


static func indice_de_paso(id_paso: String) -> int:
	for i in range(PASOS.size()):
		if PASOS[i]["id"] == id_paso:
			return i
	return -1


static func obtener_paso(indice: int) -> Dictionary:
	if indice < 0 or indice >= PASOS.size():
		return {}
	return PASOS[indice]
