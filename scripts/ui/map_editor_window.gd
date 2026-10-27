class_name MapEditorWindow
extends Window

signal application_requested(project_id: String,layout: Dictionary)
var project_id=""
var canvas: MapEditorCanvas
var draft: Dictionary={}
var selection=""
var selection_keys: Array=[]
var fixture_source: OptionButton
var fixture_source_index=0
var fixture_target_key=""
var fixture_instance_button: Button
var material_fixture_options: VBoxContainer
var fixture_canvas: MapFixtureCanvas
var fixture_kind: OptionButton
var fixture_x: SpinBox
var fixture_y: SpinBox
var fixture_angle: SpinBox
var fixture_aperture: SpinBox
var fixture_range: SpinBox
var fixture_energy: SpinBox
var fixture_color: ColorPickerButton
var fixture_checks={}
var fixture_night_label: Label
var material_error: Label
var keys=[]
var layer_sync_queued=false
var pending_layer_index=-1
var pending_layer_edit=""
var object_list: MapLayerList
var layer_tabs: TabContainer
var material_list: ItemList
var materials=[]
var x_control: SpinBox
var y_control: SpinBox
var scale_control: SpinBox
var layer_area: VBoxContainer
var operation_area: ScrollContainer
var show_layer_list=false
var soil_controls: VBoxContainer
var soil_shape: OptionButton
var soil_highlight: SpinBox
var inline_fixture: MapFixtureInspector
var texture_target=""
var category: OptionButton
var animation: CheckBox
var inspector: VBoxContainer
var name_label: Label
var status: Label
var remove_button: Button
var file_dialog: FileDialog
var discard_dialog: ConfirmationDialog
var reset_dialog: ConfirmationDialog
var undo_button: Button
var redo_button: Button
var past=[]
var future=[]
var syncing=false
var dirty=false
var material_icons=[]
var material_dialog: AcceptDialog
var material_type: OptionButton
var material_shape: OptionButton
var material_highlight: SpinBox
var material_height: SpinBox
var material_background_note: Label
var background_note: Label
var material_motion: CheckBox
var material_selected_label: Label
var material_land_options: VBoxContainer
var material_normal_preview: TextureRect
var material_selected_preview: TextureRect
var editing_material: Dictionary={}
var import_role="normal"
var material_menu: PopupMenu
var material_menu_id=""
var restore_soil_button: Button
var material_root_x: SpinBox
var material_root_y: SpinBox
var light_controls: VBoxContainer
var light_binding_label: Label
var light_kind: OptionButton
var light_angle: SpinBox
var light_aperture: SpinBox
var light_range: SpinBox
var light_energy: SpinBox
var light_color: ColorPickerButton
var light_night: CheckBox
var light_enabled: CheckBox
var light_flicker: CheckBox
var background_control: ColorPickerButton
var material_water_options: VBoxContainer
var instance_water_button: Button
var opacity_control: SpinBox
var shadow_control: SpinBox
var shadow_distance_control: SpinBox
var shadow_angle_control: SpinBox
var shadow_size_control: SpinBox
var fog_opacity: SpinBox
var fog_speed: SpinBox
var material_category: OptionButton
var land_previews: HBoxContainer
var normal_land_preview: TextureRect
var selected_land_preview: TextureRect
var land_preview_note: Label
var place_material_button: Button
var material_defaults_button: Button
var delete_materials_button: Button
var rotation_control: SpinBox
var rotation_actions: HBoxContainer
var add_light_button: Button
var water_preview: TextureRect
var water_visibility: CheckBox

func _init() -> void:
 title="苔屿 · 地图编辑器（素材类型版）"
 size=Vector2i(1380,850)
 min_size=Vector2i(1050,680)

func initialize(ui_theme: Theme,farm: FarmState=null,id: String="") -> void:
 theme=MapEditorTheme.create(ui_theme)
 project_id=id if not id.is_empty() else MapProjectStore.active_id
 draft=MapProjectStore.edit_layout(project_id)
 title="苔屿 · 编辑项目 · "+str(MapProjectStore.document(project_id).get("name","场景"))
 var panel=PanelContainer.new()
 var style=StyleBoxFlat.new()
 style.bg_color=Color("eee8d8")
 for edge in ["left","right","top","bottom"]:
  style.set("content_margin_"+edge,12)
 panel.add_theme_stylebox_override("panel",style)
 add_child(panel)
 panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var column=VBoxContainer.new()
 panel.add_child(column)
 var bar=HBoxContainer.new()
 column.add_child(bar)
 _button(bar,"保存项目",save_draft)
 _button(bar,"应用到桌面",apply_layout)
 undo_button=_button(bar,"撤销",undo)
 redo_button=_button(bar,"重做",redo)
 _button(bar,"返回项目列表",func(): close_requested.emit())
 _button(bar,"恢复已保存布局",func(): reset_dialog.popup_centered())
 _button(bar,"打开素材目录",func(): OS.shell_open(ProjectSettings.globalize_path(MapLayoutStore.DIRECTORY)))
 _button(bar,"水域标记",_edit_map_water)
 var night=CheckBox.new()
 night.text="夜景预览"
 bar.add_child(night)
 night.toggled.connect(func(value): canvas.night=value; canvas.queue_redraw())
 var lights=CheckBox.new()
 lights.text="灯光锚点"
 lights.button_pressed=true
 bar.add_child(lights)
 lights.toggled.connect(func(value): canvas.show_lights=value; canvas.queue_redraw())
 var note=Label.new()
 note.text="空白处拖动框选；Shift / Ctrl 点选增减；Alt 拖动复制；方向键微调，Shift 加速。锁定图层跳过。"
 note.add_theme_font_size_override("font_size",13)
 column.add_child(note)
 var body=HSplitContainer.new()
 body.size_flags_vertical=Control.SIZE_EXPAND_FILL
 body.split_offset=215
 column.add_child(body)
 var left=VBoxContainer.new()
 left.custom_minimum_size.x=195
 var left_scroll=ScrollContainer.new()
 left_scroll.custom_minimum_size.x=210
 left_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 body.add_child(left_scroll)
 left.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 left.size_flags_vertical=Control.SIZE_EXPAND_FILL
 left_scroll.add_child(left)
 _label(left,"素材")
 material_category=OptionButton.new()
 for type in MapMaterialSpec.TYPES:
  material_category.add_item(MapMaterialSpec.label(type))
  material_category.set_item_metadata(material_category.item_count-1,type)
 left.add_child(material_category)
 material_category.item_selected.connect(func(_index): reload_library())
 _button(left,"＋ 导入图片素材",func():
  _open_image_dialog("normal"))
 material_list=ItemList.new()
 material_list.select_mode=ItemList.SELECT_MULTI
 material_list.custom_minimum_size.y=140
 material_list.size_flags_vertical=Control.SIZE_EXPAND_FILL
 material_list.fixed_icon_size=Vector2i(40,40)
 material_list.auto_height=false
 material_list.allow_rmb_select=true
 left.add_child(material_list)
 material_list.item_activated.connect(func(_index): place_material())
 material_list.item_clicked.connect(func(index,_position,button):
  if button==MOUSE_BUTTON_RIGHT: _material_context(index))
 material_list.item_selected.connect(func(index):
  _show_land_previews()
)
 material_list.item_multi_selected.connect(func(_index,_selected): _show_land_previews.call_deferred())
 place_material_button=_button(left,"新增到地图",place_material)
 place_material_button.tooltip_text="把左侧选中的素材新增一份到地图，不会替换画布中已选中的对象。"
 material_defaults_button=_button(left,"编辑素材默认值",edit_material)
 material_defaults_button.tooltip_text="编辑素材库中的默认设置，用于以后新增的对象；已有地图对象请在右侧修改。"
 delete_materials_button=_button(left,"删除所选素材",_delete_library_selection)
 delete_materials_button.tooltip_text="从素材库移除左侧选中的条目；不会删除地图图层或图片文件。"
 material_menu=PopupMenu.new()
 material_menu.theme=theme
 add_child(material_menu)
 material_menu.id_pressed.connect(_material_context_action)
 add_light_button=_button(left,"添加单独光源",add_light)
 add_light_button.tooltip_text="创建不绑定素材的地图光源；添加后在右侧调整类型、亮度、范围和擦除区域。"
 add_light_button.hide()
 _label(left,"项目底色")
 background_control=ColorPickerButton.new()
 background_control.color=Color(str(draft.get("background_color","dfe5dc")))
 background_control.edit_alpha=false
 left.add_child(background_control)
 background_control.color_changed.connect(func(color):
  if syncing:
   return
  remember()
  draft.background_color=color.to_html(false)
  changed())
 fog_opacity=_spin(left,"雾气透明度",0,1,.05)
 fog_opacity.value=float(draft.get("fog_opacity",.65))
 fog_opacity.value_changed.connect(func(value):
  remember()
  draft.fog_opacity=value
  changed())
 fog_speed=_spin(left,"雾气飘动速度",0,3,.1)
 fog_speed.value=float(draft.get("fog_speed",1))
 fog_speed.value_changed.connect(func(value):
  remember()
  draft.fog_speed=value
  changed())
 _label(left,"水域标记 · 不可见效果范围")
 water_preview=TextureRect.new()
 water_preview.custom_minimum_size=Vector2(180,80)
 water_preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 water_preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 left.add_child(water_preview)
 water_preview.tooltip_text="纯色形状表示水域范围；不是可见素材，不参与图层排序。"
 water_preview.mouse_filter=Control.MOUSE_FILTER_STOP
 water_preview.gui_input.connect(func(event):
  if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
   if event.double_click: _edit_map_water()
   else: water_visibility.button_pressed=not water_visibility.button_pressed)
 _button(left,"绘制 / 修改地图水域",_edit_map_water)
 water_visibility=CheckBox.new()
 water_visibility.text="显示水域辅助标记"
 left.add_child(water_visibility)
 water_visibility.toggled.connect(func(value): canvas.show_water_marker=value; canvas.queue_redraw())
 var right_split=HSplitContainer.new()
 right_split.split_offset=740
 body.add_child(right_split)
 canvas=MapEditorCanvas.new()
 canvas.custom_minimum_size=Vector2(500,350)
 canvas.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 canvas.draft=draft
 canvas.farm=farm
 canvas.tooltip_text="单选素材后，拖动选框外圆形箭头旋转（Shift吸附15°），角点等比缩放。灯具的青色十字仅调整发光位置。"
 right_split.add_child(canvas)
 canvas.picked.connect(select)
 canvas.selection_changed.connect(select_many)
 canvas.group_moved.connect(move_group)
 canvas.fixture_anchor_moved.connect(func(key,index,value):
  var entry=canvas.record(key)
  if not entry.has("fixture") or canvas.is_locked(key): return
  MapLightFixture.source(entry,index).anchor=[value.x,value.y]
  dirty=true
  canvas.queue_redraw()
  undo_button.disabled=past.is_empty()
  redo_button.disabled=future.is_empty()
  status.text="已调整灯具内的发光锚点；贴图位置不变，尚未保存。")
 canvas.drag_started.connect(remember)
 canvas.duplicate_requested.connect(_duplicate_drag_selection)
 canvas.moved.connect(move_selected)
 canvas.drag_finished.connect(func(): sync_inspector())
 canvas.rotated.connect(func(value):
  var entry=canvas.record(selection)
  if entry.is_empty() or not canvas.can_transform(selection): return
  entry.rotation_degrees=value
  dirty=true
  canvas.queue_redraw()
  sync_inspector()
  undo_button.disabled=past.is_empty()
  redo_button.disabled=future.is_empty()
  status.text="旋转 %.0f°；按住 Shift 以15°吸附，Ctrl+Z 撤销。" % value)
 canvas.scaled.connect(func(value):
  var entry=canvas.record(selection)
  if not entry.is_empty() and not canvas.is_locked(selection):
   entry.scale=value
   dirty=true
   status.text="布局已修改，尚未保存。"
   undo_button.disabled=past.is_empty()
   redo_button.disabled=future.is_empty()
   canvas.queue_redraw()
   sync_inspector())
 var right_column=VBoxContainer.new()
 right_column.custom_minimum_size.x=300
 right_split.add_child(right_column)
 _label(right_column,"统一图层 · 上方覆盖下方")
 var layer_split=VBoxContainer.new()
 layer_split.size_flags_vertical=Control.SIZE_EXPAND_FILL
 right_column.add_child(layer_split)
 var layers=VBoxContainer.new()
 layer_area=layers
 layers.size_flags_vertical=Control.SIZE_EXPAND_FILL
 layer_split.add_child(layers)
 layer_tabs=TabContainer.new()
 layer_tabs.custom_minimum_size=Vector2(290,300)
 layer_tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL
 layers.add_child(layer_tabs)
 object_list=MapLayerList.new()
 object_list.select_mode=ItemList.SELECT_MULTI
 object_list.name="地图图层"
 layer_tabs.add_child(object_list)
 object_list.item_selected.connect(_queue_layer_selection)
 object_list.item_multi_selected.connect(func(index,_selected): _queue_layer_selection(index))
 object_list.item_clicked.connect(func(index,_position,button):
  if button==MOUSE_BUTTON_LEFT: _queue_layer_selection(index))
 object_list.item_activated.connect(func(index):
  if index>=0 and index<object_list.item_count:
   pending_layer_edit=str(object_list.get_item_metadata(index).get("key",""))
   _queue_layer_selection(index))
 object_list.reorder_requested.connect(_reorder_layer)
 object_list.lock_requested.connect(_toggle_layer_lock)
 var layer_actions=HBoxContainer.new()
 layers.add_child(layer_actions)
 _button(layer_actions,"上移",func(): _shift_layer(1))
 _button(layer_actions,"下移",func(): _shift_layer(-1))
 _button(layer_actions,"置顶",func(): _shift_layer(10000))
 _button(layer_actions,"置底",func(): _shift_layer(-10000))
 var layer_hint=_label(layers,"土地与环境素材自由排序。\n水域标记不在图层内；灯光不参与遮挡。")
 layer_hint.add_theme_font_size_override("font_size",12)
 layer_hint.add_theme_color_override("font_color",MapEditorTheme.MUTED)
 var sidebar_scroll=ScrollContainer.new()
 operation_area=sidebar_scroll
 sidebar_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
 sidebar_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 sidebar_scroll.custom_minimum_size.y=120
 layer_split.add_child(sidebar_scroll)
 var sidebar=VBoxContainer.new()
 sidebar.custom_minimum_size.x=205
 sidebar_scroll.add_child(sidebar)
 _button(sidebar,"← 返回图层列表",func(): show_layer_list=true; sync_inspector())
 remove_button=_button(sidebar,"移除选中对象",remove_selected)
 _label(sidebar,"素材操作")
 name_label=_label(sidebar,"请选择对象")
 inspector=VBoxContainer.new()
 sidebar.add_child(inspector)
 background_note=_label(inspector,"背景自动铺满画布、保持比例，超出部分裁切。可在图层列表拖动调整前后顺序。")
 background_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 x_control=_spin(inspector,"横向位置 X",0,1920,1)
 y_control=_spin(inspector,"纵向位置 Y",0,1080,1)
 scale_control=_spin(inspector,"等比缩放",.3,3,.01)
 rotation_control=_spin(inspector,"旋转角度（顺时针）",-360,360,1)
 rotation_control.value_changed.connect(func(value): edit_property("rotation_degrees",value))
 rotation_actions=HBoxContainer.new()
 inspector.add_child(rotation_actions)
 _button(rotation_actions,"左转90°",func(): _rotate_selection(-90))
 _button(rotation_actions,"右转90°",func(): _rotate_selection(90))
 _button(rotation_actions,"归零",func(): _rotate_selection(0,true))
 opacity_control=_spin(inspector,"素材透明度（1为不透明）",0,1,.05)
 shadow_control=_spin(inspector,"阴影强度",0,.8,.02)
 shadow_size_control=_spin(inspector,"阴影范围",.2,3,.1)
 shadow_distance_control=_spin(inspector,"阴影距离（逻辑像素，可为负）",-240,240,1)
 shadow_angle_control=_spin(inspector,"阴影方向（0°向右，90°向下）",-360,360,1)
 shadow_distance_control.value_changed.connect(func(value): edit_property("shadow_distance",value))
 shadow_angle_control.value_changed.connect(func(value): edit_property("shadow_angle",value))
 opacity_control.value_changed.connect(func(value): edit_property("opacity",value))
 shadow_control.value_changed.connect(func(value): edit_property("shadow_strength",value))
 shadow_size_control.value_changed.connect(func(value): edit_property("shadow_scale",value))
 x_control.value_changed.connect(func(value): edit_property("x",value))
 y_control.value_changed.connect(func(value): edit_property("y",value))
 scale_control.value_changed.connect(func(value): edit_property("scale",value))
 category=OptionButton.new()
 for i in MapMaterialSpec.TYPES.size():
  if MapMaterialSpec.TYPES[i] in ["land","light"]:
   continue
  category.add_item(MapMaterialSpec.LABELS[i])
  category.set_item_metadata(category.item_count-1,MapMaterialSpec.TYPES[i])
 inspector.add_child(category)
 category.item_selected.connect(func(index): edit_property("type",category.get_item_metadata(index)))
 animation=CheckBox.new()
 animation.text="启用类型对应动画"
 inspector.add_child(animation)
 animation.toggled.connect(func(value):
  var entry=canvas.record(selection)
  edit_property("animation",MapMaterialSpec.animation_for(str(entry.get("type","decoration")),value)))
 instance_water_button=_button(inspector,"编辑地图水域范围",_edit_map_water)
 fixture_instance_button=_button(inspector,"编辑灯具 · 昼夜贴图与发光锚点",_edit_fixture_instance)
 restore_soil_button=_button(inspector,"恢复默认土地贴图",func():
  var entry=canvas.record(selection)
  if entry.has("surface"):
   remember()
   entry.erase("surface")
   changed())
 _build_light_controls()
 soil_controls=VBoxContainer.new()
 inspector.add_child(soil_controls)
 _label(soil_controls,"土地外观 · 普通态与选中态")
 land_previews=HBoxContainer.new()
 soil_controls.add_child(land_previews)
 for caption in ["普通态","选中态"]:
  var box=VBoxContainer.new()
  land_previews.add_child(box)
  _label(box,caption)
  var image=TextureRect.new()
  image.custom_minimum_size=Vector2(96,64)
  image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
  image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  box.add_child(image)
  if caption=="普通态": normal_land_preview=image
  else: selected_land_preview=image
  var role="soil_normal" if caption=="普通态" else "soil_selected"
  _button(box,"更换图片",func(): _choose_object_texture(role))
 land_preview_note=_label(soil_controls,"")
 _button(soil_controls,"从素材库替换此田块外观",_choose_land_material)
 _button(soil_controls,"选中态改为自动提亮",func():
  if syncing: return
  remember()
  _editable_soil().selected_texture=""
  changed())
 soil_shape=OptionButton.new()
 for label in MapMaterialSpec.SHAPE_LABELS: soil_shape.add_item(label)
 soil_controls.add_child(soil_shape)
 soil_shape.item_selected.connect(func(index):
  remember()
  _editable_soil().shape=MapMaterialSpec.SHAPES[index]
  changed())
 soil_highlight=_spin(soil_controls,"选中态提亮程度",.02,.35,.01)
 soil_highlight.value_changed.connect(func(value):
  if syncing: return
  remember()
  _editable_soil().highlight=value
  changed())
 inline_fixture=MapFixtureInspector.new()
 inspector.add_child(inline_fixture)
 inline_fixture.operation.connect(_fixture_operation)
 inline_fixture.texture_requested.connect(func(role): _choose_object_texture(role))
 var hint=_label(sidebar,"Alt 拖动：复制并移动\n方向键：移动 1 像素\nShift + 方向键：移动 10 像素\nDel：移除所选对象\nCtrl + Z：撤销地图修改\nCtrl + Y / Ctrl + Shift + Z：重做\n\n图层单击选中，双击编辑。\n锁定图层不会移动或复制。")
 hint.add_theme_font_size_override("font_size",12)
 hint.add_theme_color_override("font_color",MapEditorTheme.MUTED)
 status=_label(column,"保存项目后应用到桌面；导入后可按分类选择素材并添加到地图。")
 status.add_theme_font_size_override("font_size",13)
 file_dialog=FileDialog.new()
 file_dialog.theme=theme
 file_dialog.title="添加自定义地图素材"
 file_dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE
 file_dialog.access=FileDialog.ACCESS_FILESYSTEM
 file_dialog.filters=PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp ; 图片素材"])
 file_dialog.use_native_dialog=true
 add_child(file_dialog)
 file_dialog.file_selected.connect(import_material)
 file_dialog.files_selected.connect(_import_materials)
 file_dialog.canceled.connect(func(): import_role="normal")
 _build_material_dialog()
 discard_dialog=ConfirmationDialog.new()
 discard_dialog.theme=theme
 discard_dialog.dialog_text="还有未保存的布局修改。关闭后将丢弃这些修改，已导入的素材仍会保留。"
 discard_dialog.ok_button_text="丢弃修改并关闭"
 add_child(discard_dialog)
 discard_dialog.confirmed.connect(func():
  draft=MapProjectStore.edit_layout(project_id)
  dirty=false
  past.clear()
  future.clear()
  selection=""
  refresh()
  hide())
 reset_dialog=ConfirmationDialog.new()
 reset_dialog.theme=theme
 reset_dialog.dialog_text="恢复这个项目上次保存的布局？未保存的编辑将被丢弃。"
 add_child(reset_dialog)
 reset_dialog.confirmed.connect(func():
  remember()
  draft=MapProjectStore.document(project_id).layout.duplicate(true)
  selection=""
  changed())
 close_requested.connect(func():
  if dirty:
   discard_dialog.popup_centered()
  else:
   hide())
 reload_library()
 refresh()

func _button(parent: Node,text: String,callback: Callable) -> Button:
 var button=Button.new()
 button.text=text
 button.pressed.connect(callback)
 parent.add_child(button)
 return button

func _label(parent: Node,text: String) -> Label:
 var label=Label.new()
 label.text=text
 parent.add_child(label)
 return label

func _spin(parent: Node,text: String,minimum: float,maximum: float,step: float) -> SpinBox:
 _label(parent,text)
 var spin=SpinBox.new()
 spin.min_value=minimum
 spin.max_value=maximum
 spin.step=step
 parent.add_child(spin)
 return spin

func remember() -> void:
 past.append(draft.duplicate(true))
 if past.size()>60:
  past.pop_front()
 future.clear()

func changed() -> void:
 dirty=true
 refresh()
 status.text="布局已修改，尚未保存。"

func refresh() -> void:
 syncing=true
 fog_opacity.set_value_no_signal(float(draft.get("fog_opacity",.65)))
 fog_speed.set_value_no_signal(float(draft.get("fog_speed",1)))
 background_control.color=Color(str(draft.get("background_color","dfe5dc")))
 syncing=false
 canvas.draft=draft
 if selection.is_empty(): selection_keys.clear()
 elif not selection_keys.has(selection): selection_keys=[selection]
 selection_keys=selection_keys.filter(func(key): return str(key)==MapLayerStack.BACKGROUND or not canvas.record(str(key)).is_empty())
 if not selection_keys.has(selection): selection=str(selection_keys.back()) if not selection_keys.is_empty() else ""
 canvas.selection=selection
 canvas.selected_keys=selection_keys.duplicate()
 canvas.queue_redraw()
 _refresh_layers()
 reload_library()
 _refresh_water_preview()
 sync_inspector()
 undo_button.disabled=past.is_empty()
 redo_button.disabled=future.is_empty()

func select(key: String) -> void:
 if selection!=key or show_layer_list: (operation_area as ScrollContainer).scroll_vertical=0
 show_layer_list=false
 selection=key
 selection_keys=[] if key.is_empty() else [key]
 refresh()

func _refresh_layers() -> void:
 var lists=[object_list]
 var scroll_positions=[]
 for list in lists:
  scroll_positions.append(list.get_v_scroll_bar().value)
 object_list.clear()
 keys.clear()
 var stack=MapLayerStack.entries(draft)
 stack.reverse()
 for layer in stack:
  var target=object_list
  var label=""
  match str(layer.kind):
   "background": label="背景 / 底色"
   "plot": label="[土地] 田块 %02d" % (int(layer.index)+1)
   "willow": label="河边柳树"
   "object":
    var entry=draft.objects[int(layer.index)]
    label="[%s] %s" % [MapMaterialSpec.label(str(entry.get("type","decoration"))),str(entry.get("name","素材"))]
  var locked=canvas.is_locked(str(layer.key))
  var background=str(layer.key)==MapLayerStack.BACKGROUND or MapLayerStack.is_background(draft,str(layer.key))
  var row=target.add_item(label,target.lock_icon(locked))
  target.set_item_metadata(row,{"key":str(layer.key),"movable":not locked,"lockable":true})
  target.set_item_tooltip(row,"点击左侧锁图标解锁；画布中无法选中或移动。" if locked else "点击左侧锁图标锁定；Shift / Ctrl 可多选图层。")
  if background: target.set_item_tooltip(row,"背景自动铺满画布；拖动可调整层级，双击可编辑透明度或移除。")
  keys.append(layer.key)
  if selection_keys.has(str(layer.key)):
   target.select(row,false)
   if str(layer.key)==selection:
    target.set_current(row)
    target.ensure_current_is_visible.call_deferred()
 for i in draft.lights.size():
  var entry=draft.lights[i]
  var kind={"point":"发散光","spot":"筒光","directional":"直射光"}.get(str(entry.get("kind","point")),"灯光")
  var locked=canvas.is_locked("light:%d" % i)
  var label="[灯光] "+str(kind)+" · "+str(entry.id)
  if not str(entry.get("parent_key","")).is_empty(): label+=" · 绑定 "+_light_parent_name(entry)
  var row=object_list.add_item(label,object_list.lock_icon(locked))
  object_list.set_item_metadata(row,{"key":"light:%d" % i,"movable":false,"lockable":true})
  object_list.set_item_tooltip(row,"点击左侧锁图标切换锁定；灯光不作为图片参与上下遮挡。")
  keys.append("light:%d" % i)
  if selection_keys.has("light:%d" % i):
   object_list.select(row,false)
   object_list.set_current(row)
   object_list.ensure_current_is_visible.call_deferred()
 for i in lists.size():
  lists[i].force_update_list_size()
  lists[i].get_v_scroll_bar().value=float(scroll_positions[i])

func _reorder_layer(source: String,target: String,below: bool) -> void:
 if canvas.is_locked(source):
  status.text="此图层已锁定，请先解锁。"
  return
 var order=MapLayerStack.reordered(draft,source,target,below)
 if order==MapLayerStack.keys(draft):
  return
 remember()
 draft.layer_order=order
 selection=source
 changed()
 status.text="图层顺序已修改；土地与环境素材按相同规则排序。"

func _shift_layer(direction: int) -> void:
 var order=[]
 for layer in MapLayerStack.entries(draft):
  order.append(str(layer.key))
 var index=order.find(selection)
 if index<0:
  status.text="请先选中需要排序的图层；独立光源不参与排序。"
  return
 var target=clampi(index+direction,0,order.size()-1)
 if target!=index:
  _reorder_layer(selection,order[target],direction<0)

func sync_inspector() -> void:
 syncing=true
 var entry=canvas.record(selection)
 var background=MapLayerStack.is_background(draft,selection)
 background_note.visible=background
 for control in [x_control,y_control,scale_control,rotation_control,shadow_control,shadow_size_control,shadow_distance_control,shadow_angle_control]:
  _show_labeled_field(control,not background)
 var has_selection=not selection_keys.is_empty()
 layer_area.visible=not has_selection or show_layer_list
 operation_area.visible=has_selection and not show_layer_list
 var multiple=selection_keys.size()>1
 var locked=canvas.is_locked(selection)
 remove_button.visible=not entry.is_empty() and selection!="willow"
 remove_button.disabled=locked and not multiple
 inspector.visible=not entry.is_empty() and not multiple and not locked
 soil_controls.visible=selection.begins_with("plot-") and not multiple
 if soil_controls.visible:
  var surface=entry.get("surface",{})
  soil_shape.select(maxi(0,MapMaterialSpec.SHAPES.find(str(surface.get("shape","square")))))
  soil_highlight.set_value_no_signal(float(surface.get("highlight",.12)))
 inline_fixture.visible=str(entry.get("type",""))=="light" and entry.has("fixture") and not multiple
 if inline_fixture.visible: inline_fixture.sync(entry)
 fixture_instance_button.hide()
 name_label.text="请选择对象" if entry.is_empty() else ("田块 %02d" % (_plot_index(selection)+1) if selection.begins_with("plot-") else str(entry.get("name",selection)))
 if multiple: name_label.text="已选 %d 个图层 · 拖动进行整体移动" % selection_keys.size()
 elif locked and not entry.is_empty(): name_label.text+=" · 已锁定，请先解锁"
 if not entry.is_empty():
  var position=canvas.record_position(selection)
  x_control.set_value_no_signal(position.x)
  y_control.set_value_no_signal(position.y)
  var light=selection.begins_with("light:")
  _show_labeled_field(rotation_control,not background and not light)
  rotation_actions.visible=not background and not light
  rotation_control.set_value_no_signal(float(entry.get("rotation_degrees",0)))
  opacity_control.editable=not light
  shadow_control.editable=not light
  shadow_size_control.editable=not light
  shadow_distance_control.editable=not light
  shadow_angle_control.editable=not light
  shadow_distance_control.set_value_no_signal(float(entry.get("shadow_distance",0)))
  shadow_angle_control.set_value_no_signal(float(entry.get("shadow_angle",90)))
  opacity_control.set_value_no_signal(float(entry.get("opacity",1)))
  shadow_control.set_value_no_signal(float(entry.get("shadow_strength",.17 if selection.begins_with("plot-") else (.2 if selection=="willow" else 0))))
  shadow_size_control.set_value_no_signal(float(entry.get("shadow_scale",1)))
  scale_control.editable=not light
  scale_control.set_value_no_signal(float(entry.get("scale",1)))
  var custom=not selection.begins_with("plot-") and not light and selection!="willow"
  instance_water_button.visible=custom and str(entry.get("type",""))=="water"
  fixture_instance_button.visible=custom and str(entry.get("type",""))=="light" and not entry.has("fixture")
  category.visible=false
  if str(entry.get("type",""))=="light":
   category.visible=false
  animation.visible=custom and not background
  remove_button.visible=custom or light or selection.begins_with("plot-")
  remove_button.text="移除选中对象"
  restore_soil_button.visible=selection.begins_with("plot-") and entry.has("surface") and draft.get("scene_mode","reference")=="reference" and _plot_index(selection)<18
  if custom:
   for i in category.item_count:
    if category.get_item_metadata(i)==MapMaterialSpec.normalize(entry).type:
     category.select(i)
   animation.set_pressed_no_signal(entry.animation=="wind")
   var type=str(MapMaterialSpec.normalize(entry).type)
   animation.disabled=not MapMaterialSpec.can_animate(type)
   animation.set_pressed_no_signal(entry.animation!="static")
 light_controls.visible=not entry.is_empty() and selection.begins_with("light:")
 if entry.is_empty():
  instance_water_button.hide()
  fixture_instance_button.hide()
 if light_controls.visible:
  _sync_light_controls(entry)
 syncing=false

func _rotate_selection(amount: float,reset: bool=false) -> void:
 var entry=canvas.record(selection)
 if entry.is_empty() or selection_keys.size()!=1 or not canvas.can_transform(selection): return
 edit_property("rotation_degrees",0.0 if reset else wrapf(float(entry.get("rotation_degrees",0))+amount,-180,180))

func edit_property(key: String,value: Variant) -> void:
 if syncing or key=="type":
  return
 var entry=canvas.record(selection)
 if entry.is_empty() or canvas.is_locked(selection) or selection_keys.size()>1:
  return
 if MapLayerStack.is_background(draft,selection) and key in ["x","y","scale"]: return
 remember()
 if key=="x":
  var position=canvas.record_position(selection)
  position.x=float(value)
  _set_record_position(selection,position)
 elif key=="y":
  var position=canvas.record_position(selection)
  position.y=float(value)
  _set_record_position(selection,position)
 elif key=="type":
  entry.type=str(value)
  entry.category=MapMaterialSpec.label(entry.type)
  entry.animation=MapMaterialSpec.animation_for(entry.type,true)
 else:
  entry[key]=value
 changed()

func move_selected(position: Vector2) -> void:
 var entry=canvas.record(selection)
 if entry.is_empty() or not canvas.can_transform(selection):
  return
 _set_record_position(selection,position)
 dirty=true
 canvas.queue_redraw()
 sync_inspector()
 undo_button.disabled=past.is_empty()
 redo_button.disabled=future.is_empty()
 status.text="布局已修改，尚未保存。"

func _input(event: InputEvent) -> void:
 if not visible or not has_focus() or not event is InputEventKey: return
 if not event.pressed: return
 var focus=gui_get_focus_owner()
 if focus is LineEdit or focus is TextEdit or focus is Range or focus is OptionButton: return
 if event.is_command_or_control_pressed():
  if event.keycode==KEY_Z:
   if event.shift_pressed: redo()
   else: undo()
  elif event.keycode==KEY_Y: redo()
  else: return
  set_input_as_handled()
  return
 if event.alt_pressed: return
 if event.keycode==KEY_DELETE:
  if not event.echo:
   if layer_sync_queued: _flush_layer_selection()
   remove_selected()
  set_input_as_handled()
  return
 var direction={KEY_LEFT:Vector2.LEFT,KEY_RIGHT:Vector2.RIGHT,KEY_UP:Vector2.UP,KEY_DOWN:Vector2.DOWN}.get(event.keycode,Vector2.ZERO)
 if direction==Vector2.ZERO: return
 var origins={}
 for key in selection_keys:
  if canvas.can_transform(str(key)) and not canvas.record(str(key)).is_empty(): origins[key]=canvas.record_position(str(key))
 if origins.is_empty(): return
 var delta=direction*(10 if event.shift_pressed else 1)
 var lo=Vector2(-INF,-INF)
 var hi=Vector2(INF,INF)
 for origin in origins.values():
  lo=lo.max(-origin)
  hi=hi.min(Vector2(1920,1080)-origin)
 delta=delta.clamp(lo,hi)
 if delta==Vector2.ZERO:
  set_input_as_handled()
  return
 if not event.echo: remember()
 var positions={}
 for key in origins: positions[key]=origins[key]+delta
 move_group(positions)
 status.text="已微调 %d 个图层，步长 %d 像素。" % [positions.size(),10 if event.shift_pressed else 1]
 set_input_as_handled()

func _duplicate_drag_selection() -> void:
 var sources=canvas.drag_origins.keys()
 var mapping={}
 var objects=[]
 var plots=[]
 var order=MapLayerStack.keys(draft)
 for key in sources:
  if str(key).begins_with("light:") or canvas.is_locked(str(key)): continue
  var copy=canvas.record(str(key)).duplicate(true)
  if copy.is_empty(): continue
  if str(key)=="willow":
   copy=_willow_copy()
   if copy.is_empty(): return
  var id=("plot-" if str(key).begins_with("plot-") else "object-")+str(Time.get_ticks_usec())+"-"+str(randi())
  copy.id=id
  mapping[key]=id
  if str(key).begins_with("plot-"): plots.append(copy)
  else:
   copy.phase=float(copy.get("phase",float(absi(hash(str(key)))%1000)*.01))
   objects.append(copy)
 if draft.objects.size()+objects.size()>128 or draft.plots.size()+plots.size()>128:
  status.text="复制后超过地图容量（最多128个素材、128块田），未复制。"
  return
 var lights=[]
 for i in draft.lights.size():
  var source=draft.lights[i]
  var key="light:%d" % i
  var parent=str(source.get("parent_key",""))
  if not mapping.has(parent) and not sources.has(key): continue
  if not mapping.has(parent) and canvas.is_locked(key): continue
  var copy=source.duplicate(true)
  copy.id="light-%d-%d" % [Time.get_ticks_usec(),randi()]
  if mapping.has(parent): copy.parent_key=mapping[parent]
  mapping[key]="light:%d" % (draft.lights.size()+lights.size())
  lights.append(copy)
 if mapping.is_empty(): return
 # The initial mouse press has already saved the undo snapshot. Cloning and
 # the ensuing drag form one operation, including attached light sources.
 draft.objects.append_array(objects)
 draft.plots.append_array(plots)
 draft.lights.append_array(lights)
 var next_order=[]
 for key in order:
  next_order.append(key)
  if mapping.has(key): next_order.append(mapping[key])
 draft.layer_order=next_order
 selection_keys=[]
 for key in sources:
  if mapping.has(key): selection_keys.append(mapping[key])
 selection=str(selection_keys.back()) if not selection_keys.is_empty() else ""
 changed()
 status.text="已复制 %d 个图层及绑定灯光，继续拖动放置副本。" % selection_keys.size()

func _willow_copy() -> Dictionary:
 var map=MapDefinition.load_map()
 var spec=map.willow
 var texture=ContentCatalog.prepared_texture(spec.texture,1536,spec.region,spec.get("edge_cleanup",{}))
 if texture==null:
  status.text="柳树贴图无法读取，未复制。"
  return {}
 var image=texture.get_image()
 image.clear_mipmaps()
 var path="user://maps/materials/tree-copy-"+image.get_data().hex_encode().sha256_text()+".png"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
 var error=image.save_png(path)
 if error!=OK:
  status.text="保存柳树副本失败："+error_string(error)
  return {}
 var copy=draft.willow.duplicate(true)
 copy.merge({"name":"河边柳树","texture":path,"type":"tree","category":"环境树木","animation":"wind","height":canvas.sprite_rect(copy,true).size.y/float(copy.get("scale",1)),"anchor":spec.anchor.duplicate(),"sway":float(spec.get("sway",.004)),"wind_response":float(spec.get("wind_response",6)),"day_exposure":float(spec.get("day_exposure",1)),"phase":2.7,"shadow_strength":float(copy.get("shadow_strength",.2))},true)
 return copy

func select_many(next: Array) -> void:
 show_layer_list=false
 if next.size()==1:
  select(str(next[0]))
  return
 selection_keys=next.duplicate()
 selection=str(selection_keys.back()) if not selection_keys.is_empty() else ""
 refresh()

func _queue_layer_selection(index: int) -> void:
 pending_layer_index=index
 if layer_sync_queued: return
 layer_sync_queued=true
 _flush_layer_selection.call_deferred()

func _flush_layer_selection() -> void:
 if not layer_sync_queued: return
 layer_sync_queued=false
 var edit=pending_layer_edit
 pending_layer_edit=""
 if object_list.lock_click_pending: return
 _layer_selection_changed(pending_layer_index)
 if not edit.is_empty(): select(edit)

func _layer_selection_changed(index: int) -> void:
 if object_list.lock_click_pending: return
 var next=[]
 for row in object_list.get_selected_items():
  if row<keys.size(): next.append(keys[row])
 if index>=0 and index<keys.size() and next.has(keys[index]):
  next.erase(keys[index])
  next.append(keys[index])
 # List selection includes locked layers for inspection. Canvas picking still
 # skips them; selecting a row must not silently unlock or move its element.
 selection_keys=next
 selection=str(next.back()) if not next.is_empty() else ""
 show_layer_list=true
 refresh()

func _toggle_layer_lock(key: String) -> void:
 var entry=canvas.record(key)
 if key!=MapLayerStack.BACKGROUND and entry.is_empty(): return
 var locked=not canvas.is_locked(key)
 remember()
 if key==MapLayerStack.BACKGROUND: draft.background_locked=locked
 else: entry.editor_locked=locked
 # Keep the list open so locks can be toggled across consecutive rows.
 show_layer_list=true
 changed()
 status.text="图层已锁定（仅编辑器）。" if locked else "图层已解锁。"

func move_group(positions: Dictionary) -> void:
 # Move parents first, then resolve selected child lights against their new
 # parent positions. A jointly selected light must not receive the delta twice.
 for lights_only in [false,true]:
  for key in positions:
   if str(key).begins_with("light:")!=lights_only: continue
   var entry=canvas.record(str(key))
   if not entry.is_empty() and canvas.can_transform(str(key)):
    _set_record_position(str(key),positions[key])
 dirty=true
 canvas.queue_redraw()
 sync_inspector()
 undo_button.disabled=past.is_empty()
 redo_button.disabled=future.is_empty()
 status.text="已整体移动 %d 个对象，尚未保存。" % positions.size()

func undo() -> void:
 if past.is_empty():
  return
 future.append(draft.duplicate(true))
 draft=past.pop_back()
 changed()

func redo() -> void:
 if future.is_empty():
  return
 past.append(draft.duplicate(true))
 draft=future.pop_back()
 changed()

func save_draft() -> bool:
 if not MapLayoutStore.valid(draft):
  status.text="布局数据无效，未保存。"
  return false
 var result=MapLayoutStore.write_json(MapProjectStore.draft_path(project_id),draft)
 if result==OK:
  result=MapProjectStore.save_project(project_id,draft)
 if result!=OK:
  status.text="保存失败："+error_string(result)
  return false
 dirty=false
 status.text="项目已保存；点击应用后才更新桌面。"
 _save_thumbnail.call_deferred()
 return true

func apply_layout() -> void:
 if not save_draft():
  return
 application_requested.emit(project_id,draft.duplicate(true))

func reload_library() -> void:
 if material_list==null or material_category==null: return
 var selected_id=""
 var selected_items=material_list.get_selected_items()
 if not selected_items.is_empty() and selected_items[0]<materials.size(): selected_id=str(materials[selected_items[0]].id)
 var all_materials=MapLayoutStore.library()
 all_materials.push_front(_builtin_land())
 var known={}
 for entry in all_materials: known[str(entry.id)]=true
 for entry in _map_materials():
  if not known.has(str(entry.id)):
   all_materials.append(entry)
   known[str(entry.id)]=true
 materials=[]
 material_list.clear()
 material_icons.clear()
 var type=str(material_category.get_selected_metadata())
 for entry in all_materials:
  if str(entry.type)!=type: continue
  materials.append(entry)
  var image=_resource_icon(entry)
  material_icons.append(image)
  var row=material_list.add_item(str(entry.name),image)
  material_list.set_item_tooltip(row,"类型："+MapMaterialSpec.label(entry.type)+("\n双击新增田块；修改已有田块请先在画布选中它。" if entry.type=="land" else "\n双击添加到地图。")+("\n右键可从素材库删除，地图内已放置的实例会保留。" if not entry.has("builtin") else ""))
  if str(entry.id)==selected_id: material_list.select(row)
 if material_list.get_selected_items().is_empty() and material_list.item_count>0: material_list.select(0)
 _show_land_previews()

func _builtin_land() -> Dictionary:
 var map=MapDefinition.load_map()
 return MapMaterialSpec.normalize({"id":"builtin-land","name":"内置耕地","type":"land","texture":map.soil_atlas,"region":map.soil_regions[0],"edge_cleanup":map.get("soil_edge_cleanup",{}),"builtin":"land","width":240,"height":140,"display_height":140})

func _resource_icon(entry: Dictionary) -> Texture2D:
 if str(entry.get("texture","")).is_empty():
  var image=Image.create(32,32,false,Image.FORMAT_RGBA8)
  image.fill(Color(str(entry.get("color",draft.get("background_color","dfe5dc")))))
  return ImageTexture.create_from_image(image)
 return ContentCatalog.prepared_texture(entry.texture,96,entry.get("region",[]),entry.get("edge_cleanup",{}))

func _map_materials() -> Array:
 var result=[]
 var seen={}
 for i in draft.plots.size():
  var plot=draft.plots[i]
  var entry=_builtin_land()
  if plot.has("surface"):
   var surface=plot.surface
   entry=MapMaterialSpec.normalize(surface.merged({"id":str(surface.get("material_id",surface.texture)),"name":"土地素材","type":"land","display_height":surface.height},true))
   for resource in MapLayoutStore.library():
    if str(resource.id)==str(entry.id): entry.name=resource.name
  var key=str(entry.id)+str(entry.get("selected_texture",""))
  if seen.has(key):
   result[int(seen[key])].usage+=1
  else:
   entry.usage=1
   entry.location_key=str(plot.id)
   seen[key]=result.size()
   result.append(entry)
 for object in draft.objects:
  var key=str(object.get("material_id",object.texture))+str(object.get("type","decoration"))
  if seen.has(key): result[int(seen[key])].usage+=1
  else:
   var image=ContentCatalog.prepared_texture(object.texture,64)
   if image==null: continue
   var entry=MapMaterialSpec.normalize(object.merged({"id":str(object.get("material_id",object.id)),"width":image.get_width(),"height":image.get_height(),"display_height":object.height,"usage":1,"location_key":object.id},true))
   seen[key]=result.size()
   result.append(entry)
 if str(draft.get("scene_mode","reference"))!="blank":
  var map=MapDefinition.load_map()
  if not draft.willow.is_empty():
   result.append(MapMaterialSpec.normalize(map.willow.merged({"id":"builtin-willow","name":"河边柳树","type":"tree","width":300,"height":300,"display_height":240,"builtin":"willow","location_key":"willow"},true)))
  result.append(MapMaterialSpec.normalize({"id":"builtin-background","name":"背景整图 · 未拆分元素","type":"background","texture":map.background,"width":1920,"height":1080,"builtin":"background","location_key":MapLayerStack.BACKGROUND}))
 else:
  result.append(MapMaterialSpec.normalize({"id":"builtin-background","name":"项目底色","type":"background","texture":"","width":1920,"height":1080,"builtin":"background","location_key":MapLayerStack.BACKGROUND}))
 for i in draft.lights.size():
  result.append(MapMaterialSpec.normalize({"id":"builtin-light-%d" % i,"name":"灯光 · "+str(draft.lights[i].id),"type":"light","texture":"","color":draft.lights[i].get("color","ffb45c"),"width":32,"height":32,"builtin":"light","location_key":"light:%d" % i}))
 return result

func _show_land_previews() -> void:
 _refresh_material_actions()
 if land_previews==null: return
 var plot=canvas.record(selection)
 var visible=selection.begins_with("plot-") and selection_keys.size()==1 and not plot.is_empty()
 land_previews.visible=visible
 land_preview_note.visible=visible
 if not visible: return
 var entry=MapMaterialSpec.normalize(plot.surface) if plot.has("surface") else _builtin_land()
 normal_land_preview.texture=ContentCatalog.prepared_texture(entry.texture,192,entry.get("region",[]),entry.get("edge_cleanup",{}))
 var path=MapMaterialSpec.selection_texture(entry)
 selected_land_preview.texture=ContentCatalog.prepared_texture(path,192) if not path.is_empty() else (ContentCatalog.prepared_texture(entry.texture,192,entry.selected_region,entry.get("edge_cleanup",{})) if entry.has("selected_region") else normal_land_preview.texture)
 var mat=ShaderMaterial.new()
 mat.shader=load("res://assets/shaders/map_material_preview.gdshader")
 mat.set_shader_parameter("highlight",float(entry.get("highlight",.12)) if path.is_empty() and not entry.has("selected_region") else 0.0)
 selected_land_preview.material=mat
 land_preview_note.text="普通 / 选中贴图" if not path.is_empty() or entry.has("selected_region") else "选中态：自动提亮"

func _refresh_material_actions() -> void:
 if place_material_button==null: return
 add_light_button.visible=str(material_category.get_selected_metadata())=="light"
 var indices=material_list.get_selected_items()
 var empty=indices.is_empty() or indices[0]>=materials.size()
 place_material_button.disabled=empty
 material_defaults_button.visible=true
 delete_materials_button.visible=true
 delete_materials_button.disabled=true
 for index in indices:
  if not materials[index].has("builtin"): delete_materials_button.disabled=false
 material_defaults_button.disabled=empty
 if empty:
  place_material_button.text="新增到地图"
  return
 var entry=materials[indices[0]]
 material_defaults_button.disabled=entry.has("builtin") or indices.size()!=1
 place_material_button.text="定位地图对象" if str(entry.get("builtin","")) in ["willow","background","light"] else ("新增田块" if str(entry.type)=="land" else "新增到地图")
 if indices.size()>1: place_material_button.text="新增所选 %d 个素材" % indices.size()

func _open_image_dialog(role: String) -> void:
 import_role=role
 file_dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILES if role=="normal" else FileDialog.FILE_MODE_OPEN_FILE
 file_dialog.popup_centered_ratio(.75)

func _import_materials(paths: PackedStringArray) -> void:
 if paths.is_empty(): return
 if paths.size()==1:
  import_material(paths[0])
  return
 var type=str(material_category.get_selected_metadata())
 var imported=[]
 var failures=[]
 for path in paths:
  var entry=MapLayoutStore.import_material(path)
  if entry.has("error"):
   failures.append(path.get_file()+"："+str(entry.error))
   continue
  entry.type=type
  entry.motion_enabled=MapMaterialSpec.can_animate(type)
  entry=MapMaterialSpec.normalize(entry)
  var error=MapLayoutStore.save_material(entry)
  if error!=OK: failures.append(path.get_file()+"："+error_string(error))
  elif not imported.has(str(entry.id)): imported.append(str(entry.id))
 import_role="normal"
 reload_library()
 material_list.deselect_all()
 for i in materials.size():
  if imported.has(str(materials[i].id)): material_list.select(i,false)
 _show_land_previews()
 status.text="已批量导入 %d 个素材到当前分类；可一起新增到地图，单选后编辑默认值。" % imported.size()
 if not failures.is_empty(): status.text+="\n%d 个失败：%s" % [failures.size(),"；".join(failures.slice(0,3))]

func import_material(path: String) -> void:
 var role=import_role
 if role in ["soil_normal","soil_selected","object_day","object_night"]:
  import_role="normal"
  var target=canvas.record(texture_target)
  if target.is_empty() or canvas.is_locked(texture_target): return
  var imported=MapLayoutStore.import_material(path,false)
  if imported.has("error"): status.text=str(imported.error); return
  if role.begins_with("object_"):
   var candidate=target.duplicate(true)
   candidate["texture" if role=="object_day" else "night_texture"]=imported.texture
   if role=="object_day": candidate.sprite_aspect=float(imported.width)/float(imported.height)
   var error=MapLightFixture.texture_error(candidate)
   if not error.is_empty(): status.text=error; return
   remember()
   target.merge(candidate,true)
  else:
   remember()
   var surface=_editable_soil()
   surface["texture" if role=="soil_normal" else "selected_texture"]=imported.texture
   if role=="soil_normal": surface.width=float(surface.height)*float(imported.width)/float(imported.height)
  changed()
  return
 var selected_image=import_role=="selected"
 import_role="normal"
 var entry=MapLayoutStore.import_material(path,not selected_image and not role in ["fixture_day","fixture_night"])
 if entry.has("error"):
  status.text="导入失败："+str(entry.error)
  if material_error!=null: material_error.text=status.text
  return
 if role in ["fixture_day","fixture_night"]:
  if role=="fixture_day":
   editing_material.texture=entry.texture
   editing_material.width=entry.width
   editing_material.height=entry.height
   editing_material.sprite_aspect=float(entry.width)/float(entry.height)
  else: editing_material.night_texture=entry.texture
  _sync_fixture_controls()
  return
 if selected_image:
  editing_material.selected_texture=entry.texture
  _sync_material_previews()
  return
 var library_entry=entry.duplicate(true)
 library_entry.type=str(material_category.get_selected_metadata())
 library_entry.motion_enabled=MapMaterialSpec.can_animate(library_entry.type)
 library_entry=MapMaterialSpec.normalize(library_entry)
 MapLayoutStore.save_material(library_entry)
 reload_library()
 for i in materials.size():
  if materials[i].id==entry.id:
   material_list.select(i)
 status.text="素材已保存到素材库；选中后可新增到地图。已有对象请在画布选中后修改。"
 edit_material()

func place_material() -> void:
 var indices=material_list.get_selected_items()
 if indices.is_empty():
  status.text="请先在素材库中选择图片；Ctrl / Shift 可多选。"
  return
 var valid=[]
 var failures=[]
 var object_slots=128-draft.objects.size()
 var plot_slots=128-draft.plots.size()
 for index in indices:
  var material=materials[index]
  if str(material.get("builtin","")) in ["willow","background","light"]:
   if indices.size()==1:
    select(str(material.location_key))
    status.text="已定位地图对象。"
    return
   failures.append(str(material.name)+"：只能定位，不能重复放置")
   continue
  if material.type=="light":
   var error=MapLightFixture.texture_error(material)
   if not error.is_empty():
    failures.append(str(material.name)+"："+error)
    continue
  if (plot_slots if material.type=="land" else object_slots)<=0:
   failures.append(str(material.name)+"：地图容量不足")
   continue
  valid.append(material)
  if material.type=="land": plot_slots-=1
  else: object_slots-=1
 if valid.is_empty():
  status.text="未添加："+"；".join(failures.slice(0,3))
  return
 remember()
 var next=[]
 var columns=ceili(sqrt(float(valid.size())))
 var rows=ceili(float(valid.size())/columns)
 for i in valid.size():
  var offset=Vector2((i%columns-(columns-1)*.5)*50,(floori(float(i)/columns)-(rows-1)*.5)*40)
  next.append(_append_map_material(valid[i],offset))
 selection_keys=next
 selection=str(next.back())
 show_layer_list=false
 changed()
 status.text="已新增 %d 个对象；可多选一起移动，Ctrl+Z 撤销整次添加。" % next.size()
 if not failures.is_empty(): status.text+="\n跳过 %d 个：%s" % [failures.size(),"；".join(failures.slice(0,3))]

func _append_map_material(material: Dictionary,offset: Vector2) -> String:
 if material.type=="land":
  var id="plot-%d-%d" % [Time.get_ticks_usec(),randi()]
  var point=Vector2(960,700)+offset
  var plot={"id":id,"position":[point.x,point.y],"scale":1.0}
  _assign_land_material(plot,material,float(material.display_height))
  draft.plots.append(plot)
  return id
 var id="object-%d-%d" % [Time.get_ticks_usec(),randi()]
 var point=Vector2(960,650)+offset
 var object={"id":id,"name":material.name,"material_id":material.id,"texture":material.texture,"position":[point.x,point.y],"height":material.display_height,"scale":1.0,"anchor":material.anchor.duplicate(),"category":MapMaterialSpec.label(material.type),"type":material.type,"water":material.water.duplicate(true),"animation":MapMaterialSpec.animation_for(material.type,material.motion_enabled)}
 draft.objects.append(object)
 if material.type=="background":
  object.position=[960,540]
  object.height=1080.0
  object.anchor=[.5,.5]
  object.animation="static"
  var order=MapLayerStack.keys(draft)
  order.erase(id)
  var at=0
  for i in order.size():
   if MapLayerStack.is_background(draft,str(order[i])): at=i+1
  order.insert(at,id)
  draft.layer_order=order
 if material.type=="light":
  object.fixture=material.fixture.duplicate(true)
  object.night_texture=material.night_texture
  object.sprite_aspect=material.sprite_aspect
  if material.has("emission_mask"): object.emission_mask=material.emission_mask
 return id

func _assign_land_material(plot: Dictionary,material: Dictionary,height: float) -> void:
 if str(material.get("builtin",""))=="land":
  plot.erase("surface")
 else:
  plot.surface={"material_id":material.id,"texture":material.texture,"selected_texture":material.selected_texture,"highlight":material.highlight,"shape":material.shape,"plant_anchor":material.plant_anchor.duplicate(),"height":height,"width":height*float(material.width)/float(material.height)}

func _choose_land_material() -> void:
 var key=selection
 var index=_plot_index(key)
 if index<0 or selection_keys.size()!=1 or canvas.is_locked(key): return
 var options=[_builtin_land()]
 for material in MapLayoutStore.library():
  if str(material.type)=="land": options.append(material)
 var dialog=ConfirmationDialog.new()
 dialog.title="替换所选田块的土地素材"
 dialog.theme=theme
 dialog.ok_button_text="替换此田块"
 dialog.cancel_button_text="取消"
 dialog.exclusive=true
 var list=ItemList.new()
 list.custom_minimum_size=Vector2(440,300)
 list.fixed_icon_size=Vector2i(56,40)
 dialog.add_child(list)
 var current=str(draft.plots[index].get("surface",{}).get("material_id","builtin-land"))
 for material in options:
  var row=list.add_item(str(material.name),_resource_icon(material))
  if str(material.id)==current: list.select(row)
 if list.get_selected_items().is_empty(): list.select(0)
 add_child(dialog)
 var apply=func():
  var selected=list.get_selected_items()
  var target_index=_plot_index(key)
  if selected.is_empty() or target_index<0 or canvas.is_locked(key): return
  var plot=draft.plots[target_index]
  var height=float(plot.get("surface",{}).get("height",canvas.plot_size(target_index,1.0).y))
  remember()
  _assign_land_material(plot,options[selected[0]],height)
  selection=key
  selection_keys=[key]
  show_layer_list=false
  changed()
  status.text="已替换所选田块外观，位置、缩放与种植记录保留。"
  dialog.queue_free()
 dialog.confirmed.connect(apply)
 list.item_activated.connect(func(_index): apply.call())
 dialog.canceled.connect(dialog.queue_free)
 dialog.popup_centered()

func _material_context(index: int) -> void:
 if index<0 or index>=materials.size(): return
 material_list.select(index)
 _show_land_previews()
 var entry=materials[index]
 material_menu_id=str(entry.id)
 material_menu.clear()
 material_menu.add_item("从素材库删除",0)
 material_menu.set_item_disabled(0,entry.has("builtin"))
 material_menu.set_item_tooltip(0,"内置素材不能删除。" if entry.has("builtin") else "仅移除素材库条目；已放到地图中的素材和图片文件保留。")
 material_menu.position=DisplayServer.mouse_get_position()
 material_menu.popup()

func _material_context_action(action: int) -> void:
 if action!=0 or material_menu_id.is_empty(): return
 var error=MapLayoutStore.remove_material(material_menu_id)
 if error!=OK:
  status.text="删除素材失败："+error_string(error)
  return
 material_menu_id=""
 reload_library()
 status.text="已删除素材条目；已放置在地图中的素材保留。"

func _delete_library_selection() -> void:
 var ids=[]
 for index in material_list.get_selected_items():
  var entry=materials[index]
  if not entry.has("builtin"): ids.append(str(entry.id))
 if ids.is_empty():
  status.text="请选中自定义素材；内置素材不能从库中删除。"
  return
 var error=MapLayoutStore.remove_materials(ids)
 if error!=OK:
  status.text="删除素材失败："+error_string(error)
  return
 reload_library()
 status.text="已从素材库移除 %d 个条目；地图实例和图片文件保留。" % ids.size()

func remove_selected() -> void:
 if selection_keys.is_empty():
  status.text="请先选中地图图层；Del 只删除图层，素材库请使用“删除所选素材”。"
  return
 var removed={}
 var light_ids={}
 var skipped=0
 for key in selection_keys:
  if canvas.is_locked(str(key)) or str(key)=="willow":
   skipped+=1
   continue
  var entry=canvas.record(str(key))
  if entry.is_empty(): continue
  if str(key).begins_with("light:"):
   light_ids[str(entry.id)]=true
   continue
  var occupied=false
  if str(key).begins_with("plot-") and canvas.farm!=null:
   for plot in canvas.farm.data.plots:
    if str(plot.get("map_plot_id",""))==str(key) and not str(plot.crop).is_empty(): occupied=true; break
  if occupied:
   skipped+=1
   continue
  removed[str(key)]=true
 if removed.is_empty() and light_ids.is_empty():
  status.text="没有可移除的对象；锁定图层、内置底图及仍种着作物的田块会保留。"
  return
 remember()
 var before=draft.objects.size()+draft.plots.size()+draft.lights.size()
 draft.objects=draft.objects.filter(func(item): return not removed.has(str(item.id)))
 draft.plots=draft.plots.filter(func(item): return not removed.has(str(item.id)))
 draft.lights=draft.lights.filter(func(item): return not light_ids.has(str(item.id)) and not removed.has(str(item.get("parent_key",""))))
 draft.layer_order=draft.get("layer_order",[]).filter(func(key): return not removed.has(str(key)))
 var count=before-draft.objects.size()-draft.plots.size()-draft.lights.size()
 selection=""
 selection_keys=[]
 show_layer_list=true
 changed()
 status.text="已移除 %d 个对象（含绑定灯光），Ctrl+Z 可撤销。" % count
 if skipped>0: status.text+="保留 %d 个锁定或不可移除对象。" % skipped

func _custom_light_count() -> int:
 var count=0
 for entry in draft.objects:
  if str(entry.get("type",""))=="light":
   count+=1
 return count

func _build_material_dialog() -> void:
 material_dialog=AcceptDialog.new()
 material_dialog.theme=theme
 material_dialog.title="素材属性（保存到素材库）"
 material_dialog.size=Vector2i(600,760)
 material_dialog.ok_button_text="保存素材属性"
 material_dialog.dialog_hide_on_ok=false
 add_child(material_dialog)
 var dialog_body=VBoxContainer.new()
 material_dialog.add_child(dialog_body)
 var scroll=ScrollContainer.new()
 scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
 scroll.custom_minimum_size=Vector2(550,560)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 dialog_body.add_child(scroll)
 var column=VBoxContainer.new()
 column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 column.add_theme_constant_override("separation",8)
 scroll.add_child(column)
 _label(column,"选择类型后，程序按类型启用种植、漂移或摇曳。")
 material_type=OptionButton.new()
 for label in MapMaterialSpec.LABELS:
  material_type.add_item(label)
 column.add_child(material_type)
 material_type.item_selected.connect(func(index):
  editing_material.type=MapMaterialSpec.TYPES[index]
  editing_material.motion_enabled=MapMaterialSpec.can_animate(editing_material.type)
  editing_material.anchor=[.5,.5] if editing_material.type in ["land","cloud","water","light"] else [.5,1.0]
  editing_material.display_height=140.0 if editing_material.type=="land" else 240.0
  _sync_material_controls())
 material_height=_spin(column,"默认显示高度（逻辑像素；放置后可等比缩放）",8,1080,1)
 material_height.value_changed.connect(func(value): editing_material.display_height=value)
 material_background_note=_label(column,"背景自动铺满画布、保持图片比例并裁切超出部分，无需设置高度。")
 material_background_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 material_motion=CheckBox.new()
 material_motion.text="启用类型对应动画（静态素材可以关闭）"
 column.add_child(material_motion)
 material_motion.toggled.connect(func(value): editing_material.motion_enabled=value)
 _build_fixture_controls(column)
 material_water_options=VBoxContainer.new()
 column.add_child(material_water_options)
 _button(material_water_options,"打开地图水域编辑器",func(): material_dialog.hide(); _edit_map_water())
 _label(material_water_options,"此分类只存放可见水面贴图。\n水域范围在地图上单独绘制，不加入图层。")
 material_land_options=VBoxContainer.new()
 column.add_child(material_land_options)
 _label(material_land_options,"土地轮廓 / 点击范围")
 material_shape=OptionButton.new()
 for label in MapMaterialSpec.SHAPE_LABELS:
  material_shape.add_item(label)
 material_land_options.add_child(material_shape)
 material_shape.item_selected.connect(func(index): editing_material.shape=MapMaterialSpec.SHAPES[index])
 material_highlight=_spin(material_land_options,"自动选中态提亮强度",.02,.35,.01)
 material_highlight.value_changed.connect(func(value):
  editing_material.highlight=value
  _sync_material_previews())
 material_root_x=_spin(material_land_options,"种植锚点 X（0～1）",0,1,.01)
 material_root_y=_spin(material_land_options,"种植锚点 Y（0～1）",0,1,.01)
 material_root_x.value_changed.connect(func(value): editing_material.plant_anchor[0]=value)
 material_root_y.value_changed.connect(func(value): editing_material.plant_anchor[1]=value)
 _button(material_land_options,"上传专用选中图（可选）",func():
  _open_image_dialog("selected"))
 _button(material_land_options,"改用自动提亮选中态",func():
  editing_material.selected_texture=""
  _sync_material_previews())
 material_selected_label=_label(material_land_options,"")
 var previews=HBoxContainer.new()
 material_land_options.add_child(previews)
 for caption in ["正常","选中"]:
  var box=VBoxContainer.new()
  box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  previews.add_child(box)
  _label(box,caption)
  var image=TextureRect.new()
  image.custom_minimum_size=Vector2(200,120)
  image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
  image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  box.add_child(image)
  if caption=="正常":
   material_normal_preview=image
  else:
   material_selected_preview=image
 var note=_label(column,"素材属性作为以后新增对象的默认值。\n修改地图中已有对象，请先在画布中选中它。\n自定义轮廓依赖透明背景；水域标记独立保存。")
 note.add_theme_font_size_override("font_size",12)
 material_error=_label(dialog_body,"")
 material_error.custom_minimum_size=Vector2(550,48)
 material_error.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 material_error.add_theme_color_override("font_color",Color("a54232"))
 material_dialog.confirmed.connect(func():
  if editing_material.type=="light":
   if not editing_material.has("fixture"): editing_material.fixture=MapLightFixture.defaults()
   var day=Image.load_from_file(str(editing_material.texture))
   if day!=null: editing_material.sprite_aspect=day.get_width()/float(day.get_height())
   var error=MapLightFixture.texture_error(editing_material)
   if not error.is_empty():
    material_error.text=error
    return
  if not fixture_target_key.is_empty():
   var target=canvas.record(fixture_target_key)
   if target.is_empty() or canvas.is_locked(fixture_target_key):
    material_error.text="地图对象已移除或锁定，无法保存。"
    return
   remember()
   for key in ["texture","night_texture","fixture","sprite_aspect"]: target[key]=editing_material[key].duplicate(true) if editing_material[key] is Dictionary else editing_material[key]
   target.height=float(editing_material.display_height)
   changed()
   material_dialog.hide()
   status.text="灯具贴图、锚点与光照已更新，请保存并应用项目。"
   return
  editing_material.animation=MapMaterialSpec.animation_for(editing_material.type,editing_material.motion_enabled)
  if editing_material.type!="light":
   editing_material.erase("fixture")
   editing_material.erase("night_texture")
  var result=MapLayoutStore.save_material(editing_material)
  if result!=OK:
   status.text="素材属性保存失败："+error_string(result)
   material_error.text=status.text
   return
  material_dialog.hide()
  var id=editing_material.id
  material_category.select(maxi(0,MapMaterialSpec.TYPES.find(editing_material.type)))
  reload_library()
  for i in materials.size():
   if materials[i].id==id:
    material_list.select(i)
  status.text="素材默认属性已保存；可新增到地图，已有对象请选中后修改。")

func edit_material() -> void:
 var indices=material_list.get_selected_items()
 if indices.is_empty():
  status.text="请先在素材库选择图片。"
  return
 editing_material=materials[indices[0]].duplicate(true)
 fixture_target_key=""
 fixture_source_index=0
 material_type.disabled=true
 material_error.text=""
 material_dialog.title="素材属性（保存到素材库）"
 if editing_material.has("builtin"):
  status.text="内置素材可直接添加或定位；需要修改贴图时，请在对应分类导入自己的图片。"
  return
 var registered=false
 for entry in MapLayoutStore.library():
  if str(entry.id)==str(editing_material.id): registered=true
 if not registered:
  status.text="此素材为地图独立配置，请选中右侧对象修改；可重新导入图片建立可复用资源。"
  return
 _sync_material_controls()
 material_dialog.popup_centered()

func _build_fixture_controls(parent: Node) -> void:
 material_fixture_options=VBoxContainer.new()
 parent.add_child(material_fixture_options)
 _label(material_fixture_options,"灯具：白天 / 夜间两张贴图均为必填")
 fixture_source=OptionButton.new()
 material_fixture_options.add_child(fixture_source)
 fixture_source.item_selected.connect(func(index): fixture_source_index=index; _sync_fixture_controls())
 var actions=HBoxContainer.new()
 material_fixture_options.add_child(actions)
 _button(actions,"添加光源",func(): _add_fixture_source(false))
 _button(actions,"复制光源",func(): _add_fixture_source(true))
 _button(actions,"删除光源",_delete_fixture_source)
 _button(material_fixture_options,"上传白天图（关灯外观）",func(): _open_image_dialog("fixture_day"))
 _button(material_fixture_options,"上传夜间图（开灯外观）",func(): _open_image_dialog("fixture_night"))
 fixture_night_label=_label(material_fixture_options,"")
 var night=CheckBox.new()
 night.text="预览夜间贴图"
 material_fixture_options.add_child(night)
 night.toggled.connect(func(value): fixture_canvas.show_night=value; fixture_canvas.queue_redraw())
 fixture_canvas=MapFixtureCanvas.new()
 fixture_canvas.custom_minimum_size=Vector2(440,230)
 material_fixture_options.add_child(fixture_canvas)
 fixture_canvas.anchor_changed.connect(func(value):
  fixture_x.set_value_no_signal(value.x)
  fixture_y.set_value_no_signal(value.y))
 _label(material_fixture_options,"点击或拖动锚点，光源可移到图片外；也可输入坐标。白天与夜间贴图应对齐。")
 fixture_x=_spin(material_fixture_options,"发光锚点 X（0～1 图片内，可超出）",-10000,10000,.01)
 fixture_y=_spin(material_fixture_options,"发光锚点 Y（0～1 图片内，可超出）",-10000,10000,.01)
 fixture_x.value_changed.connect(func(value):
  _fixture_settings().anchor[0]=value
  fixture_canvas.queue_redraw())
 fixture_y.value_changed.connect(func(value):
  _fixture_settings().anchor[1]=value
  fixture_canvas.queue_redraw())
 fixture_kind=OptionButton.new()
 for label in ["发散光 · 灯笼 / 灯泡","筒光 · 车灯 / 手电","直射光 · 大范围补光"]: fixture_kind.add_item(label)
 material_fixture_options.add_child(fixture_kind)
 fixture_kind.item_selected.connect(func(index):
  _fixture_settings().kind=["point","spot","directional"][index]
  _sync_fixture_controls())
 fixture_angle=_spin(material_fixture_options,"光照方向（0°向右，90°向下）",-360,360,1)
 fixture_angle.value_changed.connect(func(value): _fixture_settings().angle=value; fixture_canvas.queue_redraw())
 fixture_aperture=_spin(material_fixture_options,"筒光夹角（度）",5,175,1)
 fixture_aperture.value_changed.connect(func(value): _fixture_settings().aperture=value; fixture_canvas.queue_redraw())
 fixture_range=_spin(material_fixture_options,"照射范围（逻辑像素，跟随素材缩放）",12,1600,1)
 fixture_range.value_changed.connect(func(value): _fixture_settings().range=value)
 fixture_energy=_spin(material_fixture_options,"光照亮度",0,4,.05)
 fixture_energy.value_changed.connect(func(value): _fixture_settings().energy=value)
 fixture_color=ColorPickerButton.new()
 fixture_color.edit_alpha=false
 material_fixture_options.add_child(fixture_color)
 fixture_color.color_changed.connect(func(value):
  if not syncing: _fixture_settings().color=value.to_html(false))
 for key in ["enabled","night_only","flicker","pass_through_owner"]:
  var check=CheckBox.new()
  check.text={"enabled":"启用光源","night_only":"仅夜间开灯（默认）","flicker":"光照轻微闪动","pass_through_owner":"穿透所属贴图（不照亮本体）"}[key]
  material_fixture_options.add_child(check)
  fixture_checks[key]=check
  check.toggled.connect(func(value): _fixture_settings()[key]=value)

func _fixture_settings() -> Dictionary:
 fixture_source_index=clampi(fixture_source_index,0,MapLightFixture.count(editing_material)-1)
 return MapLightFixture.source(editing_material,fixture_source_index)

func _add_fixture_source(copy: bool) -> void:
 var settings=_fixture_settings().duplicate(true) if copy else MapLightFixture.defaults()
 settings.erase("sources")
 var offset=.06*float((MapLightFixture.count(editing_material)%5)+1)
 settings.anchor[0]=float(settings.anchor[0])+offset
 if not editing_material.fixture.has("sources"): editing_material.fixture.sources=[]
 editing_material.fixture.sources.append(settings)
 fixture_source_index=MapLightFixture.count(editing_material)-1
 _sync_fixture_controls()

func _delete_fixture_source() -> void:
 if MapLightFixture.count(editing_material)<=1: return
 if fixture_source_index==0:
  var sources=editing_material.fixture.sources
  var first=sources.pop_front()
  first.sources=sources
  editing_material.fixture=first
 else: editing_material.fixture.sources.remove_at(fixture_source_index-1)
 fixture_source_index=maxi(0,fixture_source_index-1)
 _sync_fixture_controls()

func _sync_fixture_controls() -> void:
 var settings=_fixture_settings()
 fixture_source.clear()
 for i in MapLightFixture.count(editing_material): fixture_source.add_item("光源 %d" % (i+1))
 fixture_source.select(fixture_source_index)
 fixture_canvas.settings=settings
 fixture_canvas.day=ContentCatalog.prepared_texture(str(editing_material.texture),512)
 var night_path=str(editing_material.get("night_texture",""))
 fixture_canvas.night=ContentCatalog.prepared_texture(night_path,512) if not night_path.is_empty() else null
 var texture_error=MapLightFixture.texture_error(editing_material)
 fixture_night_label.text="白天图 / 夜间图已齐全" if texture_error.is_empty() else texture_error
 material_dialog.get_ok_button().disabled=not texture_error.is_empty()
 material_dialog.get_ok_button().tooltip_text="保存素材属性" if texture_error.is_empty() else "无法保存："+texture_error
 material_error.text="" if texture_error.is_empty() else "无法保存："+texture_error
 fixture_x.set_value_no_signal(float(settings.anchor[0]))
 fixture_y.set_value_no_signal(float(settings.anchor[1]))
 var kind=str(settings.kind)
 fixture_kind.select(maxi(0,["point","spot","directional"].find(kind)))
 fixture_angle.set_value_no_signal(float(settings.angle))
 fixture_angle.editable=kind!="point"
 fixture_aperture.set_value_no_signal(float(settings.aperture))
 fixture_aperture.editable=kind=="spot"
 fixture_range.set_value_no_signal(float(settings.range))
 fixture_range.editable=kind!="directional"
 fixture_energy.set_value_no_signal(float(settings.energy))
 var old_syncing=syncing
 syncing=true
 fixture_color.color=Color(str(settings.color))
 syncing=old_syncing
 for key in fixture_checks: fixture_checks[key].set_pressed_no_signal(bool(settings.get(key,false)))
 fixture_canvas.queue_redraw()

func _edit_fixture_instance() -> void:
 var entry=canvas.record(selection)
 if entry.is_empty() or canvas.is_locked(selection) or selection_keys.size()!=1: return
 fixture_target_key=selection
 fixture_source_index=0
 editing_material=MapMaterialSpec.normalize(entry)
 editing_material.display_height=float(entry.height)
 if not editing_material.has("fixture"): editing_material.fixture=MapLightFixture.defaults()
 material_type.disabled=true
 material_error.text=""
 material_dialog.title="编辑地图灯具 · 只修改当前对象"
 _sync_material_controls()
 material_dialog.popup_centered()

func _sync_material_controls() -> void:
 material_dialog.get_ok_button().disabled=false
 material_dialog.get_ok_button().tooltip_text="保存素材属性"
 material_error.text=""
 material_type.select(MapMaterialSpec.TYPES.find(editing_material.type))
 material_land_options.visible=editing_material.type=="land"
 material_water_options.visible=editing_material.type=="water"
 material_fixture_options.visible=editing_material.type=="light"
 var background=editing_material.type=="background"
 _show_labeled_field(material_height,not background)
 material_background_note.visible=background
 material_motion.visible=not background
 if editing_material.type=="light":
  if not editing_material.has("fixture"): editing_material.fixture=MapLightFixture.defaults()
  _sync_fixture_controls()
 material_motion.disabled=not MapMaterialSpec.can_animate(editing_material.type)
 material_motion.set_pressed_no_signal(bool(editing_material.motion_enabled))
 material_height.set_value_no_signal(float(editing_material.display_height))
 material_shape.select(maxi(0,MapMaterialSpec.SHAPES.find(editing_material.shape)))
 material_highlight.set_value_no_signal(float(editing_material.highlight))
 material_root_x.set_value_no_signal(float(editing_material.plant_anchor[0]))
 material_root_y.set_value_no_signal(float(editing_material.plant_anchor[1]))
 _sync_material_previews()

func _show_labeled_field(control: Control,show: bool) -> void:
 control.visible=show
 var index=control.get_index()
 if index>0:
  var label=control.get_parent().get_child(index-1)
  if label is Label: label.visible=show

func _sync_material_previews() -> void:
 if editing_material.is_empty():
  return
 material_normal_preview.texture=ContentCatalog.prepared_texture(editing_material.texture,384)
 var path=str(editing_material.selected_texture)
 material_selected_preview.texture=ContentCatalog.prepared_texture(path,384) if not path.is_empty() else material_normal_preview.texture
 material_selected_label.text="已上传专用选中图" if not path.is_empty() else "自动提亮，保留透明背景"
 var mat=ShaderMaterial.new()
 mat.shader=load("res://assets/shaders/map_material_preview.gdshader")
 mat.set_shader_parameter("highlight",float(editing_material.highlight) if path.is_empty() else 0.0)
 material_selected_preview.material=mat

func _edit_water(library: bool) -> void:
 var entry=editing_material if library else canvas.record(selection)
 if entry.is_empty(): return
 if not FileAccess.file_exists(str(entry.texture)):
  status.text="图片文件缺失，无法标记水面。"
  return
 var key=selection
 var window=WaterMaskWindow.new()
 if library:
  material_dialog.add_child(window)
 else:
  add_child(window)
 window.initialize(str(entry.texture),entry.get("water",{}).duplicate(true),theme)
 window.saved.connect(func(settings):
  if library:
   editing_material.water=settings
   status.text="水面标记已生成，请点击保存素材属性。"
  else:
   var target=canvas.record(key)
   if not target.is_empty():
    remember()
    target.water=settings
    changed()
    status.text="此处水面标记已更新，请保存项目并应用到桌面。")
 window.popup_centered()

func _plot_index(key: String) -> int:
 for i in draft.plots.size():
  if str(draft.plots[i].id)==key:
   return i
 return -1

func _refresh_water_preview() -> void:
 if water_preview==null: return
 var signature=JSON.stringify(draft.get("water_region",{}))+str(draft.get("scene_mode","reference"))
 if str(water_preview.get_meta("signature",""))==signature: return
 water_preview.set_meta("signature",signature)
 var mask=MapWaterRegion.image(draft)
 water_preview.texture=MapWaterRegion.preview(mask)
 canvas.water_marker=water_preview.texture

func _edit_map_water() -> void:
 # Capture only the map rectangle as drawing guidance. No crop sprites, light
 # anchors, selection handles or marker overlay are included in this preview.
 var viewport=SubViewport.new()
 viewport.size=Vector2i(1024,576)
 viewport.transparent_bg=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 add_child(viewport)
 var map_canvas=MapEditorCanvas.new()
 map_canvas.size=Vector2(1024,576)
 map_canvas.draft=draft.duplicate(true)
 map_canvas.show_lights=false
 viewport.add_child(map_canvas)
 await RenderingServer.frame_post_draw
 var image=viewport.get_texture().get_image()
 viewport.queue_free()
 var window=WaterMaskWindow.new()
 add_child(window)
 window.initialize("",draft.get("water_region",{}).duplicate(true),theme,image,MapWaterRegion.image(draft))
 window.saved.connect(func(settings):
  remember()
  draft.water_region=settings
  water_visibility.set_pressed_no_signal(true)
  canvas.show_water_marker=true
  changed()
  status.text="地图水域标记已更新；保存并应用后，水流和涟漪按此范围显示。")
 window.popup_centered()

func add_light() -> void:
 remember()
 var light={"id":"light-%d" % Time.get_ticks_usec(),"kind":"point","position":[960,540],"radius":[160.0/1920,160.0/1080],"energy":.7,"angle":90.0,"aperture":60.0,"color":"ffb45c","night_only":true,"enabled":true,"flicker":false}
 draft.lights.append(light)
 selection="light:%d" % (draft.lights.size()-1)
 selection_keys=[selection]
 show_layer_list=false
 changed()
 status.text="已添加单独光源；在右侧调整类型、亮度、范围和擦除区域。"

func _set_record_position(key: String,position: Vector2) -> void:
 var entry=canvas.record(key)
 if key.begins_with("light:"): MapLightFixture.set_light_position(draft,entry,position)
 else: entry.position=[position.x,position.y]

func _build_light_controls() -> void:
 light_controls=VBoxContainer.new()
 inspector.add_child(light_controls)
 _label(light_controls,"灯光组件")
 light_binding_label=_label(light_controls,"")
 light_binding_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 _button(light_controls,"擦除 / 恢复此光源照明",_edit_light_paint)
 light_kind=OptionButton.new()
 for name in ["发散光","筒光 / 聚光","直射光"]:
  light_kind.add_item(name)
 light_controls.add_child(light_kind)
 light_kind.item_selected.connect(func(index): edit_property("kind",["point","spot","directional"][index]))
 light_angle=_spin(light_controls,"方向角（度）",-360,360,1)
 light_angle.value_changed.connect(func(value): edit_property("angle",value))
 light_aperture=_spin(light_controls,"光束夹角（度）",5,175,1)
 light_aperture.value_changed.connect(func(value): edit_property("aperture",value))
 light_range=_spin(light_controls,"照射范围（逻辑像素）",12,1600,1)
 light_range.value_changed.connect(func(value):
  if syncing or canvas.is_locked(selection) or selection_keys.size()>1:
   return
  remember()
  var entry=canvas.record(selection)
  entry.radius=[value/1920,value/1080]
  changed())
 light_energy=_spin(light_controls,"亮度",0,4,.05)
 light_energy.value_changed.connect(func(value): edit_property("energy",value))
 light_color=ColorPickerButton.new()
 light_color.edit_alpha=false
 light_controls.add_child(light_color)
 light_color.color_changed.connect(func(color): edit_property("color",color.to_html(false)))
 for key in ["enabled","night_only","flicker","pass_through_owner"]:
  var check=CheckBox.new()
  check.text={"enabled":"启用灯光","night_only":"仅夜间开启","flicker":"轻微闪动","pass_through_owner":"穿透所属贴图（不照亮本体）"}[key]
  light_controls.add_child(check)
  check.toggled.connect(func(value): edit_property(key,value))
  match key:
   "enabled": light_enabled=check
   "night_only": light_night=check
   "flicker": light_flicker=check

func _sync_light_controls(entry: Dictionary) -> void:
 light_binding_label.text="绑定：%s\n随素材移动、缩放；移动光源调整相对位置。" % _light_parent_name(entry) if not str(entry.get("parent_key","")).is_empty() else "地图光源 · 独立摆放"
 var kind=str(entry.get("kind","point"))
 light_kind.select(maxi(0,["point","spot","directional"].find(kind)))
 light_angle.set_value_no_signal(float(entry.get("angle",90)))
 light_angle.editable=kind!="point"
 light_aperture.set_value_no_signal(float(entry.get("aperture",60)))
 light_aperture.editable=kind=="spot"
 light_range.set_value_no_signal(float(entry.radius[0])*1920)
 light_range.editable=kind!="directional"
 light_energy.set_value_no_signal(float(entry.energy))
 light_color.color=Color(str(entry.get("color","ffb45c")))
 light_enabled.set_pressed_no_signal(bool(entry.get("enabled",true)))
 light_night.set_pressed_no_signal(bool(entry.get("night_only",true)))
 light_flicker.set_pressed_no_signal(bool(entry.get("flicker",false)))

func _save_thumbnail() -> void:
 await RenderingServer.frame_post_draw
 if not visible or not is_instance_valid(canvas):
  return
 var image=get_texture().get_image()
 var rect=canvas.canvas_rect()
 var bounds=Rect2i(canvas.position+rect.position+canvas.get_parent().global_position,rect.size)
 bounds=bounds.intersection(Rect2i(Vector2i.ZERO,image.get_size()))
 if bounds.size.x<1 or bounds.size.y<1:
  return
 var preview=image.get_region(bounds)
 preview.resize(384,216,Image.INTERPOLATE_BILINEAR)
 preview.save_png(MapProjectStore.directory(project_id).path_join("preview.png"))

func _choose_object_texture(role: String) -> void:
 if role=="light_paint":
  _edit_light_paint()
  return
 if role=="emission_mask":
  _edit_emission_mask()
  return
 if canvas.is_locked(selection): return
 texture_target=selection
 _open_image_dialog(role)

func _editable_soil() -> Dictionary:
 var entry=canvas.record(selection)
 if not entry.has("surface"):
  var map=MapDefinition.load_map()
  var paths=[]
  for region in map.soil_regions:
   var image=ContentCatalog.prepared_texture(map.soil_atlas,768,region,map.get("soil_edge_cleanup",{})).get_image()
   var path="user://maps/materials/soil-"+image.get_data().hex_encode().sha256_text()+".png"
   DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
   image.save_png(path)
   paths.append(path)
  var extent=canvas.plot_size(draft.plots.find(entry),1.0)
  entry.surface={"texture":paths[0],"selected_texture":"","width":extent.x,"height":extent.y,"shape":"square","highlight":.12,"plant_anchor":[.5,.5]}
 return entry.surface

func _fixture_operation(kind: String,value: Variant) -> void:
 var entry=canvas.record(selection)
 if not entry.has("fixture") or canvas.is_locked(selection): return
 remember()
 var index=inline_fixture.index
 if kind=="night_brightness":
  entry.fixture.night_brightness=value
 elif kind in ["anchor_x","anchor_y"]:
  MapLightFixture.source(entry,index).anchor[0 if kind=="anchor_x" else 1]=value
 elif kind=="add" or kind=="copy":
  var settings=MapLightFixture.source(entry,index).duplicate(true) if kind=="copy" else MapLightFixture.defaults()
  settings.erase("sources")
  settings.anchor[0]=float(settings.anchor[0])+.06
  if not entry.fixture.has("sources"): entry.fixture.sources=[]
  entry.fixture.sources.append(settings)
  inline_fixture.index=MapLightFixture.count(entry)-1
 elif kind=="delete":
  if MapLightFixture.count(entry)<=1: return
  if index==0:
   var sources=entry.fixture.sources
   var first=sources.pop_front()
   first.sources=sources
   entry.fixture=first
  else: entry.fixture.sources.remove_at(index-1)
  inline_fixture.index=maxi(0,index-1)
 else: MapLightFixture.source(entry,index)[kind]=value
 changed()

func _light_parent_name(light: Dictionary) -> String:
 var key=str(light.get("parent_key",""))
 if key=="willow": return "河边柳树"
 if key.begins_with("plot-"): return "田块 %02d" % (_plot_index(key)+1)
 var parent=canvas.record(key)
 return str(parent.get("name",key))

func _edit_emission_mask() -> void:
 var key=selection
 var entry=canvas.record(key)
 if not entry.has("fixture") or canvas.is_locked(key): return
 var photo=ContentCatalog.prepared_texture(entry.night_texture,512).get_image()
 if photo.is_compressed(): photo.decompress()
 var initial=Image.create(photo.get_width(),photo.get_height(),false,Image.FORMAT_L8)
 initial.fill(Color.BLACK)
 var day=ContentCatalog.prepared_texture(entry.texture,512).get_image()
 if day.is_compressed(): day.decompress()
 day.resize(photo.get_width(),photo.get_height())
 for y in photo.get_height():
  for x in photo.get_width():
   var value=MapLightFixture.emission(day.get_pixel(x,y),photo.get_pixel(x,y))
   initial.set_pixel(x,y,Color(value,value,value))
 var window=WaterMaskWindow.new()
 add_child(window)
 window.initialize("",{"mask":entry.get("emission_mask","")},theme,photo,initial)
 window.title="标记自发光区域 · 只涂灯芯和灯罩内部"
 window.canvas.show_direction=false
 for spin in [window.angle,window.speed,window.feather]:
  spin.visible=false
  spin.get_parent().get_child(spin.get_index()-1).visible=false
 for control in window.angle.get_parent().get_children():
  if control is Button and control.text.contains("保存"): control.text="保存发光区域"
 window.status.text="蓝色区域保持发光，其余本体随夜间环境变暗。初始为暖色亮起部分的自动估计，可用画笔补充或橡皮擦排除。"
 window.saved.connect(func(settings):
  var target=canvas.record(key)
  if target.is_empty() or canvas.is_locked(key): return
  remember()
  target.emission_mask=settings.mask
  changed())
 window.popup_centered()

func _edit_light_paint() -> void:
 var key=selection
 var entry=canvas.record(key)
 if entry.is_empty() or canvas.is_locked(key) or selection_keys.size()!=1: return
 var fixture=entry.has("fixture")
 if not fixture and not key.begins_with("light:"): return
 var index=inline_fixture.index if fixture else 0
 var settings=MapLightFixture.source(entry,index) if fixture else entry
 var emitter=MapLightFixture.emitter(entry,index) if fixture else MapLightFixture.resolve_light(draft,entry)
 var binding=MapLightFixture.binding_transform(draft,str(entry.get("parent_key",""))) if not fixture else {}
 # Bake the scene and all OTHER light sources as a preview background. Keep
 # this fixture's lit image visible; only suppress its selected light's pool.
 var preview_layout=draft.duplicate(true)
 var owner=preview_layout.lights[int(key.trim_prefix("light:"))] if not fixture else {}
 if fixture:
  for object in preview_layout.objects:
   if str(object.id)==key: owner=object; break
  if owner.is_empty(): return
  MapLightFixture.source(owner,index).energy=0.0
 else: owner.energy=0.0
 var viewport=SubViewport.new()
 viewport.size=Vector2i(768,432)
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 add_child(viewport)
 var preview=MapEditorCanvas.new()
 preview.size=Vector2(768,432)
 preview.draft=preview_layout
 preview.night=true
 preview.show_lights=false
 viewport.add_child(preview)
 await RenderingServer.frame_post_draw
 await RenderingServer.frame_post_draw
 var photo=viewport.get_texture().get_image()
 viewport.queue_free()
 # The editor may have closed or changed selection while rendering the image.
 if not visible or canvas.record(key).is_empty(): return
 var initial=MapLightFixture.paint_image(emitter,photo.get_size())
 emitter.energy=float(settings.get("energy",.7))
 emitter._paint_opacity=float(entry.get("opacity",1)) if fixture else float(binding.get("opacity",1))
 emitter._paint_scale=float(entry.get("scale",1)) if fixture else float(binding.get("scale",1))
 var window=LightPaintWindow.new()
 add_child(window)
 window.initialize(photo,initial,emitter,theme)
 window.saved.connect(func(result):
  var target=canvas.record(key)
  if target.is_empty() or canvas.is_locked(key): return
  if fixture and (not target.has("fixture") or index>=MapLightFixture.count(target)): return
  remember()
  var light=MapLightFixture.source(target,index) if fixture else target
  light.paint_mask=result.paint_mask
  var frame=result.paint_frame
  if fixture:
   var scale=float(target.scale)
   light.paint_frame=[(float(frame[0])-float(target.position[0]))/scale,(float(frame[1])-float(target.position[1]))/scale,float(frame[2])/scale,float(frame[3])/scale]
   light.paint_angle=-rad_to_deg(MapMaterialSpec.rotation(target))
   light.range=float(result.radius[0])*1920/scale
  else:
   var parent=MapLightFixture.binding_transform(draft,str(target.get("parent_key","")))
   if parent.is_empty():
    light.paint_frame=frame
    light.radius=result.radius
    light.paint_angle=0.0
   else:
    var scale=float(parent.scale)
    var origin=parent.position as Vector2
    light.paint_frame=[(float(frame[0])-origin.x)/scale,(float(frame[1])-origin.y)/scale,float(frame[2])/scale,float(frame[3])/scale]
    light.paint_angle=-rad_to_deg(float(parent.get("rotation",0)))
    light.radius=[float(result.radius[0])/scale,float(result.radius[1])/scale]
  light.energy=result.energy
  light.color=result.color
  changed()
  status.text="当前光源的擦除记录已更新；保存项目并应用到桌面后生效。")
 window.popup_centered()
