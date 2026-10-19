class_name BattlePresenter
extends Node
## Plays the reducer's immutable events (bible p.19 "Event Player"). The
## outcome is already decided and saved; this only dramatizes it. Every wait
## is a timer, never an animation callback, so a missing clip can never lock
## the run. Skip jumps straight to the final state; 0.5x/1x/2x only scale time.

signal finished

var screen: Node  # BattleScreen
var speed: float = 1.0
var playing: bool = false
var _skip: bool = false


func skip() -> void:
	_skip = true


func _wait(t: float) -> void:
	if _skip or t <= 0.0:
		return
	await get_tree().create_timer(t / maxf(speed, 0.1)).timeout


## `disp` = per-unit display snapshots (from the state before the command),
## mutated as events land. `final` may be empty when the battle just ended.
func play(events: Array, disp: Dictionary) -> void:
	playing = true
	_skip = false
	for e: Dictionary in events:
		if _skip:
			break
		await _step(e, disp)
	playing = false
	finished.emit()


func _snap_into(disp: Dictionary, uid: int, snap: Variant) -> void:
	if typeof(snap) != TYPE_DICTIONARY:
		return
	var key := str(uid)
	if not disp.has(key):
		return
	for k: String in (snap as Dictionary).keys():
		disp[key][k] = snap[k]
	screen.refresh_badge(uid)


func _step(e: Dictionary, disp: Dictionary) -> void:
	var kind: String = e["kind"]
	var tid: int = int(e.get("target_id", -1))
	var aid: int = int(e.get("actor_id", -1))
	match kind:
		"turn_begin":
			screen.toast(Loc.t("Turn %d") % int(e["turn"]), UiKit.TEXT)
			await _wait(0.35)
		"resolution_begin":
			screen.toast(Loc.t("The tree resolves"), UiKit.LIFE)
			await _wait(0.25)
		"floor_begin":
			screen.stage.highlight_floor(int(e["floor"]), true)
			screen.focus_floor(int(e["floor"]))
			await _wait(0.12)
		"floor_end":
			screen.stage.highlight_floor(int(e["floor"]), false)
		"wave_arrived":
			screen.toast(Loc.t("Wave %d of %d arrives on the Roots") % [int(e["wave"]), int(e["of"])], Color("ff8a4a"))
			AudioBridge.play("wave_arrive")
			await _wait(0.3)
		"enemy_spawned":
			var u: Dictionary = (screen.unit_snapshot(tid) as Dictionary).duplicate()
			u.merge(e.get("after", {}), true)
			disp[str(tid)] = u
			var v: UnitView = screen.spawn_view(u, StageLayout.enemy_spawn_pos())
			v.play(&"move", speed)
			screen.layout_floor(0, disp, 0.45 / speed)
			if u.get("is_boss", false):
				screen.toast(Loc.t("The Ash Crown has arrived"), UiKit.DANGER)
				AudioBridge.play("boss_arrive")
			await _wait(0.3)
		"card_played":
			var def: Dictionary = Catalog.card(str(e["def_id"]))
			screen.toast(Loc.field(def, "name"), UiKit.faction_color(def.get("faction", "BARK")))
			AudioBridge.play("card_play" if Catalog.is_creature(def) else "spell_cast")
			await _wait(0.12)
		"unit_inserted":
			var u: Dictionary = (screen.unit_snapshot(tid) as Dictionary).duplicate()
			u.merge(e.get("after", {}), true)
			disp[str(tid)] = u
			var f: int = int(e["floor"])
			var v: UnitView = screen.spawn_view(u, StageLayout.ally_pos(f, 0, [1]))
			screen.layout_floor(f, disp, 0.0)
			v.play(&"summon", speed)
			AudioBridge.play("unit_summon")
			await _wait(0.3)
		"attack":
			var v: UnitView = screen.view(aid)
			if v != null:
				var contact: float = v.play(&"cast" if v.def_id.begins_with("S") else &"attack", speed)
				if v.def_id.begins_with("S") and v.side == "ally":
					screen.bolt(aid, tid, maxf(contact, 0.15))
				AudioBridge.play("attack_enemy" if v.side == "enemy" else ("attack_spore" if v.def_id.begins_with("S") else "attack_bark"))
				await _wait(contact * speed)
		"damage", "thorns":
			var v: UnitView = screen.view(tid)
			if v != null:
				v.play(&"hit", speed)
			var absorbed: int = int(e.get("absorbed", 0))
			var dealt: int = int(e["amount"]) - absorbed
			if kind == "thorns":
				screen.popup(tid, "%s%d" % [UiKit.status_glyph("thorns"), int(e["amount"])], UiKit.AMBER)
			if absorbed > 0:
				screen.popup(tid, "%s-%d" % [UiKit.status_glyph("armor"), absorbed], UiKit.ARMOR)
				AudioBridge.play("armor_block")
			if dealt > 0:
				screen.popup(tid, "-%d" % dealt, UiKit.DANGER)
				screen.fx_at(tid, "fx.bark_hit" if kind == "damage" else "fx.thorns")
				AudioBridge.play("hit")
			_snap_into(disp, tid, e.get("after"))
			await _wait(0.22)
		"poison_tick":
			screen.popup(tid, "%s-%d" % [UiKit.status_glyph("poison"), int(e["amount"])], UiKit.POISON)
			AudioBridge.play("poison_tick")
			screen.fx_at(tid, "fx.poison")
			var v: UnitView = screen.view(tid)
			if v != null:
				v.play(&"hit", speed)
			_snap_into(disp, tid, e.get("after"))
			await _wait(0.22)
		"poison_applied", "poison_bloomed":
			var amt: String = ("+%d" % int(e["amount"])) if e.has("amount") else "×2"
			screen.popup(tid, "%s%s" % [UiKit.status_glyph("poison"), amt], UiKit.POISON)
			AudioBridge.play("poison_apply")
			_snap_into(disp, tid, e.get("after"))
			await _wait(0.14)
		"heal":
			screen.popup(tid, "+%d" % (int(e["after"]["hp"]) - int(e["before"]["hp"])), UiKit.GOOD)
			AudioBridge.play("heal")
			screen.fx_at(tid, "fx.heal")
			_snap_into(disp, tid, e.get("after"))
			await _wait(0.14)
		"armor_gained", "armor_stripped":
			var sign: String = "+" if kind == "armor_gained" else "-"
			screen.popup(tid, "%s%s%d" % [UiKit.status_glyph("armor"), sign, int(e["amount"])], UiKit.ARMOR)
			if kind == "armor_gained":
				screen.fx_at(tid, "fx.armor")
			_snap_into(disp, tid, e.get("after"))
			await _wait(0.14)
		"growth_gained", "max_hp_gained":
			screen.popup(tid, "%s+%d" % [UiKit.status_glyph("growth" if kind == "growth_gained" else "hp"), int(e["amount"])], UiKit.LIFE)
			_snap_into(disp, tid, e.get("after"))
			await _wait(0.1)
		"death":
			var v: UnitView = screen.view(tid)
			if v != null:
				v.play(&"death", speed)
			AudioBridge.play("death_ally" if str(e["side"]) == "ally" else "death_enemy")
			if str(e["side"]) == "enemy":
				screen.fx_at(tid, "fx.ash_death")
			if disp.has(str(tid)):
				disp[str(tid)]["alive"] = false
			await _wait(0.35)
			screen.remove_view(tid)
			screen.layout_floor(int(e["floor"]), disp, 0.25 / speed)
		"unit_removed":
			if disp.has(str(tid)):
				disp[str(tid)]["alive"] = false
			screen.remove_view(tid)
			screen.layout_floor(int(e["floor"]), disp, 0.25 / speed)
			await _wait(0.2)
		"unit_moved", "unit_lifted":
			if disp.has(str(tid)):
				disp[str(tid)]["floor"] = int(e["to_floor"])
			screen.layout_all(disp, 0.35 / speed)
			await _wait(0.3)
		"enemy_climbed":
			if disp.has(str(aid)):
				disp[str(aid)]["floor"] = int(e["to_floor"])
			screen.layout_all(disp, 0.45 / speed)
			AudioBridge.play("enemy_climb")
			await _wait(0.12)
		"heart_damaged":
			var v: UnitView = screen.view(aid)
			if v != null:
				v.move_to(StageLayout.heart_pos(), 0.35 / speed)
			await _wait(0.35)
			screen.remove_view(aid)
			if disp.has(str(aid)):
				disp[str(aid)]["alive"] = false
			screen.stage.hurt_heart()
			screen.heart_hit(int(e["amount"]), int(e["after"]), str(disp.get(str(aid), {}).get("def_id", "")))
			AudioBridge.play("heart_hit")
			await _wait(0.4)
		"boss_anchored":
			screen.popup(aid, Loc.t("Anchored"), UiKit.AMBER)
			await _wait(0.2)
		"boss_escalated":
			screen.popup(aid, "%s+2" % UiKit.status_glyph("attack"), UiKit.DANGER)
			AudioBridge.play("boss_escalate")
			await _wait(0.3)
		"boss_escaped":
			screen.toast(Loc.t("The Ash Crown has left the Crown!"), UiKit.DANGER)
			screen.stage.hurt_heart()
			await _wait(0.6)
		"on_death_effect":
			screen.toast(Loc.t("Spore Colossus bursts"), UiKit.POISON)
			await _wait(0.15)
		"deck_shuffled":
			screen.toast(Loc.t("Discard pile shuffled into the draw pile"), UiKit.TEXT_DIM)
		"battle_won":
			AudioBridge.play("victory")
			screen.stage.pulse_heart(1.5)
			await _wait(0.4)
		"battle_lost":
			AudioBridge.play("defeat")
			await _wait(0.4)
		"resolution_end":
			screen.focus_floor(-1)
			await _wait(0.1)
