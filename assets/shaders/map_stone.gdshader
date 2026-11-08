shader_type canvas_item;
// Ein Stein hüpft über das Wasser der Gebietskarte (MapStones): ein flacher Bogen vom Ufer,
// dann immer kürzere Hüpfer, bei jeder Landung ein Ring, bei der letzten ein Platschen.
// Gerechnet in Bildhöhen um den Abwurf, y nach unten; Weiten und Zeiten wie in MapStones.
//
// Je Stein ein Quadrat der Seite BOX um den Abwurf: COLOR.r Zeit seit dem Wurf (Anteil von
// LIFE), COLOR.g Landungen / 16, COLOR.b Richtung / DIRECTIONS, COLOR.a das Ausblenden der Karte.
render_mode blend_premul_alpha;

uniform vec3 stone_dark : source_color = vec3(0.36, 0.34, 0.33);
uniform vec3 stone_light : source_color = vec3(0.78, 0.76, 0.72);
uniform vec3 foam_color : source_color = vec3(0.92, 0.97, 1.0);
uniform vec3 outline_color : source_color = vec3(0.06, 0.08, 0.1);

const float BOX = 0.48;
const float THROW = 0.045;
const float SKIP = 0.04;
const float SHRINK = 0.8;
const float THROW_TIME = 0.45;
const float SKIP_TIME = 0.3;
const float RIPPLE_TIME = 0.9;
const float LIFE = 3.2;
const int MAX_SKIPS = 9;
const float DIRECTIONS = 24.0;
// Höhe des Bogens je Weite: der Wurf steigt höher als die Hüpfer.
const float THROW_RISE = 0.45;
const float SKIP_RISE = 0.22;
// Halbachsen des Steins (Bildhöhen).
const vec2 STONE = vec2(0.008, 0.005);

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

// Ring auf dem Wasser, flach wie aus der Schräge gesehen; s = 0..1 sein Alter.
float ring(vec2 p, float s, float size, float aa) {
	float d = length(vec2(p.x, p.y * 2.6));
	float r = size * (0.2 + 0.8 * s);
	float w = size * 0.2 * (1.0 - 0.4 * s);
	return (1.0 - smoothstep(w - aa, w + aa, abs(d - r))) * pow(1.0 - s, 1.3);
}

// Tropfen, die beim Versinken hochspritzen; s = 0..1 ihr Alter.
float plop(vec2 p, float s, float aa) {
	float a = 0.0;
	for (int k = 0; k < 5; k++) {
		float fk = float(k);
		vec2 at = vec2((hash(fk + 1.0) - 0.5) * 0.02 * s, -(0.022 + 0.012 * hash(fk + 7.0)) * s + 0.03 * s * s);
		a += 1.0 - smoothstep(0.003 - aa, 0.003 + aa, length(p - at));
	}
	return clamp(a, 0.0, 1.0) * (1.0 - smoothstep(0.5, 0.8, s));
}

void fragment() {
	float now = COLOR.r * LIFE;
	int skips = int(round(COLOR.g * 16.0));
	float ang = round(COLOR.b * DIRECTIONS) * 6.2831853 / DIRECTIONS;
	vec2 d = vec2(cos(ang), sin(ang));
	vec2 q = (UV - 0.5) * BOX;
	float aa = max(fwidth(q.x), 0.0006);

	float foam = 0.0;
	vec2 stone = vec2(1e3);
	// Drehung des Steins im Flug (rad).
	float spin = 0.0;
	float dist = 0.0;
	float arrive = 0.0;
	for (int k = 1; k <= MAX_SKIPS; k++) {
		if (k > skips) {
			break;
		}
		float len = k == 1 ? THROW : SKIP * pow(SHRINK, float(k - 2));
		float dur = k == 1 ? THROW_TIME : SKIP_TIME * pow(sqrt(SHRINK), float(k - 2));
		if (now >= arrive && now < arrive + dur) {
			float t = (now - arrive) / dur;
			float rise = len * (k == 1 ? THROW_RISE : SKIP_RISE);
			stone = d * (dist + len * t) + vec2(0.0, -4.0 * t * (1.0 - t) * rise);
			spin = now * 2.1;
		}
		dist += len;
		arrive += dur;
		float s = (now - arrive) / RIPPLE_TIME;
		if (s >= 0.0 && s < 1.0) {
			vec2 p = q - d * dist;
			bool last = k == skips;
			float size = last ? 0.036 : 0.026 * sqrt(len / SKIP);
			foam = max(foam, ring(p, s, size, aa));
			if (last) {
				foam = max(foam, ring(p, clamp(s * 1.6 - 0.25, 0.0, 1.0), size * 0.7, aa) * step(0.15, s));
				foam = max(foam, plop(p, s, aa) * 0.9);
			}
		}
	}
	vec3 col = foam_color;
	float a = foam;

	// Der Stein: flach, dreht sich im Flug, mit dunkler Kontur gegen das Wasser.
	vec2 rel = q - stone;
	float c = cos(spin);
	float sn = sin(spin);
	vec2 r = vec2(c * rel.x - sn * rel.y, sn * rel.x + c * rel.y);
	float body = 1.0 - smoothstep(-aa, aa, length(r / STONE) - 1.0);
	float rim = (1.0 - smoothstep(-aa, aa, length(r / (STONE + 0.0018)) - 1.0)) * (1.0 - body);
	vec3 shade = mix(stone_dark, stone_light, smoothstep(0.003, -0.003, rel.y + rel.x * 0.4));
	col = mix(col, outline_color, rim);
	a = max(a, rim * 0.8);
	col = mix(col, shade, body);
	a = max(a, body);
	COLOR = vec4(col * a, a) * COLOR.a;
}
