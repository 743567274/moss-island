class_name MapMaterialSpec
extends RefCounted

const TYPES=["land","ground","grass","tree","cloud","fog","water","building","decoration","background","light"]
const LABELS=["土地 · 普通态与选中态","地表 / 道路","草丛","环境树木","云层","雾气素材","水面贴图","建筑","装饰","背景","灯具 · 昼夜双贴图"]
const SHAPES=["square","circle","alpha"]
const SHAPE_LABELS=["方形（菱形投影）","圆形 / 椭圆","自定义（图片透明轮廓）"]
static var hit_masks={}

# soil-<hash> files are immutable copies created by _editable_soil, not imports.
static func uses_builtin_soil(surface: Dictionary) -> bool:
 return str(surface.get("texture","")).begins_with("user://maps/materials/soil-")

static func selection_texture(surface: Dictionary) -> String:
 var path=str(surface.get("selected_texture",""))
 if uses_builtin_soil(surface) and path.begins_with("user://maps/materials/soil-"): return ""
 return path

static func normalize(entry: Dictionary) -> Dictionary:
 var result=entry.duplicate(true)
 var old={"树木":"tree","草地":"ground","建筑":"building","云":"cloud","装饰":"decoration"}
 result.type=str(result.get("type",old.get(str(result.get("category","")),"decoration")))
 if not result.type in TYPES:
  result.type="decoration"
 result.shape=str(result.get("shape","alpha"))
 result.highlight=clampf(float(result.get("highlight",.12)),.02,.35)
 result.selected_texture=str(result.get("selected_texture",""))
 result.plant_anchor=result.get("plant_anchor",[.5,.5])
 result.display_height=float(result.get("display_height",140 if result.type=="land" else 240))
 result.anchor=result.get("anchor",[.5,.5] if result.type=="land" else [.5,1.0])
 result.motion_enabled=bool(result.get("motion_enabled",str(result.get("animation","static"))!="static"))
 result.animation=animation_for(result.type,result.motion_enabled)
 result.water=result.get("water",{"mask":"","angle":0.0,"speed":1.0,"feather":3.0}).duplicate(true)
 if result.type=="background":
  result.display_height=1080.0
  result.anchor=[.5,.5]
  result.motion_enabled=false
  result.animation="static"
 return result

static func background_rect(image_size: Vector2) -> Rect2:
 var extent=image_size.max(Vector2.ONE)
 var ratio=maxf(1920.0/extent.x,1080.0/extent.y)
 extent*=ratio
 return Rect2((Vector2(1920,1080)-extent)*.5,extent)

static func animation_for(type: String,enabled: bool) -> String:
 if not enabled:
  return "static"
 return {"tree":"wind","grass":"wind","cloud":"cloud","fog":"cloud","water":"water","light":"light"}.get(type,"static")

static func label(type: String) -> String:
 var index=TYPES.find(type)
 return LABELS[index] if index>=0 else "装饰"

static func can_animate(type: String) -> bool:
 return type in ["tree","grass","cloud","fog","water"]

static func contains(surface: Dictionary,uv: Vector2) -> bool:
 if uv.x<0 or uv.x>1 or uv.y<0 or uv.y>1:
  return false
 var delta=(uv-Vector2(.5,.5))*2
 match str(surface.get("shape","alpha")):
  "circle":
   return delta.length_squared()<=1
  "square":
   return absf(delta.x)+absf(delta.y)<=1
 var path=str(surface.get("texture",""))
 if path.is_empty():
  return false
 if not hit_masks.has(path):
  var texture=ContentCatalog.prepared_texture(path,256)
  if texture==null:
   return false
  var bitmap=BitMap.new()
  bitmap.create_from_image_alpha(texture.get_image(),.2)
  hit_masks[path]=bitmap
 var mask=hit_masks[path] as BitMap
 var size=mask.get_size()
 return mask.get_bitv(Vector2i(clampi(int(uv.x*size.x),0,size.x-1),clampi(int(uv.y*size.y),0,size.y-1)))

static func valid_surface(value: Variant) -> bool:
 if not value is Dictionary or not value.has_all(["texture","width","height","shape","highlight"]):
  return false
 if not _asset_path(str(value.texture)) or not str(value.shape) in SHAPES:
  return false
 if not _number(value.width,1,4096) or not _number(value.height,8,1080) or not _number(value.highlight,.02,.35):
  return false
 var selected=str(value.get("selected_texture",""))
 var anchor=value.get("plant_anchor",[.5,.5])
 if not anchor is Array or anchor.size()!=2 or not _number(anchor[0],0,1) or not _number(anchor[1],0,1):
  return false
 return selected.is_empty() or _asset_path(selected)

static func _asset_path(path: String) -> bool:
 return path.begins_with("user://maps/materials/") and not path.contains("..") and path.get_extension().to_lower()=="png"

static func _number(value: Variant,minimum: float,maximum: float) -> bool:
 return (value is float or value is int) and is_finite(float(value)) and float(value)>=minimum and float(value)<=maximum

static func valid_water(value: Variant) -> bool:
 if not value is Dictionary: return false
 var path=str(value.get("mask",""))
 return (path.is_empty() or _asset_path(path)) and _number(value.get("angle",0),-360,360) and _number(value.get("speed",1),0,3) and _number(value.get("feather",3),0,16)

static func shadow_offset(entry: Dictionary) -> Vector2:
 return Vector2.from_angle(deg_to_rad(float(entry.get("shadow_angle",90))))*float(entry.get("shadow_distance",0))

static func rotation(entry: Dictionary) -> float:
 return 0.0 if str(entry.get("type",""))=="background" else deg_to_rad(float(entry.get("rotation_degrees",0)))
