"""Build the offline county catalog and indexed province boundary files.

Inputs are archived under tools/reference/china-regions, never shipped at runtime.
Run with shapely and opencc-python-reimplemented installed in pydeps there.
"""
import csv
import hashlib
import json
import math
import struct
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'tools/reference/china-regions'
sys.path.insert(0, str(SOURCE / 'pydeps'))
from shapely.geometry import Polygon, MultiPolygon, Point, shape
from shapely.ops import transform
from shapely import make_valid
from opencc import OpenCC

csv.field_size_limit(200_000_000)
def read_csv(name):
    with (SOURCE / name).open(encoding='utf-8-sig', newline='') as file:
        return list(csv.DictReader(file))

def gcj_forward(lon, lat):
    if lon < 72.004 or lon > 137.8347 or lat < .8293 or lat > 55.8271:
        return lon, lat
    x, y = lon - 105, lat - 35
    dl = -100 + 2*x + 3*y + .2*y*y + .1*x*y + .2*math.sqrt(abs(x))
    dn = 300 + x + 2*y + .1*x*x + .1*x*y + .1*math.sqrt(abs(x))
    wave = (20*math.sin(6*x*math.pi)+20*math.sin(2*x*math.pi))*2/3
    dl += wave + (20*math.sin(y*math.pi)+40*math.sin(y*math.pi/3))*2/3
    dl += (160*math.sin(y*math.pi/12)+320*math.sin(y*math.pi/30))*2/3
    dn += wave + (20*math.sin(x*math.pi)+40*math.sin(x*math.pi/3))*2/3
    dn += (150*math.sin(x*math.pi/12)+300*math.sin(x*math.pi/30))*2/3
    rad = lat/180*math.pi
    magic = 1-.006693421622965943*math.sin(rad)**2
    root = math.sqrt(magic)
    return lon+dn*180/(6378245/root*math.cos(rad)*math.pi), lat+dl*180/(6378245*(1-.006693421622965943)/(magic*root)*math.pi)

def gcj_inverse(lon, lat):
    x, y = lon, lat
    for _ in range(5):
        gx, gy = gcj_forward(x, y)
        x -= gx-lon
        y -= gy-lat
    return x, y

names = [r for r in read_csv('ok_data_level3.csv') if not r['id'].startswith('91')]
by_id = {r['id']:r for r in names}
geo = {r['id']:r for r in read_csv('ok_geo.csv') if r['deep']=='2'}
converter = OpenCC('t2s')
tw = json.loads((SOURCE/'taiwan-towns.json').read_text(encoding='utf-8-sig'))
tw_geometries = {}
for feature in tw['features']:
    name = converter.convert(feature['properties']['名稱']).replace('臺','台')
    name = name.replace('桃园县','桃园市')
    tw_geometries[name] = feature['geometry']

# Recent counties omitted by the upstream April snapshot. OSM supplies their
# current administrative polygons; all reverse lookup remains offline at runtime.
supplements={}
for code,city,name in [('653228','6532','和康县'),('653229','6532','和安县'),('653132','6531','岑岭县')]:
    matches=json.loads((SOURCE/('osm-'+code+'.json')).read_text(encoding='utf-8'))
    record=next(r for r in matches if r['type']=='administrative' and r['display_name'].startswith(name))
    geometry=transform(gcj_forward,shape(record['geojson']))
    supplements[code]=geometry
    names.append({'id':code,'pid':city,'deep':'2','ext_name':name})

out = ROOT/'data/regions'
out.mkdir(parents=True, exist_ok=True)
provinces = [{'code':r['id'],'name':r['ext_name']} for r in names if r['deep']=='0']
cities = [{'code':r['id'],'province':r['pid'],'name':r['ext_name']} for r in names if r['deep']=='1']
counties = []
streams = {}
missing = []
point_count = 0
def polygon_parts(geometry):
    if geometry.geom_type=='Polygon':
        return [geometry]
    return [p for child in getattr(geometry,'geoms',[]) for p in polygon_parts(child)]
for row in names:
    if row['deep']!='2':
        continue
    city = by_id[row['pid']]
    province = city['pid']
    entry = {'code':row['id'],'province':province,'city':city['id'],'name':row['ext_name']}
    record = geo.get(row['id'],{})
    geometry = supplements.get(row['id'])
    center = None
    polygon = record.get('polygon','EMPTY')
    if geometry is None and polygon and polygon!='EMPTY':
        parts = []
        for ring in polygon.split(';'):
            points = [tuple(map(float,p.split())) for p in ring.split(',') if p.strip()]
            if len(points)>=3:
                parts.append(Polygon(points))
        geometry = make_valid(MultiPolygon(parts))
        center = tuple(map(float,record['geo'].split())) if record.get('geo') not in [None,'EMPTY',''] else None
    elif geometry is None and province=='71':
        full_name = city['ext_name']+row['ext_name']
        if full_name in tw_geometries:
            geometry = transform(gcj_forward,shape(tw_geometries[full_name]))
    if geometry is None or geometry.is_empty:
        missing.append({'code':row['id'],'path':city['ext_name']+row['ext_name']})
        entry['available']=False
        counties.append(entry)
        continue
    if province=='65' and row['id'] not in supplements:
        for newer in supplements.values():
            if geometry.intersects(newer):
                geometry=make_valid(geometry.difference(newer))
    geometry = geometry.simplify(.00006,preserve_topology=True)
    polygons = polygon_parts(geometry)
    if not polygons:
        raise ValueError('Missing polygons: '+row['id'])
    if center is None or not geometry.covers(Point(center)):
        c = geometry.representative_point()
        center = c.x,c.y
    lon,lat = gcj_inverse(*center)
    entry.update(lon=round(lon,6),lat=round(lat,6),bounds=[round(v,6) for v in geometry.bounds],available=True)
    if province not in streams:
        streams[province]=(out/(province+'.bin')).open('wb')
        streams[province].write(b'RGN1')
    stream=streams[province]
    entry['offset']=stream.tell()
    stream.write(struct.pack('<I',len(polygons)))
    for poly in polygons:
        rings=[poly.exterior]+list(poly.interiors)
        stream.write(struct.pack('<I',len(rings)))
        for ring in rings:
            coords=list(ring.coords)
            point_count+=len(coords)
            stream.write(struct.pack('<I',len(coords)))
            stream.write(struct.pack('<'+'ff'*len(coords),*(n for pair in coords for n in pair)))
    entry['bytes']=stream.tell()-entry['offset']
    counties.append(entry)
for stream in streams.values():
    stream.close()
catalog={'version':1,'source_version':'AreaCity 2025.251231.260403 + Taiwan-GeoJSON + OSM 2026-10-21','geometry_crs':'GCJ-02','weather_crs':'WGS84','provinces':provinces,'cities':cities,'counties':counties}
(ROOT/'data/china_regions.json').write_text(json.dumps(catalog,ensure_ascii=False,separators=(',',':')),encoding='utf-8')
report={'provinces':len(provinces),'cities':len(cities),'counties':len(counties),'available':sum(c.get('available',False) for c in counties),'points':point_count,'missing':missing,'boundary_bytes':sum(p.stat().st_size for p in out.glob('*.bin'))}
(ROOT/'build/regions-build.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False,indent=2))
