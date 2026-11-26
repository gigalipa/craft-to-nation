"""Prueba headless de separación de materiales de identidad en humanoides."""

from __future__ import annotations

import sys
from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))

from blender_identity_materials import apply_identity_materials  # noqa: E402


ASSETS = (
    ROOT / "godot/assets/personajes/base/cuerpo_m.glb",
    ROOT / "godot/assets/personajes/base/cuerpo_f.glb",
    ROOT / "godot/assets/personajes/atuendos/obrero_m.glb",
    ROOT / "godot/assets/personajes/atuendos/obrero_f.glb",
)


for asset in ASSETS:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(asset))
    meshes = [
        obj
        for obj in bpy.context.scene.objects
        if obj.type == "MESH"
        and obj.data.materials
        and not any(collection.name == "glTF_not_exported" for collection in obj.users_collection)
    ]
    assert len(meshes) == 1, f"{asset.name}: se esperaba una sola malla"
    summary = apply_identity_materials(meshes[0])
    total = summary["total_faces"]
    assert summary["base_faces"] > 0, f"{asset.name}: falta material base"
    assert 0 < summary["skin_faces"] < total * 0.60, f"{asset.name}: clasificación de piel inválida: {summary}"
    assert max(12, int(total * 0.002)) <= summary["team_faces"] < total * 0.10, (
        f"{asset.name}: el brazalete debe cubrir una franja visible: {summary}"
    )
    assert {mat.name for mat in meshes[0].data.materials} >= {
        "Material_0",
        "mat_piel",
        "mat_color_equipo",
    }

print("IDENTITY_MATERIALS_TEST_OK")
