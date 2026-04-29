## Tests del módulo OpeningThreshold.
extends RefCounted

const TestAssert := preload("res://tools/test_assert.gd")

static func run() -> Array:
	var failures: Array[String] = []

	var t := TestAssert.new("opening_thresholds")
	t.eq(OpeningThreshold.required_for(-50), 15, "negativo → 15")
	t.eq(OpeningThreshold.required_for(0), 50, "0 → 50")
	t.eq(OpeningThreshold.required_for(1499), 50, "1499 → 50")
	t.eq(OpeningThreshold.required_for(1500), 90, "1500 → 90")
	t.eq(OpeningThreshold.required_for(2999), 90, "2999 → 90")
	t.eq(OpeningThreshold.required_for(3000), 120, "3000 → 120")
	t.eq(OpeningThreshold.required_for(7000), 120, "alto → 120")
	t.is_true(OpeningThreshold.meets_threshold(0, 50), "exactamente cumple")
	t.is_false(OpeningThreshold.meets_threshold(0, 49), "no cumple")
	t.is_true(OpeningThreshold.meets_threshold(1500, 90), "tier mid cumple")
	t.is_false(OpeningThreshold.meets_threshold(3000, 119), "tier high no cumple")
	failures.append_array(t.failures)

	return failures
