class_name MapProjectWindow
extends Window

signal edit_requested(id: String)
signal apply_requested(id: String,layout: Dictionary)
var projects=[]
var list: ItemList
var status: Label
var naming: ConfirmationDialog
var name_input: LineEdit
var deletion: ConfirmationDialog
var operation="new"
var pending_id=""
var icons=[]

func _init() -> void:
 title="苔屿 · 场景项目"
 size=Vector2i(940,680)
 min_size=Vector2i(760,560)

func initialize(ui_theme: Theme) -> void:
 theme=MapEditorTheme.create(ui_theme)
 var panel=PanelContainer.new()
 var style=StyleBoxFlat.new()
 style.bg_color=Color("eee8d8")
 for side in ["left","right","top","bottom"]:
  style.set("content_margin_"+side,22)
 panel.add_theme_stylebox_override("panel",style)
 add_child(panel)
 panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var column=VBoxContainer.new()
 column.add_theme_constant_override("separation",14)
 panel.add_child(column)
 var title=Label.new()
 title.text="我的场景项目"
 title.add_theme_font_size_override("font_size",25)
 column.add_child(title)
 var note=Label.new()
 note.text="新项目从空白开始。每个项目独立保存场景、种植和库存，素材库共用。"
 note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 column.add_child(note)
 var bar=HBoxContainer.new()
 column.add_child(bar)
 _button(bar,"＋ 新建空白项目",func(): ask_name("new"))
 _button(bar,"编辑",edit_selected)
 _button(bar,"应用到桌面",apply_selected)
 _button(bar,"复制",func(): ask_name("copy"))
 _button(bar,"重命名",func(): ask_name("rename"))
 _button(bar,"删除",ask_delete)
 list=ItemList.new()
 list.size_flags_vertical=Control.SIZE_EXPAND_FILL
 list.fixed_icon_size=Vector2i(144,81)
 list.add_theme_constant_override("v_separation",12)
 column.add_child(list)
 list.item_activated.connect(func(_index): edit_selected())
 status=Label.new()
 status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 column.add_child(status)
 naming=ConfirmationDialog.new()
 naming.theme=theme
 naming.title="项目名称"
 naming.size=Vector2i(450,140)
 name_input=LineEdit.new()
 name_input.max_length=60
 naming.add_child(name_input)
 naming.confirmed.connect(commit_name)
 add_child(naming)
 deletion=ConfirmationDialog.new()
 deletion.theme=theme
 deletion.title="删除项目"
 deletion.ok_button_text="删除此项目"
 deletion.confirmed.connect(func():
  var error=MapProjectStore.remove_project(pending_id)
  refresh()
  status.text="项目已移至已删除项目目录，素材库保留。" if error==OK else "删除失败："+error_string(error))
 add_child(deletion)
 close_requested.connect(hide)
 refresh()

func _button(parent: Node,text: String,callback: Callable) -> void:
 var button=Button.new()
 button.text=text
 button.pressed.connect(callback)
 parent.add_child(button)

func refresh() -> void:
 var previous=selected_id()
 projects=MapProjectStore.list_projects()
 list.clear()
 icons.clear()
 for i in projects.size():
  var project=projects[i]
  var thumbnail=MapProjectStore.directory(project.id).path_join("preview.png")
  var icon: Texture2D
  if FileAccess.file_exists(thumbnail):
   icon=ContentCatalog.prepared_texture(thumbnail,288)
  if icon==null and project.layout.get("scene_mode","reference")=="reference":
   icon=ContentCatalog.prepared_texture(MapDefinition.load_map().background,288)
  if icon==null:
   var image=Image.create(144,81,false,Image.FORMAT_RGBA8)
   image.fill(Color(str(project.layout.get("background_color","dfe5dc"))))
   icon=ImageTexture.create_from_image(image)
  icons.append(icon)
  var updated=Time.get_datetime_string_from_unix_time(int(project.updated_at)+8*3600).replace("T"," ")
  list.add_item(project.name+("  · 正在桌面使用" if project.id==MapProjectStore.active_id else "")+"\n%d块田 · %d件素材 · 修改于 %s" % [project.layout.plots.size(),project.layout.objects.size(),updated],icon)
  if project.id==previous:
   list.select(i)
 if list.get_selected_items().is_empty() and not projects.is_empty():
  list.select(0)
 status.text="双击项目进入编辑；保存项目后可应用到桌面。复制项目不会复制作物和库存。"

func selected_id() -> String:
 if list==null:
  return ""
 var selected=list.get_selected_items()
 return str(projects[selected[0]].id) if not selected.is_empty() and selected[0]<projects.size() else ""

func edit_selected() -> void:
 var id=selected_id()
 if not id.is_empty():
  hide()
  edit_requested.emit(id)

func apply_selected() -> void:
 var id=selected_id()
 if not id.is_empty():
  apply_requested.emit(id,MapProjectStore.document(id).layout.duplicate(true))

func ask_name(mode: String) -> void:
 operation=mode
 pending_id=selected_id()
 if mode!="new" and pending_id.is_empty():
  return
 naming.title={"new":"新建空白项目","copy":"复制已保存项目","rename":"重命名项目"}[mode]
 name_input.text="未命名场景" if mode=="new" else str(MapProjectStore.document(pending_id).name)+(" 副本" if mode=="copy" else "")
 naming.popup_centered()
 name_input.grab_focus()
 name_input.select_all()

func commit_name() -> void:
 var name=name_input.text.strip_edges()
 if name.is_empty():
  status.text="项目名称不能为空。"
  return
 if operation=="rename":
  var error=MapProjectStore.rename_project(pending_id,name)
  refresh()
  if error!=OK:
   status.text="重命名失败："+error_string(error)
  return
 var project=MapProjectStore.create_project(name,MapProjectStore.document(pending_id).layout if operation=="copy" else {})
 if project.has("error"):
  status.text="创建失败："+str(project.error)
  return
 refresh()
 hide()
 edit_requested.emit(project.id)

func ask_delete() -> void:
 pending_id=selected_id()
 if pending_id.is_empty():
  return
 if pending_id==MapProjectStore.active_id:
  status.text="请先应用另一个项目，再删除当前正在桌面使用的项目。"
  return
 deletion.dialog_text="删除“%s”及其独立种植存档？\n共享素材库不会删除。项目会移至数据目录的 deleted-projects，可手动恢复。" % MapProjectStore.document(pending_id).name
 deletion.popup_centered()
