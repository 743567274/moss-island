class_name RegionCatalog
extends RefCounted

static var provinces: Array=[]
static var cities: Array=[]
static var counties: Array=[]
static var records: Dictionary={}
static var children: Dictionary={}

static func load_catalog() -> void:
 if not records.is_empty():
  return
 var parsed=JSON.parse_string(FileAccess.get_file_as_string("res://data/china_regions.json"))
 if not parsed is Dictionary or not parsed.has_all(["provinces","cities","counties"]):
  push_error("County catalog is missing or invalid")
  return
 provinces=parsed.provinces
 cities=parsed.cities
 counties=parsed.counties
 for item in provinces+cities+counties:
  records[item.code]=item
  var parent=str(item.get("city",item.get("province","")))
  if not children.has(parent):
   children[parent]=[]
  children[parent].append(item)

static func get_region(code: String) -> Dictionary:
 load_catalog()
 return records.get(code,{})

static func child_regions(code: String) -> Array:
 load_catalog()
 return children.get(code,[])

static func first_county(code: String) -> String:
 for item in child_regions(code):
  if item.has("available") and item.available:
   return str(item.code)
  var nested=first_county(str(item.code))
  if not nested.is_empty():
   return nested
 return ""

static func find_city(name: String) -> String:
 load_catalog()
 for item in cities:
  if item.name==name or str(item.name).trim_suffix("市")==name:
   return str(item.code)
 return ""

static func path_label(code: String) -> String:
 var item=get_region(code)
 if item.is_empty():
  return ""
 return "%s / %s / %s" % [get_region(item.province).name,get_region(item.city).name,item.name]

static func wgs_to_gcj(lon: float,lat: float) -> Vector2:
 if lon<72.004 or lon>137.8347 or lat<.8293 or lat>55.8271:
  return Vector2(lon,lat)
 var x=lon-105.0
 var y=lat-35.0
 var dl=-100+2*x+3*y+.2*y*y+.1*x*y+.2*sqrt(absf(x))
 var dn=300+x+2*y+.1*x*x+.1*x*y+.1*sqrt(absf(x))
 var wave=(20*sin(6*x*PI)+20*sin(2*x*PI))*2/3.0
 dl+=wave+(20*sin(y*PI)+40*sin(y*PI/3))*2/3.0
 dl+=(160*sin(y*PI/12)+320*sin(y*PI/30))*2/3.0
 dn+=wave+(20*sin(x*PI)+40*sin(x*PI/3))*2/3.0
 dn+=(150*sin(x*PI/12)+300*sin(x*PI/30))*2/3.0
 var rad=deg_to_rad(lat)
 var magic=1-.006693421622965943*pow(sin(rad),2)
 var root=sqrt(magic)
 return Vector2(lon+dn*180/(6378245/root*cos(rad)*PI),lat+dl*180/(6378245*(1-.006693421622965943)/(magic*root)*PI))

static func resolve_coordinate(lat: float,lon: float,accuracy_m: float=0.0) -> Dictionary:
 if not is_finite(lat) or not is_finite(lon) or not is_finite(accuracy_m) or absf(lat)>90 or absf(lon)>180 or accuracy_m<0:
  return {"ok":false,"reason":"invalid"}
 load_catalog()
 var point=wgs_to_gcj(lon,lat)
 var metre_scale=Vector2(111320*cos(deg_to_rad(lat)),111320)
 for county in counties:
  if not county.get("available",false):
   continue
  var box=county.bounds
  if point.x<float(box[0]) or point.x>float(box[2]) or point.y<float(box[1]) or point.y>float(box[3]):
   continue
  var file=FileAccess.open("res://data/regions/%s.bin" % county.province,FileAccess.READ)
  if file==null or file.get_buffer(4).get_string_from_ascii()!="RGN1":
   return {"ok":false,"reason":"missing_boundary"}
  file.seek(int(county.offset))
  for polygon_index in file.get_32():
   var inside=false
   var clearance=INF
   for ring_index in file.get_32():
    var size=file.get_32()
    var buffer=file.get_buffer(size*8).to_float32_array()
    var ring=PackedVector2Array()
    ring.resize(size)
    for i in size:
     ring[i]=Vector2(buffer[i*2],buffer[i*2+1])
    var hit=Geometry2D.is_point_in_polygon(point,ring)
    if ring_index==0:
     inside=hit
    elif hit:
     inside=false
    if inside:
     for i in size-1:
      var nearest=Geometry2D.get_closest_point_to_segment(point*metre_scale,ring[i]*metre_scale,ring[i+1]*metre_scale)
      clearance=minf(clearance,(point*metre_scale).distance_to(nearest))
   if inside:
    # The horizontal uncertainty circle must fit within this county. Do not
    # mislabel a city/IP-sized fix, or a fix straddling an administrative border.
    return {"ok":clearance>accuracy_m+20,"reason":"boundary" if clearance<=accuracy_m+20 else "matched","county_code":str(county.code),"clearance_m":clearance,"accuracy_m":accuracy_m}
 return {"ok":false,"reason":"outside_catalog"}
