@tool
extends MultiMeshInstance3D

@export var grass_shader: Shader

@export var blade_count: int = 15000
@export var field_size: Vector2 = Vector2(20.0, 20.0)
@export var blade_height: float = 0.5
@export var blade_width: float = 0.045
@export var segments: int = 4
@export var rebuild: bool = false:
	set(v):
		if v: _build()

func _ready() -> void:
	if multimesh == null or multimesh.instance_count == 0:
		_build()

func _build() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _make_blade()
	mm.instance_count = blade_count
	for i in blade_count:
		var x := randf_range(-field_size.x * 0.5, field_size.x * 0.5)
		var z := randf_range(-field_size.y * 0.5, field_size.y * 0.5)
		var t := Transform3D().rotated(Vector3.UP, randf() * TAU)
		t = t.scaled(Vector3(1.0, randf_range(0.8, 1.3), 1.0))
		t.origin = Vector3(x, 0.0, z)
		mm.set_instance_transform(i, t)
	multimesh = mm
	custom_aabb = AABB(Vector3(-field_size.x, 0, -field_size.y),
					   Vector3(field_size.x * 2, blade_height * 2, field_size.y * 2))

func _make_blade() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := blade_width * 0.5
	for seg in segments:
		var y0 := float(seg) / segments
		var y1 := float(seg + 1) / segments
		var w0 := hw * (1.0 - y0)
		var w1 := hw * (1.0 - y1)
		var by0 := y0 * blade_height
		var by1 := y1 * blade_height
		var lb := Vector3(-w0, by0, 0); var rb := Vector3(w0, by0, 0)
		var rt := Vector3(w1, by1, 0); var lt := Vector3(-w1, by1, 0)
		var n := Vector3(0, 0, 1)
		st.set_normal(n); st.set_uv(Vector2(0, y0)); st.add_vertex(lb)
		st.set_normal(n); st.set_uv(Vector2(1, y0)); st.add_vertex(rb)
		st.set_normal(n); st.set_uv(Vector2(1, y1)); st.add_vertex(rt)
		st.set_normal(n); st.set_uv(Vector2(0, y0)); st.add_vertex(lb)
		st.set_normal(n); st.set_uv(Vector2(1, y1)); st.add_vertex(rt)
		st.set_normal(n); st.set_uv(Vector2(0, y1)); st.add_vertex(lt)
	return st.commit()
	
	var mesh := st.commit()

	var mat := ShaderMaterial.new()
	mat.shader = grass_shader
	mesh.surface_set_material(0, mat)
	return mesh
