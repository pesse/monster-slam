shader_type canvas_item;
// Radiale Vignette für die Tipp-Slow-Motion. `strength` kommt als Uniform und nicht
// über modulate, weil ein fragment(), das COLOR überschreibt, die Modulation verwirft.

uniform vec4  tint : source_color = vec4(0.04, 0.06, 0.14, 0.75);
uniform float strength : hint_range(0.0, 1.0) = 0.0;
// UV-Abstand von der Bildmitte; die Ecke liegt bei 0.707, bleibt hier also offen.
uniform float inner_radius : hint_range(0.0, 1.0) = 0.35;
uniform float outer_radius : hint_range(0.0, 1.5) = 0.85;

void fragment() {
	float falloff = smoothstep(inner_radius, outer_radius, distance(UV, vec2(0.5)));
	COLOR = vec4(tint.rgb, tint.a * falloff * strength);
}
