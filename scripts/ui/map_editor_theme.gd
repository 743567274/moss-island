class_name MapEditorTheme
extends RefCounted

const INK=Color("263d34")
const MUTED=Color("536557")
const PAPER=Color("f7f2e5")
const FIELD=Color("fffdf5")
const BORDER=Color("b6b69e")
const ACCENT=Color("49664c")

static func box(color: Color,padding: int=10,radius: int=7) -> StyleBoxFlat:
 var style=StyleBoxFlat.new()
 style.bg_color=color
 style.border_color=BORDER
 style.set_border_width_all(1)
 style.set_corner_radius_all(radius)
 for side in ["left","right","top","bottom"]:
  style.set("content_margin_"+side,padding)
 return style

static func create(base: Theme) -> Theme:
 # Keep the farm's font, but isolate editor colors from the desktop HUD.
 var theme=base.duplicate(true) as Theme
 for type in ["Label","RichTextLabel","AcceptDialog","ConfirmationDialog","Window","PopupMenu","TooltipLabel","LineEdit","TextEdit","ItemList","Tree","CheckBox","CheckButton","OptionButton","SpinBox","ColorPicker","ColorPickerButton"]:
  theme.set_color("font_color",type,INK)
  theme.set_color("font_hover_color",type,INK)
  theme.set_color("font_focus_color",type,INK)
  theme.set_color("font_pressed_color",type,INK)
  theme.set_color("font_hover_pressed_color",type,INK)
  theme.set_color("font_disabled_color",type,MUTED)
  theme.set_color("font_selected_color",type,Color.WHITE)
 theme.set_color("default_color","RichTextLabel",INK)
 for type in ["Panel","PanelContainer","PopupPanel","PopupMenu","AcceptDialog","ConfirmationDialog","ColorPicker"]:
  theme.set_stylebox("panel",type,box(PAPER,16))
 theme.set_stylebox("hover","PopupMenu",box(Color("dce6d2"),8))
 theme.set_color("font_accelerator_color","PopupMenu",MUTED)
 theme.set_color("font_separator_color","PopupMenu",MUTED)
 theme.set_color("font_outline_color","PopupMenu",Color.TRANSPARENT)

 # Godot's tooltips are virtual theme types, independent of Label/Panel.
 theme.set_stylebox("panel","TooltipPanel",box(Color("fff9e9"),12))
 theme.set_color("font_color","TooltipLabel",INK)
 theme.set_color("font_shadow_color","TooltipLabel",Color.TRANSPARENT)
 theme.set_color("font_outline_color","TooltipLabel",Color.TRANSPARENT)
 theme.set_constant("outline_size","TooltipLabel",0)
 theme.set_font_size("font_size","TooltipLabel",14)

 for type in ["LineEdit","TextEdit"]:
  theme.set_stylebox("normal",type,box(FIELD,8,5))
  var focus=box(FIELD,8,5)
  focus.border_color=ACCENT
  focus.set_border_width_all(2)
  theme.set_stylebox("focus",type,focus)
  theme.set_stylebox("read_only",type,box(Color("e9e8dd"),8,5))
  theme.set_color("caret_color",type,INK)
  theme.set_color("font_placeholder_color",type,MUTED)
  theme.set_color("font_uneditable_color",type,MUTED)
  theme.set_color("selection_color",type,ACCENT)
 for type in ["ItemList","Tree"]:
  theme.set_color("font_selected_color",type,INK)
  theme.set_stylebox("panel",type,box(FIELD,6))
  for state in ["selected","selected_focus"]:
   theme.set_stylebox(state,type,box(Color("c9e2ec"),6,4))
  # ItemList draws the keyboard cursor over its text. An opaque cursor hides
  # the selected label even when the foreground color has enough contrast.
  for state in ["cursor","cursor_unfocused"]:
   var cursor=box(Color.TRANSPARENT,6,4)
   cursor.border_color=Color("557888")
   theme.set_stylebox(state,type,cursor)
  theme.set_stylebox("hovered",type,box(Color("e1e8d7"),6,4))
  theme.set_stylebox("hovered_selected",type,box(Color("b8d8e6"),6,4))
  theme.set_color("font_hovered_color",type,INK)
  theme.set_color("font_hovered_selected_color",type,INK)
  theme.set_color("font_outline_color",type,Color.TRANSPARENT)

 # Check marks have no solid pressed background; their text stays dark.
 for type in ["CheckBox","CheckButton"]:
  for state in ["normal","hover","pressed","hover_pressed","disabled"]:
   theme.set_stylebox(state,type,StyleBoxEmpty.new())
 for type in ["Button","OptionButton"]:
  theme.set_stylebox("normal",type,box(Color("edf0e3"),9))
  theme.set_stylebox("hover",type,box(Color("dce6d2"),9))
  theme.set_stylebox("pressed",type,box(ACCENT,9))
  theme.set_stylebox("hover_pressed",type,box(ACCENT,9))
  # Confirmation buttons receive keyboard focus immediately on opening.
  # Focus is drawn over the label, so it must have no opaque fill.
  var focus_ring=box(Color.TRANSPARENT,9)
  focus_ring.border_color=ACCENT
  focus_ring.set_border_width_all(2)
  theme.set_stylebox("focus",type,focus_ring)
  theme.set_stylebox("disabled",type,box(Color("e6e6db"),9))
  theme.set_color("font_color",type,INK)
  theme.set_color("font_hover_color",type,INK)
  theme.set_color("font_pressed_color",type,Color.WHITE)
  theme.set_color("font_hover_pressed_color",type,Color.WHITE)
  theme.set_color("font_focus_color",type,INK)
  theme.set_color("font_outline_color",type,Color.TRANSPARENT)
  theme.set_color("font_disabled_color",type,MUTED)

 theme.set_color("title_color","Window",INK)
 theme.set_stylebox("panel","TabContainer",box(PAPER,5))
 for state in ["tab_selected","tab_unselected","tab_hovered","tab_disabled"]:
  theme.set_stylebox(state,"TabBar",box(FIELD if state=="tab_selected" else Color("e3e7d8"),8,5))
 for color in ["font_selected_color","font_unselected_color","font_hovered_color","font_disabled_color"]:
  theme.set_color(color,"TabBar",MUTED if color=="font_disabled_color" else INK)
 theme.set_font_size("font_size","TabBar",14)
 theme.set_color("title_outline_modulate","Window",Color.TRANSPARENT)
 theme.set_constant("title_outline_size","Window",0)
 for state in ["embedded_border","embedded_unfocused_border"]:
  var border=box(PAPER,12,8)
  border.border_width_top=34
  border.border_color=Color("e5e7d7")
  theme.set_stylebox(state,"Window",border)
 return theme
