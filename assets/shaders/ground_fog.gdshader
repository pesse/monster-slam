shader_type spatial;
// Bodennebel von „Schwere Luft" (SpellFx.haze): flache Schichten übereinander, die das Feld
// bedecken. Jede zeigt großflächiges Rauschen in Weltkoordinaten, das langsam zieht und sich
// in sich verschiebt (domain warp) — Schwaden, keine Puffs. Die Höhe der Schicht (Welt-y)
// verschiebt das Muster, so sieht der Stapel von oben nach Tiefe aus. Zum Rand der Fläche und
// bei streifendem Blick (Ich-Sicht) blendet sie aus, damit keine Kante zu sehen ist.
// Beleuchtet wie der Rauch, damit der Nebel das Licht des Themas annimmt.
render_mode cull_disabled, depth_draw_never, shadows_disabled, specular_disabled,
		diffuse_lambert_wrap, blend_mix;

uniform vec3 tint : source_color = vec3(0.55, 0.6, 0.72);
uniform float density : hint_range(0.0, 1.0) = 0.3;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
// So groß sind die Schwaden (m je Rauschzelle).
uniform float scale = 7.0;
// Zuggeschwindigkeit (m/s). Jede Schicht zieht in eine etwas andere Richtung (gedreht nach
// ihrer Höhe), so gleiten die Schwaden gegeneinander.
uniform vec2 drift = vec2(1.1, 0.25);
// Wie stark sich die Schwaden in sich verschieben und verdichten.
uniform float churn : hint_range(0.0, 3.0) = 1.0;
// Breite des weichen Rands, Anteil der Fläche.
uniform float edge : hint_range(0.0, 0.5) = 0.25;

varying vec3 v_world;

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

float fbm(vec2 p, int octaves) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < octaves; i++) {
		sum += amp * value_noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		amp *= 0.5;
	}
	return sum;
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float h = v_world.y;
	vec2 p = v_world.xz / scale + vec2(h * 3.1, h * -1.7);
	float turn = (h - 0.5) * 2.2;
	vec2 dir = mat2(vec2(cos(turn), sin(turn)), vec2(-sin(turn), cos(turn))) * drift;
	vec2 t = TIME * dir / scale;
	// Ein langsames Feld verbiegt das zweite: Schwaden, die sich in sich drehen.
	// Der Verzug braucht nur grobe Formen: zwei Oktaven, das Muster selbst vier.
	float c = TIME * 0.12 * churn;
	vec2 warp = vec2(fbm(p * 0.7 + vec2(c, -c * 0.7), 2), fbm(p * 0.7 + vec2(-c * 0.8, c) + 5.2, 2));
	float n = fbm(p + warp * (1.4 + churn) + t, 4);
	// Langsames Atmen: Schwaden ballen sich und lockern sich, nicht überall zugleich.
	float breath = 0.5 + 0.5 * sin(TIME * 0.5 + fbm(p * 0.3, 2) * 6.28);
	float wisps = smoothstep(0.38 + breath * 0.08, 0.72, n);
	vec2 e = min(UV, 1.0 - UV);
	float border = smoothstep(0.0, edge, e.x) * smoothstep(0.0, edge, e.y);
	float facing = smoothstep(0.04, 0.3, abs(dot(normalize(VIEW), NORMAL)));
	ALBEDO = tint * mix(0.85, 1.1, n);
	ALPHA = clamp((0.15 + wisps * 1.1) * density * border * facing * fade, 0.0, 1.0);
}
