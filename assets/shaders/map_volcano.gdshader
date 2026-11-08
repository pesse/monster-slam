shader_type canvas_item;
// Ein Vulkan auf der Gebietskarte (MapAmbience, kind "volcano"): in Ruhe glimmt der Krater
// und ein dünner Rauchfaden steigt auf. Angefacht (MapAmbience.stir) bricht er aus: ein
// Blitz, Lavabrocken im Bogen, die beim Fallen abkühlen, und eine dunkle Aschewolke. Gereizt
// (MapAmbience.RAGE_CLICKS) bricht er länger aus, mit doppelt so vielen Brocken und pochendem Krater.
//
// Das Rechteck steht so auf dem Krater, dass er auf BASE liegt (MapAmbience.spot_rect).
// Alle Vulkane teilen ein Material: COLOR.r trägt den Versatz, COLOR.g die Stärke (Anteil
// von MapLayout.INTENSITY_MAX), COLOR.b den Ausbruch (0 = Ruhe, sonst sein Verlauf mal
// ERUPT_SCALE, beim Riesenausbruch plus 0.5), COLOR.a das Ausblenden der Karte.
render_mode blend_premul_alpha;

#include "res://assets/shaders/map_ambience.gdshaderinc"

uniform vec3 lava_hot : source_color = vec3(1.0, 0.9, 0.45);
uniform vec3 lava_warm : source_color = vec3(1.0, 0.42, 0.08);
uniform vec3 lava_cold : source_color = vec3(0.32, 0.08, 0.04);
uniform vec3 ash_color : source_color = vec3(0.2, 0.18, 0.18);
uniform vec3 smoke_color : source_color = vec3(0.55, 0.52, 0.5);
// Breite durch Höhe des Rechtecks (MapAmbience.SPOT_SIZE["volcano"]).
uniform float rect_aspect = 0.56;
// Lage des Kraters von oben (MapAmbience.VOLCANO_BASE).
const float BASE = 0.9;
// Dauer des Ausbruchs und des Riesenausbruchs (s, MapAmbience.STIR_TIME["volcano"],
// MapAmbience.RAGE_TIME), Brocken je Ausbruch und Schwerkraft (Rechteckhöhen je s²).
const float ERUPT_TIME = 4.5;
const float RAGE_TIME = 9.0;
const float ERUPT_SCALE = 0.49;
const int BLOBS = 18;
const float GRAVITY = 0.6;

float h1(float n) {
	return fract(sin(n * 91.345) * 47453.5453);
}

void fragment() {
	float seed = COLOR.r * 50.0;
	float strength = COLOR.g * 2.0;
	float rage = step(0.5, COLOR.b);
	float e = COLOR.b > 0.0 ? (COLOR.b - rage * 0.5) / ERUPT_SCALE : 0.0;
	float duration = mix(ERUPT_TIME, RAGE_TIME, rage);
	// p.x quer, p.y vom Krater nach oben, beide in Rechteckhöhen.
	vec2 p = vec2((UV.x - 0.5) * rect_aspect, BASE - UV.y);
	float t = TIME + seed;

	// Rauch: in Ruhe ein Faden, im Ausbruch eine wachsende Aschesäule.
	float burst = e > 0.0 ? smoothstep(0.0, 0.25, e) * (1.0 - smoothstep(0.6, 1.0, e)) : 0.0;
	float plume_top = mix(0.55, min(0.95, 0.2 + e * 2.4), step(0.001, e));
	float sway = (fbm(vec2(p.y * 2.0 - t * 0.3, seed)) - 0.5) * 0.12 * p.y;
	float x = p.x - sway - 0.06 * p.y * p.y;
	float n = fbm(vec2(x * 9.0, p.y * 6.0 - t * mix(0.5, 1.6, burst)) + seed);
	float width = mix(0.01 + 0.08 * p.y, 0.04 + 0.32 * p.y, burst) * (1.0 + 0.6 * rage * burst);
	float body = 1.0 - smoothstep(width * 0.3, width, abs(x) + (n - 0.5) * 0.08);
	float rise = smoothstep(0.0, 0.04, p.y) * (1.0 - smoothstep(plume_top * 0.5, plume_top, p.y + (n - 0.5) * 0.2));
	float smoke_a = body * rise * mix(0.4, 1.0, n) * mix(0.35, 0.95, burst) * clamp(strength + rage, 0.0, 1.0);
	vec3 smoke = mix(smoke_color, ash_color, burst);
	// Die Säule glüht unten im Ausbruch.
	smoke = mix(smoke, lava_warm, burst * (1.0 - smoothstep(0.0, 0.18, p.y)) * 0.6);

	vec3 col = smoke;
	float a = smoke_a;
	vec3 light = vec3(0.0);

	// Krater: glimmt, im Ausbruch hell.
	float crater = exp(-(p.x * p.x * 90.0 + p.y * p.y * 400.0));
	float flick = 0.7 + 0.3 * noise(vec2(t * 3.0, seed));
	light += lava_warm * crater * (0.35 * flick * strength + burst * 1.6);
	// Gereizt pocht der Krater.
	light += lava_hot * crater * rage * burst * (0.5 + 0.5 * sin(t * 9.0));
	// Blitz zu Beginn.
	float flash = e > 0.0 ? (1.0 - smoothstep(0.0, 0.12, e)) * smoothstep(0.0, 0.02, e) : 0.0;
	light += lava_hot * exp(-dot(p, p) * 60.0) * flash * (1.5 + rage);

	if (e > 0.0) {
		float now = e * duration;
		for (int i = 0; i < 2 * BLOBS; i++) {
			if (i >= BLOBS && rage < 0.5) {
				break;
			}
			float fi = float(i) + seed;
			// Die Brocken fliegen in der ersten Hälfte los.
			float tau = now - h1(fi) * duration * 0.45;
			if (tau <= 0.0) {
				continue;
			}
			float vx = (h1(fi * 1.7) - 0.5) * 0.18 * (1.0 + 1.2 * rage);
			float vy = 0.5 + 0.35 * h1(fi * 2.3);
			vec2 at = vec2(vx * tau, vy * tau - 0.5 * GRAVITY * tau * tau);
			if (at.y < -0.04) {
				continue;
			}
			float cool = smoothstep(0.3, 2.2, tau);
			float size = 0.012 + 0.008 * h1(fi * 3.9);
			// Ein kurzer Schweif hinter dem Brocken.
			vec2 vel = vec2(vx, vy - GRAVITY * tau);
			vec2 rel = p - at;
			float along = clamp(dot(rel, -normalize(vel)), 0.0, 0.02);
			vec2 off = rel + normalize(vel) * along;
			float blob = 1.0 - smoothstep(size * 0.6, size, length(off) + along * 0.15);
			vec3 lava = mix(mix(lava_hot, lava_warm, smoothstep(0.0, 0.5, cool)), lava_cold, cool);
			col = mix(col, lava, blob);
			a = blob + a * (1.0 - blob);
			light += lava_warm * exp(-dot(rel, rel) * 3000.0) * (1.0 - cool) * 0.8;
		}
	}
	// Licht läuft zum Rand des Rechtecks auf null aus, sonst stünde es als Kasten da.
	vec2 edge = min(UV, 1.0 - UV);
	light *= smoothstep(0.0, 0.2, edge.x) * smoothstep(0.0, 0.15, edge.y);
	COLOR = vec4(col * a + light * (1.0 - a), a) * COLOR.a;
}
