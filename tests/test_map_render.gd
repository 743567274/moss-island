extends SceneTree
var failures=0
var passed=0
var scene: IllustratedCourtyard
var solar: Dictionary
func check(value: bool, label: String) -> void:
 if value:
  passed+=1
  print("PASS ",label)
 else:
  failures+=1
  push_error(label)
func _initialize() -> void:
 run.call_deferred()
func frame() -> Image:
 for i in 3:
  await process_frame
  await RenderingServer.frame_post_draw
 return root.get_texture().get_image()
func at_uv(image: Image, uv: Vector2) -> Color:
 var pixel=scene.camera.unproject_position(ReferenceLayout.world(uv))
 pixel*=Vector2(image.get_size())/root.get_visible_rect().size
 return image.get_pixel(clampi(roundi(pixel.x),0,image.get_width()-1),clampi(roundi(pixel.y),0,image.get_height()-1))
func luma(color: Color) -> float:
 return color.r*.3+color.g*.55+color.b*.15
func soil_luma(image: Image,index: int) -> float:
 var total=0.0
 for x in range(-2,3):
  for y in range(-2,3):
   var point=MapDefinition.center("crops",index)+MapDefinition.axes("crops")*Vector3(x*.12,0,y*.12)
   total+=luma(at_uv(image,ReferenceLayout.uv(point)))
 return total/25.0
func changed(a: Image,b: Image,region: Rect2) -> int:
 var left=scene.camera.unproject_position(ReferenceLayout.world(region.position))
 var right=scene.camera.unproject_position(ReferenceLayout.world(region.end))
 var scale=Vector2(a.get_size())/root.get_visible_rect().size
 left*=scale
 right*=scale
 var count=0
 for y in range(maxi(0,int(left.y)),mini(a.get_height(),int(right.y)),3):
  for x in range(maxi(0,int(left.x)),mini(a.get_width(),int(right.x)),3):
   var ca=a.get_pixel(x,y)
   var cb=b.get_pixel(x,y)
   if absf(ca.r-cb.r)+absf(ca.g-cb.g)+absf(ca.b-cb.b)>.008:
    count+=1
 return count
func environment(code: int,day: float=1.0) -> void:
 solar.daylight=day
 solar.altitude=.9 if day>0 else -.5
 scene.update_environment(solar,code,1)
 scene.environment_controller.advance(30)
 scene._apply_environment()
func run() -> void:
 root.size=Vector2i(1280,720)
 var state=FarmState.new(1792500000)
 scene=IllustratedCourtyard.new()
 root.add_child(scene)
 scene.initialize(state)
 scene.set_process(false)
 solar=SolarClock.sample(1792500000,30.27,120.15,8)
 solar.moon={"altitude":.8,"azimuth":.4,"phase":.5,"illumination":1.0}
 environment(0)
 var clear=await frame()
 await create_timer(.9).timeout
 var moved=await frame()
 var willow=changed(clear,moved,Rect2(.44,.27,.14,.23))
 var water=changed(clear,moved,Rect2(.46,.66,.16,.16))
 check(willow>20,"Willow visibly sways between rendered frames")
 check(water>20,"River visibly flows between rendered frames")
 var before=soil_luma(moved,11)
 scene.select_plot(11)
 var selected=await frame()
 selected.save_png("res://build/v240-selected.png")
 check(soil_luma(selected,11)>before*1.035,"Selection visibly lightens the textured soil interior on average")
 scene.select_plot(-1)
 environment(3)
 var cloud=await frame()
 check(luma(at_uv(cloud,Vector2(.1,.3)))<luma(at_uv(clear,Vector2(.1,.3)))*.92,"Cloudy weather visibly differs from sunshine")
 environment(45)
 var fog=await frame()
 var fog_change=changed(cloud,fog,Rect2(.02,.02,.94,.55))
 check(fog_change>500,"Fog changes the distant landscape instead of only its label")
 environment(0,0)
 var night=await frame()
 var lamp_spec=MapDefinition.load_map().lights[2]
 var lamp=at_uv(night,Vector2(lamp_spec.position[0],lamp_spec.position[1]))
 check(lamp.r>lamp.b*1.5,"Pavilion has a warm visible lantern at night")
 check(luma(at_uv(night,Vector2(.1,.3)))<luma(at_uv(clear,Vector2(.1,.3)))*.6,"Night is darker while preserving moonlit colors")
 var roof_uv=Vector2(.47,.43)
 var grass_uv=Vector2(.32,.80)
 var roof_ratio=luma(at_uv(night,roof_uv))/maxf(.01,luma(at_uv(clear,roof_uv)))
 var grass_ratio=luma(at_uv(night,grass_uv))/maxf(.01,luma(at_uv(clear,grass_uv)))
 print("RELIGHT RATIOS: reflected water=",roof_ratio," shadowed grass=",grass_ratio)
 check(absf(roof_ratio-grass_ratio)>.08,"Moonlit river reflection and shadowed grass receive distinct local illumination")
 environment(63)
 scene.rain_instances.hide()
 scene.snow_instances.hide()
 scene.plate.hide()
 for plot in scene.plots:
  plot.hide()
 scene.world.environment.background_color=Color.BLACK
 var ripples=await frame()
 var top=0
 var lower=0
 for y in range(0,ripples.get_height(),2):
  for x in range(0,ripples.get_width(),2):
   if luma(ripples.get_pixel(x,y))>.015:
    if y<ripples.get_height()/3:
     top+=1
    else:
     lower+=1
 check(top==0 and lower>0,"Rain ripples render only in the lower two thirds")
 scene.impact_material.set_shader_parameter("debug_centers",true)
 var centers_before=await frame()
 await create_timer(1.8).timeout
 var centers_after=await frame()
 var center_changes=changed(centers_before,centers_after,Rect2(.02,.38,.96,.6))
 check(center_changes>5,"Ripple centers relocate between lifetimes instead of repeating at fixed points")
 var report={"passed":passed,"failed":failures,"willow_changed":willow,"water_changed":water,"fog_changed":fog_change,"ripple_pixels_top":top,"ripple_pixels_lower":lower}
 report.ripple_center_changes=center_changes
 FileAccess.open("res://build/map-render-check.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 scene.free()
 print("MAP RENDER RESULT: ",passed," passed, ",failures," failed")
 quit(1 if failures else 0)
