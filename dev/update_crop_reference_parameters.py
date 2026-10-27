"""Apply a documented agronomic reference preset; no gameplay code changes."""
from pathlib import Path
from datetime import datetime
import json
import os
import shutil

ROOT=Path(__file__).resolve().parents[1]
FAO='https://www.fao.org/4/s2022e/s2022e07.htm'
WATER='https://www.fao.org/4/s2022e/s2022e02.htm'
plans={
 'corn': {'days':[7,18,25,25,55,0], 'water':[1.5,2.5,3.5,5,5.5,0], 'yield':1,
  'months':[4,5,6], 'season':'春末夏初露地播种（北半球参考）',
  'basis':'中熟籽粒玉米，播种至籽粒集中成熟参考130天；并非甜玉米鲜穗的首次采摘日。单株参考1个主要果穗，未模拟受精和果穗大小。',
  'sources':[FAO,'https://extension.illinois.edu/gardening/corn']},
 'cotton': {'days':[7,33,23,55,42,0], 'water':[1.2,2,3,6,2.5,0],
  'months':[4,5], 'season':'春季地温回升后播种（北半球参考）',
  'basis':'陆地棉暖季日历参考160天；按一季集中采收处理。40天现蕾、63天初花、118天起吐絮是阶段划分参考，不是所有品种固定日期。',
  'sources':['https://cottonsa.org.za/technical-information/','https://extension.okstate.edu/fact-sheets/understanding-cotton-irrigation-requirements-in-oklahoma',WATER]},
 'pepper': {'days':[14,42,30,44,20,0], 'water':[1.2,2,3,4.5,3,2],
  'months':[3,4,5,6], 'season':'春夏播种（包括育苗期）',
  'basis':'露地红熟椒一季集中采收参考150天，从播种起算，含14天发芽与其后育苗；不是从移栽起算。现实多批采果在本作单次采收规则中合并处理。',
  'sources':[FAO,WATER,'https://extension.rutgers.edu/fs1273']},
 'tomato': {'days':[7,35,28,50,30,0], 'water':[1.2,2,3,5,3.5,3],
  'months':[2,3,4,5,6], 'season':'春夏播种（包括育苗期）',
  'basis':'露地中熟番茄一季集中采收参考150天，包含播种和育苗；不是移栽后150天，也不是第一枚果实开始变红的固定日期。多批果实在单次采收规则中合并。',
  'sources':[FAO,WATER,'https://extension.umn.edu/agriculture/specialty-crops/vegetable-farming/crop-and-field-planning-tools-for-vegetable-farmers']},
 'tobacco': {'days':[14,46,45,45,30,0], 'water':[1,1.8,3,4.5,2.5,1.5],
  'months':[2,3,4], 'season':'春季育苗、适温移栽的日历参考',
  'basis':'烤烟参考从播种至集中采叶180天，包括约60天育苗和其后120天田间生长；不同烟草类型和产区差异大。分叶位采收在本作合并，烘烤加工不计入成熟周期。',
  'sources':['https://nirca.icar.gov.in/farmers.php?page=soils-climate','https://tobacco.caes.uga.edu/content/dam/caes-subsite/tobacco/docs/growers-guide/2013/2013-Georgia-tobacco-growers-guide.pdf',WATER]},
 'wheat_spring': {'days':[7,23,30,30,30,0], 'water':[1,1.8,3.5,5.5,4.5,0],
  'months':[2,3,4,5], 'season':'春播（按当地解冻及地温选择）',
  'basis':'中早熟春小麦播种至籽粒成熟参考120天；抽穗开花和灌浆期耗水较高，成熟干籽不按鲜果继续耗水。未模拟品种积温差异。',
  'sources':[FAO,WATER]},
 'wheat_winter': {'days':[7,28,105,45,30,35,0], 'water':[1,1,.4,3,4.5,3.5,0],
  'months':[9,10,11], 'season':'秋播、越冬、次年收获（北半球参考）',
  'basis':'秋播冬小麦跨年参考250天，包括105天越冬日历近似。越冬、返青、抽穗和灌浆耗水分开；本轮只改参数，不新增春化或冻害算法。',
  'sources':[WATER,'https://www.fao.org/4/i2800e/i2800e.pdf']},
 'rose': {'days':[28,62,30,0], 'water':[1,2,3,3],
  'months':[3,4,5,9,10], 'season':'已完成种子预处理后的春秋适温播种',
  'basis':'保留早花类、已完成休眠解除种子的120天观花参考；这不是所有玫瑰从未处理种子到开花的通用周期。种子层积所需时间不包含在此日历内；多年生复花仍按当前单次采花规则简化。',
  'sources':['https://yardandgarden.extension.iastate.edu/how-to/how-propagate-roses']},
}

def load(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def write(path,value):
 temp=path.with_name(path.name+'.reference.tmp')
 temp.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 os.replace(temp,path)

results=[]
for key,plan in plans.items():
 path=ROOT/'data/crops'/key/'crop.json'
 d=load(path)
 before=d['duration']/86400
 assert len(d['stages'])==len(plan['days'])==len(plan['water'])
 for stage,days,water in zip(d['stages'],plan['days'],plan['water']):
  stage['seconds']=days*86400
  stage['water_mm_per_day']=water
  if stage.get('harvestable') and water>0 and stage['drought_death_seconds']==0:
   stage['drought_death_seconds']=7*86400
 d['duration']=sum(plan['days'])*86400
 d['watering']['initial_mm']=round(float(d['watering']['capacity_mm'])*.6,1)
 if 'yield' in plan:d['harvest']['yield']=plan['yield']
 sowing=d.setdefault('sowing',{})
 sowing.update(label=plan['season'],recommended_months=plan['months'],note='北半球露地参考播期；地区、品种、设施栽培可不同。月份仅提示，气温不是土温实测。')
 sowing.setdefault('badge','')
 d['description']=plan['basis']
 d['version']='1.2.0'
 d['parameter_reference']={'updated':'2026-10-26','sources':plan['sources'],'basis':plan['basis'],
  'days_are':'真实日、参考气候与供水条件下的阶段日历；不是按当前天气自动算出的物候预测',
  'water_is':'mm/日的分阶段平均耗水参考；不等于逐日实测蒸散',
  'universal_constants':False}
 d['simulation_notes']=[plan['basis'],
  '播种按已经适度湿润的土壤开始，初始水量为配置储水容量的60%；此后按阶段耗水和实际浇水补给。',
  '适温范围、土壤水容量、干土死亡时限、温度死亡等待、单次产量仍是固定参数近似，不是品种通用的致死或产量常数。',
  '维持现有单次采收、缺水和死亡玩法；本轮未更改编辑器或生长程序，不模拟新增春化、光周期、历史天气、分批采收或季节复花。',
  '除了单株玉米修正为1穗，其他库存单位和每次产量保持兼容，游戏份数不等同于实测单株重量。']
 if key=='rose':d['simulation_notes'].append('种子预处理在播种前完成；120天不含冷湿层积。不同蔷薇属物种与品种开花年龄不同，没有依据时不套统一天数。')
 d['temperature']['note']='当前程序把适温范围用于成长与温度伤害；本轮不改变该算法，不能将这些范围解释为实测生存极限。种子使用播种范围，其他阶段优先使用阶段范围。'
 write(path,d)
 results.append({'id':key,'before_days':before,'after_days':d['duration']/86400,'initial_water_mm':d['watering']['initial_mm'],'seasonal_reference_water_mm':round(sum(a*b for a,b in zip(plan['days'],plan['water'])),1),'yield':d['harvest']['yield'],'unit':d['harvest']['unit']})

# Keep the current custom rose's twelve images and per-state visual scales.
# Publish a new immutable version so its old edited package remains recoverable.
user=Path(os.environ['APPDATA'])/'Godot/app_userdata/苔屿 · 桌面微观农场'
index_path=user/'crop-editor/index.json'
index=load(index_path) if index_path.exists() else {}
if str(index.get('rose','')).startswith('user://'):
 old=user/index['rose'][7:]
 original=load(old)
 if len(original['stages'])!=4: raise RuntimeError('Custom rose stages differ; preserve it and review manually')
 base=load(ROOT/'data/crops/rose/crop.json')
 for key in ['version','description','watering','temperature','sowing','simulation_notes','parameter_reference']:original[key]=base[key]
 for i,stage in enumerate(original['stages']):
  for field in ['seconds','water_mm_per_day','drought_death_seconds']:stage[field]=base['stages'][i][field]
 original['duration']=sum(s['seconds'] for s in original['stages'])
 if len(original.get('editor_states',[]))==12:
  for slot,stage in zip([0,3,6,9],original['stages']):
   original['editor_states'][slot]['days']=max(.001,stage['seconds']/86400)
   original['editor_states'][slot]['water']=stage['water_mm_per_day']
   original['editor_states'][slot]['death_days']=stage['drought_death_seconds']/86400
 version=datetime.now().strftime('%Y%m%d-%H%M%S')+'-reference'
 directory=old.parent.parent/version
 directory.mkdir(parents=True)
 for image in old.parent.glob('*.png'):shutil.copy2(image,directory/image.name)
 write(directory/'crop.json',original)
 shutil.copy2(index_path,index_path.with_name('index.json.before-reference'))
 index['rose']='user://'+(directory/'crop.json').relative_to(user).as_posix()
 write(index_path,index)

report=ROOT/'docs/作物参数参考表-20261026.json'
write(report,{'scope':'仅作物JSON参数，不修改编辑器/生长程序','changes':results})
print(json.dumps(results,ensure_ascii=False,indent=2))
