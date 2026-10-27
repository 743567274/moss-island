class_name LightPaintWindow
extends Window

signal saved(settings: Dictionary)
var canvas: LightPaintCanvas
var message: Label
var light: Dictionary

func initialize(photo: Image,initial: Image,settings: Dictionary,ui_theme: Theme) -> void:
 title="擦除灯光 · 只影响当前光源"
 theme=ui_theme
 size=Vector2i(1120,790)
 min_size=Vector2i(850,650)
 transient=true
 exclusive=true
 light=settings.duplicate(true)
 var panel=PanelContainer.new()
 add_child(panel)
 panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var column=VBoxContainer.new()
 panel.add_child(column)
 var tools=HBoxContainer.new()
 column.add_child(tools)
 var group=ButtonGroup.new()
 for spec in [["erase","擦除灯光"],["brush","恢复灯光"]]:
  var button=Button.new()
  button.text=spec[1]
  button.toggle_mode=true
  button.button_group=group
  button.button_pressed=spec[0]=="erase"
  tools.add_child(button)
  button.pressed.connect(func(): canvas.tool=spec[0])
 _button(tools,"撤销",func(): canvas.undo())
 _button(tools,"重做",func(): canvas.redo())
 _button(tools,"恢复画面内受光",func(): canvas.restore_all())
 var marks=CheckBox.new()
 marks.text="显示擦除标记"
 tools.add_child(marks)
 marks.toggled.connect(func(value): canvas.view.material.set_shader_parameter("show_erased",value))
 canvas=LightPaintCanvas.new()
 canvas.focus_mode=Control.FOCUS_ALL
 canvas.size_flags_vertical=Control.SIZE_EXPAND_FILL
 column.add_child(canvas)
 canvas.setup(photo,initial,light)
 canvas.light.energy=float(light.get("energy",.7))*float(light.get("_paint_opacity",1))
 canvas.light.enabled=true
 canvas.refresh_light()
 canvas.radius=80.0*photo.get_width()/1920
 var brush_row=HBoxContainer.new()
 column.add_child(brush_row)
 var brush=_spin(brush_row,"画笔大小",8,300,80,2)
 brush.value_changed.connect(func(value): canvas.radius=value*photo.get_width()/1920)
 var soft=_spin(brush_row,"柔和度",.05,1,.75,.05)
 soft.value_changed.connect(func(value): canvas.softness=value)
 var force=_spin(brush_row,"擦除 / 恢复强度",.05,1,1,.05)
 force.value_changed.connect(func(value): canvas.strength=value)
 var light_row=HBoxContainer.new()
 column.add_child(light_row)
 var energy=_spin(light_row,"光源亮度",0,4,float(light.get("energy",.7)),.05)
 energy.value_changed.connect(func(value): light.energy=value; canvas.light.energy=value*float(light.get("_paint_opacity",1)); canvas.refresh_light())
 var scale=float(light.get("_paint_scale",1))
 var range_value=float(light.get("radius",[.1,.1])[0])*1920/scale
 var reach=_spin(light_row,"照射范围",12,1600,range_value,2)
 reach.editable=str(light.get("kind","point"))!="directional"
 reach.value_changed.connect(func(value):
  light.radius=[value*scale/1920,value*scale/1080]
  canvas.light.radius=light.radius
  canvas.refresh_light())
 var color=ColorPickerButton.new()
 color.edit_alpha=false
 color.color=Color(str(light.get("color","ffb45c")))
 light_row.add_child(color)
 color.color_changed.connect(func(value): light.color=value.to_html(false); canvas.light.color=light.color; canvas.refresh_light())
 _button(light_row,"保存灯光",save_paint)
 _button(light_row,"取消",queue_free)
 message=Label.new()
 message.text="夜景预览临时点亮当前光源，保存不改变开关。擦除只影响此光源，其他光源与原图不受影响。关闭窗口不保存。"
 message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 column.add_child(message)
 close_requested.connect(queue_free)

func _button(parent: Node,text: String,callback: Callable) -> void:
 var button=Button.new()
 button.text=text
 parent.add_child(button)
 button.pressed.connect(callback)

func _spin(parent: Node,text: String,minimum: float,maximum: float,value: float,step: float) -> SpinBox:
 var label=Label.new()
 label.text=text
 parent.add_child(label)
 var spin=SpinBox.new()
 spin.min_value=minimum
 spin.max_value=maximum
 spin.step=step
 spin.value=value
 parent.add_child(spin)
 return spin

func save_paint() -> void:
 var merged=MapLightFixture.merge_paint(light,canvas.pixels)
 var image=merged.image as Image
 var digest=HashingContext.new()
 digest.start(HashingContext.HASH_SHA256)
 digest.update(str(image.get_size()).to_utf8_buffer())
 digest.update(image.get_data())
 var path="user://maps/materials/light-paint-"+digest.finish().hex_encode()+".png"
 var error=DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
 if error==OK: error=image.save_png(path)
 if error!=OK:
  message.text="保存失败："+error_string(error)
  return
 saved.emit({"paint_mask":path,"paint_frame":merged.frame,"energy":light.get("energy",.7),"radius":light.get("radius",[.1,.1]),"color":light.get("color","ffb45c")})
 queue_free()
