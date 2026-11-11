shader_type canvas_item;
// Flugsand auf der Gebietskarte (MapAmbience, kind "drift"): feine Fahnen aus Sand, die über
// die Dünenkämme wehen. Rauschen, in Windrichtung lang gezogen und schnell versetzt; ein
// größeres, langsameres Rauschen lässt die Fahnen in Böen kommen und gehen. Die Farbe ist der
// gemalte Sand darunter, aufgehellt.
render_mode blend_mix;

#include "res://assets/shaders/map_ambience.gdshaderinc"

uniform vec3 tint : source_color = vec3(1.0, 0.97, 0.9);
uniform float intensity = 1.0;
// Fahnen je Bildhöhe quer zum Wind und ihr Zug (Bildhöhen je Sekunde).
uniform float scale = 140.0;
uniform float drift = 0.09;
// Einstellbar je Karte (MapLayout.PARAMS): Dichte, Länge der Fahnen als Faktor, Tempo als
// Faktor und Richtung in Grad (0 nach rechts, im Uhrzeigersinn).
uniform float density : hint_range(0.0, 1.0) = 0.6;
uniform float streak = 1.0;
uniform float speed = 1.0;
uniform float direction = 0.0;

void fragment() {
	float m = area_mask(UV);
	if (m <= 0.0) {
		discard;
	}
	vec2 wind = vec2(cos(radians(direction)), sin(radians(direction)));
	vec2 p = UV * vec2(aspect, 1.0);
	// Längs und quer zum Wind.
	vec2 q = vec2(dot(p, wind), dot(p, vec2(-wind.y, wind.x)));
	float t = TIME * speed;
	vec2 g = vec2((q.x - t * drift) * scale / (12.0 * streak), q.y * scale);
	g.y += (noise(g * vec2(0.3, 0.1)) - 0.5) * 2.0;
	float n = noise(g) * 0.7 + noise(g * 2.3 + 5.1) * 0.3;
	float streaks = smoothstep(0.5, 0.78, n);
	float gusts = smoothstep(0.3, 0.75, noise(vec2(q.x * 2.5 - t * drift * 8.0, q.y * 3.0)));
	float a = streaks * mix(0.6, 1.0, gusts) * density * 1.3 + 0.1 * gusts * density;
	vec3 sand = min(texture(TEXTURE, UV).rgb * 1.35, vec3(1.0));
	COLOR = vec4(mix(sand, tint, 0.75), clamp(a * intensity, 0.0, 1.0) * m * COLOR.a);
}
