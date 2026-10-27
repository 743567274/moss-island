extends SceneTree
var passed=0
func check(value: bool, label: String) -> void:
 assert(value,label)
 passed+=1
 print("PASS ",label)
func _initialize() -> void:
 run.call_deferred()
func run() -> void:
 var farm=FarmState.new(1792500000)
 var saved=farm.data.duplicate(true)
 var scene=IllustratedCourtyard.new()
 root.add_child(scene)
 scene.initialize(farm)
 var solar=SolarClock.sample(1792500000,30.27,120.15,8)
 solar.daylight=1.0
 solar.altitude=.9
 scene.update_environment(solar,0,1)
 var clear_energy=scene.sun.light_energy
 scene.update_environment(solar,3,1)
 check(is_equal_approx(scene.environment_controller.current.cloud,0),"Weather transitions without a snap")
 scene.environment_controller.advance(8)
 scene._apply_environment()
 check(scene.sun.light_energy<clear_energy*.5,"Clouds weaken direct sunlight")
 check(scene.sun.shadow_opacity<.35,"Clouds soften shadow contrast")
 scene.update_environment(solar,63,0)
 scene.environment_controller.advance(15)
 scene._apply_environment()
 check(scene.rain_instances.visible,"Rain enabled in eco quality")
 check(scene.last_budget==32,"Eco rain uses 32 shared particles")
 check(scene.water_shader.get_shader_parameter("rain")>.5,"Water rain rings respond to weather")
 check(scene.impact_material.get_shader_parameter("rain")>.5,"Ground impact rings respond to weather")
 check(scene.environment_controller.current.wetness>.8,"Rain wets surfaces")
 scene.update_environment(solar,0,0)
 scene.environment_controller.advance(15)
 scene._apply_environment()
 var wet=scene.environment_controller.current.wetness
 check(wet>0 and wet<1,"Ground dries gradually after rain")
 scene.preview_temperature=-6
 scene.update_environment(solar,75,0)
 scene.environment_controller.advance(35)
 scene._apply_environment()
 check(scene.snow_instances.visible and scene.environment_controller.current.snow==0 and scene.water_shader.get_shader_parameter("ice")==0,"Snow falls without cover or frozen water in eco quality")
 scene.preview_temperature=12
 scene.update_environment(solar,0,1)
 scene.environment_controller.advance(20)
 scene._apply_environment()
 check(scene.environment_controller.current.snow==0,"No snow accumulation remains after weather clears")
 check(scene.environment_controller.current.wetness<wet,"Wetness continues drying")
 scene.environment_controller.apply_details({"cloud_cover":45,"wind_speed_10m":22,"wind_direction_10m":90})
 scene.environment_controller.advance(8)
 check(scene.environment_controller.current.wind_x<-.8,"Measured wind direction changes particle drift")
 check(scene.environment_controller.current.cloud>.4 and scene.environment_controller.current.cloud<.5,"Measured cloud cover drives environment")
 check(farm.data==saved,"Visual weather never changes farm state")
 scene.free()
 print("ENVIRONMENT V2 RESULT: ",passed," passed")
 quit()
