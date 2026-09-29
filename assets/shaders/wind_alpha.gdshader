shader_type spatial;
render_mode depth_prepass_alpha;
// Wind für Laub mit Alpha-Textur (die gekauften Bäume). Alles Weitere: wind.gdshaderinc.
#define WIND_ALPHA
#include "res://assets/shaders/wind.gdshaderinc"
