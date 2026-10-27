class_name CropEditorWindow
extends Window

signal catalog_changed
var list_page: VBoxContainer
var edit_page: VBoxContainer
var list: ItemList
var ids=[]
var icons=[]
var draft={}
var states=[]
var logo={}
var editing_id=""
var name_input: LineEdit
var id_input: LineEdit
var type_input: OptionButton
var general: VBoxContainer
var grid: GridContainer
var advanced: TextEdit
var status: Label
var picker: FileDialog
var import_slot=0
var deletion: ConfirmationDialog
var discard: ConfirmationDialog
var dirty=false
var footer: Label

func _init() -> void:
 title="苔屿 · 作物编辑器"
 size=Vector2i(1180,860)
 min_size=Vector2i(950,650)

func initialize(base: Theme) -> void:
 theme=MapEditorTheme.create(base)
 var panel=PanelContainer.new()
 add_child(panel)
 panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var column=VBoxContainer.new()
 panel.add_child(column)
 list_page=VBoxContainer.new()
 list_page.size_flags_vertical=Control.SIZE_EXPAND_FILL
 column.add_child(list_page)
 var bar=HBoxContainer.new()
 list_page.add_child(bar)
 _button(bar,"＋ 新增作物",func(): open_editor("",false))
 _button(bar,"＋ 新增果树",func(): open_editor("",true))
 _button(bar,"编辑",func():
  if list.get_selected_items().size()>0: open_editor(str(ids[list.get_selected_items()[0]])))
 _button(bar,"删除",func():
  if list.get_selected_items().size()>0: deletion.popup_centered())
 list=ItemList.new()
 list.fixed_icon_size=Vector2i(72,72)
 list.size_flags_vertical=Control.SIZE_EXPAND_FILL
 list_page.add_child(list)
 list.item_activated.connect(func(index): open_editor(str(ids[index])))
 edit_page=VBoxContainer.new()
 edit_page.size_flags_vertical=Control.SIZE_EXPAND_FILL
 column.add_child(edit_page)
 var actions=HBoxContainer.new()
 edit_page.add_child(actions)
 _button(actions,"← 返回作物列表",back)
 _button(actions,"保存并应用",save_crop)
 _button(actions,"导入6×2图集",func(): choose(-3))
 _button(actions,"上传Logo",func(): choose(-2))
 var header=HBoxContainer.new()
 edit_page.add_child(header)
 _label(header,"名称")
 name_input=LineEdit.new()
 name_input.custom_minimum_size.x=190
 header.add_child(name_input)
 name_input.text_changed.connect(func(_value): dirty=true)
 _label(header,"编号")
 id_input=LineEdit.new()
 id_input.custom_minimum_size.x=200
 header.add_child(id_input)
 type_input=OptionButton.new()
 type_input.add_item("作物 · 单次采收")
 type_input.add_item("果树 · 循环结果")
 header.add_child(type_input)
 type_input.item_selected.connect(func(index):
  var name=name_input.text
  var id=id_input.text
  draft=CropEditorStore.template(index==1)
  draft.id=id
  draft.name=name
  states=CropEditorStore.slots(draft)
  dirty=true
  advanced.text=_parameters()
  rebuild_general()
  rebuild_cards())
 var hint=_label(edit_page,"所有状态保存为同尺寸512×512透明画布，统一基准、底部对齐；独立缩放不改变文件尺寸。\n作物缺水/死亡图为状态分支，其停留时间由正常阶段的缺水死亡阈值决定；果树按12阶段循环。")
 hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 var tabs=TabContainer.new()
 tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL
 edit_page.add_child(tabs)
 var scroll=ScrollContainer.new()
 scroll.name="12个状态 · 图片与时间"
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 tabs.add_child(scroll)
 grid=GridContainer.new()
 grid.columns=3
 grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 scroll.add_child(grid)
 var general_scroll=ScrollContainer.new()
 general_scroll.name="生长温度 · 浇水与收获"
 general_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 tabs.add_child(general_scroll)
 general=VBoxContainer.new()
 general.custom_minimum_size.x=700
 general_scroll.add_child(general)
 advanced=TextEdit.new()
 advanced.name="全部参数 · 温度水分收获"
 advanced.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY
 advanced.size_flags_vertical=Control.SIZE_EXPAND_FILL
 tabs.add_child(advanced)
 advanced.text_changed.connect(func(): dirty=true)
 footer=_label(edit_page,"时间按真实日计算；温度单位℃，耗水单位mm/日。果树施肥、授粉、疏果为阶段说明，当前没有对应操作系统。")
 footer.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 status=_label(column,"")
 status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 picker=FileDialog.new()
 picker.file_mode=FileDialog.FILE_MODE_OPEN_FILE
 picker.access=FileDialog.ACCESS_FILESYSTEM
 picker.filters=PackedStringArray(["*.png,*.webp,*.jpg,*.jpeg ; 图片"])
 picker.use_native_dialog=true
 add_child(picker)
 picker.file_selected.connect(import_image)
 deletion=ConfirmationDialog.new()
 deletion.dialog_text="删除所选植物？仍被种植或库存引用的植物会阻止删除；原始作物包和已保存版本保留。"
 add_child(deletion)
 deletion.confirmed.connect(func():
  if list.get_selected_items().is_empty(): return
  var error=CropEditorStore.remove(str(ids[list.get_selected_items()[0]]))
  if error.is_empty(): catalog_changed.emit(); refresh_list()
  status.text="已删除（原文件保留）。" if error.is_empty() else error)
 discard=ConfirmationDialog.new()
 discard.dialog_text="放弃尚未保存的作物修改？"
 add_child(discard)
 discard.confirmed.connect(func(): dirty=false; refresh_list())
 close_requested.connect(func():
  if dirty: discard.popup_centered()
  else: hide())
 refresh_list()

func _button(parent: Node,text: String,callback: Callable) -> Button:
 var button=Button.new()
 button.text=text
 parent.add_child(button)
 button.pressed.connect(callback)
 return button

func _label(parent: Node,text: String) -> Label:
 var label=Label.new()
 label.text=text
 parent.add_child(label)
 return label

func refresh_list() -> void:
 list_page.show()
 edit_page.hide()
 ids.clear()
 icons.clear()
 list.clear()
 for id in ContentCatalog.crops:
  ids.append(id)
  var value=ContentCatalog.crops[id]
  var icon=ContentCatalog.icon(id)
  icons.append(icon)
  list.add_item(str(value.name)+" · "+("果树" if value.get("type","crop")=="fruit_tree" else "作物")+" · "+str(id),icon)
 status.text="双击编辑；可新增作物和果树，保存后更新播种列表。"

func open_editor(id: String,tree: bool=false) -> void:
 editing_id=id
 draft=ContentCatalog.crops[id].duplicate(true) if not id.is_empty() else CropEditorStore.template(tree)
 states=CropEditorStore.slots(draft)
 logo={}
 if not id.is_empty():
  logo=draft.assets[draft.icon].duplicate(true)
  logo.path=ContentCatalog.package_dirs[id].path_join(logo.file)
 name_input.text=str(draft.name)
 id_input.text=str(draft.id)
 id_input.editable=id.is_empty()
 type_input.select(1 if draft.get("type","crop")=="fruit_tree" else 0)
 type_input.disabled=not id.is_empty()
 advanced.text=_parameters()
 rebuild_general()
 list_page.hide()
 edit_page.show()
 rebuild_cards()
 dirty=false
 status.text="上传12个状态图片，或导入平均分布的6×2图集。已有编号和类型固定，避免破坏存档。"

func _parameters() -> String:
 var result={}
 for key in ["description","temperature","watering","harvest","render","sowing","simulation_notes","dormancy_max_c","dormancy_min_c"]:
  if draft.has(key): result[key]=draft[key]
 return JSON.stringify(result,"\t")

func rebuild_cards() -> void:
 for child in grid.get_children(): child.free()
 var tree=draft.get("type","crop")=="fruit_tree"
 for i in 12:
  var state=states[i]
  var panel=PanelContainer.new()
  panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  grid.add_child(panel)
  var box=VBoxContainer.new()
  box.custom_minimum_size.x=270
  panel.add_child(box)
  _label(box,"%02d · %s [%s]" % [i+1,state.name,state.id])
  var preview=CropStatePreview.new()
  preview.custom_minimum_size=Vector2(180,125)
  preview.multiplier=float(state.asset.get("scale",1))
  preview.image=ContentCatalog.prepared_texture(state.asset.path,256,state.asset.get("region",[])) if not str(state.asset.get("path","")).is_empty() else null
  box.add_child(preview)
  _button(box,"选择状态图片",func(): choose(i))
  _spin(box,"独立缩放",.05,10,.05,float(state.asset.get("scale",1)),func(value): state.asset.scale=value; preview.multiplier=value; preview.queue_redraw(); dirty=true)
  if tree or i in [0,3,6]:
   _spin(box,"阶段时长（真实日）",.001,3650,.1,float(state.settings.days),func(value): state.settings.days=value; dirty=true)
  if tree or i in [0,3,6,9]:
   for field in [["water","耗水 mm/日",0,30],["death_days","完全干土死亡天数",0,365],["min_c","最低适温℃",-50,60],["max_c","最高适温℃",-50,60]]:
    _spin(box,field[1],field[2],field[3],.1,float(state.settings[field[0]]),func(value): state.settings[field[0]]=value; dirty=true)
  else: _label(box,"缺水、死亡及采收形态不自动进入成长阶段。")

func _spin(parent: Node,title: String,minimum: float,maximum: float,step: float,value: float,callback: Callable) -> void:
 var row=HBoxContainer.new()
 parent.add_child(row)
 var label=_label(row,title)
 label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var spin=SpinBox.new()
 spin.min_value=minimum
 spin.max_value=maximum
 spin.step=step
 spin.value=value
 row.add_child(spin)
 spin.value_changed.connect(callback)

func choose(slot: int) -> void:
 import_slot=slot
 picker.popup_centered_ratio(.7)

func import_image(path: String) -> void:
 var image=Image.load_from_file(path)
 if image==null: status.text="图片无法读取。"; return
 if import_slot==-3:
  for i in 12:
   states[i].asset={"path":path,"region":[float(i%6)/6,float(i/6)/2,1.0/6,.5],"scale":float(states[i].asset.get("scale",1))}
 elif import_slot==-2: logo={"path":path}
 else: states[import_slot].asset={"path":path,"scale":float(states[import_slot].asset.get("scale",1))}
 dirty=true
 rebuild_cards()
 status.text="图片已选取，保存时统一画布。" if import_slot!=-2 else "Logo已选取。"

func save_crop() -> void:
 var parameters=JSON.parse_string(advanced.text)
 if not parameters is Dictionary: status.text="参数JSON格式无效。"; return
 var candidate=draft.duplicate(true)
 for key in parameters: candidate[key]=parameters[key]
 candidate.id=id_input.text.strip_edges()
 candidate.name=name_input.text.strip_edges()
 candidate.type="fruit_tree" if type_input.selected==1 else "crop"
 if editing_id.is_empty() and ContentCatalog.crops.has(candidate.id): status.text="编号已存在，请更换。"; return
 var error=CropEditorStore.save(candidate,states,logo)
 if not error.is_empty(): status.text=error; return
 dirty=false
 catalog_changed.emit()
 refresh_list()
 status.text="已保存并应用，作物包支持现有仓库导出功能。"

func back() -> void:
 if dirty: discard.popup_centered()
 else: refresh_list()

func rebuild_general() -> void:
 for child in general.get_children(): child.free()
 var parameters=JSON.parse_string(advanced.text)
 if not parameters is Dictionary: return
 _label(general,"阶段适温优先于全局适温。阶段用水与缺水死亡天数在状态页设置。")
 var specs=[
  ["temperature","min_c","全局最低适温℃",-50,60,.1,1],
  ["temperature","max_c","全局最高适温℃",-50,60,.1,1],
  ["temperature","sowing_min_c","播种最低温℃",-50,60,.1,1],
  ["temperature","sowing_max_c","播种最高温℃",-50,60,.1,1],
  ["temperature","stress_death_seconds","不适温死亡时间（真实日）",.01,365,.1,86400],
  ["temperature","unsuitable_growth_factor","不适温成长系数（0暂停）",0,1,.05,1],
  ["watering","capacity_mm","土壤储水容量mm",1,1000,1,1],
  ["watering","initial_mm","播种初始水量mm",0,1000,1,1],
  ["watering","per_action_mm","每次浇水量mm",1,1000,1,1],
  ["watering","warning_mm","缺水预警水量mm",.1,1000,.1,1],
  ["watering","growth_min_mm","成长最低水量mm",0,1000,.1,1],
  ["watering","rain_absorption","雨水吸收系数",0,1,.05,1],
  ["harvest","yield","每次收获数量",1,100000,1,1],
  ["harvest","mature_lifetime_seconds","成熟未采收枯萎时间（日，0关闭）",0,3650,.1,86400],
  ["harvest","residue_delay_seconds","采后枯萎等待时间（日）",0,3650,.1,86400],
  ["render","sway","随风摇曳幅度",0,.1,.001,1],
  ["render","seed_sway","种子摇曳幅度",0,.1,.001,1]]
 for spec in specs:
  var value=float(parameters.get(spec[0],{}).get(spec[1],0))/float(spec[6])
  _spin(general,spec[2],spec[3],spec[4],spec[5],value,func(number):
   var current=JSON.parse_string(advanced.text)
   if not current is Dictionary: return
   if not current.has(spec[0]): current[spec[0]]={}
   current[spec[0]][spec[1]]=number*float(spec[6])
   advanced.text=JSON.stringify(current,"\t")
   dirty=true)
 _label(general,"果树按状态页的成熟阶段时长进入落叶周期；施肥、授粉、品质与疏果暂不参与计算。")
