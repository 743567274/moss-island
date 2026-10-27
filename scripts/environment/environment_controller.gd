class_name EnvironmentController
extends RefCounted

var solar: Dictionary={}
var effect="clear"
var temperature=20.0
var quality=1
var code=0
var initialized=false
var current={"cloud":0.0,"rain":0.0,"snowfall":0.0,"fog":0.0,"wind":.18,"wetness":0.0,"snow":0.0,"daylight":1.0,"ice":0.0,"wind_x":.98,"wind_z":.2}
var target=current.duplicate()

func submit(sample: Dictionary, weather_code: int, celsius: float, tier: int) -> void:
 solar=sample
 code=weather_code
 effect=WeatherService.effect_type(code)
 temperature=celsius
 quality=tier
 target.cloud=0.0 if effect=="clear" else (.8 if effect=="cloud" else 1.0)
 target.rain=(.95 if code in [65,82,95,96,99] else (.66 if code in [55,63,81] else .38)) if effect=="rain" else 0.0
 target.snowfall=(.95 if code in [75,86] else (.64 if code in [73,85] else .32)) if effect=="snow" else 0.0
 target.fog=.92 if effect=="fog" else (.18 if effect in ["rain","snow"] else .035)
 target.wind=.46 if effect in ["rain","snow"] else .18
 target.daylight=float(sample.daylight)
 # Snowfall is atmospheric only: no frozen river or accumulating white cover.
 target.ice=0.0
 if not initialized:
  for key in ["cloud","rain","snowfall","fog","wind","daylight","ice","wind_x","wind_z"]:
   current[key]=target[key]
  initialized=true

func advance(delta: float) -> void:
 var weight=1.0-exp(-delta/2.3) # Roughly seven seconds to reach 95%.
 for key in ["cloud","rain","snowfall","fog","wind","daylight","ice","wind_x","wind_z"]:
  current[key]=lerpf(current[key],target[key],weight)
 var wet_target=1.0 if current.rain>.05 else 0.0
 current.wetness=move_toward(current.wetness,wet_target,delta/(12.0 if wet_target>0 else 75.0))
 current.snow=0.0

func particle_budget(companion: bool) -> int:
 return roundi([32,80,144][clampi(quality,0,2)]*(.65 if companion else 1.0))

func apply_details(details: Dictionary) -> void:
 if details.has("cloud_cover"):
  target.cloud=clampf(float(details.cloud_cover)/100.0,0,1)
 if details.has("precipitation") and effect=="rain":
  target.rain=clampf(float(details.precipitation)/5.0,.18,1.0)
 if details.has("wind_speed_10m"):
  target.wind=clampf(float(details.wind_speed_10m)/55.0,0.0,1.0)
 if details.has("wind_direction_10m"):
  var direction=Vector2.from_angle(deg_to_rad(float(details.wind_direction_10m)+90))
  target.wind_x=direction.x
  target.wind_z=direction.y
