class_name SolarClock
extends RefCounted

# NOAA fractional-year equations. Civil time is explicitly the selected city's time.
# An approximation for ambience (minutes accuracy), not navigation or astronomy.
static func sample(unix_time: float, latitude: float, longitude: float, utc_offset: float) -> Dictionary:
	var local = unix_time + utc_offset * 3600.0
	var date = Time.get_datetime_dict_from_unix_time(int(local))
	var year_start = Time.get_unix_time_from_datetime_dict({"year": date.year, "month": 1, "day": 1})
	var day = floor((local - year_start) / 86400.0) + 1.0
	var hour = date.hour + date.minute / 60.0 + date.second / 3600.0
	var leap = int(date.year)%4==0 and (int(date.year)%100!=0 or int(date.year)%400==0)
	var gamma = TAU / (366.0 if leap else 365.0) * (day - 1.0 + (hour - 12.0) / 24.0)
	var eq = 229.18 * (0.000075 + 0.001868 * cos(gamma) - 0.032077 * sin(gamma) - 0.014615 * cos(2 * gamma) - 0.040849 * sin(2 * gamma))
	var decl = 0.006918 - 0.399912 * cos(gamma) + 0.070257 * sin(gamma) - 0.006758 * cos(2 * gamma) + 0.000907 * sin(2 * gamma) - 0.002697 * cos(3 * gamma) + 0.00148 * sin(3 * gamma)
	var lat = deg_to_rad(latitude)
	var solar_minutes = fposmod(hour * 60.0 + eq + 4 * longitude - 60 * utc_offset, 1440.0)
	var angle = deg_to_rad(solar_minutes / 4.0 - 180.0)
	var altitude = asin(clampf(sin(lat) * sin(decl) + cos(lat) * cos(decl) * cos(angle), -1, 1))
	var azimuth = atan2(sin(angle), cos(angle) * sin(lat) - tan(decl) * cos(lat)) + PI
	var cos_h = (cos(deg_to_rad(90.833)) / (cos(lat) * cos(decl))) - tan(lat) * tan(decl)
	var noon = 720.0 - 4.0 * longitude - eq + utc_offset * 60.0
	var span = rad_to_deg(acos(clampf(cos_h, -1, 1))) * 4.0
	return {"moon":moon_sample(unix_time,latitude,longitude),"hour": hour, "date": date, "altitude": altitude, "azimuth": azimuth,
		"daylight": smoothstep(deg_to_rad(-7), deg_to_rad(20), altitude),
		"sunrise": format_minutes(noon - span), "sunset": format_minutes(noon + span),
		"polar": "极昼" if cos_h < -1 else ("极夜" if cos_h > 1 else "")}

static func format_minutes(minutes: float) -> String:
	var rounded = int(round(minutes))
	return "%02d:%02d" % [posmod(rounded / 60, 24), posmod(rounded, 60)]

# Low precision geocentric lunar orbit, after Paul Schlyter's orbital elements.
# Omits perturbations and topocentric parallax; visual ambience, not an ephemeris.
static func moon_sample(unix_time: float, latitude: float, longitude: float) -> Dictionary:
	var d=unix_time/86400.0-10956.0
	var node=deg_to_rad(fposmod(125.1228-.0529538083*d,360))
	var peri=deg_to_rad(fposmod(318.0634+.1643573223*d,360))
	var anomaly=deg_to_rad(fposmod(115.3654+13.0649929509*d,360))
	var inc=deg_to_rad(5.1454)
	var eccentric=anomaly+.0549*sin(anomaly)*(1+.0549*cos(anomaly))
	for i in 4:
		eccentric-=(eccentric-.0549*sin(eccentric)-anomaly)/(1-.0549*cos(eccentric))
	var v=atan2(sqrt(1-.0549*.0549)*sin(eccentric),cos(eccentric)-.0549)+peri
	var ecliptic=Vector3(cos(node)*cos(v)-sin(node)*sin(v)*cos(inc),sin(node)*cos(v)+cos(node)*sin(v)*cos(inc),sin(v)*sin(inc))
	var obliquity=deg_to_rad(23.4393-.0000003563*d)
	var eq=Vector3(ecliptic.x,ecliptic.y*cos(obliquity)-ecliptic.z*sin(obliquity),ecliptic.y*sin(obliquity)+ecliptic.z*cos(obliquity))
	var ra=atan2(eq.y,eq.x)
	var decl=atan2(eq.z,Vector2(eq.x,eq.y).length())
	var jd=unix_time/86400.0+2440587.5
	var sidereal=deg_to_rad(fposmod(280.46061837+360.98564736629*(jd-2451545.0)+longitude,360))
	var hour_angle=sidereal-ra
	var lat=deg_to_rad(latitude)
	var altitude=asin(sin(lat)*sin(decl)+cos(lat)*cos(decl)*cos(hour_angle))
	var azimuth=atan2(sin(hour_angle),cos(hour_angle)*sin(lat)-tan(decl)*cos(lat))+PI
	var phase=fposmod((jd-2451550.1)/29.530588853,1.0)
	return {"altitude":altitude,"azimuth":azimuth,"phase":phase,"illumination":(1-cos(phase*TAU))*.5}
