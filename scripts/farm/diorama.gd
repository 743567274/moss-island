class_name Diorama
extends Node3D

var materials = {}
var plots: Array[Node3D] = []
var crop_nodes: Array[Node3D] = []
var decoration_root: Node3D
var selector: Node3D
var sun: DirectionalLight3D
var world: WorldEnvironment
var camera: Camera3D
var particles: CPUParticles3D
var land_material: StandardMaterial3D
var farm: FarmState
var last_signature = ""
var weather_type = "clear"
var weather_quality = 1
var last_stages = ""

func material(hex: String, roughness: float = 0.9) -> StandardMaterial3D:
	if not materials.has(hex):
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(hex)
		mat.roughness = roughness
		materials[hex] = mat
	return materials[hex]

func mesh(parent: Node3D, shape: Mesh, pos: Vector3, color: String) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	node.mesh = shape
	node.material_override = material(color)
	node.position = pos
	parent.add_child(node)
	return node

func box(parent: Node3D, pos: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	var shape = BoxMesh.new()
	shape.size = size
	return mesh(parent, shape, pos, color)

func ball(parent: Node3D, pos: Vector3, size: Vector3, color: String, segments: int = 12) -> MeshInstance3D:
	var shape = SphereMesh.new()
	shape.radial_segments = segments
	shape.rings = 6
	var node = mesh(parent, shape, pos, color)
	node.scale = size
	return node

func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: String, top: float = -1.0, segments: int = 12) -> MeshInstance3D:
	var shape = CylinderMesh.new()
	shape.bottom_radius = radius
	shape.top_radius = radius if top < 0 else top
	shape.height = height
	shape.radial_segments = segments
	return mesh(parent, shape, pos, color)

func rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, color: String) -> MeshInstance3D:
	var node = cylinder(parent, (a + b) * 0.5, radius, a.distance_to(b), color, -1, 8)
	var direction = (b - a).normalized()
	if absf(direction.dot(Vector3.UP)) < 0.999:
		node.quaternion = Quaternion(Vector3.UP, direction)
	return node

func initialize(state: FarmState) -> void:
	farm = state
	seed(42)
	_build_environment()
	_build_land()
	_build_house()
	_build_garden()
	_build_plants()
	decoration_root = Node3D.new()
	add_child(decoration_root)
	selector = Node3D.new()
	add_child(selector)
	for x in [-0.83, 0.83]:
		box(selector, Vector3(x, 0.03, 0), Vector3(0.045, 0.05, 1.48), "fff0bd")
	for z in [-0.73, 0.73]:
		box(selector, Vector3(0, 0.03, z), Vector3(1.7, 0.05, 0.045), "fff0bd")
	selector.hide()
	_merge_static_geometry()
	refresh(true)

func _merge_static_geometry() -> void:
	# Bake fixed scenery into one mesh per material. Crops and selected beds
	# stay separate, so rendering cost does not scale with every fence rail or leaf.
	var batches={}
	var sources=find_children("*","MeshInstance3D",true,false)
	for node in sources:
		var dynamic=false
		for root_node in crop_nodes+[decoration_root,selector]:
			if root_node.is_ancestor_of(node):
				dynamic=true
				break
		if dynamic:
			continue
		var mat=node.material_override
		var key=mat.get_instance_id()
		if not batches.has(key):
			var st=SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			batches[key]={"surface":st,"material":mat}
		batches[key].surface.append_from(node.mesh,0,node.global_transform)
		node.free()
	for key in batches:
		var instance=MeshInstance3D.new()
		instance.mesh=batches[key].surface.commit()
		instance.material_override=batches[key].material
		add_child(instance)

func _build_environment() -> void:
	world = WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("ced9c9")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("d4e2dd")
	world.environment.ambient_light_energy = 0.4
	world.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_color = Color("fff0d0")
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.light_angular_distance = 1.2
	sun.shadow_bias = 0.1
	sun.shadow_normal_bias = 2.0
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 26.5
	camera.position = Vector3(23, 25, 28)
	add_child(camera)
	camera.look_at(Vector3(0, 0.5, 0))
	camera.far = 150
	camera.current = true
	var backdrop=box(self, Vector3(0, -1.65, 0), Vector3(200, 0.25, 200), "c2cdbb")
	var backdrop_mat=material("c2cdbb").duplicate()
	backdrop_mat.disable_receive_shadows=true
	backdrop_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	backdrop_mat.albedo_color=Color("d4ddcf")
	backdrop.material_override=backdrop_mat
	particles = CPUParticles3D.new()
	particles.emitting = false
	particles.amount = 120
	particles.lifetime = 2.4
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(9, 0, 7)
	particles.position = Vector3(0, 9, 0)
	particles.direction = Vector3(0.1, -1, 0)
	particles.spread = 4
	particles.gravity = Vector3(0, -2, 0)
	particles.initial_velocity_min = 4.0
	particles.initial_velocity_max = 6.0
	var drop = BoxMesh.new()
	drop.size = Vector3(0.025, 0.20, 0.025)
	drop.material = material("c4dbe1")
	particles.mesh = drop
	add_child(particles)

func _build_land() -> void:
	# Chamfered layered island. Flat shaded sides retain an earthy material contrast.
	var outline = PackedVector2Array([Vector2(-8.5,-6.7), Vector2(7.8,-6.7), Vector2(9.1,-5.4), Vector2(9.1,5.3), Vector2(7.8,6.6), Vector2(-8.1,6.6), Vector2(-9.3,5.4), Vector2(-9.3,-5.4)])
	_extrude(outline, -1.45, -0.5, "987657")
	_extrude(outline, -0.5, 0.05, "b79665")
	var top = _extrude(outline, 0.05, 0.42, "90aa73")
	land_material = top.material_override
	# Soil layers along the front edge, small embedded stones.
	for i in 34:
		var x = randf_range(-8.1, 7.8)
		ball(self, Vector3(x, randf_range(-1.2, -0.5), 6.61), Vector3(randf_range(.08,.25), .09, .045), ["cbb28b", "7f6a51", "af906d"][i%3], 8)
	# Warm gravel paths: one sweeping main lane and a narrow barn approach.
	box(self, Vector3(-0.2, .44, 2.7), Vector3(1.45, .05, 7.2), "c7b38a")
	box(self, Vector3(0.5, .45, -1.35), Vector3(12.4, .045, 1.12), "c7b38a")
	for i in 38:
		var z = randf_range(-.9,6.05)
		ball(self, Vector3(randf_range(-.8,.45),.49,z), Vector3(.06,.025,.05), "dfceaa", 8)
	for i in 9:
		var stone = cylinder(self, Vector3(-1.2-i*.65,.47,-1.35),.30,.07,"d4cbb1",-1,6)
		stone.scale.z = .75
		stone.rotation.y = randf()*PI

func _extrude(outline: PackedVector2Array, bottom: float, top: float, color: String) -> MeshInstance3D:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outline.size():
		var a = outline[i]
		var b = outline[(i+1)%outline.size()]
		var vertices = [Vector3(0,top,0), Vector3(b.x,top,b.y), Vector3(a.x,top,a.y), Vector3(a.x,bottom,a.y), Vector3(a.x,top,a.y), Vector3(b.x,top,b.y), Vector3(a.x,bottom,a.y), Vector3(b.x,top,b.y), Vector3(b.x,bottom,b.y)]
		for j in range(0,vertices.size(),3):
			# Godot uses clockwise front faces.
			st.add_vertex(vertices[j])
			st.add_vertex(vertices[j+2])
			st.add_vertex(vertices[j+1])
	st.generate_normals()
	return mesh(self, st.commit(), Vector3.ZERO, color)

func _build_house() -> void:
	var root = Node3D.new()
	root.position = Vector3(-3.3,.45,-3.9)
	add_child(root)
	box(root, Vector3(0,.12,0), Vector3(4.5,.24,3.65), "c4b89a")
	box(root, Vector3(0,1.3,0), Vector3(3.85,2.4,2.8), "c08467")
	for x in 17:
		box(root, Vector3(-1.8+x*.225,1.3,1.411),Vector3(.025,2.25,.025),"ad725b")
	for z in 12:
		box(root, Vector3(1.93,1.3,-1.3+z*.235),Vector3(.02,2.25,.023),"aa705a")
	for x in [-1.83,1.83]:
		box(root,Vector3(x,1.3,1.45),Vector3(.12,2.45,.12),"ead5af")
	box(root,Vector3(0,.3,1.43),Vector3(3.85,.13,.1),"ead5af")
	box(root,Vector3(0,2.42,1.43),Vector3(3.85,.13,.1),"ead5af")
	# A pitched roof built from two broad panels with timber ribs.
	for side in [-1,1]:
		var roof = box(root, Vector3(side*1.07,2.94,0),Vector3(2.5,.16,3.5),"485f55")
		roof.rotation.z = side * deg_to_rad(-28)
		for k in 10:
			var rib = box(root,Vector3(side*1.07,3.04,-1.55+k*.345),Vector3(2.52,.055,.055),"60756a")
			rib.rotation.z = side*deg_to_rad(-28)
	box(root,Vector3(0,3.52,0),Vector3(.16,.16,3.65),"d6bd8c")
	# Gable triangle fills the roof apex.
	var triangle = SurfaceTool.new()
	triangle.begin(Mesh.PRIMITIVE_TRIANGLES)
	triangle.add_vertex(Vector3(-1.95,2.45,1.42))
	triangle.add_vertex(Vector3(1.95,2.45,1.42))
	triangle.add_vertex(Vector3(0,3.48,1.42))
	triangle.generate_normals()
	var gable = mesh(root,triangle.commit(),Vector3.ZERO,"c08467")
	var double_mat = material("c08467").duplicate()
	double_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	gable.material_override = double_mat
	for x in [-1,1]:
		rod(root,Vector3(x*2.05,2.42,1.55),Vector3(0,3.5,1.55),.065,"e2c99e")
	# Double barn doors and the familiar diagonal braces.
	box(root,Vector3(0,1.05,1.48),Vector3(1.45,1.85,.12),"655747")
	for x in [-.72,0,.72]:
		box(root,Vector3(x,1.08,1.57),Vector3(.055,1.87,.055),"dcc39a")
	box(root,Vector3(0,1.99,1.57),Vector3(1.56,.1,.07),"dcc39a")
	rod(root,Vector3(-.7,.2,1.59),Vector3(-.03,1.92,1.59),.035,"dcc39a")
	rod(root,Vector3(.7,.2,1.59),Vector3(.03,1.92,1.59),.035,"dcc39a")
	for x in [-1.35,1.35]:
		box(root,Vector3(x,1.6,1.46),Vector3(.7,.85,.11),"e5ceaa")
		box(root,Vector3(x,1.6,1.53),Vector3(.52,.65,.05),"8aafae")
		box(root,Vector3(x,1.6,1.58),Vector3(.035,.66,.025),"ead5af")
		box(root,Vector3(x,1.6,1.58),Vector3(.53,.035,.025),"ead5af")
	box(root,Vector3(.9,3.5,-.9),Vector3(.5,1.3,.65),"a48c75")
	box(root,Vector3(.9,4.15,-.9),Vector3(.66,.15,.8),"d6c5a5")
	# Tiny hay bales and a barrel beside the barn.
	for i in 3:
		cylinder(self,Vector3(-6.2,.75,-3.2+i*.67),.38,.65,"c6a96a",-1,10)
	barrel(self,Vector3(-1,.45,-3.2))
	box(self,Vector3(-3.3,.54,-1.99),Vector3(2,.2,.65),"dfd1af")

func _build_garden() -> void:
	for i in 12:
		var node = Node3D.new()
		node.position = plot_position(i)
		add_child(node)
		plots.append(node)
		box(node,Vector3(0,-.01,0),Vector3(1.56,.13,1.32),"775b42")
		for x in [-.82,.82]:
			box(node,Vector3(x,0,0),Vector3(.10,.2,1.50),"aa885b")
		for z in [-.7,.7]:
			box(node,Vector3(0,0,z),Vector3(1.74,.20,.10),"c4a477")
		for k in 4:
			box(node,Vector3(-.57+k*.38,.075,0),Vector3(.035,.02,1.15),"8c6a48")
		var crops = Node3D.new()
		node.add_child(crops)
		crop_nodes.append(crops)
	# A garden sign, with a little sprout emblem rather than floating UI text.
	box(self,Vector3(-7.7,.95,.5),Vector3(.1,1.05,.1),"7d674b")
	box(self,Vector3(-7.7,1.42,.5),Vector3(1.2,.58,.12),"d6bb87")
	rod(self,Vector3(-7.7,1.2,.59),Vector3(-7.7,1.6,.59),.025,"53794d")
	ball(self,Vector3(-7.86,1.48,.59),Vector3(.27,.11,.045),"53794d")
	ball(self,Vector3(-7.55,1.57,.59),Vector3(.27,.11,.045),"53794d")

static func plot_position(index: int) -> Vector3:
	var bed=ReferenceLayout.BEDS[index]
	return ReferenceLayout.world(Vector2(bed.x,bed.y))

func plot_at(point: Vector3) -> int:
	for i in 12:
		var pos = plot_position(i)
		if absf(point.x-pos.x)<.89 and absf(point.z-pos.z)<.77:
			return i
	return -1

func select_plot(index: int) -> void:
	selector.visible = index >= 0
	if index >= 0:
		selector.position = plot_position(index) + Vector3(0,.14,0)

func _build_plants() -> void:
	for data in [[-7.5,-4.7,1.15],[-7.7,-1.7,.9],[-.15,-5.3,1.05],[8,-4.7,1.1],[8,-.1,.85],[-8,4.5,.8],[7.7,5.8,.6]]:
		tree(Vector3(data[0],.44,data[1]),data[2])
	for i in 75:
		var pos=Vector3(randf_range(-8.5,8.3),.46,randf_range(-6,6))
		if plot_at(pos)>=0 or (pos.x>1 and pos.z>1) or absf(pos.x)<1 or pos.distance_to(Vector3(-3,.46,-4))<3.2:
			continue
		if i%4==0:
			flowers(self,pos)
		else:
			for j in 3:
				var blade=box(self,pos+Vector3(j*.07,.13,0),Vector3(.045,.25,.04),"6f8e5c")
				blade.rotation.z=randf_range(-.3,.3)
	for pos in [Vector3(-8,.5,2),Vector3(8,.5,-2),Vector3(-6,.5,-5.7)]:
		ball(self,pos,Vector3(.8,.38,.55),"a4aa92",8)
	# A little windmill beside the field.
	var tower=Node3D.new()
	tower.position=Vector3(7,.5,-5.6)
	add_child(tower)
	cylinder(tower,Vector3(0,1.2,0),.47,2.4,"d2c29b",.29,8)
	cylinder(tower,Vector3(0,2.62,0),.55,.6,"5f7563",0,8)
	for i in 4:
		var sail=box(tower,Vector3(sin(i*PI/2)*.5,2.4+cos(i*PI/2)*.5,.5),Vector3(.18,1.25,.055),"e9dbb7")
		sail.rotation.z=-i*PI/2

func tree(pos: Vector3, factor: float) -> void:
	var root=Node3D.new()
	root.position=pos
	root.scale=Vector3.ONE*factor
	add_child(root)
	cylinder(root,Vector3(0,1.1,0),.19,2.2,"7e7051",.12,9)
	rod(root,Vector3(0,1.1,0),Vector3(-.6,2,0),.08,"7e7051")
	for i in 8:
		var a=float(i)/8*TAU
		var p=Vector3(cos(a)*.65,2.1+randf_range(-.1,.65),sin(a)*.6)
		ball(root,p,Vector3(1.35,1.3,1.3),["7f9b62","93aa70","a7b87c","6f8e59"][i%4])
	ball(root,Vector3(0,3,0),Vector3(1.4,1.25,1.4),"9db47b")

func barrel(parent: Node3D, pos: Vector3) -> void:
	cylinder(parent,pos+Vector3(0,.43,0),.34,.86,"a08258",.31,12)
	for h in [.16,.65]:
		cylinder(parent,pos+Vector3(0,h,0),.35,.07,"626e5a",-1,12)
	cylinder(parent,pos+Vector3(0,.87,0),.29,.025,"bfa16d",-1,12)

func flowers(parent: Node3D, pos: Vector3) -> void:
	for j in 5:
		var p=pos+Vector3(randf_range(-.23,.23),0,randf_range(-.23,.23))
		var h=randf_range(.22,.42)
		cylinder(parent,p+Vector3(0,h*.5,0),.012,h,"6b8855",-1,5)
		for k in 4:
			ball(parent,p+Vector3(cos(k*PI/2)*.06,h,sin(k*PI/2)*.06),Vector3(.10,.06,.10),["e6d59b","e0b9a7","e9e1bd"][j%3],6)
		ball(parent,p+Vector3(0,h+.025,0),Vector3(.05,.05,.05),"c3a253",6)

func refresh(force: bool = false) -> void:
	var stages=""
	for plot in farm.data.plots:
		stages += "%s:%s;" % [plot.crop,farm.stage(plot)]
	if stages!=last_stages or force:
		last_stages=stages
		for i in 12:
			for child in crop_nodes[i].get_children():
				child.free()
			var plot=farm.data.plots[i]
			if plot.crop!="":
				_build_crop(crop_nodes[i],plot.crop,farm.stage(plot))
	var signature=JSON.stringify(farm.data.decorations)
	if signature!=last_signature or force:
		last_signature=signature
		for child in decoration_root.get_children():
			child.free()
		for item in farm.data.decorations:
			var pos=Vector3(item.x,.46,item.z)
			if item.kind=="flowers":
				flowers(decoration_root,pos)
			else:
				barrel(decoration_root,pos)

func _build_crop(parent: Node3D, kind: String, stage: int) -> void:
	var height=[.07,.20,.35,.55,.68][stage]
	for x in [-.48,0,.48]:
		for z in [-.35,.30]:
			var pos=Vector3(x,.08,z)
			if stage==0:
				ball(parent,pos,Vector3(.1,.065,.1),"c7a276",8)
				continue
			cylinder(parent,pos+Vector3(0,height*.5,0),.025,height,"6d8e4e",-1,6)
			if kind=="cabbage":
				for j in 5:
					var a=j*TAU/5
					var leaf=ball(parent,pos+Vector3(cos(a)*height*.22,height*.35,sin(a)*height*.22),Vector3(height*.65,height*.48,height*.6),"8aa967")
					leaf.rotation.y=a
				ball(parent,pos+Vector3(0,height*.55,0),Vector3(height*.55,height*.6,height*.55),"a9c080")
			elif kind=="wheat":
				for j in 3:
					var p=pos+Vector3((j-1)*.07,height,0)
					cylinder(parent,p-Vector3(0,height*.25,0),.016,height*.8,"b6a26a",-1,5)
					ball(parent,p,Vector3(.10,height*.5,.11),"dbc07b" if stage>=3 else "91a266",8)
			else:
				if stage>=3:
					cylinder(parent,pos+Vector3(0,.06,0),.11,.19,"d9924f",.14,8)
				for j in 4:
					var a=j*PI/2
					var leaf=ball(parent,pos+Vector3(cos(a)*.12,height*.72,sin(a)*.12),Vector3(.10,height*.7,.11),["729552","89a65f"][j%2],8)
					leaf.rotation.z=sin(a)*.5
					leaf.rotation.x=cos(a)*.5

func update_environment(solar: Dictionary, code: int, quality: int) -> void:
	var daylight=float(solar.daylight)
	weather_type=WeatherService.effect_type(code)
	weather_quality=quality
	var cloud=0.65 if weather_type in ["rain","storm","fog","snow"] else .9
	sun.rotation=Vector3(-float(solar.altitude), float(solar.azimuth)+PI,0)
	sun.visible=float(solar.altitude)>deg_to_rad(-1)
	sun.light_energy=lerpf(.06,.75,daylight)*cloud
	sun.light_color=Color("ffc598").lerp(Color("fff0d3"),daylight)
	world.environment.ambient_light_energy=lerpf(.25,.4,daylight)
	world.environment.ambient_light_color=Color("7c91b0").lerp(Color("d7e5d3"),daylight)
	world.environment.background_color=Color("354b58").lerp(Color("ced9c9"),daylight)
	world.environment.fog_enabled=weather_type=="fog"
	world.environment.fog_density=.025 if weather_type=="fog" else 0.0
	land_material.albedo_color=Color("c4cfbe") if weather_type=="snow" else (Color("7f9b6b") if weather_type in ["rain","storm"] else Color("90aa73"))
	particles.emitting=quality>0 and weather_type in ["rain","snow","storm"]
	particles.amount=50 if quality<=1 else 140
	if weather_type=="snow":
		particles.mesh.size=Vector3(.06,.06,.06)
		particles.gravity=Vector3(0,-.3,0)
		particles.initial_velocity_min=.8
		particles.initial_velocity_max=1.6
		particles.lifetime=7
		particles.scale_amount_min=1.5
		particles.scale_amount_max=2.0
	else:
		particles.mesh.size=Vector3(.025,.20,.025)
		particles.gravity=Vector3(0,-2,0)
		particles.initial_velocity_min=4
		particles.initial_velocity_max=6
		particles.lifetime=2.4
		particles.scale_amount_min=1
		particles.scale_amount_max=1

