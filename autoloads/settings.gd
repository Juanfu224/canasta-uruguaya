## Preferencias de UX/accesibilidad persistidas en `user://settings.cfg`.
##
## Centraliza los toggles que afectan a UI, FX y accesibilidad:
##   - vibration_enabled       (bool)  háptica en drop válido / error
##   - sound_enabled           (bool)  master SFX (cableado en F8)
##   - reduce_motion           (bool)  desactiva breathing y oscillator
##   - breathing_enabled       (bool)  toggle fino del fanning sine breath
##   - colorblind_high_contrast(bool)  paleta alternativa (cableado en F8)
##   - auto_reduce_motion      (bool)  watcher FPS; desactiva FX si <55fps
##   - font_scale              (float) multiplicador de fuente (F8 lo aplica)
##
## Diseño:
##   - Singleton autoload (`Settings`). Cargado **antes** que las escenas de
##     match (registrado en project.godot tras ProfileStore).
##   - Persistencia con `ConfigFile`. `save()` está debounce'd 200ms para
##     evitar I/O en cada toggle del slider.
##   - Señal `changed(key)` para que UI/HandLayout/CardUI/Haptics reaccionen
##     sin acoplarse.
##   - Auto reduce-motion: muestrea `Engine.get_frames_per_second()` cada
##     1s tras un warm-up de 5s. Si 3 muestras consecutivas <55fps, fija
##     `reduce_motion=true`. NO revierte solo (opt-out manual del jugador).
##
## Seguridad:
##   - El archivo no contiene secretos. Validamos rangos al cargar para
##     que un usuario que edite manualmente el .cfg no pueda inyectar
##     valores absurdos (ej. font_scale=9999).
extends Node

const SETTINGS_PATH: StringName = &"user://settings.cfg"
const SECTION: StringName = &"ux"

const FONT_SCALE_MIN: float = 0.85
const FONT_SCALE_MAX: float = 1.5

# --- Auto reduce-motion ---
const _AUTO_FPS_THRESHOLD: float = 55.0
const _AUTO_SAMPLE_INTERVAL: float = 1.0
const _AUTO_WARMUP: float = 5.0
const _AUTO_TRIGGER_SAMPLES: int = 3

const _SAVE_DEBOUNCE: float = 0.2

signal changed(key: String)

var vibration_enabled: bool = true
var sound_enabled: bool = true
var reduce_motion: bool = false
var breathing_enabled: bool = true
var colorblind_high_contrast: bool = false
var auto_reduce_motion: bool = true
var font_scale: float = 1.0

var _save_timer: SceneTreeTimer = null
var _save_pending: bool = false

# Auto reduce-motion FPS monitor
var _fps_elapsed: float = 0.0
var _fps_warmup: float = 0.0
var _fps_low_streak: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()


func _process(delta: float) -> void:
	# Solo monitoreamos FPS si el auto-modo está activo y aún no se disparó.
	if not auto_reduce_motion or reduce_motion:
		return
	_fps_warmup += delta
	if _fps_warmup < _AUTO_WARMUP:
		return
	_fps_elapsed += delta
	if _fps_elapsed < _AUTO_SAMPLE_INTERVAL:
		return
	_fps_elapsed = 0.0
	var fps: float = Engine.get_frames_per_second()
	if fps > 0.0 and fps < _AUTO_FPS_THRESHOLD:
		_fps_low_streak += 1
		if _fps_low_streak >= _AUTO_TRIGGER_SAMPLES:
			print_verbose("[Settings] auto reduce_motion ON (fps=%.1f)" % fps)
			set_reduce_motion(true)
	else:
		_fps_low_streak = 0


# ---------------------------------------------------------------------------
# Carga / guardado
# ---------------------------------------------------------------------------

func load_settings() -> Error:
	var cfg: ConfigFile = ConfigFile.new()
	var err: int = cfg.load(SETTINGS_PATH)
	if err == ERR_FILE_NOT_FOUND:
		# Migración suave: heredar de ProfileStore.settings si existe.
		_migrate_from_profile_store()
		save_settings()
		return OK
	if err != OK:
		push_warning("Settings: error cargando (%d). Usando defaults." % err)
		return err

	vibration_enabled = bool(cfg.get_value(SECTION, "vibration_enabled", vibration_enabled))
	sound_enabled = bool(cfg.get_value(SECTION, "sound_enabled", sound_enabled))
	reduce_motion = bool(cfg.get_value(SECTION, "reduce_motion", reduce_motion))
	breathing_enabled = bool(cfg.get_value(SECTION, "breathing_enabled", breathing_enabled))
	colorblind_high_contrast = bool(cfg.get_value(SECTION, "colorblind_high_contrast", colorblind_high_contrast))
	auto_reduce_motion = bool(cfg.get_value(SECTION, "auto_reduce_motion", auto_reduce_motion))
	font_scale = clampf(float(cfg.get_value(SECTION, "font_scale", font_scale)), FONT_SCALE_MIN, FONT_SCALE_MAX)
	return OK


func save_settings() -> Error:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value(SECTION, "vibration_enabled", vibration_enabled)
	cfg.set_value(SECTION, "sound_enabled", sound_enabled)
	cfg.set_value(SECTION, "reduce_motion", reduce_motion)
	cfg.set_value(SECTION, "breathing_enabled", breathing_enabled)
	cfg.set_value(SECTION, "colorblind_high_contrast", colorblind_high_contrast)
	cfg.set_value(SECTION, "auto_reduce_motion", auto_reduce_motion)
	cfg.set_value(SECTION, "font_scale", font_scale)
	var err: int = cfg.save(SETTINGS_PATH)
	if err != OK:
		push_warning("Settings: error guardando (%d)" % err)
	return err


func _request_save() -> void:
	if _save_pending:
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		# Autoload aún no en árbol (p.ej. en smoke tests con `-s`); guardar inmediato.
		save_settings()
		return
	_save_pending = true
	_save_timer = tree.create_timer(_SAVE_DEBOUNCE, true, false, true)
	_save_timer.timeout.connect(func() -> void:
		_save_pending = false
		save_settings()
	)


func _migrate_from_profile_store() -> void:
	# ProfileStore (F1) tenía un dict `settings` con `vibration` y
	# `reduce_motion`. Si existe, heredamos para no perder la elección
	# del jugador en upgrade.
	if not Engine.has_singleton("ProfileStore") and not _has_autoload("ProfileStore"):
		return
	var ps: Node = _get_profile_store()
	if ps == null or not (ps is Node):
		return
	var ps_settings: Variant = ps.get("settings")
	if ps_settings is Dictionary:
		var d: Dictionary = ps_settings
		if d.has("vibration"):
			vibration_enabled = bool(d["vibration"])
		if d.has("reduce_motion"):
			reduce_motion = bool(d["reduce_motion"])


func _has_autoload(name_: String) -> bool:
	var root: Node = get_tree().root
	return root != null and root.has_node(NodePath(name_))


func _get_profile_store() -> Node:
	var root: Node = get_tree().root
	if root == null:
		return null
	return root.get_node_or_null(^"ProfileStore")


# ---------------------------------------------------------------------------
# Setters tipados (emiten `changed` y debounce-guardan)
# ---------------------------------------------------------------------------

func set_vibration_enabled(v: bool) -> void:
	if vibration_enabled == v:
		return
	vibration_enabled = v
	changed.emit("vibration_enabled")
	_request_save()


func set_sound_enabled(v: bool) -> void:
	if sound_enabled == v:
		return
	sound_enabled = v
	changed.emit("sound_enabled")
	_request_save()


func set_reduce_motion(v: bool) -> void:
	if reduce_motion == v:
		return
	reduce_motion = v
	changed.emit("reduce_motion")
	_request_save()


func set_breathing_enabled(v: bool) -> void:
	if breathing_enabled == v:
		return
	breathing_enabled = v
	changed.emit("breathing_enabled")
	_request_save()


func set_colorblind_high_contrast(v: bool) -> void:
	if colorblind_high_contrast == v:
		return
	colorblind_high_contrast = v
	changed.emit("colorblind_high_contrast")
	_request_save()


func set_auto_reduce_motion(v: bool) -> void:
	if auto_reduce_motion == v:
		return
	auto_reduce_motion = v
	if not v:
		_fps_low_streak = 0
	changed.emit("auto_reduce_motion")
	_request_save()


func set_font_scale(v: float) -> void:
	var clamped: float = clampf(v, FONT_SCALE_MIN, FONT_SCALE_MAX)
	if is_equal_approx(font_scale, clamped):
		return
	font_scale = clamped
	changed.emit("font_scale")
	_request_save()


# Helpers de consulta para módulos que no quieren acoplarse a campos.
func motion_allowed() -> bool:
	return not reduce_motion


func breathing_allowed() -> bool:
	return not reduce_motion and breathing_enabled
