extends Node
## LR-28 layout smoke: opens every main screen at the window sizes we support
## and checks that no text is clipped and touch targets are big enough.
##   XDG_DATA_HOME=/tmp/xdg_x godot --headless --path . res://scenes/tests/layout_smoke.tscn [-- --quick]
## Each screen is mounted in a SubViewport with the *logical* size AppFlow
## would give that window (content_scale_size: landscape >= 1280 -> 1920x1080,
## portrait -> 430 wide), so layout is identical to the real window.
## Checks, for every visible Label/Button/RichTextLabel with text:
##   text_truncated   ellipsis / clip_text cut the string (text wider than rect)
##   text_lines_cut   wrapped label shows fewer lines than it has
##   outside_view     rect leaves the viewport or a clipping parent (allowed
##                    only along an axis a ScrollContainer ancestor scrolls)
## and, on touch-size windows, every enabled button / tappable is >= 44 px
## (CSS px of the device, i.e. logical px x window/logical scale) both ways.
## Writes evidence/layout/layout_report.json; exit 1 on any violation.

const MENU := "res://scenes/menu/main_menu.tscn"
const RUN := "res://scenes/flow/run_screen.tscn"
const RESULT := "res://scenes/flow/result_screen.tscn"
const BATTLE := "res://scenes/battle/battle.tscn"
const OUT := "res://evidence/layout/layout_report.json"
const TOUCH_MIN := 44.0

## window size (device CSS px) -> touch device?
const WINDOWS := [
	{"id": "desktop_1280x720", "size": Vector2i(1280, 720), "touch": false},
	{"id": "desktop_1920x1080", "size": Vector2i(1920, 1080), "touch": false},
	{"id": "phone_430x932", "size": Vector2i(430, 932), "touch": true},
	{"id": "tablet_1024x1366", "size": Vector2i(1024, 1366), "touch": true},
]
## scale -1 = the largest choice in Settings (SettingsService.TEXT_SCALES[-1]);
## --stress adds 150 % (beyond the menu, clamp limit) as an extra margin check.
const TEXT_MODES := [
	{"id": "en_1.0", "lang": "en", "scale": 1.0},
	{"id": "en_max", "lang": "en", "scale": -1.0},
]
const STRESS_MODES := [
	{"id": "en_1.5", "lang": "en", "scale": 1.5},
]

var violations: Array = []
var warnings: Array = []
var accepted: Array = []
var known: Array = []
## Real problems found by this test that are NOT fixed yet (owner outside the
## LR-28 layout pass). Listed in the report as known issues, not as passes.
const KNOWN_ISSUES := []
## Deliberate truncations that are not lost information (reviewed, LR-28).
const ACCEPTED := [
	{"kind": "text_truncated", "path": "TopBar", "prefix": "⚑",
		"reason": "Portrait battle top bar: the wave preview ellipsizes by design so the bar stays one row; the full wave text is in the forecast sheet and the route map."},
	{"kind": "text_truncated", "path": "SheetSummary", "prefix": "",
		"reason": "Portrait forecast summary button: one-line teaser that opens the full forecast sheet when tapped."},
]
var screens_checked := 0
var controls_checked := 0
var per_config: Dictionary = {}
var _cfg: String = ""
var _settings_was: Dictionary = {}
var _settings_bytes: PackedByteArray = PackedByteArray()


func _ready() -> void:
	var t0: int = Time.get_ticks_msec()
	if FileAccess.file_exists(SettingsService.PATH):
		_settings_bytes = FileAccess.get_file_as_bytes(SettingsService.PATH)
	_settings_was = SettingsService.snapshot()
	var onboarding_was: bool = SettingsService.onboarding_done
	SettingsService.onboarding_done = true
	var quick: bool = OS.get_cmdline_user_args().has("--quick")
	var only_w: String = ""
	var only_t: String = ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--window="):
			only_w = a.get_slice("=", 1)
		if a.begins_with("--text="):
			only_t = a.get_slice("=", 1)
	var modes: Array = TEXT_MODES.duplicate()
	if OS.get_cmdline_user_args().has("--stress"):
		modes.append_array(STRESS_MODES)
	for w: Dictionary in WINDOWS:
		if only_w != "" and not str(w["id"]).begins_with(only_w):
			continue
		for tm: Dictionary in modes:
			if (quick and tm["id"] == "en_1.0") or (only_t != "" and tm["id"] != only_t):
				continue
			_cfg = "%s/%s" % [w["id"], tm["id"]]
			per_config[_cfg] = {"screens": 0, "violations": 0}
			SettingsService.set_language(tm["lang"])
			SettingsService.set_text_scale(float(tm["scale"]) if float(tm["scale"]) > 0.0 else float(SettingsService.TEXT_SCALES[-1]))
			await _all_screens(w)
	SettingsService.onboarding_done = onboarding_was
	SettingsService.set_language(str(_settings_was.get("language", "en")))
	SettingsService.set_text_scale(float(_settings_was.get("text_scale", 1.0)))
	if not _settings_bytes.is_empty():
		var sf := FileAccess.open(SettingsService.PATH, FileAccess.WRITE)
		sf.store_buffer(_settings_bytes)
		sf.close()
	SaveService.delete_run()
	var ms: int = Time.get_ticks_msec() - t0
	var by_kind := {}
	for v: Dictionary in violations:
		by_kind[v["kind"]] = int(by_kind.get(v["kind"], 0)) + 1
	for v: Dictionary in violations.slice(0, 40):
		print("LAYOUT_FAIL %s %s %s %s '%s' %s" % [v["config"], v["screen"], v["kind"], v["node"], v["text"], v["detail"]])
	print("LAYOUT_SMOKE %d screens, %d controls, %d violations, %d known issues, %d accepted, %d warnings, %d ms" % [screens_checked, controls_checked, violations.size(), known.size(), accepted.size(), warnings.size(), ms])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence/layout"))
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"engine_version": Engine.get_version_info()["string"],
		"timestamp": Time.get_datetime_string_from_system(true),
		"command": "godot --headless --path . res://scenes/tests/layout_smoke.tscn",
		"windows": WINDOWS.map(func(w: Dictionary) -> Dictionary:
			return {"id": w["id"], "size": [w["size"].x, w["size"].y], "logical": [_logical(w["size"]).x, _logical(w["size"]).y], "touch": w["touch"]}),
		"text_modes": modes, "max_text_scale": SettingsService.TEXT_SCALES[-1], "touch_min_px": TOUCH_MIN,
		"screens_checked": screens_checked, "controls_checked": controls_checked,
		"violations_by_kind": by_kind, "per_config": per_config,
		"violations": violations, "warnings": warnings, "accepted": accepted, "known_issues": known, "duration_ms": ms,
		"note": "Headless: fonts are the project fonts, shaped by the real TextServer; nothing is rendered. 1280x720 and 1920x1080 share the 1920x1080 logical layout (AppFlow), so they differ only in physical size.",
		"status": "PASS" if violations.is_empty() else "FAIL",
	}, "  ", true))
	f.close()
	get_tree().quit(0 if violations.is_empty() else 1)


## AppFlow._apply_scale, same rule.
static func _logical(sz: Vector2i) -> Vector2i:
	if sz.y > sz.x:
		return Vector2i(430, int(430.0 * float(sz.y) / float(sz.x)))
	if sz.x < 1280:
		return Vector2i(1280, int(1280.0 * float(sz.y) / float(sz.x)))
	return Vector2i(1920, 1080)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _mount(path: String, run: Dictionary, size: Vector2i, extra: Dictionary = {}) -> Node:
	GameSession.run = run.duplicate(true)
	GameSession.presentation_pending = false
	var sv := SubViewport.new()
	sv.size = size
	sv.disable_3d = path != BATTLE
	add_child(sv)
	var s: Node = (load(path) as PackedScene).instantiate()
	s.set("auto_navigate", false)
	for k: String in extra:
		s.set(k, extra[k])
	sv.add_child(s)
	await _frames(3)
	return s


func _unmount(s: Node) -> void:
	s.get_parent().queue_free()
	await _frames(1)


func _all_screens(w: Dictionary) -> void:
	var lsize: Vector2i = _logical(w["size"])
	var scale: float = float(w["size"].x) / float(lsize.x)
	var touch: bool = w["touch"]
	# ---- main menu and its modals
	var m: Node = await _mount(MENU, {}, lsize)
	_check(m, "menu_title", lsize, scale, touch)
	for modal: String in ["SettingsPanel", "CreditsPanel"]:
		var p: Node = m.find_child(modal, true, false)
		p.call("open")
		await _frames(3)
		_check(p, "menu_" + modal, lsize, scale, touch)
		p.call("close")
		await _frames(1)
	var h: Node = m.find_child("HowToPlayPanel", true, false)
	h.call("open")
	for i in int(h.call("page_count")):
		h.call("goto_page", i)
		await _frames(2)
		_check(h, "how_to_play_page%d" % (i + 1), lsize, scale, touch)
	h.call("close")
	m.call("show_faction_select")
	await _frames(3)
	_check(m, "champion_select", lsize, scale, touch)
	await _unmount(m)
	SettingsService.onboarding_done = false
	m = await _mount(MENU, {}, lsize, {"view": "first_run"})
	m.set("view", "first_run")
	m.call("_build")
	await _frames(2)
	_check(m, "menu_first_run", lsize, scale, touch)
	await _unmount(m)
	SettingsService.onboarding_done = true
	# ---- run screens
	for t: String in ["card", "mutation", "champion", "relic"]:
		var s: Node = await _mount(RUN, MetaFixtures.reward_slot(t), lsize)
		_check(s, "reward_" + t, lsize, scale, touch)
		await _unmount(s)
	var r: Node = await _mount(RUN, MetaFixtures.route(1), lsize)
	_check(r, "route", lsize, scale, touch)
	await _unmount(r)
	for t: String in ["camp", "card", "encounter", "removal"]:
		var s: Node = await _mount(RUN, MetaFixtures.node(t), lsize)
		_check(s, "node_" + t, lsize, scale, touch)
		await _unmount(s)
	for t: String in ["won", "lost"]:
		var run: Dictionary = MetaFixtures.won() if t == "won" else MetaFixtures.lost()
		var s: Node = await _mount(RESULT, run, lsize)
		await _frames(2)
		_check(s, "result_" + t, lsize, scale, touch)
		await _unmount(s)
	# ---- battle
	for fx: String in ["battle1", "midbattle", "boss"]:
		var b: Node = await _mount(BATTLE, DebugFixtures.make(fx, "BARK", 2), lsize)
		await _frames(4)
		var pres: Variant = b.get("presenter")
		if pres != null:
			for i in 300:
				if not bool(pres.get("playing")):
					break
				pres.call("skip")
				await get_tree().process_frame
		await _frames(2)
		_check(b, "battle_" + fx, lsize, scale, touch)
		if fx == "midbattle" and bool(b.get("portrait")):
			b.call("set_sheet_open", true)
			await _frames(3)
			_check(b, "battle_forecast_sheet", lsize, scale, touch)
			b.call("set_sheet_open", false)
		if fx == "battle1":
			b.call("_open_menu")
			await _frames(3)
			var pm: Node = b.get("_pause")
			if pm != null:
				_check(pm, "battle_pause_menu", lsize, scale, touch)
		await _unmount(b)


# ------------------------------------------------------------------ checker

func _check(root: Node, screen: String, vp: Vector2i, scale: float, touch: bool) -> void:
	screens_checked += 1
	per_config[_cfg]["screens"] = int(per_config[_cfg]["screens"]) + 1
	var view := Rect2(Vector2.ZERO, Vector2(vp))
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if not (n is Control):
			continue
		var c: Control = n
		if not c.is_visible_in_tree() or c.size.x <= 0.5 or c.size.y <= 0.5 or _alpha(c) < 0.05:
			continue
		var text: String = _text_of(c)
		var interactive: bool = (c is BaseButton or c is Slider or c.has_signal("pressed")) and not (c is BaseButton and (c as BaseButton).disabled)
		if text == "" and not interactive:
			continue
		controls_checked += 1
		var rect: Rect2 = _rect(c)
		if text != "":
			_check_text(c, text, screen)
		_check_bounds(c, rect, view, screen, text)
		if touch and interactive and c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			var phys: Vector2 = rect.size * scale
			if phys.x < TOUCH_MIN - 0.5 or phys.y < TOUCH_MIN - 0.5:
				_fail(c, screen, "touch_target_small", text, "%dx%d px on device (min %d)" % [int(phys.x), int(phys.y), int(TOUCH_MIN)])


func _text_of(c: Control) -> String:
	if c is Label:
		return (c as Label).text.strip_edges()
	if c is Button:
		return (c as Button).text.strip_edges()
	if c is RichTextLabel:
		return (c as RichTextLabel).get_parsed_text().strip_edges()
	return ""


func _alpha(c: CanvasItem) -> float:
	var a := 1.0
	var n: Node = c
	while n != null and n is CanvasItem:
		a *= (n as CanvasItem).modulate.a * (n as CanvasItem).self_modulate.a if n == c else (n as CanvasItem).modulate.a
		n = n.get_parent()
	return a


func _rect(c: Control) -> Rect2:
	var xf: Transform2D = c.get_global_transform_with_canvas()
	return Rect2(xf.origin, c.size * xf.get_scale())


func _check_text(c: Control, text: String, screen: String) -> void:
	if c is Label:
		var l: Label = c
		var font: Font = l.get_theme_font("font")
		var fs: int = l.get_theme_font_size("font_size")
		if l.autowrap_mode == TextServer.AUTOWRAP_OFF:
			var w: float = font.get_multiline_string_size(l.text, l.horizontal_alignment, -1, fs).x
			if w > l.size.x + 1.5 and (l.clip_text or l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING):
				_fail(c, screen, "text_truncated", text, "needs %d px, has %d" % [int(w), int(l.size.x)])
			elif w > l.size.x + 1.5:
				_fail(c, screen, "text_overflows_rect", text, "needs %d px, has %d" % [int(w), int(l.size.x)])
		else:
			if l.get_visible_line_count() < l.get_line_count() and l.visible_characters < 0:
				_fail(c, screen, "text_lines_cut", text, "%d of %d lines visible" % [l.get_visible_line_count(), l.get_line_count()])
			# a single word wider than the label cannot wrap
			for word in l.text.split(" ", false):
				var ww: float = font.get_string_size(word.strip_edges(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				if ww > l.size.x + 1.5:
					# WORD_SMART / ARBITRARY force-break the word (readable, not cut): warning only
					if l.autowrap_mode == TextServer.AUTOWRAP_WORD:
						_fail(c, screen, "word_wider_than_label", text, "'%s' needs %d px, has %d" % [word, int(ww), int(l.size.x)])
					else:
						warnings.append({"config": _cfg, "screen": screen, "kind": "word_force_broken", "node": _path(c),
							"text": text.left(60), "detail": "'%s' needs %d px, has %d" % [word, int(ww), int(l.size.x)]})
					break
	elif c is Button:
		var b: Button = c
		var font: Font = b.get_theme_font("font")
		var fs: int = b.get_theme_font_size("font_size")
		var sb: StyleBox = b.get_theme_stylebox("normal")
		var need: float = font.get_multiline_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		need += sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT) if sb else 0.0
		if b.icon != null and not b.expand_icon:
			need += b.icon.get_width() + b.get_theme_constant("h_separation")
		if b.autowrap_mode == TextServer.AUTOWRAP_OFF and need > b.size.x + 1.5:
			var cut: bool = b.clip_text or b.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING
			_fail(c, screen, "text_truncated" if cut else "text_overflows_rect", text, "needs %d px, has %d" % [int(need), int(b.size.x)])


## Must lie inside the viewport and every clipping ancestor, except along an
## axis that a ScrollContainer ancestor scrolls (then the scroll itself counts).
func _check_bounds(c: Control, rect: Rect2, view: Rect2, screen: String, text: String) -> void:
	var allow_x := false
	var allow_y := false
	var clip: Rect2 = view
	var p: Node = c.get_parent()
	while p != null and not (p is Viewport):
		if p is ScrollContainer:
			var sc: ScrollContainer = p
			if sc.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
				allow_x = true
			if sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
				allow_y = true
			clip = clip.intersection(_rect(sc))
		elif p is Control and (p as Control).clip_contents:
			clip = clip.intersection(_rect(p as Control))
		p = p.get_parent()
	var tol := 1.5
	var out_x: bool = rect.position.x < clip.position.x - tol or rect.end.x > clip.end.x + tol
	var out_y: bool = rect.position.y < clip.position.y - tol or rect.end.y > clip.end.y + tol
	if (out_x and not allow_x) or (out_y and not allow_y):
		var why: String = ""
		if out_x and not allow_x:
			why = " widest: " + _widest(c, clip.size.x)
		_fail(c, screen, "outside_view", text, "rect %s vs visible %s%s" % [_r(rect), _r(clip), why])


## Diagnostic: the deepest Control under c's top-level container whose minimum
## width alone exceeds the visible width (what forces the overflow).
func _widest(c: Control, limit: float) -> String:
	var top: Node = c
	while top.get_parent() is Control and not (top.get_parent() is ScrollContainer):
		top = top.get_parent()
	var best: Control = null
	var best_depth := -1
	var stack: Array = [[top, 0]]
	while not stack.is_empty():
		var e: Array = stack.pop_back()
		var n: Node = e[0]
		for ch in n.get_children():
			stack.append([ch, int(e[1]) + 1])
		if n is Control and (n as Control).is_visible_in_tree() and (n as Control).get_combined_minimum_size().x > limit + 1.5 and int(e[1]) > best_depth:
			best = n
			best_depth = e[1]
	if best == null:
		return "-"
	return "%s %s min %d '%s'" % [best.get_class(), best.name, int(best.get_combined_minimum_size().x), _text_of(best).left(30)]


func _r(r: Rect2) -> String:
	return "(%d,%d %dx%d)" % [int(r.position.x), int(r.position.y), int(r.size.x), int(r.size.y)]


func _fail(c: Control, screen: String, kind: String, text: String, detail: String) -> void:
	var path: String = _path(c)
	for k: Dictionary in KNOWN_ISSUES:
		if k["kind"] == kind and _cfg.begins_with(k["config"]) and screen == k["screen"] and path.begins_with(k["path"]) \
				or (k["kind"] == kind and _cfg.begins_with(k["config"]) and screen == k["screen"] and text.begins_with("⚔")):
			known.append({"config": _cfg, "screen": screen, "kind": kind, "node": path, "text": text.left(60), "detail": detail, "issue": k["issue"]})
			return
	for a: Dictionary in ACCEPTED:
		if a["kind"] == kind and path.contains(a["path"]) and text.begins_with(a["prefix"]):
			accepted.append({"config": _cfg, "screen": screen, "kind": kind, "node": path, "text": text.left(60), "reason": a["reason"]})
			return
	violations.append({"config": _cfg, "screen": screen, "kind": kind, "node": _path(c),
		"class": c.get_class(), "text": text.left(60).replace("\n", " "), "detail": detail})
	per_config[_cfg]["violations"] = int(per_config[_cfg]["violations"]) + 1


func _path(c: Node) -> String:
	var parts: PackedStringArray = []
	var n: Node = c
	while n != null and not (n is SubViewport) and parts.size() < 6:
		parts.insert(0, str(n.name))
		n = n.get_parent()
	return "/".join(parts)
