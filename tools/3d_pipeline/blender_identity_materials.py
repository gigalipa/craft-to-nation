"""Separa materiales de identidad sobre un humanoide de atlas único.

Conserva el material/textura original para ropa y asigna copias del mismo
material a polígonos de piel expuesta y al brazalete neutro. La clasificación
combina posición en T-Pose con el color medio del atlas; no duplica geometría.
"""

from __future__ import annotations

import argparse
import json
import sys
from array import array
from pathlib import Path

import bpy
from mathutils import Vector


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Separa mat_piel y mat_color_equipo en un GLB humanoide.")
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", type=Path)
    return parser.parse_args(argv)


def _source_image(material: bpy.types.Material) -> bpy.types.Image:
    if not material.use_nodes or material.node_tree is None:
        raise RuntimeError(f"El material {material.name} no usa nodos.")
    for node in material.node_tree.nodes:
        if node.type == "TEX_IMAGE" and node.image is not None:
            return node.image
    raise RuntimeError(f"El material {material.name} no contiene una textura de color.")


def _mean_uv_color(
    polygon: bpy.types.MeshPolygon,
    uv_data: bpy.types.MeshUVLoopLayer,
    pixels: array,
    width: int,
    height: int,
) -> tuple[float, float, float]:
    red = green = blue = 0.0
    samples = 0
    for loop_index in polygon.loop_indices:
        uv = uv_data[loop_index].uv
        x = min(width - 1, max(0, int((uv.x % 1.0) * width)))
        y = min(height - 1, max(0, int((uv.y % 1.0) * height)))
        index = (y * width + x) * 4
        red += pixels[index]
        green += pixels[index + 1]
        blue += pixels[index + 2]
        samples += 1
    divisor = float(max(1, samples))
    return red / divisor, green / divisor, blue / divisor


def _polygon_center(obj: bpy.types.Object, polygon: bpy.types.MeshPolygon) -> Vector:
    return obj.matrix_world @ polygon.center


def _is_skin(center: Vector, rgb: tuple[float, float, float]) -> bool:
    red, green, blue = rgb
    brightness = max(rgb)
    redness = red - green
    warm = red > green > blue * 0.82 and red - blue > 0.045
    skin_color = brightness > 0.22 and redness > 0.055 and warm
    on_head_or_neck = center.z > 1.40 and abs(center.x) < 0.24
    on_exposed_arm = center.z > 1.12 and abs(center.x) > 0.43
    return skin_color and (on_head_or_neck or on_exposed_arm)


def _team_band_axis(obj: bpy.types.Object) -> tuple[Vector, Vector, float]:
    armature = obj.find_armature()
    if armature is None:
        raise RuntimeError("La malla no está vinculada a un armature.")
    bone = armature.data.bones.get("LeftUpperArm")
    if bone is None:
        raise RuntimeError("El armature no contiene LeftUpperArm.")
    head = armature.matrix_world @ bone.head_local
    axis = (armature.matrix_world @ bone.tail_local) - head
    return head, axis, axis.length_squared


def _is_team_band(center: Vector, band_axis: tuple[Vector, Vector, float]) -> bool:
    head, axis, length_squared = band_axis
    if length_squared <= 1e-8:
        return False
    along = (center - head).dot(axis) / length_squared
    closest = head + axis * along
    radius = length_squared**0.5 * 0.55
    return 0.55 <= along <= 0.78 and (center - closest).length <= radius


def _ensure_material_slot(obj: bpy.types.Object, name: str, source: bpy.types.Material) -> int:
    for index, material in enumerate(obj.data.materials):
        if material and material.name == name:
            return index
    material = source.copy()
    material.name = name
    obj.data.materials.append(material)
    return len(obj.data.materials) - 1


def apply_identity_materials(obj: bpy.types.Object) -> dict[str, int]:
    if obj.type != "MESH" or not obj.data.materials:
        raise RuntimeError("Se requiere una malla con material base.")
    mesh = obj.data
    if mesh.uv_layers.active is None:
        raise RuntimeError("La malla no contiene UVs.")
    source = mesh.materials[0]
    if source is None:
        raise RuntimeError("El primer slot de material está vacío.")
    source.name = "Material_0"
    image = _source_image(source)
    width, height = image.size
    pixels = array("f", [0.0]) * (width * height * 4)
    image.pixels.foreach_get(pixels)

    skin_index = _ensure_material_slot(obj, "mat_piel", source)
    team_index = _ensure_material_slot(obj, "mat_color_equipo", source)
    uv_data = mesh.uv_layers.active.data
    band_axis = _team_band_axis(obj)
    counts = {"base_faces": 0, "skin_faces": 0, "team_faces": 0}

    for polygon in mesh.polygons:
        center = _polygon_center(obj, polygon)
        rgb = _mean_uv_color(polygon, uv_data, pixels, width, height)
        if _is_team_band(center, band_axis):
            polygon.material_index = team_index
            counts["team_faces"] += 1
        elif _is_skin(center, rgb):
            polygon.material_index = skin_index
            counts["skin_faces"] += 1
        else:
            polygon.material_index = 0
            counts["base_faces"] += 1

    counts["total_faces"] = len(mesh.polygons)
    return counts


def main() -> None:
    args = _parse_args(sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else [])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(args.input))
    meshes = [
        obj
        for obj in bpy.context.scene.objects
        if obj.type == "MESH"
        and obj.data.materials
        and not any(collection.name == "glTF_not_exported" for collection in obj.users_collection)
    ]
    if not meshes:
        raise RuntimeError("El GLB no contiene mallas.")
    summaries = {obj.name: apply_identity_materials(obj) for obj in meshes}
    output = args.output or args.input
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(output),
        export_format="GLB",
        export_apply=False,
        export_skins=True,
        export_animations=True,
        export_animation_mode="NLA_TRACKS",
        export_morph=True,
        export_morph_normal=True,
        export_morph_animation=True,
    )
    print("CTN_IDENTITY_MATERIALS=" + json.dumps({"meshes": summaries, "output": str(output)}))


if __name__ == "__main__":
    main()
