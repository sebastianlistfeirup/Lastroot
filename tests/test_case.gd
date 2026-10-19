class_name TestCase
extends RefCounted
## Minimal assertion helper. Test files extend TestCase and define test_* methods.

var failures: PackedStringArray = []
var current: String = ""


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append("%s: %s" % [current, msg])


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%s: %s (expected %s, got %s)" % [current, msg, var_to_str(expected), var_to_str(actual)])
