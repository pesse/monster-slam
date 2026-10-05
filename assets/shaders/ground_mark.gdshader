shader_type spatial;
// Ein Fleck auf dem Boden unter einem Zauber: Brandfleck des Donnerschlags, Raureif des
// Frosts, Schlamm des Sumpfs (SpellFx, SlowAura). Ein flaches Quad, dessen runder Rand ein
// gerechnetes Rauschen ausfranst; `glow` lässt es von innen schimmern (Glut, Eis), `ripples`
// lässt Ringe nach außen laufen (Schlamm). `fade` blendet aus.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

uniform vec4 color : source_color = vec4(0.05, 0.04, 0.035, 0.85);
uniform vec3 glow_color : source_color = vec3(0.45, 0.65, 1.0);
uniform float glow : hint_range(0.0, 4.0) = 0.0;
uniform float ripples : hint_range(0.0, 1.0) = 0.0;
uniform float ring_energy : hint_range(0.0, 4.0) = 0.8;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float seed = 0.0;

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

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv);
	float n = fbm(uv * 2.6 + vec2(seed * 13.0, seed * 7.0));
	float edge = 0.78 + (n - 0.5) * 0.4;
	float body = 1.0 - smoothstep(edge - 0.22, edge, r);
	// Ringe, die langsam nach außen laufen, und Glanz, der über die Fläche zieht.
	float ring = ripples * pow(0.5 + 0.5 * sin(r * 20.0 - TIME * 2.6), 6.0) * body;
	float sheen = ripples * pow(fbm(uv * 3.0 + vec2(TIME * 0.15, -TIME * 0.1)), 3.0) * body;
	// Glut oder Eis: Adern im Rauschen, zum Rand hin stärker.
	float vein = glow * pow(1.0 - abs(n * 2.0 - 1.0), 8.0) * body * smoothstep(0.1, 0.7, r);
	ALBEDO = color.rgb * mix(0.8, 1.15, n);
	EMISSION = glow_color * (vein + (ring + sheen) * ring_energy);
	ALPHA = clamp(body * color.a * mix(0.75, 1.0, n) * fade + (ring + vein) * 0.3 * fade,
			0.0, 1.0);
}
