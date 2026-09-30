shader_type canvas_item;
// Goldenes Aufleuchten des Level-Badges beim Aufstieg (scenes/ui/hud.tscn, LevelFlare).
// Ein Multiplizieren mit Gold ließe das dunkle Badge dunkel; hier wird seine Helligkeit auf
// Gold gelegt und darüber aufgehellt. `glow` 0 = das Badge wie gemalt.

uniform float glow : hint_range(0.0, 1.0) = 0.0;
uniform vec3 gold : source_color = vec3(0.95, 0.68, 0.18);

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float l = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	vec3 golden = gold * (0.5 + l * 1.4) + vec3(0.12) * glow;
	COLOR = vec4(mix(c.rgb, golden, glow), c.a);
}
