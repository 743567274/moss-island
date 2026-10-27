extends SceneTree
var passed=0
var failures=0
func check(value: bool,message: String) -> void:
 if value:
  passed+=1
  print("PASS ",message)
 else:
  failures+=1
  push_error(message)
func _initialize() -> void:
 run.call_deferred()
func run() -> void:
 RegionCatalog.load_catalog()
 check(RegionCatalog.provinces.size()==34,"All 34 provincial regions are available")
 check(RegionCatalog.cities.size()>350 and RegionCatalog.counties.size()>=3212,"Nationwide city and county catalog replaces the short city list")
 var all_valid=true
 var seen={}
 for county in RegionCatalog.counties:
  all_valid=all_valid and county.get("available",false) and is_finite(float(county.lat)) and is_finite(float(county.lon))
  all_valid=all_valid and RegionCatalog.get_region(county.city).province==county.province and not seen.has(county.code)
  seen[county.code]=true
 check(all_valid,"Every county has unique identity, valid hierarchy, coordinates and an indexed boundary")
 var reverse_good=true
 var reverse_report=[]
 for code in ["110101","310101","330106","440305","510121","150702","542525","710101","810000","820000","653228","653229","653132"]:
  var county=RegionCatalog.get_region(code)
  var result=RegionCatalog.resolve_coordinate(county.lat,county.lon,0)
  reverse_good=reverse_good and result.get("county_code","")==code
  reverse_report.append({"code":code,"result":result})
 check(reverse_good,"Offline polygon lookup handles municipalities, counties, autonomous areas, Taiwan, SARs and recent Xinjiang counties")
 var prefs=SettingsManager.new("user://county-weather-test.cfg")
 check(prefs.data.county_code=="110101" and prefs.data.location_mode=="auto","New settings default to Beijing in automatic mode")
 check(prefs.select_county("350102"),"Manual choice supports Fuzhou Gulou district")
 var first_id=prefs.location_id()
 var first_point=prefs.location()
 prefs.select_county("320106")
 check(first_id!=prefs.location_id() and absf(first_point.lon-prefs.location().lon)>.1,"Same-named counties in different cities cannot share weather or coordinates")
 var service=WeatherService.new()
 root.add_child(service)
 prefs.data.weather_online=false
 service.initialize(prefs,"user://county-weather-cache-test.json")
 var url=service.forecast_url()
 check(url.contains("latitude=%.6f" % prefs.location().lat) and url.contains("longitude=%.6f" % prefs.location().lon),"Weather URL uses the selected county coordinate, not its prefecture center")
 var old_id=prefs.location_id()
 service.pending_city=old_id
 prefs.select_county("330106")
 service._completed(HTTPRequest.RESULT_SUCCESS,200,[],JSON.stringify({"current":{"weather_code":63,"temperature_2m":20.5}}).to_utf8_buffer())
 check(service.cache.is_empty(),"Late response from a previous county is discarded")
 var county=RegionCatalog.get_region("330106")
 var now=Time.get_unix_time_from_system()
 var actual_lat=float(county.lat)+.0001
 var actual_lon=float(county.lon)+.0001
 var automatic=prefs.apply_auto_location(actual_lat,actual_lon,10,now)
 check(automatic.ok and prefs.data.location_custom and prefs.data.county_code=="330106","Precise Windows-style WGS84 fix resolves to the actual county")
 check(is_equal_approx(prefs.location().lat,actual_lat) and is_equal_approx(prefs.location().lon,actual_lon) and prefs.location_id().begins_with("GPS:330106:"),"Automatic weather keeps the actual coordinate rather than replacing it with a county center")
 var kept_id=prefs.location_id()
 var coarse=prefs.apply_auto_location(county.lat,county.lon,100000,now)
 check(not coarse.ok and prefs.location_id()==kept_id,"City-sized uncertainty cannot silently replace a confirmed county")
 var stale=prefs.apply_auto_location(county.lat,county.lon,10,now-600)
 check(not stale.ok and prefs.location_id()==kept_id,"Stale cached location cannot replace the current place")
 check(not RegionCatalog.resolve_coordinate(INF,county.lon,10).ok and not RegionCatalog.resolve_coordinate(0,0,10).ok,"Invalid and out-of-catalog fixes are rejected")
 check(prefs.apply_ip_location(actual_lat,actual_lon,now) and prefs.data.location_source=="ip" and prefs.location_id().begins_with("IP:330106:"),"IP fallback is marked as estimate and has a distinct cache identity")
 check(prefs.data.location_accuracy<0 and str(prefs.data.location_notice).contains("估算"),"IP estimate never claims GPS accuracy")
 prefs.save()
 var ip_restored=SettingsManager.new("user://county-weather-test.cfg")
 check(ip_restored.data.location_source=="ip" and ip_restored.data.location_mode=="auto","IP source and automatic mode persist")
 check(not prefs.apply_ip_location(0,0,now) and not prefs.apply_ip_location(actual_lat,actual_lon,now-600),"Invalid or expired IP fixes are rejected")
 prefs.use_default_location()
 check(prefs.data.county_code=="110101" and prefs.data.location_source=="default" and str(prefs.data.location_notice).contains("手动"),"Exhausted automatic providers fall back to Beijing and prompt manual selection")
 prefs.apply_auto_location(actual_lat,actual_lon,10,now)
 check(prefs.data.location_source=="gps" and prefs.data.location_notice.is_empty(),"Successful system location takes priority over the fallback estimate")
 prefs.select_county("653228")
 prefs.save()
 var restored=SettingsManager.new("user://county-weather-test.cfg")
 check(restored.data.county_code=="653228" and restored.data.city_code=="6532" and restored.data.location_mode=="manual","Manual county selection persists and disables startup automatic replacement")
 var legacy=ConfigFile.new()
 legacy.set_value("preferences","city","深圳")
 legacy.set_value("preferences","province","广东")
 legacy.set_value("preferences","rain_volume",.37)
 legacy.save("user://county-legacy-test.cfg")
 var migrated=SettingsManager.new("user://county-legacy-test.cfg")
 check(migrated.data.city_code=="4403" and not str(migrated.data.county_code).is_empty() and migrated.data.rain_volume==.37,"Old city preferences migrate to county selection without resetting unrelated options")
 if "--live-weather" in OS.get_cmdline_user_args():
  prefs.select_county("330106")
  prefs.data.weather_online=true
  service.cache={}
  service.refresh(true)
  for i in 50:
   await create_timer(.3).timeout
   if not service.current().is_empty() or service.status.begins_with("天气离线"):
    break
  check(not service.current().is_empty() and service.current().city=="CN:330106","Live county-coordinate weather request succeeds")
  print("COUNTY LIVE WEATHER: ",service.status," county=",prefs.location_label())
 FileAccess.open("res://build/county-weather-check.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failures,"counties":RegionCatalog.counties.size(),"reverse":reverse_report},"\t"))
 service.queue_free()
 await process_frame
 for path in ["user://county-weather-test.cfg","user://county-legacy-test.cfg","user://county-weather-cache-test.json"]:
  DirAccess.remove_absolute(path)
 print("COUNTY WEATHER RESULT: ",passed," passed, ",failures," failed")
 quit(1 if failures else 0)
