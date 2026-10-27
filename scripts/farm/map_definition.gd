class_name MapDefinition
extends RefCounted

static var active: Dictionary={}
static var world_size=Vector2(32,18)

static func load_map() -> Dictionary:
 if not active.is_empty():
  return active
 var path=str(ProjectSettings.get_setting("farm/map_path","res://data/lakeside-map.json"))
 var parsed=JSON.parse_string(FileAccess.get_file_as_string(path))
 if not valid(parsed):
  push_warning("Invalid map definition; using bundled lakeside map: "+path)
  parsed=JSON.parse_string(FileAccess.get_file_as_string("res://data/lakeside-map.json"))
 active=parsed
 world_size=Vector2(active.world_size[0],active.world_size[1])
 MapLayoutStore.load_active()
 return active

static func valid(value: Variant) -> bool:
 if not value is Dictionary or not value.has_all(["id","world_size","grids","water","lights","background","companion"]):
  return false
 if not value.world_size is Array or value.world_size.size()!=2 or float(value.world_size[0])<=0 or float(value.world_size[1])<=0:
  return false
 if not value.grids is Dictionary or not value.grids.has_all(["crops","orchard"]):
  return false
 for kind in ["crops","orchard"]:
  var spec=value.grids[kind]
  if not spec is Dictionary or not spec.has_all(["origin","basis_a","basis_b","columns","rows","spacing"]):
   return false
  for field in ["origin","basis_a","basis_b"]:
   if not spec[field] is Array or spec[field].size()!=2:
    return false
  if int(spec.columns)<=0 or int(spec.rows)<=0 or int(spec.columns)*int(spec.rows)!=(12 if kind=="crops" else 6) or float(spec.spacing)<=1.0:
   return false
  var a=Vector2(spec.basis_a[0],spec.basis_a[1])
  var b=Vector2(spec.basis_b[0],spec.basis_b[1])
  if a.length()<.001 or not is_equal_approx(a.length(),b.length()) or absf(a.cross(b))<.001:
   return false
 if not value.water is Dictionary or not value.water.has_all(["points","widths","bridge_exclusion"]):
  return false
 if value.water.points.size()<2 or value.water.points.size()>8 or value.water.points.size()!=value.water.widths.size() or value.water.bridge_exclusion.size()!=4:
  return false
 for i in value.water.points.size():
  if value.water.points[i].size()!=2 or float(value.water.widths[i])<=0:
   return false
 if not value.lights is Array or value.lights.size()>4:
  return false
 for light in value.lights:
  if not light is Dictionary or not light.has_all(["id","position","radius","energy"]) or light.position.size()!=2 or light.radius.size()!=2:
   return false
  if float(light.radius[0])<=0 or float(light.radius[1])<=0:
   return false
 var blending=value.get("art_blending",{})
 if not blending is Dictionary:
  return false
 for key in blending:
  if not key in ["edge_grass","root_shadow_strength","soil_saturation","soil_contrast","paper_grain"] or not ContentCatalog.positive(blending[key],true):
   return false
  var maximum=.1 if key=="paper_grain" else (2.0 if key in ["soil_saturation","soil_contrast"] else 1.0)
  if float(blending[key])>maximum:
   return false
 return ResourceLoader.exists(str(value.background)) and ResourceLoader.exists(str(value.companion)) and (not value.has("night_background") or ResourceLoader.exists(str(value.night_background)))

static func grid(kind: String) -> Dictionary:
 return load_map().grids[kind]

static func center(kind: String, index: int) -> Vector3:
 var saved=MapLayoutStore.plot(index if kind=="crops" else index+12)
 if not saved.is_empty():
  return Vector3((float(saved.position[0])/1920-.5)*world_size.x,.59,(float(saved.position[1])/1080-.5)*world_size.y)
 var spec=grid(kind)
 var a=Vector2(spec.basis_a[0],spec.basis_a[1])
 var b=Vector2(spec.basis_b[0],spec.basis_b[1])
 var origin=Vector2(spec.origin[0],spec.origin[1])
 var offset=(a*(index%int(spec.columns))+b*floori(index/float(spec.columns)))*float(spec.spacing)
 return Vector3((origin.x-.5)*world_size.x+offset.x,.59,(origin.y-.5)*world_size.y+offset.y)

static func axes(kind: String, index: int=-1) -> Basis:
 var spec=grid(kind)
 if index>=0:
  var p=MapLayoutStore.plot(index if kind=="crops" else index+12)
  if p.has_all(["basis_a","basis_b"]):
   spec=p
 var a=Vector3(spec.basis_a[0],0,spec.basis_a[1])
 var b=Vector3(spec.basis_b[0],0,spec.basis_b[1])
 var scale=MapLayoutStore.scale_for(index if kind=="crops" else index+12) if index>=0 else 1.0
 return Basis(a*scale,Vector3.UP,b*scale)

static func local_position(kind: String, index: int, point: Vector3) -> Vector3:
 return axes(kind,index).inverse()*(point-center(kind,index))

static func plot_extent(index: int) -> Vector2:
 var p=MapLayoutStore.plot(index)
 if p.has("surface"):
  return Vector2(float(p.surface.width),float(p.surface.height))/60*float(p.scale)
 var basis=axes("crops" if index<12 else "orchard",index if index<12 else index-12)
 return Vector2(absf(basis.x.x)+absf(basis.z.x),absf(basis.x.z)+absf(basis.z.z))*1.06
