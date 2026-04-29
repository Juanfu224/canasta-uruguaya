## Pequeño helper de aserciones para los smoke tests headless.
## Acumula errores en lugar de abortar para reportar todos al final.
class_name TestAssert
extends RefCounted

var failures: Array[String] = []
var test_name: String = ""

func _init(name_arg: String = "") -> void:
	test_name = name_arg

func eq(actual, expected, msg: String = "") -> void:
	if actual != expected:
		failures.append("[%s] EQ FAIL: %s  expected=%s actual=%s"
			% [test_name, msg, str(expected), str(actual)])

func is_true(v: bool, msg: String = "") -> void:
	if not v:
		failures.append("[%s] TRUE FAIL: %s" % [test_name, msg])

func is_false(v: bool, msg: String = "") -> void:
	if v:
		failures.append("[%s] FALSE FAIL: %s" % [test_name, msg])

func not_null(v, msg: String = "") -> void:
	if v == null:
		failures.append("[%s] NOT_NULL FAIL: %s" % [test_name, msg])

func ok() -> bool:
	return failures.is_empty()
