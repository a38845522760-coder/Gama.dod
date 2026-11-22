# Downloadable content packs

Maps, weapons and characters are **not** inside the APK. Each one is a `.pck` pack hosted on the
GitHub release `content-v1`, together with a `manifest.json`. The game lists them under
**Main menu -> Content**, downloads the chosen ones to `user://content/packs`, checks the SHA-256
and mounts them at startup. Mounting costs almost no RAM; only what a match instantiates is loaded.

## Pieces

| File | Role |
|------|------|
| `scripts/content/content_catalog.gd` | Pure logic: manifest parsing, safe names, sizes, status (unit-tested) |
| `scripts/content/content_manager.gd` | Autoload `ContentManager`: manifest, download, verify, mount, remove |
| `scripts/ui/content_screen.gd` | The Content page (tabs: maps / weapons / characters) |
| `scripts/world/pack_map.gd` | `PackMap.open(pack_id, tree)` plays a downloaded map (spawns, player, HUD) |
| `tools/build_packs.py` | Builds `.pck` files + `manifest.json` from `content_src/` |
| `.github/workflows/build-content.yml` | Runs the builder on GitHub and uploads to `content-v1` |

## Rules for a pack

* Data only: scenes, meshes (`.glb`), textures, resources. **No scripts** (`.gd` is stripped).
* Everything lives under `content/<id>/` inside the pack; `pack_meta.txt` is generated.
* A map scene marks spawn points with `Marker3D` nodes in group `pack_spawn`; the game turns them
  into real spawn points. Loot points can use group `pack_loot` (used by the battle mode later).
* `pack.json` (source only) fields: `id` (a-z 0-9 _ -, equals the folder name), `type`
  (`map` | `weapon` | `character`), `version`, `name {fa,en}`, `modes` (list of `battle`, `duel`,
  `training`; only for maps), `max_players`, `entry_scene`. Each mode screen shows only maps that
  carry its mode: `ContentManager.get_installed_maps_for_mode("duel")`.
* Bump `version` to publish an update; players see an Update button.

## Adding a pack

1. Create `content_src/<id>/` with `pack.json` and the files.
2. Replace the project ZIP in the repository, then run **Actions -> Iron Yard - build content packs**.
3. Open the game -> Content -> Refresh list -> Download -> Play.

`content_src/` has a `.gdignore` and is excluded from the APK export.

## Changing the download address

`ContentManager.DEFAULT_BASE_URL` points at the `content-v1` release of the repository. To test another
address without rebuilding, write the URL (ending with `/`) into `user://content/base_url.txt`.

## Installing from the phone (offline)

Ready-made packs named `<id>_v<version>.pck` (for example `gorg_v1.pck`, downloaded from the workflow
artifact `IronYard-content-packs`) can be copied to the phone folder `Download/IronYard`. In the game:
Content -> From phone -> Allow file access -> Scan again -> Install. Raw model zips cannot be used this way:
textures must be compressed and models imported, which only the build workflow does.
Android 11+ needs the "all files access" permission for that folder; the export preset requests it
(`permissions/manage_external_storage`). This path is untested on real devices.
