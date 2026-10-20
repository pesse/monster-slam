shader_type canvas_item;
// Metallischer Verlauf für Fenstertitel (WindowTitle, Entwurf in
// assets/ui/windows/folder_tabs/sources/concept-v1.png). Ein Label zeichnet Kontur und Füllung
// als getrennte Glyphen; nur die helle Füllung bekommt den Verlauf, die dunkle Kontur bleibt.
// `top`/`bottom`: Oberkante und Grundlinie der Großbuchstaben in Label-Pixeln (WindowTitle, 28 px).

uniform float top = 7.0;
uniform float bottom = 28.0;
uniform vec3 light : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 mid : source_color = vec3(0.84, 0.88, 0.96);
uniform vec3 deep : source_color = vec3(0.56, 0.64, 0.82);

varying float local_y;
varying float fill;

void vertex() {
	local_y = VERTEX.y;
	// Kontur ist dunkel, Füllung hell: an der Vertexfarbe unterscheiden.
	fill = step(0.5, dot(COLOR.rgb, vec3(0.3, 0.59, 0.11)));
}

void fragment() {
	vec4 c = COLOR;
	float t = clamp((local_y - top) / (bottom - top), 0.0, 1.0);
	// Lichtkante im oberen Drittel, darunter in den Schatten.
	vec3 metal = t < 0.35 ? mix(light, mid, t / 0.35) : mix(mid, deep, (t - 0.35) / 0.65);
	COLOR = vec4(mix(c.rgb, metal, fill), c.a);
}
