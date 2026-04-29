## Smoke runner headless para la suite F2.
##
## Uso:
##   godot --headless --path . --script res://tools/run_f2_smoke.gd
##
## Sale con código 0 si todos los tests pasan, 1 si alguno falla.
extends SceneTree


func _initialize() -> void:
	var all_failures: Array = []
	var suites := [
		{"name": "test_meld",            "script": "res://tests/unit/test_meld.gd"},
		{"name": "test_opening",         "script": "res://tests/unit/test_opening_threshold.gd"},
		{"name": "test_pozo",            "script": "res://tests/unit/test_pozo_controller.gd"},
		{"name": "test_score",           "script": "res://tests/unit/test_score_calculator.gd"},
		{"name": "test_rules",           "script": "res://tests/unit/test_rules_engine.gd"},
		{"name": "test_fsm",             "script": "res://tests/fsm/test_fsm_basic.gd"},
		{"name": "test_integration_2v2", "script": "res://tests/integration/test_match_2v2.gd"},
	]

	print("=== F2 SMOKE RUNNER ===")
	for s in suites:
		var script: GDScript = load(s.script) as GDScript
		if script == null:
			all_failures.append("[%s] FAILED TO LOAD" % s.name)
			continue
		var failures: Array = script.run()
		if failures.is_empty():
			print("✓ %s" % s.name)
		else:
			print("✗ %s (%d failures)" % [s.name, failures.size()])
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
