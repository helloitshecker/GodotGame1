shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform sampler2D albedo_tex : source_color, hint_default_white;
uniform vec4 albedo_tint : source_color = vec4(1.0);

// cel diffuse
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.45;
uniform float shadow_smoothness : hint_range(0.0, 0.5) = 0.03;
uniform vec3 shadow_color : source_color = vec3(0.55, 0.5, 0.65); // cool tint

// anime specular dot
uniform float specular_glossiness : hint_range(1.0, 256.0) = 80.0;
uniform float specular_size : hint_range(0.0, 1.0) = 0.5;
uniform float specular_smoothness : hint_range(0.0, 0.3) = 0.02;
uniform vec3 specular_color : source_color = vec3(1.0);

// rim light
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;
uniform float rim_amount : hint_range(0.0, 1.0) = 0.6;
uniform float rim_smoothness : hint_range(0.0, 0.3) = 0.08;
uniform vec3 rim_color : source_color = vec3(1.0);

void fragment() {
	ALBEDO = texture(albedo_tex, UV).rgb * albedo_tint.rgb;
}

void light() {
	// --- stepped diffuse ---
	float ndotl = dot(NORMAL, LIGHT) * ATTENUATION;
	float ramp = smoothstep(shadow_threshold - shadow_smoothness,
							shadow_threshold + shadow_smoothness, ndotl);
	vec3 lit = ALBEDO;
	vec3 shadow = ALBEDO * shadow_color;
	DIFFUSE_LIGHT += mix(shadow, lit, ramp) * LIGHT_COLOR;

	// --- hard specular dot ---
	vec3 H = normalize(VIEW + LIGHT);
	float ndoth = max(dot(NORMAL, H), 0.0);
	float spec = pow(ndoth, specular_glossiness);
	spec = smoothstep(specular_size - specular_smoothness,
					  specular_size + specular_smoothness, spec) * ramp;
	SPECULAR_LIGHT += spec * specular_color * LIGHT_COLOR;

	// --- rim light (only on the lit side) ---
	float fresnel = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), rim_power);
	float rim = smoothstep(rim_amount - rim_smoothness,
						   rim_amount + rim_smoothness, fresnel) * ramp;
	SPECULAR_LIGHT += rim * rim_color;
}