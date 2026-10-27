class_name IllustratedCourtyard
extends Courtyard

var plate: MeshInstance3D
var plate_material: ShaderMaterial
var sprite_materials: Array[ShaderMaterial]=[]
var selected_index=-1
var crop_preview: Dictionary={}
var soil_materials: Array[ShaderMaterial]=[]
var soil_regions: Array[Vector4]=[]
var map_lamps=PackedVector4Array()
var map_lamp_energy=PackedFloat32Array()
var map_lamp_style=PackedVector4Array()
var map_lamp_color=PackedVector4Array()
var tree_shadow_data=PackedVector4Array()
var willow_material: ShaderMaterial
var willow_node: MeshInstance3D
var custom_root: Node3D
var custom_materials: Array[ShaderMaterial]=[]
var layer_depths={}
var extra_light_materials: Array=[]
var light_overlay_root: CanvasLayer
var fog_overlay: ShaderMaterial
var map_water_texture: Texture2D
var cloud_cycle=0.0
var cloud_speed=.25

func _process(delta: float) -> void:
 var elapsed=minf(delta,2.0)
 var wind=clampf(float(environment_controller.current.get("wind",0)),0,1)
 cloud_speed=move_toward(cloud_speed,.25+wind*3.75,elapsed*.8)
 cloud_cycle=fposmod(cloud_cycle+elapsed*cloud_speed/180.0,1.0)
 super._process(delta)

func initialize(state: FarmState) -> void:
 farm=state
 set_meta("illustrated",true)
 brush=NoiseTexture2D.new()
 brush.width=128
 brush.height=128
 brush.noise=FastNoiseLite.new()
 world=WorldEnvironment.new()
 world.environment=Environment.new()
 world.environment.background_mode=Environment.BG_COLOR
 world.environment.background_color=Color("91b27b")
 world.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
 add_child(world)
 sun=DirectionalLight3D.new()
 sun.set_meta("flat_art",true)
 moon=DirectionalLight3D.new()
 add_child(sun)
 add_child(moon)
 camera=Camera3D.new()
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.position=Vector3(0,30,.001)
 camera.size=18
 add_child(camera)
 camera.look_at(Vector3(0,.59,0))
 camera.current=true
 distant=Node3D.new()
 distant.name="ReferenceDistance"
 cutaway=Node3D.new()
 cutaway.name="CompanionCutout"
 cutaway.hide()
 add_child(distant)
 add_child(cutaway)
 imported=Node3D.new()
 add_child(imported)
 plate_material=ShaderMaterial.new()
 plate_material.shader=load("res://assets/shaders/reference_plate.gdshader")
 var map=MapDefinition.load_map()
 layer_depths=MapLayerStack.depths(MapLayoutStore.layout)
 var blank=str(MapLayoutStore.layout.get("scene_mode","reference"))=="blank"
 if blank:
  var image=Image.create(1,1,false,Image.FORMAT_RGBA8)
  image.fill(Color(str(MapLayoutStore.layout.get("background_color","dfe5dc"))))
  var texture=ImageTexture.create_from_image(image)
  plate_material.set_shader_parameter("clean_plate",texture)
  plate_material.set_shader_parameter("night_plate",texture)
 else:
  plate_material.set_shader_parameter("clean_plate",load(map.background))
  plate_material.set_shader_parameter("night_plate",load(map.get("night_background",map.background)))
 plate_material.set_shader_parameter("has_night_plate",not blank and map.has("night_background"))
 _configure_map_environment(map)
 plate=_plane(self,Vector3(0,float(layer_depths.get(MapLayerStack.BACKGROUND,.50)),0),MapDefinition.world_size,plate_material)
 plate.name="OriginalIllustrationWithEditableBeds"
 paint["illustration"]=plate_material
 # Keep the shared environment/controller contract used by the host and tray.
 water_shader=plate_material
 sky_material=plate_material
 landscape_material=plate_material
 moon_disc_material=ShaderMaterial.new()
 moon_disc_material.shader=load("res://assets/shaders/moon_v2.gdshader")
 moon_disc=MeshInstance3D.new()
 add_child(moon_disc)
 for i in farm.data.plots.size():
  var node=Node3D.new()
  node.position=plot_position(i)
  add_child(node)
  plots.append(node)
  var crops=Node3D.new()
  node.add_child(crops)
  crop_nodes.append(crops)
 _build_square_plots()
 decoration_root=Node3D.new()
 selector=Node3D.new()
 water_garden=Node3D.new()
 water_garden.set_meta("decorative_only",true)
 water_garden.name="PaintedRiverAndLotus"
 add_child(decoration_root)
 add_child(selector)
 add_child(water_garden)
 house_model=Node3D.new()
 house_model.position=ReferenceLayout.world(Vector2(.22,.55))
 house_model.set_meta("reference_layer",true)
 add_child(house_model)
 boat_model=Node3D.new() # A decorative landmark, without gameplay state.
 boat_model.position=ReferenceLayout.world(Vector2(.46,.45))
 add_child(boat_model)
 _build_willow(map)
 _build_custom_objects()
 _build_weather()
 fog_overlay=ShaderMaterial.new()
 fog_overlay.shader=load("res://assets/shaders/map_fog_overlay.gdshader")
 # Sample a continuous, filtered field instead of evaluating a sine hash in
 # every fragment. Keep the density independent of mesh triangles/derivatives.
 var fog_noise=NoiseTexture2D.new()
 fog_noise.width=256
 fog_noise.height=256
 fog_noise.seamless=true
 var fog_generator=FastNoiseLite.new()
 fog_generator.seed=7319
 fog_generator.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH
 fog_generator.frequency=.025
 fog_generator.fractal_type=FastNoiseLite.FRACTAL_NONE
 fog_noise.noise=fog_generator
 fog_overlay.set_shader_parameter("density_field",fog_noise)
 # Composite fog after all 3D transparent objects and screen-reading light
 # passes. It must not share their depth/sort order or a triangulated plane.
 var screen_fog=CanvasLayer.new()
 screen_fog.name="ScreenFog"
 screen_fog.layer=20
 add_child(screen_fog)
 var fog_rect=ColorRect.new()
 fog_rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
 fog_rect.material=fog_overlay
 screen_fog.add_child(fog_rect)
 fog_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 rain_material.render_priority=80
 snow_material.render_priority=80
 static_batches=1+soil_materials.size()+custom_materials.size()+(1 if willow_material!=null else 0)
 refresh(true)

func _build_willow(map: Dictionary) -> void:
 if str(MapLayoutStore.layout.get("scene_mode","reference"))=="blank":
  return
 var config=map.get("willow",{})
 if config.is_empty():
  return
 config=config.duplicate(true)
 var transform=MapLayoutStore.layout.get("willow",{})
 if not transform.is_empty():
  config.root=[float(transform.position[0])/1920,float(transform.position[1])/1080]
  config.scale=float(config.get("scale",1.0))*float(transform.scale)
 var texture=ContentCatalog.prepared_texture(config.texture,768,config.region,config.get("edge_cleanup",{}))
 if texture==null:
  return
 var patch=config.clean_rect
 var patch_region=[patch[0],patch[1],patch[2]-patch[0],patch[3]-patch[1]]
 plate_material.set_shader_parameter("willow_clean_day",ContentCatalog.prepared_texture(config.clean_day,512,patch_region))
 plate_material.set_shader_parameter("willow_clean_night",ContentCatalog.prepared_texture(config.clean_night,512,patch_region))
 plate_material.set_shader_parameter("willow_clean_rect",Vector4(patch[0],patch[1],patch[2],patch[3]))
 plate_material.set_shader_parameter("replace_willow",true)
 var root=Vector2(config.root[0],config.root[1])
 plate_material.set_shader_parameter("willow_root_shadow",Vector4(root.x,root.y,.016,.008))
 var shadow_scale=float(transform.get("shadow_scale",1))
 var shadow_offset=MapMaterialSpec.shadow_offset(transform).rotated(MapMaterialSpec.rotation(transform))/Vector2(1920,1080)
 plate_material.set_shader_parameter("willow_root_shadow",Vector4(root.x+shadow_offset.x,root.y+shadow_offset.y,.016*shadow_scale,.008*shadow_scale))
 plate_material.set_shader_parameter("willow_shadow_strength",float(transform.get("shadow_strength",.2))*float(transform.get("opacity",1)))
 willow_material=ShaderMaterial.new()
 willow_material.shader=load("res://assets/shaders/illustrated_sprite.gdshader")
 willow_material.set_shader_parameter("opacity",float(transform.get("opacity",1)))
 willow_material.set_shader_parameter("sprite",texture)
 willow_material.set_shader_parameter("foliage_only",true)
 willow_material.set_shader_parameter("day_exposure",clampf(float(config.get("day_exposure",1.0)),.1,1.5))
 willow_material.set_shader_parameter("sway",float(config.get("sway",.004)))
 willow_material.set_shader_parameter("wind_response",float(config.get("wind_response",6.0)))
 willow_material.set_shader_parameter("sprite_canvas_scale",1.12)
 willow_material.set_shader_parameter("phase",2.7)
 willow_material.set_shader_parameter("sprite_rotation",MapMaterialSpec.rotation(transform))
 var height=float(config.height)*float(config.get("scale",1.0))
 var width=height*texture.get_width()/float(texture.get_height())
 var anchor=Vector2(config.anchor[0],config.anchor[1])
 var position=ReferenceLayout.world(root,float(layer_depths.get("willow",.73)))+Vector3((.5-anchor.x)*width,0,(.5-anchor.y)*height)
 var angle=MapMaterialSpec.rotation(transform)
 var pivot=ReferenceLayout.world(root,position.y)
 position=pivot+(position-pivot).rotated(Vector3.UP,-angle)
 var node=_plane(self,position,Vector2(width,height)*1.12,willow_material)
 node.rotation.y=-angle
 willow_node=node
 node.name="IndependentWatercolorWillow"

func _plane(parent: Node3D, p: Vector3, size: Vector2, mat: Material) -> MeshInstance3D:
 var shape=PlaneMesh.new()
 shape.size=size
 var node=MeshInstance3D.new()
 node.mesh=shape
 node.material_override=mat
 node.position=p
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 parent.add_child(node)
 return node

static func plot_position(index: int) -> Vector3:
 return MapDefinition.center("crops" if index<12 else "orchard",index if index<12 else index-12)

static func orchard_position(index: int) -> Vector3:
 return MapDefinition.center("orchard",index)

func _configure_map_environment(map: Dictionary) -> void:
 if is_instance_valid(light_overlay_root): light_overlay_root.free()
 light_overlay_root=CanvasLayer.new()
 light_overlay_root.name="ScreenLights"
 light_overlay_root.layer=10
 add_child(light_overlay_root)
 extra_light_materials.clear()
 if MapLayoutStore.layout.has("water_region"):
  map_water_texture=ImageTexture.create_from_image(MapWaterRegion.image(MapLayoutStore.layout))
  var settings=MapLayoutStore.layout.water_region
  plate_material.set_shader_parameter("has_map_water",true)
  plate_material.set_shader_parameter("map_water_mask",map_water_texture)
  plate_material.set_shader_parameter("map_water_angle",deg_to_rad(float(settings.get("angle",0))))
  plate_material.set_shader_parameter("map_water_speed",float(settings.get("speed",1)))
  var feather=float(settings.get("feather",3))
  plate_material.set_shader_parameter("map_water_feather",Vector2(feather/map_water_texture.get_width(),feather/map_water_texture.get_height()))
 map=map.duplicate(true)
 if MapLayoutStore.layout.has("lights"):
  map.lights=MapLayoutStore.layout.lights.duplicate(true)
  for light in map.lights:
   light.position=[float(light.position[0])/1920,float(light.position[1])/1080]
 map.lights=MapLightFixture.lights(MapLayoutStore.layout)
 for light in map.lights: light.position=[float(light.position[0])/1920,float(light.position[1])/1080]
 if not map.lights.is_empty():
  # Spatial screen textures omit transparent sprite color. Copy the completed
  # scene in 2D instead, after all sprites and before any local lights or fog.
  var copy=BackBufferCopy.new()
  copy.copy_mode=BackBufferCopy.COPY_MODE_VIEWPORT
  light_overlay_root.add_child(copy)
 # Composite every light after the image layers, matching the editor. Keeping
 # the first batch inside sprite shaders let the authored night image hide it.
 for start in range(0,map.lights.size(),4):
  var mat=ShaderMaterial.new()
  mat.shader=load("res://assets/shaders/map_extra_lighting.gdshader")
  MapLightFixture.apply_batch(mat,map.lights,start,true)
  var light_rect=ColorRect.new()
  light_rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
  light_rect.material=mat
  light_overlay_root.add_child(light_rect)
  light_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  extra_light_materials.append(mat)
 var points=PackedVector2Array()
 var widths=PackedFloat32Array()
 for i in 8:
  var index=mini(i,map.water.points.size()-1)
  points.append(Vector2(map.water.points[index][0],map.water.points[index][1]))
  widths.append(float(map.water.widths[index]))
 plate_material.set_shader_parameter("water_points",points)
 plate_material.set_shader_parameter("water_widths",widths)
 plate_material.set_shader_parameter("water_count",0 if str(MapLayoutStore.layout.get("scene_mode","reference"))=="blank" else map.water.points.size())
 var bounds=Vector4(1,1,0,0)
 for i in map.water.points.size():
  var point=map.water.points[i]
  var width=float(map.water.widths[i])
  bounds.x=minf(bounds.x,float(point[0])-width)
  bounds.y=minf(bounds.y,float(point[1])-width)
  bounds.z=maxf(bounds.z,float(point[0])+width)
  bounds.w=maxf(bounds.w,float(point[1])+width)
 plate_material.set_shader_parameter("water_bounds",bounds)
 var exclusion=map.water.bridge_exclusion
 plate_material.set_shader_parameter("bridge_exclusion",Vector4(exclusion[0],exclusion[1],exclusion[2],exclusion[3]))
 var lights=PackedVector4Array()
 var energies=PackedFloat32Array()
 var lanterns=PackedFloat32Array()
 var styles=PackedVector4Array()
 var colors=PackedVector4Array()
 for i in 4:
  if i<map.lights.size():
   var light=map.lights[i]
   lights.append(Vector4(light.position[0],light.position[1],light.radius[0],light.radius[1]))
   energies.append(float(light.energy) if light.get("enabled",true) else 0.0)
   var kind={"point":0.0,"spot":1.0,"directional":2.0}.get(str(light.get("kind","point")),0.0)
   styles.append(Vector4(kind,deg_to_rad(float(light.get("angle",90))),cos(deg_to_rad(float(light.get("aperture",60))*.5)),1.0 if light.get("night_only",true) else 0.0))
   var color=Color(str(light.get("color","ffb45c")))
   colors.append(Vector4(color.r,color.g,color.b,1.0 if light.get("flicker",false) else 0.0))
   lanterns.append(1.0 if light.get("lantern",false) else 0.0)
  else:
   lights.append(Vector4(-10,-10,1,1))
   energies.append(0)
   lanterns.append(0)
   styles.append(Vector4.ZERO)
   colors.append(Vector4.ZERO)
 plate_material.set_shader_parameter("lamps",lights)
 plate_material.set_shader_parameter("lamp_energy",energies)
 plate_material.set_shader_parameter("lamp_lantern",lanterns)
 map_lamps=lights
 map_lamp_energy=energies
 map_lamp_style=styles
 map_lamp_color=colors

func _build_square_plots() -> void:
 var atlas_path=str(MapDefinition.load_map().get("soil_atlas",""))
 var normal=load(atlas_path if not atlas_path.is_empty() else "res://assets/illustrated/soil-normal.png") as Texture2D
 var highlighted=normal if not atlas_path.is_empty() else load("res://assets/illustrated/soil-selected.png") as Texture2D
 var saved_regions=MapDefinition.load_map().get("soil_regions",[])
 if not atlas_path.is_empty() and saved_regions.size()==2:
  var cleanup=MapDefinition.load_map().get("soil_edge_cleanup",{})
  normal=ContentCatalog.prepared_texture(atlas_path,768,saved_regions[0],cleanup)
  highlighted=ContentCatalog.prepared_texture(atlas_path,768,saved_regions[1],cleanup)
  saved_regions=[[0.0,0.0,1.0,1.0],[0.0,0.0,1.0,1.0]]
 for index in 2:
  if saved_regions.size()==2:
   var region=saved_regions[index]
   soil_regions.append(Vector4(region[0],region[1],region[2],region[3]))
   continue
  var texture=normal if index==0 else highlighted
  var image=texture.get_image()
  if image==null:
   soil_regions.append(Vector4(0,0,1,1))
   continue
  if image.is_compressed():
   image.decompress()
  var bounds=image.get_used_rect()
  soil_regions.append(Vector4(float(bounds.position.x)/image.get_width(),float(bounds.position.y)/image.get_height(),float(bounds.size.x)/image.get_width(),float(bounds.size.y)/image.get_height()))
 for i in farm.data.plots.size():
  var root=plots[i]
  # The sprite already contains the isometric projection.
  var shape=PlaneMesh.new()
  shape.size=MapDefinition.plot_extent(i)
  var node=MeshInstance3D.new()
  node.name="SquareSoil"
  node.mesh=shape
  node.position.y=-.045
  node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  var mat=ShaderMaterial.new()
  mat.shader=load("res://assets/shaders/map_soil.gdshader")
  mat.set_shader_parameter("soil_normal",normal)
  mat.set_shader_parameter("soil_selected",highlighted)
  mat.set_shader_parameter("normal_region",soil_regions[0])
  mat.set_shader_parameter("selected_region",soil_regions[1])
  mat.set_shader_parameter("ground_day",plate_material.get_shader_parameter("clean_plate"))
  mat.set_shader_parameter("ground_night",plate_material.get_shader_parameter("night_plate"))
  mat.set_shader_parameter("plot_phase",soil_materials.size()*2.71)
  var blending=MapDefinition.load_map().get("art_blending",{})
  for key in ["edge_grass","root_shadow_strength","soil_saturation","soil_contrast","paper_grain"]:
   if blending.has(key):
    mat.set_shader_parameter(key,float(blending[key]))
  node.material_override=mat
  root.add_child(node)
  soil_materials.append(mat)
  _apply_soil_surface(soil_materials.size()-1)

func plot_at(point: Vector3) -> int:
 var indices=[]
 for layer in MapLayerStack.entries(MapLayoutStore.layout):
  if layer.kind=="plot":
   indices.push_front(int(layer.index))
 if indices.is_empty():
  for i in range(farm.data.plots.size()-1,-1,-1):
   indices.append(i)
 for i in indices:
  var spec=MapLayoutStore.plot(i)
  var center=plot_position(i)
  var local_point=center+(point-center).rotated(Vector3.UP,MapMaterialSpec.rotation(spec))
  if spec.has("surface"):
   var extent=MapDefinition.plot_extent(i)
   if MapMaterialSpec.contains(spec.surface,Vector2((local_point.x-center.x)/extent.x+.5,(local_point.z-center.z)/extent.y+.5)):
    return i
  else:
   var local=MapDefinition.local_position("crops" if i<12 else "orchard",i if i<12 else i-12,local_point)
   if absf(local.x)<.5 and absf(local.z)<.5:
    return i
 return -1
func select_plot(index: int) -> void:
 selected_index=index
 for i in soil_materials.size():
  soil_materials[i].set_shader_parameter("selected",i==index)

func _sprite_material(texture: Texture2D, region: Vector4) -> ShaderMaterial:
 var mat=ShaderMaterial.new()
 mat.shader=load("res://assets/shaders/illustrated_sprite.gdshader")
 mat.set_shader_parameter("sprite",texture)
 # Bind safe fallbacks for the optional samplers, including after a map rebuild.
 mat.set_shader_parameter("night_sprite",texture)
 mat.set_shader_parameter("emission_mask",texture)
 mat.set_shader_parameter("water_mask",texture)
 mat.set_shader_parameter("has_fixture_night",false)
 mat.set_shader_parameter("has_emission_mask",false)
 mat.set_shader_parameter("region",region)
 mat.set_shader_parameter("daylight",environment_controller.current.daylight)
 sprite_materials.append(mat)
 return mat

func refresh(force: bool=false) -> void:
 var signature=JSON.stringify(crop_preview)+":"
 for p in farm.data.plots:
  signature+="%s:%s:%s:%s;" % [p.crop,farm.stage(p),p.health,farm.appearance(p).asset if p.crop!="" else ""]
 if not force and signature==last_stages:
  return
 last_stages=signature
 sprite_materials.clear()
 tree_shadow_data=PackedVector4Array()
 for i in farm.data.plots.size():
  soil_materials[i].set_shader_parameter("root_count",0)
  for child in crop_nodes[i].get_children():
   child.free()
  var p=farm.data.plots[i]
  if not crop_preview.is_empty() and int(crop_preview.get("plot_index",-1))==i:
   p=crop_preview.plot
  if p.crop=="":
   continue
  var config=FarmState.CROPS[p.crop]
  var look=farm.appearance(p)
  var asset=config.assets[look.asset]
  var texture=ContentCatalog.texture(p.crop,look.asset)
  if texture==null:
   continue
  var region=ContentCatalog.texture_region(p.crop,look.asset)
  var height=float(look.height)*MapLayoutStore.scale_for(i)
  var width=height*texture.get_width()*float(region[2])/(texture.get_height()*float(region[3]))
  var mat=_sprite_material(texture,Vector4(region[0],region[1],region[2],region[3]))
  mat.set_shader_parameter("phase",i*1.73)
  var is_seed=config.get("type","crop")=="crop" and config.stages[farm.stage(p)].get("id","")=="seed"
  var contact_strength=float(MapLayoutStore.plot(i).get("shadow_strength",MapDefinition.load_map().get("art_blending",{}).get("root_shadow_strength",.17)))
  mat.set_shader_parameter("opacity",float(MapLayoutStore.plot(i).get("opacity",1)))
  soil_materials[i].set_shader_parameter("root_shadow_strength",contact_strength*(.30 if is_seed else 1.0))
  mat.set_shader_parameter("sway",config.render.seed_sway if is_seed else config.render.sway)
  mat.set_shader_parameter("crop_style",true)
  mat.set_shader_parameter("root_anchor",float(config.render.anchor_y))
  mat.set_shader_parameter("sprite_world_size",Vector2(width,height))
  mat.set_shader_parameter("soil_center",ReferenceLayout.uv(plots[i].position))
  mat.set_shader_parameter("soil_rotation",MapMaterialSpec.rotation(MapLayoutStore.plot(i)))
  mat.set_shader_parameter("sprite_rotation",MapMaterialSpec.rotation(MapLayoutStore.plot(i)))
  var style=config.render.get("art_blending",{})
  for key in ["style_saturation","style_contrast","texture_softness","paper_grain","phase_variation","wind_response"]:
   if style.has(key):
    mat.set_shader_parameter(key,float(style[key]))
  mat.set_shader_parameter("root_detail",0.0 if is_seed else float(style.get("root_detail",.70)))
  mat.set_shader_parameter("ground_soil",soil_materials[i].get_shader_parameter("soil_normal"))
  mat.set_shader_parameter("ground_soil_region",soil_regions[0])
  mat.set_shader_parameter("ground_day",plate_material.get_shader_parameter("clean_plate"))
  mat.set_shader_parameter("ground_night",plate_material.get_shader_parameter("night_plate"))
  var rows=int(config.render.rows)
  var columns=int(config.render.columns)
  var batch=MultiMesh.new()
  batch.transform_format=MultiMesh.TRANSFORM_3D
  batch.use_custom_data=true
  var shape=PlaneMesh.new()
  shape.size=Vector2(width,height)*1.12
  shape.subdivide_depth=8
  mat.set_shader_parameter("sprite_canvas_scale",1.12)
  batch.mesh=shape
  batch.instance_count=rows*columns
  var basis=MapDefinition.axes("crops" if i<12 else "orchard",i if i<12 else i-12)
  var soil_size=MapDefinition.plot_extent(i)
  mat.set_shader_parameter("soil_world_size",soil_size)
  var random=RandomNumberGenerator.new()
  random.seed=7049+i*7919
  var variation=0.0 if is_seed or rows*columns==1 else clampf(float(style.get("size_variation",.035)),0,.1)
  var contacts=PackedVector4Array()
  for row in rows:
   for col in columns:
    var offset=basis*Vector3((col-(columns-1)*.5)*float(config.render.spacing_x),0,(row-(rows-1)*.5)*float(config.render.spacing_y))
    var plant_scale=1.0+random.randf_range(-variation,variation)
    var index=row*columns+col
    batch.set_instance_transform(index,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*plant_scale),offset+Vector3(0,.04,-height*plant_scale*(float(config.render.anchor_y)-.5))))
    batch.set_instance_custom_data(index,Color(random.randf(),random.randf(),0,1))
    var angle=MapMaterialSpec.rotation(MapLayoutStore.plot(i))
    var root_uv=ReferenceLayout.uv(plots[i].position+(crop_nodes[i].position+offset).rotated(Vector3.UP,-angle))
    var shadow_scale=float(MapLayoutStore.plot(i).get("shadow_scale",1))
    var shadow_offset=MapMaterialSpec.shadow_offset(MapLayoutStore.plot(i)).rotated(angle)/Vector2(1920,1080)
    contacts.append(Vector4(root_uv.x+shadow_offset.x,root_uv.y+shadow_offset.y,(.08+height*.045)*shadow_scale,(.045+height*.018)*shadow_scale))
  soil_materials[i].set_shader_parameter("root_contacts",contacts)
  soil_materials[i].set_shader_parameter("root_count",contacts.size())
  var node=MultiMeshInstance3D.new()
  node.name="ConfiguredCrop"
  node.multimesh=batch
  node.material_override=mat
  node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  crop_nodes[i].add_child(node)
  if tree_shadow_data.size()<6:
   var uv=ReferenceLayout.uv(plots[i].position+crop_nodes[i].position)
   tree_shadow_data.append(Vector4(uv.x,uv.y,height*float(config.render.shadow_scale),height*.5))
 _apply_environment()

func _precipitation(mat: ShaderMaterial, count: int, _snow: bool=false, _drips: bool=false) -> MultiMeshInstance3D:
 mat.shader=load("res://assets/shaders/illustrated_weather.gdshader")
 var mm=MultiMesh.new()
 mm.transform_format=MultiMesh.TRANSFORM_3D
 mm.use_custom_data=true
 var quad=QuadMesh.new()
 quad.size=Vector2(.055,.055) if _snow else Vector2(.025,.25)
 mm.mesh=quad
 mm.instance_count=count
 var rng=RandomNumberGenerator.new()
 rng.seed=837 if _snow else 412
 for i in count:
  mm.set_instance_transform(i,Transform3D.IDENTITY)
  mm.set_instance_custom_data(i,Color(rng.randf(),rng.randf(),rng.randf(),1))
 var node=MultiMeshInstance3D.new()
 node.multimesh=mm
 node.material_override=mat
 node.custom_aabb=AABB(Vector3(-22,0,-13),Vector3(44,6,26))
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(node)
 return node

func _build_weather() -> void:
 super._build_weather()
 for child in get_children():
  if child is MeshInstance3D and child.material_override==impact_material:
   child.free()
 impact_material.shader=load("res://assets/shaders/illustrated_ripples.gdshader")
 var ripple_depth=_ripple_depth()
 impact_material.set_shader_parameter("effect_depth",ripple_depth)
 if map_water_texture!=null:
  impact_material.set_shader_parameter("has_map_water",true)
  impact_material.set_shader_parameter("map_water_mask",map_water_texture)
  var mask=map_water_texture.get_image()
  var candidates=PackedVector2Array()
  for y in range(ceili(mask.get_height()/3.0),mask.get_height(),3):
   for x in range(0,mask.get_width(),3):
    if mask.get_pixel(x,y).r>.7: candidates.append(Vector2((x+.5)/mask.get_width(),(y+.5)/mask.get_height()))
  var points=PackedVector2Array()
  var count=mini(64,candidates.size())
  for i in 64:
   points.append(candidates[mini(candidates.size()-1,int((i%count)*candidates.size()/float(count)))] if count>0 else Vector2(-1,-1))
  impact_material.set_shader_parameter("region_points",points)
  impact_material.set_shader_parameter("region_count",count)
 var batch=MultiMesh.new()
 batch.transform_format=MultiMesh.TRANSFORM_3D
 batch.use_custom_data=true
 var shape=PlaneMesh.new()
 shape.size=Vector2(.68,.40)
 batch.mesh=shape
 batch.instance_count=36
 var rng=RandomNumberGenerator.new()
 rng.seed=917
 var water=MapDefinition.load_map().water
 for i in 36:
  var uv=Vector2(rng.randf_range(.05,.95),rng.randf_range(.4,.94))
  if i<24:
   var index=rng.randi_range(2,water.points.size()-2)
   var a=Vector2(water.points[index][0],water.points[index][1])
   var b=Vector2(water.points[index+1][0],water.points[index+1][1])
   uv=a.lerp(b,rng.randf())+Vector2(rng.randf_range(-.018,.018),0)
  batch.set_instance_transform(i,Transform3D(Basis.IDENTITY,ReferenceLayout.world(uv,ripple_depth)))
  batch.set_instance_custom_data(i,Color(rng.randf(),1.0 if i<24 else 0.0,0,1))
 for parameter in ["water_points","water_widths","water_count"]:
  impact_material.set_shader_parameter(parameter,plate_material.get_shader_parameter(parameter))
 impact_material.set_shader_parameter("map_size",MapDefinition.world_size)
 var impacts=MultiMeshInstance3D.new()
 impacts.name="LowerSceneRainRipples"
 impacts.custom_aabb=AABB(Vector3(-MapDefinition.world_size.x*.5,0,-MapDefinition.world_size.y*.5),Vector3(MapDefinition.world_size.x,3,MapDefinition.world_size.y))
 impacts.multimesh=batch
 impacts.material_override=impact_material
 impacts.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(impacts)

func _ripple_depth() -> float:
 var depth=.62
 for value in layer_depths.values(): depth=maxf(depth,float(value))
 return depth+.02

func _apply_environment() -> void:
 super._apply_environment()
 if plate_material==null or environment_controller.solar.is_empty():
  return
 # Lighting is painted per layer: no real-time mesh shadows or world fog.
 world.environment.fog_enabled=false
 var params=environment_controller.current
 var light_uv=_screen_light_uv()
 for mat in extra_light_materials:
  mat.set_shader_parameter("daylight",params.daylight)
  mat.set_shader_parameter("map_uv_rect",light_uv)
 if fog_overlay!=null:
  fog_overlay.set_shader_parameter("amount",params.fog)
  fog_overlay.set_shader_parameter("daylight",params.daylight)
  fog_overlay.set_shader_parameter("opacity",float(MapLayoutStore.layout.get("fog_opacity",.65)))
  fog_overlay.set_shader_parameter("speed",float(MapLayoutStore.layout.get("fog_speed",1)))
 plate_material.set_shader_parameter("moonlight",moon.light_energy)
 # The independent fog pass supplies both distant haze and local banks.
 # Do not wash the background a second time with a uniform fog tint.
 plate_material.set_shader_parameter("fog_amount",0.0)
 rain_material.set_shader_parameter("speed",6.5)
 rain_material.set_shader_parameter("daylight",params.daylight)
 # The inherited roof-drip mesh has no roof anchors in the illustrated map
 # and duplicates the first rain trajectories. Use only the main rain batch.
 drip_instances.visible=false
 var azimuth=float(environment_controller.solar.azimuth) if params.daylight>.3 else float(environment_controller.solar.moon.azimuth)
 var direction=Vector2(sin(azimuth),cos(azimuth))
 var painted_materials=sprite_materials.duplicate()+custom_materials
 if willow_material!=null:
  painted_materials.append(willow_material)
 for mat in [plate_material]+painted_materials+soil_materials:
  mat.set_shader_parameter("map_size",MapDefinition.world_size)
  mat.set_shader_parameter("tree_shadows",tree_shadow_data)
  mat.set_shader_parameter("light_direction",direction)
  mat.set_shader_parameter("local_lamps",map_lamps)
  # All local lighting is now drawn once by the foreground composite.
  mat.set_shader_parameter("local_lamp_energy",PackedFloat32Array([0,0,0,0]))
  mat.set_shader_parameter("local_lamp_style",map_lamp_style)
  mat.set_shader_parameter("local_lamp_color",map_lamp_color)
 for mat in painted_materials:
  mat.set_shader_parameter("cloud_cycle",cloud_cycle)
  mat.set_shader_parameter("daylight",params.daylight)
  mat.set_shader_parameter("moonlight",moon.light_energy)
  mat.set_shader_parameter("cloud",params.cloud)
  mat.set_shader_parameter("wind",params.wind)
  mat.set_shader_parameter("wind_direction",Vector2(params.wind_x,params.wind_z))
  mat.set_shader_parameter("fog_amount",0.0)
  mat.set_shader_parameter("rain",params.rain)
 for mat in soil_materials:
  mat.set_shader_parameter("daylight",params.daylight)
  mat.set_shader_parameter("moonlight",moon.light_energy)
  mat.set_shader_parameter("cloud",params.cloud)
  mat.set_shader_parameter("fog_amount",0.0)
  mat.set_shader_parameter("wetness",params.wetness)
 if drip_instances!=null:
  drip_instances.hide()

func _screen_light_uv() -> Vector4:
 # Derive map coordinates from the real camera, including non-16:9 desktop
 # coverage and viewport resizing. Canvas UV alone would move the light pools.
 var extent=get_viewport().get_visible_rect().size
 if extent.x<=0 or extent.y<=0: return Vector4(0,0,1,1)
 var plane=Plane(Vector3.UP,.65)
 var upper=plane.intersects_ray(camera.project_ray_origin(Vector2.ZERO),camera.project_ray_normal(Vector2.ZERO))
 var lower=plane.intersects_ray(camera.project_ray_origin(extent),camera.project_ray_normal(extent))
 if upper==null or lower==null: return Vector4(0,0,1,1)
 var begin=ReferenceLayout.uv(upper)
 var end=ReferenceLayout.uv(lower)
 return Vector4(begin.x,begin.y,end.x-begin.x,end.y-begin.y)

func outline(_shore: bool=false) -> PackedVector2Array:
 return PackedVector2Array([Vector2(-15,-8),Vector2(15,-8),Vector2(15,8),Vector2(-15,8)])

func apply_map_layout() -> void:
 layer_depths=MapLayerStack.depths(MapLayoutStore.layout)
 if impact_material!=null: impact_material.set_shader_parameter("effect_depth",_ripple_depth())
 if is_instance_valid(plate): plate.position.y=float(layer_depths.get(MapLayerStack.BACKGROUND,.50))
 for i in plots.size():
  plots[i].position=plot_position(i)
  var basis=MapDefinition.axes("crops" if i<12 else "orchard",i if i<12 else i-12)
  var mesh=plots[i].get_node("SquareSoil").mesh as PlaneMesh
  mesh.size=MapDefinition.plot_extent(i)
  _apply_soil_surface(i)
 if is_instance_valid(willow_node):
  willow_node.free()
 willow_material=null
 _build_willow(MapDefinition.load_map())
 _configure_map_environment(MapDefinition.load_map())
 _build_custom_objects()
 refresh(true)

func _build_custom_objects() -> void:
 if is_instance_valid(custom_root):
  custom_root.free()
 custom_root=Node3D.new()
 custom_root.name="UserMapMaterials"
 add_child(custom_root)
 custom_materials.clear()
 var objects=MapLayoutStore.layout.get("objects",[]).duplicate(true)
 objects.sort_custom(func(a,b): return float(a.position[1])<float(b.position[1]))
 for i in objects.size():
  var item=objects[i]
  var background=str(item.get("type",""))=="background"
  var texture=ContentCatalog.prepared_texture(item.texture,2048 if background else 1024)
  if texture==null:
   continue
  var height=float(item.height)/1080*MapDefinition.world_size.y*float(item.scale)
  var width=height*texture.get_width()/float(texture.get_height())
  var anchor=Vector2(item.anchor[0],item.anchor[1])
  var depth=float(layer_depths.get(str(item.id),.70+i*.0001))
  var position=ReferenceLayout.world(Vector2(float(item.position[0])/1920,float(item.position[1])/1080),depth)
  position+=Vector3((.5-anchor.x)*width,0,(.5-anchor.y)*height)
  if background:
   var bounds=MapMaterialSpec.background_rect(Vector2(texture.get_size()))
   width=bounds.size.x/1920*MapDefinition.world_size.x
   height=bounds.size.y/1080*MapDefinition.world_size.y
   position=ReferenceLayout.world(Vector2(.5,.5),depth)
  var mat=ShaderMaterial.new()
  mat.shader=load("res://assets/shaders/illustrated_sprite.gdshader")
  mat.set_shader_parameter("opacity",float(item.get("opacity",1)))
  mat.set_shader_parameter("sprite",texture)
  mat.set_shader_parameter("sprite_rotation",MapMaterialSpec.rotation(item))
  mat.set_shader_parameter("sway",float(item.get("sway",.007)) if item.animation=="wind" else 0.0)
  mat.set_shader_parameter("wind_response",float(item.get("wind_response",4.8)))
  mat.set_shader_parameter("day_exposure",float(item.get("day_exposure",1)))
  var type=str(item.get("type","tree" if item.category=="树木" else "decoration"))
  mat.set_shader_parameter("soft_atmosphere",type in ["cloud","fog"])
  mat.set_shader_parameter("light_source",type=="light" and not item.has("fixture"))
  if item.has("fixture"):
   var mask_path=str(item.get("emission_mask",""))
   if not mask_path.is_empty():
    var mask=ContentCatalog.prepared_texture(mask_path,1024)
    if mask!=null:
     mat.set_shader_parameter("emission_mask",mask)
     mat.set_shader_parameter("has_emission_mask",true)
   mat.set_shader_parameter("fixture_night_brightness",float(item.fixture.get("night_brightness",.55)))
   var night=ContentCatalog.prepared_texture(str(item.get("night_texture","")),1024)
   if night!=null:
    mat.set_shader_parameter("night_sprite",night)
    mat.set_shader_parameter("has_fixture_night",true)
    mat.set_shader_parameter("fixture_enabled",bool(MapLightFixture.state(item).enabled))
    mat.set_shader_parameter("fixture_night_only",bool(MapLightFixture.state(item).night_only))
  mat.set_shader_parameter("foliage_only",type=="tree" and item.animation=="wind")
  mat.set_shader_parameter("crop_style",type!="tree" and item.animation=="wind")
  mat.set_shader_parameter("environment_motion",1 if item.animation=="cloud" else (2 if item.animation=="water" else (3 if item.animation=="light" else 0)))
  mat.set_shader_parameter("root_anchor",anchor.y)
  mat.set_shader_parameter("sprite_world_size",Vector2(width,height))
  if type=="water":
   var settings=item.get("water",{})
   var mask_path=str(settings.get("mask",""))
   var mask=ContentCatalog.prepared_texture(mask_path,512) if not mask_path.is_empty() else null
   mat.set_shader_parameter("has_water_mask",mask!=null)
   if not mask_path.is_empty() and mask==null:
    mat.set_shader_parameter("environment_motion",0)
   if mask!=null:
    mat.set_shader_parameter("water_mask",mask)
   var feather=float(settings.get("feather",3))
   mat.set_shader_parameter("water_feather",Vector2(feather/maxf(1,mask.get_width()),feather/maxf(1,mask.get_height())) if mask!=null else Vector2.ZERO)
   mat.set_shader_parameter("water_angle",deg_to_rad(float(settings.get("angle",0))))
   mat.set_shader_parameter("water_speed",float(settings.get("speed",1)))
  if map_water_texture!=null and type in ["water","ground","background"]:
   var settings=MapLayoutStore.layout.water_region
   var feather=float(settings.get("feather",3))
   mat.set_shader_parameter("environment_motion",2)
   mat.set_shader_parameter("has_water_mask",true)
   mat.set_shader_parameter("world_water_mask",true)
   mat.set_shader_parameter("water_mask",map_water_texture)
   mat.set_shader_parameter("water_feather",Vector2(feather/map_water_texture.get_width(),feather/map_water_texture.get_height()))
   mat.set_shader_parameter("water_angle",deg_to_rad(float(settings.get("angle",0))))
   mat.set_shader_parameter("water_speed",float(settings.get("speed",1)))
  mat.set_shader_parameter("sprite_canvas_scale",1.12)
  mat.set_shader_parameter("phase",float(item.get("phase",float(absi(hash(str(item.id)))%1000)*.01)))
  var node=_plane(custom_root,position,Vector2(width,height)*1.12,mat)
  if not background:
   var angle=MapMaterialSpec.rotation(item)
   var pivot=ReferenceLayout.world(Vector2(float(item.position[0])/1920,float(item.position[1])/1080),depth)
   node.position=pivot+(position-pivot).rotated(Vector3.UP,-angle)
   node.rotation.y=-angle
  if item.animation=="cloud": node.extra_cull_margin=4.5
  (node.mesh as PlaneMesh).subdivide_depth=8
  custom_materials.append(mat)
  if not background: _build_contact_shadow(item,depth,Vector2(width,height))

func _apply_soil_surface(index: int) -> void:
 var mat=soil_materials[index]
 var spec=MapLayoutStore.plot(index)
 plots[index].rotation.y=-MapMaterialSpec.rotation(spec)
 mat.set_shader_parameter("opacity",float(spec.get("opacity",1)))
 var depth=float(layer_depths.get(str(spec.get("id","plot-%d" % index)),.63))
 var soil=plots[index].get_node("SquareSoil") as MeshInstance3D
 soil.position.y=depth-plots[index].position.y
 var crop_y=depth+.001-plots[index].position.y-.04
 crop_nodes[index].position=Vector3(0,crop_y,0)
 if not spec.has("surface"):
  var map=MapDefinition.load_map()
  var cleanup=map.get("soil_edge_cleanup",{})
  mat.set_shader_parameter("soil_normal",ContentCatalog.prepared_texture(map.soil_atlas,768,map.soil_regions[0],cleanup))
  mat.set_shader_parameter("soil_selected",ContentCatalog.prepared_texture(map.soil_atlas,768,map.soil_regions[0],cleanup))
  mat.set_shader_parameter("auto_selection",true)
  mat.set_shader_parameter("selection_brightness",.12)
  mat.set_shader_parameter("custom_surface",false)
 else:
  var surface=spec.surface
  var anchor=surface.get("plant_anchor",[.5,.5])
  var extent=MapDefinition.plot_extent(index)
  crop_nodes[index].position=Vector3((float(anchor[0])-.5)*extent.x,crop_y,(float(anchor[1])-.5)*extent.y)
  var normal=ContentCatalog.prepared_texture(surface.texture,768)
  if normal==null:
   return
  var selected_path=MapMaterialSpec.selection_texture(surface)
  var selected=ContentCatalog.prepared_texture(selected_path,768) if not selected_path.is_empty() else normal
  mat.set_shader_parameter("soil_normal",normal)
  mat.set_shader_parameter("soil_selected",selected if selected!=null else normal)
  mat.set_shader_parameter("auto_selection",selected_path.is_empty() or selected==null)
  mat.set_shader_parameter("selection_brightness",float(surface.highlight))
  mat.set_shader_parameter("custom_surface",not MapMaterialSpec.uses_builtin_soil(surface))
 mat.set_shader_parameter("normal_region",Vector4(0,0,1,1))
 mat.set_shader_parameter("selected_region",Vector4(0,0,1,1))

func _build_contact_shadow(item: Dictionary,depth: float,extent: Vector2) -> void:
 var strength=float(item.get("shadow_strength",0))*float(item.get("opacity",1))
 if strength<=0: return
 var scale=float(item.get("shadow_scale",1))
 var size=Vector2(maxf(.1,extent.x*.7),maxf(.08,extent.y*.12))*scale
 var angle=MapMaterialSpec.rotation(item)
 var offset=MapMaterialSpec.shadow_offset(item).rotated(angle)
 var root=ReferenceLayout.world(Vector2((float(item.position[0])+offset.x)/1920,(float(item.position[1])+offset.y)/1080),depth-.0005)
 var mat=ShaderMaterial.new()
 mat.shader=load("res://assets/shaders/map_contact_shadow.gdshader")
 mat.set_shader_parameter("strength",strength)
 var node=_plane(custom_root,root,size,mat)
 node.rotation.y=-angle

