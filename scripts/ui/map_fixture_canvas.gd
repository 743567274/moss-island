class_name MapFixtureCanvas
extends Control

signal anchor_changed(value: Vector2)
var day: Texture2D
var night: Texture2D
var settings: Dictionary={}
var show_night=false
var dragging=false

func _ready() -> void:
 mouse_default_cursor_shape=Control.CURSOR_CROSS
 resized.connect(queue_redraw)

func image_rect() -> Rect2:
 var texture=night if show_night and night!=null else day
 if texture==null: return Rect2()
 var extent=Vector2(texture.get_size())
 var scale=minf(size.x/extent.x,size.y/extent.y)*.65
 return Rect2((size-extent*scale)*.5,extent*scale)

func _draw() -> void:
 draw_rect(Rect2(Vector2.ZERO,size),Color("253b42") if show_night else Color("dedbca"))
 var texture=night if show_night and night!=null else day
 var bounds=image_rect()
 if texture==null: return
 draw_texture_rect(texture,bounds,false)
 var anchor=settings.get("anchor",[.5,.5])
 var center=bounds.position+bounds.size*Vector2(anchor[0],anchor[1])
 draw_circle(center,7,Color("fff6bc"))
 draw_arc(center,10,0,TAU,32,Color("5a6f56"),2,true)
 var angle=deg_to_rad(float(settings.get("angle",90)))
 if str(settings.get("kind","point"))!="point":
  draw_line(center,center+Vector2.from_angle(angle)*65,Color("f6b756"),3,true)
  if str(settings.get("kind","point"))=="spot":
   var half=deg_to_rad(float(settings.get("aperture",60))*.5)
   for side in [-1,1]: draw_line(center,center+Vector2.from_angle(angle+half*side)*65,Color("f6b756"),1.5,true)

func _gui_input(event: InputEvent) -> void:
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  dragging=event.pressed and Rect2(Vector2.ZERO,size).has_point(event.position)
  if dragging: _update_anchor(event.position)
  accept_event()
 elif event is InputEventMouseMotion and dragging:
  if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): dragging=false; return
  _update_anchor(event.position)
  accept_event()

func _update_anchor(point: Vector2) -> void:
 var bounds=image_rect()
 if bounds.size.x<=0 or bounds.size.y<=0: return
 var uv=(point-bounds.position)/bounds.size
 settings.anchor=[uv.x,uv.y]
 anchor_changed.emit(uv)
 queue_redraw()
