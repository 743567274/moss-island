"""Replace corn artwork with a transparent atlas; retain gameplay settings."""
import json
import shutil
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
source = Path.home() / 'Downloads/玉米.png'
package = ROOT / 'data/crops/corn'
runtime = ROOT / 'build/crops/corn/crop.json'
config_path = package / 'crop.json'
config = json.loads((runtime if runtime.exists() else config_path).read_text(encoding='utf-8'))
shutil.copy2(source, package / 'states.png')
image = Image.open(source)
mask = image.getchannel('A').point(lambda n: 255 if n > 16 else 0)
frames = []
for top, bottom, count in [(0, 480, 5), (480, image.height, 6)]:
    strip = mask.crop((0, top, image.width, bottom))
    gaps = []
    start = None
    for x in range(image.width + 1):
        empty = x < image.width and strip.crop((x, 0, x + 1, strip.height)).getbbox() is None
        if empty and start is None:
            start = x
        elif not empty and start is not None:
            if x - start > 6:
                gaps.append((start + x) // 2)
            start = None
    edges = [0]
    for i in range(1, count):
        expected = image.width * i / count
        candidates = [x for x in gaps if x > edges[-1] and abs(x - expected) < image.width / count * .45]
        if not candidates:
            raise ValueError(f'No transparent separator for row {top}, cell {i}')
        edges.append(min(candidates, key=lambda x: abs(x - expected)))
    edges.append(image.width)
    for left, right in zip(edges, edges[1:]):
        x0, y0, x1, y1 = mask.crop((left, top, right, bottom)).getbbox()
        x0, y0 = max(left, left + x0 - 2), max(top, top + y0 - 2)
        x1, y1 = min(right, left + x1 + 2), min(bottom, top + y1 + 2)
        frames.append([x0/image.width, y0/image.height, (x1-x0)/image.width, (y1-y0)/image.height])

keys = ['seed', 'seed_dead', 'seedling', 'seedling_dry', 'seedling_dead',
        'juvenile', 'adult_dry', 'adult_dead', 'mature', 'picked', 'residue']
previous_assets = config['assets']
assets = {key: dict(file='states.png', atlas=True, scale=previous_assets.get(key, {}).get('scale', 1.0), region=region)
          for key, region in zip(keys, frames)}
# The new sheet has one intermediate normal appearance. Reuse it through the
# existing juvenile/adult/fruiting stages without altering their growth times.
for alias, original in [('adult', 'juvenile'), ('fruiting', 'juvenile'), ('icon', 'picked')]:
    assets[alias] = dict(assets[original], scale=previous_assets.get(alias, {}).get('scale', 1.0))
config['assets'] = assets
for stage in config['stages']:
    if stage['id'] in ['juvenile', 'adult', 'fruiting']:
        stage['dead_sprite'] = 'adult_dead'
config['render']['edge_cleanup'] = dict(radius=3, light_min=.68, alpha_max=.94, saturation_max=.28)
# A common height reference preserves the relative proportions in the source
# sheet. Per-image scale remains the only user-facing size adjustment.
config['render']['atlas_reference_height'] = 1.4
config['render']['atlas_reference_region_height'] = max(frame[3] for frame in frames[5:])
config['version'] = '1.1.0'
config_path.write_text(json.dumps(config, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps(dict(size=image.size, regions=dict(zip(keys, frames))), ensure_ascii=False, indent=2))
