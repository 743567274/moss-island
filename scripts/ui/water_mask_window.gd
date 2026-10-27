class_name WaterMaskWindow
extends Window

signal saved(settings: Dictionary)
var canvas: WaterMaskCanvas
var angle: SpinBox
var speed: SpinBox
var feather: SpinBox
var status: Label

func initialize(path: String,settings: Dictionary,ui_theme: Theme,source_image: Image=null,initial_mask: Image=null) -> void:
 title="标记水面 · 蓝色区域产生动态"
 size=Vector2i(1020,760)
 min_size=Vector2i(800,620)
 theme=ui_theme
 var panel=PanelContainer.new()
 add_child(panel)
 panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var column=VBoxContainer.new()
 panel.add_child(column)
 var tools=HBoxContainer.new()
 column.add_child(tools)
 var tool_group=ButtonGroup.new()
 for entry in [["brush","画笔"],["erase","橡皮擦"],["rect","矩形"],["ellipse","椭圆"],["polygon","多边形"]]:
  var button=Button.new()
  button.text=entry[1]
  button.toggle_mode=true
  button.button_group=tool_group
  button.button_pressed=entry[0]=="brush"
  tools.add_child(button)
  button.pressed.connect(func(): canvas.tool=entry[0]; canvas.polygon.clear(); canvas.queue_redraw(); status.text="当前工具："+str(entry[1]))
 _button(tools,"完成多边形",func(): canvas.finish_polygon())
 _button(tools,"撤销",func(): canvas.undo())
 _button(tools,"清空",func(): canvas.clear_mask())
 if source_image==null: _button(tools,"按透明轮廓",func(): canvas.reset_alpha())
 canvas=WaterMaskCanvas.new()
 canvas.size_flags_vertical=Control.SIZE_EXPAND_FILL
 column.add_child(canvas)
 canvas.initialize(path,str(settings.get("mask","")),source_image,initial_mask)
 var controls=HBoxContainer.new()
 column.add_child(controls)
 var brush=_spin(controls,"画笔大小",2,72,18,1)
 brush.value_changed.connect(func(value): canvas.radius=value)
 angle=_spin(controls,"方向°",-360,360,float(settings.get("angle",0)),1)
 canvas.direction=angle.value
 angle.value_changed.connect(func(value): canvas.direction=value; canvas.queue_redraw())
 speed=_spin(controls,"速度",0,3,float(settings.get("speed",1)),.1)
 feather=_spin(controls,"边缘柔化",0,16,float(settings.get("feather",3)),1)
 _button(controls,"保存水面标记",save_mask)
 status=Label.new()
 status.text="蓝色为水面；橡皮擦排除桥、岸边等静态部分。多边形逐点点击后按完成或右键。方向0°向右、90°向下。"
 if source_image!=null:
  title="地图水域编辑器 · 不可见区域标记"
  status.text="直接沿地图描画蓝色水域，排除桥、树与岸边。保存的是效果范围，不会生成水面图片或加入图层。"
 status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 column.add_child(status)
 close_requested.connect(queue_free)

func _button(parent: Node,text: String,callback: Callable) -> void:
 var button=Button.new()
 button.text=text
 button.pressed.connect(callback)
 parent.add_child(button)

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

func save_mask() -> void:
 if canvas.polygon.size()>0:
  status.text="请先完成或撤销当前多边形，再保存。"
  return
 var hash=HashingContext.new()
 hash.start(HashingContext.HASH_SHA256)
 hash.update(str(canvas.pixels.get_size()).to_utf8_buffer())
 hash.update(canvas.pixels.get_data())
 var path="user://maps/materials/water-"+hash.finish().hex_encode()+".png"
 var error=DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
 if error==OK: error=canvas.pixels.save_png(path)
 if error!=OK:
  status.text="保存失败："+error_string(error)
  return
 saved.emit({"mask":path,"angle":angle.value,"speed":speed.value,"feather":feather.value})
 queue_free()
