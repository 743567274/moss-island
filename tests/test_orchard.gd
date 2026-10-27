extends SceneTree
var passed=0
var failures=0
func check(value: bool, label: String) -> void:
 if value:
  passed+=1
  print("PASS ",label)
 else:
  failures+=1
  push_error(label)
func _initialize() -> void:
 run.call_deferred()
func run() -> void:
 var now=1792500000.0
 var state=FarmState.new(now)
 check(FarmState.valid(state.data),"New v5 orchard validates")
 var old=state.data.duplicate(true)
 old.version=4
 old.erase("orchard")
 var migrated=SaveManager.migrate_save(old)
 check(migrated.version==5 and FarmState.valid(migrated),"V4 orchard migration validates")
 check(migrated.id==old.id and migrated.plots==old.plots and migrated.collection==old.collection,"Migration preserves identity, crops and collection")
 for i in 5:
  check(state.tree_stage(state.data.orchard[i])==i,"Distinct tree growth stage %d" % i)
 check(not state.plant_tree(0,now),"Occupied tree cannot be overwritten")
 check(state.plant_tree(5,now),"Empty orchard slot accepts a seedling")
 check(not state.harvest_tree(5,now),"Immature tree cannot be harvested")
 state.settle(now+7200)
 check(state.data.orchard[5].growth==7200 and state.tree_stage(state.data.orchard[5])==1,"Offline real time advances seedling to young tree")
 state.set_paused(true,now+7200)
 state.settle(now+10800)
 check(state.data.orchard[5].growth==7200,"Pause stops tree growth")
 state.set_paused(false,now+10800)
 state.set_rate(2,now+10800)
 state.settle(now+11800)
 check(state.data.orchard[5].growth==9200,"Configured rate applies prospectively to trees")
 state.set_rate(1,now+11800)
 state.settle(now+11800+86400)
 var current=float(state.data.last_tick)
 check(state.data.orchard[5].growth==86400,"Long absence caps growth at ripe fruit")
 check(state.harvest_tree(5,current),"Ripe fruit can be harvested")
 check(state.data.orchard[5].planted and state.data.orchard[5].growth==43200,"Harvest retains mature tree and starts next flowering cycle")
 check(not state.harvest_tree(5,current),"Repeated click cannot duplicate fruit")
 check(state.data.collection.crops.orange.count==1,"Fruit harvest is recorded in collection")
 state.settle(current+43200)
 check(state.harvest_tree(5,current+43200) and state.data.orchard[5].harvests==2,"Perennial tree fruits again after twelve hours")
 var storage=LocalSaveProvider.new("user://unit-orchard.json")
 var saved_error=storage.write_save(state.data)
 var loaded=storage.read_save()
 check(saved_error==OK and loaded!=null and LocalSaveProvider.digest(loaded)==LocalSaveProvider.digest(state.data),"Orchard growth and harvest counts survive checksum save round trip")
 var invalid=state.data.duplicate(true)
 invalid.orchard[0].growth=NAN
 check(not FarmState.valid(invalid),"Invalid orchard clock is rejected")
 var scene=IllustratedCourtyard.new()
 root.add_child(scene)
 scene.initialize(state)
 for i in 6:
  check(scene.plot_at(IllustratedCourtyard.orchard_position(i))==12+i,"Orchard hit target %d" % i)
 state.data.orchard[0].growth=0
 state.data.orchard[0].planted=true
 scene.refresh()
 var seedling=scene.orchard_nodes[0].get_child(scene.orchard_nodes[0].get_child_count()-1).material_override.get_shader_parameter("region")
 state.data.orchard[0].growth=86400
 scene.refresh()
 check(scene.orchard_nodes[0].get_child(scene.orchard_nodes[0].get_child_count()-1).material_override.get_shader_parameter("region").z>seedling.z*3,"Growth changes actual tree silhouette")
 var previous=scene.orchard_nodes[0].get_child(scene.orchard_nodes[0].get_child_count()-1).get_instance_id()
 scene.refresh()
 check(scene.orchard_nodes[0].get_child(scene.orchard_nodes[0].get_child_count()-1).get_instance_id()==previous,"Stable growth stage does not rebuild tree every tick")
 var solar=SolarClock.sample(now,30.27,120.15,8)
 scene.preview_temperature=-10
 scene.update_environment(solar,75,0)
 scene.environment_controller.advance(1800)
 scene._apply_environment()
 var unchanged=true
 for mat in scene.paint.values():
  unchanged=unchanged and mat.get_shader_parameter("snow_cover")==0.0
 check(unchanged and scene.snow_instances.visible and scene.water_shader.get_shader_parameter("ice")==0.0,"Even prolonged snowfall leaves all surfaces and river unchanged")
 scene.free()
 print("ORCHARD RESULT: ",passed," passed, ",failures," failed")
 quit(1 if failures else 0)
