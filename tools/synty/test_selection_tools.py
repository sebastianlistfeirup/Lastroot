#!/usr/bin/env python3
"""Headless test (no Godot, no purchased files) of apply_selection.py, the stage.py atlas
preference, focus.py on selection choices and fix_vendor_uid_collision.py, using fake
manifests with the file names Realmrend saw in the real Synty packs. Run by tools/check.sh.
Writes evidence/asset_pipeline/selection_tools_test.json. Exit 0 = all PASS."""
import importlib.util, json, os, shutil, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TOOLS = os.path.join(ROOT, "tools", "synty")
SEL = os.path.join(ROOT, "data", "art", "synty_selection.json")
results = []


def check(name, ok, detail=""):
    results.append({"check": name, "result": "PASS" if ok else "FAIL", "detail": detail})
    print(("PASS " if ok else "FAIL ") + name + (("  (" + detail + ")") if detail and not ok else ""))


def run(*args):
    p = subprocess.run([sys.executable, os.path.join(TOOLS, args[0])] + list(args[1:]), capture_output=True, text=True, cwd=ROOT)
    return p.returncode, p.stdout + p.stderr


def fake_pack(q, slug, files):
    d = os.path.join(q, slug)
    os.makedirs(d, exist_ok=True)
    for f in files:
        os.makedirs(os.path.dirname(os.path.join(d, f)), exist_ok=True)
        open(os.path.join(d, f), "wb").write(b"x")
    json.dump({"pack": slug, "files": [{"path": f, "size": 1, "sha256": "0"} for f in files]}, open(os.path.join(d, "manifest.json"), "w"))


def main():
    tmp = tempfile.mkdtemp(prefix="lr_sel_")
    try:
        q = os.path.join(tmp, "quarantine")
        out = os.path.join(tmp, "synty_choices.json")
        rc, txt = run("apply_selection.py", "--check")
        check("selection valid and covers every slot in asset_slots.json", rc == 0, txt.strip()[-200:])
        rc, txt = run("apply_selection.py", "--dry-run", "--quarantine", q, "--out", out)
        check("dry-run without packs prints the plan, writes nothing, exit 0", rc == 0 and "unit.S01" in txt and not os.path.exists(out), str(rc))
        rc, txt = run("apply_selection.py", "--quarantine", q, "--out", out)
        check("real run without packs: clear error, exit 2, nothing written", rc == 2 and not os.path.exists(out) and "FEJL" in txt, str(rc))
        # fake quarantine with Realmrend-verified names
        fake_pack(q, "POLYGON_Fantasy_Kingdom_SourceFiles_v5", ["Source_Files/Characters/SK_Chr_Hermit_01.fbx", "Source_Files/Characters/SK_Chr_Soldier_Male_01.fbx",
                                                                 "Source_Files/Characters/SK_Chr_Monk_01.fbx", "Source_Files/Characters/SK_Chr_King_01.fbx"])
        fake_pack(q, "POLYGON_Fantasy_Kingdom_Godot_4_5_1_v1_0_0", ["PolygonFantasyKingdom/Models/SM_Env_Rock_05.fbx", "PolygonFantasyKingdom/Models/SM_Prop_Archway_01.fbx",
                                                                     "PolygonFantasyKingdom/Textures/Alts/PolygonFantasyKingdom_Texture_01_B.png",
                                                                     "PolygonFantasyKingdom/Textures/PolygonFantasyKingdom_Texture_01_A.png",
                                                                     "PolygonFantasyKingdom/Models/SM_Env_Flower_01.fbx", "PolygonFantasyKingdom/Models/SM_Env_Flower_02.fbx"])
        fake_pack(q, "POLYGON_Dark_Fantasy_SourceFiles_v3", ["Characters/SK_Chr_DarkLord_Male_01.fbx", "Characters/SK_Chr_Demon_01.fbx", "Characters/SK_Chr_Demon_02.fbx"])
        fake_pack(q, "POLYGON_Dark_Fantasy_Godot_4_6_2_v1_0_0", ["Synty/PolygonDarkFantasy/Models/SM_Env_Cliff_Basalt_01.fbx", "Synty/PolygonDarkFantasy/Textures/Alts/PolygonDarkFantasy_01_A.png"])
        fake_pack(q, "ANIMATION_Base_Locomotion_SourceFiles_v3", ["Animations/A_Idle_Standing_Masc.fbx", "Animations/A_Walk_F_Masc.fbx"])
        fake_pack(q, "ANIMATION_Sword_Combat_SourceFiles_v5", ["Animations/A_Attack_HeavyCombo01A_Sword.fbx", "Animations/A_Hit_F_React_Sword.fbx", "Animations/A_Death_F_01_Sword.fbx"])
        rc, txt = run("apply_selection.py", "--quarantine", q, "--out", out)
        doc = json.load(open(out)) if os.path.exists(out) else {}
        ch = doc.get("choices", {})
        check("partial packs: file written, exit 3, missing slots listed", rc == 3 and "MANGLER" in txt and len(ch) == 51, str(rc))
        g = lambda s: ch.get(s, {})
        check("S01 -> Source_Files/Characters/SK_Chr_Hermit_01.fbx, approved, faces via rotation_y 180",
              g("unit.S01").get("source") == "POLYGON_Fantasy_Kingdom_SourceFiles_v5/Source_Files/Characters/SK_Chr_Hermit_01.fbx"
              and g("unit.S01").get("status") == "approved" and g("unit.S01").get("rotation_y") == 180)
        check("E06 boss -> verified Dark Lord", g("enemy.E06").get("source", "").endswith("SK_Chr_DarkLord_Male_01.fbx"))
        check("B06 needs_download pack absent -> owned fallback (Demon) used and reported",
              "Demon" in g("unit.B06").get("source", "") and g("unit.B06").get("selection", {}).get("candidate", 0) > 0 and "alternativ" in txt)
        check("B02 (Dungeon not unpacked) stays proxy with a reason", g("unit.B02").get("status") == "skip" and "not unpacked" in g("unit.B02").get("note", ""))
        check("keep_proxy floors + FX written like match.py (skip / manual, no source)",
              g("stage.floor_roots").get("status") == "skip" and g("fx.poison").get("status") == "manual" and not g("fx.poison").get("source"))
        check("ambiguous pattern (two flowers) resolved to _01 and flagged",
              g("mutation.M03").get("source", "").endswith("SM_Env_Flower_01.fbx") and "tvetydig" in txt)
        an = doc.get("animations", {}).get("humanoid", {})
        st = an.get("states", {})
        check("humanoid clips: verified Synty names for idle/move/hit/death; attack falls back to HeavyCombo01A",
              st.get("idle", "").endswith("A_Idle_Standing_Masc.fbx") and st.get("move", "").endswith("A_Walk_F_Masc.fbx")
              and st.get("attack", "").endswith("A_Attack_HeavyCombo01A_Sword.fbx") and st.get("death", "").endswith("A_Death_F_01_Sword.fbx")
              and an.get("status") == "approved" and "cast" in an.get("procedural", []))
        atl = doc.get("atlas", {})
        check("atlas: SourceFiles FBX gets the Godot build's Texture_01_A (not the Alts/ B variant)",
              atl.get("POLYGON_Fantasy_Kingdom_SourceFiles_v5", "").endswith("Textures/PolygonFantasyKingdom_Texture_01_A.png"))
        rc2, _ = run("apply_selection.py", "--quarantine", q, "--out", out, "--allow-missing")
        check("--allow-missing -> exit 0", rc2 == 0, str(rc2))
        # hand edits survive a re-run; --force overwrites
        doc["choices"]["unit.S01"] = {"source": "POLYGON_Fantasy_Kingdom_SourceFiles_v5/Source_Files/Characters/SK_Chr_King_01.fbx", "status": "manual"}
        doc["choices"]["enemy.E06"]["status"] = "skip"
        doc["choices"]["enemy.E06"]["reverted_by_owner"] = True
        json.dump(doc, open(out, "w"))
        run("apply_selection.py", "--quarantine", q, "--out", out, "--allow-missing")
        d2 = json.load(open(out))["choices"]
        check("re-run keeps hand edit (S01 manual) and focus --revert (E06 skip)",
              d2["unit.S01"]["status"] == "manual" and d2["enemy.E06"]["status"] == "skip")
        run("apply_selection.py", "--quarantine", q, "--out", out, "--allow-missing", "--force")
        d3 = json.load(open(out))["choices"]
        check("--force restores the selection", d3["unit.S01"]["source"].endswith("SK_Chr_Hermit_01.fbx") and d3["enemy.E06"]["status"] == "approved")
        # focus.py: one slot at a time also works on selection-approved choices
        rc, txt = run("focus.py", "--choices", out, "unit.S01")
        d4 = json.load(open(out))["choices"]
        check("focus.py unit.S01: S01 approved, other selection choices -> weak (not built)",
              rc == 0 and d4["unit.S01"]["status"] == "approved" and d4["enemy.E06"]["status"] == "weak" and d4["prop.rock"]["status"] == "weak", txt[-200:])
        # stage.py honours the atlas preference
        spec = importlib.util.spec_from_file_location("lr_stage", os.path.join(TOOLS, "stage.py"))
        stage = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(stage)
        stage.Q, stage.IMPORTED, stage.ROOT = q, os.path.join(tmp, "imported"), tmp
        run_doc = json.load(open(out))
        for c in run_doc["choices"].values():
            if c.get("origin") == "selection" and c.get("status") == "weak":
                c["status"] = "approved"
        json.dump(run_doc, open(out, "w"))
        sys_argv = sys.argv
        sys.argv = ["stage.py", "--choices", out]
        try:
            import contextlib, io
            with contextlib.redirect_stdout(io.StringIO()):
                src = stage.main()
        finally:
            sys.argv = sys_argv
        staged = json.load(open(os.path.join(tmp, "imported", "POLYGON_Fantasy_Kingdom_SourceFiles_v5", "staged.json")))
        check("stage.py: preferred atlas first for the SourceFiles pack (copied from the Godot-build pack)",
              src == 0 and staged["atlas"] and staged["atlas"][0].endswith("POLYGON_Fantasy_Kingdom_Godot_4_5_1_v1_0_0/PolygonFantasyKingdom/Textures/PolygonFantasyKingdom_Texture_01_A.png"),
              str(staged.get("atlas")))
        # archives check
        arch = os.path.join(tmp, "archives")
        os.makedirs(arch)
        rc, txt = run("apply_selection.py", "--archives", arch)
        check("--archives on an empty folder: 16 missing, exit 3", rc == 3 and txt.count("MANGLER") == 16, str(rc))
        open(os.path.join(arch, "ANIMATION_Sword_Combat_SourceFiles_v5.zip"), "wb").write(b"not the real zip")
        rc, txt = run("apply_selection.py", "--archives", arch)
        check("--archives: wrong size/checksum -> FEJL, exit 2", rc == 2 and "FEJL" in txt, str(rc))
        # invalid selection
        bad = json.load(open(SEL))
        del bad["slots"]["unit.B01"]
        bad["slots"]["prop.rock"]["decision"] = "maybe"
        badp = os.path.join(tmp, "bad.json")
        json.dump(bad, open(badp, "w"))
        rc, txt = run("apply_selection.py", "--check", "--selection", badp)
        check("invalid selection (missing slot, bad decision) -> exit 2 with both problems", rc == 2 and "unit.B01" in txt and "prop.rock" in txt, str(rc))
        # UID collision tool (Realmrend: Synty_Character_Collider.tres in FK + DF with one uid)
        proj = os.path.join(tmp, "browse")
        os.makedirs(proj)
        open(os.path.join(proj, "project.godot"), "w").write("config_version=5\n")
        for pk in ("Assets/PolygonFantasyKingdom", "Assets/Synty/PolygonDarkFantasy"):
            d = os.path.join(proj, pk, "Models", "Collision")
            os.makedirs(d)
            open(os.path.join(d, "Synty_Character_Collider.tres"), "w").write('[gd_resource type="CapsuleShape3D" format=3 uid="uid://cj5gwdnnnm3q3"]\n\n[resource]\nradius = 0.3\n')
            pre = os.path.join(proj, pk, "Prefabs")
            os.makedirs(pre)
            res = "res://%s/Models/Collision/Synty_Character_Collider.tres" % pk
            open(os.path.join(pre, "SM_Chr_X.tscn"), "w").write('[gd_scene format=3]\n\n[ext_resource type="Shape3D" uid="uid://cj5gwdnnnm3q3" path="%s" id="1_a"]\n' % res)
        rc, txt = run("fix_vendor_uid_collision.py", proj)
        check("uid tool: finds the shared collider uid (report mode exit 1)", rc == 1 and "cj5gwdnnnm3q3" in txt, str(rc))
        rc, txt = run("fix_vendor_uid_collision.py", proj, "--fix", "--keep", "PolygonFantasyKingdom")
        fk = open(os.path.join(proj, "Assets/PolygonFantasyKingdom/Prefabs/SM_Chr_X.tscn")).read()
        df = open(os.path.join(proj, "Assets/Synty/PolygonDarkFantasy/Prefabs/SM_Chr_X.tscn")).read()
        dfc = open(os.path.join(proj, "Assets/Synty/PolygonDarkFantasy/Models/Collision/Synty_Character_Collider.tres")).read()
        new = dfc.split('uid="')[1].split('"')[0]
        check("uid tool --fix: Kingdom keeps uid, Dark Fantasy collider + its reference get one new uid",
              rc == 0 and "cj5gwdnnnm3q3" in fk and new != "uid://cj5gwdnnnm3q3" and new in df and "cj5gwdnnnm3q3" not in df, txt[-200:])
        rc, txt = run("fix_vendor_uid_collision.py", proj)
        check("uid tool: idempotent (second scan clean, exit 0)", rc == 0, str(rc))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    ok = all(r["result"] == "PASS" for r in results)
    ev = os.path.join(ROOT, "evidence", "asset_pipeline")
    os.makedirs(ev, exist_ok=True)
    with open(os.path.join(ev, "selection_tools_test.json"), "w", encoding="utf-8") as fh:
        json.dump({"status": "PASS" if ok else "FAIL", "note": "Fake manifests named after files Realmrend saw in the real Synty packs; no purchased files.",
                   "checks": results}, fh, indent=1)
        fh.write("\n")
    print("selection tools: %s (%d/%d)" % ("PASS" if ok else "FAIL", sum(r["result"] == "PASS" for r in results), len(results)))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
