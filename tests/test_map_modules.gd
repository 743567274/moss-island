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
 var map=MapDefinition.load_map()
 check(MapDefinition.valid(map),"Bundled map passes schema validation")
 var broken=map.duplicate(true)
 broken.grids.orchard.columns=0
 check(not MapDefinition.valid(broken),"Invalid grid cannot silently break saved plot identities")
 check(map.id=="lakeside" and MapDefinition.world_size==Vector2(32,18),"Map loads from an independent environment definition")
 check(FileAccess.file_exists(map.background),"Map background asset resolves")
 var scene=IllustratedCourtyard.new()
 root.add_child(scene)
 var state=FarmState.new(1792500000)
 scene.initialize(state)
 check(scene.soil_materials.size()==18,"Twelve crop squares and six orchard squares are actual map modules")
 for kind in ["crops","orchard"]:
  var grid=map.grids[kind]
  var a=Vector2(grid.basis_a[0],grid.basis_a[1])
  var b=Vector2(grid.basis_b[0],grid.basis_b[1])
  check(is_equal_approx(a.length(),b.length()),"Projected square has equal side lengths: "+kind)
  check(grid.spacing>1.0,"Square tiles have fixed non-overlapping spacing: "+kind)
  var count=12 if kind=="crops" else 6
  for i in count:
   var center=MapDefinition.center(kind,i)
   var index=i if kind=="crops" else 12+i
   check(scene.plot_at(center)==index,"Soil center and interaction agree: %s %d" % [kind,i])
   if kind=="orchard":
    check(scene.plots[12+i].position.is_equal_approx(center),"Former orchard bed is a regular crop square %d" % i)
 scene.select_plot(4)
 var selected=0
 for mat in scene.soil_materials:
  if mat.get_shader_parameter("selected"):
   selected+=1
 check(selected==1 and scene.soil_materials[4].get_shader_parameter("selected"),"Selection highlights one tile interior")
 scene.select_plot(-1)
 check(not scene.soil_materials[4].get_shader_parameter("selected"),"Clearing selection restores soil color")
 check(map.lights.size()>=3 and map.lights[2].id=="pavilion","Pavilion lantern is a configurable light module")
 check(map.water.points.size()>=3 and map.water.points.size()==map.water.widths.size(),"Water current uses an extensible path with widths")
 check(EnvironmentTestWindow.CODES.has(61) and EnvironmentTestWindow.CODES.has(63) and EnvironmentTestWindow.CODES.has(65),"Weather preview exposes light, medium and heavy rain")
 var solar=SolarClock.sample(1792500000,30.27,120.15,8)
 var amounts=[]
 for code in [61,63,65]:
  scene.update_environment(solar,code,1)
  scene.environment_controller.advance(30)
  scene._apply_environment()
  amounts.append(scene.rain_material.get_shader_parameter("amount"))
 check(amounts[0]>0 and amounts[0]<amounts[1] and amounts[1]<amounts[2],"Rain intensities retain distinct particle amounts")
 amounts=[]
 for code in [71,73,75]:
  scene.update_environment(solar,code,1)
  scene.environment_controller.advance(30)
  scene._apply_environment()
  amounts.append(scene.snow_material.get_shader_parameter("amount"))
 check(amounts[0]>0 and amounts[0]<amounts[1] and amounts[1]<amounts[2],"Snow intensities have three distinct densities and sizes")
 check(EnvironmentTestWindow.CODES.has(71) and EnvironmentTestWindow.CODES.has(73) and EnvironmentTestWindow.CODES.has(75) and not EnvironmentTestWindow.CODES.has(95),"Preview exposes three snow levels and no thunderstorm")
 check(WeatherService.effect_type(95)=="rain" and WeatherService.classify(95)=="大雨","Old thunderstorm caches fall back to ordinary heavy rain")
 for texture_path in ["res://assets/illustrated/soil-normal.png","res://assets/illustrated/soil-selected.png"]:
  var image=Image.load_from_file(texture_path)
  check(image.get_pixel(0,0).a==0 and image.get_used_rect().has_area(),"Farmland cutout has real transparency and visible soil: "+texture_path)
 scene.free()
 print("MAP MODULE RESULT: ",passed," passed, ",failures," failed")
 quit(1 if failures else 0)
