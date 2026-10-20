#!/usr/bin/env python3
"""Builds licence-free HUMANOID test packs with Blender (bpy) for the asset pipeline dry run
(tools/synty/humanoid_dryrun.sh). Everything is generated here: no third-party content.
The two rigs deliberately differ the way the owner's purchases will:

  <out>/CC0Test_Synty/Characters/SK_Chr_Knight_01.fbx   Synty-style bone names (Root, Hips, Spine_01..03,
                                                         Clavicle_L, Shoulder_L, Elbow_L, Hand_L, UpperLeg_L,
                                                         LowerLeg_L, Ankle_L, Ball_L, IndexFinger_01_L ...),
                                                         A-POSE rest, stocky proportions, other bone rolls,
                                                         Z-up armature node (like a Unity/Synty export), no clips
  <out>/CC0Test_Synty/Characters/SK_Chr_Wizard_01.glb   the same rig as glTF
  <out>/CC0Test_Synty/Textures/PolygonTest_Texture_01_A.png   4-colour atlas
  <out>/CC0Test_Characters/Ch_TestBot.fbx|.glb         Mixamo-style character: T-POSE, mixamorig:* names
  <out>/Mixamo/<Mixamo name>.fbx                clip files WITHOUT skin (armature only, action
                                                         "mixamo.com"), authored on the Mixamo rig, laid out
                                                         flat like a folder of mixamo.com downloads; Punching
                                                         and Walking keep root travel (not "In Place")
  <out>/Mixamo_glb/<Mixamo name>.glb            the same clips as glTF

Run with Blender as a Python module (pip install bpy==5.2.2 in a venv; Python 3.13) or Blender:
  <venv>/bin/python tools/synty/make_humanoid_pack.py <out_dir>
  blender -b --python tools/synty/make_humanoid_pack.py -- <out_dir>
"""
import math, os, sys
try:
    import bpy
    from mathutils import Vector, Quaternion
except ImportError:
    print("NOT_RUN: needs Blender's Python module (pip install bpy==5.2.2, Python 3.13) or blender -b --python", file=sys.stderr)
    sys.exit(2)

OUT = sys.argv[-1]


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


# ---------------------------------------------------------------- skeletons
# (name, parent, head, tail) in Blender metres, Z up, character faces -Y (its left = +X).

def mixamo_bones():
    p = "mixamorig:"
    B = []
    def add(n, par, h, t):
        B.append((p + n, (p + par) if par else None, Vector(h), Vector(t)))
    add("Hips", None, (0, 0, 1.00), (0, 0, 1.10))
    add("Spine", "Hips", (0, 0, 1.10), (0, 0, 1.22))
    add("Spine1", "Spine", (0, 0, 1.22), (0, 0, 1.34))
    add("Spine2", "Spine1", (0, 0, 1.34), (0, 0, 1.46))
    add("Neck", "Spine2", (0, 0, 1.46), (0, 0, 1.56))
    add("Head", "Neck", (0, 0, 1.56), (0, 0, 1.76))
    add("HeadTop_End", "Head", (0, 0, 1.76), (0, 0, 1.80))
    for side, s in (("Left", 1), ("Right", -1)):
        add(side + "Shoulder", "Spine2", (0.05 * s, 0, 1.42), (0.18 * s, 0, 1.42))
        add(side + "Arm", side + "Shoulder", (0.18 * s, 0, 1.42), (0.46 * s, 0, 1.42))   # T-pose
        add(side + "ForeArm", side + "Arm", (0.46 * s, 0, 1.42), (0.72 * s, 0, 1.42))
        add(side + "Hand", side + "ForeArm", (0.72 * s, 0, 1.42), (0.80 * s, 0, 1.42))
        for f, y in (("Index", -0.02), ("Middle", 0.0), ("Ring", 0.02), ("Pinky", 0.035)):
            x0 = 0.80
            for j in (1, 2, 3):
                add("%sHand%s%d" % (side, f, j), (side + "Hand") if j == 1 else "%sHand%s%d" % (side, f, j - 1),
                    ((x0 + 0.025 * (j - 1)) * s, y, 1.42), ((x0 + 0.025 * j) * s, y, 1.42))
        for j in (1, 2, 3):
            add("%sHandThumb%d" % (side, j), (side + "Hand") if j == 1 else "%sHandThumb%d" % (side, j - 1),
                ((0.76 + 0.02 * (j - 1)) * s, -0.04 - 0.01 * j, 1.41), ((0.76 + 0.02 * j) * s, -0.05 - 0.01 * j, 1.41))
        add(side + "UpLeg", "Hips", (0.10 * s, 0, 0.98), (0.10 * s, 0, 0.54))
        add(side + "Leg", side + "UpLeg", (0.10 * s, 0, 0.54), (0.10 * s, 0.01, 0.10))
        add(side + "Foot", side + "Leg", (0.10 * s, 0.01, 0.10), (0.10 * s, -0.10, 0.03))
        add(side + "ToeBase", side + "Foot", (0.10 * s, -0.10, 0.03), (0.10 * s, -0.16, 0.02))
        add(side + "Toe_End", side + "ToeBase", (0.10 * s, -0.16, 0.02), (0.10 * s, -0.19, 0.02))
    return B, 0.0


def synty_bones():
    """Shorter, stockier, A-pose (arms ~45 deg down), Root bone at the feet."""
    B = []
    def add(n, par, h, t):
        B.append((n, par, Vector(h), Vector(t)))
    add("Root", None, (0, 0, 0), (0, 0, 0.1))
    add("Hips", "Root", (0, 0, 0.80), (0, 0, 0.90))
    add("Spine_01", "Hips", (0, 0, 0.90), (0, 0, 1.02))
    add("Spine_02", "Spine_01", (0, 0, 1.02), (0, 0, 1.14))
    add("Spine_03", "Spine_02", (0, 0, 1.14), (0, 0, 1.26))
    add("Neck", "Spine_03", (0, 0, 1.26), (0, 0, 1.34))
    add("Head", "Neck", (0, 0, 1.34), (0, 0, 1.62))
    for side, s in (("L", 1), ("R", -1)):
        a = math.radians(45)
        sh = Vector((0.20 * s, 0, 1.22))
        el = sh + Vector((0.24 * math.cos(a) * s, 0, -0.24 * math.sin(a)))
        wr = el + Vector((0.22 * math.cos(a) * s, 0, -0.22 * math.sin(a)))
        hd = wr + Vector((0.07 * math.cos(a) * s, 0, -0.07 * math.sin(a)))
        add("Clavicle_" + side, "Spine_03", (0.04 * s, 0, 1.22), sh)
        add("Shoulder_" + side, "Clavicle_" + side, sh, el)
        add("Elbow_" + side, "Shoulder_" + side, el, wr)
        add("Hand_" + side, "Elbow_" + side, wr, hd)
        for f, y in (("IndexFinger", -0.02), ("Finger", 0.01)):
            for j in (1, 2, 3):
                h = hd + Vector((0.02 * (j - 1) * math.cos(a) * s, y, -0.02 * (j - 1) * math.sin(a)))
                t = hd + Vector((0.02 * j * math.cos(a) * s, y, -0.02 * j * math.sin(a)))
                add("%s_%02d_%s" % (f, j, side), ("Hand_" + side) if j == 1 else "%s_%02d_%s" % (f, j - 1, side), h, t)
        for j in (1, 2, 3):
            h = wr + Vector((0.01 * j * s, -0.03 - 0.015 * j, -0.01 * j))
            add("Thumb_%02d_%s" % (j, side), ("Hand_" + side) if j == 1 else "Thumb_%02d_%s" % (j - 1, side), h, h + Vector((0.01 * s, -0.015, -0.01)))
        add("UpperLeg_" + side, "Hips", (0.12 * s, 0, 0.78), (0.12 * s, 0, 0.44))
        add("LowerLeg_" + side, "UpperLeg_" + side, (0.12 * s, 0, 0.44), (0.12 * s, 0.01, 0.09))
        add("Ankle_" + side, "LowerLeg_" + side, (0.12 * s, 0.01, 0.09), (0.12 * s, -0.08, 0.03))
        add("Ball_" + side, "Ankle_" + side, (0.12 * s, -0.08, 0.03), (0.12 * s, -0.14, 0.02))
        add("Toes_" + side, "Ball_" + side, (0.12 * s, -0.14, 0.02), (0.12 * s, -0.17, 0.02))
    return B, 0.7   # roll offset (radians): different local bone axes than the Mixamo rig


def make_armature(name, bones, roll):
    arm = bpy.data.armatures.new(name + "_Data")
    ob = bpy.data.objects.new(name, arm)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = {}
    for n, par, h, t in bones:
        b = arm.edit_bones.new(n)
        b.head, b.tail = h, t
        b.roll = roll
        if par:
            b.parent = eb[par]
            b.use_connect = False
        eb[n] = b
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob


def skinned_mesh(name, arm_ob, bones, color_by_part=True):
    """One box per bone (rigid skin), so the motion is easy to read."""
    verts, faces, groups = [], [], []
    skip = ("End", "Toes_", "Toe_End", "Root", "Thumb", "Finger", "HandIndex", "HandMiddle", "HandRing", "HandPinky")
    for n, par, h, t in bones:
        if any(k in n for k in skip):
            continue
        axis = t - h
        L = axis.length
        w = 0.16 if ("Spine" in n or "Hips" in n or "Head" in n) else (0.09 if ("Leg" in n or "UpLeg" in n) else 0.07)
        if "Head" in n:
            w = 0.22
        if "Clavicle" in n or "Shoulder" == n[-8:]:
            w = 0.06
        z = axis.normalized()
        x = Vector((1, 0, 0)) if abs(z.x) < 0.9 else Vector((0, 1, 0))
        y = z.cross(x).normalized()
        x = y.cross(z).normalized()
        base = len(verts)
        for dz in (0.0, L):
            for dx, dy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                verts.append(h + z * dz + x * dx * w / 2 + y * dy * w / 2)
        for f in ((0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
            faces.append(tuple(base + i for i in f))
        groups.append((n, list(range(base, base + 8))))
    me = bpy.data.meshes.new(name + "_Mesh")
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.update()
    # UVs: whole mesh on one atlas cell (Synty-style flat colour atlas)
    uv = me.uv_layers.new(name="UVMap")
    for loop in uv.data:
        loop.uv = (0.15, 0.15)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    for n, idx in groups:
        vg = ob.vertex_groups.new(name=n)
        vg.add(idx, 1.0, "REPLACE")
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm_ob
    ob.parent = arm_ob
    return ob


def material(ob, name, rgb):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*rgb, 1)
    ob.data.materials.append(m)


# ---------------------------------------------------------------- clips (authored on the Mixamo rig)

def rest_rot(arm_ob, bn):
    return arm_ob.data.bones[bn].matrix_local.to_quaternion()


def key_rot(arm_ob, bn, frame, axis, deg):
    """Rotate bone relative to its parent about a WORLD axis (as seen at rest)."""
    pb = arm_ob.pose.bones[bn]
    pb.rotation_mode = "QUATERNION"
    r = rest_rot(arm_ob, bn)
    q = r.inverted() @ Quaternion(Vector(axis), math.radians(deg)) @ r
    pb.rotation_quaternion = q
    pb.keyframe_insert("rotation_quaternion", frame=frame)


def key_loc(arm_ob, bn, frame, world_delta):
    pb = arm_ob.pose.bones[bn]
    r = arm_ob.data.bones[bn].matrix_local.to_3x3()
    pb.location = r.inverted() @ Vector(world_delta)
    pb.keyframe_insert("location", frame=frame)


P = "mixamorig:"
X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)

CLIPS = {
    # name: (frames, keys[(frame, bone, axis, deg)], locs[(frame, bone, delta)])
    "Breathing Idle": (60, [(1, "Spine1", X, 0), (30, "Spine1", X, -4), (60, "Spine1", X, 0),
                            (1, "LeftArm", Y, 70), (30, "LeftArm", Y, 66), (60, "LeftArm", Y, 70),
                            (1, "RightArm", Y, -70), (30, "RightArm", Y, -66), (60, "RightArm", Y, -70)],
                       [(1, "Hips", (0, 0, 0)), (30, "Hips", (0, 0, -0.015)), (60, "Hips", (0, 0, 0))]),
    # right arm swings forward (-Y = character front) around X; hips travel 1 m forward (NOT in place)
    "Punching": (30, [(1, "RightArm", Y, -70), (9, "RightArm", Z, 80), (18, "RightArm", Y, -70), (30, "RightArm", Y, -70),
                      (1, "RightForeArm", Z, 60), (9, "RightForeArm", Z, 0), (18, "RightForeArm", Z, 60), (30, "RightForeArm", Z, 60),
                      (1, "LeftArm", Y, 70), (30, "LeftArm", Y, 70), (1, "Spine2", Z, 0), (9, "Spine2", Z, 20), (30, "Spine2", Z, 0)],
                 [(1, "Hips", (0, 0, 0)), (30, "Hips", (0, -1.0, 0))]),
    "Standing 1H Magic Attack 01": (36, [(1, "RightArm", Y, -70), (12, "RightArm", Y, 40), (36, "RightArm", Y, -70),
                                         (1, "LeftArm", Y, 70), (36, "LeftArm", Y, 70)], []),
    "Hit Reaction": (20, [(1, "Spine1", X, 0), (6, "Spine1", X, -18), (20, "Spine1", X, 0), (1, "Head", X, 0), (6, "Head", X, -15), (20, "Head", X, 0),
                          (1, "LeftArm", Y, 70), (20, "LeftArm", Y, 70), (1, "RightArm", Y, -70), (20, "RightArm", Y, -70)],
                     [(1, "Hips", (0, 0, 0)), (6, "Hips", (0, 0.08, 0)), (20, "Hips", (0, 0, 0))]),
    "Dying": (45, [(1, "Hips", X, 0), (45, "Hips", X, -85), (1, "LeftArm", Y, 70), (45, "LeftArm", Y, 20),
                   (1, "RightArm", Y, -70), (45, "RightArm", Y, -20)],
              [(1, "Hips", (0, 0, 0)), (45, "Hips", (0, 0.5, -0.85))]),
    "Walking": (30, [(1, "LeftUpLeg", X, 25), (15, "LeftUpLeg", X, -25), (30, "LeftUpLeg", X, 25),
                     (1, "RightUpLeg", X, -25), (15, "RightUpLeg", X, 25), (30, "RightUpLeg", X, -25),
                     (1, "LeftArm", Y, 70), (30, "LeftArm", Y, 70), (1, "RightArm", Y, -70), (30, "RightArm", Y, -70)],
                [(1, "Hips", (0, 0, 0)), (30, "Hips", (0, -1.2, 0))]),
    "Victory": (40, [(1, "LeftArm", Y, 70), (15, "LeftArm", Y, -60), (40, "LeftArm", Y, -60),
                     (1, "RightArm", Y, -70), (15, "RightArm", Y, 60), (40, "RightArm", Y, 60)], []),
}


def bake_clip(arm_ob, name):
    frames, keys, locs = CLIPS[name]
    arm_ob.animation_data_create()
    act = bpy.data.actions.new("mixamo.com")
    arm_ob.animation_data.action = act
    for f, bn, ax, deg in keys:
        key_rot(arm_ob, P + bn, f, ax, deg)
    for f, bn, d in locs:
        key_loc(arm_ob, P + bn, f, d)
    sc = bpy.context.scene
    sc.frame_start, sc.frame_end = 1, frames
    sc.render.fps = 30
    return act


def select_only(obs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]


def export_fbx(path, obs, anim, types):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    select_only(obs)
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types=types, add_leaf_bones=False,
                             bake_anim=anim, bake_anim_use_all_actions=False, bake_anim_use_nla_strips=False,
                             bake_anim_force_startend_keying=True, bake_anim_simplify_factor=0.0,
                              apply_scale_options="FBX_SCALE_NONE",
                             global_scale=1.0, path_mode="STRIP")


def export_glb(path, obs, anim):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    select_only(obs)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_animations=anim,
                              export_animation_mode="ACTIVE_ACTIONS" if anim else "ACTIONS", export_skins=True)


def png(path, w=64, h=64):
    import struct, zlib
    cols = [(110, 120, 135), (150, 90, 60), (63, 200, 180), (220, 170, 60)]
    rows = b"".join(b"\x00" + b"".join(bytes(cols[(x * 2 // w) + 2 * (y * 2 // h)]) for x in range(w)) for y in range(h))
    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "wb").write(data)


def main():
    syn = os.path.join(OUT, "CC0Test_Synty")
    chars = os.path.join(OUT, "CC0Test_Characters")
    # Mixamo-style character (skinned, no clip)
    reset()
    bones, roll = mixamo_bones()
    arm = make_armature("Armature", bones, roll)
    me = skinned_mesh("Alpha_Surface", arm, bones)
    material(me, "Alpha_Body_MAT", (0.25, 0.45, 0.8))
    export_fbx(os.path.join(chars, "Ch_TestBot.fbx"), [arm, me], False, {"ARMATURE", "MESH"})
    export_glb(os.path.join(chars, "Ch_TestBot.glb"), [arm, me], False)
    # Clip files without skin, flat folder like mixamo.com downloads
    for name in CLIPS:
        reset()
        arm = make_armature("Armature", bones, roll)
        bake_clip(arm, name)
        export_fbx(os.path.join(OUT, "Mixamo", name + ".fbx"), [arm], True, {"ARMATURE"})
        export_glb(os.path.join(OUT, "Mixamo_glb", name + ".glb"), [arm], True)
    # Synty-style character
    reset()
    bones, roll = synty_bones()
    arm = make_armature("SK_Chr_Knight_01", bones, roll)
    me = skinned_mesh("SK_Chr_Knight_01_Body", arm, bones)
    material(me, "PolygonTest_Mat_01_A", (1, 1, 1))
    export_fbx(os.path.join(syn, "Characters", "SK_Chr_Knight_01.fbx"), [arm, me], False, {"ARMATURE", "MESH"})
    arm.name = "SK_Chr_Wizard_01"
    me.name = "SK_Chr_Wizard_01_Body"
    export_glb(os.path.join(syn, "Characters", "SK_Chr_Wizard_01.glb"), [arm, me], False)
    png(os.path.join(syn, "Textures", "PolygonTest_Texture_01_A.png"))
    print("humanoid test packs written to", OUT)

main()
