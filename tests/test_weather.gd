extends SceneTree

var failed=0
var passed=0

func check(condition: bool, description: String) -> void:
	if condition:
		passed+=1
		print("PASS ",description)
	else:
		failed+=1
		push_error(description)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var prefs=SettingsManager.new("user://weather-test-prefs.cfg")
	prefs.data.weather_online=false
	var service=WeatherService.new()
	root.add_child(service)
	service.initialize(prefs,"user://weather-test.json")
	prefs.select_county("330106")
	service.pending_city=prefs.location_id()
	service._completed(HTTPRequest.RESULT_SUCCESS,200,[],JSON.stringify({"current":{"weather_code":63,"temperature_2m":20.5}}).to_utf8_buffer())
	check(service.current().get("code")==63,"valid response mapped and cached")
	check(FileAccess.file_exists("user://weather-test.json"),"cache persisted independently")
	service._completed(HTTPRequest.RESULT_CANT_CONNECT,0,[],[])
	check(service.current().get("code")==63 and service.status.begins_with("天气离线"),"network failure retains valid cache")
	service._completed(HTTPRequest.RESULT_SUCCESS,200,[],"{invalid".to_utf8_buffer())
	check(service.current().get("code")==63,"invalid JSON retains valid cache")
	service._completed(HTTPRequest.RESULT_SUCCESS,200,[],JSON.stringify({"current":{"weather_code":"oops","temperature_2m":{}}}).to_utf8_buffer())
	check(service.current().get("temperature")==20.5,"invalid field types cannot crash service")
	prefs.select_county("310101")
	check(service.current().is_empty(),"city change cannot display another city's weather")
	prefs.select_county("330106")
	prefs.data.location_custom=true
	prefs.data.location_lat=30.2
	prefs.data.location_lon=120.1
	service.cache.city=prefs.location_id()
	check(not service.current().is_empty(),"custom location cache identity")
	prefs.data.location_lat=31.2
	check(service.current().is_empty(),"moving system location cannot reuse another coordinate's weather")
	prefs.data.location_custom=false
	service.cache.city=prefs.location_id()
	service.refresh()
	check(service.status.begins_with("天气联网关闭"),"network opt-out state")
	check(not WeatherService.valid_cache({"city":"杭州","code":0,"temperature":INF,"fetched":1}),"non-finite cache rejected")
	if "--live-weather" in OS.get_cmdline_user_args():
		service.cache={}
		prefs.data.weather_online=true
		service.refresh()
		for i in 50:
			await create_timer(.3).timeout
			if not service.current().is_empty() or service.status.begins_with("天气离线"):
				break
		print("LIVE WEATHER: ",service.status," ",service.current())
		check(not service.current().is_empty(),"live HTTPS request")
	service.queue_free()
	await process_frame
	for path in ["user://weather-test.json","user://weather-test.json.tmp"]:
		DirAccess.remove_absolute(path)
	print("WEATHER RESULT: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
