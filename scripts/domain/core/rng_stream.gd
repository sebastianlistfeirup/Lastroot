class_name RngStream
extends RefCounted
## Deterministic, serializable random streams (bible p.20: separate streams for
## shuffle, route and reward; both seed and generator state are saved).
## A stream is a plain Dictionary {"seed": int, "state": int} so it clones and
## saves with the rest of the state. Algorithm: SplitMix32-style mixing on a
## 32-bit counter, all arithmetic masked to 32 bits.

const MASK := 0xFFFFFFFF


static func create(seed_value: int, salt: String) -> Dictionary:
	var s: int = (seed_value ^ _hash32(salt)) & MASK
	return {"seed": seed_value & MASK, "salt": salt, "state": s}


static func _hash32(text: String) -> int:
	var h: int = 2166136261
	for b: int in text.to_utf8_buffer():
		h = _mul32(h ^ b, 16777619)
	return h


## 32-bit multiply without relying on 64-bit overflow behavior.
static func _mul32(a: int, b: int) -> int:
	a &= MASK
	b &= MASK
	var lo: int = (a * (b & 0xFFFF)) & MASK
	var hi: int = ((a * (b >> 16)) & 0xFFFF) << 16
	return (lo + hi) & MASK


## Next raw 32-bit value; advances the stream in place.
static func next_u32(stream: Dictionary) -> int:
	var s: int = (int(stream["state"]) + 0x9E3779B9) & MASK
	stream["state"] = s
	var z: int = s
	z = _mul32(z ^ (z >> 16), 0x85EBCA6B)
	z = _mul32(z ^ (z >> 13), 0xC2B2AE35)
	return (z ^ (z >> 16)) & MASK


## Uniform integer in [0, n).
static func next_int(stream: Dictionary, n: int) -> int:
	if n <= 1:
		return 0
	return next_u32(stream) % n


## Fisher-Yates shuffle in place.
static func shuffle(stream: Dictionary, arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = next_int(stream, i + 1)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## Pick k distinct elements (order = pick order).
static func pick_distinct(stream: Dictionary, pool: Array, k: int) -> Array:
	var copy: Array = pool.duplicate()
	var out: Array = []
	while out.size() < k and copy.size() > 0:
		out.append(copy.pop_at(next_int(stream, copy.size())))
	return out
