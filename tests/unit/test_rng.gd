extends TestCase
## Seed contract: separate streams, saved state, reproducible.


func test_streams_are_reproducible() -> void:
	var a := RngStream.create(99, "shuffle")
	var b := RngStream.create(99, "shuffle")
	for i in 50:
		eq(RngStream.next_u32(a), RngStream.next_u32(b), "same sequence")


func test_streams_are_independent() -> void:
	var a := RngStream.create(99, "shuffle")
	var b := RngStream.create(99, "route")
	var same := 0
	for i in 20:
		if RngStream.next_u32(a) == RngStream.next_u32(b):
			same += 1
	check(same < 2, "different salts give different sequences")


func test_state_survives_json_roundtrip() -> void:
	var a := RngStream.create(5, "reward")
	RngStream.next_u32(a)
	var b: Dictionary = JsonUtil.parse(JSON.stringify(a))
	eq(RngStream.next_u32(a), RngStream.next_u32(b), "continues identically after save/load")


func test_range_and_distribution() -> void:
	var a := RngStream.create(1, "x")
	var buckets := [0, 0, 0, 0]
	for i in 4000:
		var v := RngStream.next_int(a, 4)
		check(v >= 0 and v < 4, "in range")
		buckets[v] += 1
	for c: int in buckets:
		check(c > 850 and c < 1150, "roughly uniform %s" % [buckets])


func test_route_uses_route_stream_only() -> void:
	var r1 := RunReducer.new_run(123, "BARK")
	var r2 := RunReducer.new_run(123, "SPORE")
	eq(JsonUtil.canonical(r1["route"]), JsonUtil.canonical(r2["route"]), "faction does not change the route")
