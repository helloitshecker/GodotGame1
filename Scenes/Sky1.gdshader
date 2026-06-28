shader_type sky;

// ============================================================
//  Night sky with a huge gravitationally-lensed black hole
//  - Background nebula + multi-layer stars, lensed via β = θ - θ_E²/θ
//  - Black event horizon, bright photon ring, lensed Einstein ring
//  - Tilted turbulent accretion disk with Doppler beaming
//  - Lensed "over-the-top" halo (Gargantua wrap)
//  HDR values exceed 1.0 on purpose — enable Glow for the full effect.
// ============================================================

group_uniforms BlackHole;
uniform float bh_azimuth   : hint_range(-3.1416, 3.1416) = 0.0;
uniform float bh_elevation : hint_range(-0.2, 1.4)       = 0.35;
uniform float eh_radius    : hint_range(0.05, 0.6)  = 0.30;  // event horizon angular radius (rad)
uniform float lens_radius  : hint_range(0.05, 0.8)  = 0.40;  // Einstein radius θ_E
uniform float disk_tilt    : hint_range(-0.8, 0.8)  = 0.28;  // open the disk toward camera
uniform float disk_inner   : hint_range(0.1, 0.7)   = 0.34;
uniform float disk_outer   : hint_range(0.3, 1.2)   = 0.74;
uniform float disk_thick   : hint_range(0.005, 0.1) = 0.03;
uniform float beaming      : hint_range(0.0, 3.0)   = 1.8;
uniform float halo_strength: hint_range(0.0, 3.0)   = 1.1;

group_uniforms Sky;
uniform vec3  sky_zenith   : source_color = vec3(0.01, 0.015, 0.04);
uniform vec3  sky_horizon  : source_color = vec3(0.03, 0.04, 0.09);
uniform vec3  nebula_a     : source_color = vec3(0.35, 0.10, 0.55);
uniform vec3  nebula_b     : source_color = vec3(0.05, 0.25, 0.45);
uniform float nebula_strength : hint_range(0.0, 2.0) = 0.7;
uniform float star_density    : hint_range(0.0, 1.0) = 0.5;
uniform float star_brightness : hint_range(0.0, 4.0) = 2.0;

// ---------------- hashing / noise ----------------
float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash13(i + vec3(0,0,0));
	float n100 = hash13(i + vec3(1,0,0));
	float n010 = hash13(i + vec3(0,1,0));
	float n110 = hash13(i + vec3(1,1,0));
	float n001 = hash13(i + vec3(0,0,1));
	float n101 = hash13(i + vec3(1,0,1));
	float n011 = hash13(i + vec3(0,1,1));
	float n111 = hash13(i + vec3(1,1,1));
	return mix(mix(mix(n000,n100,f.x), mix(n010,n110,f.x), f.y),
	           mix(mix(n001,n101,f.x), mix(n011,n111,f.x), f.y), f.z);
}

float fbm3(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise3(p);
		p *= 2.02;
		a *= 0.5;
	}
	return v;
}

// star field for a given (lensed) direction
vec3 stars(vec3 d, float t) {
	vec3 acc = vec3(0.0);
	// three layers of different density/brightness
	for (int layer = 0; layer < 3; layer++) {
		float scale = 120.0 + float(layer) * 90.0;
		vec3 sp = d * scale;
		vec3 id = floor(sp);
		vec3 fp = fract(sp) - 0.5;
		float rnd = hash13(id + float(layer) * 7.3);
		float present = step(1.0 - star_density * (0.05 - float(layer) * 0.012), rnd);
		float point = present * smoothstep(0.32, 0.0, length(fp));
		float twinkle = 0.6 + 0.4 * sin(t * 3.0 + rnd * 60.0);
		float warm = hash13(id + 19.1);
		vec3 tint = mix(vec3(0.7, 0.8, 1.0), vec3(1.0, 0.85, 0.7), warm);
		acc += tint * point * twinkle * (1.0 - float(layer) * 0.25);
	}
	return acc * star_brightness;
}

// emissive accretion disk sampled along direction s
vec4 disk_sample(vec3 s, vec3 bh, vec3 n, vec3 e1, vec3 e2, float t) {
	float th = acos(clamp(dot(s, bh), -1.0, 1.0));
	float radial = smoothstep(disk_inner, disk_inner + 0.02, th)
	             * (1.0 - smoothstep(disk_outer - 0.08, disk_outer, th));
	if (radial <= 0.0) return vec4(0.0);

	float h  = dot(s, n);
	vec3  ip = normalize(s - h * n);
	float rn = clamp((th - disk_inner) / (disk_outer - disk_inner), 0.0, 1.0);

	float thlocal = disk_thick * (0.4 + 0.6 * rn);
	float vert = exp(-(h * h) / (2.0 * thlocal * thlocal));

	float az = atan(dot(ip, e2), dot(ip, e1));
	float spiral = az * 3.0 + (1.0 / (rn + 0.15)) * 6.0 - t * 1.5;
	vec3  np = vec3(cos(spiral), sin(spiral), rn * 4.0 - t * 0.3);
	float turb = fbm3(np * 1.5 + ip * 4.0);
	float bands = 0.55 + 0.85 * turb;

	// relativistic Doppler beaming: + side approaching the camera
	vec3  vdir = normalize(cross(n, ip));
	float dopp = dot(vdir, -s);
	float beam = max(1.0 + beaming * dopp, 0.05);

	// temperature: hot white-blue inside -> cool orange/red outside
	vec3 hot  = vec3(1.7, 1.5, 1.3);
	vec3 mid  = vec3(1.6, 0.7, 0.25);
	vec3 cool = vec3(0.9, 0.22, 0.07);
	vec3 dcol = mix(hot, mix(mid, cool, smoothstep(0.3, 1.0, rn)), smoothstep(0.0, 0.4, rn));
	dcol = mix(dcol, dcol.bgr * vec3(0.8, 0.9, 1.3), clamp(dopp, 0.0, 1.0) * 0.5); // blueshift

	float intensity = radial * vert * bands * beam;
	intensity *= mix(2.2, 1.0, smoothstep(0.0, 0.15, rn)); // bright inner edge
	return vec4(dcol * intensity, clamp(intensity, 0.0, 1.0));
}

void sky() {
	vec3 dir = normalize(EYEDIR);

	// ---- black hole frame ----
	vec3 bh = vec3(cos(bh_elevation) * sin(bh_azimuth),
	               sin(bh_elevation),
	               -cos(bh_elevation) * cos(bh_azimuth));
	vec3 up = abs(bh.y) > 0.99 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
	vec3 right  = normalize(cross(bh, up));
	vec3 updir  = normalize(cross(right, bh));
	vec3 n  = normalize(cos(disk_tilt) * updir + sin(disk_tilt) * bh); // disk-plane normal
	vec3 e1 = right;
	vec3 e2 = normalize(cross(n, right));

	// ---- gravitational lensing of the background ----
	float cosT  = dot(dir, bh);
	float theta = max(acos(clamp(cosT, -1.0, 1.0)), 1e-4);
	vec3  tang  = dir - cosT * bh;
	tang = length(tang) < 1e-5 ? right : normalize(tang);
	float defl  = (lens_radius * lens_radius) / theta;   // point-mass deflection
	float beta  = max(theta - defl, 0.0);                // source angle (primary image)
	vec3  ldir  = normalize(cos(beta) * bh + sin(beta) * tang);

	// ---- background sky gradient ----
	float up_t = clamp(dir.y * 0.5 + 0.5, 0.0, 1.0);
	vec3 col = mix(sky_horizon, sky_zenith, smoothstep(0.0, 1.0, up_t));

	// ---- nebula + milky-way band (lensed) ----
	float neb = fbm3(ldir * 2.2 + 11.0);
	neb = pow(neb, 2.2);
	float band = exp(-pow(dot(ldir, vec3(0.2, 0.95, 0.1)) * 2.4, 2.0)); // bright galactic band
	vec3 nebcol = mix(nebula_a, nebula_b, fbm3(ldir * 1.3 - 4.0));
	col += nebcol * (neb * 0.7 + band * 0.5) * nebula_strength;

	// ---- stars (lensed) ----
	col += stars(ldir, TIME);

	// magnification glow piling up at the Einstein ring
	float er = exp(-pow((theta - lens_radius) / 0.025, 2.0));
	col += vec3(0.6, 0.75, 1.0) * er * 1.4;

	// ---- event horizon (pure black) ----
	if (theta < eh_radius) col = vec3(0.0);

	// ---- photon ring just outside the horizon ----
	float pr = exp(-pow((theta - (eh_radius + 0.012)) / 0.012, 2.0));
	col += vec3(1.4, 1.5, 1.7) * pr * 3.0;

	// ---- accretion disk (direct image: horizontal band wrapping behind BH) ----
	vec4 d = disk_sample(dir, bh, n, e1, e2, TIME);
	col = col * (1.0 - d.a) + d.rgb;

	// ---- lensed halo: disk light bent around the hole (additive arcs) ----
	vec4 h = disk_sample(ldir, bh, n, e1, e2, TIME);
	float ring_prox = exp(-pow((theta - (eh_radius + 0.05)) / 0.12, 2.0));
	col += h.rgb * ring_prox * halo_strength;

	// dither to kill banding
	col += (hash13(dir * 2000.0) - 0.5) / 255.0;

	COLOR = col;
}