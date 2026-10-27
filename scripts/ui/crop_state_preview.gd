class_name CropStatePreview
extends Control
var image: Texture2D
var multiplier=1.0
func _ready() -> void:
 clip_contents=true
 resized.connect(queue_redraw)
func _draw() -> void:
 draw_rect(Rect2(Vector2.ZERO,size),Color("e0e6d9"))
 if image==null: return
 var extent=Vector2(image.get_size())
 var factor=minf(size.x/extent.x,size.y/extent.y)*.9*multiplier
 extent*=factor
 draw_texture_rect(image,Rect2(Vector2(size.x*.5-extent.x*.5,size.y*.94-extent.y),extent),false)
