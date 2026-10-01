shader_type spatial;
// Eine Flamme (Fire): weiche Zunge auf einem Quad, das sich um die Hochachse zur Kamera
// dreht und so immer aufrecht steht. Ein gerechnetes Rauschen zieht nach oben durch sie
// hindurch und biegt sie hin und her; unten ist sie breit und gelb, oben schmal, rot und
// franst aus. Selbstleuchtend: der Glow des WorldEnvironments macht daraus den Schein.
// Jede Flamme flackert anders — der Versatz kommt aus ihrer Lage im Raum, so teilen sich
// alle ein Material. GL-Compatibility-tauglich.
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, blend_mix, fog_disabled;

uniform vec3 core_color : source_color = vec3(1.0, 0.86, 0.45);
uniform vec3 mid_color : source_color = vec3(1.0, 0.5, 0.12);
uniform vec3 tip_color : source_color = vec3(0.75, 0.16, 0.04);
uniform float energy : hint_range(0.0, 8.0) = 1.6;
// Wie schnell das Rauschen nach oben zieht.
uniform float speed = 1.6;

varying float v_seed;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	return noise(p) * 0.6 + noise(p * 2.1 + 7.3) * 0.3 + noise(p * 4.3 + 1.7) * 0.1;
}

void vertex() {
	// Billboard um die Hochachse, mit der Größe des Knotens.
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz));
	vec3 depth = normalize(cross(right, vec3(0.0, 1.0, 0.0)));
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right * sx, 0.0), vec4(0.0, sy, 0.0, 0.0),
			vec4(depth * sx, 0.0), MODEL_MATRIX[3]);
	v_seed = hash(MODEL_MATRIX[3].xz) * 50.0;
}

void fragment() {
	float t = TIME * speed + v_seed;
	// p.x quer (-0.5..0.5), p.y von unten (0) nach oben (1)
	vec2 p = vec2(UV.x - 0.5, 1.0 - UV.y);
	float bend = (fbm(vec2(p.y * 2.0 - t * 0.7, v_seed)) - 0.5) * 0.35 * p.y;
	float x = p.x + bend;
	float lick = fbm(vec2(x * 5.0, p.y * 3.2 - t * 1.6));
	// Umriss: Tropfen, unten rund, oben spitz; das Rauschen frisst den oberen Rand an.
	float width = 0.36 * sqrt(max(1.0 - p.y, 0.0)) * smoothstep(0.0, 0.18, p.y + 0.06);
	float body = 1.0 - smoothstep(width * 0.55, width, abs(x));
	float top = 1.0 - smoothstep(0.35, 1.0, p.y + (lick - 0.5) * 0.55);
	float flame = clamp(body * top * 1.6, 0.0, 1.0);
	// Hitze: innen unten am größten
	float heat = flame * (1.0 - smoothstep(0.0, 0.9, p.y)) * (1.0 - abs(x) / max(width, 0.001) * 0.6);
	vec3 col = mix(tip_color, mid_color, smoothstep(0.1, 0.45, heat));
	col = mix(col, core_color, smoothstep(0.45, 0.8, heat));
	ALBEDO = col * energy;
	ALPHA = flame * smoothstep(0.0, 0.25, flame + heat);
}
