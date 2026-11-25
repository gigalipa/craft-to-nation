"""Pipeline Serverless Hibrido Multi-View en Modal para Craft to Nation.

Ejecuta dos contenedores CUDA independientes compartiendo un modal.Volume:
  1. image_hunyuan: rembg + Hunyuan3D-2mv (geometria multi-vista) + FaceReducer
     (reduccion de triangulos ANTES de texturizar) + Hunyuan3D-Paint (PBR).
  2. image_unirig:  UniRig (esqueleto humanoide + skinning weights -> .glb).

Uso desde local (usando el environment 'crafttonation' de la cuenta 'gigalipa'):
    modal run -e crafttonation tools/3d_pipeline/modal_hunyuan_rig.py \\
        --front scratch/views/front.png \\
        --left scratch/views/left.png \\
        --back scratch/views/back.png \\
        --target-faces 5000 \\
        --output scratch/personaje_raw_rigged.glb
"""

from __future__ import annotations

import os
import subprocess
import uuid
from pathlib import Path
from typing import Optional

import modal

APP_NAME = "ctn-hunyuan-unirig-pipeline"
VOLUME_NAME = "hunyuan-unirig-cache"
CACHE_DIR = "/cache"
HF_CACHE = f"{CACHE_DIR}/huggingface"
JOBS_DIR = f"{CACHE_DIR}/jobs"

app = modal.App(APP_NAME)
volume = modal.Volume.from_name(VOLUME_NAME, create_if_missing=True)

# ---------------------------------------------------------------------------
# Contenedor 1: Hunyuan3D-2 (Multi-View + FaceReducer + Paint + rembg)
# ---------------------------------------------------------------------------
image_hunyuan = (
    modal.Image.from_registry(
        "nvidia/cuda:12.4.1-devel-ubuntu22.04",
        add_python="3.11",
    )
    .apt_install(
        "git",
        "libgl1-mesa-glx",
        "libglib2.0-0",
        "libxi6",
        "libxrender1",
        "build-essential",
        "ninja-build",
    )
    .pip_install(
        "torch==2.5.1",
        "torchvision==0.20.1",
        extra_index_url="https://download.pytorch.org/whl/cu124",
    )
    .pip_install(
        "diffusers>=0.30.0,<0.33.0",
        "transformers>=4.46.0,<4.50.0",
        "accelerate>=0.34.0,<1.4.0",
        "huggingface_hub>=0.25.0,<1.0.0",
        "safetensors",
        "einops",
        "omegaconf",
        "trimesh",
        "pymeshlab",
        "xatlas",
        "pygltflib",
        "opencv-python-headless",
        "rembg[cpu]",
        "onnxruntime",
        "Pillow",
        "scipy",
        "scikit-image",
        "numpy<2",
        "tqdm",
        "pyyaml",
        "ninja",
        "pybind11",
    )
    .run_commands(
        "git clone --depth 1 https://github.com/Tencent-Hunyuan/Hunyuan3D-2.git /opt/Hunyuan3D-2",
        "pip install --no-deps -e /opt/Hunyuan3D-2",
        "cd /opt/Hunyuan3D-2/hy3dgen/texgen/custom_rasterizer && CC=gcc CXX=g++ CUDA_HOME=/usr/local/cuda TORCH_CUDA_ARCH_LIST='8.9;8.6;8.0' python setup.py install",
        "cd /opt/Hunyuan3D-2/hy3dgen/texgen/differentiable_renderer && CC=gcc CXX=g++ CUDA_HOME=/usr/local/cuda TORCH_CUDA_ARCH_LIST='8.9;8.6;8.0' python setup.py build_ext --inplace",
    )
    .pip_install("fast-simplification")
    .env(
        {
            "HF_HOME": HF_CACHE,
            "HUGGINGFACE_HUB_CACHE": HF_CACHE,
            "TORCH_HOME": f"{CACHE_DIR}/torch",
            "PYTORCH_CUDA_ALLOC_CONF": "expandable_segments:True",
        }
    )
)

# ---------------------------------------------------------------------------
# Contenedor 2: UniRig (Auto-Rigging Universal: esqueleto + skinning -> .glb)
# ---------------------------------------------------------------------------
image_unirig = (
    modal.Image.from_registry(
        "nvidia/cuda:12.1.1-devel-ubuntu22.04",
        add_python="3.11",
    )
    .apt_install(
        "git",
        "wget",
        "libgl1-mesa-glx",
        "libglib2.0-0",
        "libxi6",
        "libxrender1",
        "libxkbcommon0",
        "libsm6",
        "libxext6",
    )
    .pip_install(
        "torch==2.3.1",
        "torchvision==0.18.1",
        extra_index_url="https://download.pytorch.org/whl/cu121",
    )
    .run_commands(
        "pip install spconv-cu121 torch-scatter torch-cluster -f https://data.pyg.org/whl/torch-2.3.1+cu121.html",
        "pip install https://github.com/Dao-AILab/flash-attention/releases/download/v2.6.3/flash_attn-2.6.3+cu123torch2.3cxx11abiFALSE-cp311-cp311-linux_x86_64.whl",
        "git clone --depth 1 https://github.com/VAST-AI-Research/UniRig.git /opt/UniRig",
        "printf 'torch==2.3.1\\ntorchvision==0.18.1\\nnumpy<2\\n' > /tmp/unirig_constraints.txt && grep -Ev '^(flash_attn|bpy)' /opt/UniRig/requirements.txt > /tmp/unirig_req.txt && pip install -c /tmp/unirig_constraints.txt -r /tmp/unirig_req.txt",
        "pip install bpy==4.2.0 --extra-index-url https://download.blender.org/pypi/",
    )
    .apt_install("libegl1", "libopengl0", "libgl1", "libgles2", "libusb-1.0-0", "libgomp1")
    .env(
        {
            "HF_HOME": HF_CACHE,
            "HUGGINGFACE_HUB_CACHE": HF_CACHE,
            "TORCH_HOME": f"{CACHE_DIR}/torch",
        }
    )
)


def _preprocess_view(raw_bytes: bytes) -> "Image.Image":
    """Elimina el fondo con rembg y centra el personaje con margen uniforme."""
    import io
    from PIL import Image
    from rembg import remove

    img = Image.open(io.BytesIO(raw_bytes)).convert("RGBA")
    cut = remove(img)
    bbox = cut.getbbox()
    if bbox:
        cut = cut.crop(bbox)
    cw, ch = cut.size
    side = int(max(cw, ch) * 1.15)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(cut, ((side - cw) // 2, (side - ch) // 2), cut)
    return canvas.resize((1024, 1024), Image.Resampling.LANCZOS)


# ---------------------------------------------------------------------------
# Paso A: Generacion Multi-View + FaceReducer + Pintura PBR (Hunyuan3D-2mv)
# ---------------------------------------------------------------------------
@app.function(
    image=image_hunyuan,
    gpu="L40S",
    volumes={CACHE_DIR: volume},
    timeout=600,
    scaledown_window=30,
)
def generate_textured_mesh(
    job_id: str,
    front_bytes: bytes,
    left_bytes: bytes,
    back_bytes: bytes,
    target_faces: int = 5000,
    steps: int = 30,
    seed: int = 42,
    skip_paint: bool = False,
) -> str:
    import gc
    import inspect
    import torch
    from hy3dgen.shapegen import Hunyuan3DDiTFlowMatchingPipeline

    volume.reload()
    job_dir = Path(JOBS_DIR) / job_id
    job_dir.mkdir(parents=True, exist_ok=True)

    print(f"[{job_id}] Preprocesando 3 vistas con rembg...")
    views = {
        "front": _preprocess_view(front_bytes),
        "left": _preprocess_view(left_bytes),
        "back": _preprocess_view(back_bytes),
    }

    print(f"[{job_id}] Cargando Hunyuan3D-2mv (geometria multi-vista)...")
    pipeline_shape = Hunyuan3DDiTFlowMatchingPipeline.from_pretrained(
        "tencent/Hunyuan3D-2mv",
        subfolder="hunyuan3d-dit-v2-mv",
        use_safetensors=True,
        device="cuda",
    )

    generator = torch.Generator(device="cuda").manual_seed(seed)
    mesh = pipeline_shape(
        image=views,
        num_inference_steps=steps,
        octree_resolution=384,
        generator=generator,
        output_type="trimesh",
    )[0]

    print(f"[{job_id}] Limpiando malla y reduciendo a {target_faces} caras (pre-textura)...")
    parts = mesh.split(only_watertight=False)
    if parts:
        mesh = max(parts, key=lambda m: len(m.faces))
    mesh.update_faces(mesh.nondegenerate_faces())
    mesh.remove_unreferenced_vertices()
    if len(mesh.faces) > target_faces:
        mesh = mesh.simplify_quadric_decimation(face_count=target_faces)
    print(f"[{job_id}] Caras tras reduccion: {len(mesh.faces)}")

    # Liberacion explicita de VRAM antes de cargar Hunyuan3D-Paint
    del pipeline_shape
    gc.collect()
    torch.cuda.empty_cache()

    if not skip_paint:
        from hy3dgen.texgen import Hunyuan3DPaintPipeline

        print(f"[{job_id}] Cargando Hunyuan3D-Paint para texturas PBR...")
        pipeline_paint = Hunyuan3DPaintPipeline.from_pretrained("tencent/Hunyuan3D-2")
        sig = inspect.signature(pipeline_paint.__call__)
        if "image" in sig.parameters:
            mesh = pipeline_paint(mesh, image=views["front"])
        else:
            mesh = pipeline_paint(mesh, views["front"])
        del pipeline_paint
        gc.collect()
        torch.cuda.empty_cache()

    out_glb = job_dir / "mesh_textured.glb"
    mesh.export(str(out_glb))
    volume.commit()
    print(f"[{job_id}] Malla texturizada guardada en volumen: {out_glb}")
    return str(out_glb)


# ---------------------------------------------------------------------------
# Paso B: Auto-Rigging Universal con UniRig (Contenedor independiente)
# ---------------------------------------------------------------------------
@app.function(
    image=image_unirig,
    gpu="A10G",
    volumes={CACHE_DIR: volume},
    timeout=600,
    scaledown_window=30,
)
def autoroot_rig_mesh(job_id: str, input_glb_in_volume: str) -> bytes:
    volume.reload()
    job_dir = Path(JOBS_DIR) / job_id
    job_dir.mkdir(parents=True, exist_ok=True)

    in_glb = Path(input_glb_in_volume)
    skel_fbx = job_dir / "skeleton.fbx"
    skin_fbx = job_dir / "skin.fbx"
    rigged_glb = job_dir / "rigged.glb"

    unirig_dir = "/opt/UniRig"
    env = os.environ.copy()
    env["PYTHONPATH"] = f"{unirig_dir}:{env.get('PYTHONPATH', '')}"

    def _run(cmd: list[str], label: str) -> None:
        print(f"[{job_id}] UniRig -> {label}: {' '.join(cmd)}")
        subprocess.run(cmd, cwd=unirig_dir, env=env, check=True)

    _run(
        [
            "bash",
            "launch/inference/generate_skeleton.sh",
            "--input",
            str(in_glb),
            "--output",
            str(skel_fbx),
        ],
        "generate_skeleton",
    )
    _run(
        [
            "bash",
            "launch/inference/generate_skin.sh",
            "--input",
            str(skel_fbx),
            "--output",
            str(skin_fbx),
        ],
        "generate_skin",
    )
    _run(
        [
            "bash",
            "launch/inference/merge.sh",
            "--source",
            str(skin_fbx),
            "--target",
            str(in_glb),
            "--output",
            str(rigged_glb),
        ],
        "merge",
    )

    volume.commit()
    print(f"[{job_id}] Rigging completado: {rigged_glb}")
    return rigged_glb.read_bytes()


@app.function(
    image=image_hunyuan,
    volumes={CACHE_DIR: volume},
    timeout=120,
    scaledown_window=15,
)
def read_volume_file(path_in_volume: str) -> bytes:
    volume.reload()
    return Path(path_in_volume).read_bytes()


@app.function(
    image=image_unirig,
    volumes={CACHE_DIR: volume},
    timeout=120,
    scaledown_window=15,
)
def upload_for_rig_only(job_id: str, glb_bytes: bytes) -> str:
    volume.reload()
    job_dir = Path(JOBS_DIR) / job_id
    job_dir.mkdir(parents=True, exist_ok=True)
    target = job_dir / "mesh_input.glb"
    target.write_bytes(glb_bytes)
    volume.commit()
    return str(target)


# ---------------------------------------------------------------------------
# Entrypoint CLI local
# ---------------------------------------------------------------------------
@app.local_entrypoint()
def main(
    front: Optional[str] = None,
    left: Optional[str] = None,
    side: Optional[str] = None,
    back: Optional[str] = None,
    output: str = "scratch/character_raw_rigged.glb",
    target_faces: int = 5000,
    steps: int = 30,
    seed: int = 42,
    skip_rig: bool = False,
    skip_paint: bool = False,
    rig_only: Optional[str] = None,
) -> None:
    """Ejecuta el pipeline completo Hunyuan3D-2mv -> UniRig y guarda el .glb local."""
    job_id = uuid.uuid4().hex[:10]
    out_path = Path(output)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    if rig_only:
        in_bytes = Path(rig_only).read_bytes()
        print(f"[{job_id}] Modo --rig-only: subiendo {rig_only} a Modal...")
        vol_path = upload_for_rig_only.remote(job_id, in_bytes)
        result_bytes = autoroot_rig_mesh.remote(job_id, vol_path)
        out_path.write_bytes(result_bytes)
        print(f"[{job_id}] Modelo riggeado guardado en: {out_path}")
        return

    left_path = left or side
    if not (front and left_path and back):
        raise SystemExit(
            "Debes proporcionar --front, --left (o --side) y --back, o usar --rig-only <modelo.glb>."
        )

    front_bytes = Path(front).read_bytes()
    left_bytes = Path(left_path).read_bytes()
    back_bytes = Path(back).read_bytes()

    print(
        f"[{job_id}] Iniciando Hunyuan3D-2mv (target_faces={target_faces}, steps={steps}, seed={seed})..."
    )
    textured_vol_path = generate_textured_mesh.remote(
        job_id=job_id,
        front_bytes=front_bytes,
        left_bytes=left_bytes,
        back_bytes=back_bytes,
        target_faces=target_faces,
        steps=steps,
        seed=seed,
        skip_paint=skip_paint,
    )

    if skip_rig:
        print(f"[{job_id}] --skip-rig activo: descargando malla texturizada sin rig...")
        result_bytes = read_volume_file.remote(textured_vol_path)
    else:
        print(f"[{job_id}] Ejecutando UniRig en contenedor independiente...")
        result_bytes = autoroot_rig_mesh.remote(job_id, textured_vol_path)

    out_path.write_bytes(result_bytes)
    print(f"[{job_id}] Listo -> {out_path} ({len(result_bytes) / 1024:.1f} KB)")
