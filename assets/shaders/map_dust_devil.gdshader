shader_type canvas_item;
// Ein Staubteufel auf der Gebietskarte (MapAmbience, kind "dust_devil"): ein Wirbel aus Sand,
// unten schmal über einer Staubwolke, nach oben weit. Er schlängelt, wandert ein Stück hin und
// her, Streifen drehen um ihn, und er wird mal kräftiger, mal schwächer. Ein Klick lässt ihn
// zerstieben: der Trichter fällt zusammen, Staub quillt auf, dann wächst er von unten neu.
//
// Ein Rechteck mit der Quelle unten in der Mitte. COLOR.r trägt den Versatz der Quelle,
// COLOR.g die Stärke (Anteil von MapLayout.INTENSITY_MAX), COLOR.b den Verlauf des
// Zerstiebens (0 = keins, sonst bis 1), COLOR.a das Ausblenden der Karte.
render_mode blend_mix;

#include "res://assets/shaders/map_ambience.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.56, 0.41, 0.29);
uniform vec3 top_color : source_color = vec3(0.97, 0.92, 0.82);
uniform float opacity : hint_range(0.0, 1.0) = 0.9;
// Breite durch Höhe des Rechtecks (MapAmbience.SPOT_SIZE).
uniform float rect_aspect = 0.6;
// Dauer des Zerstiebens (s), MapAmbience.STIR_TIME.
uniform float burst_time = 2.4;
// So weit wandert der Fuß zur Seite (Anteil der halben Breite).
uniform float roam = 0.25;

// Wo der Fuß zur Zeit `t` steht, quer in Höhen des Rechtecks (Mitte 0).
float foot(float t, float seed) {
	return (sin(t * 0.29 + seed) * 0.75 + sin(t * 0.83 + seed * 2.0) * 0.25) * roam * rect_aspect * 0.5;
}

void fragment() {
	float seed = COLOR.r * 50.0;
	float strength = COLOR.g * 2.0;
	float burst = COLOR.b;
	float t = TIME + seed;
	// p.x quer in Höhen des Rechtecks (Mitte 0), p.y von unten (0) nach oben (1).
	vec2 p = vec2((UV.x - 0.5) * rect_aspect, 1.0 - UV.y);
	float base_x = foot(t, seed);
	float y = p.y;
	float cx = base_x + sin(y * 6.0 - t * 1.9) * 0.025 * y + sin(t * 0.21 + seed) * 0.06 * y * y;
	float w = 0.025 + 0.06 * y + 0.3 * y * y;
	float u = (p.x - cx) / w;
	float n = fbm(vec2(u * 1.4 + t * 2.6, y * 7.0 - t * 2.2) + seed);
	float body = 1.0 - smoothstep(0.45, 1.0, abs(u) + (n - 0.5) * 0.45);
	float rise = smoothstep(0.0, 0.05, y) * (1.0 - smoothstep(0.55, 0.95, y + (n - 0.5) * 0.3));
	float column = body * rise * mix(0.6, 1.0, n);
	vec2 fd = vec2((p.x - base_x) / 0.13, (y - 0.035) / 0.055);
	float fn = fbm(vec2(p.x * 22.0 - t * 3.0, y * 22.0) + seed);
	float foot_cloud = (1.0 - smoothstep(0.35, 1.0, length(fd) + (fn - 0.5) * 0.6)) * 0.7;
	float life = 0.75 + 0.25 * noise(vec2(t * 0.23, seed));
	float shown = 1.0;
	float puff = 0.0;
	if (burst > 0.0) {
		// Fällt zusammen, dann wächst er von unten neu.
		float regrow = smoothstep(0.72, 1.0, burst);
		column *= max(1.0 - smoothstep(0.0, 0.18, burst),
				regrow * (1.0 - smoothstep(regrow * 0.9 - 0.05, regrow * 0.9 + 0.05, y)));
		shown = max(1.0 - smoothstep(0.0, 0.18, burst), regrow);
		// Die Staubwolke quillt dort, wo er beim Klick stand.
		float e = 1.0 - (1.0 - burst) * (1.0 - burst);
		vec2 c = vec2(foot(t - burst * burst_time, seed), 0.1 + 0.22 * e);
		float r = 0.09 + 0.17 * e;
		float pn = fbm(p * 14.0 + vec2(0.0, -t * 0.8) + seed);
		float d = length(p - c) / r;
		puff = (1.0 - smoothstep(0.3, 1.0, d + (pn - 0.5) * 0.7))
				* smoothstep(0.0, 0.05, burst) * (1.0 - smoothstep(0.4, 0.9, burst)) * mix(0.8, 1.4, pn);
	}
	float a = (column * life + foot_cloud * shown * life + puff) * opacity * strength;
	// Die drehenden Streifen hell und dunkel, damit er sich vom Sand abhebt.
	vec3 col = mix(base_color, top_color, smoothstep(0.0, 0.7, y)) * mix(0.8, 1.1, n);
	COLOR = vec4(col, clamp(a, 0.0, 1.0) * COLOR.a);
}
