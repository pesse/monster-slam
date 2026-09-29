shader_type spatial;
// Der goldene Schein hinter einem ausgewählten Buch (Book3D, `%Glow`): ein Quad hinter dem
// Buchkörper, dessen Helligkeit mit dem Abstand zum Umriss des Buchs abfällt — ein
// abgerundetes Rechteck, eng am Buch und nicht rund. Das Buch selbst verdeckt die Mitte.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.72, 0.28);
// 0 = aus, 1 = voll (Book3D blendet über das Herausnehmen).
uniform float strength = 0.0;
// Größe des Quads und des Buchs in Metern; der Schein füllt den Rand dazwischen.
uniform vec2 quad_size = vec2(1.6, 2.0);
uniform vec2 book_size = vec2(1.0, 1.4);
// Wie schnell der Schein nach außen abfällt (m) und wie stark er atmet.
uniform float falloff = 0.05;
uniform float pulse = 0.18;

float rounded_box(vec2 p, vec2 half_size, float radius) {
	vec2 q = abs(p) - half_size + vec2(radius);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * quad_size;
	float d = max(rounded_box(p, book_size * 0.5, 0.04), 0.0);
	float glow = exp(-(d * d) / (falloff * falloff));
	// Zum Rand des Quads hin ganz aus, damit keine Kante sichtbar wird.
	vec2 edge = (quad_size * 0.5 - abs(p)) / (quad_size * 0.5 - book_size * 0.5);
	glow *= smoothstep(0.0, 1.0, min(edge.x, edge.y));
	float breath = 1.0 - pulse + pulse * sin(TIME * 3.0);
	ALBEDO = color * glow * strength * breath * 1.6;
}
