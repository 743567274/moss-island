"""Register user supplied transparent atlases without modifying their pixels."""
import json
import shutil
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DOWNLOADS = Path.home() / 'Downloads'
NAME = 'BgSub_动态桌面壁纸休闲种植游戏渲染图生成'


def regions(path, rows):
    image = Image.open(path)
    alpha = image.getchannel('A')
    mask = alpha.point(lambda n: 255 if n > 16 else 0)
    result = []
    for top, bottom, count in rows:
        strip = mask.crop((0, top, image.width, bottom))
        occupied = [strip.crop((x, 0, x + 1, strip.height)).getbbox() is not None for x in range(image.width)]
        gaps = []
        start = None
        for x, value in enumerate(occupied + [True]):
            if not value and start is None:
                start = x
            elif value and start is not None:
                if x - start > 6:
                    gaps.append((start + x) // 2)
                start = None
        edges = [0]
        for i in range(1, count):
            expected = image.width * i / count
            candidates = [x for x in gaps if abs(x - expected) < image.width / count * .45 and x > edges[-1]]
            if not candidates:
                raise ValueError(f'No transparent separator for cell {i}')
            edges.append(min(candidates, key=lambda x: abs(x - expected)))
        edges.append(image.width)
        for left, right in zip(edges, edges[1:]):
            bounds = mask.crop((left, top, right, bottom)).getbbox()
            x0, y0, x1, y1 = bounds
            # Retain a small transparent margin for linear sampling.
            x0, y0 = max(left, left + x0 - 2), max(top, top + y0 - 2)
            x1, y1 = min(right, left + x1 + 2), min(bottom, top + y1 + 2)
            result.append([x0/image.width, y0/image.height, (x1-x0)/image.width, (y1-y0)/image.height])
    return result


def write_json(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


soil_source = DOWNLOADS / (NAME + '.png')
soil = ROOT / 'assets/illustrated/soil-atlas.png'
shutil.copy2(soil_source, soil)
map_path = ROOT / 'data/lakeside-map.json'
map_data = json.loads(map_path.read_text(encoding='utf-8'))
map_data['soil_atlas'] = 'res://assets/illustrated/soil-atlas.png'
map_data['soil_regions'] = regions(soil, [(0, 1536, 2)])
map_data['soil_edge_cleanup'] = dict(radius=3, light_min=.68, alpha_max=.94, saturation_max=.28)
write_json(map_path, map_data)

package = ROOT / 'data/crops/cotton'
package.mkdir(parents=True, exist_ok=True)
shutil.copy2(DOWNLOADS / (NAME + ' (1).png'), package / 'states.png')
keys = ['seed', 'seed_dead', 'seedling', 'seedling_dry', 'seedling_dead',
        'juvenile', 'juvenile_dry', 'juvenile_dead', 'mature', 'picked', 'residue']
frames = regions(package / 'states.png', [(0, 491, 5), (491, 1152, 6)])
assets = {key: {'file': 'states.png', 'atlas': True, 'scale': 1.0, 'region': frame} for key, frame in zip(keys, frames)}
stages = []
for key, name, days, sprite, dry, dead, height, water, death in [
    ('seed', '种子', 7, 'seed', 'seed', 'seed_dead', .30, 1.2, 4),
    ('seedling', '幼苗', 33, 'seedling', 'seedling_dry', 'seedling_dead', .65, 2.0, 7),
    ('squaring', '半成熟·现蕾', 23, 'juvenile', 'juvenile_dry', 'juvenile_dead', 1.05, 3.0, 10),
    ('boll_development', '半成熟·花铃', 55, 'juvenile', 'juvenile_dry', 'juvenile_dead', 1.25, 5.5, 10),
    ('boll_opening', '吐絮', 42, 'mature', 'mature', 'juvenile_dead', 1.25, 2.5, 10),
    ('mature', '成熟', 0, 'mature', 'mature', 'juvenile_dead', 1.25, 0, 0),
]:
    stages.append(dict(id=key, name=name, seconds=days*86400, sprite=sprite, dry_sprite=dry,
                       dead_sprite=dead, height=height, water_mm_per_day=water,
                       drought_death_seconds=death*86400, harvestable=days==0))
config = dict(schema_version=1, id='cotton', name='棉花', version='1.0.0', clock='real',
    description='正常供水参考160个真实日；播种至现蕾40天、初花63天、首批吐絮118天、采收160天。品种与气候会改变实际周期；本包使用参考日历，不模拟积温。',
    duration=160*86400, color='f4ead3', model='cotton', stages=stages, assets=assets, icon='mature',
    watering=dict(capacity_mm=45.0, initial_mm=0.0, per_action_mm=30.0, warning_mm=10.0,
        growth_min_mm=2.0, dry_growth_factor=0.0, rain_absorption=.8,
        rain_mm_per_hour={'61':1.0,'63':4.0,'65':10.0}, observed_weather_max_seconds=120),
    harvest=dict(yield_=4, unit='份', picked_sprite='picked', picked_height=1.25,
        residue_delay_seconds=7*86400, residue_sprite='residue', residue_height=1.15, repeatable=False),
    render=dict(columns=1, rows=1, non_seed_scale=1.3, spacing_x=.26, spacing_y=.44, anchor_y=.94, sway=.008, seed_sway=0.0, shadow_scale=.22),
    simulation_notes=['单次采收；摘取状态保留7个真实日后切换枯株，可提前铲除。',
        '土壤容量、阶段耗水、完全干土死亡倒计时、采后枯萎时间和每田产量为可调整的模拟参数，不是统一农艺常数。',
        '播种初始土壤为干土，需要浇水；储水低于2mm暂停成长，完全干土才开始累计死亡时间。',
        '现蕾和花铃共用半成熟素材；吐絮与成熟共用成熟素材，缺失独立缺水贴图的阶段复用正常图。'],
    sources=[dict(url='https://www.cotton.org/tech/ace/growth-and-development.cfm',
        note='出苗4—9天、出苗至现蕾27—38天、现蕾至初花20—25天、开花至吐絮45—65天、播种至采收130—160天。')])
config['harvest']['yield'] = config['harvest'].pop('yield_')
config['type'] = 'crop'
config['render']['edge_cleanup'] = dict(radius=3, light_min=.68, alpha_max=.94, saturation_max=.28)
config['temperature'] = dict(min_c=15.6, max_c=35, sowing_min_c=18, sowing_max_c=32,
    unsuitable_growth_factor=0.0, stress_death_seconds=36*3600, recovery_per_second=2.0,
    note='适宜区间与累计伤害阈值为可调模拟参数，按有效天气气温近似，不推算离线温害。')
write_json(package / 'crop.json', config)
manifest_path = ROOT / 'data/catalog.json'
manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
entry = 'res://data/crops/cotton/crop.json'
if entry not in manifest['crop_packages']:
    manifest['crop_packages'].append(entry)
write_json(manifest_path, manifest)
print(json.dumps(dict(soil=map_data['soil_regions'], cotton=dict(zip(keys, frames))), ensure_ascii=False, indent=2))
