class_name StallMeter
extends RefCounted
## Erkennt Stocken aus den Startzeiten der Frames (Echtzeit, ms): eine einzelne lange Lücke
## oder eine eingebrochene Bildrate. Ein Shader-Ruckler bis `GAP_MS` gilt als keins von
## beidem. Rechnet nur; `FreezeWatch` füttert es und meldet.

## Ab dieser Lücke zwischen zwei Frames gilt ein einzelnes Stocken (ms). Liegt über dem
## kalten Shader-Ruckler (`FxWarmup`, bis 1,5 s).
const GAP_MS := 2000
## Fenster für die Bildrate (ms, gekappte Lücken).
const WINDOW_MS := 1000
## Weniger Frames als diese in einem Fenster gelten als eingebrochene Bildrate.
const MIN_FRAMES := 12
## Eine Lücke zählt fürs Fenster höchstens so lang (ms), damit ein einzelner Ruckler das
## Fenster nicht allein füllt.
const CLIP_MS := 250

var _last_ms := -1
var _gaps := PackedInt32Array()
var _sum := 0


## Meldet den Beginn eines Frames. Gibt die Lücke davor zurück (ms), wenn gestockt wurde,
## sonst 0. Nach einer Meldung beginnt die Messung der Bildrate neu.
func frame(now_ms: int) -> int:
	if _last_ms < 0:
		_last_ms = now_ms
		return 0
	var gap := now_ms - _last_ms
	_last_ms = now_ms
	var clipped := mini(gap, CLIP_MS)
	_gaps.append(clipped)
	_sum += clipped
	while _gaps.size() > 1 and _sum - _gaps[0] >= WINDOW_MS:
		_sum -= _gaps[0]
		_gaps.remove_at(0)
	if gap < GAP_MS and (_sum < WINDOW_MS or _gaps.size() >= MIN_FRAMES):
		return 0
	_gaps.clear()
	_sum = 0
	return maxi(gap, 1)
