shader_type canvas_item;
// Farbige Büste als Silber: „Wer spielt?" zeigt nur die gewählte Kachel in Farbe
// (scenes/ui/profile_card.tscn). Aufgehellt, damit Grau nicht nach „gesperrt" aussieht.

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float l = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	COLOR = vec4(vec3(min(l * 1.9 + 0.12, 1.0)), c.a);
}
