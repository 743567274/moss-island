extends SceneTree
var passed=0
func check(value: bool, message: String) -> void:
 if not value:
  push_error(message)
  quit(1)
  return
 passed+=1
 print("PASS ",message)
func _initialize() -> void:
 run.call_deferred()
func run() -> void:
 var settings=SettingsManager.new("user://test-performance.cfg")
 settings.preset("均衡")
 settings.data.background_saving=true
 var light=DirectionalLight3D.new()
 root.add_child(light)
 var manager=PerformanceManager.new()
 root.add_child(manager)
 manager.initialize(settings,light)
 var msaa=root.msaa_3d
 manager.occluded=true
 manager.apply()
 check(Engine.max_fps==2 and not RenderingServer.render_loop_enabled,"Covered desktop stops rendering")
 manager.occluded=false
 manager.locked=true
 manager.apply()
 check(Engine.max_fps==10 and RenderingServer.render_loop_enabled,"Visible locked wallpaper resumes at 10 FPS")
 check(root.msaa_3d==msaa,"Visibility transitions preserve render buffers")
 manager.locked=false
 manager.apply()
 check(Engine.max_fps==30,"Unlocked restores interactive cap")
 manager.companion=true
 manager.apply()
 check(Engine.max_fps==10,"Companion limits GPU work for its low-rate native alpha surface")
 manager.companion=false
 settings.data.background_saving=false
 manager.occluded=true
 manager.apply()
 check(RenderingServer.render_loop_enabled and Engine.max_fps==30,"User can disable background pausing")
 manager.occluded=false
 manager.apply()
 var scene=IllustratedCourtyard.new()
 root.add_child(scene)
 scene.initialize(FarmState.new(1792500000))
 check(scene.static_batches<=20,"Static geometry shares bounded batches")
 check(scene.brush.width<=128 and scene.brush.height<=128,"Runtime texture stays small")
 check(scene.rain_instances.multimesh.instance_count==144,"Weather allocation is bounded")
 scene.weather_quality=0
 scene.environment_controller.quality=0
 check(scene.environment_controller.particle_budget(false)>0,"Eco quality retains weather particles")
 print("PERFORMANCE RESULT: ",passed," passed")
 scene.free()
 quit()
