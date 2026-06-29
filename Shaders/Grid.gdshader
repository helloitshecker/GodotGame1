shader_type spatial;

uniform float cell_size = 1.0;            // world units per cell
uniform float line_width : hint_range(0.5, 5.0) = 1.5;  // in pixels
uniform vec3 line_color : source_color = vec3(0.6);
uniform vec3 bg_color : source_color = vec3(0.1);
uniform float fade_distance = 40.0;       // grid fades out past this

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 coord = world_pos.xz / cell_size;

	// distance to nearest cell line, in cells
	vec2 grid = abs(fract(coord - 0.5) - 0.5);
	// derivative = how fast coord changes per pixel → keeps line constant width
	vec2 deriv = fwidth(coord);
	vec2 line = grid / deriv;
	float g = min(line.x, line.y);

	// g < line_width → on a line
	float strength = 1.0 - min(g / line_width, 1.0);

	// fade with distance from camera
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	strength *= 1.0 - smoothstep(fade_distance * 0.5, fade_distance, dist);

	ALBEDO = mix(bg_color, line_color, strength);
}