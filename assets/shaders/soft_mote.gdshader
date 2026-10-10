shader_type spatial;
// Ein Staubkorn im Lampenlicht (Turm des Schwätzers, RamblerStage): ein weicher, leuchtender
// Punkt auf einem Billboard-Quad, für CPUParticles3D. Kein Würfel, keine Kante — nur ein
// Schimmer, der langsam auf- und abblendet. Farbe und Deckkraft aus COLOR (color_ramp).
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add, fog_disabled;

uniform vec3 tint : source_color = vec3(1.0, 0.82, 0.5);
uniform float energy : hint_range(0.0, 8.0) = 1.2;

varying float v_seed;

void vertex() {
	mat4 world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]),
			normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * world * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	v_seed = fract(MODEL_MATRIX[3].x * 3.17 + MODEL_MATRIX[3].y * 1.93 + MODEL_MATRIX[3].z * 5.11);
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float glow = pow(max(1.0 - r, 0.0), 2.2);
	float twinkle = 0.65 + 0.35 * sin(TIME * (1.3 + v_seed * 1.7) + v_seed * 40.0);
	ALBEDO = tint * COLOR.rgb * energy;
	ALPHA = clamp(glow * twinkle * COLOR.a, 0.0, 1.0);
}
