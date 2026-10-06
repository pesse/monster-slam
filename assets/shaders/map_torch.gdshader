shader_type canvas_item;
// Fackel auf der Gebietskarte (MapAmbience, kind "torch"): eine echte Flammenzunge wie in
// flame.gdshader, die aus der Quelle aufsteigt — unten breit und gelb, oben schmal und rot,
// von Rauschen hin und her gebogen —, dazu ein flackernder Schein und ab und zu ein Funke.
// Vormultipliziertes Alpha: die Flamme deckt das Bild (auch heller Stein lässt sie stehen),
// der Schein gibt nur Licht dazu.
//
// Das Rechteck steht so auf der Quelle, dass sie auf BASE liegt (MapAmbience.spot_rect).
// Alle Fackeln teilen ein Material: COLOR.r trägt den Versatz, COLOR.g die Stärke (Anteil
// von MapLayout.INTENSITY_MAX), COLOR.a das Ausblenden der Karte.
render_mode blend_premul_alpha;

#include "res://assets/shaders/map_ambience.gdshaderinc"

uniform vec3 core_color : source_color = vec3(1.0, 0.93, 0.62);
uniform vec3 mid_color : source_color = vec3(1.0, 0.56, 0.12);
uniform vec3 tip_color : source_color = vec3(0.85, 0.2, 0.04);
uniform vec3 glow_color : source_color = vec3(1.0, 0.55, 0.18);
uniform float glow = 0.45;
uniform float speed = 1.8;
// Wo die Quelle im Rechteck liegt (von oben) und wie hoch die Flamme ist (Anteil der Höhe).
const float BASE = 0.8;
const float FLAME = 0.6;
// Breite durch Höhe des Rechtecks (MapAmbience.SPOT_SIZE["torch"]).
uniform float rect_aspect = 0.5;

void fragment() {
	float seed = COLOR.r * 50.0;
	float strength = COLOR.g * 2.0;
	float t = TIME * speed + seed;
	// p.x quer, p.y von der Quelle (0) bis zur Spitze (1), beide in Flammenhöhen.
	vec2 p = vec2((UV.x - 0.5) * rect_aspect, BASE - UV.y) / FLAME;
	// Die Flamme atmet: mal höher, mal niedriger.
	float tall = 0.85 + 0.25 * noise(vec2(t * 2.3, seed));
	p.y /= tall;
	float bend = (fbm(vec2(p.y * 2.0 - t * 0.7, seed)) - 0.5) * 0.4 * p.y;
	float x = p.x + bend;
	float lick = fbm(vec2(x * 5.0, p.y * 3.2 - t * 1.6));
	float width = 0.2 * sqrt(max(1.0 - p.y, 0.0)) * smoothstep(-0.06, 0.12, p.y);
	float body = 1.0 - smoothstep(width * 0.45, width, abs(x));
	float top = 1.0 - smoothstep(0.3, 1.0, p.y + (lick - 0.5) * 0.55);
	float flame = clamp(body * top * 1.6, 0.0, 1.0);
	float heat = flame * (1.0 - smoothstep(0.0, 0.9, p.y)) * (1.0 - abs(x) / max(width, 0.001) * 0.6);
	vec3 col = mix(tip_color, mid_color, smoothstep(0.1, 0.45, heat));
	col = mix(col, core_color, smoothstep(0.45, 0.8, heat));
	float a = flame * smoothstep(0.0, 0.25, flame + heat) * clamp(strength, 0.0, 1.0);
	// Schein um die Mitte der Flamme, im Rechteck rund gemessen.
	vec2 g = vec2((UV.x - 0.5) * rect_aspect, BASE - FLAME * 0.3 - UV.y);
	float flick = 0.7 + 0.3 * noise(vec2(t * 4.0, seed + 3.0));
	vec3 light = glow_color * exp(-dot(g, g) * 40.0) * glow * flick * strength;
	// Ein Funke, der aufsteigt und verglimmt.
	float life = fract(TIME * 0.6 + hash(vec2(seed, 1.0)));
	vec2 spark = vec2(p.x - (hash(vec2(seed, floor(TIME * 0.6 + hash(vec2(seed, 1.0))))) - 0.5) * 0.2
			- sin(life * 6.0) * 0.05, p.y * tall - 0.6 - life * 0.6);
	light += core_color * exp(-dot(spark, spark) * 2500.0) * (1.0 - life) * strength;
	COLOR = vec4(col * a + light * (1.0 - a), a) * COLOR.a;
}
