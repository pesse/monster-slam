shader_type spatial;
// Ein Blitz des Donnerschlags (LightningBolt): ein Band aus Dreiecken entlang der Zickzack-
// Linie, das sich um seine eigene Richtung zur Kamera dreht. Der Knoten steht im Ursprung
// der Welt (top_level, Einheitsmatrix): VERTEX ist der Punkt auf der Mittellinie, NORMAL die
// Richtung der Linie dort, UV2.x die halbe Breite mit Vorzeichen (links/rechts).
// Quer zur Linie ein weißer Kern in einem weichen, blauen Hof; selbstleuchtend, damit der
// Glow des WorldEnvironment ihn aufnimmt.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add;

uniform vec3 tint : source_color = vec3(0.45, 0.62, 1.0);
uniform float energy : hint_range(0.0, 16.0) = 7.0;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	vec3 along = length(NORMAL) > 0.0001 ? normalize(NORMAL) : vec3(0.0, 1.0, 0.0);
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - VERTEX);
	vec3 side = cross(along, to_cam);
	side = length(side) > 0.0001 ? normalize(side) : INV_VIEW_MATRIX[0].xyz;
	VERTEX += side * UV2.x;
}

void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float core = pow(across, 5.0);
	float halo = pow(across, 1.4);
	// Oben (UV.y = 0) aus der Wolke heraus, nicht wie abgeschnitten.
	float top = smoothstep(0.0, 0.12, UV.y);
	vec3 col = mix(tint, vec3(1.0), core);
	ALBEDO = col;
	EMISSION = col * energy * (0.35 * halo + core);
	ALPHA = clamp((halo * 0.6 + core) * alpha * top, 0.0, 1.0);
}
