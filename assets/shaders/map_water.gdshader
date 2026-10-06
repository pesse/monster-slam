shader_type canvas_item;
// Wasser auf der Gebietskarte (MapAmbience, kind "water"), in zwei Formen (`style`, wie
// MapLayout.STYLES): ein Wellenfeld aus fünf Zügen, durch Rauschen verbogen, damit es nicht
// nach Raster aussieht — oder Ringe, die sich von einzelnen Stellen ausbreiten und
// verebben, wie von Regentropfen oder springenden Fischen.
// Aus seiner Neigung folgt alles: das gemalte Wasser wird um sie verschoben gelesen
// (Brechung), Flanken zum Licht hin werden hell (Glanz auf den Kämmen), die abgewandten
// etwas dunkler. Senkrecht gestaucht, weil man schräg auf die Karte schaut. Wo die Maske
// schwächer wird, läuft alles aus, dort steht das Bild unverändert.
render_mode blend_mix;

#include "res://assets/shaders/map_ambience.gdshaderinc"

// Wellen je Bildhöhe (quer gemessen) und Stauchung in der Höhe.
uniform float scale = 150.0;
uniform float squash = 2.2;
uniform float speed = 1.0;
// Einstellbar je Karte (MapLayout.PARAMS): Wellenlänge als Faktor, Laufrichtung in Grad.
uniform float wave_size = 1.0;
uniform float direction = 0.0;
uniform float ring_size = 1.0;
// Verschiebung des Bildes durch die Neigung, in Bildhöhen.
uniform float ripple = 0.003;
// Licht von oben links, wie in den Bildern.
uniform vec2 light = vec2(-0.5, -0.85);
uniform vec3 glint_color : source_color = vec3(1.0, 0.97, 0.88);
uniform float glint : hint_range(0.0, 1.0) = 0.3;
uniform float shade : hint_range(0.0, 1.0) = 0.22;
uniform float intensity = 1.0;
// 0 Wellenfeld, 1 Ringe.
uniform int style = 0;
// Ringe: Zellen je Bildhöhe (je Zelle höchstens ein Ring zugleich), Ringe je Sekunde und Zelle.
uniform float ring_scale = 14.0;
uniform float ring_rate = 0.35;
uniform float ring_boost = 2.0;
// Wellenzahl der Ringe in Zellen: ein Ring hat etwa drei Kämme.
const float RING_K = 22.0;

// Die Wasserfläche, wie man sie von oben sähe: entstaucht und in die Laufrichtung gedreht.
vec2 plane(vec2 p, float cells) {
	float a = radians(direction);
	return mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * (p * vec2(1.0, squash) * cells);
}

float height(vec2 p, float t) {
	vec2 q = plane(p, scale / wave_size);
	// Verbiegen: die Züge laufen nicht gerade, sondern in Bögen, die langsam wandern.
	q += (vec2(fbm(q * 0.05 + vec2(t * 0.05, 0.0)), fbm(q * 0.05 + vec2(3.7, -t * 0.04))) - 0.5) * 12.0;
	// Fünf Züge, die Kämme meist quer zum Blick: so entstehen Linien statt eines Eierkartons.
	return sin(dot(q, vec2(0.25, 1.0)) - t * 1.3) * 0.36
			+ sin(dot(q, vec2(-0.4, 0.92)) - t * 1.0 + 1.7) * 0.26
			+ sin(dot(q, vec2(0.7, 0.75)) * 1.7 - t * 1.9 + 4.1) * 0.16
			+ sin(dot(q, vec2(-0.85, 0.5)) * 2.3 - t * 2.4 + 2.3) * 0.12
			+ sin(dot(q, vec2(0.1, 1.0)) * 3.1 - t * 2.9 + 0.6) * 0.1;
}

// Ein Ring je Zelle: er entsteht an einer zufälligen Stelle, läuft auseinander und verebbt;
// danach kommt der nächste an anderer Stelle. Die Höhe ist durch RING_K geteilt, damit die
// Neigung wie beim Wellenfeld um 1 liegt.
float rings(vec2 p, float t) {
	vec2 q = plane(p, ring_scale / ring_size);
	vec2 cell = floor(q);
	float h = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 c = cell + vec2(float(x), float(y));
			float clock = t * ring_rate + hash(c);
			float drop = floor(clock);
			float life = fract(clock);
			vec2 at = c + 0.2 + 0.6 * vec2(hash(c + drop * 1.31), hash(c + 17.0 + drop * 0.73));
			float front = (length(q - at) - life * 1.1) * RING_K;
			float wave = exp(-front * front * 0.025) * (1.0 - life);
			h += sin(front) * wave * smoothstep(0.0, 0.08, life) / RING_K;
		}
	}
	return h;
}

void fragment() {
	float m = area_mask(UV);
	if (m <= 0.0) {
		discard;
	}
	vec2 p = UV * vec2(aspect, 1.0);
	float t = TIME * speed;
	// Neigung in Wellen-Einheiten: um 1 auf der steilsten Flanke.
	vec2 slope;
	if (style == 1) {
		// Die Ringe sind feiner als die Züge: kleiner Schritt, sonst überspringt er einen Kamm.
		float e = 0.02 * ring_size / ring_scale;
		slope = vec2(rings(p + vec2(e, 0.0), t) - rings(p - vec2(e, 0.0), t),
				rings(p + vec2(0.0, e), t) - rings(p - vec2(0.0, e), t)) * 0.5 / (e * ring_scale / ring_size);
		// Ein Ring ist nur ein schmaler Streifen bewegtes Wasser — er darf steiler sein.
		slope *= ring_boost;
	} else {
		float e = 0.25 * wave_size / scale;
		slope = vec2(height(p + vec2(e, 0.0), t) - height(p - vec2(e, 0.0), t),
				height(p + vec2(0.0, e), t) - height(p - vec2(0.0, e), t)) * 0.5 / (e * scale / wave_size);
	}
	slope *= intensity;
	vec4 col = texture(TEXTURE, UV + slope * ripple * vec2(1.0 / aspect, 1.0) * m);
	// Wie sehr die Flanke zum Licht zeigt: -1 abgewandt, 1 zugewandt.
	float facing = clamp(dot(slope, -normalize(light)), -1.0, 1.0);
	col.rgb *= 1.0 - max(-facing, 0.0) * shade * m;
	col.rgb = mix(col.rgb, glint_color, smoothstep(0.4, 0.95, facing) * glint * m);
	COLOR = vec4(col.rgb, m * COLOR.a);
}
