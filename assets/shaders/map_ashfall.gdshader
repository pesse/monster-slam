shader_type canvas_item;
// Ascheregen über der Gebietskarte, solange ein Vulkan im Riesenausbruch ist (MapAmbience):
// ein dunkler Schleier und drei Lagen Flocken, die schaukelnd fallen.
//
// Ein Rechteck über dem Bild: COLOR.g die Menge der Asche (0..1), COLOR.a das Ausblenden der Karte.
render_mode blend_premul_alpha;

#include "res://assets/shaders/map_ambience.gdshaderinc"

uniform vec3 ash_color : source_color = vec3(0.34, 0.32, 0.31);
uniform vec3 haze_color : source_color = vec3(0.2, 0.14, 0.12);
uniform float haze = 0.34;

void fragment() {
	float amount = COLOR.g;
	vec2 p = vec2(UV.x * aspect, UV.y);
	float flakes = 0.0;
	for (int layer = 0; layer < 3; layer++) {
		float fl = float(layer);
		// Nahe Lagen: größere Zellen, schnelleres Fallen.
		float scale = 30.0 - fl * 9.0;
		float fall = 0.05 + 0.03 * fl;
		vec2 g = p * scale + vec2(sin(TIME * 0.7 + fl * 2.0) * 0.6 + TIME * 0.4, -TIME * fall * scale);
		vec2 cell = floor(g);
		vec2 f = fract(g) - 0.5;
		vec2 o = (vec2(hash(cell), hash(cell + 3.1)) - 0.5) * 0.6;
		float present = step(0.5, hash(cell + 7.7));
		float r = 0.08 + 0.08 * hash(cell + 1.3);
		flakes += present * (1.0 - smoothstep(r * 0.4, r, length(f - o)));
	}
	float veil = haze * (0.7 + 0.3 * fbm(p * 3.0 + vec2(TIME * 0.05, 0.0))) * amount;
	float fa = clamp(flakes, 0.0, 1.0) * 0.85 * amount;
	float a = fa + veil * (1.0 - fa);
	vec3 col = mix(haze_color, ash_color, fa / max(a, 0.0001));
	COLOR = vec4(col * a, a) * COLOR.a;
}
