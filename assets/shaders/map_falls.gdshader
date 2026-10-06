shader_type canvas_item;
// Ein Wasserfall auf der Gebietskarte (MapAmbience, kind "falls"): senkrechte Streifen
// eines Rauschens laufen nach unten und verschieben das gemalte Wasser mit, helle Fäden
// darin sind die Gischt. Zum Rand der Fläche läuft es aus.
render_mode blend_mix;

#include "res://assets/shaders/map_ambience.gdshaderinc"

uniform float speed = 1.0;
// Wie fein die Fäden quer und längs sind (Rauschzellen je Bildhöhe).
uniform vec2 scale = vec2(110.0, 9.0);
uniform float shift = 0.004;
uniform float foam : hint_range(0.0, 1.0) = 0.5;
uniform float intensity = 1.0;

void fragment() {
	float m = area_mask(UV);
	if (m <= 0.0) {
		discard;
	}
	vec2 p = UV * vec2(aspect, 1.0);
	float t = TIME * speed;
	float s = fbm(vec2(p.x * scale.x, p.y * scale.y - t * 6.0));
	vec4 col = texture(TEXTURE, UV + vec2(0.0, (s - 0.5) * shift * intensity * m));
	float streak = smoothstep(0.55, 0.85, s);
	col.rgb = mix(col.rgb, vec3(1.0), clamp(streak * foam * intensity, 0.0, 1.0) * m);
	COLOR = vec4(col.rgb, m * COLOR.a);
}
