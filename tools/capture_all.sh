#!/usr/bin/env bash
# One command to see every visual surface of LASTROOT side by side, e.g. after
# importing the real Synty / PolyPerfect / Mixamo assets (tools/synty/build.sh).
#
#   tools/capture_all.sh [label] [--compare=<other label>] [--no-date] [--only=group,group]
#
# Runs every capture scene SEQUENTIALLY (never in parallel: several of them use
# user:// and the save backup), collects the screenshots into
#   evidence/captures/<YYYY-MM-DD>_<label>/<group>/*.jpg|png   (label default "current")
# downscaled to max 1280 px wide, and writes index.html there (all images,
# grouped by area, relative paths). With --compare=<label> it also writes
# compare_<label>.html: before (<label>) / after (this run), item by item.
# The baseline of today's procedural proxies lives in evidence/captures/proxies_baseline/
# (made with: tools/capture_all.sh proxies_baseline --no-date).
#
# Groups: battle heart dioramas gallery riglab branding meta cards battle_ui
# Needs: godot 4.5 (GODOT_BIN), xvfb-run, python3 + Pillow.
set -uo pipefail
GODOT="${GODOT_BIN:-godot}"
cd "$(dirname "$0")/.."
ROOT=$(pwd)

LABEL="current"; COMPARE=""; DATED=1; ONLY=""
for a in "$@"; do
	case "$a" in
		--compare=*) COMPARE="${a#--compare=}" ;;
		--no-date) DATED=0 ;;
		--only=*) ONLY=",${a#--only=}," ;;
		-h|--help) sed -n 2,17p "$0"; exit 0 ;;
		*) LABEL="$a" ;;
	esac
done
NAME="$LABEL"; [ $DATED -eq 1 ] && NAME="$(date +%F)_$LABEL"
CAP=evidence/captures
OUT="$CAP/$NAME"
RAW="$CAP/.raw_$NAME"          # full-size working copy, removed at the end
mkdir -p "$CAP" && touch "$CAP/.gdignore"   # Godot must not import thousands of shots
rm -rf "$RAW" && mkdir -p "$RAW"
LOG="$RAW/capture.log"
echo "capture_all: $OUT"

want() { [ -z "$ONLY" ] || [[ "$ONLY" == *",$1,"* ]]; }
godot_run() {   # godot_run <resolution> <timeout s> <args...>
	local res="$1" t="$2"; shift 2
	echo "+ $res $*" >> "$LOG"
	timeout "$t" xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path . --rendering-method gl_compatibility \
		--resolution "$res" "$@" >> "$LOG" 2>&1
	local rc=$?
	[ $rc -ne 0 ] && [ $rc -ne 1 ] && echo "  ! exit $rc: $*"
	return 0
}
# For capture scenes that write to a fixed evidence folder: copy what this run
# wrote into the group, then put the tracked evidence files back as they were.
collect_fixed() {   # collect_fixed <group> <src dir> <marker> <pre-list> [name glob]
	local g="$1" src="$2" marker="$3" pre="$4" glob="${5:-*.png}"
	mkdir -p "$RAW/$g"
	find "$src" -maxdepth 1 -name "$glob" -newer "$marker" -print0 2>/dev/null | while IFS= read -r -d '' f; do
		cp "$f" "$RAW/$g/"
		if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
			git checkout -q -- "$f"
		elif ! grep -qxF "$f" "$pre"; then
			rm -f "$f"
		fi
	done
}
fixed_scene() {   # fixed_scene <group> <scene> <src dir> <glob> <resolution> <timeout>
	local g="$1" scene="$2" src="$3" glob="$4" res="$5" t="$6"
	local marker="$RAW/.mark_$g" pre="$RAW/.pre_$g"
	find "$src" -maxdepth 1 -name "$glob" > "$pre" 2>/dev/null
	touch "$marker"; sleep 1
	godot_run "$res" "$t" "$scene"
	collect_fixed "$g" "$src" "$marker" "$pre" "$glob"
}

if want battle; then
	echo "- battle"; B="$RAW/battle"; mkdir -p "$B"
	godot_run 1920x1080 240 -- --setup=boss --capture=$B/battle_boss_1080p.png --frames=90
	godot_run 1920x1080 240 -- --setup=midbattle --capture=$B/battle_mid_1080p.png --frames=90
	godot_run 390x844 240 -- --setup=midbattle --capture=$B/battle_mid_portrait.png --frames=90
	godot_run 390x844 240 -- --setup=boss --capture=$B/battle_boss_portrait.png --frames=90
	godot_run 1920x1080 240 res://scenes/tests/stage_mutations.tscn -- --capture=$B/stage_mutations_all.png --frames=60
	godot_run 1920x1080 240 res://scenes/tests/stage_mutations.tscn -- --mutations= --capture=$B/stage_mutations_none.png --frames=60
fi
if want heart; then
	echo "- heart"; mkdir -p "$RAW/heart"
	godot_run 1500x700 200 res://scenes/tests/heart_strip.tscn -- --capture=$RAW/heart/heart_health_strip.png --frames=40
fi
if want dioramas; then
	echo "- dioramas"; D="$RAW/dioramas"; mkdir -p "$D"
	godot_run 1920x1080 200 res://scenes/art/menu_diorama.tscn -- --champion=BARK --capture=$D/menu_1080p.png --frames=60
	godot_run 430x932 200 res://scenes/art/menu_diorama.tscn -- --portrait --champion=SPORE --capture=$D/menu_portrait.png --frames=60
	godot_run 1920x1080 200 res://scenes/art/route_diorama.tscn -- --progress=3 --capture=$D/route_1080p.png --frames=60
	godot_run 430x932 200 res://scenes/art/route_diorama.tscn -- --portrait --progress=3 --capture=$D/route_portrait.png --frames=60
	godot_run 1920x1080 200 res://scenes/art/epilog_diorama.tscn -- --result=won --faction=BARK --path=BULWARK --mutations=M01,M02,M03,M04 --capture=$D/epilog_won_1080p.png --frames=70
	godot_run 1920x1080 200 res://scenes/art/epilog_diorama.tscn -- --result=lost --capture=$D/epilog_lost_1080p.png --frames=70
	godot_run 430x932 200 res://scenes/art/epilog_diorama.tscn -- --portrait --result=won --faction=SPORE --path=LIFEWEAVER --mutations=M02,M03 --capture=$D/epilog_won_portrait.png --frames=70
	godot_run 430x932 200 res://scenes/art/epilog_diorama.tscn -- --portrait --result=lost --capture=$D/epilog_lost_portrait.png --frames=70
fi
if want gallery; then
	echo "- gallery"; G="$RAW/gallery"; mkdir -p "$G"
	for m in lineup gate stage props; do
		godot_run 1600x900 200 res://scenes/tests/asset_gallery.tscn -- --mode=$m --capture=$G/gallery_$m.png
	done
fi
if want riglab; then
	echo "- riglab"; R="$RAW/riglab"; mkdir -p "$R/states"
	for s in unit.B01 unit.B04 unit.S01 enemy.E06; do
		godot_run 1600x900 200 res://scenes/tests/rig_lab.tscn -- --slot=$s --capture=$R/riglab_${s#*.}.png
	done
	# states sheet: the style gate lineup frozen mid-state, one tile per animator state
	for st in idle summon attack cast hit death defend victory move; do
		godot_run 1600x900 200 res://scenes/tests/asset_gallery.tscn -- --mode=gate --state=$st --capture=$R/states/$st.png
	done
	python3 -I tools/synty/contact_sheet.py tile "$R/states" "$R/riglab_states_sheet.png" \
		idle summon attack cast hit death defend victory move >> "$LOG" 2>&1
	rm -rf "$R/states"
fi
if want branding; then
	echo "- branding"
	godot_run 640x360 300 res://scenes/tests/branding_capture.tscn -- --out=$RAW/branding/
fi
if want meta; then
	echo "- meta (meta_capture, takes a while)"
	fixed_scene meta res://scenes/tests/meta_capture.tscn evidence/meta_screens "*.png" 1920x1080 900
fi
if want cards; then
	echo "- cards"
	fixed_scene cards res://scenes/tests/card_gallery.tscn evidence/meta_screens "cards_*.png" 1920x1080 400
fi
if want battle_ui; then
	echo "- battle_ui"
	fixed_scene battle_ui res://scenes/tests/battle_capture.tscn evidence/shots "*.png" 1920x1080 400
fi

python3 -I tools/synty/contact_sheet.py build "$RAW" "$OUT" "$NAME" || { echo "contact sheet failed (see $LOG)"; exit 1; }
cp "$LOG" "$OUT/capture.log" 2>/dev/null
rm -rf "$RAW"
if [ -n "$COMPARE" ]; then
	BASE="$CAP/$COMPARE"
	[ -d "$BASE" ] || BASE=$(ls -d "$CAP"/*_"$COMPARE" 2>/dev/null | sort | tail -1)
	if [ -n "$BASE" ] && [ -d "$BASE" ]; then
		python3 -I tools/synty/contact_sheet.py compare "$BASE" "$OUT"
	else
		echo "no capture set named '$COMPARE' under $CAP"
	fi
fi
echo "open: $ROOT/$OUT/index.html"
