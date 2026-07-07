shader_type spatial;
// Inverted-Hull-Outline: bläht das Mesh entlang seiner Normalen auf und rendert nur
// die Rückseiten (cull_front). Der aufgeblähte Rand bleibt rund um die Silhouette
// sichtbar, der Rest wird per Depth-Test vom Hauptmesh verdeckt. In Godot 4 sind
// VERTEX/NORMAL in vertex() bereits geskinnt -> die Hülle folgt der Animation.
//
// Die Kante SELBSTLEUCHTET (EMISSION mit glow_strength > 1): so ist die Farbe auch bei
// dunklen Wortart-Tönen kräftig sichtbar und blutet, wenn Glow im WorldEnvironment aktiv
// ist, in einen leuchtenden Halo. GL-Compatibility-tauglich (keine Forward+-only Modes).
render_mode cull_front, shadows_disabled, specular_disabled;

uniform vec4  outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// Breite in LOCAL space des Mesh. Die model_scale wird in monster.gd herausgerechnet,
// damit die Welt-Dicke über alle Modelle konsistent bleibt.
uniform float outline_width : hint_range(0.0, 0.5) = 0.02;
// 1.0 = echte Farbe ohne Kanal-Clipping (Outline == Legende). Der Bloom-Halo entsteht
// über die niedrige HDR-Schwelle im WorldEnvironment, nicht durch Übersteuern hier.
uniform float glow_strength : hint_range(0.0, 8.0) = 1.0;

void vertex() {
	VERTEX += normalize(NORMAL) * outline_width;
}

void fragment() {
	ALBEDO = vec3(0.0);
	EMISSION = outline_color.rgb * glow_strength;
}
