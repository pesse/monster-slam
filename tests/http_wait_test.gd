extends GdUnitTestSuite

const PORT := 47812


func test_stall_limits() -> void:
	assert_bool(HttpWait.stalled(false, 31.0)).is_true()
	assert_bool(HttpWait.stalled(true, 31.0)).is_false()
	assert_bool(HttpWait.stalled(true, 61.0)).is_true()


## Ein Server, der annimmt und nie antwortet: die Anfrage endet als Timeout, und das Bild
## läuft dabei weiter.
func test_silent_server_ends_as_timeout_without_freezing() -> void:
	var server := TCPServer.new()
	assert_int(server.listen(PORT, "127.0.0.1")).is_equal(OK)
	var http: HTTPRequest = auto_free(HTTPRequest.new())
	http.use_threads = false
	add_child(http)
	assert_int(http.request("http://127.0.0.1:%d/" % PORT)).is_equal(OK)
	var started := Time.get_ticks_msec()
	var result: Array = await HttpWait.completed(http, 1.0, 1.0)
	server.stop()
	assert_int(int(result[0])).is_equal(HTTPRequest.RESULT_TIMEOUT)
	assert_int(Time.get_ticks_msec() - started).is_less(3000)
	assert_int(http.get_http_client_status()).is_equal(HTTPClient.STATUS_DISCONNECTED)
