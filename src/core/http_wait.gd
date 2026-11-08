class_name HttpWait
## Wartet auf eine laufende Anfrage eines `HTTPRequest` ohne Thread (CONVENTIONS, Fallen) und
## macht einen Stillstand zum Fehler, statt ewig zu warten.

## Sekunden bis zum ersten Byte, Weiterleitungen eingeschlossen.
const CONNECT_TIMEOUT := 30.0
## Sekunden ohne neues Byte, während übertragen wird.
const STALL_TIMEOUT := 60.0


## Die Argumente von `request_completed` als Array [result, code, headers, body]. Bewegt sich
## nichts mehr, bricht es ab und gibt `RESULT_TIMEOUT` zurück. Direkt nach `request()` rufen.
static func completed(http: HTTPRequest, connect_s := CONNECT_TIMEOUT,
		stall_s := STALL_TIMEOUT) -> Array:
	var outcome: Array = []
	var on_done := func(result: int, code: int, headers: PackedStringArray,
			body: PackedByteArray) -> void:
		# Füllen statt zuweisen: ein Lambda fängt Variablen als Kopie.
		outcome.append_array([result, code, headers, body])
	http.request_completed.connect(on_done, CONNECT_ONE_SHOT)
	var last_bytes := 0
	var last_change := Time.get_ticks_msec()
	while outcome.is_empty():
		await http.get_tree().process_frame
		var got := http.get_downloaded_bytes()
		var now := Time.get_ticks_msec()
		if got != last_bytes:
			last_bytes = got
			last_change = now
		if stalled(got > 0, float(now - last_change) / 1000.0, connect_s, stall_s) \
				and outcome.is_empty():
			http.request_completed.disconnect(on_done)
			http.cancel_request()
			return [HTTPRequest.RESULT_TIMEOUT, 0, PackedStringArray(), PackedByteArray()]
	return outcome


## Hängt die Anfrage? Vor dem ersten Byte gilt `connect_s`, danach `stall_s`, jeweils seit
## dem letzten Fortschritt.
static func stalled(receiving: bool, idle_seconds: float, connect_s := CONNECT_TIMEOUT,
		stall_s := STALL_TIMEOUT) -> bool:
	return idle_seconds > (stall_s if receiving else connect_s)
