## Smoke runner F6: tests de IA heurística para bots.
##
## Uso:
##   godot --headless --path . --script res://tools/run_f6_smoke.gd
##
## Sale con código 0 si todos los tests pasan, 1 si alguno falla.
extends SceneTree


func _initialize() -> void:
	GameConfig.bot_instant = true  # bots resuelven sin timer en tests
	var all_failures: Array = []
	var suites := [
		{"name": "test_hand_analyzer", "script": "res://tests/unit/test_hand_analyzer.gd"},
		{"name": "test_capture_eval",  "script": "res://tests/unit/test_capture_eval.gd"},
		{"name": "test_discard_picker","script": "res://tests/unit/test_discard_picker.gd"},
		{"name": "test_meld_planner",  "script": "res://tests/unit/test_meld_planner.gd"},
		{"name": "test_match_bots",    "script": "res://tests/integration/test_match_2v2_bots.gd"},
	]

	print("=== F6 SMOKE RUNNER ===")
	for s in suites:
		var script: GDScript = load(s.script) as GDScript
		if script == null:
			all_failures.append("[%s] FAILED TO LOAD" % s.name)
			print("✗ %s NO SE PUDO CARGAR" % s.name)
			continue
		var failures: Array = script.run()
		if failures.is_empty():
			print("✓ %s" % s.name)
		else:
			print("✗ %s (%d fallos)" % [s.name, failures.size()])
			for f in failures:
				print("    %s" % f)
				all_failures.append(f)

	print("=======================")
	if all_failures.is_empty():
		print("ALL PASS")
		quit(0)
	else:
		print("FAILED: %d total" % all_failures.size())
		quit(1)
