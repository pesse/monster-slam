shader_type canvas_item;
// Ein Vogel im Flug über der Gebietskarte (MapBirds): dunkle Silhouette mit schlagenden
// Flügeln, Kopf in Flugrichtung.
//
// Je Vogel ein Quadrat: COLOR.r Phase des Flügelschlags (0..1), COLOR.g Deckung, COLOR.b 0.5
// wenn er nach links fliegt, COLOR.a das Ausblenden der Karte.
render_mode blend_premul_alpha;

uniform vec3 back_color : source_color = vec3(0.1, 0.1, 0.13);
uniform vec3 light_color : source_color = vec3(0.85, 0.85, 0.82);

void fragment() {
	float flap = COLOR.r;
	float cover = COLOR.g;
	// q: -1.25..1.25 über das Quadrat, x in Flugrichtung, y nach unten; Flügelspitzen bei ±1.
	vec2 q = (UV - 0.5) * 2.5;
	q.x *= COLOR.b > 0.25 ? -1.0 : 1.0;
	float aa = max(fwidth(q.x), 0.02);
	// Flügel wie ein flaches M: die Schulter hebt und senkt sich mit dem Schlag, die Spitze
	// hängt etwas nach. Mehr Auf- als Abschlag, damit er nach oben strebt.
	float lift = 0.25 + 0.6 * sin(flap * 6.2832);
	float x = abs(q.x);
	float span = clamp(x, 0.0, 1.0);
	float wing_y = -lift * span + 0.45 * span * span;
	float thick = 0.15 * (1.0 - 0.75 * span) * step(x, 1.0);
	float wing = 1.0 - smoothstep(thick - aa, thick + aa, abs(q.y - wing_y));
	wing *= 1.0 - smoothstep(0.9, 1.0, x);
	// Leib und Kopf.
	float body = 1.0 - smoothstep(-aa, aa, length(vec2(q.x / 0.26, q.y / 0.11)) - 1.0);
	float head = 1.0 - smoothstep(-aa, aa, length(q - vec2(0.24, -0.05)) - 0.09);
	float a = max(wing, max(body, head)) * cover;
	// Die Oberseite der Flügel fängt etwas Licht.
	vec3 col = mix(back_color, light_color, wing * (1.0 - body) * smoothstep(0.0, -0.1, q.y - wing_y) * 0.25);
	COLOR = vec4(col * a, a) * COLOR.a;
}
