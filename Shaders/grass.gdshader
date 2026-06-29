shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_toon;

uniform vec3 root_color : source_color = vec3(0.10, 0.28, 0.08);
uniform vec3 tip_color  : source_color = vec3(0.45, 0.72, 0.28);
uniform float wind_strength : hint_range(0.0, 1.0) = 0.18;
uniform float wind_speed : hint_range(0.0, 5.0) = 1.6;
uniform vec2 wind_dir = vec2(1.0, 0.4);
uniform float stiffness : hint_range(0.5, 4.0) = 2.0;
uniform float ao_strength : hint_range(0.0, 1.0) = 0.5;

varying float height_factor;

void vertex() {
	float h = clamp(UV.y, 0.0, 1.0);   // 0 at root, 1 at tip
	height_factor = h;

	// per-blade world position → gusts travel coherently across the field
	vec3 world_pos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec2 dir = normalize(wind_dir);
	float phase = dot(world_pos.xz, dir) * 0.6 + TIME * wind_speed;
	float sway = sin(phase) + 0.3 * sin(phase * 2.7 + 1.3);

	// bend scales with height^stiffness so the base stays planted
	float bend = pow(h, stiffness) * wind_strength * sway;
	VERTEX.x += bend;
	VERTEX.z += bend * 0.5;
}

void fragment() {
	ALBEDO = mix(root_color, tip_color, height_factor);
	// fake AO darkening toward the root
	ALBEDO *= mix(1.0 - ao_strength, 1.0, height_factor);
	ROUGHNESS = 0.85;
	// thin blades are double-sided — flip normal on back faces so lighting is correct
	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
}