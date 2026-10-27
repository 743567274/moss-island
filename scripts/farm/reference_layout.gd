class_name ReferenceLayout
extends RefCounted

static var BEDS: Array[Vector4]=[]
static var TREES: Array[Vector2]=[]
static func _static_init() -> void:
 MapDefinition.load_map()
 for i in 12:
  var p=uv(MapDefinition.center("crops",i))
  var grid=MapDefinition.grid("crops")
  BEDS.append(Vector4(p.x,p.y,absf(grid.basis_a[0])/MapDefinition.world_size.x,absf(grid.basis_a[1])/MapDefinition.world_size.y))
 for i in 6:
  TREES.append(uv(MapDefinition.center("orchard",i)))
static func world(p: Vector2, height: float=.59) -> Vector3:
 return Vector3((p.x-.5)*MapDefinition.world_size.x,height,(p.y-.5)*MapDefinition.world_size.y)
static func uv(point: Vector3) -> Vector2:
 return Vector2(point.x/MapDefinition.world_size.x+.5,point.z/MapDefinition.world_size.y+.5)
