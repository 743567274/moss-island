class_name FarmState
extends RefCounted

const VERSION=6
const PLOT_COUNT=18
const MAX_OFFLINE=30.0*86400.0
static var CROPS: Dictionary:
	get:
		ContentCatalog.load_catalog()
		return ContentCatalog.crops
var data: Dictionary
var clock_notice=""
var temperature=20.0
var temperature_from=0.0
var temperature_until=0.0
var rain_code=-1
var rain_valid_until=0.0

static func empty_plot(index: int) -> Dictionary:
	return {"id":index,"crop":"","growth":0.0,"age":0.0,"stress":0.0,"health":"healthy","water_mm":0.0,"dry_seconds":0.0,"last_watered":0.0}

func _init(now: float=0.0,plot_count: int=PLOT_COUNT) -> void:
	ContentCatalog.load_catalog()
	if now==0:
		now=Time.get_unix_time_from_system()
	data={"version":VERSION,"id":"%s-%s" % [int(now),randi()],"created_at":now,"last_tick":now,"updated_at":now,"rate":1.0,"paused":false,"offline_cap_days":0,"harvested":0,"plots":[],"decorations":[],"collection":{"crops":{},"discovered":[]}}
	for i in plot_count:
		data.plots.append(empty_plot(i))

func settle(now: float) -> float:
	var previous=float(data.last_tick)
	var delta=now-float(data.last_tick)
	clock_notice=""
	if delta<0:
		clock_notice="系统时间回退，成长等待时钟恢复"
		return 0.0
	data.last_tick=now
	for plot in data.plots:
		if not CROPS.has(plot.crop) or plot.health=="dead":
			continue
		if plot.health=="harvested":
			var delay=float(CROPS[plot.crop].harvest.get("residue_delay_seconds",0))
			plot.post_harvest_seconds=minf(delay,float(plot.get("post_harvest_seconds",0))+delta)
			continue
		var config=CROPS[plot.crop]
		var rain=0.0
		# Only the currently observed online interval receives rain. No historical weather is invented.
		if delta<=config.watering.observed_weather_max_seconds and now<=rain_valid_until:
			rain=float(config.watering.rain_mm_per_hour.get(str(rain_code),0))*float(config.watering.rain_absorption)/3600.0
		var observed_start=maxf(previous,temperature_from)
		var observed_end=minf(now,temperature_until)
		if observed_end>observed_start:
			_advance(plot,config,observed_start-previous,rain)
			_advance(plot,config,observed_end-observed_start,rain,true)
			_advance(plot,config,now-observed_end,rain)
		else:
			_advance(plot,config,delta,rain)
	return delta

func _advance(plot: Dictionary,config: Dictionary,seconds: float,rain: float,observed_temperature: bool=false) -> void:
	var left=seconds
	var w=config.watering
	while left>0.000001 and not plot.health in ["dead","harvested"]:
		var cyclic=config.get("type","crop")=="fruit_tree" and config.get("cycle_stages",false)
		var dormant=cyclic and observed_temperature and temperature<=float(config.get("dormancy_max_c",5)) and temperature>=float(config.get("dormancy_min_c",-15))
		if dormant:
			plot.growth=0.0
			plot.mature_seconds=0.0
		var index=stage(plot)
		var spec=config.stages[index]
		var end=0.0
		for i in index+1:
			end+=float(config.stages[i].seconds)
		var use=float(spec.water_mm_per_day)/86400.0-rain
		var wet=plot.water_mm>float(w.growth_min_mm)+.000001 or (use<=0 and plot.water_mm>=float(w.growth_min_mm))
		var rate=1.0 if wet else float(w.dry_growth_factor)
		var climate=config.get("temperature",{})
		var thermal=observed_temperature and not climate.is_empty()
		var unsuitable=thermal and not dormant and not temperature_suitable(plot)
		if dormant: rate=0.0
		if unsuitable:
			rate*=float(climate.unsuitable_growth_factor)
		var step=left
		var mature_limit=float(config.harvest.get("mature_lifetime_seconds",0))
		if spec.get("harvestable",false) and mature_limit>0:
			step=minf(step,maxf(.000001,mature_limit-float(plot.get("mature_seconds",0))))
		if rate>0 and spec.seconds>0:
			step=minf(step,maxf(.000001,(end-plot.growth)/rate))
		if use>0:
			for threshold in [float(w.warning_mm),float(w.growth_min_mm),0.0]:
				if plot.water_mm>threshold+.000001:
					step=minf(step,(plot.water_mm-threshold)/use)
		elif use<0:
			for threshold in [float(w.growth_min_mm)+.00001,float(w.warning_mm)+.00001,float(w.capacity_mm)]:
				if plot.water_mm<threshold-.000001:
					step=minf(step,(threshold-plot.water_mm)/-use)
		var drought=not dormant and plot.water_mm<=.000001 and use>=0
		var death=float(spec.drought_death_seconds)
		if unsuitable:
			step=minf(step,maxf(.000001,float(climate.stress_death_seconds)-float(plot.get("thermal_stress_seconds",0))))
		if drought and death>0:
			step=minf(step,maxf(.000001,death-plot.dry_seconds))
		plot.growth=minf(float(config.duration),plot.growth+step*rate)
		if cyclic:
			if index==9 and stage(plot)==10:
				plot.growth+=float(config.stages[10].seconds)
			if plot.growth>=float(config.duration)-.000001:
				plot.growth=0.0
				plot.mature_seconds=0.0
		plot.age+=step
		if spec.get("harvestable",false) and mature_limit>0:
			plot.mature_seconds=float(plot.get("mature_seconds",0))+step
		plot.water_mm=clampf(plot.water_mm-step*use,0,float(w.capacity_mm))
		plot.dry_seconds=plot.dry_seconds+step if drought else 0.0
		if thermal:
			plot.temperature_wilted=unsuitable
			plot.thermal_stress_seconds=maxf(0,float(plot.get("thermal_stress_seconds",0))+step*(1.0 if unsuitable else -float(climate.recovery_per_second)))
		left-=step
		if (mature_limit>0 and float(plot.get("mature_seconds",0))>=mature_limit-.000001) or (death>0 and plot.dry_seconds>=death-.000001) or (unsuitable and plot.thermal_stress_seconds>=float(climate.stress_death_seconds)-.000001):
			plot.health="dead"
		else:
			plot.health="wilted" if plot.get("temperature_wilted",false) or (plot.water_mm<=float(w.warning_mm) and float(spec.water_mm_per_day)>0) else "healthy"

func temperature_suitable(plot: Dictionary,planting: bool=false) -> bool:
	var config=CROPS[plot.crop]
	var climate=config.get("temperature",{})
	if climate.is_empty():
		return true
	var seed=planting or config.stages[stage(plot)].get("id","")=="seed"
	var limits=config.stages[stage(plot)].get("temperature",climate)
	return temperature>=float(climate.sowing_min_c if seed else limits.min_c) and temperature<=float(climate.sowing_max_c if seed else limits.max_c)

static func sowing_notice(crop_id: String,now: float) -> String:
	var sowing=CROPS[crop_id].get("sowing",{})
	if sowing.is_empty():
		return ""
	# All supported Chinese county locations use China Standard Time.
	var month=int(Time.get_datetime_dict_from_unix_time(int(now)+28800).month)
	return "" if month in sowing.recommended_months else "当前不在建议播期，可按当地气候种植。"

func water(index: int,now: float) -> bool:
	settle(now)
	if index<0 or index>=data.plots.size():
		return false
	var p=data.plots[index]
	if not CROPS.has(p.crop) or p.health in ["dead","harvested"]:
		return false
	var w=CROPS[p.crop].watering
	if p.water_mm>=w.capacity_mm:
		return false
	p.water_mm=minf(w.capacity_mm,p.water_mm+w.per_action_mm)
	p.last_watered=now
	p.dry_seconds=0.0
	p.health="wilted" if p.get("temperature_wilted",false) or p.water_mm<=w.warning_mm else "healthy"
	return true

func set_rate(_value: float,now: float) -> void:
	settle(now)
	data.rate=1.0

func set_paused(_value: bool,now: float) -> void:
	settle(now)
	data.paused=false

func progress(plot: Dictionary) -> float:
	return clampf(float(plot.growth)/float(CROPS[plot.crop].duration),0,1) if CROPS.has(plot.crop) else 0.0

func stage(plot: Dictionary) -> int:
	if not CROPS.has(plot.crop):
		return 0
	var stages=CROPS[plot.crop].stages
	var remaining=float(plot.growth)
	for i in stages.size():
		if remaining<float(stages[i].seconds)-.000001 or i==stages.size()-1:
			return i
		remaining-=float(stages[i].seconds)
	return stages.size()-1

func appearance(plot: Dictionary) -> Dictionary:
	var config=CROPS[plot.crop]
	var spec=config.stages[stage(plot)]
	var key=str(spec.sprite)
	var height=float(spec.height)
	if plot.health=="harvested":
		key=config.harvest.residue_sprite
		height=config.harvest.residue_height
		if float(plot.get("post_harvest_seconds",0))<float(config.harvest.get("residue_delay_seconds",0)):
			key=config.harvest.picked_sprite
			height=config.harvest.picked_height
	elif plot.health=="dead":
		key=spec.dead_sprite
	elif plot.health=="wilted":
		key=spec.dry_sprite
	if config.render.has("atlas_reference_height"):
		height=float(config.render.atlas_reference_height)*float(config.assets[key].region[3])/float(config.render.atlas_reference_region_height)
	if spec.get("id","")!="seed":
		height*=float(config.render.get("non_seed_scale",1.0))
	return {"asset":key,"height":height*float(config.assets[key].scale)}

func harvestable(plot: Dictionary) -> bool:
	return CROPS.has(plot.crop) and not plot.health in ["dead","harvested"] and CROPS[plot.crop].stages[stage(plot)].get("harvestable",false)

func plant(index: int,crop: String,now: float) -> bool:
	settle(now)
	if index<0 or index>=data.plots.size() or not CROPS.has(crop) or data.plots[index].crop!="":
		return false
	var p=empty_plot(index)
	if data.plots[index].has("map_plot_id"):
		p.map_plot_id=data.plots[index].map_plot_id
	p.crop=crop
	p.water_mm=float(CROPS[crop].watering.initial_mm)
	p.last_watered=0.0
	data.plots[index]=p
	if now>=temperature_from and now<=temperature_until and not temperature_suitable(p,true):
		p.temperature_wilted=true
		p.health="wilted"
	return true

func harvest(index: int,now: float) -> bool:
	settle(now)
	if index<0 or index>=data.plots.size() or not harvestable(data.plots[index]):
		return false
	var p=data.plots[index]
	var record=data.collection.crops.get(p.crop,{"count":0,"first_harvest":now})
	record.count+=int(CROPS[p.crop].harvest.yield)
	data.collection.crops[p.crop]=record
	if not p.crop in data.collection.discovered:
		data.collection.discovered.append(p.crop)
	var config=CROPS[p.crop]
	if config.get("type","crop")=="fruit_tree" and config.harvest.get("repeatable",false):
		p.growth=0.0
		for spec in config.stages:
			if spec.get("id","")==config.harvest.regrow_stage:
				break
			p.growth+=float(spec.seconds)
		p.mature_seconds=0.0
		p.health="wilted" if p.get("temperature_wilted",false) or p.water_mm<=config.watering.warning_mm else "healthy"
	else:
		p.health="harvested"
		p.post_harvest_seconds=0.0
	data.harvested+=1
	return true

func clear_dead(index: int) -> bool:
	if index<0 or index>=data.plots.size() or not data.plots[index].health in ["dead","harvested"]:
		return false
	var key=data.plots[index].get("map_plot_id","")
	data.plots[index]=empty_plot(index)
	if not str(key).is_empty():
		data.plots[index].map_plot_id=key
	return true

func ready_count() -> int:
	var count=0
	for plot in data.plots:
		if harvestable(plot):
			count+=1
	return count

static func valid(d: Variant) -> bool:
	ContentCatalog.load_catalog()
	if not d is Dictionary or not d.has_all(["version","id","created_at","last_tick","updated_at","rate","paused","harvested","plots","decorations","collection"]):
		return false
	if d.version!=VERSION or not d.id is String or not d.paused is bool or not d.collection is Dictionary or not d.collection.has_all(["crops","discovered"]):
		return false
	if d.has("map_project") and (not d.map_project is String or str(d.map_project).is_empty() or not d.get("map_archive",{}) is Dictionary):
		return false
	if d.has("creatures") or d.has("orchard") or d.collection.has("products") or not CollectionStore.valid_collection(d.collection):
		return false
	for key in ["created_at","last_tick","updated_at","rate","harvested"]:
		if not ContentCatalog.positive(d[key],true):
			return false
	if d.rate!=1.0 or d.paused or d.last_tick<1 or not d.plots is Array or (d.plots.size()>128 if d.has("map_project") else d.plots.size()!=PLOT_COUNT) or not d.decorations is Array:
		return false
	for i in d.plots.size():
		var p=d.plots[i]
		if not p is Dictionary or p.get("id",-1)!=i or not p.get("crop") is String or (p.crop!="" and not CROPS.has(p.crop)):
			return false
		for key in ["growth","age","stress","water_mm","dry_seconds","last_watered"]:
			if not ContentCatalog.positive(p.get(key),true):
				return false
		if not p.get("health") in ["healthy","wilted","dead","harvested"]:
			return false
		if not ContentCatalog.positive(p.get("post_harvest_seconds",0),true):
			return false
		if not ContentCatalog.positive(p.get("mature_seconds",0),true):
			return false
		if not ContentCatalog.positive(p.get("thermal_stress_seconds",0),true) or not p.get("temperature_wilted",false) is bool:
			return false
		if p.crop!="" and (p.growth>CROPS[p.crop].duration+.001 or p.water_mm>CROPS[p.crop].watering.capacity_mm+.001):
			return false
	return true

func bind_map(project_id: String,layout: Dictionary) -> void:
	var by_id={}
	for i in data.plots.size():
		var p=data.plots[i]
		var key=str(p.get("map_plot_id","plot-%d" % i))
		by_id[key]=p
	# Retired beds remain archived, so undoing a layout change never clones a
	# harvest or silently destroys a crop. Time advances before retiring them.
	var archive=data.get("map_archive",{}).duplicate(true)
	for key in by_id:
		if not str(by_id[key].crop).is_empty():
			archive[key]=by_id[key].duplicate(true)
		else:
			archive.erase(key)
	var current=[]
	for i in layout.get("plots",[]).size():
		var key=str(layout.plots[i].id)
		var p=archive.get(key,empty_plot(i)).duplicate(true)
		p.id=i
		p.map_plot_id=key
		archive.erase(key)
		current.append(p)
	data.map_project=project_id
	data.map_archive=archive
	data.plots=current
