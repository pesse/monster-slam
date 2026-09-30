shader_type spatial;
// Rauch des Explosionspfeils (Blast): weiche Wolke auf einem Billboard-Quad, gedacht für
// CPUParticles3D. Die Ränder franst ein gerechnetes Rauschen aus, das mit dem Alter des
// Partikels (INSTANCE_CUSTOM.y, 0..1) wabert. Farbe und Deckkraft kommen aus der
// color_ramp der Partikel (COLOR). Jung glüht der Puff von unten orange — das ist das
// Feuer, das in Rauch übergeht. Beleuchtet, damit der Rauch das Licht des Themas annimmt.
render_mode cull_disabled, depth_draw_never, shadows_disabled, specular_disabled,
		diffuse_lambert_wrap, blend_mix;

// Wie lange (Anteil der Lebenszeit) ein Puff noch glüht; 0 = reiner Rauch.
uniform float ember : hint_range(0.0, 1.0) = 0.25;
uniform vec3 ember_color : source_color = vec3(1.0, 0.45, 0.1);
uniform float ember_energy : hint_range(0.0, 8.0) = 3.0;

varying float v_age;
varying float v_seed;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
			mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		sum += amp * value_noise(p);
		p *= 2.1;
		amp *= 0.5;
	}
	return sum;
}

void vertex() {
	// Billboard wie BILLBOARD_PARTICLES des StandardMaterial3D: zur Kamera gedreht, um
	// den Partikelwinkel (INSTANCE_CUSTOM.x) gerollt, Skalierung des Partikels behalten.
	mat4 world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]),
			normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	float a = INSTANCE_CUSTOM.x;
	world = world * mat4(vec4(cos(a), -sin(a), 0.0, 0.0), vec4(sin(a), cos(a), 0.0, 0.0),
			vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * world;
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	v_age = INSTANCE_CUSTOM.y;
	v_seed = fract(MODEL_MATRIX[3].x * 3.17 + MODEL_MATRIX[3].z * 1.93);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv);
	vec2 np = UV * 3.0 + vec2(v_seed * 17.0, v_seed * 5.0 - v_age * 1.2);
	float n = fbm(np);
	// Eine runde Wolke, deren Rand das Rauschen zerfranst; mit dem Alter wird sie lockerer.
	float shape = 1.0 - smoothstep(0.35, 1.0, r + (n - 0.5) * (0.6 + v_age * 0.5));
	float density = shape * mix(0.75, 1.0, n);
	vec3 base = COLOR.rgb * mix(0.8, 1.15, n);
	ALBEDO = base;
	// Glut: jung, und unten stärker (UV.y wächst nach unten).
	float glow = (1.0 - smoothstep(0.0, max(ember, 0.001), v_age)) * mix(0.4, 1.0, UV.y);
	EMISSION = ember_color * ember_energy * glow * n;
	ALPHA = clamp(density * COLOR.a, 0.0, 1.0);
}
