class_name ContentCatalog
extends RefCounted

static var crops: Dictionary={}
static var diagnostics: Array[String]=[]
static var textures: Dictionary={}
static var package_dirs: Dictionary={}

static func load_catalog() -> void:
	if not crops.is_empty() and not package_dirs.is_empty():
		return
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	if manifest is Dictionary:
		for bundled in manifest.get("crop_packages",[]):
			var external=OS.get_executable_path().get_base_dir().path_join("crops").path_join(str(bundled).get_base_dir().get_file()).path_join("crop.json")
			var path=external if not OS.has_feature("editor") and not "--bundled-crop-test" in OS.get_cmdline_user_args() and FileAccess.file_exists(external) else str(bundled)
			var value=read_package(path)
			if value.is_empty() and path!=str(bundled):
				value=read_package(str(bundled))
			if not value.is_empty():
				crops[value.id]=value
	CropEditorStore.overlay()
	if crops.is_empty():
		diagnostics.append("没有有效作物包；请检查 crops/corn/crop.json")

static func read_package(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var value=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not valid_crop(value):
		diagnostics.append("无效作物配置："+path)
		return {}
	for asset in value.assets.values():
		var image_path=path.get_base_dir().path_join(asset.file)
		if not FileAccess.file_exists(image_path) and not (image_path.begins_with("res://") and ResourceLoader.exists(image_path)):
			diagnostics.append("素材不存在："+str(asset.file))
			return {}
	package_dirs[value.id]=path.get_base_dir()
	return value

static func positive(value: Variant,allow_zero: bool=false) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and (value>=0 if allow_zero else value>0)

static func valid_crop(value: Variant) -> bool:
	if not value is Dictionary or value.get("schema_version")!=1 or not value.get("id") is String or not value.get("name") is String or value.get("clock")!="real":
		return false
	if value.id.is_empty() or not value.id.is_valid_identifier() or not value.get("assets") is Dictionary or not value.get("stages") is Array or value.stages.size()<2 or value.stages.size()>12:
		return false
	if not value.get("type","crop") in ["crop","fruit_tree"]:
		return false
	var sowing=value.get("sowing",{})
	if not sowing is Dictionary:
		return false
	if not sowing.is_empty():
		if not sowing.get("label") is String or not sowing.get("recommended_months") is Array or sowing.recommended_months.is_empty() or not sowing.get("badge","") is String:
			return false
		for month in sowing.recommended_months:
			if not positive(month) or month!=floor(month) or month>12:
				return false
	var climate=value.get("temperature",{})
	if not climate is Dictionary:
		return false
	if not climate.is_empty():
		for key in ["min_c","max_c","sowing_min_c","sowing_max_c"]:
			if not (climate.get(key) is int or climate.get(key) is float) or not is_finite(float(climate[key])):
				return false
		if climate.min_c>=climate.max_c or climate.sowing_min_c>=climate.sowing_max_c:
			return false
		for key in ["stress_death_seconds","recovery_per_second","unsuitable_growth_factor"]:
			if not positive(climate.get(key),key!="stress_death_seconds"):
				return false
		if climate.unsuitable_growth_factor>1:
			return false
	for key in value.assets:
		var a=value.assets[key]
		if not a is Dictionary or not a.get("file") is String or a.file.get_file()!=a.file or not a.file.to_lower().ends_with(".png") or not positive(a.get("scale")) or a.scale>10:
			return false
		if not a.get("atlas",false) is bool:
			return false
		if not a.get("region") is Array or a.region.size()!=4:
			return false
		for n in a.region:
			if not positive(n,true) or n>1:
				return false
		if a.region[2]<=0 or a.region[3]<=0 or a.region[0]+a.region[2]>1.00001 or a.region[1]+a.region[3]>1.00001:
			return false
	var seconds=0.0
	var stage_ids: Dictionary={}
	for i in value.stages.size():
		var stage=value.stages[i]
		if not stage is Dictionary or not stage.get("name") is String or not positive(stage.get("seconds"),i==value.stages.size()-1) or not positive(stage.get("height")) or not positive(stage.get("water_mm_per_day"),true) or not positive(stage.get("drought_death_seconds"),true):
			return false
		if not stage.get("id") is String or stage.id.is_empty() or stage_ids.has(stage.id):
			return false
		stage_ids[stage.id]=true
		if stage.has("temperature"):
			var limits=stage.temperature
			if not limits is Dictionary:
				return false
			for key in ["min_c","max_c"]:
				if not (limits.get(key) is int or limits.get(key) is float) or not is_finite(float(limits[key])):
					return false
			if limits.min_c>=limits.max_c:
				return false
		if value.get("type","crop")=="fruit_tree" and stage.id=="seed":
			return false
		for field in ["sprite","dry_sprite","dead_sprite"]:
			if not value.assets.has(stage.get(field,"")):
				return false
		seconds+=float(stage.seconds)
	var cyclic=value.get("type","crop")=="fruit_tree" and value.get("cycle_stages",false)
	var has_harvest=false
	for stage in value.stages: has_harvest=has_harvest or stage.get("harvestable",false)
	if not positive(value.get("duration")) or not is_equal_approx(seconds,value.duration) or (not cyclic and (value.stages[-1].seconds!=0 or not value.stages[-1].get("harvestable",false))) or (cyclic and (not has_harvest or value.stages[-1].seconds<=0)):
		return false
	if not value.get("watering") is Dictionary or not value.get("harvest") is Dictionary or not value.get("render") is Dictionary:
		return false
	var water=value.watering
	for key in ["capacity_mm","per_action_mm","observed_weather_max_seconds"]:
		if not positive(water.get(key)):
			return false
	for key in ["initial_mm","warning_mm","growth_min_mm","dry_growth_factor","rain_absorption"]:
		if not positive(water.get(key),true):
			return false
	if water.initial_mm>water.capacity_mm or water.warning_mm>=water.capacity_mm or water.growth_min_mm>=water.warning_mm or water.dry_growth_factor>1 or water.rain_absorption>1 or not water.get("rain_mm_per_hour") is Dictionary:
		return false
	for amount in water.rain_mm_per_hour.values():
		if not positive(amount,true):
			return false
	var harvest=value.get("harvest",{})
	if not positive(harvest.get("mature_lifetime_seconds",0),true):
		return false
	if not positive(harvest.get("yield")) or harvest.yield!=floor(harvest.yield) or not harvest.get("unit") is String or not positive(harvest.get("residue_height")) or not value.assets.has(harvest.get("residue_sprite","")) or not harvest.get("repeatable") is bool:
		return false
	if value.get("type","crop")=="crop" and harvest.repeatable:
		return false
	if value.get("type","crop")=="fruit_tree":
		if not harvest.repeatable or value.stages[0].get("id","")=="seed":
			return false
		var regrow=-1
		for i in value.stages.size()-1:
			if value.stages[i].get("id","")==harvest.get("regrow_stage",""):
				regrow=i
		if regrow<0:
			return false
	if not positive(harvest.get("residue_delay_seconds",0),true):
		return false
	if harvest.get("residue_delay_seconds",0)>0 and (not value.assets.has(harvest.get("picked_sprite","")) or not positive(harvest.get("picked_height"))):
		return false
	var render=value.get("render",{})
	if not positive(render.get("non_seed_scale",1.0)) or render.get("non_seed_scale",1.0)>10:
		return false
	var blending=render.get("art_blending",{})
	if not blending is Dictionary:
		return false
	for key in blending:
		if not key in ["style_saturation","style_contrast","texture_softness","paper_grain","phase_variation","root_detail","size_variation","wind_response"] or not positive(blending[key],true):
			return false
		var maximum=10.0 if key=="wind_response" else (.1 if key in ["size_variation","paper_grain"] else (1.0 if key=="root_detail" else 2.0))
		if float(blending[key])>maximum:
			return false
	if render.has("atlas_reference_height") or render.has("atlas_reference_region_height"):
		if not positive(render.get("atlas_reference_height")) or not positive(render.get("atlas_reference_region_height")) or render.atlas_reference_region_height>1:
			return false
	if not render.get("edge_cleanup",{}) is Dictionary:
		return false
	for key in render.get("edge_cleanup",{}):
		if not positive(render.edge_cleanup[key],true):
			return false
	for key in ["columns","rows","spacing_x","spacing_y","anchor_y","sway","seed_sway","shadow_scale"]:
		if not positive(render.get(key),key in ["sway","seed_sway","shadow_scale"]):
			return false
	return value.assets.has(value.get("icon","")) and render.columns==floor(render.columns) and render.rows==floor(render.rows) and render.columns*render.rows<=36

static func texture(crop_id: String,asset_id: String,max_size: int=512) -> Texture2D:
	load_catalog()
	var config=crops[crop_id]
	var path=str(package_dirs[crop_id]).path_join(config.assets[asset_id].file)
	var asset=config.assets[asset_id]
	return prepared_texture(path,max_size,asset.region if asset.get("atlas",false) else [],config.render.get("edge_cleanup",{}))

static func prepared_texture(path: String,max_size: int,frame: Array=[],cleanup: Dictionary={}) -> Texture2D:
	var cache_key=path+":"+str(max_size)+":"+JSON.stringify(frame)+":"+JSON.stringify(cleanup)
	if textures.has(cache_key):
		var cached=textures[cache_key].get_ref()
		if cached!=null:
			return cached
	for key in textures.keys():
		if textures[key].get_ref()==null:
			textures.erase(key)
	var image: Image
	var stamp=FileAccess.get_modified_time(OS.get_executable_path()) if path.begins_with("res://") else FileAccess.get_modified_time(path)
	var cache_directory="user://texture-cache-v2"
	var cached_image=cache_directory.path_join((cache_key+":"+str(stamp)).sha256_text()+".png")
	if FileAccess.file_exists(cached_image):
		image=Image.load_from_file(cached_image)
	if image!=null and image.is_empty():
		image=null
	var from_cache=image!=null
	if image==null and path.begins_with("res://"):
		var source=load(path) as Texture2D
		image=source.get_image() if source!=null else null
	elif image==null:
		image=Image.load_from_file(path)
	if image==null or image.is_empty():
		return null
	if image.is_compressed():
		image.decompress()
	if not from_cache and not frame.is_empty():
		var r=frame
		var bounds=Rect2i(roundi(r[0]*image.get_width()),roundi(r[1]*image.get_height()),roundi(r[2]*image.get_width()),roundi(r[3]*image.get_height()))
		image=image.get_region(bounds.intersection(Rect2i(Vector2i.ZERO,image.get_size())))
	if not from_cache:
		if image.has_mipmaps():
			image.clear_mipmaps()
		image.convert(Image.FORMAT_RGBA8)
		if not cleanup.is_empty():
			image=_remove_matte_fringe(image,cleanup)
		# Runtime-loaded crop packages bypass the editor's Fix Alpha Border import.
		image.fix_alpha_edges()
	var extent=maxi(image.get_width(),image.get_height())
	if extent>max_size:
		if image.has_mipmaps():
			image.clear_mipmaps()
		var ratio=float(max_size)/extent
		image.resize(maxi(1,roundi(image.get_width()*ratio)),maxi(1,roundi(image.get_height()*ratio)),Image.INTERPOLATE_BILINEAR)
	if not from_cache:
		image.fix_alpha_edges()
		DirAccess.make_dir_recursive_absolute(cache_directory)
		image.save_png(cached_image)
	if not image.has_mipmaps():
		image.generate_mipmaps()
	var result=ImageTexture.create_from_image(image)
	textures[cache_key]=weakref(result)
	return result

static func _remove_matte_fringe(image: Image,options: Dictionary) -> Image:
	# Trim pale background-removal residue only within a narrow transparent-edge
	# band. Interior white cotton bolls and the golden selection rim stay intact.
	var width=image.get_width()
	var height=image.get_height()
	var source=image.get_data()
	var alpha_floor=clampi(roundi(float(options.get("alpha_floor",0))*255),0,64)
	if alpha_floor>0:
		# Near-transparent extraction debris must not tint lower mip levels.
		for offset in range(0,source.size(),4):
			if source[offset+3]<alpha_floor:
				source[offset]=0
				source[offset+1]=0
				source[offset+2]=0
				source[offset+3]=0
	var output=source.duplicate()
	var radius=clampi(int(options.get("radius",3)),1,6)
	var light=clampi(roundi(float(options.get("light_min",.68))*255),0,255)
	var alpha_max=clampi(roundi(float(options.get("alpha_max",.94))*255),0,255)
	var saturation=clampi(roundi(float(options.get("saturation_max",.28))*255),0,255)
	for y in height:
		for x in width:
			var offset=(y*width+x)*4
			var alpha=source[offset+3]
			if alpha==0 or alpha>=alpha_max:
				continue
			var low=mini(source[offset],mini(source[offset+1],source[offset+2]))
			var high=maxi(source[offset],maxi(source[offset+1],source[offset+2]))
			if low<light or high-low>saturation:
				continue
			for step in [Vector2i(-radius,0),Vector2i(radius,0),Vector2i(0,-radius),Vector2i(0,radius),Vector2i(-2,-2),Vector2i(2,-2),Vector2i(-2,2),Vector2i(2,2)]:
				var nx=x+step.x
				var ny=y+step.y
				if nx<0 or ny<0 or nx>=width or ny>=height or source[(ny*width+nx)*4+3]<20:
					output[offset+3]=0
					break
	return Image.create_from_data(width,height,false,Image.FORMAT_RGBA8,output)

static func texture_region(crop_id: String,asset_id: String) -> Array:
	var asset=crops[crop_id].assets[asset_id]
	return [0.0,0.0,1.0,1.0] if asset.get("atlas",false) else asset.region

static func description(crop_id: String) -> String:
	var config=crops[crop_id]
	var tree=config.get("type","crop")=="fruit_tree"
	var text="%s · %s\n正常供水生长周期：约 %.1f 天" % [config.name,"果树（循环结果）" if tree else "作物（单次采收）",float(config.duration)/86400.0]
	var climate=config.get("temperature",{})
	if not climate.is_empty():
		text+="\n适宜生长温度：%.1f–%.1f°C\n适宜%s温度：%.1f–%.1f°C" % [climate.min_c,climate.max_c,"种下" if tree else "播种",climate.sowing_min_c,climate.sowing_max_c]
		text+="\n不适温耐受：%s小时\n达到上限后枯死" % String.num(float(climate.stress_death_seconds)/3600.0,1)
	if tree:
		var cycle=0.0
		var started=false
		for spec in config.stages:
			started=started or spec.get("id","")==config.harvest.regrow_stage
			if started:
				cycle+=float(spec.seconds)
		text+="\n再次结果周期：约 %.1f 天" % (cycle/86400.0)
	text+="\n每田 %d 株 · 每次收获 %d %s" % [config.render.columns*config.render.rows,config.harvest.yield,config.harvest.unit]
	var sowing=config.get("sowing",{})
	if not sowing.is_empty():
		var months=PackedStringArray()
		for month in sowing.recommended_months:
			months.append(str(int(month)))
		text+="\n建议播期：%s（%s月）" % [sowing.label,"、".join(months)]
		text+="\n月份仅供参考，适合当地气候时可播种。"
	for spec in config.stages:
		if spec.has("temperature"):
			text+="\n%s耐温：%.1f–%.1f°C" % [spec.name,spec.temperature.min_c,spec.temperature.max_c]
	return text

static func icon(crop_id: String) -> Texture2D:
	load_catalog()
	var config=crops[crop_id]
	var key=str(config.icon)
	var source=texture(crop_id,key,256)
	if source==null:
		return null
	var region=texture_region(crop_id,key)
	var atlas=AtlasTexture.new()
	atlas.atlas=source
	atlas.region=Rect2(region[0]*source.get_width(),region[1]*source.get_height(),region[2]*source.get_width(),region[3]*source.get_height())
	return atlas

static func export_crop(crop_id: String,path: String) -> Error:
	load_catalog()
	if not crops.has(crop_id):
		return ERR_INVALID_PARAMETER
	var config=crops[crop_id].duplicate(true)
	var directory=str(package_dirs[crop_id])
	var zip=ZIPPacker.new()
	var error=zip.open(path+".tmp")
	if error!=OK:
		return error
	error=zip.start_file("crop.json")
	if error==OK:
		error=zip.write_file(JSON.stringify(config,"\t").to_utf8_buffer())
	zip.close_file()
	var written: Dictionary={}
	for asset in config.assets.values():
		if written.has(asset.file):
			continue
		written[asset.file]=true
		if error!=OK:
			break
		error=zip.start_file(asset.file)
		if error==OK:
			var source_path=directory.path_join(asset.file)
			if not FileAccess.file_exists(source_path):
				source_path=directory.path_join("raw").path_join(asset.file+".bin")
			var bytes=FileAccess.get_file_as_bytes(source_path)
			error=zip.write_file(bytes) if not bytes.is_empty() else ERR_FILE_NOT_FOUND
		zip.close_file()
	var close_error=zip.close()
	if error!=OK or close_error!=OK:
		DirAccess.remove_absolute(path+".tmp")
		return error if error!=OK else close_error
	return DirAccess.rename_absolute(path+".tmp",path)
