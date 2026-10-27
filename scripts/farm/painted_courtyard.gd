class_name PaintedCourtyard
extends Courtyard

# A bounded in-engine art sample. Shared albedo atlas and authored UVs,
# shaped eaves/timber and clipped leaf cards replace primitive silhouettes.
var authored_materials={}
var leaf_cards=0

func _paint(role: String) -> ShaderMaterial:
 if role not in ["ground","soil"] and not role.begins_with("paint_"):
  return super._paint(role)
 if paint.has(role):
  return paint[role]
 var mat=ShaderMaterial.new()
 if role=="paint_leaves":
  mat.shader=load("res://assets/shaders/painted_leaves.gdshader")
  mat.set_shader_parameter("leaf_map",load("res://assets/painted/willow-bough-bold.png"))
 else:
  mat.shader=load("res://assets/shaders/meadow.gdshader" if role=="ground" else "res://assets/shaders/handpainted.gdshader")
  mat.set_shader_parameter("atlas",load("res://assets/painted/material-atlas.png"))
  mat.set_shader_parameter("grass_map",load("res://assets/painted/meadow-gouache.png"))
  mat.set_shader_parameter("earth_map",load("res://assets/painted/soil-melle.png"))
  mat.set_shader_parameter("path_map",load("res://assets/painted/path-melle.png"))
  var cells={"paint_roof":Vector2(0,0),"paint_wood":Vector2(1,0),"paint_wall":Vector2(2,0),"paint_stone":Vector2(3,0),"paint_bark":Vector2(2,1),"paint_crop":Vector2(3,1)}
  mat.set_shader_parameter("tile",cells.get(role,Vector2.ZERO))
  mat.set_shader_parameter("terrain",1.0 if role=="ground" else 0.0)
  mat.set_shader_parameter("soil",1.0 if role=="soil" else 0.0)
  mat.set_shader_parameter("path",1.0 if role=="paint_path" else 0.0)
  mat.set_shader_parameter("foliage",1.0 if role=="paint_crop" else 0.0)
 paint[role]=mat
 return mat

func _surface(parent: Node3D, st: SurfaceTool, role: String) -> MeshInstance3D:
 st.index()
 st.generate_normals()
 var node=MeshInstance3D.new()
 node.mesh=st.commit()
 if not authored_materials.has(role):
  var mat=StandardMaterial3D.new()
  mat.albedo_color=Color.WHITE
  mat.set_meta("role",role)
  authored_materials[role]=mat
 node.material_override=authored_materials[role]
 node.set_meta("authored_uv",true)
 parent.add_child(node)
 return node

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
 for item in [[a,ua],[b,ub],[c,uc]]:
  st.set_uv(item[1])
  st.add_vertex(item[0])

func _soft_box(parent: Node3D, p: Vector3, size: Vector3, role: String, radius: float=.09) -> void:
 var edge=[]
 var r=minf(radius,minf(size.x,size.z)*.22)
 for corner in 4:
  var a=PI*.5*corner
  var center=Vector2((size.x*.5-r)*(1 if corner in [0,3] else -1),(size.z*.5-r)*(1 if corner in [0,1] else -1))
  for i in 5:
   var angle=a+i*PI/8
   edge.append(center+Vector2(cos(angle),sin(angle))*r)
 var rings=[]
 for item in [[-size.y*.5,.97],[-size.y*.5+.045,1.0],[size.y*.5-.045,1.0],[size.y*.5,.97]]:
  var ring=[]
  for point in edge:
   ring.append(p+Vector3(point.x*item[1],item[0],point.y*item[1]))
  rings.append(ring)
 var st=SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for j in 3:
  for i in edge.size():
   var k=(i+1)%edge.size()
   var u=float(i)/edge.size()*2
   var nu=float(i+1)/edge.size()*2
   _tri(st,rings[j][i],rings[j+1][i],rings[j][k],Vector2(u,0),Vector2(u,1),Vector2(nu,0))
   _tri(st,rings[j][k],rings[j+1][i],rings[j+1][k],Vector2(nu,0),Vector2(u,1),Vector2(nu,1))
 for i in edge.size():
  var k=(i+1)%edge.size()
  var a: Vector3=rings[3][i]
  var b: Vector3=rings[3][k]
  _tri(st,p+Vector3(0,size.y*.5,0),b,a,Vector2(.5,.5),Vector2(b.x,b.z)*.3,Vector2(a.x,a.z)*.3)
 _surface(parent,st,role)

func _tube(parent: Node3D, points: Array, radii: Array, role: String, sides: int=10) -> void:
 var st=SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var rings=[]
 for i in points.size():
  var direction: Vector3=(points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)]).normalized()
  var side=direction.cross(Vector3.FORWARD).normalized()
  if side.length()<.1:
   side=direction.cross(Vector3.UP).normalized()
  var other=direction.cross(side).normalized()
  var ring=[]
  for j in sides:
   var a=float(j)/sides*TAU
   ring.append(points[i]+(side*cos(a)+other*sin(a))*float(radii[i]))
  rings.append(ring)
 for i in points.size()-1:
  for j in sides:
   var k=(j+1)%sides
   var u=float(j)/sides
   var nu=float(j+1)/sides
   var v=float(i)/(points.size()-1)
   var nv=float(i+1)/(points.size()-1)
   _tri(st,rings[i][j],rings[i+1][j],rings[i][k],Vector2(u,v),Vector2(u,nv),Vector2(nu,v))
   _tri(st,rings[i][k],rings[i+1][j],rings[i+1][k],Vector2(nu,v),Vector2(u,nv),Vector2(nu,nv))
 _surface(parent,st,role)

func _build_house() -> void:
 house_model=Node3D.new()
 house_model.name="HandPaintedFarmhouse"
 house_model.position=Vector3(-3.5,.46,-3.7)
 house_model.set_meta("art_sample",true)
 add_child(house_model)
 var root=house_model
 _soft_box(root,Vector3(0,.12,0),Vector3(5.9,.24,3.8),"paint_stone",.18)
 _soft_box(root,Vector3(0,1.40,0),Vector3(4.95,2.55,2.90),"paint_wall",.14)
 _soft_box(root,Vector3(0,.24,1.78),Vector3(5.85,.18,.70),"paint_stone",.12)
 for i in 3:
  _soft_box(root,Vector3(0,.10-i*.065,2.16+i*.22),Vector3(2.0+i*.32,.13,.32),"paint_stone",.08)
 for x in [-2.42,2.42]:
  _tube(root,[Vector3(x,.25,1.55),Vector3(x*.99,1.1,1.57),Vector3(x,2.52,1.55)],[.13,.095,.14],"paint_wood")
  _tube(root,[Vector3(x,2.34,1.55),Vector3(x*.92,2.51,1.72),Vector3(x*.85,2.60,1.84)],[.085,.1,.055],"paint_wood")
 _tube(root,[Vector3(-2.64,2.58,1.62),Vector3(0,2.49,1.66),Vector3(2.64,2.58,1.62)],[.12,.14,.12],"paint_wood")
 _door(root)
 for x in [-1.65,1.65]:
  _window(root,Vector3(x,1.48,1.50))
 # Gable plaster fills the volume below the curved roof.
 var st=SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for x in [-2.47,2.47]:
  _tri(st,Vector3(x,2.60,-1.44),Vector3(x,3.95,0),Vector3(x,2.60,1.44),Vector2(0,1),Vector2(.5,0),Vector2(1,1))
 _surface(root,st,"paint_wall")
 _roof(root,Vector3(0,2.52,0),6.5,4.85,1.42)
 for x in [-2.05,2.05]:
  _lantern(root,Vector3(x,2.03,1.97))
 # Small porch accents give scale without enclosing the courtyard.
 for x in [-2.5,2.55]:
  _soft_box(root,Vector3(x,.39,1.98),Vector3(.48,.45,.42),"paint_wood",.09)
 _pavilion(Vector3(6.7,.47,-3.5))
 for i in 12:
  var x=2.75+i*.30
  var y=.55+sin(float(i)/11*PI)*.55
  _soft_box(self,Vector3(x,y,1.40),Vector3(.32,.15,1.0),"paint_stone",.06)
  if i%3==0:
   for side in [-1,1]:
    _tube(self,[Vector3(x,y,1.4+side*.51),Vector3(x,y+.62,1.4+side*.51)],[.075,.09],"paint_stone",8)
  if i<11:
   var ny=.55+sin(float(i+1)/11*PI)*.55
   for side in [-1,1]:
    _tube(self,[Vector3(x,y+.55,1.4+side*.51),Vector3(x+.3,ny+.55,1.4+side*.51)],[.055,.055],"paint_stone",8)

func _door(parent: Node3D) -> void:
 var shape=[Vector3(-.61,.28,1.53),Vector3(.61,.28,1.53)]
 for i in 17:
  var a=float(i)/16*PI
  shape.append(Vector3(cos(a)*.61,1.67+sin(a)*.49,1.53))
 var st=SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in shape.size():
  var a: Vector3=shape[i]
  var b: Vector3=shape[(i+1)%shape.size()]
  _tri(st,Vector3(0,1.1,1.53),a,b,Vector2(.5,.5),Vector2(a.x+.5,a.y*.5),Vector2(b.x+.5,b.y*.5))
 _surface(parent,st,"paint_wood")
 var frame=[Vector3(.66,.26,1.59),Vector3(.66,1.67,1.59)]
 for i in 17:
  var a=float(i)/16*PI
  frame.append(Vector3(cos(a)*.66,1.67+sin(a)*.54,1.59))
 frame.append(Vector3(-.66,.26,1.59))
 var widths=[]
 for p in frame:
  widths.append(.065)
 _tube(parent,frame,widths,"paint_wood",8)
 for x in [-.42,-.21,0,.21,.42]:
  _tube(parent,[Vector3(x,.34,1.555),Vector3(x,1.90,1.555)],[.013,.013],"paint_bark",6)
 for x in [-.13,.13]:
  ball(parent,Vector3(x,1.08,1.61),Vector3(.075,.09,.055),"dfc480",10)

func _window(parent: Node3D, p: Vector3) -> void:
 var disk=cylinder(parent,p,.53,.04,"e7c88e",-1,32)
 disk.rotation.x=PI*.5
 disk.material_override.emission_enabled=true
 var points=[]
 var widths=[]
 for i in 33:
  var a=float(i)/32*TAU
  points.append(p+Vector3(cos(a)*.57,sin(a)*.57,.04))
  widths.append(.055)
 _tube(parent,points,widths,"paint_wood",8)
 for x in [-.27,0,.27]:
  var h=sqrt(.49*.49-x*x)
  _tube(parent,[p+Vector3(x,-h,.055),p+Vector3(x,h,.055)],[.022,.022],"paint_wood",6)
 for y in [-.26,0,.26]:
  var w=sqrt(.49*.49-y*y)
  _tube(parent,[p+Vector3(-w,y,.055),p+Vector3(w,y,.055)],[.022,.022],"paint_wood",6)
 # Diamond-shaped small lattice inside the circular surround.
 var diamond=[]
 for v in [Vector2(0,.28),Vector2(.28,0),Vector2(0,-.28),Vector2(-.28,0),Vector2(0,.28)]:
  diamond.append(p+Vector3(v.x,v.y,.07))
 _tube(parent,diamond,[.024,.024,.024,.024,.024],"paint_wood",6)

func _roof(parent: Node3D, pos: Vector3, width: float, depth: float, rise: float) -> void:
 var st=SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for side in [-1,1]:
  for row in 10:
   for col in 24:
    var points=[]
    var uvs=[]
    for corner in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
     var u=(col+corner.x)/24.0
     var v=(row+corner.y)/10.0
     var x=(u-.5)*width*(.94+.06*v)
     var y=rise*pow(1-v,1.35)+pow(v,4)*.32+pow(absf(u-.5)*2,5)*pow(v,2)*.39
     y+=.024*cos(u*TAU*18)
     points.append(pos+Vector3(x,y,side*v*depth*.5))
     uvs.append(Vector2(u*2.6,v*1.4))
    for ids in ([[0,1,2],[1,3,2]] if side>0 else [[0,2,1],[1,2,3]]):
     _tri(st,points[ids[0]],points[ids[1]],points[ids[2]],uvs[ids[0]],uvs[ids[1]],uvs[ids[2]])
 _surface(parent,st,"paint_roof")
 for side in [-1,1]:
  var edge=[]
  var radii=[]
  for i in 25:
   var u=float(i)/24
   edge.append(pos+Vector3((u-.5)*width,.29+pow(absf(u-.5)*2,5)*.39,side*depth*.5))
   radii.append(.075)
  _tube(parent,edge,radii,"paint_wood",8)
 for side in [-1,1]:
  var edge=[]
  var radii=[]
  for i in 21:
   var t=float(i)/20*2-1
   var v=absf(t)
   edge.append(pos+Vector3(side*width*.5*(.94+.06*v),rise*pow(1-v,1.35)+pow(v,4)*.32+pow(v,2)*.39,t*depth*.5))
   radii.append(.085)
  _tube(parent,edge,radii,"paint_roof",8)
 var ridge=[]
 for i in 17:
  var t=float(i)/16*2-1
  ridge.append(pos+Vector3(t*width*.53,rise+.08+pow(absf(t),6)*.42,0))
 var radii=[]
 for p in ridge:
  radii.append(.095)
 _tube(parent,ridge,radii,"paint_roof",10)

func _tree(p: Vector3, scale_factor: float, parent: Node3D) -> void:
 var root=Node3D.new()
 root.name="PaintedWillow"
 parent.add_child(root)
 root.position=p
 root.scale=Vector3.ONE*scale_factor
 _tube(root,[Vector3(0,0,0),Vector3(-.16,.6,.02),Vector3(.12,1.4,.04),Vector3(.24,2.3,0),Vector3(.1,3.2,-.12)],[.32,.25,.20,.17,.10],"paint_bark",12)
 for i in 6:
  var a=i*TAU/6+.3
  var end=Vector3(cos(a)*1.15,3.0+sin(i*1.7)*.45,sin(a)*1.02)
  _tube(root,[Vector3(.1,1.6,0),Vector3(cos(a)*.5,2.4,sin(a)*.4),end],[.14,.10,.035],"paint_bark",9)
 for i in 5:
  var a=i*TAU/5
  _tube(root,[Vector3(cos(a)*.75,.025,sin(a)*.55),Vector3(cos(a)*.3,.15,sin(a)*.25),Vector3(0,.45,0)],[.07,.12,.2],"paint_bark",8)
 var shape=QuadMesh.new()
 shape.size=Vector2(1.75,1.85)
 var mm=MultiMesh.new()
 mm.transform_format=MultiMesh.TRANSFORM_3D
 mm.use_colors=true
 mm.mesh=shape
 mm.instance_count=20
 var rng=RandomNumberGenerator.new()
 rng.seed=1781
 for i in mm.instance_count:
  var a=i*2.39996
  var r=.4+sqrt(float(i)/mm.instance_count)*1.25
  var center=Vector3(cos(a)*r,2.65+rng.randf_range(-.3,.75),sin(a)*r*.77)
  var basis=Basis(Vector3.UP,a+PI*.5)*Basis(Vector3.RIGHT,rng.randf_range(-.28,.25))
  basis=basis.scaled(Vector3.ONE*rng.randf_range(.82,1.17))
  mm.set_instance_transform(i,Transform3D(basis,center))
  mm.set_instance_color(i,Color.WHITE* rng.randf_range(.83,1.05))
 var leaves=MultiMeshInstance3D.new()
 leaves.name="ClippedPaintedBoughs"
 leaves.multimesh=mm
 leaves.material_override=_paint("paint_leaves")
 leaves.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
 root.add_child(leaves)
 leaf_cards+=mm.instance_count

func _build_garden() -> void:
 for i in 12:
  var node=Node3D.new()
  node.position=plot_position(i)
  add_child(node)
  plots.append(node)
  var st=SurfaceTool.new()
  st.begin(Mesh.PRIMITIVE_TRIANGLES)
  var points=[]
  var uvs=[]
  for z in 17:
   for x in 21:
    var u=float(x)/20*2-1
    var v=float(z)/16*2-1
    var r=pow(pow(absf(u),4)+pow(absf(v),4),.25)
    var y=-.11+(1-smoothstep(.62,1.04,r))*.17
    y+=cos(v*PI*5+sin(u*4)*.3)*.016*(1-smoothstep(.65,1.0,r))
    points.append(Vector3(u*.91*(1+.025*sin(v*7+i)),y,v*.77*(1+.03*cos(u*6+i))))
    uvs.append(Vector2((u+1)*.5,(v+1)*.5))
  for z in 16:
   for x in 20:
    var a=z*21+x
    for ids in [[a,a+1,a+21],[a+1,a+22,a+21]]:
     _tri(st,points[ids[0]],points[ids[1]],points[ids[2]],uvs[ids[0]],uvs[ids[1]],uvs[ids[2]])
  _surface(node,st,"soil")
  var crops=Node3D.new()
  node.add_child(crops)
  crop_nodes.append(crops)

func _build_land() -> void:
 super._build_land()
 for node in find_children("*","MeshInstance3D",true,false):
  var mat=node.material_override
  if not mat is StandardMaterial3D:
   continue
  var hex=mat.albedo_color.to_html(false)
  var role=""
  if hex in ["c7c9b0","b8bfac","d2ceb5","c4c6ad"]:
   role="paint_path"
  elif hex in ["99aaa0","afbaa6","8b9f97","96aaa3"]:
   role="paint_stone"
  if role!="":
   var replacement=StandardMaterial3D.new()
   replacement.albedo_color=Color.WHITE
   replacement.set_meta("role",role)
   node.material_override=replacement

func _leaf(parent: Node3D, p: Vector3, angle: float, length: float, width: float, curl: float) -> void:
 var st=SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var points=[]
 var uvs=[]
 var direction=Vector3(cos(angle),0,sin(angle))
 var sideways=Vector3(-sin(angle),0,cos(angle))
 for y in 7:
  var t=float(y)/6
  for x in 7:
   var s=float(x)/6*2-1
   var span=pow(maxf(.001,sin(t*PI)),.65)*width
   var point=p+direction*length*t+sideways*span*s
   point.y+=sin(t*PI*.8)*curl+.05*pow(absf(s),2)*sin(t*PI)+.016*cos(t*PI*5)*absf(s)
   points.append(point)
   uvs.append(Vector2((s+1)*.5,t))
 for y in 6:
  for x in 6:
   var a=y*7+x
   for ids in [[a,a+1,a+7],[a+1,a+8,a+7]]:
    _tri(st,points[ids[0]],points[ids[1]],points[ids[2]],uvs[ids[0]],uvs[ids[1]],uvs[ids[2]])
 _surface(parent,st,"paint_crop")

func _build_crop(parent: Node3D, kind: String, stage: int) -> void:
 if kind not in ["cabbage","carrot"] or stage==0:
  super._build_crop(parent,kind,stage)
  return
 var growth=[.1,.28,.48,.76,1.0][stage]
 for x in [-.47,0,.47]:
  for z in [-.3,.3]:
   var p=Vector3(x,.08,z)
   if kind=="cabbage":
    for i in 12:
     var a=i*2.39996
     var layer=float(i)/12
     var length=growth*(.33-layer*.12)
     _leaf(parent,p+Vector3(0,layer*growth*.19,0),a,length,growth*.19,growth*(.14+layer*.18))
   else:
    for i in 5:
     var a=i*TAU/5
     var height=growth*(.42+.07*sin(i))
     var end=p+Vector3(cos(a)*growth*.18,height,sin(a)*growth*.18)
     rod(parent,p,end,.012,"6b9869")
     for j in 3:
      var t=.3+j*.20
      var at=p.lerp(end,t)
      _leaf(parent,at,a-1.1,growth*.18,growth*.035,.045)
      _leaf(parent,at,a+1.1,growth*.18,growth*.035,.045)

