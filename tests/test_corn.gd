extends SceneTree
var passed=0
var failed=0
var t=1792500000.0
func check(value: bool,message: String) -> void:
	if value:
		passed+=1
		print("PASS ",message)
	else:
		failed+=1
		push_error(message)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var farm=FarmState.new(t)
	check(FarmState.CROPS.keys()==["corn"] and FarmState.valid(farm.data),"Only corn is enabled and new farm is valid")
	check(farm.data.plots.size()==18 and not farm.data.has("orchard") and farm.data.collection.crops.is_empty(),"All eighteen beds and warehouse start empty")
	var cfg=FarmState.CROPS.corn
	check(cfg.duration==120*86400 and cfg.stages.size()==6,"Configured real-time cycle is 120 days over six stages")
	check(cfg.assets.size()==12 and cfg.assets.values().all(func(a):return a.has("scale") and not a.has("scale_x") and not a.has("scale_y")),"Every original image has exactly one uniform scale")
	check(farm.plant(0,"corn",t) and farm.stage(farm.data.plots[0])==0,"Planting starts as a seed")
	check(not farm.plant(0,"corn",t) and not farm.plant(1,"carrot",t),"Occupied beds and removed species cannot be planted")
	farm.settle(t+3*86400)
	check(farm.data.plots[0].health=="dead" and farm.appearance(farm.data.plots[0]).asset=="seed_dead","Unwatered seed dies at its configured real drought deadline")
	check(not farm.water(0,t+3*86400) and not farm.harvest(0,t+3*86400),"Water cannot resurrect a dead seed and dead crops cannot be harvested")
	check(farm.clear_dead(0) and farm.data.plots[0].crop=="","Dead crop can be cleared")
	farm=FarmState.new(t)
	farm.plant(0,"corn",t)
	farm.water(0,t)
	farm.set_rate(5,t)
	farm.set_paused(true,t)
	farm.settle(t+86400)
	check(is_equal_approx(farm.data.plots[0].growth,86400) and farm.data.rate==1 and not farm.data.paused,"Corn always uses real seconds, ignoring legacy speed and pause")
	check(is_equal_approx(farm.data.plots[0].water_mm,28.5),"Seed stage consumes configured millimeters per real day")
	var now=t+86400
	for day in range(2,122):
		now=t+day*86400
		farm.water(0,now)
		if day==7:
			check(farm.stage(farm.data.plots[0])==1,"Seedling starts at seven real days")
		if day==21:
			check(farm.stage(farm.data.plots[0])==2,"Juvenile starts at twenty-one real days")
		if day==42:
			check(farm.stage(farm.data.plots[0])==3,"Adult starts at forty-two real days")
		if day==60:
			check(farm.stage(farm.data.plots[0])==4,"Fruiting starts at sixty real days")
		if day==119:
			check(not farm.harvestable(farm.data.plots[0]),"Cannot harvest a day before maturity")
		if day==120:
			check(farm.harvestable(farm.data.plots[0]),"Matures after 120 well-watered real days")
	check(farm.harvest(0,now) and farm.data.collection.crops.corn.count==cfg.harvest.yield,"Configured yield enters warehouse")
	check(farm.data.plots[0].health=="harvested" and farm.appearance(farm.data.plots[0]).asset=="residue","Harvest leaves the user supplied withered adult sprite")
	check(not farm.harvest(0,now) and not farm.plant(0,"corn",now),"Residue cannot be repeatedly harvested or overwritten")
	farm.clear_dead(0)
	check(farm.plant(0,"corn",now),"Clearing residue allows the next planting")
	var dry=FarmState.new(t)
	dry.plant(1,"corn",t)
	dry.data.plots[1].growth=8*86400
	dry.data.plots[1].water_mm=11
	dry.settle(t+86400)
	check(dry.data.plots[1].health=="wilted" and dry.appearance(dry.data.plots[1]).asset=="seedling_dry","Seedling uses its dedicated dry sprite")
	check(dry.water(1,t+86400) and dry.data.plots[1].health=="healthy","Timely irrigation restores a living dry seedling")
	var single=FarmState.new(t)
	single.plant(0,"corn",t)
	single.water(0,t)
	var many=FarmState.new(t)
	many.data=single.data.duplicate(true)
	single.settle(t+60*86400)
	for day in range(1,61):
		many.settle(t+day*86400)
	check(single.data.plots[0].health==many.data.plots[0].health and is_equal_approx(single.data.plots[0].growth,many.data.plots[0].growth),"Long offline settlement matches daily settlement without watering")
	check(single.data.plots[0].health=="dead","Offline absence includes water depletion and death")
	var rain_farm=FarmState.new(t)
	rain_farm.plant(0,"corn",t)
	rain_farm.rain_code=63
	rain_farm.rain_valid_until=t+3600
	rain_farm.settle(t+60)
	check(rain_farm.data.plots[0].water_mm>0,"Observed current rain replenishes soil according to crop configuration")
	var dry_rain=FarmState.new(t)
	dry_rain.plant(0,"corn",t)
	dry_rain.rain_code=65
	dry_rain.rain_valid_until=t+86400
	dry_rain.settle(t+3600)
	check(dry_rain.data.plots[0].water_mm==0,"Offline gaps never invent a historical hour of rainfall")
	var archive=CollectionStore.new("user://corn-old-collection.json")
	var old_stock={"version":1,"farm_id":"old","collection":{"crops":{"corn":{"count":900}},"discovered":["corn"]}}
	FileAccess.open(archive.path,FileAccess.WRITE).store_string(JSON.stringify({"payload":old_stock,"sha256":LocalSaveProvider.digest(old_stock)}))
	check(archive.load_collection("old").is_empty(),"Old independent collection cannot resurrect deleted corn stock")
	DirAccess.remove_absolute(archive.path)
	var high=many.data.last_tick
	many.settle(t)
	check(many.data.last_tick==high,"Clock rollback cannot double-grow or refill soil")
	var bad=cfg.duplicate(true)
	bad.assets.seed.scale=-1
	check(not ContentCatalog.valid_crop(bad),"Invalid per-image scaling is rejected")
	bad=cfg.duplicate(true)
	bad.duration=100
	check(not ContentCatalog.valid_crop(bad),"Stage durations must sum to maturity duration")
	var old={"version":5,"id":"legacy-corn","created_at":t,"last_tick":t,"updated_at":t,"rate":5.0,"paused":true,"harvested":99,"plots":[],"decorations":[],"collection":{"crops":{"corn":{"count":22}},"discovered":["corn"]},"orchard":[{"planted":true}]}
	for i in 12:
		old.plots.append({"id":i,"crop":"carrot","growth":100})
	var migrated=SaveManager.migrate_save(old)
	check(FarmState.valid(migrated) and migrated.id==old.id and migrated.plots.all(func(p):return p.crop=="") and migrated.collection.crops.is_empty() and migrated.harvested==0,"One-time v5 migration clears all old planting, citrus and inventory without changing farm identity")
	var save=LocalSaveProvider.new("user://corn-test-save.json")
	check(save.write_save(farm.data)==OK,"Corn water and growth state saves with checksum")
	var restored=save.read_save()
	check(restored!=null and restored.plots[0].crop=="corn","Restart keeps new planting instead of resetting again")
	var package_path="res://build/玉米.crop.zip"
	check(ContentCatalog.export_crop("corn",package_path)==OK,"Crop package exports to a portable ZIP")
	var reader=ZIPReader.new()
	var opened=reader.open(package_path)==OK
	check(opened and reader.get_files().size()==13,"Export contains one complete configuration and twelve images")
	var exported=JSON.parse_string(reader.read_file("crop.json").get_string_from_utf8()) if opened else null
	check(ContentCatalog.valid_crop(exported) and not exported.has("_package_dir") and exported.assets.seed.scale==cfg.assets.seed.scale,"Exported configuration is self-contained and preserves scale")
	var image_bytes=FileAccess.get_file_as_bytes("res://data/crops/corn/seed.png")
	check(reader.read_file("seed.png")==image_bytes,"Export preserves original image bytes")
	reader.close()
	check(ContentCatalog.export_crop("corn",package_path)==OK and not str(ContentCatalog.package_dirs.corn).is_empty(),"Repeated exports keep the source directory and replace the previous ZIP")
	for path in ["user://corn-test-save.json","user://corn-test-save.json.bak"]:
		DirAccess.remove_absolute(path)
	print("CORN RESULT: ",passed," passed, ",failed," failed")
	quit(1 if failed else 0)
