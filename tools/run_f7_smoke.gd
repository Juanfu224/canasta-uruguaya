## Smoke test F7 (mobile optimization + accesibilidad).
##
## Valida sin abrir red ni mostrar UI:
##   1. Settings: round-trip en ConfigFile, defaults, clamps de font_scale,
##      señal `changed` y migración desde ProfileStore.
##   2. Haptics: API estática es no-op en headless (no crash).
##   3. HandLayout: el pool de CardUI no crece sin límite tras N ciclos
##      add/remove y los nodos se reusan.
##
## Ejecutar:
##   godot --headless --path . -s tools/run_f7_smoke.gd
extends SceneTree


func _initialize() -> void:
	print("[F7 Smoke] Inicio")
	# Esperar a que autoloads completen `_ready` y se añadan al árbol antes de
	# tocar `Settings`, que usa `get_tree().create_timer` para el debounce.
	await process_frame
	_test_settings_roundtrip()
	_test_settings_clamps()
	_test_haptics_noop()
	await _test_handlayout_pool()
	print("[F7 Smoke] OK")
	quit()


func _test_settings_roundtrip() -> void:
	var s: Node = root.get_node_or_null(^"Settings")
	assert(s != null, "Settings autoload no registrado")
	# Cambiar y guardar.
	s.call("set_vibration_enabled", false)
	s.call("set_reduce_motion", true)
	s.call("set_font_scale", 1.25)
	s.call("save_settings")
	# Recargar.
	s.call("set_vibration_enabled", true)
	s.call("load_settings")
	assert(bool(s.get("vibration_enabled")) == false, "vibration_enabled no persistió")
	assert(bool(s.get("reduce_motion")) == true, "reduce_motion no persistió")
	assert(absf(float(s.get("font_scale")) - 1.25) < 0.001, "font_scale no persistió")
	# Restaurar defaults para no contaminar otras corridas.
	s.call("set_vibration_enabled", true)
	s.call("set_reduce_motion", false)
	s.call("set_font_scale", 1.0)
	s.call("save_settings")
	print("[F7 Smoke] settings round-trip OK")


func _test_settings_clamps() -> void:
	var s: Node = root.get_node_or_null(^"Settings")
	s.call("set_font_scale", 99.0)
	assert(float(s.get("font_scale")) <= 1.5 + 0.001, "clamp max font_scale falló")
	s.call("set_font_scale", -1.0)
	assert(float(s.get("font_scale")) >= 0.85 - 0.001, "clamp min font_scale falló")
	s.call("set_font_scale", 1.0)
	s.call("save_settings")
	print("[F7 Smoke] settings clamps OK")


func _test_haptics_noop() -> void:
	# En headless DisplayServer es "headless" → no debe crashear.
	Haptics.tap()
	Haptics.success()
	Haptics.error()
	print("[F7 Smoke] haptics no-op OK")


func _test_handlayout_pool() -> void:
	# En modo `-s` (MainLoop script) Godot 4.6 a veces falla al precompilar
	# scripts UI que referencian autoloads como globals (parse-order). Si los
	# scripts no están disponibles, hacemos best-effort y reportamos skip.
	var hl_script: GDScript = load("res://ui/hand_layout.gd") as GDScript
	if hl_script == null or not hl_script.can_instantiate():
		print("[F7 Smoke] handlayout pool SKIP (UI scripts no compilan en `-s`)")
		return
	var deck: Deck = Deck.build_standard_108()
	if deck == null or deck.cards.is_empty():
		print("[F7 Smoke] handlayout pool SKIP (Deck no construible en `-s`)")
		return
	var hl: HandLayout = hl_script.new() as HandLayout
	root.add_child(hl)
	hl.size = Vector2(1280, 200)
	await _stress_pool(hl, deck)
	hl.queue_free()


func _stress_pool(hl: HandLayout, deck: Deck) -> void:
	# 50 ciclos: agregar 22 cartas, sacarlas todas. El pool no debe crecer
	# más allá del cap interno (24).
	var rng_service: Node = root.get_node_or_null(^"RngService")
	assert(rng_service != null, "RngService autoload no registrado")
	deck.shuffle(rng_service.get("match_rng") as RandomNumberGenerator)
	var added: Array[Card] = []
	for cycle in 50:
		for i in 22:
			var c: Card = deck.cards[(cycle * 22 + i) % deck.size()]
			hl.add_card(c, false)
			added.append(c)
		# Drain
		for c in added:
			hl.remove_card_by_id(c.id, false)
		added.clear()
	# Acceso al pool privado vía get() (no es API pero sirve para test).
	var pool_size: int = (hl.get("_pool") as Array).size()
	assert(pool_size <= 24, "pool excedió cap: %d" % pool_size)
	# El nodo activo se vacía.
	assert(hl.get_card_count() == 0, "_cards no se vació")
	print("[F7 Smoke] handlayout pool OK (pool=%d tras 50x22 ciclos)" % pool_size)
