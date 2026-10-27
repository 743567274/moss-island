class_name Courtyard
extends Diorama

# V2: one small brush texture, baked vertex colors, four shared scene materials.
var distant: Node3D
var cutaway: Node3D
var imported: Node3D
var water_garden: Node3D
var house_model: Node3D
var boat_model: Node3D
var lotus_leaves: MultiMeshInstance3D
var lotus_positions: Array[Vector3]=[]
var moon: DirectionalLight3D
var companion=false
var preview_temperature: Variant=null
var environment_controller=EnvironmentController.new()
var brush: NoiseTexture2D
var paint: Dictionary={}
var water_shader: ShaderMaterial
var sky_material: ShaderMaterial
var landscape_material: ShaderMaterial
var moon_disc: MeshInstance3D
var moon_disc_material: ShaderMaterial
var impact_material: ShaderMaterial
var rain_material: ShaderMaterial
var snow_material: ShaderMaterial
var drip_material: ShaderMaterial
var rain_instances: MultiMeshInstance3D
var snow_instances: MultiMeshInstance3D
var drip_instances: MultiMeshInstance3D
var last_budget=-1
var crop_cache={}
var static_batches=0
var baked_vertices=0
const LEAF=["527e60","6b9869","8ab17a","a9c58c","748d4e"]

func initialize(state: FarmState) -> void:
 farm=state
 seed(42)
 _build_environment()
 _build_land()
 _build_house()
 _build_garden()
 _build_plants()
 _build_water_garden()
 decoration_root=Node3D.new()
 add_child(decoration_root)
 selector=Node3D.new()
 add_child(selector)
 _merge_static_geometry()
 _build_weather()
 refresh(true)

func material(hex: String, roughness: float=.9) -> StandardMaterial3D:
 var mat=super.material(hex,roughness)
 if hex in LEAF:
  mat.set_meta("role","foliage")
 return mat

func _paint(role: String) -> ShaderMaterial:
 if not paint.has(role):
  var mat=ShaderMaterial.new()
  mat.shader=load("res://assets/shaders/painted_v2.gdshader")
  mat.set_shader_parameter("brush",brush)
  mat.set_shader_parameter("foliage",1.0 if role=="foliage" else 0.0)
  mat.set_shader_parameter("terrain",1.0 if role=="ground" else 0.0)
  mat.set_shader_parameter("soil",1.0 if role=="soil" else 0.0)
  paint[role]=mat
 return paint[role]

func _bake_branch(root_node: Node3D, skip: Array=[]) -> Array:
 var batches={}
 for node in root_node.find_children("*","MeshInstance3D",true,false):
  if node.get_meta("keep",false):
   continue
  var excluded=false
  for branch in skip:
   if branch.is_ancestor_of(node):
    excluded=true
    break
  if excluded:
   continue
  var mat=node.material_override
  if not mat is StandardMaterial3D:
   continue
  var role=str(node.get_meta("role",mat.get_meta("role","solid")))
  if not batches.has(role):
   var surface=SurfaceTool.new()
   surface.begin(Mesh.PRIMITIVE_TRIANGLES)
   batches[role]=surface
  var surface: SurfaceTool=batches[role]
  var at=root_node.global_transform.affine_inverse()*node.global_transform
  var normal_basis=at.basis.inverse().transposed()
  var arrays=node.mesh.surface_get_arrays(0)
  var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
  var indices=PackedInt32Array()
  if arrays[Mesh.ARRAY_INDEX]!=null:
   indices=arrays[Mesh.ARRAY_INDEX]
  if indices.is_empty():
   for i in vertices.size():
    indices.append(i)
  for index in indices:
   var p=at*vertices[index]
   var n=(normal_basis*normals[index]).normalized()
   var ao=(.84+.16*maxf(n.y,0))*(.9+.1*smoothstep(.4,2.5,p.y))
   var color=mat.albedo_color*ao
   color.a=0.0 if mat.emission_enabled else 1.0
   surface.set_color(color)
   surface.set_normal(n)
   if node.get_meta("authored_uv",false) and arrays[Mesh.ARRAY_TEX_UV]!=null:
    surface.set_uv(arrays[Mesh.ARRAY_TEX_UV][index])
   else:
    surface.set_uv(Vector2(p.x,p.z))
   surface.add_vertex(p)
  node.free()
 var result=[]
 for role in batches:
  var surface: SurfaceTool=batches[role]
  surface.index()
  var shape=surface.commit()
  var node=MeshInstance3D.new()
  node.mesh=shape
  node.material_override=_paint(role)
  if role in ["foliage","ground","soil"]:
   node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  root_node.add_child(node)
  result.append({"mesh":shape,"material":node.material_override,"shadow":node.cast_shadow})
  baked_vertices+=shape.surface_get_array_len(0)
 return result

func _merge_static_geometry() -> void:
 static_batches+=_bake_branch(distant).size()
 static_batches+=_bake_branch(cutaway).size()
 static_batches+=_bake_branch(self,[distant,cutaway,decoration_root,selector]+crop_nodes).size()

func _build_environment() -> void:
 brush=NoiseTexture2D.new()
 brush.width=128
 brush.height=128
 brush.seamless=true
 var noise=FastNoiseLite.new()
 noise.seed=37
 noise.frequency=.045
 brush.noise=noise
 world=WorldEnvironment.new()
 world.environment=Environment.new()
 world.environment.background_mode=Environment.BG_COLOR
 world.environment.background_color=Color("b5cec7")
 world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 world.environment.ambient_light_color=Color("c4d6cc")
 world.environment.ambient_light_energy=.62
 world.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
 world.environment.ssao_enabled=false
 world.environment.glow_enabled=false
 add_child(world)
 sun=DirectionalLight3D.new()
 sun.light_energy=1.0
 sun.light_color=Color("ffe1af")
 sun.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL
 sun.directional_shadow_max_distance=30
 sun.shadow_bias=.07
 sun.shadow_normal_bias=1.3
 add_child(sun)
 moon=DirectionalLight3D.new()
 moon.light_color=Color("9cbce1")
 moon.light_energy=0
 moon.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL
 moon.directional_shadow_max_distance=30
 add_child(moon)
 camera=Camera3D.new()
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.size=18.5
 camera.position=Vector3(18,18,22)
 camera.far=180
 camera.near=.2
 add_child(camera)
 camera.look_at(Vector3(0,.7,-1))
 camera.current=true
 distant=Node3D.new()
 distant.name="LayeredLandscape"
 add_child(distant)
 cutaway=Node3D.new()
 cutaway.name="IslandSection"
 add_child(cutaway)
 imported=Node3D.new() # Kept as a semantic scenery group; no imported textures/models.
 add_child(imported)
 water_shader=ShaderMaterial.new()
 water_shader.shader=load("res://assets/shaders/water_v2.gdshader")
 sky_material=ShaderMaterial.new()
 sky_material.shader=load("res://assets/shaders/backdrop_v2.gdshader")
 var backdrop=MeshInstance3D.new()
 var plane=QuadMesh.new()
 plane.size=Vector2(210,110)
 backdrop.mesh=plane
 backdrop.position=Vector3(0,35,-72)
 backdrop.material_override=sky_material
 backdrop.set_meta("keep",true)
 backdrop.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 distant.add_child(backdrop)
 var lake=MeshInstance3D.new()
 var water=PlaneMesh.new()
 water.size=Vector2(220,220)
 lake.mesh=water
 lake.position.y=.12
 lake.material_override=water_shader
 lake.set_meta("keep",true)
 lake.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 distant.add_child(lake)
 moon_disc_material=ShaderMaterial.new()
 moon_disc_material.shader=load("res://assets/shaders/moon_v2.gdshader")
 moon_disc=MeshInstance3D.new()
 var disc=QuadMesh.new()
 disc.size=Vector2(.8,.8)
 moon_disc.mesh=disc
 moon_disc.material_override=moon_disc_material
 moon_disc.transform=Transform3D(camera.global_basis,Vector3(0,.8,-1)-camera.global_basis.z*12+camera.global_basis.x*(-8.8)+camera.global_basis.y*8.6)
 moon_disc.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 distant.add_child(moon_disc)
 landscape_material=ShaderMaterial.new()
 landscape_material.shader=load("res://assets/shaders/landscape_v2.gdshader")
 for layer in 3:
  var st=SurfaceTool.new()
  st.begin(Mesh.PRIMITIVE_TRIANGLES)
  var basis=camera.global_basis
  var origin=Vector3(0,.8,-1)-basis.z*(8+layer*1.2)
  var color=Color(["85aaa5","a7bdb3","c3cdc0"][layer])
  for i in 60:
   var x=-24+i*.8
   var nx=x+.8
   var y=6.5+layer*.3+sin(i*.35+layer)*1.15+sin(i*.71+layer)*.45
   var ny=6.5+layer*.3+sin((i+1)*.35+layer)*1.15+sin((i+1)*.71+layer)*.45
   for v in [Vector2(x,4.0+layer*.3),Vector2(nx,ny),Vector2(x,y),Vector2(x,4.0+layer*.3),Vector2(nx,4.0+layer*.3),Vector2(nx,ny)]:
    st.set_color(color)
    st.set_uv(v)
    st.add_vertex(origin+basis.x*v.x+basis.y*v.y)
  st.generate_normals()
  var mountains=MeshInstance3D.new()
  mountains.mesh=st.commit()
  mountains.material_override=landscape_material
  mountains.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  distant.add_child(mountains)

func outline(shore: bool=false) -> PackedVector2Array:
 var points=PackedVector2Array()
 for i in 48:
  var a=float(i)/48*TAU
  var radius=1+.035*sin(a*7)+.025*cos(a*11)+.16*exp(-pow((a-2.38)/.55,2))
  if shore:
   radius*=1-.54*exp(-pow((a-.63)/.43,2))
  points.append(Vector2(cos(a)*10.2*radius,sin(a)*7.4*radius))
 return points

func _build_land() -> void:
 var boundary=outline()
 var base=_extrude(boundary,-1.7,-.65,"9b8467")
 base.reparent(cutaway)
 _extrude(boundary,-.65,.12,"bd9d70").reparent(cutaway)
 var top=_extrude(outline(true),.12,.46,"86ab73")
 top.set_meta("role","ground")
 land_material=top.material_override
 cutaway.hide()
 water_garden=Node3D.new()
 water_garden.name="DecorativeWaterGarden"
 water_garden.set_meta("decorative_only",true)
 add_child(water_garden)
 var water=_extrude(boundary,.13,.145,"418384")
 water.material_override=water_shader
 water.set_meta("keep",true)
 water.reparent(water_garden)
 var edge=outline(true)
 for i in 30:
  var p=edge[int(float(i)/30*edge.size())]*.98
  var rock=ball(self,Vector3(p.x,.38,p.y),Vector3(.55+randf()*.35,.38,.48),["99aaa0","afbaa6","8b9f97"][i%3],8)
  rock.rotation.y=randf()*TAU
 for i in 16:
  var t=float(i)/15
  var p=Vector3(-.7+sin(t*3)*.3,.51,5.9-t*10.1)
  var stone=cylinder(self,p,.44,.09,["c7c9b0","b8bfac","d2ceb5"][i%3],-1,7)
  stone.scale=Vector3(1.25,1,.7)
 for i in 8:
  var t=float(i)/7
  cylinder(self,Vector3(-6.9+t*6.5,.51,-1.4),.35,.08,"c4c6ad",-1,7)
 for i in 5:
  ball(self,Vector3(.5+i*.9,.65,-5.1+sin(i)*.4),Vector3(1.0,.9+randf()*.4,.9),"96aaa3",9)

func _build_house() -> void:
 house_model=Node3D.new()
 house_model.name="PaintedFarmhouse"
 house_model.position=Vector3(-3.5,.46,-3.7)
 add_child(house_model)
 var root=house_model
 box(root,Vector3(0,.10,0),Vector3(6.1,.20,4.0),"c5c8ae")
 box(root,Vector3(0,1.55,0),Vector3(5.45,2.85,3.15),"e0d6b4")
 box(root,Vector3(0,.18,1.92),Vector3(6.0,.18,.85),"d3ceb4")
 for y in 2:
  box(root,Vector3(0,.03-y*.055,2.38+y*.23),Vector3(2.1+y*.35,.12,.27),"c3c1ac")
 for x in [-2.72,0,2.72]:
  box(root,Vector3(x,1.55,1.66),Vector3(.14,2.9,.17),"8c6548")
 box(root,Vector3(0,2.85,1.76),Vector3(5.9,.18,.18),"a78256")
 box(root,Vector3(0,1.1,1.60),Vector3(1.12,2.1,.12),"9c7048")
 for x in [-.4,-.2,0,.2,.4]:
  box(root,Vector3(x,1.12,1.69),Vector3(.025,1.95,.025),"bd9661")
 for x in [-1.73,1.73]:
  var window=box(root,Vector3(x,1.7,1.63),Vector3(1.27,1.37,.09),"eacb8c")
  window.material_override=material("eacb8c")
  window.material_override.emission_enabled=true
  for j in 5:
   box(root,Vector3(x-.56+j*.28,1.7,1.70),Vector3(.035,1.46,.04),"826444")
  for y in [.99,1.46,1.93,2.4]:
   box(root,Vector3(x,y,1.70),Vector3(1.36,.035,.04),"826444")
 _roof(root,Vector3(0,2.90,0),6.5,4.7,1.20)
 for x in [-2.1,2.1]:
  _lantern(root,Vector3(x,2.30,1.97))
 _pavilion(Vector3(6.7,.47,-3.5))
 # Small arched stone footbridge above the decorative cove.
 for i in 10:
  var x=2.9+i*.32
  var y=.55+sin(float(i)/9*PI)*.52
  box(self,Vector3(x,y,1.40),Vector3(.34,.16,1.0),"b8c2b1")
  if i%3==0:
   for side in [-1,1]:
    cylinder(self,Vector3(x,y+.34,1.4+side*.51),.065,.65,"a6b7a8",-1,6)
  if i<9:
   var ny=.55+sin(float(i+1)/9*PI)*.52
   for side in [-1,1]:
    rod(self,Vector3(x,y+.58,1.4+side*.51),Vector3(x+.32,ny+.58,1.4+side*.51),.055,"b9c4b4")

func _roof(parent: Node3D, pos: Vector3, width: float, depth: float, rise: float) -> void:
 var st=SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for side in [-1,1]:
  for row in 6:
   for col in 18:
    var points=[]
    for cell in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
     var u=(col+cell.x)/18.0
     var v=(row+cell.y)/6.0
     var x=(u-.5)*width
     var z=side*v*depth*.5
     var y=rise*(1-v)+pow(v,3)*.22+pow(absf(u-.5)*2,6)*.20
     points.append(pos+Vector3(x,y,z))
    for id in ([0,1,2,1,3,2] if side>0 else [0,2,1,1,2,3]):
     st.add_vertex(points[id])
 st.generate_normals()
 mesh(parent,st.commit(),Vector3.ZERO,"536f70")
 for i in 22:
  var u=float(i)/21
  var x=(u-.5)*width
  for side in [-1,1]:
   for row in 6:
    var v=float(row)/6
    var nv=float(row+1)/6
    var y=rise*(1-v)+pow(v,3)*.22+pow(absf(u-.5)*2,6)*.20
    var ny=rise*(1-nv)+pow(nv,3)*.22+pow(absf(u-.5)*2,6)*.20
    rod(parent,pos+Vector3(x,y+.025,side*v*depth*.5),pos+Vector3(x,ny+.025,side*nv*depth*.5),.037,"647e7b")
 rod(parent,pos+Vector3(-width*.51,rise+.05,0),pos+Vector3(width*.51,rise+.05,0),.09,"829184")
 for x in [-width*.52,width*.52]:
  rod(parent,pos+Vector3(x,rise,0),pos+Vector3(x*1.03,rise+.30,0),.075,"69827e")
 for i in 23:
  var x=-width*.5+i*width/22
  for side in [-1,1]:
   rod(parent,pos+Vector3(x,.22,side*depth*.5),pos+Vector3(x,.30,side*(depth*.5-.18)),.055,"7f958a")

func _lantern(parent: Node3D, p: Vector3) -> void:
 rod(parent,p+Vector3(0,.2,0),p+Vector3(0,.57,0),.018,"a17d50")
 var lamp=ball(parent,p,Vector3(.27,.39,.27),"efc774",10)
 lamp.material_override.emission_enabled=true
 cylinder(parent,p+Vector3(0,.20,0),.12,.04,"967449",-1,8)
 cylinder(parent,p-Vector3(0,.20,0),.12,.04,"967449",-1,8)
 rod(parent,p-Vector3(0,.20,0),p-Vector3(0,.40,0),.025,"d7a568")

func _pavilion(p: Vector3) -> void:
 var root=Node3D.new()
 root.position=p
 add_child(root)
 cylinder(root,Vector3(0,.07,0),1.45,.14,"b8c0ad",-1,8)
 for x in [-.85,.85]:
  for z in [-.85,.85]:
   cylinder(root,Vector3(x,1.15,z),.075,2.3,"a17e55",-1,8)
 _roof(root,Vector3(0,2.3,0),3.0,3.0,.7)
 box(root,Vector3(0,.48,.8),Vector3(1.7,.13,.32),"b0956c")
 _lantern(root,Vector3(0,1.85,.1))

func _build_garden() -> void:
 for i in 12:
  var node=Node3D.new()
  node.position=plot_position(i)
  add_child(node)
  plots.append(node)
  var st=SurfaceTool.new()
  st.begin(Mesh.PRIMITIVE_TRIANGLES)
  var vertices=[]
  for z in 13:
   for x in 17:
    var u=(float(x)/16-.5)*2
    var v=(float(z)/12-.5)*2
    var r=pow(pow(absf(u),4)+pow(absf(v),4),.25)
    var shoulder=1-smoothstep(.66,1.0,r)
    vertices.append(Vector3(u*.90,-.125+shoulder*(.18+.012*cos(u*PI*4)),v*.76))
  for z in 12:
   for x in 16:
    var a=z*17+x
    for index in [a,a+1,a+17,a+1,a+18,a+17]:
     st.add_vertex(vertices[index])
  st.index()
  st.generate_normals()
  mesh(node,st.commit(),Vector3.ZERO,"947452").set_meta("role","soil")
  var crops=Node3D.new()
  node.add_child(crops)
  crop_nodes.append(crops)

func select_plot(index: int) -> void:
 selector.hide()
 _paint("soil").set_shader_parameter("selected",index>=0)
 if index>=0:
  var p=plot_position(index)
  _paint("soil").set_shader_parameter("selected_center",Vector2(p.x,p.z))

func _tree(p: Vector3, scale_factor: float, parent: Node3D) -> void:
 var root=Node3D.new()
 parent.add_child(root)
 root.position=p
 root.scale=Vector3.ONE*scale_factor
 rod(root,Vector3.ZERO,Vector3(.15,2.8,0),.22,"92724f")
 for i in 5:
  var angle=i*TAU/5
  var end=Vector3(cos(angle)*1.0,3.25+sin(i)*.4,sin(angle)*.8)
  rod(root,Vector3(.12,1.7,0),end,.07,"a18458")
  ball(root,end,Vector3(1.38,.78,1.07),LEAF[i%LEAF.size()],12)
 for i in 22:
  var a=i*TAU/22
  var anchor=Vector3(cos(a)*1.55,3.3+sin(a*3)*.22,sin(a)*1.2)
  var st=SurfaceTool.new()
  st.begin(Mesh.PRIMITIVE_TRIANGLES)
  for k in 5:
   var t=float(k)/5
   var nt=float(k+1)/5
   var aa=anchor+Vector3(sin(t*2.0+a)*.17,-t*1.65,cos(a)*t*.18)
   var bb=anchor+Vector3(sin(nt*2.0+a)*.17,-nt*1.65,cos(a)*nt*.18)
   var side=Vector3(cos(a),0,sin(a))*.13
   for v in [aa-side*(1-t*.8),bb-side*(1-nt*.8),aa+side*(1-t*.8),aa+side*(1-t*.8),bb-side*(1-nt*.8),bb+side*(1-nt*.8)]:
    st.add_vertex(v)
  st.generate_normals()
  mesh(root,st.commit(),Vector3.ZERO,LEAF[(i+2)%LEAF.size()])

func _bamboo(p: Vector3) -> void:
 for i in 5:
  var at=p+Vector3(sin(i*2)*.35,0,cos(i*2)*.3)
  var h=2.1+i*.17
  rod(self,at,at+Vector3(.14,h,.1),.035,"8eac76")
  for j in 4:
   var tip=at+Vector3(.14,.9+j*.33,.1)
   for side in [-1,1]:
    var leaf=ball(self,tip+Vector3(side*.25,.05,0),Vector3(.55,.055,.12),LEAF[1],8)
    leaf.rotation.z=side*.25

func _grass(p: Vector3, height: float) -> void:
 var st=SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in 6:
  var a=i*TAU/6
  var side=Vector3(-sin(a),0,cos(a))*height*.08
  var mid=Vector3(cos(a)*height*.15,height*.53,sin(a)*height*.15)
  var tip=Vector3(cos(a)*height*.4,height,sin(a)*height*.4)
  for v in [-side,mid-side,side,side,mid-side,mid+side,mid-side,tip,mid+side]:
   st.add_vertex(v)
 st.generate_normals()
 mesh(self,st.commit(),p,LEAF[3])

func _build_plants() -> void:
 _tree(Vector3(-8,.46,-2.8),1.0,self)
 _tree(Vector3(6.4,.46,-5.1),.75,self)
 for p in [Vector3(-7.8,.46,-5.2),Vector3(.2,.46,-4.4),Vector3(8.1,.46,-3.8)]:
  _bamboo(p)
 var shore=outline(true)
 for i in 135:
  var p=Vector3(randf_range(-9,9),.47,randf_range(-6.5,6.5))
  if not Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),shore) or plot_at(p)>=0 or (p.x>-7 and p.x<.3 and p.z<-1.1):
   continue
  _grass(p,randf_range(.25,.6))
  if i%4==0:
   _flowers(p)

func _flowers(p: Vector3) -> void:
 for i in 3:
  var at=p+Vector3(cos(i*2.1)*.15,.25+sin(i)*.08,sin(i*2.1)*.15)
  rod(self,p,at,.018,LEAF[0])
  for j in 5:
   var a=j*TAU/5
   ball(self,at+Vector3(cos(a)*.055,0,sin(a)*.055),Vector3(.085,.045,.07),"eddbac",6)
  ball(self,at,Vector3(.06,.045,.06),"d9b562",6)

func _build_water_garden() -> void:
 boat_model=Node3D.new()
 boat_model.name="PaintedMooredBoat"
 boat_model.position=Vector3(5.6,.15,3.5)
 boat_model.rotation.y=.6
 add_child(boat_model)
 var hull=PackedVector2Array([Vector2(-1.65,0),Vector2(-1.25,-.57),Vector2(.95,-.57),Vector2(1.65,0),Vector2(.95,.57),Vector2(-1.25,.57)])
 # Low-poly pointed hull, with distinct plank bands and an arched cloth canopy.
 var st=SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in hull.size():
  var a=hull[i]
  var b=hull[(i+1)%hull.size()]
  for v in [Vector3(a.x*.8,0,a.y*.8),Vector3(a.x,.38,a.y),Vector3(b.x,.38,b.y),Vector3(a.x*.8,0,a.y*.8),Vector3(b.x,.38,b.y),Vector3(b.x*.8,0,b.y*.8)]:
   st.add_vertex(v)
 st.generate_normals()
 mesh(boat_model,st.commit(),Vector3.ZERO,"b59664")
 box(boat_model,Vector3(0,.15,0),Vector3(2.6,.15,.83),"c4a974")
 for x in [-1.1,-.75,-.4,-.05,.3,.65,1.0]:
  box(boat_model,Vector3(x,.245,0),Vector3(.027,.03,.87),"a38657")
 var roof_surface=SurfaceTool.new()
 roof_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in 12:
  var a=i*PI/12
  var b=(i+1)*PI/12
  for v in [Vector3(-.85,.35+sin(a)*.82,cos(a)*.56),Vector3(.62,.35+sin(a)*.82,cos(a)*.56),Vector3(-.85,.35+sin(b)*.82,cos(b)*.56),Vector3(.62,.35+sin(a)*.82,cos(a)*.56),Vector3(.62,.35+sin(b)*.82,cos(b)*.56),Vector3(-.85,.35+sin(b)*.82,cos(b)*.56)]:
   roof_surface.add_vertex(v)
 roof_surface.generate_normals()
 mesh(boat_model,roof_surface.commit(),Vector3.ZERO,"dccb96")
 for x in [-.85,-.48,-.11,.26,.63]:
  for i in 8:
   var a=i*PI/8
   var b=(i+1)*PI/8
   rod(boat_model,Vector3(x,.36+sin(a)*.84,cos(a)*.58),Vector3(x,.36+sin(b)*.84,cos(b)*.58),.018,"a58b5e")
 for x in [4.8,6.4]:
  for z in [1.25,2.55]:
   cylinder(self,Vector3(x,.51,z),.085,.9,"9e8358",.07,8)
 for i in 8:
  box(self,Vector3(5.6,.46,1.25+i*.17),Vector3(1.6,.10,.14),"b49a6b")
 for x in [-.1,1.2]:
  cylinder(self,Vector3(x,.84,5.8),.09,.78,"a18b60",.08,8)
 rod(self,Vector3(-.1,1.05,5.8),Vector3(.55,.92,5.8),.018,"caba8f")
 rod(self,Vector3(.55,.92,5.8),Vector3(1.2,1.05,5.8),.018,"caba8f")
 var leaf_mesh=SurfaceTool.new()
 leaf_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in 24:
  var a=.2+i*(TAU-.4)/24
  var b=.2+(i+1)*(TAU-.4)/24
  for v in [Vector3.ZERO,Vector3(cos(a),.08,sin(a)),Vector3(cos(b),.08,sin(b))]:
   leaf_mesh.set_color(Color("a0be75") if v==Vector3.ZERO else Color("80a965"))
   leaf_mesh.set_normal(Vector3.UP)
   leaf_mesh.add_vertex(v)
 var instances=MultiMesh.new()
 instances.transform_format=MultiMesh.TRANSFORM_3D
 instances.mesh=leaf_mesh.commit()
 var poses=[]
 var rng=RandomNumberGenerator.new()
 rng.seed=2718
 for attempt in 400:
  var p=Vector3(rng.randf_range(2,9),.20,rng.randf_range(1,6.5))
  var flat=Vector2(p.x,p.z)
  if Geometry2D.is_point_in_polygon(flat,outline(true)) or not Geometry2D.is_point_in_polygon(flat,outline()) or flat.distance_to(Vector2(5.6,3.5))<1.65:
   continue
  var nearby=false
  for other in lotus_positions:
   if p.distance_to(other)<.6:
    nearby=true
  if nearby:
   continue
  lotus_positions.append(p)
  var radius=rng.randf_range(.25,.43)
  poses.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*radius),p))
  if poses.size()>=18:
   break
 instances.instance_count=poses.size()
 for i in poses.size():
  instances.set_instance_transform(i,poses[i])
  if i%4==0:
   var p: Vector3=poses[i].origin+Vector3(0,.20,0)
   rod(self,poses[i].origin,p,.018,LEAF[1])
   for j in 7:
    var angle=j*TAU/7
    var petal=ball(self,p+Vector3(cos(angle)*.10,.03,sin(angle)*.10),Vector3(.16,.12,.09),"e9a9b1",8)
    petal.rotation.y=-angle
   ball(self,p+Vector3(0,.06,0),Vector3(.11,.09,.11),"efce7c",8)
 lotus_leaves=MultiMeshInstance3D.new()
 lotus_leaves.multimesh=instances
 lotus_leaves.material_override=_paint("solid")
 lotus_leaves.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 water_garden.add_child(lotus_leaves)

func refresh(force: bool=false) -> void:
 var decoration_signature=JSON.stringify(farm.data.decorations)
 if force or decoration_signature!=last_signature:
  last_signature=decoration_signature
  for child in decoration_root.get_children():
   child.free()
  for item in farm.data.decorations:
   var p=Vector3(item.x,.46,item.z)
   if item.kind=="flowers":
    flowers(decoration_root,p)
   else:
    barrel(decoration_root,p)
  _bake_branch(decoration_root)
 var signature=""
 for plot in farm.data.plots:
  signature+="%s:%s:%s;" % [plot.crop,farm.stage(plot),plot.get("health","healthy")]
 if not force and signature==last_stages:
  return
 last_stages=signature
 for i in crop_nodes.size():
  for child in crop_nodes[i].get_children():
   child.free()
  var plot=farm.data.plots[i]
  if plot.crop=="":
   continue
  var config=FarmState.CROPS[plot.crop]
  var ratio=float(farm.stage(plot))/maxi(1,config.stages.size()-1)
  var key="%s:%d:%s" % [plot.crop,roundi(ratio*4),plot.get("health","healthy")]
  if not crop_cache.has(key):
   _build_crop(crop_nodes[i],plot.crop,roundi(ratio*4))
   if plot.get("health","healthy") in ["dead","wilted"]:
    for leaf in crop_nodes[i].find_children("*","MeshInstance3D",true,false):
     leaf.material_override=material("aa936c")
   crop_cache[key]=_bake_branch(crop_nodes[i])
  else:
   for part in crop_cache[key]:
    var node=MeshInstance3D.new()
    node.mesh=part.mesh
    node.material_override=part.material
    node.cast_shadow=part.shadow
    crop_nodes[i].add_child(node)

func _build_crop(parent: Node3D, kind: String, stage: int) -> void:
 var h=[.05,.20,.38,.62,.78][stage]
 for x in [-.47,0,.47]:
  for z in [-.3,.3]:
   var p=Vector3(x,.08,z)
   if stage==0:
    ball(parent,p,Vector3(.10,.065,.10),"c7a77c",6)
    continue
   cylinder(parent,p+Vector3(0,h*.45,0),.018,h,LEAF[0],-1,6)
   if kind=="cabbage":
    for j in 5:
     var a=j*TAU/5
     var leaf=ball(parent,p+Vector3(cos(a)*h*.24,h*.4,sin(a)*h*.24),Vector3(h*.6,h*.40,h*.45),LEAF[2 if j%2 else 3],8)
     leaf.rotation.y=a
    ball(parent,p+Vector3(0,h*.5,0),Vector3(h*.47,h*.48,h*.47),LEAF[3],8)
   elif kind in ["wheat","rice"]:
    for j in 3:
     var tip=p+Vector3((j-1)*.065,h,0)
     rod(parent,p,tip,.012,LEAF[2])
     for k in 3:
      ball(parent,tip+Vector3(.02*(k%2),k*.05,0),Vector3(.065,.12,.07),"d9c584" if stage>=3 else LEAF[3],6)
   else:
    for j in 4:
     var a=j*TAU/4
     var leaf=ball(parent,p+Vector3(cos(a)*h*.2,h*.55,sin(a)*h*.2),Vector3(.12,h*.75,.15) if kind=="carrot" else Vector3(h*.65,.06,h*.25),LEAF[1 if j%2 else 2],8)
     leaf.rotation.y=a
     leaf.rotation.z=sin(a)*.35
    if stage>=3:
     if kind=="pumpkin":
      ball(parent,p+Vector3(0,.14,0),Vector3(.34,.25,.33),"daaa64",10)
     elif kind=="corn":
      ball(parent,p+Vector3(.11,h*.65,0),Vector3(.13,.32,.13),"e9ce7f",8)
     elif kind in ["tomato","eggplant"]:
      ball(parent,p+Vector3(.10,h*.55,.09),Vector3(.17,.24 if kind=="eggplant" else .16,.16),"9272a4" if kind=="eggplant" else "d98069",8)

func _precipitation(mat: ShaderMaterial, count: int, snow: bool=false, drips: bool=false) -> MultiMeshInstance3D:
 var shape=QuadMesh.new()
 shape.size=Vector2(.10,.10) if snow else Vector2(.018,.28 if not drips else .14)
 var instances=MultiMesh.new()
 instances.transform_format=MultiMesh.TRANSFORM_3D
 instances.use_custom_data=true
 instances.mesh=shape
 instances.instance_count=count
 var rng=RandomNumberGenerator.new()
 rng.seed=811 if snow else 531
 for i in count:
  var x=rng.randf_range(-9,9)
  var z=rng.randf_range(-6,6)
  if drips:
   x=-6.0+(i%8)*.72
   z=-1.27 if i<8 else -5.6
  var landing=.15 if not Geometry2D.is_point_in_polygon(Vector2(x,z),outline(true)) else .48
  if not drips and x>-6.75 and x<-.25 and z>-6.05 and z<-1.35:
   var v=absf(z+3.7)/2.35
   var u=absf(x+3.5)/3.25
   landing=3.44+1.2*(1-v)+pow(v,3)*.22+pow(u,6)*.20
  elif not drips and absf(x-6.7)<1.5 and absf(z+3.5)<1.5:
   var v=absf(z+3.5)/1.5
   landing=2.85+.7*(1-v)+pow(v,3)*.22
  instances.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*rng.randf_range(.75,1.15)),Vector3(x,landing,z)))
  instances.set_instance_custom_data(i,Color(rng.randf(),rng.randf(),0,1))
 var node=MultiMeshInstance3D.new()
 node.multimesh=instances
 node.material_override=mat
 node.custom_aabb=AABB(Vector3(-15,-1,-12),Vector3(30,18,24))
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(node)
 return node

func _build_weather() -> void:
 rain_material=ShaderMaterial.new()
 rain_material.shader=load("res://assets/shaders/precipitation_v2.gdshader")
 rain_material.set_shader_parameter("speed",6.5)
 snow_material=rain_material.duplicate()
 snow_material.set_shader_parameter("snow_mode",1.0)
 snow_material.set_shader_parameter("speed",1.0)
 drip_material=rain_material.duplicate()
 drip_material.set_shader_parameter("height",3.1)
 drip_material.set_shader_parameter("speed",4.5)
 rain_instances=_precipitation(rain_material,144)
 snow_instances=_precipitation(snow_material,144,true)
 drip_instances=_precipitation(drip_material,16,false,true)
 impact_material=ShaderMaterial.new()
 impact_material.shader=load("res://assets/shaders/impacts_v2.gdshader")
 var st=SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in 12:
  var z=5.4-i*.75
  var center=Vector3(-.7+sin(i*.15)*.3,.565,z)
  for pair in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
   st.set_uv(pair*.5+Vector2(.5,.5))
   st.set_color(Color(float(i)/12,0,0,1))
   st.add_vertex(center+Vector3(pair.x*.28,0,pair.y*.28))
 st.generate_normals()
 var impacts=MeshInstance3D.new()
 impacts.mesh=st.commit()
 impacts.material_override=impact_material
 impacts.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(impacts)

func set_companion(value: bool) -> void:
 companion=value
 distant.visible=not value
 cutaway.visible=value
 get_viewport().transparent_bg=value
 world.environment.background_color=Color(0,0,0,0) if value else Color("b5cec7")
 camera.attributes=null

func update_environment(solar: Dictionary, code: int, quality: int) -> void:
 weather_type=WeatherService.effect_type(code)
 weather_quality=quality
 environment_controller.submit(solar,code,float(farm.temperature if preview_temperature==null else preview_temperature),quality)
 _apply_environment()

func _apply_environment() -> void:
 if environment_controller.solar.is_empty():
  return
 var params=environment_controller.current
 var solar=environment_controller.solar
 var day=float(params.daylight)
 var cloud=float(params.cloud)
 sun.rotation=Vector3(-maxf(.02,float(solar.altitude)),PI-float(solar.azimuth),0)
 sun.visible=float(solar.altitude)>deg_to_rad(-2)
 sun.light_color=Color("f2b47d").lerp(Color("fff1d9"),day)
 sun.light_energy=lerpf(.0,1.05,day)*lerpf(1.0,.25,cloud)
 sun.shadow_opacity=lerpf(.78,.18,cloud)
 var lunar=solar.moon
 moon.rotation=Vector3(-float(lunar.altitude),PI-float(lunar.azimuth),0)
 moon.visible=lunar.altitude>0 and day<.95
 moon_disc.visible=moon.visible
 moon_disc_material.set_shader_parameter("illumination",float(lunar.illumination))
 moon_disc_material.set_shader_parameter("cloud",cloud)
 moon.shadow_enabled=sun.shadow_enabled and not sun.visible
 moon.light_energy=(1-day)*(.07+.37*pow(float(lunar.illumination),2))*smoothstep(0,.15,float(lunar.altitude))*lerpf(1.0,.5,cloud)
 world.environment.ambient_light_color=Color("718ab2").lerp(Color("c5d9d0"),day).lerp(Color("b5c6cd"),cloud*day*.3)
 world.environment.ambient_light_energy=lerpf(.34,.60,day)+cloud*.10*day
 world.environment.background_color=Color(0,0,0,0) if companion else Color("182d49").lerp(Color("b5cec7"),day)
 world.environment.fog_enabled=not companion
 world.environment.fog_density=lerpf(.001,.025,float(params.fog))
 world.environment.fog_light_color=Color("263b54").lerp(Color("bdcfc9"),day)
 var direction=Vector2(sin(float(solar.azimuth)),cos(float(solar.azimuth)))
 for mat in paint.values():
  mat.set_shader_parameter("wetness",params.wetness)
  mat.set_shader_parameter("snow_cover",0.0)
  mat.set_shader_parameter("daylight",day)
  mat.set_shader_parameter("wind",params.wind)
  mat.set_shader_parameter("wind_direction",Vector2(params.wind_x,params.wind_z))
  mat.set_shader_parameter("autumn",1.0 if int(solar.date.month) in [9,10,11] else 0.0)
  mat.set_shader_parameter("shadow_direction",direction)
  mat.set_shader_parameter("shadow_strength",(.25 if sun.visible else .08)*lerpf(1.0,.22,cloud))
 water_shader.set_shader_parameter("rain",params.rain)
 water_shader.set_shader_parameter("cloud",cloud)
 water_shader.set_shader_parameter("wind",params.wind)
 water_shader.set_shader_parameter("daylight",day)
 water_shader.set_shader_parameter("ice",0.0)
 sky_material.set_shader_parameter("daylight",day)
 sky_material.set_shader_parameter("cloud",cloud)
 landscape_material.set_shader_parameter("daylight",day)
 landscape_material.set_shader_parameter("cloud",cloud)
 sky_material.set_shader_parameter("moon_visibility",float(lunar.illumination) if lunar.altitude>0 else 0.0)
 if rain_material==null:
  return
 var budget=environment_controller.particle_budget(companion)
 if budget!=last_budget:
  rain_instances.multimesh.visible_instance_count=budget
  snow_instances.multimesh.visible_instance_count=budget
  last_budget=budget
 rain_instances.visible=params.rain>.01
 snow_instances.visible=params.snowfall>.01
 drip_instances.visible=params.rain>.18
 rain_material.set_shader_parameter("amount",params.rain)
 rain_material.set_shader_parameter("speed",5.0+params.rain*3.0)
 rain_material.set_shader_parameter("wind",params.wind)
 rain_material.set_shader_parameter("wind_direction",Vector2(params.wind_x,params.wind_z))
 snow_material.set_shader_parameter("amount",params.snowfall)
 snow_material.set_shader_parameter("wind",params.wind)
 snow_material.set_shader_parameter("wind_direction",Vector2(params.wind_x,params.wind_z))
 drip_material.set_shader_parameter("amount",params.rain)
 impact_material.set_shader_parameter("rain",params.rain)

func _process(delta: float) -> void:
 environment_controller.advance(minf(delta,2.0))
 _apply_environment()
