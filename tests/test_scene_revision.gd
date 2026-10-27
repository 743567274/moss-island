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
 var state=FarmState.new(1792500000)
 var scene=IllustratedCourtyard.new()
 root.add_child(scene)
 scene.initialize(state)
 check(scene.get_meta("illustrated",false),"Approved 2.5D illustration renderer active")
 check(scene.plate.mesh.size==Vector2(32,18),"Original 16:9 composition preserved without stretch")
 check(scene.plots.size()==18 and scene.crop_nodes.size()==18,"All eighteen crop anchors available")
 for i in 12:
  check(scene.plot_at(Diorama.plot_position(i))==i,"Reference-aligned crop hit target %d" % i)
 for i in 6:
  check(scene.plot_at(IllustratedCourtyard.orchard_position(i))==i+12,"Reference-aligned orchard hit target %d" % i)
 check(not state.data.has("creatures") and not scene.has_method("_build_animal"),"Plant-only farm has no animal models or state")
 check(scene.water_garden.get_meta("decorative_only"),"River and lotus remain decorative")
 check(scene.static_batches==19,"Static scene is one background and eighteen modular soil tiles")
 var background=scene.plate_material.get_shader_parameter("clean_plate")
 check(background.get_width()<=2048 and background.get_width()>1024,"Map background keeps bounded detailed resolution")
 check(scene.plate_material.get_shader_parameter("clean_plate")!=null,"Empty planting plate is composited only over editable areas")
 var corn=Image.load_from_file("res://data/crops/corn/adult.png")
 check(corn.detect_alpha()!=Image.ALPHA_NONE,"User corn sprite has transparent surroundings")
 check(scene.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"Fixed illustrated projection")
 for i in 12:
  for node in scene.crop_nodes[i].get_children():
   check(node is MultiMeshInstance3D,"Each occupied crop bed uses one instanced sprite batch")
 scene.select_plot(9)
 check(scene.soil_materials[9].get_shader_parameter("selected"),"Selected soil changes color on its own square tile")
 scene.select_plot(16)
 check(scene.soil_materials[16].get_shader_parameter("selected") and not scene.soil_materials[9].get_shader_parameter("selected"),"Orchard selection changes only its own soil")
 check(scene.distant.visible and not scene.cutaway.visible,"Wallpaper uses full reference scene")
 scene.set_companion(true)
 check(root.transparent_bg and not scene.distant.visible and scene.cutaway.visible,"Companion keeps transparent surroundings")
 check(scene.plate_material.get_shader_parameter("companion"),"Companion uses the foreground silhouette")
 scene.set_companion(false)
 check(not root.transparent_bg and not scene.plate_material.get_shader_parameter("companion"),"Wallpaper restores complete scene")
 var solar=SolarClock.sample(1792500000,30.27,120.15,8)
 solar.daylight=0.0
 solar.altitude=-.5
 solar.moon={"altitude":.8,"azimuth":.4,"phase":.5,"illumination":1.0}
 scene.update_environment(solar,0,1)
 var full=scene.moon.light_energy
 check(full>.4 and scene.plate_material.get_shader_parameter("moonlight")>0,"Night layers use actual lunar illumination")
 solar.moon.illumination=0.0
 scene.update_environment(solar,0,1)
 check(scene.moon.light_energy<full*.3,"New moon changes moonlit layers")
 check(not scene.world.environment.fog_enabled,"Illustrated mist does not allocate 3D fog")
 scene.free()
 print("SCENE REVISION RESULT: ",passed," passed, ",failures," failed")
 quit(1 if failures else 0)
