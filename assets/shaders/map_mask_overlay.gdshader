shader_type canvas_item;
// Zeigt eine Maske der Gebietskarte (MapAmbience) als Tönung: die Farbe des Zeichnens,
// deckend, so weit die Maske weiß ist. Nur für die Werkbank (Umrisse, Vorschau). Was ohne
// Textur gezeichnet wird (Linien, Punkte), steht voll da.

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	COLOR = vec4(tint.rgb, tint.a * texture(TEXTURE, UV).r);
}
