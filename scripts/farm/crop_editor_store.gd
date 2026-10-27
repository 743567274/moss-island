class_name CropEditorStore
extends RefCounted

const ROOT="user://crop-editor"
const INDEX=ROOT+"/index.json"
static var active_farm: Variant=null
const CROP_IDS=["seed","seed_dry","seed_dead","sprout","sprout_dry","sprout_dead","half","half_dry","half_dead","mature","harvested","withered"]
const CROP_NAMES=["种子","种子缺水","种子死亡","幼苗","幼苗缺水","幼苗枯萎","半成熟","半成熟缺水","半成熟枯萎","成熟","采收","残株枯萎"]
const TREE_IDS=["dormant","budbreak","sprouting","leafy","buds","flowering","fruit_set","young_fruit","swelling","mature","harvested","leaf_fall"]
const TREE_NAMES=["秃树/休眠","萌芽","发芽","展叶/正常","花苞","开花","谢花/坐果","小果","多果/膨果","成熟","采摘","凋零/落叶"]

static func index() -> Dictionary:
 var parsed=JSON.parse_string(FileAccess.get_file_as_string(INDEX)) if FileAccess.file_exists(INDEX) else {}
 return parsed if parsed is Dictionary else {}

static func overlay() -> void:
 for id in index():
  var path=str(index()[id])
  if path=="deleted":
   ContentCatalog.crops.erase(id)
   ContentCatalog.package_dirs.erase(id)
  else:
   var value=ContentCatalog.read_package(path)
   if not value.is_empty(): ContentCatalog.crops[id]=value

static func used(id: String) -> bool:
 if active_farm!=null and _references(active_farm.data,id): return true
 var paths=["user://farm.json","user://farm-collection.json"]
 for directory in ["user://maps/projects","user://maps/deleted-projects"]:
  for folder in DirAccess.get_directories_at(directory):
   paths.append(directory.path_join(folder).path_join("farm.json"))
   paths.append(directory.path_join(folder).path_join("farm-collection.json"))
 for path in paths:
  if FileAccess.file_exists(path) and _references(JSON.parse_string(FileAccess.get_file_as_string(path)),id): return true
 return false

static func _references(value: Variant,id: String) -> bool:
 if value is Dictionary:
  if str(value.get("crop",""))==id: return true
  if value.has("crops") and value.crops is Dictionary and value.crops.has(id): return true
  for child in value.values():
   if _references(child,id): return true
 elif value is Array:
  for child in value:
   if _references(child,id): return true
 return false

static func template(tree: bool=false) -> Dictionary:
 var value=ContentCatalog.crops.values()[0].duplicate(true) if not ContentCatalog.crops.is_empty() else JSON.parse_string(FileAccess.get_file_as_string("res://data/crops/corn/crop.json"))
 value.id="plant_"+str(Time.get_ticks_usec())
 value.name="新果树" if tree else "新作物"
 value.type="fruit_tree" if tree else "crop"
 value.description="自定义植物；阶段时间和温度为用户配置，不自动推定真实农艺参数。"
 value.assets={}
 value.stages=[]
 value.harvest={"yield":1,"unit":"个","repeatable":tree,"residue_sprite":"withered","residue_height":1.35,"picked_sprite":"harvested","picked_height":1.35,"residue_delay_seconds":86400,"mature_lifetime_seconds":604800}
 value.render.erase("atlas_reference_height")
 value.render.erase("atlas_reference_region_height")
 value.render.columns=1
 value.render.rows=1
 value.render.non_seed_scale=1.0
 return value

static func slots(value: Dictionary) -> Array:
 var tree=value.get("type","crop")=="fruit_tree"
 var ids=TREE_IDS if tree else CROP_IDS
 var names=TREE_NAMES if tree else CROP_NAMES
 var aliases=["seed","seed","seed_dead","seedling","seedling_dry","seedling_dead","juvenile","juvenile_dry","juvenile_dead","mature","picked","residue"]
 var result=[]
 for i in 12:
  var key=str(ids[i])
  var asset=value.assets.get(key,value.assets.get(aliases[i],{})).duplicate(true)
  if not asset.is_empty():
   asset.path=ContentCatalog.package_dirs.get(str(value.id),"").path_join(str(asset.file))
   asset.normalized=int(value.get("editor_canvas",0))==512
  var days=float([60,7,10,30,14,10,14,30,45,14,3,21][i]) if tree else 1.0
  var water=.2 if tree and i==0 else 2.0
  var death=0.0 if tree and i==0 else 7.0
  for stage in value.stages:
   if str(stage.sprite)==key or (not tree and str(stage.sprite)==str(aliases[i])):
    days=maxf(1,float(stage.seconds)/86400)
    water=float(stage.water_mm_per_day)
    death=float(stage.drought_death_seconds)/86400
    break
  var stored=value.get("editor_states",[])
  var settings=stored[i].duplicate(true) if stored.size()==12 else {"days":days,"water":water,"death_days":death,"min_c":float(value.get("temperature",{}).get("min_c",10)),"max_c":float(value.get("temperature",{}).get("max_c",30))}
  result.append({"id":key,"name":names[i],"asset":asset,"settings":settings})
 return result

static func save(value: Dictionary,states: Array,logo: Dictionary) -> String:
 var id=str(value.id)
 if not id.is_valid_identifier() or str(value.name).strip_edges().is_empty(): return "编号需为字母、数字、下划线，名称不能为空。"
 for key in ["harvest","render","watering","temperature"]:
  if not value.get(key) is Dictionary: return "参数必须为对象："+key
 var images=[]
 var maximum=1
 for state in states:
  var asset=state.asset
  if str(asset.get("path","")).is_empty(): return "请补齐12个状态图片："+str(state.name)
  var texture=ContentCatalog.prepared_texture(asset.path,2048,asset.get("region",[]))
  if texture==null: return "无法读取图片："+str(state.name)
  var image=texture.get_image()
  if image.is_compressed(): image.decompress()
  maximum=maxi(maximum,maxi(image.get_width(),image.get_height()))
  images.append(image)
 var directory=ROOT+"/packages/"+id+"/"+str(Time.get_ticks_usec())
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
 value=value.duplicate(true)
 value.assets={}
 value.stages=[]
 value.editor_states=[]
 var tree=value.type=="fruit_tree"
 var factor=480.0/maximum
 for i in 12:
  var state=states[i]
  var image=images[i]
  image.convert(Image.FORMAT_RGBA8)
  var frame: Image
  if state.asset.get("normalized",false) and image.get_size()==Vector2i(512,512):
   frame=image
  else:
   image.resize(maxi(1,roundi(image.get_width()*factor)),maxi(1,roundi(image.get_height()*factor)),Image.INTERPOLATE_LANCZOS)
   frame=Image.create(512,512,false,Image.FORMAT_RGBA8)
   frame.fill(Color.TRANSPARENT)
   frame.blit_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i((512-image.get_width())/2,480-image.get_height()))
  var file=str(state.id)+".png"
  var error=frame.save_png(directory.path_join(file))
  if error!=OK: return "图片写入失败："+error_string(error)
  value.assets[state.id]={"file":file,"scale":float(state.asset.get("scale",1)),"region":[0,0,1,1]}
  value.editor_states.append(state.settings.duplicate(true))
  if tree or i in [0,3,6,9]:
   var info=state.settings
   var mature=i==9
   var duration=float(info.days)*86400
   if not tree and mature: duration=0
   var dry=state.id if tree or mature else states[i+1].id
   var dead="leaf_fall" if tree else ("withered" if mature else states[i+2].id)
   value.stages.append({"id":state.id,"name":state.name,"seconds":duration,"sprite":state.id,"dry_sprite":dry,"dead_sprite":dead,"height":1.35,"water_mm_per_day":float(info.water),"drought_death_seconds":float(info.death_days)*86400,"harvestable":mature,"temperature":{"min_c":info.min_c,"max_c":info.max_c}})
 value.duration=0.0
 for stage in value.stages: value.duration+=float(stage.seconds)
 value.render.erase("atlas_reference_height")
 value.render.erase("atlas_reference_region_height")
 value.render.anchor_y=.9375
 value.render.non_seed_scale=1.0
 value.editor_canvas=512
 value.cycle_stages=tree
 value.harvest.repeatable=tree
 value.harvest.residue_sprite="leaf_fall" if tree else "withered"
 value.harvest.picked_sprite="harvested"
 value.harvest.picked_height=1.35
 value.harvest.residue_height=1.35
 if tree:
  value.harvest.regrow_stage="harvested"
  value.harvest.mature_lifetime_seconds=0
  value.dormancy_max_c=float(value.get("dormancy_max_c",5))
  value.dormancy_min_c=float(value.get("dormancy_min_c",-15))
 value.icon="mature"
 if not str(logo.get("path","")).is_empty():
  var icon=ContentCatalog.prepared_texture(logo.path,256,logo.get("region",[]))
  if icon==null: return "Logo 无法读取。"
  var error=icon.get_image().save_png(directory+"/icon.png")
  if error!=OK: return "Logo 保存失败。"
  value.assets.icon={"file":"icon.png","scale":1.0,"region":[0,0,1,1]}
  value.icon="icon"
 if not ContentCatalog.valid_crop(value): return "参数组合无效：检查温度上下限、阶段时间、水量阈值和收获设置。"
 if ContentCatalog.crops.has(id) and used(id):
  var old=ContentCatalog.crops[id]
  if old.type!=value.type or not is_equal_approx(float(old.duration),float(value.duration)): return "此植物仍被种植/库存引用，暂不能修改类型或总周期。请先清理相关存档中的种植和库存，或另建植物。"
 var error=MapLayoutStore.write_json(directory+"/crop.json",value)
 if error!=OK: return "配置保存失败。"
 var registry=index()
 registry[id]=directory+"/crop.json"
 error=MapLayoutStore.write_json(INDEX,registry)
 return "" if error==OK else "索引保存失败。"

static func remove(id: String) -> String:
 if used(id): return "此植物仍被种植、库存或地图归档引用，不能删除。"
 var registry=index()
 registry[id]="deleted"
 return "" if MapLayoutStore.write_json(INDEX,registry)==OK else "删除失败。"
