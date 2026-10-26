shader_type canvas_item;
// Noch nicht freigeschalteter Erfolg (scenes/ui/achievement_row.tscn): grau und abgedunkelt
// wie bei Steam, nur über die Helligkeit lesbar.

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float l = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	COLOR = vec4(vec3(l * 0.8), c.a);
}
