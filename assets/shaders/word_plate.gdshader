shader_type canvas_item;
// Wortschild in zwei Ebenen (assets/ui/gameplay/README.md): TEXTURE ist der graue Rand, der
// die Farbe der Wortart voll annimmt, `base` die dunkle Fläche mit den Rauten, nur leicht
// getönt. Die Farbe kommt über self_modulate — so teilen sich alle Schilder ein Material.
//
// Beide Ebenen werden an derselben Stelle gelesen und vormultipliziert addiert (ihre
// Masken sind disjunkt). Zwei übereinander gezeichnete Sprites hätten beim Verkleinern an
// der Trennlinie eine durchscheinende Naht.

uniform sampler2D base : source_color, filter_linear_mipmap;
uniform float base_tint : hint_range(0.0, 1.0) = 0.12;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 rim = texture(TEXTURE, UV);
	vec4 ground = texture(base, UV);
	vec3 rgb = rim.rgb * tint.rgb * rim.a + ground.rgb * mix(vec3(1.0), tint.rgb, base_tint) * ground.a;
	float a = min(1.0, rim.a + ground.a);
	COLOR = vec4(a > 0.0 ? rgb / a : vec3(0.0), a * tint.a);
}
