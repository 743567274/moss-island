class_name MapLayoutStore
extends RefCounted

# A layout overlays the bundled map. Plot IDs deliberately retain the existing
# save slots; changing a transform never creates or clears a planted plot.
const DIRECTORY="user://maps"
const APPLIED=DIRECTORY+"/active-layout.json"
const DRAFT=DIRECTORY+"/draft-layout.json"
const LIBRARY=DIRECTORY+"/materials.json"
static var layout: Dictionary={}

static func load_active() -> void:
 layout=read_layout(APPLIED)

static func read_layout(path: String) -> Dictionary:
 if not FileAccess.file_exists(path):
  return {}
 var parsed=JSON.parse_string(FileAccess.get_file_as_string(path))
 return parsed if valid(parsed) else {}

static func valid(value: Variant) -> bool:
 if not value is Dictionary or not int(value.get("version",0)) in [1,2]:
  return false
 if not value.has_all(["plots","objects","willow","lights"]) or str(value.get("map_id",""))!="lakeside":
  return false
 var modern=int(value.version)==2
 if modern and (not value.get("project_id","") is String or not str(value.get("scene_mode","")) in ["reference","blank"]):
  return false
 if not value.get("plots") is Array or (value.plots.size()>128 if modern else value.plots.size()!=18) or not value.get("objects",[]) is Array:
  return false
 var seen={}
 if value.has("water_region") and not MapMaterialSpec.valid_water(value.water_region):
  return false
 if not _number(value.get("fog_opacity",.65),0,1) or not _number(value.get("fog_speed",1),0,3):
  return false
 var order=value.get("layer_order",[])
 if not order is Array or order.size()>258:
  return false
 var ordered={}
 for key in order:
  if not key is String or key.length()>100 or ordered.has(key):
   return false
  ordered[key]=true
 for p in value.plots:
  if not p is Dictionary or not p.has_all(["id","position","scale"]):
   return false
  var id=str(p.id)
  if seen.has(id) or not id.begins_with("plot-") or id.length()>100:
   return false
  if not modern and (not id.trim_prefix("plot-").is_valid_int() or int(id.trim_prefix("plot-"))>=18):
   return false
  if not _pair(p.position) or not _number(p.scale,.3,3.0):
   return false
  seen[id]=true
  if not _appearance(p):
   return false
  if p.has("surface") and not MapMaterialSpec.valid_surface(p.surface):
   return false
  if p.has("basis_a") and (not _pair(p.basis_a) or not _pair(p.get("basis_b"))):
   return false
 if value.objects.size()>128:
  return false
 var object_ids={}
 for item in value.objects:
  if not item is Dictionary or not item.has_all(["id","texture","position","height","scale","anchor","animation","category"]):
   return false
  if object_ids.has(str(item.id)) or not _pair(item.position) or not _pair(item.anchor) or not _number(item.height,8,1080) or not _number(item.scale,.1,5):
   return false
  object_ids[str(item.id)]=true
  if not _appearance(item):
   return false
  if not str(item.get("emission_mask","")).is_empty() and not _asset_path(str(item.emission_mask)): return false
  if not MapMaterialSpec.valid_water(item.get("water",{})):
   return false
  if item.has("fixture") and (str(item.get("type",""))!="light" or not MapLightFixture.valid(item)):
   return false
  if not str(item.animation) in ["static","wind","cloud","water","light"] or not _asset_path(str(item.texture)):
   return false
 var willow=value.get("willow",{})
 if not willow is Dictionary:
  return false
 if not _appearance(willow):
  return false
 if not willow.is_empty() and (not _pair(willow.get("position")) or not _number(willow.get("scale"),.3,3)):
  return false
 var lights=value.get("lights",[])
 if not lights is Array:
  return false
 for light in lights:
  if light is Dictionary and not MapLightFixture.valid_paint(light): return false
  if light is Dictionary:
   var parent=light.get("parent_key","")
   if not parent is String: return false
   if not parent.is_empty() and MapLightFixture.binding_transform(value,parent).is_empty(): return false
  if not light is Dictionary: return false
  var position=light.get("position")
  var position_valid=_pair(position)
  if not str(light.get("parent_key","")).is_empty():
   position_valid=position is Array and position.size()==2 and _number(position[0],-1000000,1000000) and _number(position[1],-1000000,1000000)
  if not position_valid or not _pair(light.get("radius")) or not _number(light.get("energy"),0,4):
   return false
  if float(light.radius[0])<=0 or float(light.radius[1])<=0:
   return false
  if not str(light.get("kind","point")) in ["point","spot","directional"] or not _number(light.get("angle",0),-360,360) or not _number(light.get("aperture",60),5,175):
   return false
  if not light.get("night_only",true) is bool or not light.get("enabled",true) is bool or not light.get("flicker",false) is bool or not light.get("editor_locked",false) is bool:
   return false
  if not Color.html_is_valid(str(light.get("color","ffb45c"))):
   return false
 return true

static func _appearance(value: Dictionary) -> bool:
 if not _number(value.get("rotation_degrees",0),-360,360): return false
 return _number(value.get("shadow_distance",0),-240,240) and _number(value.get("shadow_angle",90),-360,360) and value.get("editor_locked",false) is bool and _number(value.get("opacity",1),0,1) and _number(value.get("shadow_strength",0),0,.8) and _number(value.get("shadow_scale",1),.2,3)

static func _number(value: Variant,minimum: float,maximum: float) -> bool:
 return (value is float or value is int) and is_finite(float(value)) and float(value)>=minimum and float(value)<=maximum

static func _pair(value: Variant) -> bool:
 return value is Array and value.size()==2 and _number(value[0],-4096,8192) and _number(value[1],-4096,8192)

static func _asset_path(path: String) -> bool:
 return path.begins_with("user://maps/materials/") and not path.contains("..") and path.get_extension().to_lower()=="png"

static func write_json(path: String,value: Variant) -> Error:
 var directory=ProjectSettings.globalize_path(path.get_base_dir())
 var result=DirAccess.make_dir_recursive_absolute(directory)
 if result!=OK:
  return result
 var temporary=path+".tmp"
 var file=FileAccess.open(temporary,FileAccess.WRITE)
 if file==null:
  return FileAccess.get_open_error()
 file.store_string(JSON.stringify(value,"\t"))
 file.flush()
 var error=file.get_error()
 file.close()
 if error!=OK:
  return error
 if FileAccess.file_exists(path):
  result=DirAccess.copy_absolute(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path(path+".previous"))
  if result!=OK:
   return result
 return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(path))

static func apply(value: Dictionary) -> Error:
 if not valid(value):
  return ERR_INVALID_DATA
 if not MapLightFixture.paint_files_exist(value): return ERR_FILE_NOT_FOUND
 var region_path=str(value.get("water_region",{}).get("mask",""))
 if not region_path.is_empty() and not FileAccess.file_exists(region_path): return ERR_FILE_NOT_FOUND
 for item in value.objects:
  if not FileAccess.file_exists(item.texture):
   return ERR_FILE_NOT_FOUND
  if item.has("fixture") and not FileAccess.file_exists(str(item.get("night_texture",""))): return ERR_FILE_NOT_FOUND
 for p in value.plots:
  if p.has("surface"):
   if not FileAccess.file_exists(p.surface.texture):
    return ERR_FILE_NOT_FOUND
   var selected=str(p.surface.get("selected_texture",""))
   if not selected.is_empty() and not FileAccess.file_exists(selected):
    return ERR_FILE_NOT_FOUND
 var result=write_json(APPLIED,value)
 if result==OK:
  layout=value.duplicate(true)
 return result

static func plot(index: int) -> Dictionary:
 if int(layout.get("version",1))==2:
  return layout.plots[index] if index>=0 and index<layout.plots.size() else {}
 for item in layout.get("plots",[]):
  if str(item.id)=="plot-%d" % index:
   return item
 return {}

static func scale_for(index: int) -> float:
 return float(plot(index).get("scale",1.0))

static func defaults(map: Dictionary) -> Dictionary:
 var plots=[]
 for i in 18:
  var grid=map.grids["crops" if i<12 else "orchard"]
  var index=i if i<12 else i-12
  var a=Vector2(grid.basis_a[0],grid.basis_a[1])
  var b=Vector2(grid.basis_b[0],grid.basis_b[1])
  var offset=(a*(index%int(grid.columns))+b*floori(index/float(grid.columns)))*float(grid.spacing)
  plots.append({"id":"plot-%d" % i,"position":[float(grid.origin[0])*1920+offset.x/float(map.world_size[0])*1920,float(grid.origin[1])*1080+offset.y/float(map.world_size[1])*1080],"scale":1.0,"basis_a":grid.basis_a.duplicate(),"basis_b":grid.basis_b.duplicate()})
 var willow=map.get("willow",{})
 var lights=[]
 for light in map.lights:
  var copy=light.duplicate(true)
  copy.position=[float(light.position[0])*1920,float(light.position[1])*1080]
  lights.append(copy)
 return {"version":1,"map_id":"lakeside","plots":plots,"objects":[],"willow":{"position":[float(willow.root[0])*1920,float(willow.root[1])*1080],"scale":1.0},"lights":lights}

static func library() -> Array:
 if not FileAccess.file_exists(LIBRARY):
  return []
 var parsed=JSON.parse_string(FileAccess.get_file_as_string(LIBRARY))
 if not parsed is Array:
  return []
 var materials=[]
 for entry in parsed:
  if entry is Dictionary and entry.has_all(["id","texture","name","width","height"]):
   materials.append(MapMaterialSpec.normalize(entry))
 return materials

static func save_material(entry: Dictionary) -> Error:
 var materials=library()
 for i in materials.size():
  if materials[i].id==entry.id:
   materials[i]=entry.duplicate(true)
   return write_json(LIBRARY,materials)
 return ERR_DOES_NOT_EXIST

static func remove_material(id: String) -> Error:
 if id.begins_with("builtin-"): return ERR_UNAUTHORIZED
 var materials=library()
 for i in materials.size():
  if str(materials[i].id)==id:
   materials.remove_at(i)
   # Files may still be referenced by saved projects, drafts or undo history.
   # Delete the library record only; never remove their shared texture files.
   return write_json(LIBRARY,materials)
 return ERR_DOES_NOT_EXIST

static func remove_materials(ids: Array) -> Error:
 var materials=library()
 var remaining=materials.filter(func(entry): return not ids.has(str(entry.id)) or str(entry.id).begins_with("builtin-"))
 if remaining.size()==materials.size(): return ERR_DOES_NOT_EXIST
 return write_json(LIBRARY,remaining)

static func import_material(path: String,register: bool=true) -> Dictionary:
 var image=Image.load_from_file(path)
 if image==null or image.is_empty():
  return {"error":"无法读取图片，请选择 PNG、JPG 或 WebP。"}
 if maxi(image.get_width(),image.get_height())>8192:
  return {"error":"图片最长边不能超过8192像素。"}
 var original=FileAccess.get_file_as_bytes(path)
 var hash=HashingContext.new()
 hash.start(HashingContext.HASH_SHA256)
 hash.update(original)
 var id=hash.finish().hex_encode()
 var destination=DIRECTORY+"/materials/"+id+".png"
 var result=DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination.get_base_dir()))
 if result!=OK:
  return {"error":error_string(result)}
 result=image.save_png(destination)
 if result!=OK:
  return {"error":error_string(result)}
 if not register:
  return MapMaterialSpec.normalize({"id":id,"name":path.get_file().get_basename(),"texture":destination,"width":image.get_width(),"height":image.get_height()})
 var materials=library()
 for entry in materials:
  if entry.id==id:
   return entry
 var entry=MapMaterialSpec.normalize({"id":id,"name":path.get_file().get_basename(),"texture":destination,"width":image.get_width(),"height":image.get_height(),"source_height":image.get_height()})
 materials.append(entry)
 result=write_json(LIBRARY,materials)
 return entry if result==OK else {"error":error_string(result)}
