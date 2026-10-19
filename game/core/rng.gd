class_name Rng
extends RefCounted
## A tiny deterministic random generator (mulberry32). Same seed, same numbers,
## on every platform; its whole state is one 32-bit int, so it saves to JSON
## exactly (Godot's own generator has a 64-bit state that JSON would round).

var state: int = 0


func _init(seed_value: int = 1) -> void:
	state = seed_value & 0xFFFFFFFF


## 32-bit multiply without 64-bit overflow.
static func imul(a: int, b: int) -> int:
	a &= 0xFFFFFFFF
	b &= 0xFFFFFFFF
	return ((a & 0xFFFF) * b + ((((a >> 16) * b) & 0xFFFF) << 16)) & 0xFFFFFFFF


func next_u32() -> int:
	state = (state + 0x6D2B79F5) & 0xFFFFFFFF
	var t: int = state
	t = imul(t ^ (t >> 15), t | 1)
	t = (t ^ ((t + imul(t ^ (t >> 7), t | 61)) & 0xFFFFFFFF)) & 0xFFFFFFFF
	return (t ^ (t >> 14)) & 0xFFFFFFFF


## 0 <= x < 1
func rand_float() -> float:
	return float(next_u32()) / 4294967296.0


## lo..hi inclusive.
func range_i(lo: int, hi: int) -> int:
	if hi <= lo:
		return lo
	return lo + next_u32() % (hi - lo + 1)


func chance(p: float) -> bool:
	return rand_float() < p


func pick(arr: Array) -> Variant:
	return arr[next_u32() % arr.size()] if not arr.is_empty() else null


func shuffle(arr: Array) -> void:
	for i: int in range(arr.size() - 1, 0, -1):
		var j: int = next_u32() % (i + 1)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## Picks a key of `weights` (key -> weight) in proportion to its weight.
func weighted(weights: Dictionary) -> Variant:
	var total: float = 0.0
	for k: Variant in weights:
		total += float(weights[k])
	var r: float = rand_float() * total
	for k: Variant in weights:
		r -= float(weights[k])
		if r < 0.0:
			return k
	return weights.keys()[weights.size() - 1]


## FNV-1a 32-bit hash of a string (stable seeds from dates and level ids).
static func hash_string(s: String) -> int:
	var h: int = 0x811C9DC5
	for b: int in s.to_utf8_buffer():
		h = imul(h ^ b, 0x01000193)
	return h
