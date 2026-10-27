class_name MapWaterRegion
extends RefCounted

# The mask is a map-space annotation, never a renderable scene object.
static func image(layout: Dictionary) -> Image:
 var settings=layout.get("water_region",{})
 var path=str(settings.get("mask",""))
 if not path.is_empty() and FileAccess.file_exists(path):
  var loaded=Image.load_from_file(path)
  if loaded!=null:
   loaded.convert(Image.FORMAT_L8)
   return loaded
 var mask=Image.create(512,288,false,Image.FORMAT_L8)
 mask.fill(Color.BLACK)
 if layout.has("water_region") or str(layout.get("scene_mode","reference"))=="blank": return mask
 var water=MapDefinition.load_map().water
 for y in 288:
  for x in 512:
   var p=Vector2((x+.5)/512,(y+.5)/288)
   var exclusion=water.bridge_exclusion
   if p.x>=exclusion[0] and p.x<=exclusion[2] and p.y>=exclusion[1] and p.y<=exclusion[3]: continue
   var coverage=0.0
   for i in water.points.size()-1:
    var a=Vector2(water.points[i][0],water.points[i][1])
    var b=Vector2(water.points[i+1][0],water.points[i+1][1])
    var t=clampf((p-a).dot(b-a)/maxf(.00001,(b-a).length_squared()),0,1)
    var width=lerpf(water.widths[i],water.widths[i+1],t)
    coverage=maxf(coverage,1-smoothstep(width*.72,width,p.distance_to(a.lerp(b,t))))
   if coverage>0: mask.set_pixel(x,y,Color(coverage,coverage,coverage))
 return mask

static func preview(mask: Image) -> ImageTexture:
 var colored=Image.create(mask.get_width(),mask.get_height(),false,Image.FORMAT_RGBA8)
 for y in mask.get_height():
  for x in mask.get_width(): colored.set_pixel(x,y,Color(.12,.60,.87,mask.get_pixel(x,y).r*.7))
 return ImageTexture.create_from_image(colored)
