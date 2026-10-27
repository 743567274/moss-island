"""Copy user-authored sprites unchanged and build the editable corn package."""
import json, shutil
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
target = root / 'data/crops/corn'
target.mkdir(parents=True, exist_ok=True)
names = {'seed':'种子', 'mature':'成熟', 'seedling_dry':'幼苗缺水',
         'adult_dry':'收获完-长大缺水', 'adult':'长大', 'fruiting':'结果',
         'juvenile':'半成熟', 'seedling':'幼苗', 'seedling_dead':'幼苗死亡',
         'residue':'长大枯萎', 'icon':'logo', 'seed_dead':'种子枯死'}
assets = {}
for key, name in names.items():
    source = Path('C:/Users/Cozy/Downloads') / (name + '.png')
    destination = target / (key + '.png')
    shutil.copy2(source, destination)
    with Image.open(source) as image:
        if image.mode != 'RGBA' or image.getextrema()[3][0] != 0:
            raise ValueError(f'{name} must have a transparent background')
        box = image.getchannel('A').getbbox()
        assets[key] = {'file':key+'.png', 'scale':1.0, 'region':[box[0]/image.width,box[1]/image.height,(box[2]-box[0])/image.width,(box[3]-box[1])/image.height]}
stages = []
for key,name,days,water,death,height,dry,dead in [
    ('seed','种子',7,1.5,3,.30,'seed','seed_dead'),
    ('seedling','幼苗',14,2.5,5,.62,'seedling_dry','seedling_dead'),
    ('juvenile','半成熟',21,3.5,7,.95,'adult_dry','residue'),
    ('adult','长大',18,5,7,1.25,'adult_dry','residue'),
    ('fruiting','结果',60,6,7,1.40,'adult_dry','residue'),
    ('mature','成熟',0,0,0,1.40,'mature','residue')]:
    stages.append({'id':key,'name':name,'seconds':days*86400,'sprite':key,
                   'dry_sprite':dry,'dead_sprite':dead,'height':height,
                   'water_mm_per_day':water,'drought_death_seconds':death*86400,
                   'harvestable':key=='mature'})
config = {'schema_version':1,'id':'corn','name':'玉米','version':'1.0.0',
    'description':'中熟籽粒玉米：正常供水下参考120个真实日。实际农艺时长随品种、土壤和气候变化。',
    'clock':'real','duration':120*86400,'color':'e7ba4a','model':'corn',
    'stages':stages,'assets':assets,'icon':'icon',
    'watering':{'capacity_mm':40.0,'initial_mm':0.0,'per_action_mm':30.0,
                'warning_mm':10.0,'growth_min_mm':2.0,'dry_growth_factor':0.0,
                'rain_absorption':0.8,'rain_mm_per_hour':{'61':1.0,'63':4.0,'65':10.0},
                'observed_weather_max_seconds':120},
    'harvest':{'yield':4,'unit':'穗','residue_sprite':'residue','residue_height':1.25,'repeatable':False},
    'render':{'columns':1,'rows':1,'non_seed_scale':1.3,'spacing_x':.26,'spacing_y':.44,
              'anchor_y':.94,'sway':.008,'seed_sway':0.0,'shadow_scale':.22},
    'sources':[{'url':'https://extension.umn.edu/agriculture/crop-production/corn/growth-and-development',
                'note':'生殖期约55—65天；本包采用60天，其余阶段为中熟玉米参考配置，非统一生物学常数。'},
               {'url':'https://extension.umn.edu/natural-resources/conservation/agricultural-soil-and-water/irrigation/irrigation-management-strategies',
                'note':'需水随生育期变化；储水容量与缺水死亡时间为可调模拟参数，不冒充普适农艺阈值。'}]}
config['type'] = 'crop'
config['temperature'] = dict(min_c=10, max_c=35, sowing_min_c=10, sowing_max_c=32,
    unsuitable_growth_factor=0.0, stress_death_seconds=48*3600, recovery_per_second=2.0,
    note='适宜区间与累计伤害阈值为可调模拟参数，按有效天气气温近似，不推算离线温害。')
(target/'crop.json').write_text(json.dumps(config, ensure_ascii=False, indent=2), encoding='utf-8')
manifest_path=root/'data/catalog.json'
manifest=json.loads(manifest_path.read_text(encoding='utf-8')) if manifest_path.exists() else {'version':2,'crop_packages':[]}
if 'res://data/crops/corn/crop.json' not in manifest['crop_packages']:
    manifest['crop_packages'].append('res://data/crops/corn/crop.json')
manifest_path.write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print('Corn package: 12 original transparent sprites, 6 stages, 120 real days')
