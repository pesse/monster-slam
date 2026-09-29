shader_type spatial;
render_mode cull_disabled;
// Boden des Schlachtfelds (BattleTheme.ground_material). Die Farbe kommt aus den
// Vertexfarben des Themas; die Detailtextur (BattleTheme.ground_texture) ist grau und
// moduliert nur die Helligkeit: 50 % Grau lässt die Farbe stehen, heller hebt, dunkler
// senkt. Deshalb OHNE source_color — der Wert 128 muss als 0.5 ankommen, nicht linearisiert
// als 0.22.
//
// Beleuchtet wird in light() selbst: Die Farben der Themen sind auf Boden abgestimmt, der
// nur Umgebungslicht bekommt. Die Albedo ist deshalb um shadow_depth gesenkt, und die Sonne
// legt genau diesen Anteil des Umgebungslichts wieder dazu — nicht ihre eigene Helligkeit.
// So steht flacher Boden in der Sonne in der Farbe des Themas, egal wie hell dessen Sonne
// ist; im Schatten fehlt der Anteil, ein abgewandter Hang wird dunkler, einer zur Sonne
// etwas heller. Den Schatten selbst multipliziert gl_compatibility NACH light() auf das
// Ergebnis (ATTENUATION enthält ihn nicht) — deshalb muss die Sonne hier etwas addieren.
//
// Wolkenschatten ziehen in Windrichtung über den Boden (wie Wind.sway, dieselbe `wind_time`):
// ein Rauschen, das der Sonne ihren Anteil nimmt wie ein Schatten, nur weich und schwächer.
// Gerechnet, nicht als Textur — dann gibt es keine Naht und nichts zu laden.

uniform sampler2D detail : filter_linear_mipmap_anisotropic, repeat_enable;
// Wie stark die Textur wirkt: 0 = gar nicht, 1 = voller Kontrast der Datei.
uniform float strength : hint_range(0.0, 1.0) = 0.6;
// Weltmeter je Kachel — so groß ist eine Textur auf dem Boden (siehe assets/textures/ground/BRIEF.md).
uniform float tile_size = 8.0;
// Umgebungslicht des Themas, linear und mal Energie (ambient * ambient_energy).
uniform vec3 ambient_light = vec3(0.21, 0.23, 0.34);
// sin(Sonnenhöhe): so hell trifft die Sonne flachen Boden — das ist „keine Änderung".
uniform float sun_sin = 0.819;
// Wie viel vom Umgebungslicht der Schatten wegnimmt (unter 1).
uniform float shadow_depth : hint_range(0.0, 0.9) = 0.45;
// Wie viel vom Sonnenanteil eine Wolke nimmt (BattleTheme.clouds): 0 = keine Wolken.
uniform float clouds : hint_range(0.0, 1.0) = 0.0;
// Weltmeter je Wolke und ihr Tempo in m/s.
uniform float cloud_size = 22.0;
uniform float cloud_speed = 1.6;

global uniform float wind_time;
const vec2 WIND_DIR = vec2(0.8, 0.6);

varying vec2 world_xz;
// 1 = volle Sonne, darunter liegt eine Wolke (fragment() rechnet, light() nutzt).
varying float sun_left;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// 0 = offen, 1 = unter einer Wolke. Zwei Lagen, damit die Ränder nicht nach Raster aussehen.
float cloud_cover(vec2 xz) {
	vec2 p = (xz - WIND_DIR * wind_time * cloud_speed) / cloud_size;
	float n = 0.65 * value_noise(p) + 0.35 * value_noise(p * 2.3 + vec2(3.7, 1.3));
	return smoothstep(0.42, 0.62, n);
}

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float d = texture(detail, world_xz / tile_size).r;
	ALBEDO = COLOR.rgb * mix(1.0, d * 2.0, strength) * (1.0 - shadow_depth);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	sun_left = 1.0 - clouds * cloud_cover(world_xz);
}

void light() {
	float facing = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) / sun_sin;
	DIFFUSE_LIGHT += ambient_light * (shadow_depth / (1.0 - shadow_depth)) * facing * ATTENUATION * sun_left;
}
