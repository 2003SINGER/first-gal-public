# Display System — Architecture (Demo shell)

> Scope: minimal production shell built for the transition from "experiment" to
> formal Demo. Build per Timeline order (S01→S17); do NOT pre-build managers.
> Last updated: 2026-08-21.

## 1. SceneTree (res://scenes/main.tscn — root `FirstGal`)

```
FirstGal (Node, scripts/main.gd)
├─ SceneHost          (Control, Full Rect, mouse_filter=IGNORE)
│   └─ <current world scene>      # instantiated by SceneController
├─ PresentationRoot    (Control, Full Rect, mouse_filter=IGNORE)
│   └─ PhotoViewer     (Control, Full Rect, mouse_filter=IGNORE)
│       └─ Overlay     (Control, hidden by default, mouse_filter=IGNORE)
│           ├─ Dim     (ColorRect, 50% black, mouse_filter=IGNORE)
│           └─ Photo   (TextureRect, keep_aspect_covered, mouse_filter=IGNORE)
├─ SceneController     (Node, scripts/scene_controller.gd)
├─ NarrativeBridge    (Node, scripts/narrative_bridge.gd)
└─ InteractionController (Node, scripts/interaction/interaction_controller.gd)
```

Layering bottom→top: **World (SceneHost) → Photo (PresentationRoot) → Dialogic
dialogue layer**. PhotoViewer is a normal Control, not a CanvasLayer, so Dialogic
(its own CanvasLayer) renders above the photo and keeps input focus.

## 2. SceneHost
Container for the *current world scene*. Knows nothing about content. The active
world scene is added here as a child by SceneController.

## 3. SceneController (`scripts/scene_controller.gd`)
Owns "current world scene". Maps a semantic id → `PackedScene` and swaps the child
of SceneHost. **Hard-coded Dictionary registry** (no JSON/ResourceCatalog yet).
- `setup(host: Control)` — receives SceneHost.
- `change_scene(scene_id: String)` — unknown ids are warned and ignored.
- Current registry: `blank`, `school_gate`, `school_corridor`, `classroom`, `classroom_morning`, and `graduation_ceremony` → `res://scenes/world/*.tscn`. The corridor/morning/ceremony entries are graybox support for the current production slice, not a general scene-state system.

## 4. NarrativeBridge (`scripts/narrative_bridge.gd`)
Only bridge between Dialogic and Godot presentation/interaction commands. Connects
`Dialogic.signal_event` and parses the semantic command string:
- `scene:<id>`     → `SceneController.change_scene(<id>)`
- `photo:<id>`     → show registered photo
- `photo:hide`     → hide photo
- `interaction:<id>` → `InteractionController.start_interaction(<id>)`
Knows no file paths; resource mapping lives in the registries. Modal interaction
lifecycle is documented separately in `interaction_system.md`.

## 5. PhotoViewer (`scripts/presentation/photo_viewer.gd`)
Minimal API: `show_photo(texture: Texture2D)`, `hide_photo()`. Overlay/Dim/Photo
are all `mouse_filter = IGNORE` so they never eat Dialogic input. Non-modal by
design.

## 6. Semantic commands (Timeline → Godot)
Emitted from a Dialogic **Signal event** (argument_type = STRING), argument = the
whole command, e.g. `scene:school_gate`. A Timeline must NEVER contain file paths
or SceneTree structure — only these ids.

## 7. Resource registries (where mapping lives)
- Scenes: `SCENES` Dictionary in `scene_controller.gd`.
- Photos: `PHOTOS` Dictionary in `narrative_bridge.gd`
  (`first_day_classroom` → `res://assets/photos/classroom/first_day_classroom.png`).
  Missing files fall back to a generated placeholder so the system never crashes.
  Add real entries here as art lands.

## 8. Dialogic ↔ Godot responsibility boundary
- **Dialogic owns:** dialogue, choices, portraits, timeline order, and emitting
  *when* to switch scene/show photo (semantic commands only).
- **Godot owns:** current world scene, background, props, future hotspots, scene
  state, and the actual scene switch / photo presentation.
- The old Dialogic Background Event is NOT used by production world scenes. World
  scenes are Godot `Control` scenes (currently ColorRect+Label placeholders).
  Dialogic Background Event may stay for plugin/experiment timelines only.

## 9. Not implemented yet (do not pre-build)
Inventory, save, title/settings, AudioManager, CG system, custom Dialogic Event,
LLM compiler, phone UI, camera system, full Hotspot framework, relationship/
maturity numbers, many Autoloads, universal VisualManager, and formal Ending UI or
Credits. Build each only when its Timeline needs it.

## 10. Current production slice: S01–S17
- `01_return_to_school.dtl`: S01–S04.
- `02_locker_and_future.dtl`: S05–S06.
- `03_lunch_and_afternoon.dtl`: S07–S12.
- `04_memory_and_ending.dtl`: S13–S17.
- S12 jumps to the fourth Timeline. S13/S15 use `scene:classroom_late_afternoon`;
  S14, S15, and S17 use the existing semantic PhotoViewer commands.
- S05 emits `interaction:locker_cleanup`; S11 emits `interaction:desk_cleanup`.
  Each modal interaction pauses Dialogic and resumes it after its own `finished(result)`.
- S17 shows `photo:graduation_selfie` and the text `Demo End`; the Timeline then ends.
- Development runner: open `res://dev/scenes/demo_current_runner.tscn` and press F6.
  `main.tscn` deliberately remains neutral and therefore still begins at `blank`.

## 11. Next step
Play through S13–S17 with the graybox runner and inspect the placeholder montage,
final classroom photo, and selfie. Do not start visual refinement yet.

## Known gaps to resolve later
- Real art for world scenes and every new ending photo semantic id is absent; the
  existing PhotoViewer intentionally generates placeholder textures.
- `classroom_late_afternoon` is a graybox representation of the same space as the morning
  and afternoon classroom scenes; formal art must preserve that spatial structure.
- `test_intro.dtl` remains in `res://dialogic/timelines/` as a working reference
  (uses the Dialogic Background Event on purpose).
