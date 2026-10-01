// Wind in Bäumen und Gras (Wind.sway). Ersetzt das StandardMaterial3D eines Modells und
// zeichnet es genauso — Farbe, Textur, Vertexfarbe, Rauheit wie dort —, verbiegt aber die
// Ecken mit der Höhe: der Fuß steht, die Spitze schwankt. Die Wellen laufen über das Feld
// (Phase aus der Lage des Modells), so dass nicht alle Bäume im Gleichtakt nicken.
//
// Die Zeit ist `wind_time` (Wind._process) und nicht TIME: sie läuft mit Engine.time_scale,
// in der Zeitlupe also langsamer wie alles andere.

global uniform float wind_time;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_texture = false;
uniform bool use_vertex_color = false;
uniform vec3 uv1_scale = vec3(1.0);
uniform vec3 uv1_offset = vec3(0.0);
uniform float roughness = 1.0;
uniform float metallic = 0.0;
uniform float specular = 0.5;
// Höhe des Modells im Mesh-Raum: darüber gerechnet wird der Anteil, der sich biegt.
uniform float sway_height = 1.0;
// Ausschlag an der Spitze, als Anteil der Höhe (0 = steht still).
uniform float sway = 0.03;

const vec2 WIND_DIR = vec2(0.8, 0.6);

void vertex() {
	UV = UV * uv1_scale.xy + uv1_offset.xy;
	float h = clamp(VERTEX.y / sway_height, 0.0, 1.0);
	float bend = h * h;
	// Lage aus MODEL_MATRIX, nicht NODE_POSITION_WORLD: in einem MultiMesh (GroundCover)
	// trägt sie die des einzelnen Büschels, der Knoten nur die aller.
	float phase = dot(MODEL_MATRIX[3].xz, WIND_DIR) * 0.15;
	// Ein Grundzug in Windrichtung, darauf Böen; nie ganz zurück in die Ruhelage.
	float gust = 0.35 + 0.6 * sin(wind_time * 1.1 - phase) + 0.25 * sin(wind_time * 2.3 - phase * 1.7);
	// Blätter zittern je Ecke ein wenig gegeneinander.
	float flutter = 0.15 * h * sin(wind_time * 5.0 + dot(VERTEX, vec3(3.1, 2.3, 2.7)));
	// Windrichtung in den Raum des Meshs: MODEL_MATRIX ist Drehung mal Skalierung, die
	// Transponierte dreht also zurück; normalize nimmt die Skalierung heraus.
	vec3 dir = normalize(transpose(mat3(MODEL_MATRIX)) * vec3(WIND_DIR.x, 0.0, WIND_DIR.y));
	VERTEX += dir * (sway * sway_height * (bend * gust + flutter));
}

void fragment() {
	vec4 col = albedo;
	if (use_texture) {
		col *= texture(albedo_texture, UV);
	}
	if (use_vertex_color) {
		col.rgb *= COLOR.rgb;
	}
	ALBEDO = col.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = specular;
#ifdef WIND_ALPHA
	ALPHA = col.a;
#endif
}
