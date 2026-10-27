class_name SettingsManager
extends RefCounted

const PRESETS = {
	"节能优先": {"fps": 15, "scale": 0.5, "shadow": 0, "effects": 0},
	"均衡": {"fps": 30, "scale": 0.85, "shadow": 1, "effects": 1},
	"高画质": {"fps": 30, "scale": 1.0, "shadow": 2, "effects": 2}}
const CITIES = {
	"杭州": {"lat": 30.27, "lon": 120.15, "offset": 8.0, "tz": "Asia/Shanghai"},
	"上海": {"lat": 31.23, "lon": 121.47, "offset": 8.0, "tz": "Asia/Shanghai"},
	"北京": {"lat": 39.90, "lon": 116.40, "offset": 8.0, "tz": "Asia/Shanghai"},
	"成都": {"lat": 30.67, "lon": 104.06, "offset": 8.0, "tz": "Asia/Shanghai"},
	"广州": {"lat": 23.13, "lon": 113.26, "offset": 8.0, "tz": "Asia/Shanghai"},
	"深圳": {"lat": 22.54, "lon": 114.06, "offset": 8.0, "tz": "Asia/Shanghai"},
	"东京": {"lat": 35.68, "lon": 139.69, "offset": 9.0, "tz": "Asia/Tokyo"},
	"新加坡": {"lat": 1.35, "lon": 103.82, "offset": 8.0, "tz": "Asia/Singapore"}}
const CITY_PROVINCES={"杭州":"浙江","上海":"上海","北京":"北京","成都":"四川","广州":"广东","深圳":"广东","东京":"东京都","新加坡":"新加坡"}
var data = {"preset": "均衡", "fps": 30, "scale": 0.85, "shadow": 1, "effects": 1,
	"hud_details_position":Vector2(-1,-1),"hud_tools_position":Vector2(-1,-1),"hud_weather_position":Vector2(-1,-1),
	"dynamic": true, "background_saving": true, "city": "北京市", "weather_online": true,
	"refresh_minutes": 30, "monitor": 0, "camera": 0, "desktop_camera": 0,
	"companion_scale":1.0,"companion_x":-1,"companion_y":-1,"audio_enabled":false,
	"rain_volume":0.2,"insects_volume":0.2,"leaves_volume":0.2,
	"camera_position":Vector3(0,30,.001),"camera_target":Vector3(0,.59,0),"camera_size":18.0,"visual_revision":9,"performance_revision":1,
	"province":"北京市","province_code":"11","city_code":"1101","county_code":"110101","county":"东城区",
	"location_mode":"auto","location_source":"default",
	"location_custom":false,"location_lat":30.27,"location_lon":120.15,"location_accuracy":0.0,"location_measured_at":0.0,"location_notice":"","location_revision":1}
var path: String

func _init(config_path: String = "user://preferences.cfg") -> void:
	path=config_path
	var cfg = ConfigFile.new()
	if cfg.load(path) == OK:
		for key in data:
			var value = cfg.get_value("preferences", key, data[key])
			if typeof(value) == typeof(data[key]):
				data[key] = value
		if int(cfg.get_value("preferences","visual_revision",0))<9:
			data.camera_position=Vector3(0,30,.001)
			data.camera_target=Vector3(0,.59,0)
			data.camera=0
			data.visual_revision=9
			data.camera_size=18.0
		if int(cfg.get_value("preferences","performance_revision",0))<1:
			if data.preset=="均衡" and is_equal_approx(data.scale,1.0):
				data.scale=.85
			data.performance_revision=1
	RegionCatalog.load_catalog()
	if int(cfg.get_value("preferences","location_revision",0))<1:
		if data.location_custom:
			data.county_code=""
			data.county=""
			data.location_notice="旧定位没有精度信息，请重新自动定位或手动选择区县。"
		else:
			var legacy=RegionCatalog.find_city(str(data.city))
			select_county(RegionCatalog.first_county(legacy) if not legacy.is_empty() else "110101")
	elif not data.location_custom:
		var source=str(data.location_source)
		if not select_county(str(data.county_code),source):
			use_default_location()
	if not cfg.has_section_key("preferences","location_mode"):
		data.location_mode="auto"
		data.location_source="gps" if data.location_custom else "default"
	if not data.fps in [15, 30]:
		data.fps = 30
	data.scale = clampf(data.scale, 0.5, 1.0)
	data.shadow = clampi(data.shadow, 0, 2)
	data.effects = clampi(data.effects, 0, 2)
	data.refresh_minutes = clampi(data.refresh_minutes, 15, 120)
	data.camera = clampi(data.camera, 0, 2)
	data.desktop_camera = clampi(data.desktop_camera, 0, 2)
	data.location_lat=clampf(data.location_lat,-89.9,89.9)
	data.location_lon=clampf(data.location_lon,-180,180)

func location() -> Dictionary:
	var county=RegionCatalog.get_region(str(data.county_code))
	if not county.is_empty():
		return {"lat":data.location_lat if data.location_custom else county.lat,"lon":data.location_lon if data.location_custom else county.lon,"offset":8.0,"tz":"Asia/Shanghai"}
	return {"lat":data.location_lat,"lon":data.location_lon,"offset":Time.get_time_zone_from_system().bias/60.0,"tz":"auto"}

func location_id() -> String:
	return "%s:%s:%.5f,%.5f" % ["IP" if data.location_source=="ip" else "GPS",data.county_code,data.location_lat,data.location_lon] if data.location_custom else "CN:"+str(data.county_code)

func location_label() -> String:
	return "%s · %s" % [data.city,data.county] if not str(data.county).is_empty() else "系统位置（区县未确认）"

func select_county(code: String,source: String="manual") -> bool:
	var county=RegionCatalog.get_region(code)
	if county.is_empty() or not county.get("available",false):
		return false
	data.county_code=code
	data.county=county.name
	data.city_code=county.city
	data.province_code=county.province
	data.city=RegionCatalog.get_region(county.city).name
	data.province=RegionCatalog.get_region(county.province).name
	data.location_lat=float(county.lat)
	data.location_lon=float(county.lon)
	data.location_custom=false
	data.location_accuracy=0.0
	data.location_notice=""
	data.location_revision=1
	data.location_source=source
	data.location_mode="manual" if source=="manual" else "auto"
	return true

func apply_auto_location(lat: float,lon: float,accuracy: float,measured_at: float) -> Dictionary:
	var age=Time.get_unix_time_from_system()-measured_at
	if not is_finite(measured_at) or age>300 or age< -60:
		data.location_notice="定位结果已过期，请重新定位。"
		return {"ok":false,"reason":"stale"}
	var result=RegionCatalog.resolve_coordinate(lat,lon,accuracy)
	if not result.ok:
		data.location_notice="当前定位精度不足以确认区县，请在省／市／区县中手动选择。" if result.reason=="boundary" else "未能确认所在区县，请手动选择。"
		return result
	select_county(result.county_code,"gps")
	data.location_lat=lat
	data.location_lon=lon
	data.location_custom=true
	data.location_accuracy=accuracy
	data.location_measured_at=measured_at
	data.location_notice=""
	return result

func apply_ip_location(lat: float,lon: float,measured_at: float) -> bool:
	var age=Time.get_unix_time_from_system()-measured_at
	if not is_finite(measured_at) or age>300 or age< -60:
		return false
	var result=RegionCatalog.resolve_coordinate(lat,lon,0)
	if not result.has("county_code") or not select_county(str(result.county_code),"ip"):
		return false
	data.location_lat=lat
	data.location_lon=lon
	data.location_custom=true
	data.location_accuracy=-1.0
	data.location_measured_at=measured_at
	data.location_notice="IP 估算位置可能有偏差，请确认区县，或手动修改。"
	return true

func use_default_location() -> void:
	select_county("110101","default")
	data.location_notice="系统定位与 IP 定位均不可用，暂用北京（东城区），请手动选择所在区县。"

func save() -> Error:
	var cfg = ConfigFile.new()
	for key in data:
		cfg.set_value("preferences", key, data[key])
	return cfg.save(path)

func preset(name: String) -> void:
	if PRESETS.has(name):
		data.merge(PRESETS[name], true)
		data.preset = name
		save()
