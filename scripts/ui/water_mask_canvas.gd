class_name WaterMaskCanvas
extends Control

var source: Image
var pixels: Image
var mask_texture: ImageTexture
var view: TextureRect
var tool="brush"
var radius=18.0
var drawing=false
var start=Vector2.ZERO
var last=Vector2.ZERO
var current=Vector2.ZERO
var polygon=PackedVector2Array()
var history=[]
var overlay: Control
var direction=0.0
var show_direction=true
var hover=Vector2(-1,-1)

func initialize(path: String,mask_path: String,source_image: Image=null,initial_mask: Image=null) -> void:
 var texture=ContentCatalog.prepared_texture(path,512) if source_image==null else ImageTexture.create_from_image(source_image)
 source=texture.get_image()
 if source.is_compressed(): source.decompress()
 source.convert(Image.FORMAT_RGBA8)
 pixels=Image.load_from_file(mask_path) if not mask_path.is_empty() and FileAccess.file_exists(mask_path) else null
 if pixels==null and initial_mask!=null: pixels=initial_mask.duplicate()
 if pixels==null:
  reset_alpha(false)
 else:
  pixels.convert(Image.FORMAT_L8)
  pixels.resize(source.get_width(),source.get_height(),Image.INTERPOLATE_BILINEAR)
 mask_texture=ImageTexture.create_from_image(pixels)
 view=TextureRect.new()
 view.texture=texture
 view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 view.stretch_mode=TextureRect.STRETCH_SCALE
 view.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var mat=ShaderMaterial.new()
 mat.shader=load("res://assets/shaders/water_mask_preview.gdshader")
 mat.set_shader_parameter("mask_image",mask_texture)
 view.material=mat
 add_child(view)
 overlay=Control.new()
 overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
 overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay.draw.connect(_draw_overlay)
 add_child(overlay)
 resized.connect(_layout)
 mouse_exited.connect(func(): hover=Vector2(-1,-1); queue_redraw())
 _layout()

func rect() -> Rect2:
 if source==null: return Rect2()
 var extent=Vector2(source.get_size())
 var scale=minf(size.x/extent.x,size.y/extent.y)
 return Rect2((size-extent*scale)*.5,extent*scale)

func _layout() -> void:
 if view!=null:
  view.position=rect().position
  view.size=rect().size
 queue_redraw()

func _draw() -> void:
 for y in ceili(size.y/24):
  for x in ceili(size.x/24):
   draw_rect(Rect2(x*24,y*24,24,24),Color("b5bdb4") if (x+y)%2==0 else Color("d8ddd3"))
 if overlay!=null: overlay.queue_redraw()

func _draw_overlay() -> void:
 if source==null: return
 var transform=rect().size/Vector2(source.get_size())
 if rect().has_point(hover) and tool in ["brush","erase"]:
  overlay.draw_arc(hover,radius*transform.x,0,TAU,48,Color("bc5648") if tool=="erase" else Color("fff1b7"),1.5,true)
 var points=PackedVector2Array()
 for point in polygon: points.append(rect().position+point*transform)
 if points.size()>1: overlay.draw_polyline(points,Color("ffc86b"),2,true)
 if drawing and tool in ["rect","ellipse"]:
  var bounds=Rect2(rect().position+start*transform,(current-start)*transform).abs()
  overlay.draw_rect(bounds,Color("ffc86b"),false,2)
 if not show_direction: return
 var center=rect().position+rect().size*Vector2(.85,.85)
 var vector=Vector2.from_angle(deg_to_rad(direction))
 var tip=center+vector*40
 overlay.draw_circle(center,4,Color("fff1b7"))
 overlay.draw_line(center,tip,Color("fff1b7"),3,true)
 overlay.draw_polyline(PackedVector2Array([tip-vector.rotated(.55)*12,tip,tip-vector.rotated(-.55)*12]),Color("fff1b7"),3,true)

func remember() -> void:
 history.append(pixels.duplicate())
 if history.size()>20: history.pop_front()

func update_mask() -> void:
 if mask_texture!=null: mask_texture.update(pixels)
 queue_redraw()

func reset_alpha(undoable: bool=true) -> void:
 if undoable: remember()
 var rgba=source.get_data()
 var bytes=PackedByteArray()
 bytes.resize(source.get_width()*source.get_height())
 for i in bytes.size(): bytes[i]=rgba[i*4+3]
 pixels=Image.create_from_data(source.get_width(),source.get_height(),false,Image.FORMAT_L8,bytes)
 update_mask()

func clear_mask() -> void:
 remember()
 pixels.fill(Color.BLACK)
 polygon.clear()
 update_mask()

func undo() -> void:
 polygon.clear()
 if not history.is_empty(): pixels=history.pop_back()
 update_mask()

func _dab(point: Vector2) -> void:
 var color=Color.BLACK if tool=="erase" else Color.WHITE
 for y in range(maxi(0,int(point.y-radius)),mini(pixels.get_height(),ceili(point.y+radius+1))):
  for x in range(maxi(0,int(point.x-radius)),mini(pixels.get_width(),ceili(point.x+radius+1))):
   if Vector2(x,y).distance_squared_to(point)<=radius*radius: pixels.set_pixel(x,y,color)

func fill_shape(points: PackedVector2Array,ellipse: bool=false) -> void:
 if points.size()<3: return
 remember()
 var lo=points[0]
 var hi=lo
 for p in points:
  lo=lo.min(p)
  hi=hi.max(p)
 var center=(lo+hi)*.5
 var extent=(hi-lo)*.5
 for y in range(maxi(0,floori(lo.y)),mini(pixels.get_height(),ceili(hi.y)+1)):
  for x in range(maxi(0,floori(lo.x)),mini(pixels.get_width(),ceili(hi.x)+1)):
   var point=Vector2(x,y)
   var inside=((point-center)/extent.max(Vector2.ONE)).length_squared()<=1 if ellipse else Geometry2D.is_point_in_polygon(point,points)
   if inside: pixels.set_pixel(x,y,Color.WHITE)
 update_mask()

func finish_polygon() -> void:
 fill_shape(polygon)
 polygon.clear()
 queue_redraw()

func _gui_input(event: InputEvent) -> void:
 if source==null: return
 if event is InputEventMouseMotion:
  hover=event.position
  queue_redraw()
 if event is InputEventMouseButton:
  if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
   finish_polygon()
   return
  if event.button_index!=MOUSE_BUTTON_LEFT: return
  var point=(event.position-rect().position)/rect().size*Vector2(source.get_size())
  point=point.clamp(Vector2.ZERO,Vector2(source.get_size())-Vector2.ONE)
  if event.pressed:
   if not rect().has_point(event.position): return
   if tool=="polygon":
    polygon.append(point)
    queue_redraw()
    return
   drawing=true
   start=point
   last=point
   current=point
   if tool in ["brush","erase"]:
    remember()
    _dab(point)
    update_mask()
  elif drawing:
   drawing=false
   if tool in ["rect","ellipse"]:
    var lo=start.min(point)
    var hi=start.max(point)
    fill_shape(PackedVector2Array([lo,Vector2(hi.x,lo.y),hi,Vector2(lo.x,hi.y)]),tool=="ellipse")
   queue_redraw()
 elif event is InputEventMouseMotion and drawing:
  current=((event.position-rect().position)/rect().size*Vector2(source.get_size())).clamp(Vector2.ZERO,Vector2(source.get_size())-Vector2.ONE)
  if tool in ["brush","erase"]:
   var steps=maxi(1,ceili(last.distance_to(current)/maxf(1,radius*.4)))
   for i in steps: _dab(last.lerp(current,float(i+1)/steps))
   last=current
   update_mask()
  queue_redraw()
