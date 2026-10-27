"""Add five crop packages from four user atlases; preserve existing farms."""
import json
import shutil
from pathlib import Path
from atlas_regions import crop_regions

ROOT = Path(__file__).resolve().parents[1]
DAY = 86400
KEYS = ['seed', 'seed_dead', 'seedling', 'seedling_dry', 'seedling_dead',
        'juvenile', 'juvenile_dry', 'juvenile_dead', 'mature', 'picked', 'residue']


def stage(id, name, days, sprite, water, death=10, temperature=None):
    dry = 'seedling_dry' if sprite == 'seedling' else ('juvenile_dry' if sprite == 'juvenile' else sprite)
    dead = 'seed_dead' if sprite == 'seed' else ('seedling_dead' if sprite == 'seedling' else 'juvenile_dead')
    data = dict(id=id, name=name, seconds=days*DAY, sprite=sprite, dry_sprite=dry,
                dead_sprite=dead, height=1.3, water_mm_per_day=water,
                drought_death_seconds=death*DAY if days else 0, harvestable=not days)
    if temperature:
        data['temperature'] = dict(min_c=temperature[0], max_c=temperature[1])
    return data


specs = [
    dict(id='wheat_spring', name='春小麦', sheet='麦子', icon='wheat', split=480,
         months=[2,3,4,5], badge='春', season='春播', climate=[4,28,2,22], yield_count=4, unit='份',
         stages=[stage('seed','种子',7,'seed',1,5), stage('seedling','幼苗',23,'seedling',1.8),
                 stage('tillering','分蘖拔节',30,'juvenile',3), stage('heading','抽穗开花',30,'juvenile',4),
                 stage('grain_filling','灌浆转熟',30,'mature',3), stage('mature','成熟',0,'mature',0)],
         sources=['https://extension.umn.edu/agriculture/crop-production/small-grains/spring-wheat-growth-and-development-guide']),
    dict(id='wheat_winter', name='冬小麦', sheet='麦子', icon='wheat', split=480,
         months=[9,10,11,12], badge='冬', season='秋末冬初播种', climate=[4,28,2,22], yield_count=4, unit='份',
         stages=[stage('seed','种子',7,'seed',1,5), stage('seedling','冬前幼苗',28,'seedling',1,14,(-5,25)),
                 stage('overwinter','越冬分蘖',105,'seedling',.4,21,(-12,20)),
                 stage('jointing','返青拔节',45,'juvenile',3), stage('heading','抽穗开花',30,'juvenile',4),
                 stage('grain_filling','灌浆转熟',35,'mature',3), stage('mature','成熟',0,'mature',0)],
         sources=['https://zzys.moa.gov.cn/tzgg/201309/t20130912_6310559.htm',
                  'https://extension.umn.edu/agriculture/crop-production/small-grains/plant-winter-hardy-adapted-varieties']),
    dict(id='pepper', name='辣椒', sheet='辣椒', icon='pepper', split=494,
         months=[3,4,5,6], badge='', season='春夏播种', climate=[15,32,20,30], yield_count=16, unit='个',
         stages=[stage('seed','种子',10,'seed',1.2,4), stage('seedling','幼苗',46,'seedling',2,7),
                 stage('vegetative','长大',30,'juvenile',3), stage('fruiting','开花结果',44,'juvenile',4),
                 stage('ripening','转红成熟',20,'mature',3), stage('mature','成熟',0,'mature',0)],
         sources=['https://extension.umd.edu/resource/growing-peppers-home-garden',
                  'https://yardandgarden.extension.iastate.edu/how-to/vegetable-harvest-guide']),
    dict(id='tomato', name='西红柿', sheet='西红柿', icon='tomato', split=494,
         months=[2,3,4,5,6], badge='', season='春夏播种', climate=[12,32,18,30], yield_count=16, unit='个',
         stages=[stage('seed','种子',7,'seed',1.2,4), stage('seedling','幼苗',35,'seedling',2,7),
                 stage('vegetative','长大开花',28,'juvenile',3), stage('fruiting','结果膨大',40,'juvenile',4.5),
                 stage('ripening','转红成熟',20,'mature',3), stage('mature','成熟',0,'mature',0)],
         sources=['https://extension.usu.edu/yardandgarden/research/grow-your-own-transplants-at-home',
                  'https://yardandgarden.extension.iastate.edu/how-to/vegetable-harvest-guide']),
    dict(id='tobacco', name='烟叶', sheet='烟叶', icon='tobacco', split=464,
         months=[2,3,4,5], badge='', season='春播', climate=[15,32,20,30], yield_count=24, unit='片',
         stages=[stage('seed','种子',10,'seed',1,4), stage('seedling','幼苗',50,'seedling',1.8,7),
                 stage('vegetative','团棵伸根',60,'juvenile',3), stage('leaf_expansion','旺长展叶',30,'juvenile',4),
                 stage('ripening','叶片成熟',30,'mature',2.5), stage('mature','成熟',0,'mature',0)],
         sources=['https://dfz.shaanxi.gov.cn/zslm/fzzlk/xbsxsz/szdylpdf/201404/P020240923626374688109.pdf',
                  'https://et.ynau.edu.cn/lab/yckx/Media/73_20140529234013.pdf']),
]

manifest_path = ROOT / 'data/catalog.json'
manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
for spec in specs:
    package = ROOT / 'data/crops' / spec['id']
    package.mkdir(parents=True, exist_ok=True)
    shutil.copy2(Path.home() / ('Downloads/'+spec['sheet']+'.png'), package/'states.png')
    frames = crop_regions(package/'states.png', spec['split'])
    assets = {key:dict(file='states.png', atlas=True, scale=1.0, region=frame) for key,frame in zip(KEYS,frames)}
    assets['icon'] = dict(file='icon.png', scale=1.0, region=[0,0,1,1])
    lo,hi,slo,shi = spec['climate']
    days = sum(s['seconds'] for s in spec['stages'])//DAY
    notes = ['参考周期从播种起算，包含育苗阶段，非从移栽起算。气候、品种、水分会改变实际成熟时间。',
             '阶段耗水、干土死亡阈值、温度伤害阈值和每田产量为可调模拟参数，不是普适农艺常数。',
             '当前作物统一采用单次整田采收；未模拟番茄辣椒逐批果实采摘或烟草分层采叶。']
    if spec['id']=='wheat_winter':
        notes.append('冬小麦采用105天越冬日历阶段与阶段耐寒范围近似越冬，不计算真实春化、积温、抗寒锻炼和积雪保护；地区差异需修改配置。')
    config = dict(schema_version=1,id=spec['id'],name=spec['name'],version='1.0.0',type='crop',
        description=f'正常供水、适温下参考{days}个真实日；'+notes[0],clock='real',duration=days*DAY,
        color='cfad59' if spec['sheet']=='麦子' else ('c75c49' if spec['sheet'] in ['西红柿','辣椒'] else '8da35f'),
        model=spec['icon'],stages=spec['stages'],assets=assets,icon='icon',
        sowing=dict(label=spec['season'],badge=spec['badge'],recommended_months=spec['months'],
                    note='中国北半球通用参考播期，月份仅提示不禁止播种；具体地区和品种请调整。'),
        temperature=dict(min_c=lo,max_c=hi,sowing_min_c=slo,sowing_max_c=shi,
                         unsuitable_growth_factor=0.0,stress_death_seconds=48*3600,recovery_per_second=2.0,
                         note='气温近似；种子使用播种范围，其他阶段优先使用阶段温度范围，缺失则使用全局范围。'),
        watering=dict(capacity_mm=45.0,initial_mm=0.0,per_action_mm=30.0,warning_mm=10.0,growth_min_mm=2.0,
                      dry_growth_factor=0.0,rain_absorption=.8,rain_mm_per_hour={'61':1.0,'63':4.0,'65':10.0},observed_weather_max_seconds=120),
        harvest=dict(yield_count=spec['yield_count'],unit=spec['unit'],residue_sprite='residue',residue_height=1.3,repeatable=False),
        render=dict(columns=1,rows=1,non_seed_scale=1.3,spacing_x=.26,spacing_y=.44,anchor_y=.94,sway=.008,seed_sway=0.0,shadow_scale=.22,
                    atlas_reference_height=1.4,atlas_reference_region_height=max(f[3] for f in frames[5:]),
                    edge_cleanup=dict(radius=3,light_min=.68,alpha_max=.94,saturation_max=.28)),
        simulation_notes=notes,sources=[dict(url=url,note='生育及播期参考；默认阶段划分与数值为本包的可调整近似。') for url in spec['sources']])
    config['harvest']['yield'] = config['harvest'].pop('yield_count')
    (package/'crop.json').write_text(json.dumps(config,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    entry='res://data/crops/'+spec['id']+'/crop.json'
    if entry not in manifest['crop_packages']:
        manifest['crop_packages'].append(entry)
    print(spec['name'], str(days)+'天', package)
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
