extends SceneTree
var failures=0
var passed=0
func check(value: bool,message: String) -> void:
	if value:
		passed+=1
		print("PASS ",message)
	else:
		failures+=1
		push_error(message)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	root.size=Vector2i(1920,1080)
	var state=FarmState.new(1792500000)
	var cfg=FarmState.CROPS.corn
	for i in 18:
		state.plant(i,"corn",state.data.last_tick)
		state.data.plots[i].water_mm=cfg.watering.capacity_mm
		for stage_index in i%6:
			state.data.plots[i].growth+=cfg.stages[stage_index].seconds
	state.data.plots[6].health="dead"
	state.data.plots[7].health="wilted"
	state.data.plots[8].health="wilted"
	state.data.plots[9].health="dead"
	state.data.plots[10].health="harvested"
	state.data.plots[13].health="dead"
	var scene=IllustratedCourtyard.new()
	root.add_child(scene)
	scene.initialize(state)
	var solar=SolarClock.sample(1792500000,30.27,120.15,8)
	solar.daylight=1.0
	solar.altitude=.8
	scene.update_environment(solar,0,1)
	scene.environment_controller.advance(30)
	scene._apply_environment()
	for i in 18:
		check(scene.crop_nodes[i].get_child_count()==1,"Configured sprite batch rendered at plot "+str(i))
	var batch=scene.crop_nodes[1].get_child(0)
	var before_size=batch.multimesh.mesh.size
	var before_foot=batch.multimesh.get_instance_transform(0).origin
	cfg.assets.seedling.scale=1.25
	scene.refresh(true)
	batch=scene.crop_nodes[1].get_child(0)
	check(batch.multimesh.mesh.size.is_equal_approx(before_size*1.25),"One image scale changes both dimensions proportionally")
	var foot=batch.multimesh.get_instance_transform(0).origin
	check(is_equal_approx(foot.z+batch.multimesh.mesh.size.y*(cfg.render.anchor_y-.5),before_foot.z+before_size.y*(cfg.render.anchor_y-.5)),"Scaling keeps the plant rooted at the same ground position")
	cfg.assets.seedling.scale=1.0
	scene.refresh(true)
	var ui=CourtyardUI.new()
	root.add_child(ui)
	var prefs=SettingsManager.new("user://corn-render-test-preferences.cfg")
	ui.initialize(prefs,state)
	ui.selection=4
	ui.refresh()
	for i in 4:
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/corn-scene-v260.png")
	ui.state.data.collection.crops.corn={"count":128,"first_harvest":state.data.last_tick}
	ui.show_collection()
	for i in 4:
		await process_frame
		await RenderingServer.frame_post_draw
	check(ui.inventory_grid.get_child_count()==12,"Warehouse displays twelve square slots")
	var cell=ui.inventory_grid.get_child(0)
	var quantity=cell.find_children("*","Label",true,false)[0]
	check(quantity.text=="128" and quantity.position.x>cell.size.x*.5 and quantity.position.y>cell.size.y*.5,"Inventory count is at the bottom-right of its slot")
	ui.collection_window.get_texture().get_image().save_png("res://build/corn-warehouse-v260.png")
	ui.collection_window.free()
	ui.free()
	scene.free()
	print("CORN RENDER RESULT: ",passed," passed, ",failures," failed")
	quit(1 if failures else 0)
