class_name MapLayerList
extends ItemList

signal reorder_requested(source: String,target: String,below: bool)
signal lock_requested(key: String)
var indicator_y=-1.0
var marker: Line2D
var lock_click_pending=false
var lock_icons={}

func _ready() -> void:
 fixed_icon_size=Vector2i(24,24)
 marker=Line2D.new()
 marker.width=3
 marker.default_color=Color("49664c")
 marker.antialiased=true
 marker.z_index=10
 add_child(marker)
 marker.hide()
 mouse_exited.connect(func(): indicator_y=-1; _refresh_indicator())

func lock_icon(locked: bool) -> Texture2D:
 if lock_icons.has(locked): return lock_icons[locked]
 var color="9a5832" if locked else "426754"
 var shackle="M8 11V8a4 4 0 0 1 8 0v3" if locked else "M8 11V7a4 4 0 0 1 8 0"
 var svg='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><rect x="1" y="1" width="22" height="22" rx="4" fill="#fffaf0"/><g fill="none" stroke="#%s" stroke-width="2" stroke-linecap="round"><path d="%s"/><rect x="6" y="11" width="12" height="9" rx="2"/><path d="M12 15v2"/></g></svg>' % [color,shackle]
 var image=Image.new()
 image.load_svg_from_string(svg)
 lock_icons[locked]=ImageTexture.create_from_image(image)
 return lock_icons[locked]

func _over_lock(at_position: Vector2,index: int) -> bool:
 if index<0: return false
 var rect=_visible_rect(index)
 return at_position.x>=rect.position.x and at_position.x<rect.position.x+30

func _gui_input(event: InputEvent) -> void:
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  if not event.pressed: return
  lock_click_pending=false
  var index=get_item_at_position(event.position,true)
  if not _over_lock(event.position,index): return
  var data=get_item_metadata(index)
  if not data is Dictionary: return
  lock_click_pending=true
  accept_event()
  # Rebuild rows only after ItemList finishes processing this mouse event.
  if data.get("lockable",false): lock_requested.emit.call_deferred(str(data.key))
 elif event is InputEventKey:
  lock_click_pending=false

func _get_drag_data(at_position: Vector2) -> Variant:
 var index=get_item_at_position(at_position,true)
 if index<0 or _over_lock(at_position,index):
  return null
 var data=get_item_metadata(index)
 if not data is Dictionary or not data.get("movable",false):
  return null
 var preview=PanelContainer.new()
 preview.theme=get_window().theme
 var label=Label.new()
 label.text="移动图层 · "+get_item_text(index)
 preview.add_child(label)
 set_drag_preview(preview)
 return {"source_list":get_instance_id(),"key":str(data.key)}

func _can_drop_data(at_position: Vector2,data: Variant) -> bool:
 if not data is Dictionary or data.get("source_list",0)!=get_instance_id():
  return false
 var index=get_item_at_position(at_position,true)
 if index<0:
  indicator_y=-1
  _refresh_indicator()
  return false
 var target=get_item_metadata(index)
 if not target is Dictionary or (not target.get("movable",false) and str(target.get("key",""))!=MapLayerStack.BACKGROUND):
  indicator_y=-1
  _refresh_indicator()
  return false
 var rect=_visible_rect(index)
 var below=at_position.y>rect.get_center().y
 indicator_y=rect.end.y if below else rect.position.y
 _refresh_indicator()
 return str(target.key)!=str(data.key)

func _drop_data(at_position: Vector2,data: Variant) -> void:
 var index=get_item_at_position(at_position,true)
 if index<0:
  return
 var target=get_item_metadata(index)
 var below=at_position.y>_visible_rect(index).get_center().y
 indicator_y=-1
 _refresh_indicator()
 reorder_requested.emit(str(data.key),str(target.key),below)

func _notification(what: int) -> void:
 if what==NOTIFICATION_DRAG_END:
  indicator_y=-1
  _refresh_indicator()

func _refresh_indicator() -> void:
 if not is_instance_valid(marker):
  return
 marker.visible=indicator_y>=0
 if marker.visible:
  var right=size.x-6-(get_v_scroll_bar().size.x if get_v_scroll_bar().visible else 0.0)
  marker.points=PackedVector2Array([Vector2(6,indicator_y),Vector2(right,indicator_y)])

func _visible_rect(index: int) -> Rect2:
 var rect=get_item_rect(index)
 rect.position.y-=get_v_scroll_bar().value
 return rect
