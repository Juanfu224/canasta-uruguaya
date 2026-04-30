## Punto de entrada de la app.
##
## Por ahora (F1) solo loguea el estado de los autoloads y deja la pantalla
## en negro. La transición a Lobby/Menu se cablea en F3.
extends Node


func _ready() -> void:
	# Per CLAUDE.md / arquitectura: el drag&drop táctil necesita eventos
	# crudos sin acumular para latencia <50ms.
	Input.use_accumulated_input = false
	# Solo emulamos toque desde mouse en builds de debug (desktop dev).
	# En release apuntamos a touch nativo para no enmascarar bugs móviles.
	Input.set_emulate_touch_from_mouse(OS.is_debug_build())

	print("[Main] Canasta Uruguaya — boot OK")
	print("[Main] Profile UUID: %s nickname=%s" % [ProfileStore.uuid, ProfileStore.nickname])
	var seed_value: int = RngService.start_match(0)
	print("[Main] Match RNG seed: %d" % seed_value)

	# Smoke check: construir y mezclar el mazo. Si algo está roto, falla aquí
	# antes de cualquier UI.
	var deck: Deck = Deck.build_standard_108()
	deck.shuffle(RngService.match_rng)
	assert(deck.size() == GameConfig.TOTAL_CARDS, "Deck inválido")
	print("[Main] Deck OK (%d cartas)" % deck.size())

	# HUD de performance opcional para QA — solo en debug builds.
	if OS.is_debug_build():
		_install_perf_overlay()

	# Lanzador opcional de la escena de QA visual de F3. Activar con:
	#   godot --path . -- --match-offline
	# Si no se pide QA, cargamos el menú principal (F4).
	if "--match-offline" in OS.get_cmdline_user_args():
		print("[Main] Cargando escena de QA: MatchOffline")
		_change_scene.call_deferred("res://scenes/MatchOffline.tscn")
	else:
		_change_scene.call_deferred("res://scenes/Menu.tscn")


func _change_scene(path: String) -> void:
	var err: int = get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Main: error cargando %s (%d)" % [path, err])


func _install_perf_overlay() -> void:
	# El overlay vive en un CanvasLayer para sobrevivir cambios de escena.
	if get_tree().root.has_node(^"PerfOverlay"):
		return
	var scene: PackedScene = load("res://ui/hud/perf_overlay.tscn") as PackedScene
	if scene == null:
		return
	var overlay: CanvasLayer = scene.instantiate() as CanvasLayer
	overlay.name = "PerfOverlay"
	get_tree().root.call_deferred("add_child", overlay)
