class_name LightPaintCanvas
extends WaterMaskCanvas

var softness=.75
var strength=1.0
var future=[]
var stroke_base: Image
var light: Dictionary={}

func setup(photo: Image,initial: Image,settings: Dictionary) -> void:
 initialize("","",photo,initial)
 tool="erase"
 show_direction=false
 light=settings.duplicate(true)
 light.paint_frame=[0,0,1920,1080]
 var mat=ShaderMaterial.new()
 mat.shader=load("res://assets/shaders/light_paint_preview.gdshader")
 view.material=mat
 refresh_light()

func refresh_light() -> void:
 if view==null: return
 MapLightFixture.apply_batch(view.material,[light])
 view.material.set_shader_parameter("light_mask_0",mask_texture)
 view.material.set_shader_parameter("light_mask_rects",PackedVector4Array([Vector4(0,0,1,1),Vector4(0,0,1,1),Vector4(0,0,1,1),Vector4(0,0,1,1)]))
 view.material.set_shader_parameter("light_mask_transforms",PackedVector4Array([Vector4.ZERO,Vector4.ZERO,Vector4.ZERO,Vector4.ZERO]))

func remember() -> void:
 super.remember()
 future.clear()
 stroke_base=pixels.duplicate()

func _dab(point: Vector2) -> void:
 if stroke_base==null: stroke_base=pixels.duplicate()
 for y in range(maxi(0,int(point.y-radius)),mini(pixels.get_height(),ceili(point.y+radius+1))):
  for x in range(maxi(0,int(point.x-radius)),mini(pixels.get_width(),ceili(point.x+radius+1))):
   var distance=Vector2(x+.5,y+.5).distance_to(point)/maxf(1,radius)
   if distance>=1: continue
   var weight=(1.0-smoothstep(1.0-softness,1.0,distance))*strength
   var base=stroke_base.get_pixel(x,y).r
   var value=lerpf(base,0.0 if tool=="erase" else 1.0,weight)
   var old=pixels.get_pixel(x,y).r
   value=minf(old,value) if tool=="erase" else maxf(old,value)
   pixels.set_pixel(x,y,Color(value,value,value))

func undo() -> void:
 if history.is_empty(): return
 future.append(pixels.duplicate())
 pixels=history.pop_back()
 stroke_base=null
 update_mask()

func redo() -> void:
 if future.is_empty(): return
 history.append(pixels.duplicate())
 pixels=future.pop_back()
 stroke_base=null
 update_mask()

func restore_all() -> void:
 remember()
 pixels.fill(Color.WHITE)
 update_mask()

func _gui_input(event: InputEvent) -> void:
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
  grab_focus()
 super._gui_input(event)

func _unhandled_key_input(event: InputEvent) -> void:
 if not has_focus() or not event is InputEventKey or not event.pressed: return
 if event.is_command_or_control_pressed() and event.keycode in [KEY_Z,KEY_Y]:
  if event.keycode==KEY_Y or event.shift_pressed: redo()
  else: undo()
  accept_event()
