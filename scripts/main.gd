extends Node3D

var CAMERA_VIEWS = [
	{"position":Vector3(11.8,7.8,17.3),"target":Vector3(0,.8,-1),"size":24.5},
	{"position":Vector3(4,7,13),"target":Vector3(-4,.7,2.7),"size":14.5},
	{"position":Vector3(5,6,9),"target":Vector3(-3.8,1.3,-3.4),"size":14.0}]
var settings: SettingsManager
var save_manager: SaveManager
var state: FarmState
var scene: Courtyard
var ui: CourtyardUI
var weather: WeatherService
var desktop: DesktopModeManager
var performance_manager: PerformanceManager
var selected = -1
var tool = "inspect"
var crop = "corn"
var camera_tween: Tween
var camera_target = Vector3(0,.7,0)
var camera_index = 0
var environment_counter = 0
var last_saved = "尚未保存"
var shutting_down = false
var test_mode = false
var capture_mode = false
var elapsed_ticks = 0
var benchmark_samples=[]
var renderer_mode="immersive"
var control_dir=""
var last_control=""
var moving_island=false
var drag_start=Vector2i.ZERO
var drag_window=Vector2i.ZERO
var dragging=false
var middle_anchor: Variant=null
var last_daylight=-1.0
var camera_dirty=false
var ambient_audio: EnvironmentAudio
var controller_pid=0
var environment_test_window: EnvironmentTestWindow
var environment_preview={}
var last_manual_location_change=0.0
var map_editor: MapEditorWindow
var crop_editor: CropEditorWindow
var project_window: MapProjectWindow

func _ready() -> void:
	get_tree().auto_accept_quit=false
	test_mode="--test-mode" in OS.get_cmdline_user_args()
	capture_mode="--capture" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--renderer="):
			renderer_mode="immersive"
		if arg.begins_with("--control-dir="):
			control_dir=arg.trim_prefix("--control-dir=")
		if arg.begins_with("--controller-pid="):
			controller_pid=int(arg.trim_prefix("--controller-pid="))
	if not OS.has_feature("editor") and not test_mode and control_dir.is_empty():
		var launcher=OS.get_executable_path().get_base_dir().path_join("MossIsland.exe")
		if FileAccess.file_exists(launcher):
			var direct_mode="immersive"
			OS.create_process(launcher,["--mode="+direct_mode],false)
			get_tree().quit()
			return
	if OS.has_feature("editor") and control_dir.is_empty():
		test_mode=true
	get_tree().root.gui_embed_subwindows=false
	settings=SettingsManager.new("user://test-preferences.cfg" if test_mode else "user://preferences.cfg")
	if test_mode and ("--benchmark" in OS.get_cmdline_user_args() or "--profile-v2" in OS.get_cmdline_user_args()):
		# A fixed-rate benchmark must not measure background energy throttling.
		settings.path="user://benchmark-preferences.cfg"
		settings.data.background_saving=false
		settings.data.dynamic=false
	if test_mode:
		settings.data.weather_online=false
		settings.data.camera=0
		settings.preset("均衡")
	MapDefinition.load_map()
	if not test_mode:
		var project_error=MapProjectStore.initialize(MapLayoutStore.defaults(MapDefinition.load_map()))
		if project_error!=OK:
			push_error("无法初始化场景项目："+error_string(project_error))
			get_tree().quit()
			return
		MapLayoutStore.layout=MapProjectStore.active_layout()
	else:
		MapLayoutStore.layout={}
	var provider=LocalSaveProvider.new("user://test-farm.json" if test_mode else MapProjectStore.farm_path(MapProjectStore.active_id))
	save_manager=SaveManager.new(provider)
	state=save_manager.load_save(FarmState.PLOT_COUNT if test_mode or MapProjectStore.document(MapProjectStore.active_id).get("legacy_farm",false) else 0)
	if not test_mode:
		state.bind_map(MapProjectStore.active_id,MapLayoutStore.layout)
	scene=IllustratedCourtyard.new()
	add_child(scene)
	scene.initialize(state)
	scene.camera.h_offset=0
	ui=CourtyardUI.new()
	add_child(ui)
	ui.initialize(settings,state)
	ui.action.connect(_action)
	weather=WeatherService.new()
	add_child(weather)
	weather.changed.connect(_environment)
	weather.initialize(settings,"user://test-weather-main.json" if test_mode else "user://weather.json")
	desktop=DesktopModeManager.new()
	desktop.controller_pid=controller_pid
	add_child(desktop)
	desktop.initialize(settings)
	desktop.changed.connect(_desktop_changed)
	desktop.pointer_moved.connect(ui.set_wallpaper_pointer)
	desktop.problem.connect(func(message): ui.toast(message))
	desktop.bridge_failed.connect(func():
		save_farm(false)
		get_tree().quit())
	performance_manager=PerformanceManager.new()
	add_child(performance_manager)
	performance_manager.initialize(settings,scene.sun)
	desktop.visibility_changed.connect(func(covered):
		if not test_mode:
			performance_manager.occluded=covered
			performance_manager.apply()
			if not covered:
				state.settle(Time.get_unix_time_from_system())
				_environment())
	ambient_audio=EnvironmentAudio.new()
	add_child(ambient_audio)
	ambient_audio.initialize(settings)
	desktop.power_changed.connect(func(active):
		performance_manager.display_off=not active
		performance_manager.apply()
		if active:
			state.settle(Time.get_unix_time_from_system())
			_environment())
	_fit_illustrated_view()
	var tick=Timer.new()
	tick.wait_time=1.0
	tick.timeout.connect(_tick)
	add_child(tick)
	tick.start()
	var autosave=Timer.new()
	autosave.wait_time=60.0
	autosave.timeout.connect(func(): save_farm(false))
	add_child(autosave)
	autosave.start()
	var control_timer=Timer.new()
	control_timer.wait_time=.3
	control_timer.timeout.connect(_control_tick)
	add_child(control_timer)
	control_timer.start()
	if not test_mode and not control_dir.is_empty():
		desktop.enter()
	_environment()
	_tick()
	if "--profile-4k" in OS.get_cmdline_user_args():
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS,true)
		DisplayServer.window_set_size(Vector2i(1920,1080))
		DisplayServer.window_set_position(Vector2i.ZERO)
		settings.data.scale=2.0
		get_viewport().scaling_3d_scale=2.0
	if provider.notice!="":
		ui.toast(provider.notice)
	elif state.clock_notice!="":
		ui.toast(state.clock_notice)
	if capture_mode:
		_capture.call_deferred()
	if "--environment-test" in OS.get_cmdline_user_args():
		_environment_test.call_deferred()
	if "--integration" in OS.get_cmdline_user_args():
		_integration.call_deferred()
	if "--desktop-test" in OS.get_cmdline_user_args():
		_desktop_test.call_deferred()
	if "--energy-test" in OS.get_cmdline_user_args():
		_energy_test.call_deferred()
	if test_mode and "--county-catalog-test" in OS.get_cmdline_user_args():
		_county_catalog_test.call_deferred()
	if test_mode and "--crop-package-test" in OS.get_cmdline_user_args():
		_crop_package_test.call_deferred()
	if not test_mode and settings.data.location_mode=="auto":
		_request_location.call_deferred(false)

func _request_location(force: bool=true) -> void:
	if test_mode:
		return
	settings.data.location_mode="auto"
	settings.data.location_notice="正在获取系统位置，失败后将尝试 IP 定位…"
	settings.save()
	ui.sync_settings()
	_host_location_command("locate" if force else "locate-auto")

func _host_location_command(command: String) -> void:
	if not test_mode:
		var launcher=OS.get_executable_path().get_base_dir().path_join("MossIsland.exe")
		OS.create_process(launcher,["--command="+command],false)

func _location_result_current(requested_at: float) -> bool:
	return settings.data.location_mode=="auto" and requested_at>=last_manual_location_change

func _finish_location() -> void:
	settings.save()
	ui.sync_settings()
	weather.refresh()
	_environment()
	ui.toast(settings.location_label()+" · "+str(settings.data.location_notice))

func _crop_package_test() -> void:
	var path="user://corn-release-export.zip"
	var error=ContentCatalog.export_crop("corn",path)
	var zip=ZIPReader.new()
	var opened=zip.open(path)==OK
	var result={"ok":false,"files":zip.get_files().size() if opened else 0,"external":not str(ContentCatalog.package_dirs.corn).begins_with("res://"),"package_dir":str(ContentCatalog.package_dirs.corn),"export_error":error}
	var intact=true
	if opened:
		for asset in FarmState.CROPS.corn.assets.values():
			intact=intact and not zip.read_file(asset.file).is_empty()
		var config=JSON.parse_string(zip.read_file("crop.json").get_string_from_utf8())
		result["valid_config"]=ContentCatalog.valid_crop(config)
		result["intact_images"]=intact
		result.ok=error==OK and result.files==13 and intact and ContentCatalog.valid_crop(config)
		zip.close()
	FileAccess.open("user://crop-release-audit.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("CROP PACKAGE AUDIT: ",result)
	get_tree().quit(0 if result.ok else 1)

func _county_catalog_test() -> void:
	var checked=[]
	var failures=[]
	for province in RegionCatalog.provinces:
		var code=RegionCatalog.first_county(str(province.code))
		var county=RegionCatalog.get_region(code)
		var result=RegionCatalog.resolve_coordinate(county.lat,county.lon,0)
		checked.append(code)
		if result.get("county_code","")!=code:
			failures.append({"code":code,"result":result})
	var report={"checked":checked,"failures":failures,"counties":RegionCatalog.counties.size(),"version":ProjectSettings.get_setting("application/config/version","")}
	FileAccess.open("user://county-release-audit.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("COUNTY CATALOG AUDIT: ",checked.size()," provinces checked; ",failures.size()," failures; ",RegionCatalog.counties.size()," county entries")
	get_tree().quit(1 if not failures.is_empty() else 0)

func _tick() -> void:
	if camera_dirty:
		settings.save()
		camera_dirty=false
	state.settle(Time.get_unix_time_from_system())
	scene.refresh()
	ui.refresh()
	var solar=solar_now()
	ui.update_environment(solar,weather)
	environment_counter+=1
	if environment_counter>=30:
		environment_counter=0
		_environment()
	# Check minimized state even if a size notification wasn't emitted by the window manager.
	var minimized=DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_MINIMIZED
	if minimized!=performance_manager.minimized:
		performance_manager.minimized=minimized
		performance_manager.apply()
	if performance_manager.degradation>0:
		_environment()
	var cap="∞" if Engine.max_fps==0 else str(Engine.max_fps)
	ui.footer.text="%s   ·   %s× 生长%s   ·   %s FPS / 上限 %s   ·   %s" % [last_saved,state.data.rate,"已暂停" if state.data.paused else "",roundi(performance_manager.measured_fps),cap,settings.data.preset]
	elapsed_ticks+=1
	if "--benchmark" in OS.get_cmdline_user_args() or "--profile-v2" in OS.get_cmdline_user_args():
		_benchmark_tick()

func solar_now() -> Dictionary:
	var city=settings.location()
	var now=Time.get_unix_time_from_system()
	if "--visual-day" in OS.get_cmdline_user_args() or "--visual-night" in OS.get_cmdline_user_args():
		var d=Time.get_datetime_dict_from_unix_time(int(now+city.offset*3600))
		d.hour=22 if "--visual-night" in OS.get_cmdline_user_args() else 10
		d.minute=0
		now=Time.get_unix_time_from_datetime_dict(d)-city.offset*3600
	if not environment_preview.is_empty():
		var date=Time.get_datetime_dict_from_unix_time(int(now+city.offset*3600))
		date.hour=int(environment_preview.hour)
		date.minute=roundi(fmod(environment_preview.hour,1)*60)
		date.second=0
		now=Time.get_unix_time_from_datetime_dict(date)-city.offset*3600
	var sample=SolarClock.sample(now,city.lat,city.lon,city.offset)
	if "--visual-moon" in OS.get_cmdline_user_args():
		sample.daylight=0.0
		sample.altitude=-.6
		sample.moon={"altitude":.10,"azimuth":-.55,"phase":.5,"illumination":1.0}
	return sample

func _environment() -> void:
	if scene==null or weather==null:
		return
	var current=weather.current()
	var code=int(current.get("code",0))
	state.settle(Time.get_unix_time_from_system())
	state.temperature=float(current.get("temperature",20))
	state.temperature_from=float(current.get("fetched",0))
	state.temperature_until=state.temperature_from+float(settings.data.refresh_minutes)*60 if settings.data.weather_online and not current.is_empty() else 0.0
	state.rain_code=int(current.get("code",-1)) if not current.is_empty() else -1
	state.rain_valid_until=float(current.get("fetched",0))+float(settings.data.refresh_minutes)*60 if settings.data.weather_online else 0.0
	scene.preview_temperature=null
	if not environment_preview.is_empty():
		code=environment_preview.code
		scene.preview_temperature=environment_preview.temperature
	var quality=int(settings.data.effects)
	var visual_weather_override=false
	if performance_manager!=null:
		quality=maxi(0,quality-performance_manager.degradation)
	if test_mode:
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--profile-weather=") or ("--capture" in OS.get_cmdline_user_args() and arg.begins_with("--capture-weather=")):
				code=int(arg.get_slice("=",1))
				visual_weather_override=true
				scene.preview_temperature=-6.0 if code in [71,73,75] else 20.0
	scene.update_environment(solar_now(),code,quality)
	if environment_preview.is_empty() and not visual_weather_override:
		scene.environment_controller.apply_details(current)
	elif not environment_preview.is_empty():
		scene.environment_controller.apply_details({"wind_speed_10m":environment_preview.get("wind_speed_10m",10.0),"wind_direction_10m":current.get("wind_direction_10m",270.0)})
	if ambient_audio!=null:
		ambient_audio.apply(scene.weather_type,solar_now().daylight)
	ui.update_environment(solar_now(),weather)

func _action(name: String, value: Variant) -> void:
	if name=="request_location":
		_request_location()
		return
	if desktop.locked and not name in ["setting","save","map_editor","crop_editor"]:
		return
	match name:
		"crop_editor":
			_open_crop_editor()
		"map_editor":
			_open_map_editor()
		"primary":
			if selected>=0:
				var p=state.data.plots[selected]
				if p.get("health","") in ["dead","harvested"]:
					state.clear_dead(selected)
				elif p.crop=="":
					state.plant(selected,crop,Time.get_unix_time_from_system())
				else:
					state.harvest(selected,Time.get_unix_time_from_system())
				after_change()
			else:
				ui.region=""
				ui.refresh()
		"water":
			if selected<0 or ui.selection!=selected:
				return
			ui.seed_picker.hide()
			if state.water(selected,Time.get_unix_time_from_system()):
				after_change()
				ui.toast("已浇水，土壤水分已补充。")
		"plant_selected":
			if selected<0 or selected>=state.data.plots.size() or ui.selection!=selected:
				return
			if state.plant(selected,str(value),Time.get_unix_time_from_system()):
				ui.seed_picker.hide()
				after_change()
				ui.toast("已在 %02d 号田播种。" % (selected+1))
				var notice=FarmState.sowing_notice(str(value),Time.get_unix_time_from_system())
				if not notice.is_empty():
					ui.toast("已播种 · "+notice)
			else:
				ui.toast("当前田块已有作物，请先收获或清理。")
		"harvest_selected":
			if selected<0 or selected>=state.data.plots.size() or ui.selection!=selected:
				return
			var plot=state.data.plots[selected]
			var changed=state.clear_dead(selected) if plot.health in ["dead","harvested"] else state.harvest(selected,Time.get_unix_time_from_system())
			if changed:
				ui.seed_picker.hide()
				after_change()
		"crop":
			_action("plant_selected",value)
		"tool":
			if str(value)=="water":
				_action("water",null)
			elif str(value)=="harvest":
				_action("harvest_selected",null)
		"save":
			save_farm(true)
		"desktop":
			if desktop.desktop:
				desktop.leave()
			else:
				save_farm(false)
				desktop.enter()
		"undo_decoration":
			if not state.data.decorations.is_empty():
				state.data.decorations.pop_back()
				after_change()
				ui.toast("已撤回最后一件装饰。")
			else:
				ui.toast("还没有摆放装饰。")
		"setting":
			change_setting(value.key,value.value)

func set_tool(value: String) -> void:
	tool=value
	ui.set_tool(tool)

func after_change() -> void:
	scene.refresh()
	ui.refresh()
	save_farm(false)

func save_farm(feedback: bool) -> void:
	var err=save_manager.save_game_state()
	if err!=OK:
		ui.toast("存档写入失败（%s），上一份有效存档已保留。" % error_string(err))
		last_saved="保存失败"
	else:
		var date=solar_now().date
		last_saved="已保存 %02d:%02d" % [date.hour,date.minute]
		if feedback:
			ui.toast("农场已保存，离线时也会慢慢生长。")

func change_setting(key: String, value: Variant) -> void:
	var now=Time.get_unix_time_from_system()
	if key=="rate":
		state.set_rate(float(value),now)
		save_farm(false)
	elif key=="paused":
		state.set_paused(bool(value),now)
		save_farm(false)
	elif key=="offline_cap_days":
		state.settle(now)
		state.data.offline_cap_days=int(value)
		save_farm(false)
	else:
		if key in ["province_code","city_code","county_code"]:
			var code=str(value) if key=="county_code" else RegionCatalog.first_county(str(value))
			if not settings.select_county(code):
				ui.toast("所选区县的数据暂不可用。")
				return
			last_manual_location_change=now
		if key=="preset" and value!="自定义":
			settings.preset(str(value))
		else:
			settings.data[key]=value
			if key in ["fps","scale","shadow","effects"]:
				settings.data.preset="自定义"
		if settings.save()!=OK:
			ui.toast("偏好设置保存失败。")
		performance_manager.degradation=0
		performance_manager.apply()
		if key in ["province_code","city_code","county_code","weather_online","refresh_minutes"]:
			weather.refresh()
		_environment()
	ui.sync_settings()
	ui.refresh()

func set_camera(_index: int=0,_smooth: bool=false) -> void:
	_fit_illustrated_view()

func _remember_camera() -> void:
	pass

func _collapse_panels() -> void:
	selected=-1
	tool="inspect"
	scene.select_plot(-1)
	ui.selection=-1
	ui.region=""
	ui.set_tool("inspect")
	ui.toast_panel.hide()
	ui.settings_overlay.hide()
	if ui.settings_window!=null:
		ui.settings_window.hide()
	if ui.collection_window!=null:
		ui.collection_window.hide()
	if environment_test_window!=null and environment_test_window.visible:
		environment_test_window.restore_live()
		environment_test_window.hide()

func _illustration_cover_size() -> float:
	var size=get_viewport().get_visible_rect().size
	return minf(MapDefinition.world_size.y,MapDefinition.world_size.x*size.y/maxf(1.0,size.x))

func _fit_illustrated_view() -> void:
	if scene==null:
		return
	camera_target=Vector3(0,.59,0)
	scene.camera.position=camera_target+Vector3(0,30,.001)
	scene.camera.size=_illustration_cover_size()
	scene.camera.look_at(camera_target)

func _open_environment_test() -> void:
	if environment_test_window==null:
		environment_test_window=EnvironmentTestWindow.new()
		get_tree().root.add_child(environment_test_window)
		environment_test_window.initialize(solar_now(),weather.current(),ui.root.theme,maxi(0,selected),state.data.plots.size())
		environment_test_window.crop_preview_changed.connect(func(preview):
			scene.set("crop_preview",preview)
			scene.refresh(true))
		environment_test_window.preview_changed.connect(func(hour,code,temperature):
			environment_preview={"hour":hour,"code":code,"temperature":temperature,"wind_speed_10m":environment_test_window.wind_control.value}
			_environment()
			# Preview shows the requested condition immediately; live weather still blends.
			scene.environment_controller.advance(20.0)
			scene._apply_environment())
		environment_test_window.restored.connect(func():
			environment_preview.clear()
			_environment()
			environment_test_window.sync_live_wind(weather.current()))
	if environment_preview.is_empty():
		environment_test_window.sync_live_wind(weather.current())
	if DisplayServer.get_name()=="headless":
		environment_test_window.show()
	else:
		environment_test_window.popup_centered()

func _open_map_editor() -> void:
	if is_instance_valid(map_editor) and map_editor.visible:
		map_editor.grab_focus()
		return
	if project_window==null:
		project_window=MapProjectWindow.new()
		get_tree().root.add_child(project_window)
		project_window.initialize(ui.root.theme)
		project_window.edit_requested.connect(_edit_project)
		project_window.apply_requested.connect(_apply_project)
		project_window.visibility_changed.connect(_sync_editor_activity)
	project_window.refresh()
	project_window.popup_centered()
	_sync_editor_activity()

func _sync_editor_activity() -> void:
	performance_manager.editor_active=(is_instance_valid(crop_editor) and crop_editor.visible) or (is_instance_valid(project_window) and project_window.visible) or (is_instance_valid(map_editor) and map_editor.visible)
	performance_manager.apply()

func _edit_project(id: String) -> void:
	if map_editor!=null:
		map_editor.queue_free()
	var preview: FarmState
	if id==MapProjectStore.active_id:
		preview=FarmState.new()
		preview.data=state.data.duplicate(true)
	else:
		var manager=SaveManager.new(LocalSaveProvider.new(MapProjectStore.farm_path(id)))
		preview=manager.load_save(FarmState.PLOT_COUNT if MapProjectStore.document(id).get("legacy_farm",false) else 0)
	preview.bind_map(id,MapProjectStore.edit_layout(id))
	map_editor=MapEditorWindow.new()
	get_tree().root.add_child(map_editor)
	map_editor.initialize(ui.root.theme,preview,id)
	map_editor.application_requested.connect(_apply_project)
	map_editor.visibility_changed.connect(func():
		if is_instance_valid(map_editor) and not map_editor.visible:
			map_editor.queue_free()
			map_editor=null
			_open_map_editor.call_deferred()
		_sync_editor_activity())
	map_editor.popup_centered()
	_sync_editor_activity()

func _apply_project(id: String,layout: Dictionary) -> void:
	var error=save_manager.save_game_state()
	if error!=OK:
		_project_notice("当前种植存档保存失败，未切换项目："+error_string(error))
		return
	if not MapLayoutStore.valid(layout):
		_project_notice("项目布局无效，未应用。")
		return
	if not MapLightFixture.paint_files_exist(layout):
		_project_notice("灯光擦除记录缺失或无法读取，未应用；请重新编辑对应光源。")
		return
	var region_path=str(layout.get("water_region",{}).get("mask",""))
	if not region_path.is_empty() and not FileAccess.file_exists(region_path):
		_project_notice("地图水域标记文件缺失，未应用。")
		return
	for item in layout.objects:
		var emission_path=str(item.get("emission_mask",""))
		if not emission_path.is_empty() and not FileAccess.file_exists(emission_path):
			_project_notice("灯具自发光区域文件缺失，未应用。")
			return
		if item.has("fixture"):
			var fixture_error=MapLightFixture.texture_error(item)
			if not fixture_error.is_empty():
				_project_notice(fixture_error)
				return
		if not FileAccess.file_exists(item.texture):
			_project_notice("项目素材缺失，未应用："+str(item.texture))
			return
		var mask=str(item.get("water",{}).get("mask",""))
		if not mask.is_empty() and not FileAccess.file_exists(mask):
			_project_notice("水面标记文件缺失，未应用。")
			return
	for plot in layout.plots:
		if plot.has("surface"):
			if not FileAccess.file_exists(plot.surface.texture):
				_project_notice("土地图片缺失，未应用。")
				return
			var selected_texture=str(plot.surface.get("selected_texture",""))
			if not selected_texture.is_empty() and not FileAccess.file_exists(selected_texture):
				_project_notice("土地选中图片缺失，未应用。")
				return
	var candidate=save_manager if id==MapProjectStore.active_id else SaveManager.new(LocalSaveProvider.new(MapProjectStore.farm_path(id)))
	if candidate!=save_manager:
		candidate.load_save(FarmState.PLOT_COUNT if MapProjectStore.document(id).get("legacy_farm",false) else 0)
	var retained={}
	for plot in layout.plots:
		retained[str(plot.id)]=true
	for index in candidate.state.data.plots.size():
		var plot=candidate.state.data.plots[index]
		if not str(plot.crop).is_empty() and not retained.has(str(plot.get("map_plot_id","plot-%d" % index))):
			_project_notice("有田块仍种着作物，请先收获并铲除，未应用删除。")
			return
	var snapshot=candidate.state.data.duplicate(true)
	candidate.state.bind_map(id,layout)
	error=candidate.save_game_state()
	if error!=OK:
		candidate.state.data=snapshot
		_project_notice("项目种植记录保存失败，未切换："+error_string(error))
		return
	error=MapProjectStore.save_project(id,layout)
	if error==OK:
		error=MapProjectStore.activate(id)
	if error!=OK:
		candidate.state.data=snapshot
		candidate.save_game_state()
		_project_notice("项目应用失败，桌面保持原场景："+error_string(error))
		return
	_collapse_panels()
	if is_instance_valid(environment_test_window):
		environment_test_window.queue_free()
		environment_test_window=null
	environment_preview.clear()
	save_manager=candidate
	state=candidate.state
	CropEditorStore.active_farm=state
	ui.state=state
	var previous_scene=scene
	previous_scene.hide()
	for layer_name in ["ScreenFog","ScreenLights"]:
		var previous_layer=previous_scene.get_node_or_null(layer_name)
		if previous_layer!=null: previous_layer.hide()
	previous_scene.process_mode=Node.PROCESS_MODE_DISABLED
	scene=IllustratedCourtyard.new()
	add_child(scene)
	scene.initialize(state)
	_retire_map_scene(previous_scene)
	performance_manager.sun=scene.sun
	performance_manager.applied_shadow_size=-1
	performance_manager.apply()
	_fit_illustrated_view()
	_select_plot(-1)
	_environment()
	ui.refresh()
	if is_instance_valid(map_editor):
		var preview=FarmState.new()
		preview.data=state.data.duplicate(true)
		map_editor.canvas.farm=preview
	if is_instance_valid(project_window):
		project_window.refresh()
	_project_notice("已应用项目“%s”，种植和库存按项目独立保存。" % MapProjectStore.document(id).name)

func _project_notice(message: String) -> void:
	ui.toast(message)
	if is_instance_valid(map_editor):
		map_editor.status.text=message
	if is_instance_valid(project_window):
		project_window.status.text=message

func _control_tick() -> void:
	if control_dir.is_empty():
		return
	var path=control_dir.path_join("command")
	if not FileAccess.file_exists(path):
		return
	var message=FileAccess.get_file_as_string(path).strip_edges().trim_prefix("\ufeff")
	if message==last_control:
		return
	last_control=message
	var parts=message.split("|")
	if parts.size()<2:
		return
	match parts[1]:
		"request_location":
			_request_location()
		"location":
			if parts.size()>=7:
				if not _location_result_current(float(parts[6])):
					ui.toast("已保留你刚刚手动选择的区县。")
					return
				var result=settings.apply_auto_location(float(parts[2]),float(parts[3]),float(parts[4]),float(parts[5]))
				settings.save()
				ui.sync_settings()
				if result.ok:
					weather.refresh()
					_environment()
					ui.toast("已定位到 "+RegionCatalog.path_label(str(settings.data.county_code)))
				else:
					settings.data.location_notice="系统定位无法确认区县，正在尝试 IP 估算…"
					ui.sync_settings()
					_host_location_command("locate-ip|"+str(parts[6]))
		"location-ip":
			if parts.size()>=6 and _location_result_current(float(parts[5])):
				if not settings.apply_ip_location(float(parts[2]),float(parts[3]),float(parts[4])):
					settings.use_default_location()
				_finish_location()
		"location-failed":
			if parts.size()>=3 and _location_result_current(float(parts[2])):
				settings.use_default_location()
				_finish_location()
		"lock":
			if renderer_mode=="immersive":
				desktop.command("lock")
		"unlock":
			if renderer_mode=="immersive":
				desktop.command("unlock")
		"settings":
			ui.open_settings()
		"crop_editor":
			_open_crop_editor()
		"map_editor":
			_open_map_editor()
		"collection":
			ui.show_collection()
		"environment_test":
			_open_environment_test()
		"preset":
			if parts.size()>2 and SettingsManager.PRESETS.has(parts[2]):
				change_setting("preset",parts[2])
		"resource_report":
			var report={"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"preset":settings.data.preset,"scale":get_viewport().scaling_3d_scale,"occluded":performance_manager.occluded,"cap":Engine.max_fps,"rendering":RenderingServer.render_loop_enabled,"fps":performance_manager.measured_fps,"texture_mb":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)/1048576.0,"mesh_mb":Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)/1048576.0,"static_mb":OS.get_static_memory_usage()/1048576.0,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
			var file=FileAccess.open(control_dir.path_join("resource-report.json"),FileAccess.WRITE)
			if file!=null:
				file.store_string(JSON.stringify(report,"\t"))
		"quit":
			RenderingServer.render_loop_enabled=true
			_remember_camera()
			settings.save()
			if save_manager.save_game_state()==OK:
				get_tree().quit()

func _desktop_changed() -> void:
	ui.set_desktop(desktop.desktop,desktop.locked)
	if desktop.locked:
		_collapse_panels()
	performance_manager.locked=desktop.locked
	performance_manager.apply()
	state.settle(Time.get_unix_time_from_system())
	scene.camera.h_offset=0
	save_farm(false)

func _unhandled_input(event: InputEvent) -> void:
	if "--capture" in OS.get_cmdline_user_args():
		return
	if desktop.locked:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:
			if ui.settings_overlay.visible:
				ui.settings_overlay.hide()
			else:
				_select_plot(-1)
			return
		if event.keycode==KEY_S and event.ctrl_pressed:
			save_farm(true)
			return
	if ui.settings_window!=null and ui.settings_window.visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var ray=scene.camera.project_ray_origin(event.position)
		var direction=scene.camera.project_ray_normal(event.position)
		var point=Plane(Vector3.UP,.59).intersects_ray(ray,direction)
		if point!=null:
			interact(point)

func _select_plot(index: int) -> void:
	selected=index
	tool="inspect"
	scene.select_plot(index)
	ui.select_plot(index)

func interact(point: Vector3) -> void:
	if desktop.locked:
		return
	var index=scene.plot_at(point)
	_select_plot(-1 if index==selected else index)

func valid_decoration_position(p: Vector3) -> bool:
	if not Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),scene.outline(true)):
		return false
	if absf(p.x)>8.2 or absf(p.z)>5.7 or scene.plot_at(p)>=0:
		return false
	if p.x>-6 and p.x<-.7 and p.z<-1.5:
		return false
	for item in state.data.decorations:
		if Vector2(p.x,p.z).distance_to(Vector2(item.x,item.z))<.65:
			return false
	return true

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST and not shutting_down:
		shutting_down=true
		if save_manager!=null and ui!=null:
			save_farm(false)
		if desktop!=null:
			desktop.command("quit")
		get_tree().quit()
	elif what==NOTIFICATION_APPLICATION_RESUMED and state!=null:
		state.settle(Time.get_unix_time_from_system())
		_environment()
	elif what==NOTIFICATION_WM_SIZE_CHANGED and scene!=null:
		_fit_illustrated_view.call_deferred()

func _capture() -> void:
	if "--capture-wide" in OS.get_cmdline_user_args():
		DisplayServer.window_set_size(Vector2i(1920,1080))
		set_camera(0,false)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-weather="):
			scene.preview_temperature=-6.0 if int(arg.get_slice("=",1)) in [71,73,75] else 20.0
			scene.update_environment(solar_now(),int(arg.get_slice("=",1)),int(settings.data.effects))
			scene.environment_controller.advance(35.0)
			scene._apply_environment()
	if "--panel-capture" in OS.get_cmdline_user_args():
		set_tool("inspect")
		interact(IllustratedCourtyard.plot_position(9))
	await get_tree().create_timer(3.0).timeout
	print("CAPTURE VIEW: size=",scene.camera.size," weather=",scene.weather_type," snow=",scene.snow_instances.visible," budget=",scene.snow_instances.multimesh.visible_instance_count," amount=",scene.snow_material.get_shader_parameter("amount")," mode=",scene.snow_material.get_shader_parameter("snow_mode"))
	if "--art-only" in OS.get_cmdline_user_args():
		ui.normal.hide()
		ui.toast_panel.hide()
	if "--settings-capture" in OS.get_cmdline_user_args():
		ui.open_settings()
		await get_tree().process_frame
	if "--test-panel-capture" in OS.get_cmdline_user_args():
		_open_environment_test()
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if "--test-panel-capture" in OS.get_cmdline_user_args():
		environment_test_window.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://build/environment-test-panel.png"))
	var path=ProjectSettings.globalize_path("res://build/settings.png" if "--settings-capture" in OS.get_cmdline_user_args() else "res://build/preview.png")
	var captured=ui.settings_window.get_texture().get_image() if "--settings-capture" in OS.get_cmdline_user_args() else get_viewport().get_texture().get_image()
	captured.save_png(path)
	print("CAPTURE: ",path)
	get_tree().quit()

func _desktop_test() -> void:
	await get_tree().create_timer(2.0).timeout
	var identity=state.data.id
	var original_size=DisplayServer.window_get_size()
	var original_camera=scene.camera.transform
	desktop.enter()
	for i in 30:
		await get_tree().create_timer(.3).timeout
		if desktop.desktop and desktop.locked:
			break
	if not desktop.desktop or not desktop.locked:
		push_error("DESKTOP TEST FAILED: enter")
		get_tree().quit(1)
		return
	print("DESKTOP locked: ",DisplayServer.window_get_size()," original: ",original_size)
	var output=[]
	OS.execute(desktop.bridge_path(),["--inspect",str(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))],output)
	print("NATIVE INSPECT: ",output)
	var locked_info=str(output[0])
	var parent_id=locked_info.get_slice("Parent=",1).get_slice(" ",0)
	assert(parent_id!="0" and parent_id==locked_info.get_slice("ExpectedWorker=",1).get_slice(" ",0),"Attached to wallpaper layer")
	var physical=DisplayServer.window_get_size()
	assert(physical==DisplayServer.screen_get_size(int(settings.data.monitor)),"Wallpaper covers the physical monitor resolution, including high-DPI 2K")
	var canvas=get_viewport().get_visible_rect().size
	assert(absf(float(physical.x)/physical.y-canvas.x/canvas.y)<.005,"Canvas expands across entire monitor without letterboxing")
	assert(not ui.normal.visible,"Toolbar hidden on lock")
	assert(not ui.lock_hint.visible and scene.camera.transform==original_camera,"No lock UI and camera retained")
	var plot_before=state.data.plots[9].duplicate(true)
	tool="plant"
	interact(IllustratedCourtyard.plot_position(9))
	assert(state.data.plots[9].crop==plot_before.crop,"Locked click blocked")
	# Exercise the same native commands issued by the tray controller.
	desktop.command("unlock")
	for i in 20:
		await get_tree().create_timer(.3).timeout
		if not desktop.locked:
			break
	if desktop.locked:
		push_error("DESKTOP TEST FAILED: tray unlock")
		get_tree().quit(1)
		return
	assert(ui.normal.visible,"Toolbar restored after unlock")
	assert(scene.camera.transform==original_camera,"Unlock preserves camera")
	print("DESKTOP unlocked: ",DisplayServer.window_get_size())
	output.clear()
	OS.execute(desktop.bridge_path(),["--inspect",str(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))],output)
	print("UNLOCKED NATIVE INSPECT: ",output)
	assert(str(output[0]).get_slice("Parent=",1).get_slice(" ",0)==parent_id,"Unlock stays in the same desktop layer")
	assert(DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_FULLSCREEN,"Unlock never enters fullscreen")
	assert(DisplayServer.window_get_size()==physical,"Lock/unlock preserves monitor coverage")
	assert(FileAccess.get_file_as_string(desktop.ipc.path_join("input-status")).contains("Hook=True Icons=True"),"Desktop input hook and icon exclusion available")
	selected=-1
	tool="inspect"
	var projected=scene.camera.unproject_position(IllustratedCourtyard.plot_position(9))
	var native_point=projected*Vector2(physical)/canvas
	desktop.command("test-input|%d|%d" % [native_point.x,native_point.y])
	await get_tree().create_timer(.6).timeout
	assert(selected==9,"Unfocused wallpaper renderer receives forwarded plot click")
	await RenderingServer.frame_post_draw
	assert(ui.context_panel.get_global_rect().position.x>canvas.x*.5,"Plant panel stays on the right")
	var button_clicks=[0]
	for key in ui.crop_buttons:
		var seed_button: Button=ui.crop_buttons[key]
		seed_button.pressed.connect(func(): button_clicks[0]+=1)
		var point=seed_button.get_global_rect().get_center()*Vector2(physical)/canvas
		var expected=button_clicks[0]+5
		desktop.command("test-input|%d|%d|5" % [point.x,point.y])
		for attempt in 30:
			await get_tree().create_timer(.1).timeout
			if button_clicks[0]>=expected:
				break
		if button_clicks[0]!=expected:
			push_error("DESKTOP GUI FAILED: %s delivered %d / %d" % [key,button_clicks[0],expected])
			get_tree().quit(1)
			return
	assert(button_clicks[0]==ui.crop_buttons.size()*5,"All rapid seed button clicks delivered")
	print("DESKTOP GUI PASS: ",button_clicks[0]," queued seed button clicks; right-side panel")
	for cycle in 3:
		desktop.command("lock")
		await get_tree().create_timer(.4).timeout
		desktop.command("unlock")
		await get_tree().create_timer(.4).timeout
	if not FileAccess.get_file_as_string(desktop.ipc.path_join("input-status")).strip_edges().ends_with("Attachments=1"):
		push_error("DESKTOP FAILED: repeated lock/unlock reattached the window")
		get_tree().quit(1)
		return
	desktop.command("lock")
	for i in 20:
		await get_tree().create_timer(.3).timeout
		if desktop.locked:
			break
	assert(desktop.locked,"Tray relock")
	desktop.command("browse")
	for i in 20:
		await get_tree().create_timer(.3).timeout
		if not desktop.desktop:
			break
	if desktop.desktop or state.data.id!=identity:
		push_error("DESKTOP TEST FAILED: return or farm identity")
		get_tree().quit(1)
		return
	print("DESKTOP TEST PASS: locked, click prevention, tray unlock/relock/return, same farm, restored size ",DisplayServer.window_get_size())
	get_tree().quit()

func _test_location_command(command: String) -> void:
	FileAccess.open(control_dir.path_join("command"),FileAccess.WRITE).store_string(str(Time.get_ticks_usec())+"|"+command)
	_control_tick()

func _integration() -> void:
	await get_tree().create_timer(1.0).timeout
	var before=state.data.duplicate(true)
	state.data.plots[8].crop=""
	set_tool("plant")
	interact(IllustratedCourtyard.plot_position(8))
	assert(state.data.plots[8].crop==crop,"Plant interaction")
	state.data.plots[8].growth=FarmState.CROPS[crop].duration
	set_tool("harvest")
	interact(IllustratedCourtyard.plot_position(8))
	assert(state.data.plots[8].health=="harvested","Harvest leaves residue")
	state.clear_dead(8)
	for i in CAMERA_VIEWS.size():
		set_camera(i,false)
		assert(scene.camera.size==CAMERA_VIEWS[i].size,"Camera preset")
	var before_scenery=state.data.duplicate(true)
	set_tool("inspect")
	interact(scene.boat_model.position)
	assert(state.data==before_scenery and selected<0 and not ui.context_panel.visible,"Decorative boat has no gameplay or growth action")
	ui.open_settings()
	assert(ui.settings_overlay.visible,"Settings open")
	ui.settings_overlay.hide()
	ui.settings_window.hide()
	change_setting("province_code","44")
	assert(ui.setting_controls.city_code["values"].has("4403") and ui.setting_controls.city_code["values"].size()>2,"Complete province/city hierarchy")
	ui.setting_controls.city_code.node.item_selected.emit(ui.setting_controls.city_code["values"].find("4403"))
	assert(settings.data.city_code=="4403" and ui.setting_controls.county_code["values"].has("440305"),"Dynamic city/county option callback")
	change_setting("county_code","330106")
	var saved_control_dir=control_dir
	control_dir="user://county-control-test"
	DirAccess.make_dir_recursive_absolute(control_dir)
	var fix_time=Time.get_unix_time_from_system()
	var test_county=RegionCatalog.get_region("330106")
	settings.data.location_mode="auto"
	_test_location_command("location|%s|%s|100000|%s|%s" % [test_county.lat,test_county.lon,fix_time,fix_time])
	assert(str(settings.data.location_notice).contains("IP"),"Coarse system position initiates IP fallback")
	_test_location_command("location-ip|%s|%s|%s|%s" % [test_county.lat,test_county.lon,fix_time,fix_time])
	assert(settings.data.location_source=="ip","IP command applies estimated county")
	change_setting("county_code","440305")
	_test_location_command("location-failed|"+str(fix_time))
	assert(settings.data.county_code=="440305" and settings.data.location_mode=="manual","Late failure cannot replace manual county")
	settings.data.location_mode="auto"
	_test_location_command("location-failed|"+str(Time.get_unix_time_from_system()+1))
	assert(settings.data.county_code=="110101" and settings.data.location_source=="default","All-provider failure selects Beijing")
	change_setting("county_code","330106")
	DirAccess.remove_absolute(control_dir.path_join("command"))
	DirAccess.remove_absolute(control_dir)
	control_dir=saved_control_dir
	set_tool("inspect")
	assert(scene.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"Fixed orthographic camera")
	ui.show_collection()
	assert(ui.collection_window.visible,"Collection opened")
	ui.collection_window.hide()
	interact(IllustratedCourtyard.plot_position(17))
	assert(selected==17,"Right-hand bed is a regular crop plot")
	_action("primary",null)
	assert(state.data.plots[17].crop=="corn","Corn planting on former orchard bed")
	_action("water",null)
	assert(state.data.plots[17].water_mm>0,"Watering through UI action")
	state.data.plots[17].growth=FarmState.CROPS.corn.duration
	ui.refresh()
	_action("primary",null)
	assert(state.data.plots[17].health=="harvested","Harvest keeps the configured residue")
	ui.show_collection()
	assert(ui.inventory_grid.get_child_count()>=1,"Inventory displays configured crop cells")
	_open_environment_test()
	set_camera(0,false)
	assert(selected==-1 and ui.selection==-1 and not ui.context_panel.visible,"Overview clears plot selection and context panel")
	assert(not ui.settings_window.visible and not ui.collection_window.visible and not environment_test_window.visible,"Overview collapses all auxiliary panels")
	print("OVERVIEW UI PASS: selection and all panels collapse")
	state.data=before
	save_farm(false)
	print("INTEGRATION PASS: planting, harvest, 3 fixed orthographic cameras, crop focus, independent settings, collection, save")
	get_tree().quit()

func _energy_test() -> void:
	await get_tree().create_timer(3.0).timeout
	var identity=state.data.id
	for preset_name in ["节能优先","均衡","高画质"]:
		change_setting("preset",preset_name)
		await get_tree().create_timer(5.0).timeout
		var expected=SettingsManager.PRESETS[preset_name]
		if Engine.max_fps!=expected.fps or not is_equal_approx(get_viewport().scaling_3d_scale,expected.scale):
			push_error("ENERGY TEST FAILED preset "+preset_name)
			get_tree().quit(1)
			return
		print("ENERGY preset ",preset_name," cap=",Engine.max_fps," measured=",performance_manager.measured_fps," scale=",get_viewport().scaling_3d_scale)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	await get_tree().create_timer(4.0).timeout
	if RenderingServer.render_loop_enabled or Engine.max_fps!=2:
		push_error("ENERGY TEST FAILED minimize")
		get_tree().quit(1)
		return
	print("ENERGY minimized: render_loop=",RenderingServer.render_loop_enabled," cap=",Engine.max_fps)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await get_tree().create_timer(3.0).timeout
	if not RenderingServer.render_loop_enabled or state.data.id!=identity:
		push_error("ENERGY TEST FAILED restore")
		get_tree().quit(1)
		return
	change_setting("preset","均衡")
	print("ENERGY TEST PASS: presets, frame caps, resolution, minimize rendering stop, restore, same farm")
	get_tree().quit()

func _benchmark_tick() -> void:
	benchmark_samples.append({"second":elapsed_ticks,"cap":Engine.max_fps,"fps":performance_manager.measured_fps,"process_ms":performance_manager.render_ms,"memory_mb":OS.get_static_memory_usage()/1048576.0,"nodes":get_tree().get_node_count(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
	if elapsed_ticks>=(12 if "--profile-v2" in OS.get_cmdline_user_args() else 65):
		var file=FileAccess.open("res://build/benchmark-%s.json" % RenderingServer.get_current_rendering_method(),FileAccess.WRITE)
		file.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"resolution":DisplayServer.window_get_size(),"scale_3d":get_viewport().scaling_3d_scale,"preset":settings.data.preset,"samples":benchmark_samples},"\t"))
		file.close()
		print("BENCHMARK COMPLETE")
		get_tree().quit()


func _environment_test() -> void:
	await get_tree().create_timer(.5).timeout
	var before=state.data.duplicate(true)
	var temperature=state.temperature
	var cache=weather.cache.duplicate(true)
	_open_environment_test()
	environment_test_window.hour_control.value=22.5
	environment_test_window.weather_control.select(EnvironmentTestWindow.CODES.find(71))
	environment_test_window.temperature_control.value=-8
	environment_test_window.apply_preview()
	environment_test_window.crop_control.select(5)
	environment_test_window.crop_control.item_selected.emit(5)
	assert(scene.get("crop_preview")==4 and state.data==before,"Tree appearance preview never changes saved growth")
	assert(solar_now().date.hour==22 and solar_now().date.minute==30,"Preview local time")
	assert(scene.weather_type=="snow" and scene.preview_temperature==-8,"Weather and temperature preview")
	assert(state.temperature==temperature and state.data==before and weather.cache==cache,"Preview never changes growth or weather cache")
	assert(ui.camera_buttons.size()==1 and ui.camera_buttons[0].text=="全景","Single overview control")
	assert(not ui.footer.visible and not ui.save_button.is_visible_in_tree(),"Desktop chrome removed")
	environment_test_window.close_requested.emit()
	assert(environment_preview.is_empty() and scene.preview_temperature==null,"Close restores live environment")
	assert(scene.get("crop_preview")==-1,"Close restores real tree growth visuals")
	if "--capture" in OS.get_cmdline_user_args():
		return
	print("ENVIRONMENT TEST PASS: time, weather, visual temperature, isolated farm/cache, live restore, minimal desktop UI")
	get_tree().quit()

func _retire_map_scene(previous: Node) -> void:
	# Keep shared textures/shaders alive until the replacement has rendered.
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(previous): previous.queue_free()

func _open_crop_editor() -> void:
	CropEditorStore.active_farm=state
	if is_instance_valid(crop_editor):
		crop_editor.popup_centered()
		_sync_editor_activity()
		return
	save_farm(false)
	crop_editor=CropEditorWindow.new()
	get_tree().root.add_child(crop_editor)
	crop_editor.initialize(ui.root.theme)
	crop_editor.visibility_changed.connect(_sync_editor_activity)
	crop_editor.catalog_changed.connect(func():
		scene.crop_preview={}
		if is_instance_valid(environment_test_window):
			environment_test_window.queue_free()
			environment_test_window=null
		state.settle(Time.get_unix_time_from_system())
		ContentCatalog.crops.clear()
		ContentCatalog.package_dirs.clear()
		ContentCatalog.load_catalog()
		if not ContentCatalog.crops.has(crop): crop=str(ContentCatalog.crops.keys()[0]) if not ContentCatalog.crops.is_empty() else ""
		ui.reload_crop_buttons()
		scene.refresh(true)
		ui.refresh())
	crop_editor.popup_centered()
	_sync_editor_activity()
