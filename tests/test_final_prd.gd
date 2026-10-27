extends SceneTree

var passed=0
var failed=0
func check(value: bool, name: String) -> void:
	if value:
		passed+=1
		print("PASS ",name)
	else:
		failed+=1
		push_error(name)

func _initialize() -> void:
	var t=1792500000.0
	var farm=FarmState.new(t)
	check(FarmState.valid(farm.data),"v5 plant-only farm validates")
	check(FarmState.CROPS.size()==8,"8 configured crop species")
	check(not farm.data.has("creatures") and not farm.data.collection.has("products"),"New farms contain crop data only")
	check(FarmState.CROPS.carrot.stages.size()!=FarmState.CROPS.wheat.stages.size(),"growth stage count is data driven")
	farm.data.plots[9].crop="carrot"
	farm.set_rate(5,t)
	farm.settle(t+100)
	check(farm.data.plots[9].growth==500,"5x applies to crop only")
	farm.set_rate(2,t+150)
	check(farm.data.plots[9].growth==750,"settle old crop rate first")
	farm.settle(t+200)
	check(farm.data.plots[9].growth==850,"new crop rate is prospective")
	farm.set_paused(true,t+200)
	farm.settle(t+300)
	check(farm.data.plots[9].growth==850,"crop pause works")
	farm.settle(t+250)
	check(farm.data.last_tick==t+300,"clock rollback retains high watermark")
	farm.settle(t+300)
	farm.set_paused(false,t+300)
	farm.data.plots[9].growth=FarmState.CROPS.carrot.duration*.99
	check(not farm.harvestable(farm.data.plots[9]),"no maturity before configured threshold")
	farm.data.plots[9].growth=FarmState.CROPS.carrot.duration
	check(farm.harvest(9,t+300),"mature crop harvested")
	check(farm.data.collection.crops.carrot.count==1,"harvest entered collection")
	check(farm.plant(9,"corn",t+300),"new crop can replace harvested crop")
	check(farm.data.collection.crops.carrot.count==1,"collection survives current crop replacement")
	check(not farm.plant(9,"carrot",t+300),"occupied plot cannot be overwritten")
	var dead=FarmState.new(t)
	dead.data.plots[10].crop="carrot"
	dead.settle(t+15*86400)
	check(dead.data.plots[10].health=="dead","long offline interval ages crops to death")
	check(not dead.harvest(10,t+15*86400),"dead crop cannot be harvested")
	check(dead.clear_dead(10),"dead plant can be cleared")
	var unlimited=FarmState.new(t)
	unlimited.data.offline_cap_days=0
	unlimited.settle(t+40*86400)
	check(unlimited.data.last_tick==t+40*86400 and unlimited.clock_notice=="","Offline time cap can be disabled")
	var defaults=FarmState.new(t)
	defaults.settle(t+40*86400)
	check(defaults.clock_notice!="","Default time jump protection remains enabled")
	var old=JSON.parse_string(FileAccess.get_file_as_string("res://data/example_save_v2.json")).payload
	var migrated=SaveManager.migrate_save(old)
	check(migrated.version==5 and FarmState.valid(migrated),"old v2 save migrates safely")
	check(migrated.id==old.id and migrated.harvested==old.harvested,"migration preserves identity and harvest history")
	var old_v3=farm.data.duplicate(true)
	old_v3.version=3
	old_v3.creatures=[{"kind":"cow","growth":1000}]
	old_v3.collection.products={"鲜奶":5}
	old_v3.collection.discovered.append("cow")
	var crop_only=SaveManager.migrate_save(old_v3)
	check(FarmState.valid(crop_only) and not crop_only.has("creatures"),"v3 migration removes retired systems")
	check(crop_only.plots==old_v3.plots and crop_only.id==old_v3.id and crop_only.harvested==old_v3.harvested,"Migration retains all plots, identity and crop history")
	check(not crop_only.collection.has("products") and not "cow" in crop_only.collection.discovered,"Retired collection entries removed")
	check(SaveManager.migrate_save(crop_only)==crop_only,"Crop-only migration is idempotent")
	var bad_collection=farm.data.duplicate(true)
	bad_collection.collection="bad"
	check(not FarmState.valid(bad_collection),"Malformed collection is rejected without a crash")
	var invalid={"name":"bad","stages":[{"name":"x","seconds":-1}]}
	check(not ContentCatalog.valid_crop(invalid),"malformed config rejected")
	var path="user://v3-test-farm.json"
	for suffix in ["",".bak",".bak2",".bak3",".tmp"]:
		DirAccess.remove_absolute(path+suffix)
	var provider=LocalSaveProvider.new(path)
	for i in 5:
		farm.data.harvested=i
		check(provider.write_save(farm.data)==OK,"atomic save with rotating backups %d" % i)
	check(provider.read_save()!=null,"v4 save round trip validates parsed JSON numeric types")
	check(FileAccess.file_exists(path+".bak3"),"three valid backups retained")
	var corrupt=FileAccess.open(path,FileAccess.WRITE)
	corrupt.store_string("broken")
	corrupt.close()
	var recovered=provider.read_save()
	check(recovered!=null and recovered.harvested==3,"corruption restores latest valid backup")
	check(WeatherService.effect_type(95)=="rain" and WeatherService.effect_type(75)=="snow","Retired thunderstorms map to rain while snow remains supported")
	var archive_path="user://unit-collection.json"
	var archive=CollectionStore.new(archive_path)
	check(archive.save_collection(farm.data.id,farm.data.collection)==OK,"collection saved independently")
	var record=archive.load_collection(farm.data.id)
	check(record.crops.get("carrot",{}).get("count",0)==1,"collection archive round trip")
	var merged=CollectionStore.merge({"crops":{},"discovered":[]},record)
	check(merged.crops.carrot.count==1,"collection survives scene state restoration")
	var legacy_archive=record.duplicate(true)
	legacy_archive.products={"鸡蛋":10}
	legacy_archive.discovered.append("chicken")
	var cleaned=CollectionStore.merge(merged,legacy_archive)
	check(not cleaned.has("products") and not "chicken" in cleaned.discovered,"Legacy collection cannot resurrect removed features")
	check(archive.load_collection("other-farm").is_empty(),"collection archive cannot mix farm identities")
	for suffix in ["",".bak",".tmp"]:
		DirAccess.remove_absolute(archive_path+suffix)
	for suffix in ["",".bak",".bak2",".bak3",".tmp"]:
		DirAccess.remove_absolute(path+suffix)
	print("FINAL PRD RESULT: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
