class_name JsonUtil
extends RefCounted
## JSON helpers for the domain. Godot parses every JSON number as float; the
## domain only uses integers, so loaded data is normalized back to int. The
## canonical form (sorted keys) is what hashes and checksums are computed on.


static func normalize(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			var f: float = v
			if is_equal_approx(f, roundf(f)) and absf(f) < 9.0e15:
				return int(f)
			return f
		TYPE_DICTIONARY:
			var d: Dictionary = {}
			for k: Variant in (v as Dictionary).keys():
				d[k] = normalize(v[k])
			return d
		TYPE_ARRAY:
			var a: Array = []
			for x: Variant in v:
				a.append(normalize(x))
			return a
	return v


static func parse(text: String) -> Variant:
	var j := JSON.new()
	if j.parse(text) != OK:
		return null
	return normalize(j.data)


static func load_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return parse(FileAccess.get_file_as_string(path))


static func canonical(v: Variant) -> String:
	return JSON.stringify(v, "", true)


static func state_hash(v: Variant) -> String:
	return canonical(v).md5_text()
