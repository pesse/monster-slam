shader_type spatial;
// Feuerball des Explosionspfeils (Blast): eine Kugel, deren Oberfläche ein Rauschen nach
// außen beult und deren Rand sich mit `progress` auflöst. Die Farbe läuft von Weißglut
// über Gelb und Orange zu dunklem Rot; die Mitte (zur Kamera gewandt) bleibt heißer als
// der Rand. Das Rauschen ist gerechnet, keine Textur. Selbstleuchtend: der Glow des
// WorldEnvironments macht daraus den Schein. GL-Compatibility-tauglich.
render_mode unshaded, cull_back, shadows_disabled, depth_draw_never, blend_mix;

// 0 = eben gezündet, 1 = verglüht.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
// Zufallsversatz je Explosion, damit nicht zwei gleich aussehen.
uniform vec3 seed = vec3(0.0);
uniform float bulge : hint_range(0.0, 1.0) = 0.55;
uniform float glow : hint_range(0.0, 8.0) = 1.4;

varying float v_noise;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float value_noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float sum = 0.0;
	float amp = 0.55;
	for (int i = 0; i < 4; i++) {
		sum += amp * value_noise(p);
		p *= 2.03;
		amp *= 0.5;
	}
	return sum;
}

vec3 heat(float t) {
	// t: 1 = weißglühend, 0 = erloschen.
	vec3 white = vec3(1.0, 0.97, 0.85);
	vec3 yellow = vec3(1.0, 0.78, 0.25);
	vec3 orange = vec3(1.0, 0.42, 0.08);
	vec3 red = vec3(0.45, 0.07, 0.03);
	if (t > 0.75) return mix(yellow, white, (t - 0.75) / 0.25);
	if (t > 0.45) return mix(orange, yellow, (t - 0.45) / 0.3);
	return mix(red, orange, t / 0.45);
}

void vertex() {
	vec3 p = VERTEX * 3.2 + seed + vec3(0.0, -progress * 2.0, 0.0);
	// Kontrast: sonst mittelt fbm zu einem glatten Ball.
	v_noise = smoothstep(0.2, 0.8, fbm(p));
	VERTEX += NORMAL * (v_noise - 0.35) * bulge;
}

void fragment() {
	// Zur Kamera gewandt = Mitte der Kugel im Bild = heißer.
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float t = clamp(0.9 - progress * 1.25 + facing * 0.3 + (v_noise - 0.5) * 1.0, 0.0, 1.0);
	vec3 col = heat(t);
	// Wo es erkaltet, bleibt Ruß: der Übergang in den Rauch.
	float soot = smoothstep(0.25, 0.0, t) * smoothstep(0.2, 0.6, progress);
	ALBEDO = mix(col, vec3(0.12, 0.1, 0.09), soot);
	EMISSION = col * glow * (0.2 + t * t) * (1.0 - soot);
	// Auflösen: ab der Hälfte frisst das Rauschen die Kugel von außen her.
	float edge = smoothstep(0.0, 0.25, facing);
	float keep = v_noise + edge * 0.3 - smoothstep(0.35, 1.0, progress) * 1.1;
	ALPHA = clamp(keep * 3.0, 0.0, 1.0) * (1.0 - smoothstep(0.85, 1.0, progress));
}
