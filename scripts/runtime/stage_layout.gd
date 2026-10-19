class_name StageLayout
extends RefCounted
## Fixed anchors of the battle diorama (bible p.16: "faste anchors").
## Domain positions (floor + index in the floor list) map to world positions
## here and nowhere else. Front (index 0) is next to the tree's centre line.

const FLOOR_Y: Array[float] = [0.0, 4.5, 9.0]
const HEART_Y := 12.4
const SPACE_W := 0.95   # metres per space point on the ally side
const CENTER_GAP := 0.75
const ENEMY_SPAN := 4.6


static func floor_y(f: int) -> float:
	return FLOOR_Y[clampi(f, 0, 2)]


## World position of an ally standing at `index` in `spaces` (space per unit, front first).
static func ally_pos(f: int, index: int, spaces: Array) -> Vector3:
	var before := 0.0
	for i in index:
		before += float(spaces[i])
	var own: float = float(spaces[index]) if index < spaces.size() else 1.0
	var x: float = -(CENTER_GAP + (before + own * 0.5) * SPACE_W)
	return Vector3(x, floor_y(f), _stagger(index))


## Insertion ghost position before `index` (index == size means behind everyone).
static func ally_slot_pos(f: int, index: int, spaces: Array) -> Vector3:
	var before := 0.0
	for i in index:
		before += float(spaces[i])
	return Vector3(-(CENTER_GAP + before * SPACE_W + 0.1), floor_y(f), 0.0)


static func enemy_pos(f: int, index: int, count: int, is_boss: bool = false) -> Vector3:
	var step: float = 1.1
	if count > 1:
		step = minf(1.1, ENEMY_SPAN / float(count - 1))
	var x: float = CENTER_GAP + 0.55 + float(index) * step
	if is_boss:
		x += 0.4
	return Vector3(x, floor_y(f), _stagger(index))


static func enemy_spawn_pos() -> Vector3:
	return Vector3(7.5, floor_y(0), 0.0)


static func heart_pos() -> Vector3:
	return Vector3(0.0, HEART_Y, -0.4)


static func _stagger(index: int) -> float:
	return 0.18 if index % 2 == 1 else -0.12
