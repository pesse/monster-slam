// Gemeinsames der Ambiente-Shader auf den Gebietskarten (MapAmbience): Rauschen wie in
// flame/smoke, und die Maske einer Fläche.
//
// Eine Fläche wird als ganzes Kartenbild gezeichnet (TEXTURE), UV ist darum der Anteil des
// Bildes (0..1), wie die Punkte in map.json. `mask` ist ihre gemalte Maske
// (assets/maps/<book>/unit<n>_<mask>.webp) über demselben Bild: schwarz bleibt still, weiß
// bewegt sich voll, gemalte weiche Ränder laufen weich aus. Gerechnet wird in
// `p = UV * vec2(aspect, 1)`, damit ein Abstand quer so lang ist wie hoch.

uniform sampler2D mask : filter_linear, repeat_disable, hint_default_black;
uniform float aspect = 1.7778;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	return noise(p) * 0.6 + noise(p * 2.1 + 7.3) * 0.3 + noise(p * 4.3 + 1.7) * 0.1;
}

// Wie stark sich das Bild an `uv` bewegt, 0..1.
float area_mask(vec2 uv) {
	return texture(mask, uv).r;
}
