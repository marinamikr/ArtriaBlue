import bpy
import bmesh
import math


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)
    for mat in list(bpy.data.materials):
        bpy.data.materials.remove(mat)
    for light in list(bpy.data.lights):
        bpy.data.lights.remove(light)
    for cam in list(bpy.data.cameras):
        bpy.data.cameras.remove(cam)


def make_material(name, base_color, roughness=0.45, specular=0.45, metallic=0.0, subsurface=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    for node in list(nodes):
        nodes.remove(node)

    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = (*base_color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = specular
    elif "Specular" in bsdf.inputs:
        bsdf.inputs["Specular"].default_value = specular
    bsdf.inputs["Metallic"].default_value = metallic
    if "Subsurface Weight" in bsdf.inputs:
        bsdf.inputs["Subsurface Weight"].default_value = subsurface
    elif "Subsurface" in bsdf.inputs:
        bsdf.inputs["Subsurface"].default_value = subsurface
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def assign_material(obj, mat):
    if obj.data.materials:
        obj.data.materials[0] = mat
    else:
        obj.data.materials.append(mat)


def shade_smooth(obj):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.shade_smooth()
    obj.select_set(False)


def create_uv_sphere(name, radius=1.0, location=(0, 0, 0), scale=(1, 1, 1), segments=48, rings=24):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=segments,
        ring_count=rings,
        radius=radius,
        location=location,
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    shade_smooth(obj)
    return obj


def create_ico_sphere(name, radius=1.0, location=(0, 0, 0), subdivisions=3):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=radius, location=location)
    obj = bpy.context.active_object
    obj.name = name
    shade_smooth(obj)
    return obj


def create_cylinder(name, radius=0.2, depth=1.0, location=(0, 0, 0), rotation=(0, 0, 0), vertices=32):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=depth,
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.active_object
    obj.name = name
    shade_smooth(obj)
    return obj


def create_beak(name, location=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(
        vertices=24,
        radius1=0.14,
        radius2=0.03,
        depth=0.28,
        location=location,
        rotation=(math.radians(90), 0, 0),
    )
    obj = bpy.context.active_object
    obj.name = name
    return obj


def create_eye(name, location=(0, 0, 0), scale=1.0):
    eye = create_uv_sphere(name, radius=0.1 * scale, location=location, segments=24, rings=16)
    eye.scale = (1.0, 0.85, 1.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return eye


def create_cheek(name, location=(0, 0, 0)):
    cheek = create_uv_sphere(name, radius=0.08, location=location, segments=18, rings=12)
    cheek.scale = (1.0, 0.65, 1.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return cheek


def create_helmet():
    # Blue helmet-like cap.
    helmet = create_uv_sphere(
        "Helmet",
        radius=1.0,
        location=(0.0, 0.0, 0.85),
        scale=(1.18, 1.04, 1.12),
        segments=64,
        rings=32,
    )

    # Flatten the lower half and carve a light V-shaped front edge.
    bpy.context.view_layer.objects.active = helmet
    bpy.ops.object.mode_set(mode="EDIT")
    bm = bmesh.from_edit_mesh(helmet.data)
    for v in bm.verts:
        if v.co.z < 0:
            v.co.z *= 0.58
        if v.co.y < -0.1:
            v.co.y *= 0.95
        if v.co.y > 0.28 and abs(v.co.x) < 0.58:
            v.co.z -= 0.16 * (1.0 - abs(v.co.x) / 0.58)
        if v.co.y > 0.55 and v.co.z > 0.2:
            v.co.z *= 1.03
    bmesh.update_edit_mesh(helmet.data)
    bpy.ops.object.mode_set(mode="OBJECT")
    return helmet


def create_face_shell():
    face = create_uv_sphere(
        "Face",
        radius=1.0,
        location=(0.0, 0.0, -0.03),
        scale=(1.08, 1.0, 1.06),
        segments=64,
        rings=32,
    )

    # Shape it into a chick-like face.
    bpy.context.view_layer.objects.active = face
    bpy.ops.object.mode_set(mode="EDIT")
    bm = bmesh.from_edit_mesh(face.data)
    for v in bm.verts:
        if v.co.z > 0.22:
            v.co.z *= 0.66
        if v.co.z < -0.42:
            v.co.z *= 0.42
        if v.co.y > 0.2:
            v.co.y *= 0.82
        if abs(v.co.x) > 0.58 and v.co.z < -0.02:
            v.co.x *= 1.22
        if abs(v.co.x) < 0.28 and v.co.z < -0.12:
            v.co.z *= 0.56
        if v.co.y > 0.45 and v.co.z > 0.0 and abs(v.co.x) < 0.25:
            v.co.z += 0.05
    bmesh.update_edit_mesh(face.data)
    bpy.ops.object.mode_set(mode="OBJECT")
    return face


def create_arm(side=1):
    # side = 1 for right, -1 for left from the character's perspective.
    loc = (0.82 * side, 0.0, -0.08)
    rot = (math.radians(84), math.radians(8 * side), math.radians(18 * side))
    arm = create_cylinder(
        f"Arm_{'R' if side > 0 else 'L'}",
        radius=0.15,
        depth=0.82,
        location=loc,
        rotation=rot,
        vertices=22,
    )
    # Puff out the far end slightly.
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    bm = bmesh.from_edit_mesh(arm.data)
    for v in bm.verts:
        if v.co.z > 0:
            v.co.z *= 1.1
            v.co.x *= 1.15
    bmesh.update_edit_mesh(arm.data)
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def create_glove(side=1):
    glove = create_ico_sphere(
        f"Glove_{'R' if side > 0 else 'L'}",
        radius=0.2,
        location=(1.2 * side, -0.02, -0.3),
        subdivisions=2,
    )
    glove.scale = (1.22, 0.48, 1.02)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return glove


def create_body():
    body = create_uv_sphere(
        "Body",
        radius=1.02,
        location=(0.0, 0.0, -1.08),
        scale=(0.98, 0.9, 1.32),
        segments=56,
        rings=28,
    )
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.mode_set(mode="EDIT")
    bm = bmesh.from_edit_mesh(body.data)
    for v in bm.verts:
        if v.co.z > 0.25:
            v.co.z *= 0.58
        if v.co.z < -0.25:
            v.co.z *= 0.72
        if abs(v.co.x) < 0.45 and v.co.z < 0.0:
            v.co.y *= 0.86
        if abs(v.co.x) < 0.18 and v.co.z < -0.65:
            v.co.z -= 0.18
    bmesh.update_edit_mesh(body.data)
    bpy.ops.object.mode_set(mode="OBJECT")
    return body


def create_hole(location):
    hole = create_cylinder("HelmetHole", radius=0.06, depth=0.08, location=location, rotation=(0, 0, 0), vertices=16)
    return hole


def create_foot(name, side=1):
    foot = create_ico_sphere(name, radius=0.14, location=(0.18 * side, 0.0, -2.08), subdivisions=2)
    foot.scale = (0.9, 0.6, 1.45)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.context.view_layer.objects.active = foot
    bpy.ops.object.mode_set(mode="EDIT")
    bm = bmesh.from_edit_mesh(foot.data)
    for v in bm.verts:
        if v.co.z < 0:
            v.co.z *= 0.68
        if v.co.x * side > 0:
            v.co.x *= 1.15
    bmesh.update_edit_mesh(foot.data)
    bpy.ops.object.mode_set(mode="OBJECT")
    return foot


def create_camera_and_lights():
    bpy.ops.object.light_add(type="AREA", location=(3.2, -2.4, 4.9))
    key = bpy.context.active_object
    key.data.energy = 4200
    key.data.shape = "RECTANGLE"
    key.data.size = 4.0
    key.data.size_y = 3.0

    bpy.ops.object.light_add(type="AREA", location=(-3.3, -1.2, 3.0))
    fill = bpy.context.active_object
    fill.data.energy = 1800
    fill.data.shape = "RECTANGLE"
    fill.data.size = 5.0
    fill.data.size_y = 3.6

    bpy.ops.object.light_add(type="SUN", location=(0.0, 0.0, 6.0))
    sun = bpy.context.active_object
    sun.data.energy = 1.8

    bpy.ops.object.camera_add(location=(0.0, -9.2, 0.95), rotation=(math.radians(85), 0, 0))
    cam = bpy.context.active_object
    bpy.context.scene.camera = cam

    return cam


def setup_world():
    scene = bpy.context.scene
    # Blender 4.x/5.x compatibility: 4.x uses BLENDER_EEVEE, newer builds may
    # expose EEVEE Next internally but still accept the classic enum here.
    scene.render.engine = "BLENDER_EEVEE"
    if hasattr(scene, "eevee"):
        if hasattr(scene.eevee, "use_gtao"):
            scene.eevee.use_gtao = True
        if hasattr(scene.eevee, "gtao_factor"):
            scene.eevee.gtao_factor = 1.5
        if hasattr(scene.eevee, "use_bloom"):
            scene.eevee.use_bloom = True
        if hasattr(scene.eevee, "bloom_intensity"):
            scene.eevee.bloom_intensity = 0.05
    scene.render.film_transparent = False
    scene.view_settings.look = "None"

    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    nodes = world.node_tree.nodes
    links = world.node_tree.links
    for n in list(nodes):
        nodes.remove(n)
    out = nodes.new("ShaderNodeOutputWorld")
    bg = nodes.new("ShaderNodeBackground")
    sky = nodes.new("ShaderNodeTexSky")
    sky.sun_elevation = math.radians(35)
    sky.air_density = 1.1
    sky.ground_albedo = 0.35
    bg.inputs["Strength"].default_value = 0.75
    links.new(sky.outputs["Color"], bg.inputs["Color"])
    links.new(bg.outputs["Background"], out.inputs["Surface"])
    bpy.context.scene.world = world


def make_toon_outline_material(name="Mat_Outline"):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    for node in list(nodes):
        nodes.remove(node)

    out = nodes.new("ShaderNodeOutputMaterial")
    emis = nodes.new("ShaderNodeEmission")
    emis.inputs["Color"].default_value = (0.06, 0.06, 0.08, 1.0)
    emis.inputs["Strength"].default_value = 0.65
    links.new(emis.outputs["Emission"], out.inputs["Surface"])
    return mat


def build_character():
    clear_scene()
    setup_world()

    yellow = make_material("Mat_Yellow", (0.98, 0.91, 0.40), roughness=0.5, specular=0.28, subsurface=0.04)
    blue = make_material("Mat_Blue", (0.3137255, 0.5176471, 0.7686275), roughness=0.22, specular=0.52)
    dark = make_material("Mat_Dark", (0.03, 0.03, 0.04), roughness=0.4, specular=0.08)
    outline_mat = make_toon_outline_material("Mat_Outline")

    # Base yellow sphere.
    body = create_uv_sphere(
        "YellowBall",
        radius=1.0,
        location=(0.0, 0.0, 0.0),
        scale=(1.0, 1.0, 1.0),
        segments=64,
        rings=32,
    )
    assign_material(body, yellow)

    # Blue cap sitting on the upper half of the sphere.
    cap = create_uv_sphere(
        "BlueCap",
        radius=1.02,
        location=(0.0, 0.0, 0.12),
        scale=(1.02, 1.0, 0.9),
        segments=64,
        rings=32,
    )
    bpy.context.view_layer.objects.active = cap
    bpy.ops.object.mode_set(mode="EDIT")
    bm = bmesh.from_edit_mesh(cap.data)
    for v in bm.verts:
        theta = math.atan2(v.co.y, v.co.x)
        # Create six sharp triangular teeth around the lower edge.
        tri_phase = ((theta + math.pi) / (2.0 * math.pi)) * 6.0
        local = tri_phase % 1.0
        dist = abs(local - 0.5) * 2.0
        spike = max(0.0, 1.0 - dist * 1.7) ** 7.0
        base = -0.22
        tooth_height = 0.46
        if v.co.z < 0.24:
            v.co.z = base + spike * tooth_height
        if v.co.z > 0.22:
            v.co.z *= 1.01
        if v.co.z < base:
            v.co.z = base
    bmesh.update_edit_mesh(cap.data)
    bpy.ops.object.mode_set(mode="OBJECT")
    assign_material(cap, blue)

    # Slight glossy highlight on the cap to sell the bowling-ball feel.
    highlight = create_uv_sphere(
        "CapHighlight",
        radius=0.22,
        location=(-0.42, 0.62, 0.72),
        scale=(1.0, 0.7, 1.0),
        segments=20,
        rings=12,
    )
    assign_material(highlight, make_material("Mat_Highlight", (0.9, 0.98, 1.0), roughness=0.08, specular=0.7))

    # Parent everything to a root object for easy movement.
    root = bpy.data.objects.new("PippoRoot", None)
    bpy.context.collection.objects.link(root)
    for obj in [body, cap, highlight]:
        obj.parent = root

    # Presentation setup.
    cam = create_camera_and_lights()
    cam.data.lens = 70
    cam.location = (0.0, -5.2, 1.2)
    cam.rotation_euler = (math.radians(82), 0, 0)

    bpy.context.scene.render.resolution_x = 1024
    bpy.context.scene.render.resolution_y = 1024
    bpy.context.scene.render.resolution_percentage = 100

    for obj in [body, cap, highlight]:
        obj.color = obj.active_material.diffuse_color if obj.active_material else (1, 1, 1, 1)

    return root


def main():
    build_character()

    # Save as a new file so the original pippo.blend stays intact.
    out_path = bpy.path.abspath("//pippo_character_generated.blend")
    bpy.ops.wm.save_as_mainfile(filepath=out_path)
    print(f"Saved: {out_path}")


if __name__ == "__main__":
    main()
