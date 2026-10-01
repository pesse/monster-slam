shader_type spatial;
// Die Festung, vom Krieg gezeichnet (BattleTheme.fortress_wear, FortressModel): dieselbe
// Atlas-Textur wie im Pack, aber ausgeblichen, mit Ruß, der vom Boden her hochzieht, mit
// Brandflecken und senkrechten Schmutzfahnen. Alles gerechnet, aus der Lage im Raum — die
// Teile des Packs haben keine eigene Textur dafür, und so passt es über jede Stufe.
//
// `wear` 0 zeigt die Festung wie im Pack, 1 ganz mitgenommen. Die Höhe zählt im Raum des
// Modells (VERTEX.y), damit der Ruß auf jedem Hügel unten am Bau sitzt.

uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform float wear : hint_range(0.0, 1.0) = 0.0;
uniform vec3 soot : source_color = vec3(0.07, 0.06, 0.06);
// Bis zu dieser Höhe (Modelleinheiten, ein Turm ist ~1.5) zieht der Ruß vom Boden hoch.
uniform float soot_height = 0.45;

varying vec3 world_pos;
varying float model_y;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	model_y = VERTEX.y;
}

void fragment() {
	vec3 col = texture(atlas, UV).rgb;
	float grey = dot(col, vec3(0.299, 0.587, 0.114));
	// Ausgeblichen: die Farben verlieren an Kraft, das Blau der Dächer zuerst.
	col = mix(col, vec3(grey) * vec3(1.0, 0.97, 0.94), wear * 0.6);
	col *= 1.0 - wear * 0.22;
	// Ruß vom Boden her, mit unruhigem Rand
	float edge = soot_height * (0.7 + 0.6 * noise(world_pos.xz * 1.3 + world_pos.y));
	float from_ground = 1.0 - smoothstep(0.0, edge, model_y);
	// Brandflecken: große, weiche Flecken über den ganzen Bau
	float patches = smoothstep(0.58, 0.78, noise(world_pos.xz * 0.45 + vec2(world_pos.y * 0.6, 3.1)));
	// Schmutzfahnen: senkrecht gestreckt, wie von Regen und Rauch
	float streaks = smoothstep(0.62, 0.9, noise(vec2((world_pos.x + world_pos.z) * 2.6, world_pos.y * 0.35)));
	float dirt = clamp(from_ground * 0.85 + patches * 0.65 + streaks * 0.4, 0.0, 0.9) * wear;
	ALBEDO = mix(col, soot, dirt);
	ROUGHNESS = 1.0;
}
