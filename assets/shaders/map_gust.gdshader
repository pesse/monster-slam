shader_type canvas_item;
// Sandböe über der Gebietskarte (MapAmbience, kind "gust"): alle `every` Sekunden zieht
// `span` Sekunden lang ein Band aus Sand in Windrichtung über die ganze Karte — eine weiche
// Front, dahinter Schwaden und feine Fahnen. Dazwischen ist es klar.
render_mode blend_mix;

#include "res://assets/shaders/map_ambience.gdshaderinc"

uniform vec3 dust : source_color = vec3(0.88, 0.7, 0.47);
uniform vec3 streak_color : source_color = vec3(1.0, 0.9, 0.72);
uniform float intensity = 1.0;
// Dichte des Schleiers bei voller Böe und Breite des Bandes (Bildhöhen).
uniform float haze = 0.5;
uniform float band = 1.3;
// Einstellbar je Karte (MapLayout.PARAMS): Abstand und Dauer (s), Dichte, Richtung in Grad.
uniform float every = 70.0;
uniform float span = 7.0;
uniform float density : hint_range(0.0, 1.0) = 0.6;
uniform float direction = 0.0;

void fragment() {
	float phase = mod(TIME, max(every, span));
	if (phase > span) {
		discard;
	}
	vec2 wind = vec2(cos(radians(direction)), sin(radians(direction)));
	vec2 p = UV * vec2(aspect, 1.0);
	vec2 c = vec2(aspect, 1.0) * 0.5;
	// Längs und quer zum Wind, von der Bildmitte aus; `reach` deckt jede Richtung ab.
	vec2 q = vec2(dot(p - c, wind), dot(p - c, vec2(-wind.y, wind.x)));
	float reach = 0.5 * length(vec2(aspect, 1.0));
	float front = mix(-reach, reach + band, phase / span);
	float s = q.x - front;
	float body = (1.0 - smoothstep(-0.35, 0.0, s)) * smoothstep(-band, -band + 0.5, s);
	float n = fbm(vec2(q.x * 3.0 - TIME * 0.9, q.y * 5.0));
	float streaks = smoothstep(0.55, 0.85, fbm(vec2((q.x - TIME * 0.35) * 6.0, q.y * 60.0)));
	float veil = haze * (0.55 + 0.45 * n) * body;
	float fine = streaks * body * 0.5;
	float a = clamp((veil + fine * (1.0 - veil)) * density * intensity * 1.6, 0.0, 1.0);
	COLOR = vec4(mix(dust, streak_color, fine / max(veil + fine, 0.0001)), a * COLOR.a);
}
