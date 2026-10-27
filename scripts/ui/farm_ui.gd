class_name FarmUI
extends CanvasLayer

signal action(name: String, value: Variant)
const INK = Color("304b40")
const MUTED = Color("7b897a")
const CREAM = Color("f8f7ee")
var root: Control
var normal: Control
var settings_overlay: Control
var clock_label: Label
var weather_label: Label
var weather_status: Label
var stats: Label
var plot_title: Label
var plot_detail: Label
var plot_progress: ProgressBar
var hint: Label
var footer: Label
var toast_label: Label
var toast_panel: PanelContainer
var toast_timer: Timer
var mode_label: Label
var lock_hint: PanelContainer
var selected_crop = "corn"
var tool_buttons = {}
var crop_buttons = {}
var save_button: Button
var desktop_button: Button
var prefs: SettingsManager
var state: FarmState
var status_line = ""
var selection = -1
var selected_tool = "inspect"
var setting_controls = {}
var location_status: Label
var rate_label: Label
var camera_buttons = []

func initialize(settings: SettingsManager, farm: FarmState) -> void:
	layer=100
	prefs=settings
	state=farm
	root=Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme=Theme.new()
	var font=SystemFont.new()
	font.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","Noto Sans CJK SC"])
	theme.default_font=font
	theme.default_font_size=16
	theme.set_color("font_color","Label",INK)
	theme.set_color("font_color","Button",INK)
	theme.set_color("font_hover_color","Button",INK)
	theme.set_color("font_pressed_color","Button",Color("f6f4df"))
	theme.set_stylebox("normal","Button",style("edf0e3",10,10))
	theme.set_stylebox("hover","Button",style("dbe4cd",10,10))
	theme.set_stylebox("pressed","Button",style("4e6b50",10,10))
	theme.set_stylebox("focus","Button",StyleBoxEmpty.new())
	theme.set_stylebox("disabled","Button",style("dedfd3",10,10))
	theme.set_color("font_disabled_color","Button",Color("788371"))
	theme.set_color("icon_disabled_color","Button",Color(1,1,1,.48))
	var tooltip_box=style("fff9e9",8,10)
	tooltip_box.bg_color.a=1.0
	tooltip_box.border_color=Color("a49a7b")
	tooltip_box.set_border_width_all(1)
	theme.set_stylebox("panel","TooltipPanel",tooltip_box)
	theme.set_color("font_color","TooltipLabel",Color("263d34"))
	theme.set_color("font_shadow_color","TooltipLabel",Color.TRANSPARENT)
	theme.set_color("font_outline_color","TooltipLabel",Color.TRANSPARENT)
	theme.set_constant("outline_size","TooltipLabel",0)
	theme.set_font_size("font_size","TooltipLabel",13)
	theme.set_stylebox("panel","PopupMenu",style("f8f7ee",12,12))
	theme.set_color("font_color","PopupMenu",INK)
	theme.set_color("font_color_hover","PopupMenu",INK)
	theme.set_stylebox("hover","PopupMenu",style("e1e7d6",6,8))
	theme.set_color("font_color","OptionButton",INK)
	theme.set_stylebox("normal","OptionButton",style("e8eddf",8,10))
	theme.set_stylebox("hover","OptionButton",style("dbe4cd",8,10))
	theme.set_stylebox("focus","OptionButton",StyleBoxEmpty.new())
	theme.set_stylebox("background","ProgressBar",style("e5e8d8",4,0))
	theme.set_stylebox("fill","ProgressBar",style("90a568",4,0))
	root.theme=theme
	normal=Control.new()
	normal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	normal.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(normal)
	_build_header()
	_build_sidebar()
	_build_dock()
	_build_footer()
	_build_lock_hint()
	_build_toast()
	_build_settings()
	set_tool("inspect")
	refresh()

func style(hex: String, radius: int = 16, padding: int = 20) -> StyleBoxFlat:
	var s=StyleBoxFlat.new()
	s.bg_color=Color(hex)
	s.corner_radius_top_left=radius
	s.corner_radius_top_right=radius
	s.corner_radius_bottom_left=radius
	s.corner_radius_bottom_right=radius
	s.content_margin_left=padding
	s.content_margin_right=padding
	s.content_margin_top=padding
	s.content_margin_bottom=padding
	return s

func panel(parent: Node, pos: Vector2, size: Vector2, hex: String = "f8f7ee") -> PanelContainer:
	var p=PanelContainer.new()
	p.position=pos
	p.custom_minimum_size=size
	p.add_theme_stylebox_override("panel",style(hex))
	parent.add_child(p)
	return p

func column(parent: Node, gap: int = 12) -> VBoxContainer:
	var v=VBoxContainer.new()
	v.add_theme_constant_override("separation",gap)
	parent.add_child(v)
	return v

func row(parent: Node, gap: int = 10) -> HBoxContainer:
	var h=HBoxContainer.new()
	h.add_theme_constant_override("separation",gap)
	parent.add_child(h)
	return h

func label(parent: Node, text: String, size: int = 16, color: Color = INK) -> Label:
	var l=Label.new()
	l.text=text
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",color)
	parent.add_child(l)
	return l

func button(parent: Node, text: String, callback: Callable, min_width: float = 0) -> Button:
	var b=Button.new()
	b.text=text
	b.custom_minimum_size=Vector2(min_width,42)
	b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func separator(parent: Node) -> void:
	var line=ColorRect.new()
	line.color=Color("e2e5d7")
	line.custom_minimum_size.y=1
	parent.add_child(line)

func anchor(control: Control, preset: int, offset: Vector2, extent: Vector2) -> void:
	control.set_anchors_preset(preset)
	control.offset_left=offset.x
	control.offset_top=offset.y
	control.offset_right=offset.x+extent.x
	control.offset_bottom=offset.y+extent.y

func _build_header() -> void:
	var brand=VBoxContainer.new()
	brand.position=Vector2(36,28)
	normal.add_child(brand)
	var title_row=row(brand,12)
	label(title_row,"苔屿",36)
	var brand_meta=column(title_row,0)
	label(brand_meta,"M O S S   I S L A N D",12,MUTED)
	label(brand_meta,"桌 面 微 观 农 场",13,MUTED)
	label(brand,"留一方自然，让时间慢慢生长。",15,MUTED)
	var actions=HBoxContainer.new()
	normal.add_child(actions)
	anchor(actions,Control.PRESET_TOP_RIGHT,Vector2(-346,30),Vector2(310,42))
	actions.add_theme_constant_override("separation",10)
	save_button=button(actions,"保存",func(): action.emit("save",null),74)
	desktop_button=button(actions,"桌面陪伴  ↗",func(): action.emit("desktop",null),144)
	button(actions,"设置",func(): open_settings(),72)
	var weather_panel=panel(normal,Vector2.ZERO,Vector2(288,116))
	anchor(weather_panel,Control.PRESET_TOP_RIGHT,Vector2(-324,92),Vector2(288,116))
	var weather_col=column(weather_panel,3)
	clock_label=label(weather_col,"",24)
	weather_label=label(weather_col,"",16)
	weather_status=label(weather_col,"",12,MUTED)

func _build_sidebar() -> void:
	var p=panel(normal,Vector2(36,155),Vector2(248,0))
	var v=column(p,12)
	label(v,"在这座小岛上",12,MUTED)
	stats=label(v,"",17)
	separator(v)
	label(v,"观赏视角",13,MUTED)
	for i in 3:
		var names=["01   农场全景", "02   菜园时光", "03   林间农舍"]
		var b=button(v,names[i],func(): action.emit("camera",i))
		b.alignment=HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode=true
		camera_buttons.append(b)
	separator(v)
	plot_title=label(v,"一块地，一点期待",18)
	plot_detail=label(v,"点击菜园地块，查看生长。",13,MUTED)
	plot_detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	plot_detail.custom_minimum_size.x=204
	plot_progress=ProgressBar.new()
	plot_progress.custom_minimum_size=Vector2(0,6)
	plot_progress.show_percentage=false
	v.add_child(plot_progress)
	var seeds=row(v,6)
	for kind in FarmState.CROPS:
		var b=button(seeds,FarmState.CROPS[kind].name.left(2),func(): action.emit("crop",kind))
		b.tooltip_text=FarmState.CROPS[kind].name
		b.add_theme_font_size_override("font_size",12)
		b.toggle_mode=true
		crop_buttons[kind]=b
	label(v,"无需浇水，也不必赶时间。",12,MUTED)

func _build_dock() -> void:
	var p=panel(normal,Vector2.ZERO,Vector2(680,80))
	anchor(p,Control.PRESET_CENTER_BOTTOM,Vector2(-380,-120),Vector2(760,80))
	var h=row(p,10)
	var names={"inspect":"观赏", "plant":"播种", "harvest":"收获", "flowers":"花丛", "barrel":"木桶"}
	for key in names:
		var b=button(h,names[key],func(): action.emit("tool",key),82)
		b.toggle_mode=true
		tool_buttons[key]=b
	separator(h)
	button(h,"收获全部",func(): action.emit("harvest_all",null),118)
	var undo=button(h,"撤回",func(): action.emit("undo_decoration",null),60)
	undo.tooltip_text="移除最后摆放的装饰物"
	hint=Label.new()
	hint.custom_minimum_size=Vector2(580,30)
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color",INK)
	normal.add_child(hint)
	anchor(hint,Control.PRESET_CENTER_BOTTOM,Vector2(-290,-160),Vector2(580,30))

func _build_footer() -> void:
	footer=label(normal,"",12,MUTED)
	anchor(footer,Control.PRESET_BOTTOM_LEFT,Vector2(36,-34),Vector2(900,20))
	mode_label=label(normal,"本地农场  /  浏览模式",12,MUTED)
	anchor(mode_label,Control.PRESET_BOTTOM_RIGHT,Vector2(-320,-34),Vector2(290,20))

func _build_lock_hint() -> void:
	lock_hint=panel(root,Vector2.ZERO,Vector2(426,44),"f1f2e6")
	anchor(lock_hint,Control.PRESET_CENTER_BOTTOM,Vector2(-213,-76),Vector2(426,44))
	label(lock_hint,"Ctrl + Alt + F  解锁     ·     Ctrl + Alt + B  返回",13)
	lock_hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	lock_hint.hide()

func _build_toast() -> void:
	toast_panel=panel(root,Vector2.ZERO,Vector2(480,52),"304b40")
	anchor(toast_panel,Control.PRESET_CENTER_TOP,Vector2(-240,110),Vector2(480,52))
	toast_label=label(toast_panel,"",14,Color("f8f3dc"))
	toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	toast_panel.hide()
	toast_timer=Timer.new()
	toast_timer.one_shot=true
	toast_timer.wait_time=4
	toast_timer.timeout.connect(func(): toast_panel.hide())
	add_child(toast_timer)

func toast(text: String) -> void:
	toast_label.text=text
	toast_panel.show()
	toast_timer.start()

func set_tool(tool: String) -> void:
	selected_tool=tool
	for key in tool_buttons:
		tool_buttons[key].set_pressed_no_signal(key==tool)
	var hints={"inspect":"滚轮缩放 · 点击地块查看 · 让自然陪你一会儿", "plant":"选择左侧种子，再点击空地播种", "harvest":"点击成熟作物收获，或一键收获全部", "flowers":"点击草地摆放花丛 · 最多 32 件装饰", "barrel":"点击草地摆放木桶 · 撤回可移除最后一件"}
	hint.text=hints.get(tool,"")
	refresh()

func select_camera(index: int) -> void:
	for i in camera_buttons.size():
		camera_buttons[i].set_pressed_no_signal(i==index)

func refresh() -> void:
	stats.text="%02d  可收获    ·    累计收获 %02d 次" % [state.ready_count(),state.data.harvested]
	for key in crop_buttons:
		crop_buttons[key].set_pressed_no_signal(key==selected_crop)
	if selection>=0:
		var plot=state.data.plots[selection]
		plot_title.text="%02d 号地块  ·  %s" % [selection+1,FarmState.CROPS[plot.crop].name if plot.crop!="" else "等待播种"]
		if plot.crop=="":
			plot_detail.text="选好种子，切换播种工具后点击这里。"
		else:
			var stages=[]
			for stage in FarmState.CROPS[plot.crop].stages:
				stages.append(stage.name)
			var remaining=(FarmState.CROPS[plot.crop].duration-plot.growth)/state.data.rate
			plot_detail.text="%s · %d%%\n%s" % [stages[state.stage(plot)],roundi(state.progress(plot)*100),"可以收获了" if state.progress(plot)>=1 else ("成长已暂停" if state.data.paused else "约 %s 后成熟" % duration_text(remaining))]
		plot_progress.value=state.progress(plot)*100
	else:
		plot_title.text="一块地，一点期待"
		plot_detail.text="点击菜园地块，查看生长。\n累计收获 %d 次" % state.data.harvested
		plot_progress.value=0

static func duration_text(seconds: float) -> String:
	if seconds>=86400:
		return "%d 天 %d 小时" % [int(seconds)/86400,int(seconds)%86400/3600]
	if seconds>=3600:
		return "%d 小时 %d 分钟" % [int(seconds)/3600,int(seconds)%3600/60]
	return "%d 分钟" % maxi(1,ceili(seconds/60))

func update_environment(solar: Dictionary, weather: WeatherService) -> void:
	var date=solar.date
	clock_label.text="%02d:%02d  ·  %s" % [date.hour,date.minute,prefs.location_label()]
	var current=weather.current()
	weather_label.text="%s  %s    日落 %s" % [WeatherService.classify(int(current.code)) if not current.is_empty() else "本地晴空", "%d°C" % roundi(current.temperature) if not current.is_empty() else "",solar.sunset]
	weather_status.text=weather.status

func set_desktop(desktop: bool, locked: bool) -> void:
	normal.visible=not locked
	settings_overlay.hide()
	lock_hint.visible=locked
	desktop_button.text="返回浏览  ↙" if desktop else "桌面陪伴  ↗"
	mode_label.text="Ctrl+Alt+F 锁定  /  Ctrl+Alt+B 返回" if desktop else "本地农场  /  浏览模式"
	if desktop and not locked:
		toast("桌面操作中 · Ctrl+Alt+F 重新锁定")

func _build_settings() -> void:
	settings_overlay=Control.new()
	settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(settings_overlay)
	var dim=ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color=Color(0.12,.20,.17,.42)
	settings_overlay.add_child(dim)
	var p=panel(settings_overlay,Vector2.ZERO,Vector2(640,760))
	anchor(p,Control.PRESET_CENTER,Vector2(-320,-380),Vector2(640,760))
	var outer=column(p,10)
	var head=row(outer)
	var title=label(head,"把农场调成你喜欢的样子",22)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button(head,"完成",func(): settings_overlay.hide(),74)
	label(outer,"设置自动保存 · 环境时间始终跟随现实",13,MUTED)
	separator(outer)
	var scroll=ScrollContainer.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var v=column(scroll,13)
	v.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	label(v,"01  生长的节奏",17)
	label(v,"玉米按真实时间成长，离线也继续耗水。\n生长周期、浇水和枯死规则来自作物配置。\n缺水时可先浇水恢复；枯死后需清理重种。",13,MUTED)
	separator(v)
	label(v,"02  现实中的天空",17)
	RegionCatalog.load_catalog()
	option(v,"省 / 自治区 / 直辖市",[],[],"province_code")
	option(v,"城市 / 地区",[],[],"city_code")
	option(v,"区 / 县 / 县级市",[],[],"county_code")
	button(v,"自动定位（系统 → IP → 手选）",func(): action.emit("request_location",null))
	location_status=label(v,"",12,MUTED)
	location_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	location_status.custom_minimum_size.x=400
	check(v,"启用真实天气（Open-Meteo）","weather_online")
	option(v,"天气刷新间隔",["15 分钟","30 分钟","60 分钟","120 分钟"],[15,30,60,120],"refresh_minutes")
	label(v,"优先系统定位，失败后通过 IP 估算；均失败默认北京。\n可随时手选省／市／区县，手选后保存，不再自动覆盖。\n自动模式启动时单次定位，不持续跟踪；IP 位置请确认。",12,MUTED)
	separator(v)
	label(v,"03  画面与能耗",17)
	option(v,"画质预设",["节能优先","均衡","高画质","自定义"],["节能优先","均衡","高画质","自定义"],"preset")
	option(v,"帧率上限",["15 FPS","30 FPS"],[15,30],"fps")
	option(v,"3D 渲染分辨率",["50%","75%","85%（均衡）","100%"],[.5,.75,.85,1.0],"scale")
	option(v,"阴影质量",["关闭 / 低","中","高"],[0,1,2],"shadow")
	option(v,"天气特效",["简化（无粒子）","标准","完整"],[0,1,2],"effects")
	check(v,"根据持续帧耗时动态降低画质","dynamic")
	check(v,"隐藏或最小化时自动节能","background_saving")
	separator(v)
	label(v,"04  桌面陪伴",17)
	var monitor_names=[]
	var monitors=[]
	for i in DisplayServer.get_screen_count():
		var resolution=DisplayServer.screen_get_size(i)
		monitor_names.append("显示器 %d · %d × %d" % [i+1,resolution.x,resolution.y])
		monitors.append(i)
	if monitors.is_empty():
		monitor_names.append("无可用显示器（headless）")
		monitors.append(0)
	option(v,"铺满指定屏幕",monitor_names,monitors,"monitor")
	label(v,"右键系统托盘叶片图标切换模式、锁定/解锁。\n陪伴岛屿只供观赏；移动结束后恢复鼠标穿透。",13,MUTED)
	separator(v)
	label(v,"05  自然的声音",17)
	check(v,"开启环境音（默认关闭）","audio_enabled")
	for key in ["rain_volume","insects_volume","leaves_volume"]:
		option(v,{"rain_volume":"雨声","insects_volume":"虫鸣","leaves_volume":"风吹树叶"}[key],["静音","轻柔","适中","清晰"],[0.0,.2,.4,.6],key)
	separator(v)
	label(v,"05  本地存档",17)
	var saves=row(v)
	button(saves,"立即保存",func(): action.emit("save",null),120)
	button(saves,"打开存档目录",func(): OS.shell_open(ProjectSettings.globalize_path("user://")),150)
	label(v,"每 60 秒自动保存；重要操作后立即保存。\nSHA-256 校验 · 三份有效备份 · 旧存档自动迁移",12,MUTED)
	label(v,"苔屿 0.2  /  Godot 4.6\nWeather data by Open-Meteo.com · CC BY 4.0",12,MUTED)
	settings_overlay.hide()

func option(parent: Node, title: String, names: Array, values: Array, key: String) -> void:
	var h=row(parent)
	var l=label(h,title,14)
	l.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var o=OptionButton.new()
	o.custom_minimum_size=Vector2(240,38)
	for text in names:
		o.add_item(str(text))
	h.add_child(o)
	setting_controls[key]={"node":o,"values":values}
	o.item_selected.connect(func(index): action.emit("setting",{"key":key,"value":setting_controls[key]["values"][index]}))

func check(parent: Node, title: String, key: String) -> void:
	var c=CheckButton.new()
	c.text=title
	c.add_theme_color_override("font_color",INK)
	c.add_theme_font_size_override("font_size",14)
	c.custom_minimum_size.y=38
	parent.add_child(c)
	setting_controls[key]={"node":c}
	c.toggled.connect(func(value): action.emit("setting",{"key":key,"value":value}))

func sync_settings() -> void:
	for key in setting_controls:
		var item=setting_controls[key]
		var value=state.data.get(key,30) if key in ["rate","paused","offline_cap_days"] else prefs.data[key]
		if item.node is OptionButton:
			var index=item["values"].find(value)
			item.node.select(maxi(0,index))
		else:
			item.node.set_pressed_no_signal(value)

func open_settings() -> void:
	sync_settings()
	settings_overlay.show()
