shader_type canvas_item;
// Eine Rauchsäule auf der Gebietskarte (MapAmbience, kind "smoke"): auf einem Rechteck,
// dessen Mitte unten auf der Quelle steht. Rauschen zieht nach oben durch die Säule, sie
// wird nach oben breiter und dünner und biegt sich im Wind. Die Farbe wie der Rauch im
// Kampf (smoke.gdshader): unten warm-dunkel, oben hell und durchscheinend.
//
// Alle Säulen teilen ein Material: COLOR.r trägt den Versatz der Quelle (MapAmbience),
// COLOR.g die Stärke (Anteil von MapLayout.INTENSITY_MAX), COLOR.a das Ausblenden der Karte.
render_mode blend_mix;

#include "res://assets/shaders/map_ambience.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.24, 0.2, 0.18);
uniform vec3 top_color : source_color = vec3(0.62, 0.6, 0.58);
uniform float opacity : hint_range(0.0, 1.0) = 0.7;
uniform float speed = 0.45;
// Neigung im Wind: so weit (Anteil der Breite) steht die Spitze seitlich.
uniform float lean = 0.18;

void fragment() {
	float seed = COLOR.r * 50.0;
	float t = TIME * speed + seed;
	// p.x quer (-0.5..0.5), p.y von unten (0) nach oben (1)
	vec2 p = vec2(UV.x - 0.5, 1.0 - UV.y);
	float sway = (fbm(vec2(p.y * 2.0 - t * 0.4, seed)) - 0.5) * 0.35 * p.y;
	float x = p.x - sway - lean * p.y * p.y;
	float n = fbm(vec2(x * 7.0, p.y * 5.0 - t * 1.4) + seed);
	float width = 0.05 + 0.3 * p.y;
	float body = 1.0 - smoothstep(width * 0.25, width, abs(x) + (n - 0.5) * 0.12);
	float rise = smoothstep(0.0, 0.06, p.y) * (1.0 - smoothstep(0.3, 1.0, p.y + (n - 0.5) * 0.5));
	float a = body * rise * mix(0.45, 1.0, n) * opacity * COLOR.g * 2.0;
	COLOR = vec4(mix(base_color, top_color, smoothstep(0.0, 0.7, p.y)), a * COLOR.a);
}
