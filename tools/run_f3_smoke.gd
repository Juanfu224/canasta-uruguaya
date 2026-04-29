## Smoke runner headless para la suite F3.
##
## Uso:
##   godot --headless --path . --script res://tools/run_f3_smoke.gd
##
## Sale con código 0 si todos los tests pasan, 1 si alguno falla. Solo
## ejecuta tests que no dependan de un viewport visible (matemática pura).
extends SceneTree


func _initialize() -> void:
	var all_failures: Array = []
	var suites := [
		{"name": "test_hand_layout", "script": "res://tests/unit/test_hand_layout.gd"},
	]

	print("=== F3 SMOKE RUNNER ===")
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
