class_name MapFixtureInspector
extends VBoxContainer

signal operation(kind: String,value: Variant)
signal texture_requested(role: String)
var index=0
var item: Dictionary={}
var selector: OptionButton
var kind: OptionButton
var controls={}
var checks={}
var color: ColorPickerButton
var syncing=false
var body_brightness: SpinBox

func _ready() -> void:
 var title=Label.new()
 title.text="灯具光源 · 在地图中拖动编号锚点"
 add_child(title)
 var body_label=Label.new()
 body_label.text="本体夜间亮度（不改变灯芯亮度）"
 add_child(body_label)
 body_brightness=SpinBox.new()
 body_brightness.min_value=.1
 body_brightness.max_value=1.5
 body_brightness.step=.05
 add_child(body_brightness)
 body_brightness.value_changed.connect(func(value):
  if not syncing: operation.emit("night_brightness",value))
 selector=OptionButton.new()
 add_child(selector)
 selector.item_selected.connect(func(value): index=value; sync(item))
 var row=HBoxContainer.new()
 add_child(row)
 for action in ["add","copy","delete"]:
  var button=Button.new()
  button.text={"add":"添加","copy":"复制","delete":"删除"}[action]
  row.add_child(button)
  button.pressed.connect(func(): operation.emit(action,null))
 kind=OptionButton.new()
 for label in ["发散光","筒光","直射光"]: kind.add_item(label)
 add_child(kind)
 kind.item_selected.connect(func(value): operation.emit("kind",["point","spot","directional"][value]))
 for spec in [["anchor_x","光源 X（可超出 0～1）",-10000,10000,.01],["anchor_y","光源 Y（可超出 0～1）",-10000,10000,.01],["angle","方向角",-360,360,1],["aperture","筒光夹角",5,175,1],["range","照射范围",12,1600,1],["energy","亮度",0,4,.05]]:
  var label=Label.new()
  label.text=spec[1]
  add_child(label)
  var spin=SpinBox.new()
  spin.min_value=spec[2]
  spin.max_value=spec[3]
  spin.step=spec[4]
  add_child(spin)
  controls[spec[0]]=spin
  spin.value_changed.connect(func(value):
   if not syncing: operation.emit(spec[0],value))
 color=ColorPickerButton.new()
 color.edit_alpha=false
 add_child(color)
 color.color_changed.connect(func(value):
  if not syncing: operation.emit("color",value.to_html(false)))
 for key in ["enabled","night_only","flicker","pass_through_owner"]:
  var check=CheckBox.new()
  check.text={"enabled":"启用此光源","night_only":"仅夜间开启","flicker":"轻微闪动","pass_through_owner":"穿透所属贴图（不照亮本体）"}[key]
  add_child(check)
  checks[key]=check
  check.toggled.connect(func(value):
   if not syncing: operation.emit(key,value))
 var paint=Button.new()
 paint.text="擦除 / 恢复此光源照明"
 add_child(paint)
 paint.pressed.connect(func(): texture_requested.emit("light_paint"))
 var emission=Button.new()
 emission.text="标记灯芯 / 自发光区域"
 add_child(emission)
 emission.pressed.connect(func(): texture_requested.emit("emission_mask"))
 for role in ["object_day","object_night"]:
  var button=Button.new()
  button.text="替换白天贴图" if role=="object_day" else "替换夜间贴图"
  add_child(button)
  button.pressed.connect(func(): texture_requested.emit(role))

func sync(value: Dictionary) -> void:
 item=value
 if selector==null: return
 syncing=true
 body_brightness.set_value_no_signal(float(item.fixture.get("night_brightness",.55)))
 index=clampi(index,0,MapLightFixture.count(item)-1)
 selector.clear()
 for i in MapLightFixture.count(item): selector.add_item("光源 %d" % (i+1))
 selector.select(index)
 var settings=MapLightFixture.source(item,index)
 kind.select(maxi(0,["point","spot","directional"].find(str(settings.kind))))
 for key in controls:
  var setting_value=settings.anchor[0 if key=="anchor_x" else 1] if key in ["anchor_x","anchor_y"] else settings[key]
  controls[key].set_value_no_signal(float(setting_value))
 controls.angle.editable=str(settings.kind)!="point"
 controls.aperture.editable=str(settings.kind)=="spot"
 controls.range.editable=str(settings.kind)!="directional"
 color.color=Color(str(settings.color))
 for key in checks: checks[key].set_pressed_no_signal(bool(settings.get(key,false)))
 syncing=false
