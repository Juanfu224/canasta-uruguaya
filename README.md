# canasta-uruguaya

Juego de **Canasta Uruguaya** para móvil en Godot 4.6 (renderer Mobile, GDScript).

## Pruebas (smoke headless)

```bash
godot --headless --path . -s tools/run_f2_smoke.gd
godot --headless --path . -s tools/run_f3_smoke.gd
godot --headless --path . -s tools/run_f5_smoke.gd
godot --headless --path . -s tools/run_f6_smoke.gd
godot --headless --path . -s tools/run_f7_smoke.gd
```

## F7 — Optimización móvil + accesibilidad

- `Settings` (autoload): persistencia en `user://settings.cfg`. Toggles:
  vibración, sonido, reduce-motion (manual + auto-watcher de FPS),
  breathing del fanning, alto contraste, escala de fuente.
- `Haptics` (estático): API `tap()/success()/error()` con guards de
  plataforma (mobile-only) y respeto a `Settings.vibration_enabled`.
- `HandLayout`: pool interno de `CardUI` (cap 24) — recicla nodos en lugar
  de `queue_free()` por cada robo/descarte. Drena en `_exit_tree`.
- `CardUI`: omite `CardHoverOscillator` cuando `reduce_motion=true`.
  Vibra `Haptics.error()` si el drag se cancela.
- `DropZone`: vibra `Haptics.success()` en drop válido.
- `project.godot`: `default_texture_filter=1` (Linear),
  `pointing/emulate_touch_from_mouse=false` (debug-only en `main.gd`).
- `ui/hud/perf_overlay`: HUD opcional (FPS / draws / mem / nodes) —
  toggle con `F3`, sólo se monta si `OS.is_debug_build()`.