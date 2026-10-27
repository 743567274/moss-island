class_name WeatherService
extends Node

signal changed
var settings: SettingsManager
var cache: Dictionary = {}
var status = "本地环境 · 联网未开启"
var request_node: HTTPRequest
var next_requests: Dictionary = {}
var pending_city = ""
var cache_path = "user://weather.json"
static var rules: Dictionary={}

func initialize(prefs: SettingsManager, storage_path: String = "user://weather.json") -> void:
	settings = prefs
	cache_path=storage_path
	request_node = HTTPRequest.new()
	request_node.timeout = 12.0
	add_child(request_node)
	request_node.request_completed.connect(_completed)
	if FileAccess.file_exists(cache_path):
		var parser=JSON.new()
		parser.parse(FileAccess.get_file_as_string(cache_path))
		var loaded = parser.data
		if valid_cache(loaded):
			cache = loaded
	var timer = Timer.new()
	timer.wait_time = 60.0
	timer.timeout.connect(refresh)
	add_child(timer)
	timer.start()
	refresh()

static func valid_cache(value: Variant) -> bool:
	if not value is Dictionary or not value.has_all(["city", "code", "temperature", "fetched"]) or not value.city is String:
		return false
	for key in ["code","temperature","fetched"]:
		if not (value[key] is float or value[key] is int) or not is_finite(float(value[key])):
			return false
	for key in ["wind_speed_10m","wind_direction_10m"]:
		if value.has(key) and (not (value[key] is float or value[key] is int) or not is_finite(float(value[key])) or value[key]<0):
			return false
	return value.fetched>0 and value.code>=0 and absf(float(value.temperature))<100

func current() -> Dictionary:
	if cache.get("city", "") == settings.location_id():
		return cache
	return {}

func refresh(force: bool = false) -> void:
	if not settings.data.weather_online:
		request_node.cancel_request()
		status = "本地环境 · 联网未开启" if current().is_empty() else "天气联网关闭 · "+cache_time()
		changed.emit()
		return
	var now = Time.get_unix_time_from_system()
	if request_node.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		if pending_city!=settings.location_id():
			request_node.cancel_request()
		else:
			return
	if now < float(next_requests.get(settings.location_id(),0.0)):
		status="等待定时刷新 · "+cache_time()
		changed.emit()
		return
	if not force and not current().is_empty() and now - float(cache.fetched) < settings.data.refresh_minutes * 60:
		status = "天气缓存 · " + cache_time()
		changed.emit()
		return
	pending_city = settings.location_id()
	status = "正在更新天气…"
	# Throttle failures as well as successes, including repeated button presses.
	next_requests[pending_city] = now + settings.data.refresh_minutes * 60
	if request_node.request(forecast_url()) != OK:
		status = "天气连接失败 · " + cache_time()
	changed.emit()

func forecast_url() -> String:
	var point=settings.location()
	return "https://api.open-meteo.com/v1/forecast?latitude=%.6f&longitude=%.6f&current=temperature_2m,weather_code,cloud_cover,precipitation,wind_speed_10m,wind_direction_10m&wind_speed_unit=kmh&timezone=%s&forecast_days=1" % [point.lat,point.lon,point.tz.uri_encode()]

func _completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if pending_city!=settings.location_id():
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		status = "天气离线 · " + cache_time()
		changed.emit()
		return
	var parser=JSON.new()
	parser.parse(body.get_string_from_utf8())
	var parsed = parser.data
	if parsed is Dictionary and parsed.get("current") is Dictionary:
		var current_data = parsed.current
		if current_data.has_all(["weather_code", "temperature_2m"]) and (current_data.weather_code is float or current_data.weather_code is int) and (current_data.temperature_2m is float or current_data.temperature_2m is int) and is_finite(float(current_data.temperature_2m)) and absf(float(current_data.temperature_2m))<100:
			cache = {"city": pending_city, "code": int(current_data.weather_code), "temperature": float(current_data.temperature_2m), "fetched": Time.get_unix_time_from_system()}
			for key in ["cloud_cover","precipitation","wind_speed_10m","wind_direction_10m"]:
				var value=current_data.get(key)
				if (value is int or value is float) and is_finite(float(value)):
					if key in ["wind_speed_10m","wind_direction_10m"] and value<0:
						continue
					cache[key]=float(value)
			var file = FileAccess.open(cache_path+".tmp", FileAccess.WRITE)
			if file != null:
				file.store_string(JSON.stringify(cache))
				file.close()
				DirAccess.rename_absolute(cache_path+".tmp", cache_path)
			status = "实时天气 · " + cache_time()
		else:
			status = "天气数据无效 · " + cache_time()
	else:
		status = "天气数据无效 · " + cache_time()
	changed.emit()

func cache_time() -> String:
	if current().is_empty():
		return "暂无缓存"
	var city = settings.location()
	var d = Time.get_datetime_dict_from_unix_time(int(cache.fetched + city.offset * 3600))
	return "%02d/%02d %02d:%02d 更新" % [d.month, d.day, d.hour, d.minute]

static func classify(code: int) -> String:
	if code in [95,96,99]:
		return "大雨"
	var mapping = {0: "晴", 1: "少云", 2: "多云", 3: "阴", 45: "雾", 48: "冻雾", 51: "毛毛雨", 53: "小雨", 55: "中雨", 56: "冻雨", 57: "冻雨", 61: "小雨", 63: "中雨", 65: "大雨", 66: "冻雨", 67: "冻雨", 71: "小雪", 73: "中雪", 75: "大雪", 77: "雪粒", 80: "阵雨", 81: "中阵雨", 82: "暴雨", 85: "阵雪", 86: "大雪", 95: "雷暴", 96: "雷暴冰雹", 99: "强雷暴"}
	var rule=configured_rule(code)
	return str(rule.get("label",mapping.get(code,"未知天气")))

static func configured_rule(code: int) -> Dictionary:
	if rules.is_empty():
		for path in ["res://data/weather_mapping.json","user://weather_mapping.json"]:
			if FileAccess.file_exists(path):
				var parser=JSON.new()
				if parser.parse(FileAccess.get_file_as_string(path))==OK and parser.data is Dictionary:
					for key in parser.data:
						var rule=parser.data[key]
						if rule is Dictionary and rule.get("label") is String and rule.get("effect") in ["clear","cloud","fog","rain","snow","storm"]:
							rules[str(key)]=rule
		# An unavailable config should not cause repeated disk reads each frame.
		rules["loaded"]=true
	return rules.get(str(code),{})

static func effect_type(code: int) -> String:
	# Retired thunderstorm conditions use ordinary heavy rain, including old caches/custom mappings.
	if code in [95,96,99]:
		return "rain"
	var rule=configured_rule(code)
	if rule.has("effect"):
		return "rain" if rule.effect=="storm" else rule.effect
	if code >= 95:
		return "rain"
	if code in [71, 73, 75, 77, 85, 86]:
		return "snow"
	if code >= 51:
		return "rain"
	if code in [45, 48]:
		return "fog"
	return "cloud" if code >= 2 else "clear"
