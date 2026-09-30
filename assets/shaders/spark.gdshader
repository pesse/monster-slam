shader_type spatial;
// Funken und Glut des Explosionspfeils (Blast): ein weicher, leuchtender Streifen auf einem
// Quad, der entlang der Flugrichtung gestreckt ist und sich um sie zur Kamera dreht
// (gestrecktes Billboard). Gedacht für CPUParticles3D mit particle_flag_align_y — dann
// zeigt die Y-Achse des Partikels in seine Flugrichtung. Breite und Länge kommen aus der
// Skalierung des Partikels, Farbe und Deckkraft aus COLOR (color_ramp).
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add;

uniform vec3 tint : source_color = vec3(1.0, 0.7, 0.3);
uniform float energy : hint_range(0.0, 8.0) = 3.0;
// So viel länger als breit.
uniform float stretch : hint_range(1.0, 20.0) = 6.0;

void vertex() {
	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 along = MODEL_MATRIX[1].xyz;
	float size = length(MODEL_MATRIX[0].xyz);
	vec3 dir = length(along) > 0.0001 ? normalize(along) : vec3(0.0, 1.0, 0.0);
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - center);
	vec3 side = cross(dir, to_cam);
	side = length(side) > 0.0001 ? normalize(side) : normalize(INV_VIEW_MATRIX[0].xyz);
	vec3 facing = cross(side, dir);
	mat4 world = mat4(vec4(side * size, 0.0), vec4(dir * size * stretch, 0.0),
			vec4(facing, 0.0), vec4(center, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * world;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	// Quer weich, längs zur Spitze (oben, UV.y = 0) hell, zum Schweif hin auslaufend.
	float across = 1.0 - smoothstep(0.0, 1.0, abs(uv.x));
	float head = smoothstep(1.0, 0.6, -uv.y) * smoothstep(1.0, -0.4, uv.y);
	float core = pow(across, 3.0) * head;
	vec3 col = mix(tint * COLOR.rgb, vec3(1.0, 0.95, 0.85), pow(across, 8.0) * 0.6);
	ALBEDO = col;
	EMISSION = col * energy;
	ALPHA = clamp(core * COLOR.a, 0.0, 1.0);
}
