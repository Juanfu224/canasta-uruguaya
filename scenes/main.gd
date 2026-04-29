## Punto de entrada de la app.
##
## Por ahora (F1) solo loguea el estado de los autoloads y deja la pantalla
## en negro. La transición a Lobby/Menu se cablea en F3.
extends Node


func _ready() -> void:
	# Per CLAUDE.md / arquitectura: el drag&drop táctil necesita eventos
	# crudos sin acumular para latencia <50ms.
	Input.use_accumulated_input = false

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
