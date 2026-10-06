shader_type canvas_item;
// Glut auf der Gebietskarte (MapAmbience, kind "ember"): ein weicher,
// flackernder Schein um die Quelle, ein heller Kern und einzelne Funken, die aufsteigen und
// verglimmen. Additiv: es gibt Licht dazu, statt das Bild zu übermalen. Die Fackel hat eine
// eigene Flamme (map_torch.gdshader).
//
// Alle Quellen einer Art teilen ein Material: COLOR.r trägt den Versatz der Quelle,
// COLOR.g die Stärke (Anteil von MapLayout.INTENSITY_MAX), COLOR.a das Ausblenden der Karte.
render_mode blend_add;

#include "res://assets/shaders/map_ambience.gdshaderinc"

uniform vec3 glow_color : source_color = vec3(1.0, 0.42, 0.1);
uniform vec3 core_color : source_color = vec3(1.0, 0.82, 0.45);
uniform float energy = 0.55;
uniform float flicker_hz = 5.0;
uniform int sparks = 3;
// Wie hoch die Funken steigen (Anteil des Rechtecks).
uniform float spark_rise = 0.42;

void fragment() {
	float seed = COLOR.r * 50.0;
	vec2 p = UV - 0.5;
	float flick = 0.65 + 0.35 * noise(vec2(TIME * flicker_hz + seed, seed));
	float d2 = dot(p * vec2(1.0, 1.3), p * vec2(1.0, 1.3));
	float glow = exp(-d2 * 30.0) * flick;
	float core = exp(-d2 * 260.0) * flick;
	float lit = 0.0;
	for (int i = 0; i < 6; i++) {
		if (i >= sparks) {
			break;
		}
		float k = float(i);
		float life = fract(TIME * 0.45 + hash(vec2(seed, k)));
		vec2 at = vec2((hash(vec2(k, seed)) - 0.5) * 0.25 + sin(life * 7.0 + k) * 0.04,
				0.05 - life * spark_rise);
		vec2 off = p - at;
		lit += exp(-dot(off, off) * 5000.0) * (1.0 - life);
	}
	vec3 col = glow_color * glow * energy + core_color * (core * energy + lit);
	COLOR = vec4(col * COLOR.g * 2.0, COLOR.a);
}
