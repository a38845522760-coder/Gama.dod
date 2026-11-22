#!/usr/bin/env python3
"""Build downloadable content packs (.pck) and manifest.json for Iron Yard.

Each pack source is a folder containing a pack.json plus the files that ship in the pack:

    <src>/<pack_id>/pack.json        {"id","type","version","name":{fa,en},"battle","max_players","entry_scene"}
    <src>/<pack_id>/...              scenes, glb/gltf models, textures, resources (NO scripts)

For every pack the tool creates a tiny throw-away Godot project that holds only that pack's files
under res://content/<id>/, imports it (Android preset -> ETC2/ASTC textures) and exports a .pck.
Usage: build_packs.py --src content_src [--src more_dirs] --out build/packs [--godot godot]
"""
import argparse, hashlib, json, os, re, shutil, subprocess, sys
from pathlib import Path

SAFE_ID = re.compile(r"^[a-z0-9_-]{1,64}$")
MODES = {"battle", "duel", "training"}

PROJECT_GODOT = """config_version=5

[application]

config/name="IronYardPack"
config/features=PackedStringArray("4.4")

[rendering]

renderer/rendering_method="mobile"
renderer/rendering_method.mobile="mobile"
textures/vram_compression/import_etc2_astc=true
"""

PRESET = """[preset.0]

name="Android"
platform="Android"
runnable=false
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter="*.txt"
exclude_filter=""
export_path=""
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false

[preset.0.options]

gradle_build/use_gradle_build=false
architectures/armeabi-v7a=true
architectures/arm64-v8a=true
version/code=1
version/name="1.0"
package/unique_name="com.ironyard.pack"
package/name="Iron Yard Pack"
package/signed=true
"""


def run(cmd, cwd):
    print("+", " ".join(cmd), flush=True)
    proc = subprocess.run(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    sys.stdout.write(proc.stdout[-6000:])
    return proc.returncode


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def build_pack(src_dir: Path, out_dir: Path, work_root: Path, godot: str):
    cfg = json.loads((src_dir / "pack.json").read_text(encoding="utf-8"))
    pack_id = cfg["id"]
    if not SAFE_ID.match(pack_id) or pack_id != src_dir.name:
        raise SystemExit(f"[{src_dir.name}] pack.json id must be a safe name equal to the folder name")
    version = int(cfg.get("version", 1))
    entry = cfg.get("entry_scene", "")
    if not entry or not (src_dir / entry).exists():
        raise SystemExit(f"[{pack_id}] entry_scene '{entry}' not found")

    work = work_root / pack_id
    if work.exists():
        shutil.rmtree(work)
    target = work / "content" / pack_id
    shutil.copytree(src_dir, target, ignore=shutil.ignore_patterns("pack.json", "*.gd", "*.cs"))
    modes = [m for m in cfg.get("modes", []) if m in MODES]
    if cfg.get("battle") and "battle" not in modes:
        modes.append("battle")
    meta = {"id": pack_id, "type": cfg.get("type", "other"), "version": version,
            "entry_scene": f"res://content/{pack_id}/{entry}", "name": cfg.get("name", {}),
            "modes": modes, "max_players": int(cfg.get("max_players", 1))}
    (target / "pack_meta.txt").write_text(json.dumps(meta), encoding="utf-8")
    (work / "project.godot").write_text(PROJECT_GODOT, encoding="utf-8")
    (work / "export_presets.cfg").write_text(PRESET, encoding="utf-8")

    run([godot, "--headless", "--editor", "--path", ".", "--quit"], str(work))
    file_name = f"{pack_id}_v{version}.pck"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = (out_dir / file_name).resolve()
    if out_path.exists():
        out_path.unlink()
    code = run([godot, "--headless", "--path", ".", "--export-pack", "Android", str(out_path)], str(work))
    if code != 0 or not out_path.exists() or out_path.stat().st_size == 0:
        raise SystemExit(f"[{pack_id}] export failed (exit {code})")
    entry_info = {
        "id": pack_id, "type": cfg.get("type", "other"), "version": version,
        "file": file_name, "size": out_path.stat().st_size, "sha256": sha256(out_path),
        "name": cfg.get("name", {}), "modes": modes,
        "max_players": int(cfg.get("max_players", 1)),
    }
    print(f"[{pack_id}] built {file_name} ({entry_info['size']} bytes)")
    return entry_info


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", action="append", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--work", default="build/work")
    ap.add_argument("--godot", default="godot")
    ap.add_argument("--only", default="", help="comma separated pack ids")
    args = ap.parse_args()
    only = {x for x in args.only.split(",") if x}
    out_dir, work_root = Path(args.out), Path(args.work).resolve()
    packs = []
    for src_root in args.src:
        for src_dir in sorted(Path(src_root).iterdir()):
            if src_dir.is_dir() and (src_dir / "pack.json").exists():
                if only and src_dir.name not in only:
                    continue
                packs.append(build_pack(src_dir, out_dir, work_root, args.godot))
    if not packs:
        raise SystemExit("no packs found")
    # Merge with a manifest that already exists in --out (downloaded from the release), so a run that
    # rebuilds only some packs does not drop the others.
    merged = {}
    old_manifest = out_dir / "manifest.json"
    if old_manifest.exists():
        try:
            for old in json.loads(old_manifest.read_text(encoding="utf-8")).get("packs", []):
                merged[old["id"]] = old
        except (ValueError, KeyError):
            print("warning: existing manifest.json was unreadable; starting fresh")
    for entry in packs:
        merged[entry["id"]] = entry
    manifest = {"schema": 1, "packs": [merged[k] for k in sorted(merged)]}
    (out_dir / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"manifest.json written with {len(manifest['packs'])} pack(s) ({len(packs)} rebuilt)")


if __name__ == "__main__":
    main()
