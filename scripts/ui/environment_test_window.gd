class_name EnvironmentTestWindow
extends Window

signal preview_changed(hour: float,code: int,temperature: float)
signal restored
signal crop_preview_changed(preview: Dictionary)
const CODES=[0,3,45,61,63,65,71,73,75]
var hour_control: HSlider
var weather_control: OptionButton
var temperature_control: SpinBox
var wind_control: HSlider
var wind_value: Label
var growth_control: HSlider
var growth_value: Label
var status: Label
var initializing=false
var crop_control: OptionButton
var species_control: OptionButton
var plot_control: OptionButton
var health_control: OptionButton
var drought_control: SpinBox
var crop_status: Label
var crop_ids=[]

func _init() -> void:
 title="苔屿 · 天气与作物预览"
 size=Vector2i(560,760)
 unresizable=true

func initialize(solar: Dictionary,current: Dictionary,ui_theme: Theme,selected_plot: int=0,plot_count: int=FarmState.PLOT_COUNT) -> void:
 theme=ui_theme
 initializing=true
 var panel=PanelContainer.new()
 var background=StyleBoxFlat.new()
 background.bg_color=Color("eee7d4")
 background.set_corner_radius_all(12)
 panel.add_theme_stylebox_override("panel",background)
 add_child(panel)
 panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var margin=MarginContainer.new()
 for side in ["left","right","top","bottom"]:
  margin.add_theme_constant_override("margin_"+side,24)
 panel.add_child(margin)
 var scroll=ScrollContainer.new()
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 margin.add_child(scroll)
 var column=VBoxContainer.new()
 column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 column.add_theme_constant_override("separation",12)
 scroll.add_child(column)
 var note=Label.new()
 note.text="临时预览天气与单块田中的作物\n不修改种植、库存、系统时间或天气缓存。"
 column.add_child(note)
 status=Label.new()
 column.add_child(status)
 hour_control=HSlider.new()
 hour_control.min_value=0
 hour_control.max_value=23.75
 hour_control.step=.25
 hour_control.value=float(solar.date.hour)+float(solar.date.minute)/60
 column.add_child(hour_control)
 var weather_row=HBoxContainer.new()
 column.add_child(weather_row)
 var weather_label=Label.new()
 weather_label.text="天气  "
 weather_row.add_child(weather_label)
 weather_control=OptionButton.new()
 for name in ["晴朗","阴天","雾","小雨","中雨","大雨","小雪","中雪","大雪"]:
  weather_control.add_item(name)
 var current_code=int(current.get("code",0))
 weather_control.select(maxi(0,CODES.find(65 if current_code in [95,96,99] else current_code)))
 weather_row.add_child(weather_control)
 var temperature_label=Label.new()
 temperature_label.text="    气温 °C  "
 weather_row.add_child(temperature_label)
 temperature_control=SpinBox.new()
 temperature_control.min_value=-30
 temperature_control.max_value=45
 temperature_control.value=float(current.get("temperature",20))
 weather_row.add_child(temperature_control)
 var wind_row=HBoxContainer.new()
 column.add_child(wind_row)
 var wind_title=Label.new()
 wind_title.text="风速预览"
 wind_title.custom_minimum_size.x=100
 wind_row.add_child(wind_title)
 wind_control=HSlider.new()
 wind_control.min_value=0
 wind_control.max_value=55
 wind_control.step=.5
 wind_control.value=clampf(float(current.get("wind_speed_10m",10)),0,55)
 wind_control.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 wind_control.tooltip_text="0–55 km/h；只影响预览风力，河流保留基础流动。"
 wind_row.add_child(wind_control)
 wind_value=Label.new()
 wind_value.custom_minimum_size.x=88
 wind_row.add_child(wind_value)
 _update_wind_label()
 species_control=_option(column,"选择作物")
 crop_ids=FarmState.CROPS.keys()
 for id in crop_ids:
  species_control.add_item(FarmState.CROPS[id].name)
 plot_control=_option(column,"预览田块")
 for index in plot_count:
  plot_control.add_item("%02d 号田畦" % (index+1))
 if plot_count>0:
  plot_control.select(clampi(selected_plot,0,plot_count-1))
 crop_control=_option(column,"生长阶段")
 growth_value=Label.new()
 growth_value.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 column.add_child(growth_value)
 growth_control=HSlider.new()
 growth_control.min_value=0
 growth_control.max_value=1
 growth_control.step=1
 growth_control.editable=false
 growth_control.custom_minimum_size.y=24
 growth_control.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 growth_control.tooltip_text="拖动绿色进度条，预览从种子到成熟的任意生长进度；上方可直接跳转各阶段。"
 var track=StyleBoxFlat.new()
 track.bg_color=Color("d4dbc9")
 track.set_corner_radius_all(4)
 var fill=track.duplicate() as StyleBoxFlat
 fill.bg_color=Color("7fa05d")
 growth_control.add_theme_stylebox_override("slider",track)
 growth_control.add_theme_stylebox_override("grabber_area",fill)
 growth_control.add_theme_stylebox_override("grabber_area_highlight",fill)
 column.add_child(growth_control)
 health_control=_option(column,"水分与状态")
 for name in ["正常供水","缺水外观","不浇水推演（从干土开始）","刚采收","采收后枯萎","温度不适推演"]:
  health_control.add_item(name)
 var drought_row=HBoxContainer.new()
 column.add_child(drought_row)
 var drought_label=Label.new()
 drought_label.text="断水／温度推演天数  "
 drought_row.add_child(drought_label)
 drought_control=SpinBox.new()
 drought_control.min_value=0
 drought_control.max_value=365
 drought_control.step=.25
 drought_control.value=3
 drought_row.add_child(drought_control)
 crop_status=Label.new()
 crop_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 crop_status.custom_minimum_size=Vector2(440,85)
 column.add_child(crop_status)
 var restore=Button.new()
 restore.text="恢复真实画面"
 column.add_child(restore)
 restore.pressed.connect(restore_live)
 close_requested.connect(func():
  restore_live()
  hide())
 hour_control.value_changed.connect(func(_v): apply_preview())
 weather_control.item_selected.connect(func(_v): apply_preview())
 temperature_control.value_changed.connect(func(_v): apply_preview(); _apply_crop_preview())
 species_control.item_selected.connect(func(_v): _fill_stages(); _apply_crop_preview())
 crop_control.item_selected.connect(_select_stage)
 growth_control.value_changed.connect(_growth_changed)
 wind_control.value_changed.connect(func(_v): _update_wind_label(); apply_preview())
 plot_control.item_selected.connect(func(_v): _apply_crop_preview())
 health_control.item_selected.connect(func(_v): _apply_crop_preview())
 drought_control.value_changed.connect(func(_v): _apply_crop_preview())
 _fill_stages()
 initializing=false
 drought_control.editable=false
 status.text="实时 %02d:%02d · 调整滑块预览时刻" % [solar.date.hour,solar.date.minute]
 crop_status.text="选择作物阶段，单独查看正常、缺水和断水后的结果。"

func _option(column: VBoxContainer,title_text: String) -> OptionButton:
 var row=HBoxContainer.new()
 column.add_child(row)
 var title_label=Label.new()
 title_label.text=title_text
 title_label.custom_minimum_size.x=130
 row.add_child(title_label)
 var option=OptionButton.new()
 option.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 row.add_child(option)
 return option

func _fill_stages() -> void:
 crop_control.clear()
 crop_control.add_item("真实存档（不预览作物）")
 if not crop_ids.is_empty():
  var config=FarmState.CROPS[crop_ids[species_control.selected]]
  growth_control.max_value=float(config.duration)
  for stage in FarmState.CROPS[crop_ids[species_control.selected]].stages:
   crop_control.add_item(stage.name)
 growth_control.set_value_no_signal(0)
 growth_control.editable=false
 growth_value.text="选择阶段后，可拖动进度条预览。"

func _update_wind_label() -> void:
 wind_value.text="%.1f km/h" % wind_control.value

func sync_live_wind(current: Dictionary) -> void:
 wind_control.set_value_no_signal(clampf(float(current.get("wind_speed_10m",10)),0,55))
 _update_wind_label()

func _select_stage(index: int) -> void:
 if crop_ids.is_empty():
  return
 var elapsed=0.0
 var config=FarmState.CROPS[crop_ids[species_control.selected]]
 for i in maxi(0,index-1):
  elapsed+=float(config.stages[i].seconds)
 growth_control.set_value_no_signal(elapsed)
 growth_control.editable=index>0
 _apply_crop_preview()

func _growth_changed(value: float) -> void:
 if initializing or crop_ids.is_empty() or crop_control.selected==0:
  return
 var config=FarmState.CROPS[crop_ids[species_control.selected]]
 var elapsed=0.0
 for i in config.stages.size():
  elapsed+=float(config.stages[i].seconds)
  if value<elapsed-.000001 or i==config.stages.size()-1:
   crop_control.select(i+1)
   break
 _apply_crop_preview()

func _apply_crop_preview() -> void:
 if initializing:
  return
 if plot_control.item_count==0:
  crop_preview_changed.emit({})
  crop_status.text="当前项目没有田块，可先在地图编辑器添加土地。"
  return
 drought_control.editable=health_control.selected in [2,5]
 if crop_control.selected==0 or crop_ids.is_empty():
  growth_control.editable=false
  growth_value.text="真实存档 · 选择阶段后启用进度预览"
  crop_preview_changed.emit({})
  crop_status.text="已恢复真实作物外观。天气预览可独立调整。"
  return
 var id=str(crop_ids[species_control.selected])
 var config=FarmState.CROPS[id]
 var index=crop_control.selected-1
 var now=Time.get_unix_time_from_system()
 var simulated=FarmState.new(now,maxi(1,plot_control.item_count))
 var plot=FarmState.empty_plot(plot_control.selected)
 plot.crop=id
 plot.water_mm=config.watering.capacity_mm
 plot.growth=growth_control.value
 var stage_start=0.0
 for stage_index in index:
  stage_start+=float(config.stages[stage_index].seconds)
 var seconds=float(config.stages[index].seconds)
 var stage_percent=100.0 if seconds==0 else clampf((plot.growth-stage_start)/seconds*100,0,100)
 growth_value.text="%s · 阶段 %.1f%% · 总成长 %.1f%%\n播种后 %.1f / %.0f 天（初始预览进度）" % [config.stages[index].name,stage_percent,plot.growth/float(config.duration)*100,plot.growth/86400.0,float(config.duration)/86400.0]
 if health_control.selected==1:
  plot.water_mm=config.watering.warning_mm*.5
  plot.health="wilted"
 elif health_control.selected==2:
  plot.water_mm=0.0
  simulated.data.plots[plot.id]=plot
  simulated.settle(now+drought_control.value*86400)
  plot=simulated.data.plots[plot.id]
 elif health_control.selected in [3,4]:
  plot.growth=config.duration
  plot.health="harvested"
  plot.post_harvest_seconds=float(config.harvest.get("residue_delay_seconds",0)) if health_control.selected==4 else 0.0
 elif health_control.selected==5:
  simulated.temperature=temperature_control.value
  simulated.temperature_from=now
  simulated.temperature_until=now+drought_control.value*86400+1
  simulated.data.plots[plot.id]=plot
  simulated.settle(now+drought_control.value*86400)
  plot=simulated.data.plots[plot.id]
 var stage=config.stages[simulated.stage(plot)]
 var death=float(config.stages[index].drought_death_seconds)
 var result={"healthy":"正常","wilted":"缺水","dead":"已枯死","harvested":"收获后枯株"}.get(plot.health,plot.health)
 if plot.health=="harvested" and float(plot.get("post_harvest_seconds",0))<float(config.harvest.get("residue_delay_seconds",0)):
  result="已摘取"
 crop_status.text="%s · %02d 号田 · %s\n结果：%s，储水 %.1f mm\n%s" % [config.name,plot.id+1,stage.name,result,plot.water_mm,"此阶段干土连续断水 %.1f 天后枯死。" % (death/86400) if death>0 else "此阶段没有因缺水而死亡的配置。"]
 if health_control.selected==5:
  crop_status.text="%s · %.1f°C 推演 %.1f 天\n结果：%s · 累计温度伤害 %.1f 小时\n仅为预览，水分同时按配置消耗。" % [config.name,temperature_control.value,drought_control.value,result,float(plot.get("thermal_stress_seconds",0))/3600.0]
 crop_preview_changed.emit({"plot_index":plot.id,"plot":plot.duplicate(true)})

func apply_preview() -> void:
 if initializing:
  return
 var hour=hour_control.value
 status.text="预览 %02d:%02d · %s · %d°C · 风 %.1f km/h" % [int(hour),roundi(fmod(hour,1)*60),weather_control.get_item_text(weather_control.selected),temperature_control.value,wind_control.value]
 preview_changed.emit(hour,CODES[weather_control.selected],temperature_control.value)

func restore_live() -> void:
 crop_control.select(0)
 growth_control.set_value_no_signal(0)
 growth_control.editable=false
 growth_value.text="真实存档 · 选择阶段后启用进度预览"
 crop_preview_changed.emit({})
 restored.emit()
 status.text="已恢复真实时间、天气与作物"
 crop_status.text="选择阶段可再次预览，不影响真实种植。"
