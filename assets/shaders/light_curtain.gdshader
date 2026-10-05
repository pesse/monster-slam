shader_type spatial;
// Ein Vorhang aus Licht: der Lichtstreifen von „Drittes Auge" und „Orakelblick", der über
// das Feld fährt, und die Lichtsäule von „Lebensquell" und „Eisenhaut" an der Festung
// (SpellFx). Unten hell, nach oben auslaufend, mit Streifen, die nach oben ziehen. Auf einem
// Quad oder einem offenen Zylinder; UV.y = 0 ist oben.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add;

uniform vec3 tint : source_color = vec3(0.75, 0.5, 1.0);
uniform float energy : hint_range(0.0, 8.0) = 2.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
// Wie oft die Streifen um einen Zylinder oder über ein Quad laufen.
uniform float streaks = 24.0;
// Quad: zu den Seiten auslaufen (1); Zylinder: rundum gleich (0).
uniform float side_fade : hint_range(0.0, 1.0) = 1.0;

float hash(float x) {
	return fract(sin(x * 91.3458) * 47453.5453);
}

void fragment() {
	float up = 1.0 - UV.y;
	float base = pow(1.0 - up, 2.2);
	float column = floor(UV.x * streaks);
	float speed = mix(0.6, 1.6, hash(column));
	float stripe = pow(fract(up * 1.5 - TIME * speed + hash(column + 7.0)), 6.0)
			* smoothstep(0.0, 0.5, sin(fract(UV.x * streaks) * 3.14159));
	float sides = mix(1.0, smoothstep(0.0, 0.18, UV.x) * smoothstep(1.0, 0.82, UV.x), side_fade);
	float shape = (base * 0.75 + stripe * (1.0 - up) * 0.9) * sides;
	vec3 col = mix(tint, vec3(1.0), base * 0.35);
	ALBEDO = col;
	EMISSION = col * energy;
	ALPHA = clamp(shape * fade, 0.0, 1.0);
}
