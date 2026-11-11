shader_type canvas_item;
// Wolkenschatten über der Gebietskarte (MapAmbience, kind "clouds"): weiche dunkle Flecken aus
// verzerrtem Rauschen, die mit dem Wind übers Land ziehen und sich dabei langsam verformen.
// Ohne Maske: frei bleibt, was die Farbe des Hintergrunds hat, gelesen in der Ecke des Bildes.
render_mode blend_mix;

#include "res://assets/shaders/map_ambience.gdshaderinc"

uniform vec3 shade : source_color = vec3(0.1, 0.08, 0.18);
uniform float intensity = 1.0;
// Wolken je Bildhöhe und ihr Zug (Bildhöhen je Sekunde).
uniform float scale = 3.0;
uniform float drift = 0.012;
// Einstellbar je Karte (MapLayout.PARAMS): Anteil im Schatten, wie dunkel er ist, Größe und
// Zug als Faktor, Richtung in Grad (0 nach rechts, im Uhrzeigersinn).
uniform float cover : hint_range(0.0, 1.0) = 0.5;
uniform float darkness : hint_range(0.0, 1.0) = 0.45;
uniform float cloud_size = 1.0;
uniform float speed = 1.0;
uniform float direction = 20.0;
// Wo der Hintergrund gelesen wird (Anteil des Bildes) und über welchen Farbabstand (RGB)
// das Land beginnt.
uniform vec2 sea_probe = vec2(0.004, 0.006);
uniform vec2 land_edge = vec2(0.06, 0.16);

void fragment() {
	vec3 sea = texture(TEXTURE, sea_probe).rgb;
	float land = smoothstep(land_edge.x, land_edge.y, distance(texture(TEXTURE, UV).rgb, sea));
	if (land <= 0.0) {
		discard;
	}
	float cells = scale / cloud_size;
	vec2 wind = vec2(cos(radians(direction)), sin(radians(direction)));
	vec2 p = UV * vec2(aspect, 1.0) * cells - wind * TIME * speed * drift * cells;
	float n = fbm(p + vec2(fbm(p * 0.5 + TIME * 0.01), fbm(p * 0.5 - TIME * 0.008 + 4.2)) * 0.9);
	float edge = 1.0 - cover;
	float c = smoothstep(edge - 0.1, edge + 0.1, n);
	COLOR = vec4(shade, clamp(c * darkness * intensity, 0.0, 1.0) * land * COLOR.a);
}
