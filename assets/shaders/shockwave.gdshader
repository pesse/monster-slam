shader_type spatial;
// Druckwelle des Explosionspfeils (Blast): ein heller Ring auf einem flachen Quad am
// Boden, der mit `progress` nach außen läuft, dünner wird und verblasst. Selbstleuchtend.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color : source_color = vec4(1.0, 0.75, 0.4, 1.0);
uniform float energy : hint_range(0.0, 8.0) = 2.5;

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	// Der Ring steht bei `radius` (Anteil des Quads) und hat die Breite `width`.
	float radius = mix(0.15, 0.95, 1.0 - pow(1.0 - progress, 3.0));
	float width = mix(0.18, 0.03, progress);
	float ring = 1.0 - smoothstep(0.0, width, abs(r - radius));
	// Innen ein schwacher Hauch Staub, der mitläuft.
	float inner = (1.0 - smoothstep(0.0, radius, r)) * 0.15;
	float fade = 1.0 - progress;
	ALBEDO = color.rgb;
	EMISSION = color.rgb * energy;
	ALPHA = clamp((ring + inner) * fade * color.a, 0.0, 1.0);
}
