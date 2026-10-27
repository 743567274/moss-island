class_name MapEditorCanvas
extends Control

signal picked(key: String)
signal drag_started
signal duplicate_requested
signal moved(position: Vector2)
signal drag_finished
signal scaled(value: float)
signal rotated(value: float)
signal selection_changed(keys: Array)
signal group_moved(positions: Dictionary)
signal fixture_anchor_moved(key: String,index: int,value: Vector2)
var draft: Dictionary={}
var selection=""
var night=false
var show_lights=true
var dragging=false
var duplicate_pending=false
var drag_offset=Vector2.ZERO
var textures={}
var farm: FarmState
var resizing=false
var rotating=false
var rotation_start=0.0
var rotation_delta=0.0
var rotation_pointer_angle=0.0
var resize_scale=1.0
var resize_vector=Vector2.ONE
var resize_root=Vector2.ZERO
var show_water_marker=false
var water_marker: Texture2D
var selected_keys: Array=[]
var boxing=false
var box_start=Vector2.ZERO
var box_end=Vector2.ZERO
var box_seed: Array=[]
var drag_origins={}
var drag_start=Vector2.ZERO
var preview_light: ColorRect
var preview_material: ShaderMaterial
var anchor_drag_index=0
var extra_light_previews: Array=[]
var receiver_signature=""
var receiver_texture: Texture2D
var anchor_drag_key=""
var anchor_drag_offset=Vector2.ZERO
var draw_rotation=0.0
var draw_pivot=Vector2.ZERO


func _ready() -> void:
 preview_material=ShaderMaterial.new()
 preview_material.shader=load("res://assets/shaders/map_editor_lighting.gdshader")
 preview_light=ColorRect.new()
 preview_light.mouse_filter=Control.MOUSE_FILTER_IGNORE
 preview_light.material=preview_material
 add_child(preview_light)
 mouse_default_cursor_shape=Control.CURSOR_CROSS
 resized.connect(queue_redraw)
 mouse_exited.connect(func():
  if dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
   dragging=false
   drag_finished.emit())

func canvas_rect() -> Rect2:
 var factor=minf(size.x/1920,size.y/1080)
 return Rect2((size-Vector2(1920,1080)*factor)*.5,Vector2(1920,1080)*factor)

func to_screen(point: Vector2) -> Vector2:
 var rect=canvas_rect()
 return rect.position+point*(rect.size.x/1920)

func to_map(point: Vector2) -> Vector2:
 var rect=canvas_rect()
 return (point-rect.position)/maxf(.0001,rect.size.x/1920)

func texture(path: String,region: Array=[],cleanup: Dictionary={}) -> Texture2D:
 var key=path+JSON.stringify(region)
 if not textures.has(key):
  textures[key]=ContentCatalog.prepared_texture(path,1536,region,cleanup)
 return textures[key]

func record(key: String) -> Dictionary:
 if key.begins_with("plot-"):
  for entry in draft.get("plots",[]):
   if entry.id==key:
    return entry
 elif key=="willow":
  return draft.get("willow",{})
 elif key.begins_with("light:"):
  var index=int(key.trim_prefix("light:"))
  if index<draft.get("lights",[]).size():
   return draft.lights[index]
 else:
  for entry in draft.get("objects",[]):
   if entry.id==key:
    return entry
 return {}

func plot_size(index: int,scale: float) -> Vector2:
 var p=draft.plots[index] if index<draft.get("plots",[]).size() else {}
 if p.has("surface"):
  return Vector2(float(p.surface.width),float(p.surface.height))*scale
 if p.has_all(["basis_a","basis_b"]):
  return Vector2(absf(float(p.basis_a[0]))+absf(float(p.basis_b[0])),absf(float(p.basis_a[1]))+absf(float(p.basis_b[1])))*60*1.06*scale
 var basis=MapDefinition.axes("crops" if index<12 else "orchard")
 return Vector2(absf(basis.x.x)+absf(basis.z.x),absf(basis.x.z)+absf(basis.z.z))*60*1.06*scale

func record_position(key: String) -> Vector2:
 var entry=record(key)
 if entry.is_empty(): return Vector2.ZERO
 if str(entry.get("type",""))=="background": return Vector2(960,540)
 if key.begins_with("light:"): entry=MapLightFixture.resolve_light(draft,entry)
 return Vector2(entry.position[0],entry.position[1])

func sprite_rect(entry: Dictionary,is_willow: bool=false) -> Rect2:
 var spec=MapDefinition.load_map().willow if is_willow else entry
 var image=texture(spec.texture,spec.region,spec.get("edge_cleanup",{})) if is_willow else texture(spec.texture)
 if image==null:
  return Rect2()
 if not is_willow and str(entry.get("type",""))=="background": return MapMaterialSpec.background_rect(Vector2(image.get_size()))
 var height=float(spec.height)*60*float(spec.get("scale",1.0))*float(entry.get("scale",1.0)) if is_willow else float(entry.height)*float(entry.scale)
 var extent=Vector2(height*image.get_width()/float(image.get_height()),height)
 var anchor=Vector2(spec.anchor[0],spec.anchor[1])
 var position=Vector2(entry.position[0],entry.position[1])-extent*anchor
 return Rect2(position,extent)

func _image(image: Texture2D,rect: Rect2,tint: Color=Color.WHITE) -> void:
 if image!=null:
  _screen_image(image,Rect2(to_screen(rect.position),rect.size*(canvas_rect().size.x/1920)),tint)

func _screen_image(image: Texture2D,destination: Rect2,tint: Color) -> void:
 if absf(draw_rotation)>.00001:
  _rotated_screen_image(image,destination,tint)
  return
 var clipped=destination.intersection(canvas_rect())
 if clipped.size.x<=0 or clipped.size.y<=0 or destination.size.x<=0 or destination.size.y<=0: return
 var source=Rect2((clipped.position-destination.position)/destination.size*Vector2(image.get_size()),clipped.size/destination.size*Vector2(image.get_size()))
 draw_texture_rect_region(image,clipped,source,tint)

func _rotated_screen_image(image: Texture2D,bounds: Rect2,tint: Color) -> void:
 var points=PackedVector2Array([bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)])
 var uvs=PackedVector2Array([Vector2.ZERO,Vector2(1,0),Vector2.ONE,Vector2(0,1)])
 for i in points.size(): points[i]=draw_pivot+(points[i]-draw_pivot).rotated(draw_rotation)
 var clip=canvas_rect()
 # Clip positions and UVs together so rotated sprites cannot spill outside
 # the map. Avoid clipping their unrotated rectangles before rotating them.
 for edge in 4:
  if points.is_empty(): return
  var axis=0 if edge<2 else 1
  var limit=(clip.position[axis] if edge%2==0 else clip.end[axis])
  var sign=1.0 if edge%2==0 else -1.0
  var next_points=PackedVector2Array()
  var next_uvs=PackedVector2Array()
  var a=points[-1]
  var uv_a=uvs[-1]
  var a_inside=(a[axis]-limit)*sign>=0
  for i in points.size():
   var b=points[i]
   var uv_b=uvs[i]
   var b_inside=(b[axis]-limit)*sign>=0
   if a_inside!=b_inside:
    var t=(limit-a[axis])/(b[axis]-a[axis])
    next_points.append(a.lerp(b,t))
    next_uvs.append(uv_a.lerp(uv_b,t))
   if b_inside:
    next_points.append(b)
    next_uvs.append(uv_b)
   a=b
   uv_a=uv_b
   a_inside=b_inside
  points=next_points
  uvs=next_uvs
 if points.size()>=3: draw_polygon(points,PackedColorArray([tint]),uvs,image)

func _draw_base_background(map: Dictionary,config: Dictionary) -> void:
 if str(draft.get("scene_mode","reference"))=="blank":
  var color=Color(str(draft.get("background_color","dfe5dc")))
  draw_rect(canvas_rect(),color*Color(.14,.24,.40) if night else color)
 else:
  _image(texture(map.get("night_background",map.background) if night else map.background),Rect2(0,0,1920,1080))

  var patch=config.clean_rect
  var patch_region=[patch[0],patch[1],patch[2]-patch[0],patch[3]-patch[1]]
  _image(texture(config.clean_night if night else config.clean_day,patch_region),Rect2(float(patch[0])*1920,float(patch[1])*1080,float(patch_region[2])*1920,float(patch_region[3])*1080))

func _draw() -> void:
 draw_rotation=0.0
 draw_rect(Rect2(Vector2.ZERO,size),Color("172b2c"))
 if draft.is_empty():
  return
 var map=MapDefinition.load_map()
 var config=map.willow
 for layer in MapLayerStack.entries(draft):
  draw_rotation=MapMaterialSpec.rotation(record(str(layer.key)))
  draw_pivot=to_screen(record_position(str(layer.key)))
  match str(layer.kind):
   "background":
    _draw_base_background(map,config)
   "plot":
    _draw_plot(int(layer.index))
   "willow":
    _draw_contact_shadow(draft.willow,sprite_rect(draft.willow,true),.2)
    _image(texture(config.texture,config.region,config.get("edge_cleanup",{})),sprite_rect(draft.willow,true),_tint(draft.willow,Color(.48,.60,.71) if night else Color.WHITE))
   "object":
    var entry=draft.objects[int(layer.index)]
    if str(entry.get("type",""))!="background": _draw_contact_shadow(entry,sprite_rect(entry),0)
    var lit=entry.has("fixture") and bool(MapLightFixture.state(entry).enabled) and (night or not bool(MapLightFixture.state(entry).night_only))
    var path=str(entry.get("night_texture",entry.texture)) if lit else str(entry.texture)
    _image(MapLightFixture.night_preview(entry) if lit and night else texture(path),sprite_rect(entry),_tint(entry,Color(.60,.67,.76) if night and not lit else Color.WHITE))
    if show_lights and entry.has("fixture"):
     var emitter=MapLightFixture.emitter(entry)
     var center=to_screen(Vector2(emitter.position[0],emitter.position[1]))
     draw_circle(center,5,Color("ffe5a1"))
     if is_selected(str(entry.id)):
      var angle=deg_to_rad(float(emitter.angle))
      if str(emitter.kind)!="point": draw_line(center,center+Vector2.from_angle(angle)*45,Color("ffe5a1"),2,true)
 draw_rotation=0.0
 if show_water_marker and water_marker!=null:
  _image(water_marker,Rect2(0,0,1920,1080))
 if show_lights:
  for i in draft.get("lights",[]).size():
   var entry=MapLightFixture.resolve_light(draft,draft.lights[i])
   var center=to_screen(Vector2(entry.position[0],entry.position[1]))
   draw_circle(center,7,Color("ffe5a1"))
   draw_arc(center,11,0,TAU,32,Color("987143"),1.5,true)
   if is_selected("light:%d" % i):
    var range_pixels=float(entry.radius[0])*canvas_rect().size.x
    var angle=deg_to_rad(float(entry.get("angle",90)))
    var kind=str(entry.get("kind","point"))
    if kind=="point":
     draw_arc(center,range_pixels,0,TAU,64,Color(1,.85,.4,.65),1.5,true)
    else:
     var direction=Vector2(cos(angle),sin(angle))
     draw_line(center,center+direction*range_pixels,Color("ffe6a1"),2,true)
     if kind=="spot":
      var aperture=deg_to_rad(float(entry.get("aperture",60)))*.5
      draw_arc(center,range_pixels,angle-aperture,angle+aperture,32,Color(1,.85,.4,.65),1.5,true)
      for side in [-1,1]:
       draw_line(center,center+Vector2.from_angle(angle+aperture*side)*range_pixels,Color(1,.85,.4,.65),1,true)
 for key in selected_keys:
  if str(key)==MapLayerStack.BACKGROUND:
   draw_rect(canvas_rect().grow(-2),Color("263d34"),false,5)
   draw_rect(canvas_rect().grow(-2),Color("c9e2ec"),false,2)
   continue
  var entry=record(str(key))
  if not entry.is_empty():
   var center=to_screen(record_position(str(key)))
   draw_line(center-Vector2(9,0),center+Vector2(9,0),Color("fff3bf"),2)
   draw_line(center-Vector2(0,9),center+Vector2(0,9),Color("fff3bf"),2)
   var points=object_polygon(str(key))
   for i in points.size(): points[i]=to_screen(points[i])
   if not points.is_empty():
    points.append(points[0])
    draw_polyline(points,Color("263d34"),5,true)
    draw_polyline(points,Color("c9e2ec") if is_locked(str(key)) else Color("fff3bf"),2,true)
 if boxing:
  var bounds=Rect2(box_start,box_end-box_start).abs().intersection(canvas_rect())
  draw_rect(bounds,Color(.55,.76,.68,.18))
  draw_rect(bounds,Color("d9efc4"),false,1.5)
 _draw_resize_handles()
 _draw_fixture_anchor()
 _draw_rotation_handle()
 _sync_light_preview()

func rotation_handle() -> Dictionary:
 if selected_keys.size()!=1 or not can_transform(selection) or selection.begins_with("light:"): return {}
 var points=object_polygon(selection)
 if points.size()!=4: return {}
 for i in points.size(): points[i]=to_screen(points[i])
 var midpoint=(points[0]+points[1])*.5
 var edge=(points[1]-points[0]).normalized()
 var normal=Vector2(edge.y,-edge.x)
 var bounds=canvas_rect().grow(-14)
 return {"anchor":midpoint.clamp(bounds.position,bounds.end),"position":(midpoint+normal*32).clamp(bounds.position,bounds.end)}

func _draw_rotation_handle() -> void:
 var handle=rotation_handle()
 if handle.is_empty(): return
 var point=handle.position as Vector2
 draw_line(handle.anchor,point,Color("263d34"),4,true)
 draw_line(handle.anchor,point,Color("ffe2a0"),1.5,true)
 draw_circle(point,12,Color("263d34"))
 draw_arc(point,12,0,TAU,40,Color("ffe2a0"),1.5,true)
 draw_arc(point,6,-PI*.75,PI*.75,24,Color("fff3bf"),1.7,true)
 var tip=point+Vector2.from_angle(PI*.75)*6
 var tangent=Vector2.from_angle(PI*1.25)
 draw_colored_polygon(PackedVector2Array([tip+tangent*2.5,tip-tangent*3+Vector2.from_angle(PI*.75)*3,tip-tangent*3-Vector2.from_angle(PI*.75)*3]),Color("fff3bf"))
 if rotating:
  draw_string(get_theme_default_font(),point+Vector2(17,5),"%.0f°" % float(record(selection).get("rotation_degrees",0)),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("fff3bf"))

func _get_tooltip(at_position: Vector2) -> String:
 var handle=rotation_handle()
 if not handle.is_empty() and at_position.distance_to(handle.position)<=14:
  return "拖动圆形箭头旋转；按住 Shift 以15°吸附。"
 return tooltip_text

func _fixture_handle_key() -> String:
 if not show_lights or selected_keys.size()!=1 or is_locked(selection): return ""
 var entry=record(selection)
 return selection if entry.has("fixture") else ""

func _fixture_handle_position(key: String,index: int=0) -> Vector2:
 var emitter=MapLightFixture.emitter(record(key),index)
 return to_screen(Vector2(emitter.position[0],emitter.position[1]))

func _draw_fixture_anchor() -> void:
 var key=_fixture_handle_key()
 if key.is_empty(): return
 for i in MapLightFixture.count(record(key)):
  var center=_fixture_handle_position(key,i)
  if not canvas_rect().has_point(center): continue
  var entry=record(key)
  var pivot=to_screen(Vector2(entry.position[0],entry.position[1]))
  draw_line(pivot,center,Color(.7,.92,.91,.65),1,true)
  draw_circle(center,8,Color("245968"))
  draw_arc(center,9,0,TAU,40,Color("bdf9e9"),2,true)
  draw_line(center-Vector2(5,0),center+Vector2(5,0),Color("fff3bc"),2,true)
  draw_line(center-Vector2(0,5),center+Vector2(0,5),Color("fff3bc"),2,true)
  draw_string(get_theme_default_font(),center+Vector2(12,-8),str(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("fff3bc"))

func _move_fixture_anchor(position: Vector2) -> void:
 var entry=record(anchor_drag_key)
 if entry.is_empty() or is_locked(anchor_drag_key): return
 var height=float(entry.height)*float(entry.scale)
 var extent=Vector2(height*float(entry.get("sprite_aspect",1)),height)
 var pivot=Vector2(entry.anchor[0],entry.anchor[1])
 var bounds=Rect2(Vector2(entry.position[0],entry.position[1])-extent*pivot,extent)
 if bounds.size.x<=0 or bounds.size.y<=0: return
 var origin=Vector2(entry.position[0],entry.position[1])
 var point=origin+(to_map(position)-anchor_drag_offset-origin).rotated(-MapMaterialSpec.rotation(entry))
 var uv=(point-bounds.position)/bounds.size
 fixture_anchor_moved.emit(anchor_drag_key,anchor_drag_index,uv)

func _draw_resize_handles() -> void:
 for point in resize_handles():
  if canvas_rect().grow(6).has_point(point):
   draw_rect(Rect2(point-Vector2(4,4),Vector2(8,8)),Color("fff8dc"))
   draw_rect(Rect2(point-Vector2(4,4),Vector2(8,8)),Color("49664c"),false,1)

func _draw_plot(i: int) -> void:
 var map=MapDefinition.load_map()
 var p=draft.plots[i]
 var center=Vector2(p.position[0],p.position[1])
 var extent=plot_size(i,float(p.scale))
 if p.has("surface"):
  var surface=p.surface
  var selected_path=MapMaterialSpec.selection_texture(surface)
  var path=selected_path if is_selected(str(p.id)) and not selected_path.is_empty() else str(surface.texture)
  if is_selected(str(p.id)) and selected_path.is_empty():
   var image=texture(path)
   if image!=null:
    var destination=Rect2(to_screen(center-extent*.5),extent*(canvas_rect().size.x/1920))
    _draw_highlight(image,destination,float(surface.highlight),p)
  else:
   _image(texture(path),Rect2(center-extent*.5,extent),_tint(p,Color(.60,.67,.76) if night else Color.WHITE))
 else:
  var image=texture(map.soil_atlas,map.soil_regions[0],map.get("soil_edge_cleanup",{}))
  if is_selected(str(p.id)) and image!=null:
   _draw_highlight(image,Rect2(to_screen(center-extent*.5),extent*(canvas_rect().size.x/1920)),.12,p)
  else:
   _image(image,Rect2(center-extent*.5,extent),_tint(p,Color(.60,.67,.76) if night else Color.WHITE))
 if not _preview_plot(str(p.id)).is_empty() and _preview_plot(str(p.id)).crop!="":
  var planted=_preview_plot(str(p.id))
  var look=farm.appearance(planted)
  var crop_image=ContentCatalog.texture(planted.crop,look.asset)
  if crop_image!=null:
   var height=float(look.height)*60*float(p.scale)
   var crop_size=Vector2(height*crop_image.get_width()/float(crop_image.get_height()),height)
   var anchor=float(FarmState.CROPS[planted.crop].render.anchor_y)
   var root=center
   if p.has("surface"):
    var plant_anchor=p.surface.get("plant_anchor",[.5,.5])
    root+=extent*(Vector2(plant_anchor[0],plant_anchor[1])-Vector2(.5,.5))
   _image(crop_image,Rect2(root-crop_size*Vector2(.5,anchor),crop_size),_tint(p,Color(.60,.67,.76) if night else Color.WHITE))
 if is_selected(str(p.id)) and not p.has("surface") and absf(MapMaterialSpec.rotation(p))<.00001:
  var polygon=PackedVector2Array([center+Vector2(-extent.x*.5,0),center+Vector2(0,-extent.y*.5),center+Vector2(extent.x*.5,0),center+Vector2(0,extent.y*.5),center+Vector2(-extent.x*.5,0)])
  for j in polygon.size():
   polygon[j]=to_screen(polygon[j])
  draw_polyline(polygon,Color("f6e29d"),2,true)

func pick(point: Vector2) -> String:
 if show_lights:
  for i in draft.get("lights",[]).size():
   var entry=MapLightFixture.resolve_light(draft,draft.lights[i])
   if is_locked("light:%d" % i): continue
   if point.distance_to(Vector2(entry.position[0],entry.position[1]))<20:
    return "light:%d" % i
 var stack=MapLayerStack.entries(draft)
 stack.reverse()
 for layer in stack:
  if layer.kind=="background" or is_locked(str(layer.key)): continue
  if layer.kind=="object" and str(draft.objects[int(layer.index)].get("type",""))=="background": continue
  if layer.kind=="plot":
   var entry=draft.plots[int(layer.index)]
   var delta=(point-Vector2(entry.position[0],entry.position[1])).rotated(-MapMaterialSpec.rotation(entry))
   var extent=plot_size(int(layer.index),float(entry.scale))
   if entry.has("surface"):
    if MapMaterialSpec.contains(entry.surface,delta/extent+Vector2(.5,.5)):
     return entry.id
   elif absf(delta.x)/(extent.x*.5)+absf(delta.y)/(extent.y*.5)<=1:
    return entry.id
  elif layer.kind=="willow":
   var origin=record_position("willow")
   var local=origin+(point-origin).rotated(-MapMaterialSpec.rotation(draft.willow))
   if sprite_rect(draft.willow,true).has_point(local):
    return "willow"
  else:
   var entry=draft.objects[int(layer.index)]
   var rect=sprite_rect(entry)
   var origin=Vector2(entry.position[0],entry.position[1])
   var local=origin+(point-origin).rotated(-MapMaterialSpec.rotation(entry))
   if rect.has_point(local) and MapMaterialSpec.contains({"shape":"alpha","texture":entry.texture},(local-rect.position)/rect.size):
    return entry.id
 return ""
func _preview_plot(key: String) -> Dictionary:
 if farm==null:
  return {}
 for i in farm.data.plots.size():
  var p=farm.data.plots[i]
  if str(p.get("map_plot_id","plot-%d" % i))==key:
   return p
 return {}

func _draw_highlight(image: Texture2D,destination: Rect2,amount: float,entry: Dictionary) -> void:
 var key="selected:"+str(image.get_instance_id())+":"+str(amount)
 if not textures.has(key):
  var pixels=image.get_image()
  if pixels.is_compressed():
   pixels.decompress()
  pixels.convert(Image.FORMAT_RGBA8)
  pixels.adjust_bcs(1.0+amount,1.0,1.0)
  var variants=[]
  for old in textures.keys():
   if str(old).begins_with("selected:"): variants.append(old)
  if variants.size()>=16: textures.erase(variants[0])
  textures[key]=ImageTexture.create_from_image(pixels)
 _screen_image(textures[key],destination,_tint(entry,Color(.60,.67,.76) if night else Color.WHITE))

func _gui_input(event: InputEvent) -> void:
 if event is InputEventMouseMotion and not (dragging or resizing or rotating):
  var handle=rotation_handle()
  mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND if not handle.is_empty() and event.position.distance_to(handle.position)<=14 else Control.CURSOR_CROSS
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  if event.pressed:
   var rotation=rotation_handle()
   if not rotation.is_empty() and not (event.alt_pressed or event.ctrl_pressed) and event.position.distance_to(rotation.position)<=14:
    rotating=true
    rotation_start=float(record(selection).get("rotation_degrees",0))
    rotation_delta=0.0
    rotation_pointer_angle=(event.position-to_screen(record_position(selection))).angle()
    drag_started.emit()
    accept_event()
    return
   var fixture_key=_fixture_handle_key()
   if not fixture_key.is_empty() and not (event.alt_pressed or event.shift_pressed or event.ctrl_pressed):
    for i in MapLightFixture.count(record(fixture_key)):
     var handle=_fixture_handle_position(fixture_key,i)
     if canvas_rect().has_point(handle) and event.position.distance_to(handle)<=12:
      anchor_drag_key=fixture_key
      anchor_drag_index=i
      anchor_drag_offset=to_map(event.position)-to_map(handle)
      drag_started.emit()
      accept_event()
      return
   var handles=PackedVector2Array() if event.alt_pressed else resize_handles()
   for handle in handles:
    if canvas_rect().grow(6).has_point(handle) and event.position.distance_to(handle)<=10:
     var entry=record(selection)
     resize_scale=float(entry.get("scale",1))
     resize_root=Vector2(entry.position[0],entry.position[1])
     resize_vector=to_map(handle)-resize_root
     resizing=true
     drag_started.emit()
     accept_event()
     return
   if not canvas_rect().has_point(event.position): return
   var point=to_map(event.position)
   var key=pick(point)
   var additive=(event.shift_pressed or event.ctrl_pressed) and not event.alt_pressed
   if key.is_empty():
    boxing=true
    box_start=event.position
    box_end=box_start
    box_seed=selected_keys.duplicate() if additive else []
    if not additive: _set_canvas_selection([])
    accept_event()
    return
   if additive:
    var next=selected_keys.duplicate()
    if next.has(key): next.erase(key)
    else: next.append(key)
    _set_canvas_selection(next)
    accept_event()
    return
   if not is_selected(key): _set_canvas_selection([key])
   if not key.is_empty():
    drag_origins.clear()
    for selected in selected_keys:
     var entry=record(str(selected))
     if not entry.is_empty() and can_transform(str(selected)):
      drag_origins[selected]=record_position(str(selected))
    drag_start=point
    dragging=not drag_origins.is_empty()
    duplicate_pending=event.alt_pressed
    if dragging: drag_started.emit()
  elif rotating:
   rotating=false
   drag_finished.emit()
  elif not anchor_drag_key.is_empty():
   _move_fixture_anchor(event.position)
   anchor_drag_key=""
   drag_finished.emit()
  elif boxing:
   box_end=event.position.clamp(canvas_rect().position,canvas_rect().end)
   var bounds=Rect2(to_map(box_start),to_map(box_end)-to_map(box_start)).abs()
   var next=box_seed.duplicate()
   if bounds.size.length()>4:
    for key in editable_keys():
     if bounds.intersects(object_bounds(str(key))) and not next.has(key): next.append(key)
   boxing=false
   _set_canvas_selection(next)
  elif resizing:
   resizing=false
   drag_finished.emit()
  elif dragging:
   dragging=false
   duplicate_pending=false
   drag_finished.emit()
  queue_redraw()
  accept_event()
 elif event is InputEventMouseMotion and rotating:
  if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
   rotating=false
   drag_finished.emit()
   return
  var angle=(event.position-to_screen(record_position(selection))).angle()
  rotation_delta+=rad_to_deg(wrapf(angle-rotation_pointer_angle,-PI,PI))
  rotation_pointer_angle=angle
  var value=rotation_start+rotation_delta
  if event.shift_pressed: value=snappedf(value,15.0)
  rotated.emit(wrapf(value,-180,180))
  accept_event()
 elif event is InputEventMouseMotion and not anchor_drag_key.is_empty():
  if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
   anchor_drag_key=""
   drag_finished.emit()
   return
  _move_fixture_anchor(event.position)
  accept_event()
 elif event is InputEventMouseMotion and boxing:
  box_end=event.position.clamp(canvas_rect().position,canvas_rect().end)
  queue_redraw()
  accept_event()
 elif event is InputEventMouseMotion and resizing:
  if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
   resizing=false
   drag_finished.emit()
   return
  var ratio=(to_map(event.position)-resize_root).dot(resize_vector)/maxf(.01,resize_vector.length_squared())
  scaled.emit(clampf(resize_scale*ratio,.3,3.0))
  accept_event()
 elif event is InputEventMouseMotion and dragging:
  if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
   dragging=false
   drag_finished.emit()
   return
  if duplicate_pending:
   if (to_map(event.position)-drag_start).length()*canvas_rect().size.x/1920<5: return
   duplicate_pending=false
   var original=selected_keys.duplicate()
   duplicate_requested.emit()
   if selected_keys==original:
    dragging=false
    return
   drag_origins.clear()
   for key in selected_keys: drag_origins[key]=record_position(str(key))
  var delta=to_map(event.position)-drag_start
  var minimum=Vector2(-INF,-INF)
  var maximum=Vector2(INF,INF)
  for origin in drag_origins.values():
   minimum=minimum.max(-origin)
   maximum=maximum.min(Vector2(1920,1080)-origin)
  delta=delta.clamp(minimum,maximum)
  var positions={}
  for key in drag_origins: positions[key]=drag_origins[key]+delta
  group_moved.emit(positions)
  accept_event()

func resize_handles() -> PackedVector2Array:
 var entry=record(selection)
 if entry.is_empty() or selected_keys.size()!=1 or not can_transform(selection) or selection.begins_with("light:"): return PackedVector2Array()
 var bounds: Rect2
 if selection.begins_with("plot-"):
  var index=draft.plots.find(entry)
  var extent=plot_size(index,float(entry.scale))
  bounds=Rect2(Vector2(entry.position[0],entry.position[1])-extent*.5,extent)
 else:
  bounds=sprite_rect(entry,selection=="willow")
 var points=PackedVector2Array([bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)])
 var origin=record_position(selection)
 for i in points.size(): points[i]=to_screen(origin+(points[i]-origin).rotated(MapMaterialSpec.rotation(entry)))
 return points

func is_locked(key: String) -> bool:
 if key==MapLayerStack.BACKGROUND: return bool(draft.get("background_locked",true))
 return bool(record(key).get("editor_locked",MapLayerStack.is_background(draft,key)))

func can_transform(key: String) -> bool:
 return key!=MapLayerStack.BACKGROUND and not is_locked(key) and not MapLayerStack.is_background(draft,key)

func is_selected(key: String) -> bool:
 return selected_keys.has(key)

func editable_keys() -> Array:
 var result=[]
 for layer in MapLayerStack.entries(draft):
  if can_transform(str(layer.key)): result.append(str(layer.key))
 if show_lights:
  for i in draft.get("lights",[]).size():
   var key="light:%d" % i
   if not is_locked(key): result.append(key)
 return result

func object_bounds(key: String) -> Rect2:
 var points=object_polygon(key)
 if points.is_empty(): return Rect2()
 var bounds=Rect2(points[0],Vector2.ZERO)
 for point in points: bounds=bounds.expand(point)
 return bounds

func object_polygon(key: String) -> PackedVector2Array:
 var entry=record(key)
 if entry.is_empty(): return PackedVector2Array()
 var root=record_position(key)
 var bounds: Rect2
 if str(entry.get("type",""))=="background": bounds=Rect2(0,0,1920,1080)
 elif key.begins_with("light:"): bounds=Rect2(root-Vector2(16,16),Vector2(32,32))
 elif key.begins_with("plot-"):
  var extent=plot_size(draft.plots.find(entry),float(entry.scale))
  bounds=Rect2(root-extent*.5,extent)
 else: bounds=sprite_rect(entry,key=="willow")
 var points=PackedVector2Array([bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)])
 for i in points.size(): points[i]=root+(points[i]-root).rotated(MapMaterialSpec.rotation(entry))
 return points

func _set_canvas_selection(next: Array) -> void:
 selected_keys=[]
 for key in next:
  if not is_locked(str(key)) and not record(str(key)).is_empty(): selected_keys.append(str(key))
 selection=str(selected_keys.back()) if not selected_keys.is_empty() else ""
 selection_changed.emit(selected_keys.duplicate())
 queue_redraw()

func _sync_light_preview() -> void:
 if preview_light==null: return
 preview_light.position=canvas_rect().position
 preview_light.size=canvas_rect().size
 var signature=JSON.stringify(draft.get("objects",[]))
 if receiver_texture==null or (signature!=receiver_signature and not dragging and not resizing and anchor_drag_key.is_empty()):
  receiver_signature=signature
  receiver_texture=MapLightFixture.receiver(draft)
 var lights=MapLightFixture.lights(draft)
 var batches=maxi(1,ceili(lights.size()/4.0))
 while extra_light_previews.size()<batches-1:
  var overlay=ColorRect.new()
  overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
  var mat=ShaderMaterial.new()
  mat.shader=preview_material.shader
  overlay.material=mat
  add_child(overlay)
  extra_light_previews.append(overlay)
 for batch in maxi(batches,extra_light_previews.size()+1):
  var overlay=preview_light if batch==0 else extra_light_previews[batch-1]
  overlay.visible=batch<batches
  if batch>=batches: continue
  overlay.position=canvas_rect().position
  overlay.size=canvas_rect().size
  var mat=overlay.material as ShaderMaterial
  mat.set_shader_parameter("daylight",0.0 if night else 1.0)
  mat.set_shader_parameter("receiver",receiver_texture)
  MapLightFixture.apply_batch(mat,lights,batch*4)

func _tint(entry: Dictionary,color: Color) -> Color:
 color.a*=float(entry.get("opacity",1))
 return color

func _draw_contact_shadow(entry: Dictionary,bounds: Rect2,fallback: float) -> void:
 var strength=float(entry.get("shadow_strength",fallback))*float(entry.get("opacity",1))
 if strength<=0: return
 if not textures.has("contact-shadow"):
  var pixels=Image.create(64,32,false,Image.FORMAT_RGBA8)
  for y in 32:
   for x in 64:
    var radius=Vector2((x+.5)/32-1,(y+.5)/16-1).length()
    pixels.set_pixel(x,y,Color(.06,.09,.065,exp(-radius*radius*4)*(1-smoothstep(.7,1.0,radius))))
  textures["contact-shadow"]=ImageTexture.create_from_image(pixels)
 var extent=Vector2(maxf(6,bounds.size.x*.7),maxf(4.8,bounds.size.y*.12))*float(entry.get("shadow_scale",1))
 var root=Vector2(entry.position[0],entry.position[1])+MapMaterialSpec.shadow_offset(entry)
 _image(textures["contact-shadow"],Rect2(root-extent*.5,extent),Color(1,1,1,strength))
