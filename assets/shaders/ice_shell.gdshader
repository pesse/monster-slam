shader_type spatial;
// Die Eishülle eines eingefrorenen Monsters (FrostShell) und ihre Kristalle: durchscheinend
// blau, am Rand hell (Fresnel), mit feinen Facettenlinien aus einem Voronoi-Muster. Kurz vor
// dem Auftauen ziehen Risse auf (`cracks`), dann zerspringt sie. Beleuchtet, damit die Sonne
// des Themas darauf glänzt.
render_mode blend_mix, depth_draw_never, cull_back, shadows_disabled, specular_schlick_ggx;

uniform vec3 tint : source_color = vec3(0.5, 0.8, 1.0);
uniform float cracks : hint_range(0.0, 1.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
// Kurzes Aufleuchten beim Gefrieren.
uniform float flash : hint_range(0.0, 4.0) = 0.0;

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// Abstand zur nächsten Zellgrenze: 0 auf der Linie.
float cell_edge(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float first = 8.0;
	float second = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			float d = length(g + hash2(i + g) - f);
			if (d < first) {
				second = first;
				first = d;
			} else if (d < second) {
				second = d;
			}
		}
	}
	return second - first;
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 2.2);
	float facet = 1.0 - smoothstep(0.0, 0.06, cell_edge(UV * vec2(7.0, 4.0)));
	float crack = cracks * (1.0 - smoothstep(0.0, 0.05, cell_edge(UV * vec2(15.0, 9.0) + 3.7)));
	// Unten bereift (UV.y wächst nach unten), oben klar.
	float rime = smoothstep(0.45, 1.0, UV.y);
	ALBEDO = mix(tint, vec3(0.95, 0.98, 1.0), rime * 0.7);
	ROUGHNESS = 0.08;
	SPECULAR = 0.9;
	EMISSION = tint * (fresnel * 1.1 + facet * 0.6 + flash) + vec3(1.0) * crack * 2.5;
	ALPHA = clamp(0.38 + fresnel * 0.55 + facet * 0.3 + rime * 0.3 + crack * 0.6 + flash * 0.2,
			0.0, 1.0) * fade;
}
