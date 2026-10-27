"""Record provenance and checksums for the local, public region data."""
import hashlib
import json
from pathlib import Path
from urllib.parse import quote

root=Path(__file__).resolve().parents[1]
catalog=root/'data/china_regions.json'
data=json.loads(catalog.read_text(encoding='utf-8'))
data['source_version']='AreaCity 2025.251231.260403 + Taiwan-GeoJSON + OSM 2026-10-21'
catalog.write_text(json.dumps(data,ensure_ascii=False,separators=(',',':')),encoding='utf-8')
sources=[
    {'url':'https://github.com/xiangyuecn/AreaCity-JsSpider-StatsGov/releases/tag/2025.251231.260403','license':'MIT'},
    {'url':'https://github.com/titaneric/Taiwan-GeoJSON','origin':'https://data.gov.tw/dataset/7441'},
]
for code,name in [('653228','和康县'),('653229','和安县'),('653132','岑岭县')]:
    sources.append({'url':'https://nominatim.openstreetmap.org/search?format=jsonv2&polygon_geojson=1&q='+quote(name),'county_code':code,'license':'ODbL-1.0'})
files=[catalog]+sorted((root/'data/regions').glob('*.bin'))
report={'version':'2.5.0','snapshot':'2026-10-21','provinces':34,'cities':392,'counties':3212,'sources':sources,'boundary_crs':'GCJ-02','weather_crs':'WGS84','simplification_degrees':.00006,'files':[]}
for file in files:
    report['files'].append({'path':file.relative_to(root).as_posix(),'bytes':file.stat().st_size,'sha256':hashlib.sha256(file.read_bytes()).hexdigest()})
(root/'data/regions-source.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('Region provenance and hashes ready')
