shader_type canvas_item;
// Ein Fisch springt aus dem Wasser der Gebietskarte (MapFish): Spritzer und Ringe beim
// Ein- und Auftauchen, ein silbriger Fisch im Bogen dazwischen, und ein goldenes Funkeln,
// wenn er gefangen wird. Gerechnet in Sprungweiten: q = (0, 0) ist, wo er auftaucht,
// (1, 0), wo er landet, y nach unten. Der Bogen ist derselbe wie in MapFish.fish_point.
//
// Je Fisch ein Rechteck: COLOR.r Anteil des Lebens, COLOR.g Fang (0 = nicht gefangen),
// COLOR.b 0.5 für gespiegelt plus Anteil des Sprungs beim Fang mal CAUGHT_SCALE,
// COLOR.a das Ausblenden der Karte.
render_mode blend_premul_alpha;

uniform float rise = 0.7;
uniform float margin = 0.4;
// Anteil des Sprungs am Leben (MapFish.JUMP_TIME / (JUMP_TIME + AFTER_TIME)).
uniform float jump_share = 0.55;
uniform vec3 back_color : source_color = vec3(0.16, 0.38, 0.52);
uniform vec3 belly_color : source_color = vec3(0.88, 0.93, 0.95);
uniform vec3 fin_color : source_color = vec3(0.95, 0.55, 0.25);
uniform vec3 foam_color : source_color = vec3(0.92, 0.97, 1.0);
uniform vec3 gold_color : source_color = vec3(1.0, 0.85, 0.35);
uniform vec3 outline_color : source_color = vec3(0.04, 0.1, 0.16);

const float CAUGHT_SCALE = 0.49;

vec2 path(float t) {
	return vec2(t, -4.0 * t * (1.0 - t) * rise);
}

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

// Ring auf dem Wasser, flach wie aus der Schräge gesehen, s = 0..1 sein Alter.
float ripple(vec2 p, float s, float aa) {
	float d = length(vec2(p.x, p.y * 2.6));
	float r = 0.06 + 0.34 * s;
	float w = 0.045 * (1.0 - s * 0.5);
	return (1.0 - smoothstep(w - aa, w + aa, abs(d - r))) * (1.0 - s) * (1.0 - s);
}

// Tropfen, die bei `p` hochspritzen und zurückfallen, s = 0..1 ihr Alter.
float droplets(vec2 p, float s, float seed, float aa) {
	float a = 0.0;
	for (int k = 0; k < 6; k++) {
		float fk = float(k);
		float side = (hash(seed + fk) - 0.5) * 0.5;
		float up = 0.35 + 0.35 * hash(seed + fk * 3.1);
		vec2 at = vec2(side * s, -(up * s - 0.55 * s * s));
		float size = 0.035 * (1.0 - s * 0.6);
		a += 1.0 - smoothstep(size - aa, size + aa, length(p - at));
	}
	return clamp(a, 0.0, 1.0) * (1.0 - smoothstep(0.6, 1.0, s));
}

// Der Fisch, Kopf nach +x, in seinem eigenen Rahmen f; gibt Farbe und Deckung.
vec4 fish(vec2 f, float aa) {
	float body = 1.0 - smoothstep(-aa, aa, length(vec2(f.x / 0.21, f.y / 0.08)) - 1.0);
	float back = -f.x - 0.16;
	float tail = step(0.0, back) * step(back, 0.12)
			* (1.0 - smoothstep(-aa, aa, abs(f.y) - (0.02 + back * 0.75)));
	float fin = (1.0 - smoothstep(-aa, aa, length(vec2((f.x + 0.02) / 0.07, (f.y + 0.075) / 0.035)) - 1.0));
	vec3 col = mix(back_color, belly_color, smoothstep(-0.03, 0.045, f.y));
	// Glanzstreifen und Auge.
	col += vec3(0.4) * (1.0 - smoothstep(0.0, 0.014, abs(f.y + 0.014))) * step(-0.12, f.x) * step(f.x, 0.12);
	float eye = 1.0 - smoothstep(0.016, 0.026, length(f - vec2(0.12, -0.018)));
	col = mix(col, vec3(0.05), eye * body);
	vec3 fins = mix(fin_color, back_color, 0.35);
	float a = max(body, max(tail, fin * (1.0 - body)));
	col = mix(fins, col, body);
	return vec4(col, a);
}

void fragment() {
	float life = COLOR.r;
	float caught = COLOR.g;
	float flip = step(0.5, COLOR.b);
	float caught_t = (COLOR.b - flip * 0.5) / CAUGHT_SCALE;
	vec2 uv = vec2(mix(UV.x, 1.0 - UV.x, flip), UV.y);
	vec2 q = vec2(uv.x * (1.0 + 2.0 * margin) - margin, uv.y * (rise + 2.0 * margin) - rise - margin);
	float aa = max(fwidth(q.x), 0.004);
	float t = life / jump_share;

	vec3 col = vec3(0.0);
	float a = 0.0;
	vec3 light = vec3(0.0);
	if (life < 1.0) {
		// Auftauchen.
		float s0 = clamp(t / 0.55, 0.0, 1.0);
		float splash = max(ripple(q, s0, aa), droplets(q, s0, 1.0, aa) * 0.9) * step(t, 0.55);
		// Landen (nur ungefangen).
		float s1 = clamp((life - jump_share) / (1.0 - jump_share), 0.0, 1.0);
		float land = (1.0 - step(0.001, caught)) * step(jump_share, life)
				* max(ripple(q - vec2(1.0, 0.0), s1, aa), droplets(q - vec2(1.0, 0.0), s1, 7.0, aa) * 0.9);
		float foam = max(splash, land);
		col = foam_color;
		a = foam;

		float ft = caught > 0.0 ? caught_t : t;
		if (ft < 1.0 && caught < 1.0) {
			vec2 at = path(ft);
			vec2 dir = normalize(vec2(1.0, -4.0 * rise * (1.0 - 2.0 * ft)));
			vec2 rel = q - at;
			float grow = 1.0 + caught * 0.6;
			vec2 f = vec2(dot(rel, dir), dot(rel, vec2(-dir.y, dir.x))) / grow;
			vec4 fsh = fish(f, aa / grow);
			// Dunkle Kontur: derselbe Fisch etwas größer darunter, damit er sich vom Wasser abhebt.
			float rim = fish(f / 1.18, aa / grow).a * (1.0 - fsh.a);
			fsh = vec4(mix(fsh.rgb, outline_color, rim), max(fsh.a, rim * 0.75));
			// Ein- und Austauchen: am Anfang und Ende des Bogens nur halb da.
			float show = smoothstep(0.0, 0.1, ft) * (1.0 - smoothstep(0.9, 1.0, ft) * (1.0 - step(0.001, caught)));
			float fa = fsh.a * show * (1.0 - caught * caught);
			col = mix(col, mix(fsh.rgb, gold_color, caught * 0.7), fa);
			a = fa + a * (1.0 - fa);
		}
		if (caught > 0.0) {
			// Goldenes Funkeln um den gefangenen Fisch: Schein und Funken nach außen.
			vec2 rel = q - path(caught_t);
			float d = length(rel);
			light += gold_color * exp(-d * d * 20.0) * (1.0 - caught) * 1.8;
			for (int k = 0; k < 8; k++) {
				float ang = 6.2832 * (float(k) + 0.3 * hash(float(k))) / 8.0;
				vec2 sp = vec2(cos(ang), sin(ang)) * (0.06 + 0.42 * sqrt(caught));
				float sd = length(rel - sp);
				light += gold_color * (1.0 - smoothstep(0.0, 0.05, sd)) * (1.0 - caught) * 1.5;
			}
		}
	}
	COLOR = vec4(col * a + light * (1.0 - a), a) * COLOR.a;
}
