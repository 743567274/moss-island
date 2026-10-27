class_name MapProjectStore
extends RefCounted

const ROOT="user://maps/projects"
const POINTER="user://maps/active-project.json"
const EXAMPLE="lakeside-example"
static var active_id=EXAMPLE

static func safe_id(id: String) -> bool:
 return not id.is_empty() and id.length()<100 and id.is_valid_filename() and not id.contains(".") and not id.contains("/") and not id.contains("\\")

static func directory(id: String) -> String:
 return ROOT.path_join(id) if safe_id(id) else ""

static func document(id: String) -> Dictionary:
 if not safe_id(id):
  return {}
 var path=directory(id).path_join("project.json")
 if not FileAccess.file_exists(path):
  return {}
 var parsed=JSON.parse_string(FileAccess.get_file_as_string(path))
 return parsed if parsed is Dictionary and str(parsed.get("id",""))==id and parsed.get("layout") is Dictionary else {}

static func save_json(path: String,value: Variant) -> Error:
 return MapLayoutStore.write_json(path,value)

static func initialize(seed: Dictionary) -> Error:
 if document(EXAMPLE).is_empty() and not FileAccess.file_exists("user://maps/project-migration.json"):
  var migrated=MapLayoutStore.read_layout(MapLayoutStore.APPLIED)
  var initial=migrated if not migrated.is_empty() else seed.duplicate(true)
  initial.version=2
  initial.project_id=EXAMPLE
  initial.scene_mode="reference"
  for i in initial.plots.size():
   initial.plots[i].basis_a=seed.plots[i].basis_a.duplicate()
   initial.plots[i].basis_b=seed.plots[i].basis_b.duplicate()
  var now=Time.get_unix_time_from_system()
  var result=save_json(directory(EXAMPLE).path_join("project.json"),{"id":EXAMPLE,"name":"湖畔庭院 · 原有布景","created_at":now,"updated_at":now,"legacy_farm":true,"layout":initial})
  if result!=OK:
   return result
  save_json("user://maps/project-migration.json",{"completed":true})
  var old_draft=MapLayoutStore.read_layout(MapLayoutStore.DRAFT)
  if not old_draft.is_empty():
   old_draft.version=2
   old_draft.project_id=EXAMPLE
   old_draft.scene_mode="reference"
   for i in old_draft.plots.size():
    old_draft.plots[i].basis_a=seed.plots[i].basis_a.duplicate()
    old_draft.plots[i].basis_b=seed.plots[i].basis_b.duplicate()
   save_json(draft_path(EXAMPLE),old_draft)
 if FileAccess.file_exists(POINTER):
  var pointer=JSON.parse_string(FileAccess.get_file_as_string(POINTER))
  if pointer is Dictionary and not document(str(pointer.get("id",""))).is_empty():
   active_id=str(pointer.id)
   return OK
 var projects=list_projects()
 if projects.is_empty():
  var created=create_project("未命名场景")
  if created.has("error"):
   return ERR_CANT_CREATE
  active_id=created.id
 else:
  active_id=EXAMPLE if not document(EXAMPLE).is_empty() else str(projects[0].id)
 return save_json(POINTER,{"id":active_id})

static func list_projects() -> Array:
 var result=[]
 var dir=DirAccess.open(ROOT)
 if dir==null:
  return result
 for id in dir.get_directories():
  var project=document(id)
  if not project.is_empty():
   result.append(project)
 result.sort_custom(func(a,b): return float(a.get("updated_at",0))>float(b.get("updated_at",0)))
 return result

static func draft_path(id: String) -> String:
 return directory(id).path_join("draft.json")

static func farm_path(id: String) -> String:
 return "user://farm.json" if document(id).get("legacy_farm",false) else directory(id).path_join("farm.json")

static func edit_layout(id: String) -> Dictionary:
 var draft=MapLayoutStore.read_layout(draft_path(id))
 return draft if not draft.is_empty() else document(id).get("layout",{}).duplicate(true)

static func create_project(name: String,source: Dictionary={}) -> Dictionary:
 var id="project-%d-%d" % [int(Time.get_unix_time_from_system()),randi()]
 var layout={"version":2,"project_id":id,"map_id":"lakeside","scene_mode":"blank","background_color":"dfe5dc","plots":[],"objects":[],"willow":{},"lights":[]}
 if not source.is_empty():
  layout=source.duplicate(true)
  layout.project_id=id
  layout.version=2
  for i in layout.plots.size():
   layout.plots[i].id="plot-%d-%d" % [i,randi()]
 var now=Time.get_unix_time_from_system()
 var project={"id":id,"name":name.strip_edges().left(60),"created_at":now,"updated_at":now,"legacy_farm":false,"layout":layout}
 var error=save_json(directory(id).path_join("project.json"),project)
 return project if error==OK else {"error":error_string(error)}

static func save_project(id: String,layout: Dictionary) -> Error:
 if not MapLayoutStore.valid(layout) or str(layout.get("project_id",""))!=id:
  return ERR_INVALID_DATA
 var project=document(id)
 if project.is_empty():
  return ERR_DOES_NOT_EXIST
 project.layout=layout.duplicate(true)
 project.updated_at=Time.get_unix_time_from_system()
 return save_json(directory(id).path_join("project.json"),project)

static func activate(id: String) -> Error:
 var project=document(id)
 if project.is_empty() or not MapLayoutStore.valid(project.layout):
  return ERR_INVALID_DATA
 var previous=MapLayoutStore.read_layout(MapLayoutStore.APPLIED)
 var result=save_json(MapLayoutStore.APPLIED,project.layout)
 if result!=OK:
  return result
 result=save_json(POINTER,{"id":id})
 if result!=OK and not previous.is_empty():
  save_json(MapLayoutStore.APPLIED,previous)
 if result==OK:
  active_id=id
  MapLayoutStore.layout=project.layout.duplicate(true)
 return result

static func active_layout() -> Dictionary:
 var snapshot=MapLayoutStore.read_layout(MapLayoutStore.APPLIED)
 return snapshot if str(snapshot.get("project_id",""))==active_id else document(active_id).get("layout",{}).duplicate(true)

static func rename_project(id: String,name: String) -> Error:
 var project=document(id)
 if project.is_empty() or name.strip_edges().is_empty():
  return ERR_INVALID_DATA
 project.name=name.strip_edges().left(60)
 project.updated_at=Time.get_unix_time_from_system()
 return save_json(directory(id).path_join("project.json"),project)

static func remove_project(id: String) -> Error:
 if id==active_id or not safe_id(id) or document(id).is_empty():
  return ERR_UNAVAILABLE
 # Move only the validated single project directory into the user's map trash.
 # Shared material files are outside this directory and never get removed.
 var trash="user://maps/deleted-projects"
 var error=DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(trash))
 if error!=OK:
  return error
 return DirAccess.rename_absolute(ProjectSettings.globalize_path(directory(id)),ProjectSettings.globalize_path(trash.path_join(id+"-"+str(Time.get_ticks_usec()))))
