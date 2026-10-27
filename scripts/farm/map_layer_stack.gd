class_name MapLayerStack
extends RefCounted

const BACKGROUND="__background"

# Storage order is bottom -> top, just like the runtime depth order. The UI
# reverses it so the first visible row is the frontmost image layer.
static func entries(layout: Dictionary) -> Array:
 var defaults=[{"key":BACKGROUND,"kind":"background","index":0,"rank":-2,"y":0.0}]
 for i in layout.get("objects",[]).size():
  var item=layout.objects[i]
  var type=str(item.get("type","decoration"))
  var rank={"background":-1,"cloud":0,"ground":1,"water":2}.get(type,5)
  defaults.append({"key":str(item.id),"kind":"object","index":i,"rank":rank,"y":float(item.position[1])})
 for i in layout.get("plots",[]).size():
  defaults.append({"key":str(layout.plots[i].id),"kind":"plot","index":i,"rank":9,"y":float(i)})
 if not layout.get("willow",{}).is_empty() and str(layout.get("scene_mode","reference"))!="blank":
  defaults.append({"key":"willow","kind":"willow","index":0,"rank":4,"y":0.0})
 defaults.sort_custom(func(a,b):
  if int(a.rank)!=int(b.rank):
   return int(a.rank)<int(b.rank)
  if not is_equal_approx(float(a.y),float(b.y)):
   return float(a.y)<float(b.y)
  return str(a.key)<str(b.key))
 var lookup={}
 for entry in defaults:
  lookup[entry.key]=entry
 var result=[]
 var used={}
 if not layout.get("layer_order",[]).has(BACKGROUND):
  result.append(lookup[BACKGROUND])
  used[BACKGROUND]=true
 for key in layout.get("layer_order",[]):
  if lookup.has(str(key)) and not used.has(str(key)):
   result.append(lookup[str(key)])
   used[str(key)]=true
 for entry in defaults:
  if not used.has(entry.key):
   result.append(entry)
 return result

static func keys(layout: Dictionary) -> Array:
 var result=[]
 for entry in entries(layout):
  result.append(entry.key)
 return result

static func depths(layout: Dictionary) -> Dictionary:
 var result={}
 var stack=entries(layout)
 for i in stack.size():
  # Everything remains in front of the plate (.50), below rain/snow (2.0).
  # Each field reserves a small gap for its crop sprites above its soil.
  result[stack[i].key]=.62+i*.003
 return result

static func reordered(layout: Dictionary,source: String,target: String,below: bool) -> Array:
 var order=keys(layout)
 if source==target or not order.has(source) or (target!=BACKGROUND and not order.has(target)):
  return order
 order.erase(source)
 var index=order.find(target)
 order.insert(index if below else index+1,source)
 return order

static func is_background(layout: Dictionary,key: String) -> bool:
 for item in layout.get("objects",[]):
  if str(item.id)==key: return str(item.get("type",""))=="background"
 return false
