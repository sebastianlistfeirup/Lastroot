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
