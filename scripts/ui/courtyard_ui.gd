class_name CourtyardUI
extends FarmUI

var context_panel: PanelContainer
var collection_window: Window
var settings_window: Window
var main_button: Button
var collection_text: RichTextLabel
var inventory_grid: GridContainer
var inventory_details: Label
var export_dialog: FileDialog
var water_button: Button
var operation_buttons={}
var locked_info: Control
var locked_location: Label
var locked_weather: Label
var toolbar: PanelContainer
var seed_picker: PanelContainer
var crop_logo: TextureRect
var crop_description: Label
var crop_description_scroll: ScrollContainer
var moisture_progress: ProgressBar
var growth_value: Label
var moisture_value: Label
var shown_crop=""
var region=""
var export_crop_id="corn"
var exporting_crop_id="corn"
var hud_unlocked=false
var hud_controls={}
var hud_drag_key=""
var hud_drag_offset=Vector2.ZERO
var wallpaper_hover: BaseButton

# Store positions as fractions of the available viewport so changing resolution
# keeps both HUD elements on-screen. Only the explicit handle starts tool dragging.
func _hud_grip(parent: Node) -> TextureRect:
	var grip=TextureRect.new()
	grip.texture=load("res://assets/icons/hud-grip.svg")
	grip.custom_minimum_size=Vector2(16,24)
	grip.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	grip.stretch_mode=TextureRect.STRETCH_KEEP_CENTERED
	grip.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	parent.add_child(grip)
	return grip

func _position_seed_picker() -> void:
	if seed_picker==null or context_panel==null: return
	var point=context_panel.position+Vector2(0,context_panel.size.y+12)
	if point.y+seed_picker.size.y>root.size.y:
		point.y=context_panel.position.y-seed_picker.size.y-12
	seed_picker.set_anchors_preset(Control.PRESET_TOP_LEFT)
	seed_picker.position=point.clamp(Vector2.ZERO,(root.size-seed_picker.size).max(Vector2.ZERO))

func _register_hud(key: String,target: Control,handle: Control) -> void:
	hud_controls[key]=target
	handle.mouse_filter=Control.MOUSE_FILTER_STOP
	handle.mouse_default_cursor_shape=Control.CURSOR_DRAG
	handle.tooltip_text="拖动调整位置，松开保存。"
	handle.gui_input.connect(func(event):
		if not hud_unlocked: return
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
			hud_drag_key=key
			hud_drag_offset=event.global_position-target.global_position
			var point=target.position
			target.set_anchors_preset(Control.PRESET_TOP_LEFT)
			target.position=point
			handle.accept_event())
	target.resized.connect(func():
		if hud_drag_key!=key: _restore_hud_position.call_deferred(key))
	get_viewport().size_changed.connect(func(): _restore_hud_position.call_deferred(key))
	_restore_hud_position.call_deferred(key)

func _restore_hud_position(key: String) -> void:
	if not hud_controls.has(key) or hud_drag_key==key: return
	var target: Control=hud_controls[key]
	var saved: Vector2=prefs.data.get("hud_"+key+"_position",Vector2(-1,-1))
	if saved.x<0 or saved.y<0 or not saved.is_finite(): return
	target.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var extent=(root.size-target.size).max(Vector2.ZERO)
	target.position=saved.clamp(Vector2.ZERO,Vector2.ONE)*extent
	if key=="details": _position_seed_picker()

func _finish_hud_drag() -> void:
	if hud_drag_key.is_empty(): return
	var target: Control=hud_controls[hud_drag_key]
	var extent=(root.size-target.size).max(Vector2.ONE)
	prefs.data["hud_"+hud_drag_key+"_position"]=(target.position/extent).clamp(Vector2.ZERO,Vector2.ONE)
	prefs.save()
	hud_drag_key=""

func _input(event: InputEvent) -> void:
	if hud_drag_key.is_empty(): return
	if event is InputEventMouseMotion:
		var target: Control=hud_controls[hud_drag_key]
		target.position=(event.position-hud_drag_offset-root.global_position).clamp(Vector2.ZERO,(root.size-target.size).max(Vector2.ZERO))
		if hud_drag_key=="details": _position_seed_picker()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_hud_drag()
		get_viewport().set_input_as_handled()

func set_wallpaper_pointer(point: Vector2) -> void:
	var target: BaseButton=null
	if normal.is_visible_in_tree():
		for node in normal.find_children("*","BaseButton",true,false):
			if node.is_visible_in_tree() and not node.disabled and node.get_global_rect().has_point(point):
				target=node
	if is_instance_valid(wallpaper_hover) and wallpaper_hover!=target and wallpaper_hover.is_hovered():
		wallpaper_hover.notification(Control.NOTIFICATION_MOUSE_EXIT)
	wallpaper_hover=target
	if target!=null and not target.is_hovered():
		target.notification(Control.NOTIFICATION_MOUSE_ENTER)

func style(hex: String, radius: int=14, padding: int=20) -> StyleBoxFlat:
	var s=super.style(hex,radius,padding)
	s.bg_color.a=.94
	s.border_color=Color("b4a88a")
	s.set_border_width_all(1)
	s.shadow_color=Color(0.04,.08,.06,.18)
	s.shadow_size=2 if padding<=12 else 10
	s.shadow_offset=Vector2(0,4)
	return s

func _build_header() -> void:
	# Keep update targets off the desktop; settings and collection live in the tray.
	var hidden=Control.new()
	normal.add_child(hidden)
	hidden.hide()
	clock_label=label(hidden,"")
	weather_label=label(hidden,"")
	weather_status=label(hidden,"")
	save_button=Button.new()
	hidden.add_child(save_button)
	desktop_button=Button.new()
	hidden.add_child(desktop_button)
	locked_info=Control.new()
	root.add_child(locked_info)
	anchor(locked_info,Control.PRESET_TOP_RIGHT,Vector2(-294,22),Vector2(270,48))
	var info=VBoxContainer.new()
	info.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	info.add_theme_constant_override("separation",2)
	locked_info.add_child(info)
	locked_location=label(info,"正在获取位置…",12)
	locked_weather=label(info,"正在获取天气…",11)
	for text_label in [locked_location,locked_weather]:
		text_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		text_label.add_theme_color_override("font_shadow_color",Color(0,0,0,.40))
		text_label.add_theme_constant_override("shadow_offset_x",0)
		text_label.add_theme_constant_override("shadow_offset_y",1)
		text_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	for node in [locked_info,info,locked_location,locked_weather]:
		node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_register_hud("weather",locked_info,locked_info)
	locked_info.hide()

func update_environment(solar: Dictionary,weather: WeatherService) -> void:
	super.update_environment(solar,weather)
	var ink=Color(.80,.83,.77,.78) if solar.daylight<.4 else Color(.24,.31,.26,.72)
	locked_location.add_theme_color_override("font_color",ink)
	locked_weather.add_theme_color_override("font_color",Color(ink,ink.a*.8))
	locked_location.text=prefs.location_label()+(" · IP 估算" if prefs.data.location_source=="ip" else "")
	var current=weather.current()
	locked_weather.text="天气未联网" if not prefs.data.weather_online else "天气暂不可用"
	if prefs.data.weather_online and not current.is_empty():
		locked_weather.text="%s  %d°C" % [WeatherService.classify(int(current.code)),roundi(current.temperature)]
		if current.has("wind_speed_10m"):
			locked_weather.text+="  风 %.0f km/h" % float(current.wind_speed_10m)
		if Time.get_unix_time_from_system()-float(current.get("fetched",0))>prefs.data.refresh_minutes*60:
			locked_weather.text+=" · 缓存"

func _compact_panel(size: Vector2,offset: Vector2) -> PanelContainer:
	var result=panel(normal,Vector2.ZERO,size,"eee7d4")
	result.add_theme_stylebox_override("panel",style("eee7d4",12,12))
	anchor(result,Control.PRESET_TOP_RIGHT,offset,size)
	return result

func _progress_row(parent: Node,title: String,color: String) -> Dictionary:
	var line=row(parent,6)
	var title_label=label(line,title,11,MUTED)
	title_label.custom_minimum_size.x=30
	var bar=ProgressBar.new()
	bar.show_percentage=false
	bar.custom_minimum_size=Vector2(100,7)
	bar.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("background",style("d9dece",4,0))
	bar.add_theme_stylebox_override("fill",style(color,4,0))
	line.add_child(bar)
	var value=label(line,"0%",11,MUTED)
	value.custom_minimum_size.x=30
	value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	return {"bar":bar,"value":value}

func _build_sidebar() -> void:
	context_panel=_compact_panel(Vector2(232,180),Vector2(-256,154))
	var content=column(context_panel,8)
	var header=row(content,9)
	crop_logo=TextureRect.new()
	crop_logo.custom_minimum_size=Vector2(36,40)
	crop_logo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	crop_logo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crop_logo.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	header.add_child(crop_logo)
	var names=column(header,3)
	names.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	plot_title=label(names,"",14)
	plot_detail=label(names,"",11,MUTED)
	var details_grip=_hud_grip(header)
	details_grip.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for node in [crop_logo,names,plot_title,plot_detail]: node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_register_hud("details",context_panel,header)
	var growth=_progress_row(content,"成长","83a55c")
	plot_progress=growth.bar
	growth_value=growth.value
	var moisture=_progress_row(content,"水分","6cabc3")
	moisture_progress=moisture.bar
	moisture_value=moisture.value
	stats=label(content,"",10,MUTED)
	stats.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	crop_description_scroll=ScrollContainer.new()
	crop_description_scroll.custom_minimum_size.y=112
	crop_description_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(crop_description_scroll)
	crop_description=label(crop_description_scroll,"",11,INK)
	crop_description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	crop_description.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	context_panel.hide()

func _build_dock() -> void:
	toolbar=_compact_panel(Vector2(198,62),Vector2(-222,82))
	toolbar.add_theme_stylebox_override("panel",style("eee7d4",12,7))
	var tools=row(toolbar,7)
	var drag_handle=_hud_grip(tools)
	_register_hud("tools",toolbar,drag_handle)
	for spec in [{"id":"harvest","icon":"shovel","tip":"收获当前田块／清理枯株"},{"id":"plant","icon":"backpack","tip":"为当前田块选择种子"},{"id":"water","icon":"watering","tip":"给当前田块浇水"}]:
		var key=str(spec.id)
		var b=button(tools,"",func():
			if key=="plant":
				seed_picker.visible=not seed_picker.visible
				_position_seed_picker.call_deferred()
			else:
				action.emit("harvest_selected" if key=="harvest" else "water",null),38)
		b.custom_minimum_size=Vector2(48,46)
		for visual in {"normal":"edf0e3","hover":"dbe4cd","pressed":"4e6b50","disabled":"dedfd3"}:
			b.add_theme_stylebox_override(visual,style({"normal":"edf0e3","hover":"dbe4cd","pressed":"4e6b50","disabled":"dedfd3"}[visual],10,6))
		b.icon=load("res://assets/icons/farm-tools/"+str(spec.icon)+".png")
		b.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
		b.expand_icon=true
		b.add_theme_constant_override("icon_max_width",36)
		b.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		b.tooltip_text=spec.tip
		operation_buttons[key]=b
	toolbar.hide()
	seed_picker=_compact_panel(Vector2(232,112),Vector2(-256,280))
	context_panel.resized.connect(func(): _position_seed_picker.call_deferred())
	seed_picker.resized.connect(_position_seed_picker)
	var seeds=GridContainer.new()
	seeds.columns=4
	seeds.add_theme_constant_override("h_separation",6)
	seed_picker.add_child(seeds)
	for key in FarmState.CROPS:
		var b=button(seeds,"",func(): action.emit("plant_selected",key),40)
		b.custom_minimum_size=Vector2(40,40)
		b.icon=ContentCatalog.icon(key)
		b.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
		b.expand_icon=true
		b.add_theme_constant_override("icon_max_width",30)
		b.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		b.tooltip_text=FarmState.CROPS[key].name
		b.tooltip_text=ContentCatalog.description(key)
		var badge=str(FarmState.CROPS[key].get("sowing",{}).get("badge",""))
		if not badge.is_empty():
			var mark=label(b,badge,9,Color("f6f0da"))
			mark.position=Vector2(27,22)
			mark.mouse_filter=Control.MOUSE_FILTER_IGNORE
			mark.add_theme_color_override("font_shadow_color",Color("304535"))
			mark.add_theme_constant_override("shadow_offset_x",1)
			mark.add_theme_constant_override("shadow_offset_y",1)
		crop_buttons[key]=b
	seed_picker.hide()
	hint=label(normal,"")
	hint.hide()

func _build_footer() -> void:
	footer=label(normal,"")
	mode_label=label(normal,"")
	footer.hide()
	mode_label.hide()

func _build_lock_hint() -> void:
	lock_hint=PanelContainer.new()
	root.add_child(lock_hint)
	lock_hint.hide()

func select_plot(index: int) -> void:
	selection=index
	region=""
	seed_picker.hide()
	refresh()

func refresh() -> void:
	var active=selection>=0 and selection<state.data.plots.size()
	context_panel.visible=active
	toolbar.visible=active
	if not active:
		seed_picker.hide()
		return
	var plot=state.data.plots[selection]
	var occupied=FarmState.CROPS.has(plot.crop)
	for key in crop_buttons:
		crop_buttons[key].disabled=occupied
		crop_buttons[key].tooltip_text=ContentCatalog.description(key)+("\n请先清理当前作物" if occupied else "\n种植到 %02d 号田" % (selection+1))
	operation_buttons.plant.disabled=occupied
	operation_buttons.harvest.disabled=not occupied or (not state.harvestable(plot) and not plot.health in ["dead","harvested"])
	operation_buttons.water.disabled=not occupied
	plot_title.text="%02d 号田 · %s" % [selection+1,FarmState.CROPS[plot.crop].name if occupied else "空闲"]
	crop_logo.visible=occupied
	crop_description_scroll.visible=occupied
	context_panel.tooltip_text=""
	crop_logo.tooltip_text=""
	if shown_crop!=plot.crop:
		shown_crop=plot.crop
		crop_logo.texture=ContentCatalog.icon(plot.crop) if occupied else null
	if not occupied:
		crop_description.text=""
		context_panel.tooltip_text=""
		plot_detail.text="可播种"
		plot_progress.value=0
		moisture_progress.value=0
		growth_value.text="—"
		moisture_value.text="—"
		stats.text="通过背包选择种子"
		return
	var config=FarmState.CROPS[plot.crop]
	var description=ContentCatalog.description(plot.crop)
	if crop_description.text!=description:
		crop_description.text=description
		crop_description_scroll.scroll_vertical=0
	var stage=config.stages[state.stage(plot)]
	plot_detail.text={"dead":"已枯死","harvested":"收获后枯株"}.get(plot.health,stage.name+(" · 缺水" if plot.health=="wilted" else ""))
	if plot.health=="harvested" and float(plot.get("post_harvest_seconds",0))<float(config.harvest.get("residue_delay_seconds",0)):
		plot_detail.text="已摘取"
	if plot.health=="wilted" and plot.get("temperature_wilted",false):
		plot_detail.text=stage.name+" · 温度不适"
	plot_progress.value=state.progress(plot)*100
	moisture_progress.value=clampf(plot.water_mm/config.watering.capacity_mm*100,0,100)
	growth_value.text="%d%%" % roundi(plot_progress.value)
	moisture_value.text="%d%%" % roundi(moisture_progress.value)
	var inactive=plot.health in ["dead","harvested"]
	var growth_color="a8947d" if inactive else ("d8ae59" if state.harvestable(plot) else "83a55c")
	var water_color="a8947d" if inactive else ("d49a59" if plot.water_mm<=config.watering.warning_mm else "6cabc3")
	plot_progress.add_theme_stylebox_override("fill",style(growth_color,4,0))
	moisture_progress.add_theme_stylebox_override("fill",style(water_color,4,0))
	moisture_progress.tooltip_text="土壤储水 %.1f / %.0f mm" % [plot.water_mm,config.watering.capacity_mm]
	operation_buttons.water.disabled=inactive or plot.water_mm>=config.watering.capacity_mm
	operation_buttons.harvest.tooltip_text="清理当前田块的枯株" if inactive else "收获当前田块"
	stats.text="清理后可重新播种" if inactive else ("已成熟，可以采收" if state.harvestable(plot) else "正常供水下约 "+duration_text(maxf(0,config.duration-plot.growth))+" 后成熟")
	var climate=config.get("temperature",{})
	if not climate.is_empty():
		var limits=stage.get("temperature",climate)
		if stage.get("id","")=="seed":
			limits={"min_c":climate.sowing_min_c,"max_c":climate.sowing_max_c}
		stats.text+="\n本阶段适温 %.1f–%.1f°C" % [limits.min_c,limits.max_c]

func set_tool(_value: String) -> void:
	selected_tool="inspect"
	refresh()

func set_desktop(_desktop: bool, locked: bool) -> void:
	normal.visible=not locked
	hud_unlocked=not locked
	if locked and not hud_drag_key.is_empty(): _finish_hud_drag()
	locked_info.visible=true
	locked_info.mouse_filter=Control.MOUSE_FILTER_STOP if hud_unlocked else Control.MOUSE_FILTER_IGNORE
	lock_hint.hide()
	toast_panel.hide()
	if locked and settings_window!=null:
		settings_overlay.hide()
		settings_window.hide()

func toast(text: String) -> void:
	if normal.visible:
		super.toast(text)

func open_settings() -> void:
	if settings_window==null:
		settings_window=Window.new()
		settings_window.title="苔屿 · 设置"
		settings_window.size=Vector2i(720,830)
		settings_window.min_size=Vector2i(680,800)
		settings_window.theme=root.theme
		get_tree().root.add_child(settings_window)
		settings_overlay.reparent(settings_window)
		settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		settings_window.close_requested.connect(func():
			settings_overlay.hide()
			settings_window.hide())
	sync_settings()
	settings_overlay.show()
	if DisplayServer.get_name()=="headless":
		settings_window.show()
	else:
		settings_window.popup_centered()

func _build_settings() -> void:
	super._build_settings()
	var heading=settings_overlay.find_children("*","VBoxContainer",true,false)[0]
	var map_button=button(heading,"场景项目 · 新建与编辑地图",func(): action.emit("map_editor",null),280)
	heading.move_child(map_button,2)
	button(heading,"作物编辑器 · 新增与编辑植物",func(): action.emit("crop_editor",null),280)
	for node in settings_overlay.find_children("*","Button",true,false):
		if node.text=="完成":
			for connection in node.pressed.get_connections():
				node.pressed.disconnect(connection.callable)
			node.pressed.connect(func():
				settings_overlay.hide()
				if settings_window!=null:
					settings_window.hide())

func sync_settings() -> void:
	if setting_controls.has("county_code"):
		var levels={"province_code":RegionCatalog.provinces,"city_code":RegionCatalog.child_regions(str(prefs.data.province_code)),"county_code":RegionCatalog.child_regions(str(prefs.data.city_code))}
		for key in levels:
			var item=setting_controls[key]
			item["values"]=[]
			item.node.clear()
			for region_item in levels[key]:
				item["values"].append(str(region_item.code))
				item.node.add_item(str(region_item.name))
	super.sync_settings()
	if is_instance_valid(location_status):
		var sources={"gps":"系统定位","ip":"IP 估算","default":"默认地点","manual":"手动区县"}
		location_status.text=str(sources.get(prefs.data.location_source,"默认地点"))+" · "+RegionCatalog.path_label(str(prefs.data.county_code))+"\n经纬度 %.5f, %.5f" % [prefs.location().lon,prefs.location().lat]
		if prefs.data.location_source=="gps":
			location_status.text+=" · 定位精度约 %d 米" % roundi(prefs.data.location_accuracy)
		if not str(prefs.data.location_notice).is_empty():
			location_status.text+="\n"+str(prefs.data.location_notice)

func show_collection() -> void:
	if collection_window==null:
		collection_window=Window.new()
		collection_window.title="苔屿 · 仓库"
		collection_window.size=Vector2i(560,800)
		collection_window.theme=root.theme
		get_tree().root.add_child(collection_window)
		collection_window.close_requested.connect(func(): collection_window.hide())
		var p=panel(collection_window,Vector2.ZERO,Vector2(560,800),"eee7d4")
		p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var v=column(p,12)
		label(v,"仓库",24)
		label(v,"收获自动入库 · 数量显示在格子右下角",13,MUTED)
		inventory_grid=GridContainer.new()
		inventory_grid.columns=4
		inventory_grid.add_theme_constant_override("h_separation",10)
		inventory_grid.add_theme_constant_override("v_separation",10)
		v.add_child(inventory_grid)
		var details_scroll=ScrollContainer.new()
		details_scroll.custom_minimum_size=Vector2(0,170)
		details_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		v.add_child(details_scroll)
		inventory_details=label(details_scroll,"点击物品格子查看生长周期、温度、播期与产量。",12,MUTED)
		inventory_details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		inventory_details.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var export_row=HBoxContainer.new()
		export_row.add_theme_constant_override("separation",10)
		v.add_child(export_row)
		var species=OptionButton.new()
		var crop_ids=FarmState.CROPS.keys()
		for id in crop_ids:
			species.add_item(FarmState.CROPS[id].name)
		species.item_selected.connect(func(index): export_crop_id=str(crop_ids[index]))
		export_crop_id=str(crop_ids[0]) if not crop_ids.is_empty() else ""
		export_row.add_child(species)
		button(export_row,"导出所选作物包…",_export_crop_dialog,220)
		label(v,"作物包包含完整配置及原始图集。\n更改程序旁 crops/对应作物/crop.json 后重启生效。",12,MUTED)
	for child in inventory_grid.get_children():
		child.free()
	var keys=FarmState.CROPS.keys()
	for i in maxi(12,keys.size()):
		var cell=PanelContainer.new()
		cell.custom_minimum_size=Vector2(112,112)
		cell.add_theme_stylebox_override("panel",style("e3e7d8",10,6))
		inventory_grid.add_child(cell)
		if i>=keys.size():
			continue
		var key=keys[i]
		var config=FarmState.CROPS[key]
		var count=int(state.data.collection.crops.get(key,{}).get("count",0))
		cell.tooltip_text="%s · %d %s" % [config.name,count,config.harvest.unit]
		cell.tooltip_text+="\n"+ContentCatalog.description(key)
		cell.mouse_filter=Control.MOUSE_FILTER_STOP
		cell.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
				inventory_details.text=ContentCatalog.description(key))
		var surface=Control.new()
		surface.mouse_filter=Control.MOUSE_FILTER_IGNORE
		surface.custom_minimum_size=Vector2(100,100)
		cell.add_child(surface)
		var image=TextureRect.new()
		image.mouse_filter=Control.MOUSE_FILTER_IGNORE
		image.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		image.texture=ContentCatalog.icon(key)
		image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var size=72.0*float(config.assets[config.icon].scale)
		image.size=Vector2(size,size)
		image.position=(Vector2(100,100)-image.size)*.5
		surface.clip_contents=true
		surface.add_child(image)
		var badge=str(config.get("sowing",{}).get("badge",""))
		if not badge.is_empty():
			var season_label=label(surface,badge+"播",11,MUTED)
			season_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var quantity=label(surface,str(count),18,INK)
		quantity.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		quantity.grow_horizontal=Control.GROW_DIRECTION_BEGIN
		quantity.grow_vertical=Control.GROW_DIRECTION_BEGIN
		quantity.position-=Vector2(4,2)
	if DisplayServer.get_name()=="headless":
		collection_window.show()
	else:
		collection_window.popup_centered()

func _export_crop_dialog() -> void:
	if not FarmState.CROPS.has(export_crop_id):
		return
	exporting_crop_id=export_crop_id
	if export_dialog==null:
		export_dialog=FileDialog.new()
		export_dialog.title="导出作物包"
		export_dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE
		export_dialog.access=FileDialog.ACCESS_FILESYSTEM
		export_dialog.use_native_dialog=true
		export_dialog.filters=PackedStringArray(["*.zip ; 作物包 ZIP"])
		collection_window.add_child(export_dialog)
		export_dialog.file_selected.connect(func(path):
			var error=ContentCatalog.export_crop(exporting_crop_id,path)
			toast("作物包已导出："+path if error==OK else "导出失败，请检查文件位置与写入权限。"))
	export_dialog.current_dir=OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	export_dialog.current_file=str(FarmState.CROPS[exporting_crop_id].name)+".crop.zip"
	export_dialog.popup_centered_ratio(.6)

func reload_crop_buttons() -> void:
	if seed_picker==null: return
	for child in seed_picker.get_children(): child.free()
	crop_buttons.clear()
	var grid=GridContainer.new()
	grid.columns=4
	seed_picker.add_child(grid)
	for key in FarmState.CROPS:
		var b=button(grid,"",func(): action.emit("plant_selected",key),40)
		b.icon=ContentCatalog.icon(key)
		b.expand_icon=true
		b.custom_minimum_size=Vector2(40,40)
		b.add_theme_constant_override("icon_max_width",30)
		b.tooltip_text=ContentCatalog.description(key)
		crop_buttons[key]=b
