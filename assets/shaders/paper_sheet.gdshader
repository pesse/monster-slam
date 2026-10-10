shader_type spatial;
// Ein loses Blatt Papier, das durch die Luft segelt (Turm des Schwätzers, RamblerStage):
// gedacht für CPUParticles3D mit einem QuadMesh. Das Partikel dreht das Blatt; der Shader
// wölbt es und lässt die Wölbung wandern, so flattert es, statt als steifes Plättchen zu
// kippen. Ecken weich gerundet, auf der Vorderseite ein paar Zeilen Schrift, die zum Rand hin
// verblassen. Beleuchtet (das Kerzenlicht soll es färben), aber mit weichem Umgriff, damit die
// Rückseite nicht schwarz wird. Farbe und Deckkraft kommen aus der color_ramp (COLOR).
// GL-Compatibility-tauglich.
render_mode cull_disabled, depth_draw_never, shadows_disabled, specular_disabled,
		diffuse_lambert_wrap, blend_mix;

uniform vec3 paper : source_color = vec3(0.95, 0.9, 0.78);
uniform vec3 ink : source_color = vec3(0.25, 0.2, 0.22);
// Wie stark sich das Blatt wölbt (Meter bei Blattgröße 1).
uniform float curl : hint_range(0.0, 0.5) = 0.14;
uniform float flutter_speed = 5.0;

varying float v_seed;

void vertex() {
	v_seed = fract(MODEL_MATRIX[3].x * 1.37 + MODEL_MATRIX[3].z * 2.71 + float(INSTANCE_ID) * 0.618);
	float t = TIME * flutter_speed + v_seed * 31.0;
	// Wölbung quer, Welle längs: ein Blatt, das in der Luft hängt und sich biegt.
	VERTEX.z += curl * (VERTEX.x * VERTEX.x * 3.0 - 0.25) * sin(t);
	VERTEX.z += curl * 0.6 * sin(VERTEX.y * 5.0 + t * 1.3) * (VERTEX.y + 0.5);
}

void fragment() {
	vec2 p = abs(UV - 0.5) * 2.0;
	// Abgerundetes Rechteck mit weichem Rand.
	vec2 q = max(p - vec2(0.82), 0.0);
	float edge = length(q) / 0.18 + max(max(p.x, p.y) - 1.0, 0.0);
	float alpha = 1.0 - smoothstep(0.7, 1.0, max(edge, max(p.x, p.y) - 0.02));
	// Zeilen: nur auf der Vorderseite, innerhalb eines Rands, unregelmäßig lang.
	float row = fract(UV.y * 9.0);
	float line_no = floor(UV.y * 9.0);
	float len = 0.55 + 0.35 * fract(sin(line_no * 12.9 + v_seed * 78.2) * 437.5);
	float in_text = step(0.15, UV.x) * step(UV.x, 0.15 + len * 0.7) * step(0.12, UV.y) * step(UV.y, 0.88);
	float stroke = smoothstep(0.35, 0.45, row) * (1.0 - smoothstep(0.55, 0.65, row));
	float writing = in_text * stroke * (FRONT_FACING ? 0.55 : 0.12);
	ALBEDO = mix(paper * COLOR.rgb, ink, writing);
	ALPHA = alpha * COLOR.a;
}
