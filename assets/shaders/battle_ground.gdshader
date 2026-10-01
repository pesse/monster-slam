shader_type spatial;
render_mode cull_disabled;
// Boden des Schlachtfelds (BattleTheme.ground_material). Die Farbe kommt aus den
// Vertexfarben des Themas; die Detailtextur (BattleTheme.ground_texture) ist grau und
// moduliert nur die Helligkeit: 50 % Grau lässt die Farbe stehen, heller hebt, dunkler
// senkt. Deshalb OHNE source_color — der Wert 128 muss als 0.5 ankommen, nicht linearisiert
// als 0.22.
//
// Beleuchtet wird in light() selbst: Die Farben der Themen sind auf Boden abgestimmt, der
// nur Umgebungslicht bekommt. Die Albedo ist deshalb um shadow_depth gesenkt, und die Sonne
// legt genau diesen Anteil des Umgebungslichts wieder dazu — nicht ihre eigene Helligkeit.
// So steht flacher Boden in der Sonne in der Farbe des Themas, egal wie hell dessen Sonne
// ist; im Schatten fehlt der Anteil, ein abgewandter Hang wird dunkler, einer zur Sonne
// etwas heller. Den Schatten selbst multipliziert gl_compatibility NACH light() auf das
// Ergebnis (ATTENUATION enthält ihn nicht) — deshalb muss die Sonne hier etwas addieren.
//
// Wolkenschatten ziehen in Windrichtung über den Boden (wie Wind.sway, dieselbe `wind_time`):
// ein Rauschen, das der Sonne ihren Anteil nimmt wie ein Schatten, nur weich und schwächer.
// Gerechnet, nicht als Textur — dann gibt es keine Naht und nichts zu laden.
//
// Ebenso gerechnet: Flecken in einem dritten Ton (patch_color, trockenes Gras, Erde) und der
// Weg (BattlePath) zum Tor — Trampelpfad, Weg, Bohlenweg oder Pflaster. Seine Mittellinie
// ist path_centre, dieselbe Formel wie BattlePath.centre_x; die Zahlen kommen von dort.
// Farben wie die Vertexfarben ohne source_color: sie werden genauso gelesen wie ground_low.

uniform sampler2D detail : filter_linear_mipmap_anisotropic, repeat_enable;
// Detailtextur des Wegs (BattleTheme.path_texture) und wie stark sie wirkt; 0 = keine.
uniform sampler2D path_detail : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float path_strength : hint_range(0.0, 1.0) = 0.0;
// Wie stark die Textur wirkt: 0 = gar nicht, 1 = voller Kontrast der Datei.
uniform float strength : hint_range(0.0, 1.0) = 0.6;
// Weltmeter je Kachel — so groß ist eine Textur auf dem Boden (siehe assets/textures/ground/BRIEF.md).
uniform float tile_size = 8.0;
// Umgebungslicht des Themas, linear und mal Energie (ambient * ambient_energy).
uniform vec3 ambient_light = vec3(0.21, 0.23, 0.34);
// sin(Sonnenhöhe): so hell trifft die Sonne flachen Boden — das ist „keine Änderung".
// Global, weil die Sonne wandert (SunCycle stellt ihn jedes Bild).
global uniform float sun_sin;
// Ton der Sonne nach Tageszeit (SunCycle.tint_at): golden, wenn sie tief steht.
global uniform vec4 sun_tint;
// Wie viel vom Umgebungslicht der Schatten wegnimmt (unter 1).
uniform float shadow_depth : hint_range(0.0, 0.9) = 0.45;
// Wie viel vom Sonnenanteil eine Wolke nimmt (BattleTheme.clouds): 0 = keine Wolken.
uniform float clouds : hint_range(0.0, 1.0) = 0.0;
// Weltmeter je Wolke und ihr Tempo in m/s.
uniform float cloud_size = 22.0;
uniform float cloud_speed = 1.6;

// Dritter Bodenton und wie viel Fläche er ungefähr deckt (0 = keine Flecken).
uniform vec3 patch_color = vec3(0.5, 0.46, 0.27);
uniform float patch_amount : hint_range(0.0, 1.0) = 0.0;
uniform float patch_size = 7.0;

// Der Weg: Art (Reihenfolge wie BattlePath.KINDS, -1 = keiner), Farbe und Form.
uniform int path_kind = -1;
uniform vec3 path_color = vec3(0.36, 0.27, 0.17);
uniform float path_half_width = 1.2;
// Je Bogen Ausschlag, Länge, Phase; dazu die Schräge (BattlePath).
uniform vec3 path_big = vec3(0.0, 44.0, 0.0);
uniform vec3 path_small = vec3(0.0, 15.0, 0.0);
uniform float path_drift = 0.0;
uniform float path_gate_z = 16.5;
// Von x nach y geht der Weg aus dem Bogen in die Gerade auf das Tor.
uniform vec2 path_straight = vec2(2.5, 12.5);

global uniform float wind_time;
const vec2 WIND_DIR = vec2(0.8, 0.6);

varying vec2 world_xz;
// 1 = volle Sonne, darunter liegt eine Wolke (fragment() rechnet, light() nutzt).
varying float sun_left;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// 0 = offen, 1 = unter einer Wolke. Zwei Lagen, damit die Ränder nicht nach Raster aussehen.
float cloud_cover(vec2 xz) {
	vec2 p = (xz - WIND_DIR * wind_time * cloud_speed) / cloud_size;
	float n = 0.65 * value_noise(p) + 0.35 * value_noise(p * 2.3 + vec2(3.7, 1.3));
	return smoothstep(0.42, 0.62, n);
}

// Abstand zum nächsten Zellkern und zur nächsten Zellgrenze, dazu ein Wert je Zelle (Pflaster).
vec3 cells(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash(i + g), hash(i + g + vec2(17.0, 31.0))) * 0.8 + 0.1;
			float d = length(g + o - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = hash(i + g + vec2(5.0, 9.0));
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec3(d1, d2 - d1, id);
}

float path_centre(float z) {
	float straight = 1.0 - smoothstep(path_straight.x, path_straight.y, z);
	float x = path_big.x * sin(6.2831853 * z / path_big.y + path_big.z)
			+ path_small.x * sin(6.2831853 * z / path_small.y + path_small.z)
			+ path_drift * (path_straight.y - z);
	return x * straight;
}

// Wie stark (0..1) der Weg den Boden bei world_xz deckt, und seine Farbe dort. `fringe`
// ist der abgetretene Saum daneben, `shade` dunkelt den Boden (Schatten des Bohlenwegs).
void path_at(vec2 xz, out float cover, out vec3 col, out float fringe, out float shade) {
	cover = 0.0;
	col = path_color;
	fringe = 0.0;
	shade = 1.0;
	if (path_kind < 0) {
		return;
	}
	float c = path_centre(xz.y);
	// Weitab vom Weg nichts rechnen. Quer gemessen ist der Abstand höchstens so viel kleiner,
	// wie der Weg schräg läuft — bei den Grenzen von BattlePath nie unter 0.65 von |x - c|.
	if (abs(xz.x - c) * 0.65 > path_half_width + 2.0) {
		return;
	}
	float slope = path_centre(xz.y + 0.5) - path_centre(xz.y - 0.5);
	float nrm = inversesqrt(1.0 + slope * slope);
	float across = (xz.x - c) * nrm;
	float along = xz.y + (xz.x - c) * slope * nrm;
	float d = abs(across);
	float hw = path_half_width;
	// Hinter dem Tor liegt kein Weg mehr.
	float end = 1.0 - smoothstep(path_gate_z + 0.5, path_gate_z + 2.0, xz.y);
	float speck = hash(floor(xz * 9.0));
	if (path_kind == 0) {
		// Trampelpfad: schwingender Rand, an dem das Gras fein ausfranst, fleckige Erde und
		// ein schmaler abgetretener Saum. Der Rand ist scharf — weich wirkte er verwaschen.
		float ragged = (value_noise(xz * 0.8) - 0.5) * 0.9 + (value_noise(xz * 3.1) - 0.5) * 0.3
				+ (value_noise(xz * 11.0) - 0.5) * 0.22;
		cover = 1.0 - smoothstep(hw - 0.1, hw + 0.04, d + ragged);
		col *= 0.9 + 0.18 * value_noise(xz * 2.2) + 0.08 * (speck - 0.5);
		fringe = (1.0 - smoothstep(hw, hw + 0.7, d + ragged)) * 0.25;
	} else if (path_kind == 1) {
		// Weg: Kies mit klarer Kante und zwei Fahrspuren.
		float ragged = (value_noise(xz * 1.3) - 0.5) * 0.3 + (value_noise(xz * 10.0) - 0.5) * 0.12;
		cover = 1.0 - smoothstep(hw - 0.06, hw + 0.02, d + ragged);
		float rut = exp(-pow((d - hw * 0.5) / 0.22, 2.0));
		col *= (0.86 + 0.28 * speck) * (1.0 - 0.16 * rut);
		fringe = (1.0 - smoothstep(hw, hw + 0.8, d + ragged)) * 0.3;
	} else if (path_kind == 2) {
		// Bohlenweg: Bretter quer, jede mit eigenem Ton und eigener Länge, dunkle Fugen; er
		// liegt erhöht und wirft einen schmalen Schatten neben sich.
		float board = along / 0.34;
		float id = hash(vec2(floor(board), 3.0));
		float reach = hw - id * 0.14;
		cover = 1.0 - smoothstep(reach - 0.03, reach, d);
		float f = fract(board);
		float gap = smoothstep(0.0, 0.07, f) * (1.0 - smoothstep(0.93, 1.0, f));
		float grain = value_noise(vec2(across * 1.4, board * 6.0 + id * 40.0));
		col *= (0.78 + 0.34 * id) * (0.9 + 0.2 * grain) * mix(0.35, 1.0, gap);
		shade = mix(0.6, 1.0, smoothstep(hw, hw + 0.45, d));
	} else {
		// Pflaster: unregelmäßige Steine mit Fugen, jeder etwas anders getönt.
		vec3 cell = cells(vec2(across, along) / 0.7);
		float joint = smoothstep(0.02, 0.09, cell.y);
		cover = 1.0 - smoothstep(hw - 0.04, hw, d);
		col *= (0.86 + 0.26 * cell.z) * (1.06 - 0.12 * cell.x) * mix(0.62, 1.0, joint);
		fringe = (1.0 - smoothstep(hw, hw + 0.5, d)) * 0.25;
	}
	cover *= end;
	fringe *= end;
	shade = mix(1.0, shade, end);
}

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float d = texture(detail, world_xz / tile_size).r;
	vec3 ground = COLOR.rgb;
	if (patch_amount > 0.0) {
		vec2 p = world_xz / patch_size;
		float n = 0.6 * value_noise(p) + 0.3 * value_noise(p * 2.1 + vec2(4.1, 7.3))
				+ 0.1 * value_noise(p * 5.3 + vec2(1.7, 2.9));
		float th = 0.72 - 0.4 * patch_amount;
		ground = mix(ground, patch_color, smoothstep(th - 0.05, th + 0.05, n) * 0.85);
	}
	float cover;
	vec3 path_col;
	float fringe;
	float shade;
	path_at(world_xz, cover, path_col, fringe, shade);
	ground = mix(ground, path_color, fringe * value_noise(world_xz * 1.7)) * shade;
	// Auf dem Weg seine eigene Textur statt der des Bodens; ohne eine bleibt nur sein
	// gerechnetes Muster und ein Rest der Bodentextur.
	float ground_mod = mix(1.0, d * 2.0, strength);
	float path_mod = path_strength > 0.0
			? mix(1.0, texture(path_detail, world_xz / tile_size).r * 2.0, path_strength)
			: mix(1.0, d * 2.0, strength * 0.3);
	float detail_mod = mix(ground_mod, path_mod, cover);
	ALBEDO = mix(ground, path_col, cover) * detail_mod * (1.0 - shadow_depth);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	sun_left = 1.0 - clouds * cloud_cover(world_xz);
}

void light() {
	float facing = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) / sun_sin;
	DIFFUSE_LIGHT += ambient_light * (shadow_depth / (1.0 - shadow_depth)) * facing * ATTENUATION * sun_left * sun_tint.rgb;
}
