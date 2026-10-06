shader_type canvas_item;
// Nebel auf der Gebietskarte (MapAmbience, kind "mist"): Schwaden aus verzerrtem Rauschen
// (domain warp, wie ground_fog), die langsam ziehen und sich in sich verschieben. Unter den
// dichten Schwaden liegt ein dünner Schleier, damit die Fläche als Ganzes neblig wirkt und
// nicht nur gefleckt; zum Rand der Fläche wird beides dünn.
render_mode blend_mix;

#include "res://assets/shaders/map_ambience.gdshaderinc"

uniform vec3 tint : source_color = vec3(0.93, 0.95, 1.0);
uniform float density : hint_range(0.0, 1.0) = 0.85;
// Der Schleier unter den Schwaden.
uniform float haze : hint_range(0.0, 1.0) = 0.22;
uniform float intensity = 1.0;
// Größe der Schwaden (Rauschzellen je Bildhöhe) und ihr Zug (Bildhöhen je Sekunde).
uniform float scale = 5.0;
uniform float drift = 0.0124;
// Einstellbar je Karte (MapLayout.PARAMS): Schwadengröße als Faktor, Zug als Faktor und
// Richtung in Grad (0 nach rechts, im Uhrzeigersinn).
uniform float puff_size = 1.0;
uniform float speed = 1.0;
uniform float direction = 14.0;

void fragment() {
	float m = area_mask(UV);
	if (m <= 0.0) {
		discard;
	}
	float cells = scale / puff_size;
	vec2 p = UV * vec2(aspect, 1.0) * cells;
	float t = TIME * speed;
	vec2 wind = vec2(cos(radians(direction)), sin(radians(direction))) * drift;
	vec2 q = vec2(fbm(p + t * 0.05), fbm(p - t * 0.04 + 3.1));
	float n = fbm(p * 1.4 + q * 1.6 - wind * t * cells);
	float a = max(smoothstep(0.34, 0.72, n) * density, haze * (0.6 + 0.4 * n));
	COLOR = vec4(tint, clamp(a * intensity, 0.0, 1.0) * m * COLOR.a);
}
