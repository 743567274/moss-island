class_name MapLightFixture
extends RefCounted

static func defaults() -> Dictionary:
 return {"anchor":[.5,.5],"kind":"point","angle":90.0,"aperture":60.0,"range":160.0,"energy":.65,"color":"ffb45c","enabled":true,"night_only":true,"flicker":false,"pass_through_owner":false}

static func valid(item: Dictionary) -> bool:
 var settings=item.get("fixture",{})
 if not settings is Dictionary or settings.is_empty(): return false
 if not _number(settings.get("night_brightness",.55),.1,1.5): return false
 if not valid_paint(settings): return false
 var path=str(item.get("night_texture",""))
 if not path.begins_with("user://maps/materials/") or path.contains("..") or path.get_extension()!="png": return false
 var sources=settings.get("sources",[])
 if not sources is Array: return false
 for source in sources:
  if not source is Dictionary or source.has("sources"): return false
  if not valid(item.merged({"fixture":source},true)): return false
 var anchor=settings.get("anchor")
 if not anchor is Array or anchor.size()!=2: return false
 for number in anchor:
  if not _number(number,-10000,10000): return false
 if not str(settings.get("kind","")) in ["point","spot","directional"]: return false
 for key in ["enabled","night_only","flicker","pass_through_owner"]:
  if not settings.get(key,false) is bool: return false
 return _number(settings.get("range"),12,1600) and _number(settings.get("energy"),0,4) and _number(settings.get("angle"),-360,360) and _number(settings.get("aperture"),5,175) and Color.html_is_valid(str(settings.get("color",""))) and _number(item.get("sprite_aspect",1),.001,1000)

static func _number(value: Variant,minimum: float,maximum: float) -> bool:
 return (value is int or value is float) and is_finite(float(value)) and float(value)>=minimum and float(value)<=maximum

static func texture_error(item: Dictionary) -> String:
 var day=str(item.get("texture",""))
 var night=str(item.get("night_texture",""))
 if day.is_empty() or night.is_empty(): return "光源素材必须同时上传白天与夜间两张贴图。"
 if day==night: return "白天与夜间需要两张不同状态的贴图，不能使用同一张图片。"
 var a=Image.load_from_file(day) if FileAccess.file_exists(day) else null
 var b=Image.load_from_file(night) if FileAccess.file_exists(night) else null
 if a==null or b==null: return "光源的白天或夜间贴图无法读取，请重新上传。"
 if a.get_size()!=b.get_size(): return "昼夜贴图尺寸不一致：白天 %d×%d，夜间 %d×%d。请统一画布尺寸并保持物体位置对齐后重新上传。" % [a.get_width(),a.get_height(),b.get_width(),b.get_height()]
 if not valid(item): return "光源锚点或光照参数无效，请检查设置。"
 return ""

static func source(item: Dictionary,index: int=0) -> Dictionary:
 return item.fixture if index==0 else item.fixture.sources[index-1]

static func count(item: Dictionary) -> int:
 return 1+item.get("fixture",{}).get("sources",[]).size()

static func emitter(item: Dictionary,index: int=0,project_ground: bool=false) -> Dictionary:
 if not item.has("fixture"):
  return {"position":item.position.duplicate(),"radius":[.04*float(item.scale),.055*float(item.scale)],"energy":.65,"color":"ffb45c","night_only":true}
 var settings=source(item,index).duplicate(true)
 settings.erase("sources")
 var scale=float(item.get("scale",1))
 var height=float(item.get("height",item.get("display_height",240)))*scale
 var extent=Vector2(height*float(item.get("sprite_aspect",1)),height)
 var pivot=item.get("anchor",[.5,1.0])
 var anchor=settings.get("anchor",[.5,.5])
 var angle=MapMaterialSpec.rotation(item)
 var origin=Vector2(item.position[0],item.position[1])+(extent*(Vector2(anchor[0],anchor[1])-Vector2(pivot[0],pivot[1]))).rotated(angle)
 settings.angle=float(settings.get("angle",90))+rad_to_deg(angle)
 var radius=float(settings.get("range",160))*scale
 settings.position=[origin.x,origin.y]
 if settings.get("pass_through_owner",false): settings["_receiver_item"]=item
 # Emit from the actual anchor. The user paints exclusions instead of an
 # automatic foot projection or global silhouette mask.
 settings.radius=[radius/1920,radius/1080]
 if settings.has("paint_frame"):
  var frame=settings.paint_frame
  settings.paint_frame=[float(item.position[0])+float(frame[0])*scale,float(item.position[1])+float(frame[1])*scale,float(frame[2])*scale,float(frame[3])*scale]
 settings.paint_rotation=rad_to_deg(angle)+float(settings.get("paint_angle",0))
 settings.paint_pivot=item.position.duplicate()
 settings.energy=float(settings.get("energy",.65))*float(item.get("opacity",1))
 return settings

static func lights(layout: Dictionary) -> Array:
 var result=[]
 for light in layout.get("lights",[]): result.append(resolve_light(layout,light))
 for item in layout.get("objects",[]):
  if str(item.get("type",""))=="light":
   for i in count(item): result.append(emitter(item,i,true))
 return result

static func binding_transform(layout: Dictionary,key: String) -> Dictionary:
 var item={}
 if key=="willow": item=layout.get("willow",{})
 else:
  for entry in layout.get("objects",[])+layout.get("plots",[]):
   if str(entry.id)==key: item=entry; break
 if item.is_empty() or not item.has("position"): return {}
 if str(item.get("type",""))=="background": return {"position":Vector2(960,540),"scale":1.0,"opacity":float(item.get("opacity",1))}
 return {"position":Vector2(item.position[0],item.position[1]),"scale":float(item.get("scale",1)),"opacity":float(item.get("opacity",1)),"rotation":MapMaterialSpec.rotation(item)}

static func resolve_light(layout: Dictionary,light: Dictionary) -> Dictionary:
 var result=light.duplicate(true)
 var binding=binding_transform(layout,str(light.get("parent_key","")))
 if binding.is_empty(): return result
 if light.get("pass_through_owner",false):
  for item in layout.get("objects",[]):
   if str(item.id)==str(light.get("parent_key","")): result["_receiver_item"]=item; break
 var origin=binding.position as Vector2
 var scale=float(binding.scale)
 var offset=Vector2(light.position[0],light.position[1])
 var angle=float(binding.get("rotation",0))
 var position=origin+(offset*scale).rotated(angle)
 result.angle=float(light.get("angle",90))+rad_to_deg(angle)
 result.position=[position.x,position.y]
 result.radius=[float(light.radius[0])*scale,float(light.radius[1])*scale]
 result.energy=float(light.energy)*float(binding.opacity)
 if light.has("paint_frame"):
  var f=light.paint_frame
  result.paint_frame=[origin.x+float(f[0])*scale,origin.y+float(f[1])*scale,float(f[2])*scale,float(f[3])*scale]
 result.paint_rotation=rad_to_deg(angle)+float(light.get("paint_angle",0))
 result.paint_pivot=[origin.x,origin.y]
 return result

static func set_light_position(layout: Dictionary,light: Dictionary,position: Vector2) -> void:
 var binding=binding_transform(layout,str(light.get("parent_key","")))
 if not binding.is_empty(): position=(position-binding.position).rotated(-float(binding.get("rotation",0)))/float(binding.scale)
 light.position=[position.x,position.y]

static func remove_bound_lights(layout: Dictionary,key: String) -> void:
 for i in range(layout.get("lights",[]).size()-1,-1,-1):
  if str(layout.lights[i].get("parent_key",""))==key: layout.lights.remove_at(i)

static func apply_batch(material: ShaderMaterial,lights: Array,start: int=0,normalized: bool=false) -> void:
 var lamps=PackedVector4Array()
 var energies=PackedFloat32Array()
 var styles=PackedVector4Array()
 var colors=PackedVector4Array()
 for i in 4:
  var entry=lights[start+i] if start+i<lights.size() else {}
  var position=entry.get("position",[-19200,-10800])
  var radius=entry.get("radius",[1,1])
  var divisor=Vector2.ONE if normalized else Vector2(1920,1080)
  lamps.append(Vector4(float(position[0])/divisor.x,float(position[1])/divisor.y,float(radius[0]),float(radius[1])))
  energies.append(float(entry.get("energy",0)) if entry.get("enabled",true) else 0.0)
  var kind={"point":0.0,"spot":1.0,"directional":2.0}.get(str(entry.get("kind","point")),0.0)
  styles.append(Vector4(kind,deg_to_rad(float(entry.get("angle",90))),cos(deg_to_rad(float(entry.get("aperture",60))*.5)),1.0 if entry.get("night_only",true) else 0.0))
  var color=Color(str(entry.get("color","ffb45c")))
  colors.append(Vector4(color.r,color.g,color.b,1.0 if entry.get("flicker",false) else 0.0))
 material.set_shader_parameter("local_lamps",lamps)
 material.set_shader_parameter("local_lamp_energy",energies)
 material.set_shader_parameter("local_lamp_style",styles)
 material.set_shader_parameter("local_lamp_color",colors)
 apply_paint_batch(material,lights,start)

static var white_paint: ImageTexture
static func white_mask() -> ImageTexture:
 if white_paint==null:
  var image=Image.create(1,1,false,Image.FORMAT_L8)
  image.fill(Color.WHITE)
  white_paint=ImageTexture.create_from_image(image)
 return white_paint

static func valid_paint(settings: Dictionary) -> bool:
 if not _number(settings.get("paint_angle",0),-720,720): return false
 var path=settings.get("paint_mask","")
 if not path is String: return false
 if path.is_empty(): return not settings.has("paint_frame")
 if not path.begins_with("user://maps/materials/light-paint-") or path.contains("..") or path.get_extension()!="png": return false
 var frame=settings.get("paint_frame",[])
 if not frame is Array or frame.size()!=4: return false
 for value in frame:
  if not _number(value,-1000000,1000000): return false
 return float(frame[2])>0 and float(frame[3])>0

static func apply_paint_batch(material: ShaderMaterial,lights: Array,start: int) -> void:
 var rects=PackedVector4Array()
 var transforms=PackedVector4Array()
 var owners=PackedVector4Array()
 var owner_styles=PackedVector4Array()
 for i in 4:
  var entry=lights[start+i] if start+i<lights.size() else {}
  var owner=entry.get("_receiver_item",{})
  var owner_texture: Texture2D=null
  if not owner.is_empty(): owner_texture=ContentCatalog.prepared_texture(str(owner.get("texture","")),768)
  var height=float(owner.get("height",owner.get("display_height",240)))*float(owner.get("scale",1))
  var width=height*float(owner.get("sprite_aspect",1))
  var position=owner.get("position",[0,0])
  var anchor=owner.get("anchor",[.5,1])
  owners.append(Vector4(float(position[0]),float(position[1]),width,height))
  owner_styles.append(Vector4(float(anchor[0]),float(anchor[1]),MapMaterialSpec.rotation(owner),float(owner.get("opacity",1)) if owner_texture!=null else 0.0))
  material.set_shader_parameter("light_owner_%d" % i,owner_texture if owner_texture!=null else white_mask())
  var frame=entry.get("paint_frame",[0,0,1920,1080])
  rects.append(Vector4(float(frame[0])/1920,float(frame[1])/1080,float(frame[2])/1920,float(frame[3])/1080))
  var pivot=entry.get("paint_pivot",[0,0])
  transforms.append(Vector4(float(pivot[0])/1920,float(pivot[1])/1080,deg_to_rad(float(entry.get("paint_rotation",0))),0))
  var path=str(entry.get("paint_mask",""))
  var texture=ContentCatalog.prepared_texture(path,768) if not path.is_empty() else null
  material.set_shader_parameter("light_mask_%d" % i,texture if texture!=null else white_mask())
 material.set_shader_parameter("light_owner_rects",owners)
 material.set_shader_parameter("light_owner_styles",owner_styles)
 material.set_shader_parameter("light_mask_rects",rects)
 material.set_shader_parameter("light_mask_transforms",transforms)

static func paint_uv(light: Dictionary,point: Vector2) -> Vector2:
 var frame=light.get("paint_frame",[0,0,1920,1080])
 var p=light.get("paint_pivot",[0,0])
 var pivot=Vector2(p[0],p[1])
 point=pivot+(point-pivot).rotated(-deg_to_rad(float(light.get("paint_rotation",0))))
 return (point-Vector2(frame[0],frame[1]))/Vector2(frame[2],frame[3])

static func paint_image(light: Dictionary,size: Vector2i) -> Image:
 var image=Image.create(size.x,size.y,false,Image.FORMAT_L8)
 image.fill(Color.WHITE)
 var path=str(light.get("paint_mask",""))
 if path.is_empty() or not FileAccess.file_exists(path): return image
 var original=Image.load_from_file(path)
 if original==null: return image
 original.convert(Image.FORMAT_L8)
 for y in size.y:
  for x in size.x:
   var uv=paint_uv(light,Vector2((x+.5)*1920/size.x,(y+.5)*1080/size.y))
   if uv.x>=0 and uv.y>=0 and uv.x<=1 and uv.y<=1:
    image.set_pixel(x,y,original.get_pixel(clampi(int(uv.x*original.get_width()),0,original.get_width()-1),clampi(int(uv.y*original.get_height()),0,original.get_height()-1)))
 return image

static func merge_paint(light: Dictionary,edited: Image) -> Dictionary:
 # Keep painted areas that moved outside the map with their parent object.
 # Saving the visible map must not silently erase those off-canvas exclusions.
 var frame=Rect2(0,0,1920,1080)
 var old_frame=light.get("paint_frame",[0,0,1920,1080])
 var old_rect=Rect2(float(old_frame[0]),float(old_frame[1]),float(old_frame[2]),float(old_frame[3]))
 var p=light.get("paint_pivot",[0,0])
 var pivot=Vector2(p[0],p[1])
 var angle=deg_to_rad(float(light.get("paint_rotation",0)))
 var points=[old_rect.position,Vector2(old_rect.end.x,old_rect.position.y),old_rect.end,Vector2(old_rect.position.x,old_rect.end.y)]
 var old_bounds=Rect2(pivot+(points[0]-pivot).rotated(angle),Vector2.ZERO)
 for point in points: old_bounds=old_bounds.expand(pivot+(point-pivot).rotated(angle))
 var path=str(light.get("paint_mask",""))
 var old=Image.load_from_file(path) if not path.is_empty() and FileAccess.file_exists(path) else null
 if old==null or frame.encloses(old_bounds): return {"image":edited,"frame":[0,0,1920,1080]}
 old.convert(Image.FORMAT_L8)
 var bounds=frame.merge(old_bounds)
 var density=minf(edited.get_width()/1920.0,2048.0/maxf(bounds.size.x,bounds.size.y))
 var size=Vector2i(maxi(1,ceili(bounds.size.x*density)),maxi(1,ceili(bounds.size.y*density)))
 var output=Image.create(size.x,size.y,false,Image.FORMAT_L8)
 output.fill(Color.WHITE)
 for y in size.y:
  for x in size.x:
   var point=bounds.position+(Vector2(x+.5,y+.5)/Vector2(size))*bounds.size
   var image=edited if frame.has_point(point) else old
   var uv=point/frame.size if frame.has_point(point) else paint_uv(light,point)
   if uv.x<0 or uv.y<0 or uv.x>1 or uv.y>1: continue
   output.set_pixel(x,y,image.get_pixel(clampi(int(uv.x*image.get_width()),0,image.get_width()-1),clampi(int(uv.y*image.get_height()),0,image.get_height()-1)))
 return {"image":output,"frame":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]}

static func paint_files_exist(layout: Dictionary) -> bool:
 for light in lights(layout):
  var path=str(light.get("paint_mask",""))
  if not path.is_empty() and (not FileAccess.file_exists(path) or Image.load_from_file(path)==null): return false
 return true

static func state(item: Dictionary) -> Dictionary:
 var enabled=false
 var night_only=true
 for i in count(item):
  var light=source(item,i)
  if light.get("enabled",true):
   enabled=true
   if not light.get("night_only",true): night_only=false
 return {"enabled":enabled,"night_only":night_only}

static var night_previews={}
static func emission(day: Color,lit: Color) -> float:
 var warm=smoothstep(.08,.35,lit.r-lit.b)*smoothstep(.06,.28,lit.r-lit.g)
 var difference=maxf(0,lit.r-day.r)+maxf(0,lit.g-day.g)*.5
 return warm*smoothstep(.04,.3,difference)

static func night_preview(item: Dictionary) -> Texture2D:
 var key=str(item.texture)+str(item.get("night_texture",""))+str(item.get("emission_mask",""))+str(item.fixture.get("night_brightness",.55))
 if night_previews.has(key): return night_previews[key]
 var day=ContentCatalog.prepared_texture(item.texture,512).get_image()
 var lit=ContentCatalog.prepared_texture(item.night_texture,512).get_image()
 if day.is_compressed(): day.decompress()
 if lit.is_compressed(): lit.decompress()
 var mask=Image.load_from_file(str(item.get("emission_mask",""))) if FileAccess.file_exists(str(item.get("emission_mask",""))) else null
 var output=Image.create(lit.get_width(),lit.get_height(),false,Image.FORMAT_RGBA8)
 day.resize(lit.get_width(),lit.get_height())
 if mask!=null: mask.resize(lit.get_width(),lit.get_height())
 for y in lit.get_height():
  for x in lit.get_width():
   var color=lit.get_pixel(x,y)
   var weight=mask.get_pixel(x,y).r if mask!=null else emission(day.get_pixel(x,y),color)
   var brightness=float(item.fixture.get("night_brightness",.55))
   var shade=color*Color(.72*brightness,.83*brightness,brightness,1)
   output.set_pixel(x,y,shade.lerp(color,weight))
 if night_previews.size()>12: night_previews.clear()
 var texture=ImageTexture.create_from_image(output)
 night_previews[key]=texture
 return texture

static func receiver(_layout: Dictionary) -> ImageTexture:
 # Compatibility sampler for older callers. Each light now owns its painted
 # exclusion mask; no global silhouette or screen-height restrictions.
 return white_mask()
