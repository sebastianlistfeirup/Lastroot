extends Node
## Player text. English is the source language (D-03); other languages come
## from localization/translations.csv (column per language, key = English).
## Data files carry `name`/`text` in English and `name_da`/`text_da` from the
## bible, which the CSV does not need to repeat.

signal language_changed

const LANGUAGES: PackedStringArray = ["en", "da"]
const CSV_PATH := "res://localization/translations.csv"

var language: String = "en"
var _table: Dictionary = {}  # lang -> {en: translated}


func _ready() -> void:
	_load_csv()


func _load_csv() -> void:
	_table.clear()
	if not FileAccess.file_exists(CSV_PATH):
		return
	var f := FileAccess.open(CSV_PATH, FileAccess.READ)
	var header: PackedStringArray = f.get_csv_line()
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() < 2 or row[0] == "":
			continue
		for i in range(1, min(row.size(), header.size())):
			if row[i] == "":
				continue
			if not _table.has(header[i]):
				_table[header[i]] = {}
			_table[header[i]][row[0]] = row[i]


func set_language(lang: String) -> void:
	if not LANGUAGES.has(lang):
		lang = "en"
	language = lang
	language_changed.emit()


## Translate an English source string. Unknown strings fall back to English.
func t(en: String) -> String:
	if language == "en":
		return en
	var tab: Dictionary = _table.get(language, {})
	return tab.get(en, en)


## A reason string from a reducer (English, possibly already formatted with
## numbers or floor names). Plain reasons translate directly; formatted ones
## are matched against their template, then re-formatted in the language.
func reason(text: String) -> String:
	if language == "en" or text == "":
		return text
	var direct: String = t(text)
	if direct != text:
		return direct
	var templates: Array = [
		["No space on the %s (%d/%d, needs %d).", Loc.t("No space on the %s (%d/%d, needs %d).")],
		["Not enough Sap (needs %d).", Loc.t("Not enough Sap (needs %d).")],
		["Not enough Resin (needs %d).", Loc.t("Not enough Resin (needs %d).")],
		["This save comes from a newer version of the game (schema %d).", Loc.t("This save comes from a newer version of the game (schema %d).")],
		["Your deck must keep at least %d normal cards.", Loc.t("Your deck must keep at least %d normal cards.")],
	]
	for pair: Array in templates:
		var args: Variant = _match_template(str(pair[0]), text)
		if args != null:
			return str(pair[1]) % args
	return text


func _match_template(tpl: String, text: String) -> Variant:
	var codes: Array = []
	var pat := "^"
	var i := 0
	while i < tpl.length():
		var c := tpl[i]
		if c == "%" and i + 1 < tpl.length() and tpl[i + 1] in ["d", "s"]:
			codes.append(tpl[i + 1])
			pat += "(-?\\d+)" if tpl[i + 1] == "d" else "(.+?)"
			i += 2
			continue
		pat += ("\\" + c) if "\\^$.|?*+()[]{}/".contains(c) else c
		i += 1
	var re := RegEx.new()
	if re.compile(pat + "$") != OK:
		return null
	var m := re.search(text)
	if m == null:
		return null
	var out: Array = []
	for k in codes.size():
		var v: String = m.get_string(k + 1)
		out.append(int(v) if codes[k] == "d" else t(v))
	return out


## Name/text field of a data definition in the active language.
## The translation table wins over a definition's `<key>_<lang>` field: the
## catalog's text_da is design-spec wording without {placeholders}, so it
## could not show a card's upgraded numbers (fix: player text via the CSV).
func field(def: Dictionary, key: String) -> String:
	if language != "en":
		var en: String = str(def.get(key, ""))
		var tab: Dictionary = _table.get(language, {})
		if en != "" and tab.has(en):
			return tab[en]
		if def.has(key + "_" + language):
			return str(def[key + "_" + language])
	return t(str(def.get(key, "")))


func has_translation(en: String, lang: String) -> bool:
	return _table.get(lang, {}).has(en)
