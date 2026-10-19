#!/usr/bin/env python3
"""Builds small, licence-free FAKE vendor packs to test the LASTROOT import
pipeline without any purchased files (adapted from the GENESIS ARK selftest):

  <out>/SelfTestSynty.unitypackage   Synty layout (<guid>/asset + pathname): a flat rock
                                     platform authored in CENTIMETRES, a lantern with an
                                     off-centre pivot, a crystal in cm, a rock, a tree trunk,
                                     a skinned golem with Synty bone names facing +Z, an atlas
                                     texture and Unity-only junk (.prefab/.mat/.meta/.cs)
  <out>/SelfTestPolyPerfect.zip      a quadruped deer with its OWN embedded clips
                                     (Idle_A, Attack_1, Death, Walk) and non-humanoid bones
  <out>/SelfTestMixamo/              Mixamo-style clip files ("Breathing Idle", "Punching" with
                                     1 m of root travel, "Hit Reaction", "Dying"), clip name
                                     "mixamo.com", mixamorig bone names

Models are glTF (Godot imports .fbx through the same importer interface; generating
FBX without third-party tools is not practical). Python 3 stdlib only.

  python3 tools/synty/make_test_pack.py <out_dir>
"""
import base64, io, json, math, os, struct, sys, tarfile, uuid, zipfile, zlib

# name, size (x, y, z) in file units, box centre
STATIC = [
    ("SM_Env_Rock_Flat_Platform_01", (1150.0, 60.0, 330.0), (0.0, -30.0, 0.0)),   # centimetres, top at 0
    ("SM_Prop_Lantern_01", (0.3, 1.2, 0.3), (0.5, 0.6, 0.2)),                     # pivot off-centre
    ("SM_Prop_Crystal_01", (60.0, 100.0, 50.0), (0.0, 50.0, 0.0)),                # centimetres
    ("SM_Env_Rock_01", (1.0, 0.6, 0.9), (0.0, 0.3, 0.0)),
    ("SM_Env_Tree_Trunk_01", (2.5, 6.0, 2.5), (0.0, 3.0, 0.0)),
]


def box_gltf(name, size, center, mat="PolygonNature_Mat_01_A"):
    sx, sy, sz = (s / 2 for s in size)
    cx, cy, cz = center
    faces = [((1, 0, 0), [(1, -1, -1), (1, 1, -1), (1, 1, 1), (1, -1, 1)]),
             ((-1, 0, 0), [(-1, -1, 1), (-1, 1, 1), (-1, 1, -1), (-1, -1, -1)]),
             ((0, 1, 0), [(-1, 1, -1), (-1, 1, 1), (1, 1, 1), (1, 1, -1)]),
             ((0, -1, 0), [(-1, -1, 1), (-1, -1, -1), (1, -1, -1), (1, -1, 1)]),
             ((0, 0, 1), [(1, -1, 1), (1, 1, 1), (-1, 1, 1), (-1, -1, 1)]),
             ((0, 0, -1), [(-1, -1, -1), (-1, 1, -1), (1, 1, -1), (1, -1, -1)])]
    pos, nrm, uv, idx = [], [], [], []
    for n, quad in faces:
        base = len(pos)
        for i, (x, y, z) in enumerate(quad):
            pos.append((cx + x * sx, cy + y * sy, cz + z * sz))
            nrm.append(n)
            uv.append(((0.1, 0.1), (0.1, 0.2), (0.2, 0.2), (0.2, 0.1))[i])
        idx += [base, base + 1, base + 2, base, base + 2, base + 3]
    buf = b"".join(struct.pack("<3f", *p) for p in pos) + b"".join(struct.pack("<3f", *n) for n in nrm)
    buf += b"".join(struct.pack("<2f", *t) for t in uv) + b"".join(struct.pack("<H", i) for i in idx)
    n = len(pos)
    lo = [min(p[k] for p in pos) for k in range(3)]
    hi = [max(p[k] for p in pos) for k in range(3)]
    g = {"asset": {"version": "2.0", "generator": "lastroot make_test_pack"}, "scene": 0, "scenes": [{"nodes": [0]}],
         "nodes": [{"name": name, "mesh": 0}],
         "meshes": [{"name": name, "primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2}, "indices": 3, "material": 0}]}],
         # Like many vendor FBX imports: a named material without the atlas attached.
         "materials": [{"name": mat, "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1], "metallicFactor": 0, "roughnessFactor": 0.9}}],
         "buffers": [{"byteLength": len(buf), "uri": "data:application/octet-stream;base64," + base64.b64encode(buf).decode()}],
         "bufferViews": [{"buffer": 0, "byteOffset": 0, "byteLength": n * 12}, {"buffer": 0, "byteOffset": n * 12, "byteLength": n * 12},
                         {"buffer": 0, "byteOffset": n * 24, "byteLength": n * 8}, {"buffer": 0, "byteOffset": n * 32, "byteLength": len(idx) * 2}],
         "accessors": [{"bufferView": 0, "componentType": 5126, "count": n, "type": "VEC3", "min": lo, "max": hi},
                       {"bufferView": 1, "componentType": 5126, "count": n, "type": "VEC3"},
                       {"bufferView": 2, "componentType": 5126, "count": n, "type": "VEC2"},
                       {"bufferView": 3, "componentType": 5123, "count": len(idx), "type": "SCALAR"}]}
    return json.dumps(g).encode()


def png(w, h):
    rows = []
    for y in range(h):
        row = b"\x00"
        for x in range(w):
            row += bytes([(107, 74, 47), (122, 76, 214), (63, 242, 214), (255, 178, 56)][(x * 2 // w) + 2 * (y * 2 // h)])
        rows.append(row)
    raw = zlib.compress(b"".join(rows))

    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">2I5B", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", raw) + chunk(b"IEND", b"")


# ------------------------------------------------------------------ skinned rigs
# Synty-style humanoid; toes (Ball_*) point +Z like an un-flipped vendor character.
SYNTY_RIG = [
    ("Hips", None, (0, 1.0, 0)), ("Spine_01", "Hips", (0, 0.12, 0)), ("Spine_02", "Spine_01", (0, 0.12, 0)),
    ("Spine_03", "Spine_02", (0, 0.12, 0)), ("Neck", "Spine_03", (0, 0.15, 0)), ("Head", "Neck", (0, 0.12, 0)),
    ("Clavicle_L", "Spine_03", (0.08, 0.1, 0)), ("Shoulder_L", "Clavicle_L", (0.12, 0, 0)), ("Elbow_L", "Shoulder_L", (0.28, 0, 0)), ("Hand_L", "Elbow_L", (0.26, 0, 0)),
    ("Clavicle_R", "Spine_03", (-0.08, 0.1, 0)), ("Shoulder_R", "Clavicle_R", (-0.12, 0, 0)), ("Elbow_R", "Shoulder_R", (-0.28, 0, 0)), ("Hand_R", "Elbow_R", (-0.26, 0, 0)),
    ("UpperLeg_L", "Hips", (0.1, -0.05, 0)), ("LowerLeg_L", "UpperLeg_L", (0, -0.45, 0)), ("Ankle_L", "LowerLeg_L", (0, -0.45, 0)), ("Ball_L", "Ankle_L", (0, -0.05, 0.12)),
    ("UpperLeg_R", "Hips", (-0.1, -0.05, 0)), ("LowerLeg_R", "UpperLeg_R", (0, -0.45, 0)), ("Ankle_R", "LowerLeg_R", (0, -0.45, 0)), ("Ball_R", "Ankle_R", (0, -0.05, 0.12)),
]
MIXAMO = {"Hips": "mixamorig:Hips", "Spine_01": "mixamorig:Spine", "Spine_02": "mixamorig:Spine1", "Spine_03": "mixamorig:Spine2",
          "Neck": "mixamorig:Neck", "Head": "mixamorig:Head", "Clavicle_L": "mixamorig:LeftShoulder", "Shoulder_L": "mixamorig:LeftArm",
          "Elbow_L": "mixamorig:LeftForeArm", "Hand_L": "mixamorig:LeftHand", "Clavicle_R": "mixamorig:RightShoulder",
          "Shoulder_R": "mixamorig:RightArm", "Elbow_R": "mixamorig:RightForeArm", "Hand_R": "mixamorig:RightHand",
          "UpperLeg_L": "mixamorig:LeftUpLeg", "LowerLeg_L": "mixamorig:LeftLeg", "Ankle_L": "mixamorig:LeftFoot", "Ball_L": "mixamorig:LeftToeBase",
          "UpperLeg_R": "mixamorig:RightUpLeg", "LowerLeg_R": "mixamorig:RightLeg", "Ankle_R": "mixamorig:RightFoot", "Ball_R": "mixamorig:RightToeBase"}
# Non-humanoid deer (PolyPerfect-like). Head and Nose toward +Z (vendor default).
DEER_RIG = [
    ("Root", None, (0, 0.9, 0)), ("Spine", "Root", (0, 0.05, 0.3)), ("Neck", "Spine", (0, 0.25, 0.3)), ("Head", "Neck", (0, 0.25, 0.15)),
    ("Nose", "Head", (0, -0.05, 0.25)), ("Tail", "Root", (0, 0.05, -0.45)),
    ("Leg_FL", "Spine", (0.18, -0.1, 0.1)), ("Leg_FL_Low", "Leg_FL", (0, -0.45, 0)), ("Leg_FR", "Spine", (-0.18, -0.1, 0.1)), ("Leg_FR_Low", "Leg_FR", (0, -0.45, 0)),
    ("Leg_BL", "Root", (0.18, -0.05, -0.35)), ("Leg_BL_Low", "Leg_BL", (0, -0.45, 0)), ("Leg_BR", "Root", (-0.18, -0.05, -0.35)), ("Leg_BR_Low", "Leg_BR", (0, -0.45, 0)),
]


def quat_x(deg):
    h = math.radians(deg) / 2
    return (math.sin(h), 0.0, 0.0, math.cos(h))


def skinned_gltf(rig, names, anims=(), mesh=True, mat="PolygonNature_Mat_01_A"):
    """anims: [(name, {bone: [(t, quat)]}, travel_bone, travel_m)]."""
    idx = {b[0]: i for i, b in enumerate(rig)}
    glob = {}
    for b, parent, off in rig:
        base = glob[parent] if parent else (0, 0, 0)
        glob[b] = tuple(base[k] + off[k] for k in range(3))
    nodes = []
    for b, parent, off in rig:
        n = {"name": names.get(b, b), "translation": list(off)}
        kids = [idx[c] for c, p, _o in rig if p == b]
        if kids:
            n["children"] = kids
        nodes.append(n)
    buf = b""
    views, accs = [], []

    def add(data, ctype, count, typ, extra=None):
        nonlocal buf
        while len(buf) % 4:
            buf += b"\0"
        views.append({"buffer": 0, "byteOffset": len(buf), "byteLength": len(data)})
        buf += data
        a = {"bufferView": len(views) - 1, "componentType": ctype, "count": count, "type": typ}
        if extra:
            a.update(extra)
        accs.append(a)
        return len(accs) - 1

    ibm = b""
    for b, _p, _o in rig:
        x, y, z = glob[b]
        ibm += struct.pack("<16f", 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, -x, -y, -z, 1)
    skin = {"joints": list(range(len(rig))), "inverseBindMatrices": add(ibm, 5126, len(rig), "MAT4"), "skeleton": 0}
    root_children = [0]
    g = {"asset": {"version": "2.0", "generator": "lastroot make_test_pack"}, "scene": 0, "skins": [skin], "materials": [{"name": mat}]}
    if mesh:
        pos, jnt, wgt, ind = [], [], [], []
        for j, (b, _p, _o) in enumerate(rig):
            cx, cy, cz = glob[b]
            base = len(pos)
            for dx in (-0.06, 0.06):
                for dy in (-0.06, 0.06):
                    for dz in (-0.06, 0.06):
                        pos.append((cx + dx, cy + dy, cz + dz))
                        jnt.append((j, 0, 0, 0))
                        wgt.append((1.0, 0.0, 0.0, 0.0))
            for a_, b_, c_ in [(0, 1, 3), (0, 3, 2), (4, 6, 7), (4, 7, 5), (0, 4, 5), (0, 5, 1), (2, 3, 7), (2, 7, 6), (0, 2, 6), (0, 6, 4), (1, 5, 7), (1, 7, 3)]:
                ind += [base + a_, base + b_, base + c_]
        lo = [min(p[k] for p in pos) for k in range(3)]
        hi = [max(p[k] for p in pos) for k in range(3)]
        pa = add(b"".join(struct.pack("<3f", *p) for p in pos), 5126, len(pos), "VEC3", {"min": lo, "max": hi})
        ja = add(b"".join(struct.pack("<4H", *j) for j in jnt), 5123, len(jnt), "VEC4")
        wa = add(b"".join(struct.pack("<4f", *w) for w in wgt), 5126, len(wgt), "VEC4")
        ia = add(b"".join(struct.pack("<H", i) for i in ind), 5123, len(ind), "SCALAR")
        g["meshes"] = [{"name": "Body", "primitives": [{"attributes": {"POSITION": pa, "JOINTS_0": ja, "WEIGHTS_0": wa}, "indices": ia, "material": 0}]}]
        nodes.append({"name": "Body", "mesh": 0, "skin": 0})
        root_children.append(len(nodes) - 1)
    nodes.append({"name": "Armature", "children": root_children})
    g["scenes"] = [{"nodes": [len(nodes) - 1]}]
    g["nodes"] = nodes
    out_anims = []
    for name, tracks, travel_bone, travel in anims:
        samplers, channels = [], []
        for bone, keys in tracks.items():
            t = add(b"".join(struct.pack("<f", k[0]) for k in keys), 5126, len(keys), "SCALAR", {"min": [keys[0][0]], "max": [keys[-1][0]]})
            v = add(b"".join(struct.pack("<4f", *k[1]) for k in keys), 5126, len(keys), "VEC4")
            samplers.append({"input": t, "output": v, "interpolation": "LINEAR"})
            channels.append({"sampler": len(samplers) - 1, "target": {"node": idx[bone], "path": "rotation"}})
        if travel:
            end = max(k[-1][0] for k in tracks.values())
            ts = [0.0, end * 0.5, end]
            base = rig[idx[travel_bone]][2]
            t = add(b"".join(struct.pack("<f", x) for x in ts), 5126, 3, "SCALAR", {"min": [0.0], "max": [end]})
            v = add(b"".join(struct.pack("<3f", base[0], base[1], base[2] + travel * x / end) for x in ts), 5126, 3, "VEC3")
            samplers.append({"input": t, "output": v, "interpolation": "LINEAR"})
            channels.append({"sampler": len(samplers) - 1, "target": {"node": idx[travel_bone], "path": "translation"}})
        out_anims.append({"name": name, "samplers": samplers, "channels": channels})
    if out_anims:
        g["animations"] = out_anims
    g["buffers"] = [{"byteLength": len(buf), "uri": "data:application/octet-stream;base64," + base64.b64encode(buf).decode()}]
    g["bufferViews"] = views
    g["accessors"] = accs
    return json.dumps(g).encode()


def swing(a, end=1.0):
    return [(0.0, quat_x(0)), (end * 0.5, quat_x(a)), (end, quat_x(0))]


def write_unitypackage(path, entries):
    with tarfile.open(path, "w:gz") as tar:
        def add(p, data):
            ti = tarfile.TarInfo(p)
            ti.size = len(data)
            tar.addfile(ti, io.BytesIO(data))
        for p, data in entries:
            g = uuid.uuid5(uuid.NAMESPACE_URL, p).hex
            add(g + "/asset", data)
            add(g + "/pathname", (p + "\n00\n").encode())
            add(g + "/asset.meta", b"fileFormatVersion: 2\n")
        add(uuid.uuid4().hex + "/pathname", b"Assets/PolygonNature\n")  # folder entry, no asset


def main() -> int:
    out = sys.argv[1] if len(sys.argv) > 1 else "selftest_packs"
    os.makedirs(out, exist_ok=True)
    synty = {b[0]: b[0] for b in SYNTY_RIG}
    entries = []
    for name, size, center in STATIC:
        entries.append(("Assets/PolygonNature/Models/%s.gltf" % name, box_gltf(name, size, center)))
        entries.append(("Assets/PolygonNature/Prefabs/%s.prefab" % name, b"%YAML 1.1 fake prefab"))
    entries.append(("Assets/PolygonNature/Models/Characters/SK_Chr_Golem_01.gltf", skinned_gltf(SYNTY_RIG, synty)))
    entries.append(("Assets/PolygonNature/Textures/PolygonNature_Texture_01_A.png", png(64, 64)))
    entries.append(("Assets/PolygonNature/Materials/PolygonNature_Mat_01_A.mat", b"%YAML 1.1 fake material"))
    entries.append(("Assets/PolygonNature/Scripts/Wind.cs", b"// unity script"))
    write_unitypackage(os.path.join(out, "SelfTestSynty.unitypackage"), entries)
    deer_anims = [("Idle_A", {"Neck": swing(6, 2.0)}, None, 0), ("Attack_1", {"Neck": swing(-40, 0.8), "Head": swing(-20, 0.8)}, None, 0),
                  ("Death", {"Root": [(0.0, quat_x(0)), (1.0, quat_x(80))]}, None, 0),
                  ("Walk", {"Leg_FL": swing(25), "Leg_BR": swing(25), "Leg_FR": swing(-25), "Leg_BL": swing(-25)}, "Root", 1.2)]
    with zipfile.ZipFile(os.path.join(out, "SelfTestPolyPerfect.zip"), "w") as z:
        z.writestr("PolyPerfect/Animals/Models/Deer_Animated_01.gltf", skinned_gltf(DEER_RIG, {}, deer_anims, mat="PolyPerfect_Animals_Mat"))
        z.writestr("PolyPerfect/Animals/Textures/Animals_Texture.png", png(32, 32))
        z.writestr("PolyPerfect/Animals/Prefabs/Deer.prefab", b"%YAML fake")
    mix = os.path.join(out, "SelfTestMixamo", "Mixamo")
    os.makedirs(mix, exist_ok=True)
    clips = {"Breathing Idle": ({"Spine_01": swing(3, 2.0)}, 0), "Punching": ({"Shoulder_R": swing(-70, 0.9), "Elbow_R": swing(-40, 0.9)}, 1.0),
             "Hit Reaction": ({"Spine_02": swing(18, 0.6)}, 0), "Dying": ({"Hips": [(0.0, quat_x(0)), (1.4, quat_x(85))]}, 0)}
    for name, (tracks, travel) in clips.items():
        with open(os.path.join(mix, name + ".gltf"), "wb") as fh:
            fh.write(skinned_gltf(SYNTY_RIG, MIXAMO, [("mixamo.com", tracks, "Hips", travel)], mat="mixamo_skin"))
    print("wrote fake packs to", out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
