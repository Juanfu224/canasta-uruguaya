## Menú principal del juego.
##
## Pantalla de entrada con:
##   - Título y nickname.
##   - "Practicar (offline)": carga `MatchOffline.tscn` con transición fluid.
##   - "Jugar online": placeholder F5 (deshabilitado).
##   - "Tutorial": placeholder F6 (deshabilitado).
##   - "Ajustes": panel modal con squishy toggles para sonido y vibración.
##
## El menú es un `Control` autocontenido. No expone estado mutable global;
## sólo escribe en `ProfileStore.set_setting(...)` para preferencias.
class_name Menu
extends Control

const MATCH_OFFLINE_PATH: String = "res://scenes/MatchOffline.tscn"
const MATCH_VS_BOTS_PATH: String = "res://scenes/MatchVsBots.tscn"
const LOBBY_PATH: String = "res://scenes/Lobby.tscn"
const LOADING_FLUID_SCENE: PackedScene = preload("res://ui/transitions/loading_fluid.tscn")
const SQUISHY_TOGGLE_SCENE: PackedScene = preload("res://ui/squishy_toggle.tscn")

@onready var _title: Label = $Center/VBox/Title
@onready var _nickname_label: Label = $Center/VBox/NickRow/NicknameLabel
@onready var _btn_offline: Button = $Center/VBox/BtnOffline
@onready var _btn_vs_bots: Button = $Center/VBox/BtnVsBots
@onready var _btn_online: Button = $Center/VBox/BtnOnline
@onready var _btn_tutorial: Button = $Center/VBox/BtnTutorial
@onready var _btn_settings: Button = $Center/VBox/BtnSettings
@onready var _settings_modal: Control = $SettingsModal
@onready var _settings_rows: VBoxContainer = $SettingsModal/Center/Panel/Margin/VBox/Rows
@onready var _settings_close: Button = $SettingsModal/Center/Panel/Margin/VBox/Close

var _toggle_sfx: SquishyToggle = null
var _toggle_music: SquishyToggle = null
var _toggle_vibration: SquishyToggle = null
var _toggle_reduce_motion: SquishyToggle = null


func _ready() -> void:
	_nickname_label.text = ProfileStore.nickname
	_btn_offline.pressed.connect(_on_offline_pressed)
	_btn_vs_bots.pressed.connect(_on_vs_bots_pressed)
	_btn_online.pressed.connect(_on_online_pressed)
	_btn_tutorial.pressed.connect(_on_tutorial_pressed)
	_btn_settings.pressed.connect(_on_settings_pressed)
	_settings_close.pressed.connect(_on_settings_close)

	# Online: lobby LAN (F5).
	_btn_online.disabled = false
	_btn_online.tooltip_text = "LAN 2v2"
	_btn_tutorial.disabled = true
	_btn_tutorial.tooltip_text = "Disponible en F6"

	_settings_modal.visible = false
	_build_settings()


func _build_settings() -> void:
	_toggle_sfx = _add_toggle_row("Efectos de sonido", bool(ProfileStore.settings.get("sfx_volume", 1.0) > 0.0))
	_toggle_sfx.toggled_state.connect(func(state: bool) -> void:
		ProfileStore.set_setting("sfx_volume", 1.0 if state else 0.0)
	)
	_toggle_music = _add_toggle_row("Música", bool(ProfileStore.settings.get("music_volume", 0.7) > 0.0))
	_toggle_music.toggled_state.connect(func(state: bool) -> void:
		ProfileStore.set_setting("music_volume", 0.7 if state else 0.0)
	)
	_toggle_vibration = _add_toggle_row("Vibración", bool(ProfileStore.settings.get("vibration", true)))
	_toggle_vibration.toggled_state.connect(func(state: bool) -> void:
		ProfileStore.set_setting("vibration", state)
	)
	_toggle_reduce_motion = _add_toggle_row("Reducir movimiento", bool(ProfileStore.settings.get("reduce_motion", false)))
	_toggle_reduce_motion.toggled_state.connect(func(state: bool) -> void:
		ProfileStore.set_setting("reduce_motion", state)
	)


func _add_toggle_row(label_text: String, initial: bool) -> SquishyToggle:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN

	var l: Label = Label.new()
	l.text = label_text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 18)
	row.add_child(l)

	var t: SquishyToggle = SQUISHY_TOGGLE_SCENE.instantiate() as SquishyToggle
	t.initial_state = initial
	row.add_child(t)
	_settings_rows.add_child(row)
	return t


# ---------------------------------------------------------------------------
# Acciones
# ---------------------------------------------------------------------------

func _on_offline_pressed() -> void:
	_btn_offline.disabled = true
	var transition: LoadingFluid = LOADING_FLUID_SCENE.instantiate() as LoadingFluid
	add_child(transition)
	await transition.play_in(0.4)
	# El botón "Offline" lleva a una partida vs bots autoritativa (host local).
	# La escena de QA visual `MatchOffline.tscn` queda detrás del flag
	# `--match-offline-qa` para evitar exponer un flujo no productivo.
	var err: int = get_tree().change_scene_to_file(MATCH_VS_BOTS_PATH)
	if err != OK:
		push_error("Menu: no se pudo cargar %s (err=%d)" % [MATCH_VS_BOTS_PATH, err])
		_btn_offline.disabled = false
		await transition.play_out(0.4)
		transition.queue_free()


func _on_online_pressed() -> void:
	_btn_online.disabled = true
	var err: int = get_tree().change_scene_to_file(LOBBY_PATH)
	if err != OK:
		push_error("Menu: no se pudo cargar %s (err=%d)" % [LOBBY_PATH, err])
		_btn_online.disabled = false


func _on_vs_bots_pressed() -> void:
	_btn_vs_bots.disabled = true
	var transition: LoadingFluid = LOADING_FLUID_SCENE.instantiate() as LoadingFluid
	add_child(transition)
	await transition.play_in(0.4)
	var err: int = get_tree().change_scene_to_file(MATCH_VS_BOTS_PATH)
	if err != OK:
		push_error("Menu: no se pudo cargar %s (err=%d)" % [MATCH_VS_BOTS_PATH, err])
		_btn_vs_bots.disabled = false
		await transition.play_out(0.4)
		transition.queue_free()


func _on_tutorial_pressed() -> void:
	pass


func _on_settings_pressed() -> void:
	_settings_modal.visible = true
	_settings_modal.modulate.a = 0.0
	create_tween().tween_property(_settings_modal, "modulate:a", 1.0, 0.18)


func _on_settings_close() -> void:
	var t: Tween = create_tween()
	t.tween_property(_settings_modal, "modulate:a", 0.0, 0.15)
	await t.finished
	_settings_modal.visible = false
