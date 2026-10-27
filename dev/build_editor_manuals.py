"""Build two self-contained offline HTML manuals from actual UI captures."""
from pathlib import Path
import base64
import html
import json
import os
import struct

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs' / '使用手册'
ASSETS = OUT / 'assets'

def uri(path):
    path = Path(path)
    mime = 'image/svg+xml' if path.suffix == '.svg' else ('image/jpeg' if path.suffix == '.jpg' else 'image/png')
    return 'data:' + mime + ';base64,' + base64.b64encode(path.read_bytes()).decode()

def shot(name, caption):
    raw = (ASSETS/name).read_bytes()
    offset = 2
    while offset < len(raw):
        marker = raw[offset+1]
        offset += 2
        length = struct.unpack('>H', raw[offset:offset+2])[0]
        if marker in (0xc0, 0xc1, 0xc2):
            height, width = struct.unpack('>HH', raw[offset+3:offset+7])
            break
        offset += length
    else: raise ValueError('JPEG dimensions missing: '+name)
    return f'<figure><button class="zoom" aria-label="放大截图"><img loading="lazy" width="{width}" height="{height}" src="{uri(ASSETS/name)}" alt="{html.escape(caption)}"></button><figcaption><b>真实界面截图</b> · {caption} · 点击放大</figcaption></figure>'

def table(headers, rows):
    return '<div class="tablewrap"><table><thead><tr>'+''.join('<th>'+v+'</th>' for v in headers)+'</tr></thead><tbody>'+''.join('<tr>'+''.join('<td>'+str(v)+'</td>' for v in row)+'</tr>' for row in rows)+'</tbody></table></div>'

def note(text): return '<aside class="note">'+text+'</aside>'
def steps(items): return '<ol class="steps">'+''.join('<li>'+x+'</li>' for x in items)+'</ol>'
def flow(items): return '<div class="flow">'+''.join('<span>'+x+'</span>' for x in items)+'</div>'

CSS = r'''
:root{--ink:#253d37;--muted:#677770;--green:#3e6d58;--paper:#f8f7ef;--line:#d9e0d3;--accent:#e7bd66}*{box-sizing:border-box}html{scroll-behavior:smooth;scroll-padding-top:30px}body{margin:0;color:var(--ink);background:var(--paper);font:16px/1.85 "Microsoft YaHei UI","Microsoft YaHei",sans-serif}a{color:var(--green);text-underline-offset:4px}aside.nav{position:fixed;inset:0 auto 0 0;width:244px;background:#e9eee4;border-right:1px solid var(--line);padding:30px 22px;overflow:auto}.brand{letter-spacing:.25em;font-size:12px;color:var(--green)}.nav h2{font-size:23px;margin:8px 0}.nav a{display:block;text-decoration:none;font-size:13px;padding:7px 0;border-bottom:1px solid #dce3d6}.nav .other{margin-top:24px}.search{width:100%;padding:10px;border:1px solid #b6c6b7;background:white;border-radius:8px;color:var(--ink);margin:15px 0 10px}.nav button{width:100%;margin-top:15px;padding:9px;border:1px solid #bbc9b6;border-radius:8px;background:#fffdf5;color:var(--ink);cursor:pointer}main{max-width:1260px;margin-left:244px;padding:48px 6vw 90px}.hero{border-bottom:2px solid #adbca9;padding-bottom:30px;margin-bottom:40px}.eyebrow{font-size:12px;letter-spacing:.18em;color:var(--green)}h1{font-size:42px;line-height:1.25;margin:14px 0 18px;font-weight:650}h2{font-size:26px;margin:0 0 20px}h3{font-size:19px;margin:26px 0 12px}p{margin:12px 0}section{margin:0 0 55px;padding-top:10px;scroll-margin-top:24px}.summary{font-size:18px;max-width:760px}.meta{font-size:12px;color:var(--muted)}figure{margin:25px 0;background:white;border:1px solid var(--line);border-radius:14px;overflow:hidden}.zoom{display:block;width:100%;border:0;padding:0;background:#fff;cursor:zoom-in}.zoom img{display:block;width:100%;height:auto}figcaption{font-size:12px;color:var(--muted);padding:12px 16px;background:#f1f3eb}.tablewrap{overflow:auto;margin:20px 0;border:1px solid var(--line);border-radius:10px}table{width:100%;border-collapse:collapse;font-size:13px}th,td{padding:13px 14px;text-align:left;vertical-align:top;border-bottom:1px solid var(--line)}th{background:#e9eee2;white-space:nowrap}tr:last-child td{border-bottom:0}td:first-child{font-weight:600;min-width:105px}code,kbd{font-family:Consolas,monospace;font-size:.9em;background:#eaf0e4;padding:2px 5px;border-radius:4px;overflow-wrap:anywhere}pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#edf1e8;padding:18px;border-radius:12px;font-size:13px;line-height:1.7}.note{border-left:4px solid var(--accent);background:#fff6df;padding:14px 18px;border-radius:0 10px 10px 0;font-size:14px;margin:20px 0}.steps{counter-reset:step;list-style:none;padding:0}.steps li{position:relative;padding:12px 0 14px 44px;counter-increment:step}.steps li:before{content:counter(step,decimal-leading-zero);position:absolute;left:0;top:12px;color:var(--green);font-weight:700;font-size:19px}.flow{display:flex;flex-wrap:wrap;gap:12px;margin:22px 0}.flow span{background:#e7eddf;border:1px solid #c4d2bd;border-radius:9px;padding:8px 14px;font-size:14px}.flow span:not(:last-child):after{content:' →';color:#76866d}.cards{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:13px;margin:24px 0}.card{background:white;border:1px solid var(--line);border-radius:12px;overflow:hidden}.card .art{height:148px;background:linear-gradient(145deg,#f0f2e8,#e4eadc);display:flex;align-items:center;justify-content:center}.art img{height:140px;max-width:100%;object-fit:contain}.art svg{height:145px;width:160px}.card .body{padding:14px}.card b{display:block;font-size:14px}.card code{font-size:11px}.card p{font-size:12px;color:var(--muted);margin:7px 0 0}.atlas{display:grid;grid-template-columns:repeat(6,1fr);gap:6px;padding:14px;background:#e6eddf;border-radius:12px;margin:20px 0}.atlas div{background:#fffdf5;padding:12px 6px;text-align:center;font-size:12px;border-radius:6px}.atlas strong{display:block;color:var(--green);font-size:17px}.diagram{background:#eef2e9;border:1px solid var(--line);border-radius:12px;padding:18px;margin:20px 0}.diagram svg{display:block;width:100%;height:auto}.badge{display:inline-block;background:#dae7d4;padding:2px 9px;border-radius:20px;font-size:12px;margin:3px}.faq details{border-bottom:1px solid var(--line);padding:15px 0}.faq summary{font-weight:600;cursor:pointer}.faq details p{font-size:14px}.footer{font-size:12px;color:var(--muted);border-top:1px solid var(--line);padding-top:24px}.no-results{color:var(--muted);display:none}dialog{padding:14px;border:0;border-radius:12px;max-width:96vw;max-height:95vh;background:#faf9ef}dialog::backdrop{background:#12221cce}dialog img{max-width:90vw;max-height:83vh;display:block;object-fit:contain}dialog button{display:block;margin:8px auto 0;padding:8px 28px;border:0;border-radius:7px;background:var(--green);color:white;cursor:pointer}.shape-row{display:flex;gap:22px;flex-wrap:wrap}.shape-row div{flex:1;min-width:160px;text-align:center}.shape-row svg{width:150px;height:100px}.top-link{display:inline-block;margin-top:10px;font-size:13px}
@media(max-width:900px){aside.nav{position:static;width:auto;padding:20px}.nav nav{display:flex;flex-wrap:wrap;gap:5px 15px}.nav a{border:0}.nav .other{margin-top:5px}.nav button{width:auto}.search{max-width:380px;display:block}main{margin:0;padding:30px 22px}h1{font-size:32px}.cards{grid-template-columns:repeat(2,1fr)}.atlas{grid-template-columns:repeat(3,1fr)}}@media(max-width:500px){.cards{grid-template-columns:1fr}th,td{padding:10px}h1{font-size:28px}}@media print{aside.nav,.top-link,dialog,.search{display:none!important}main{margin:0;padding:0;max-width:none}body{background:white;font-size:11pt}h1{font-size:26pt}h2{font-size:19pt}section{display:block!important;margin-bottom:25px}figure,.card,tr,.note{break-inside:avoid}figure img{max-height:135mm;object-fit:contain}.cards{grid-template-columns:repeat(3,1fr)}a{color:inherit}.hero{break-after:avoid}}
'''

JS = r'''
const search=document.querySelector('.search');search.addEventListener('input',()=>{const q=search.value.trim().toLowerCase();let count=0;document.querySelectorAll('main section').forEach(s=>{const hit=!q||s.textContent.toLowerCase().includes(q);s.hidden=!hit;if(hit)count++;});document.querySelector('.no-results').style.display=count?'none':'block';});document.querySelectorAll('.nav nav a').forEach(a=>a.addEventListener('click',()=>{search.value='';document.querySelectorAll('main section').forEach(s=>s.hidden=false);}));const modal=document.querySelector('dialog');document.querySelectorAll('.zoom').forEach(b=>b.addEventListener('click',()=>{modal.querySelector('img').src=b.querySelector('img').src;modal.querySelector('img').alt=b.querySelector('img').alt;modal.showModal();}));modal.querySelector('button').addEventListener('click',()=>modal.close());modal.addEventListener('click',e=>{if(e.target===modal)modal.close();});
'''

def document(title, subtitle, sections, other):
    nav=''.join(f'<a href="#{i}">{n:02d}　{t}</a>' for n,(i,t,c) in enumerate(sections,1))
    body=''.join(f'<section id="{i}"><h2>{t}</h2>{c}</section>' for i,t,c in sections)
    return f'''<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{title}｜苔屿</title><style>{CSS}</style></head><body><aside class="nav"><div class="brand">苔屿 / 使用手册</div><h2>{title}</h2><input class="search" placeholder="搜索本手册，例如：温度" aria-label="搜索章节"><nav>{nav}</nav><a class="other" href="{other[0]}">打开{other[1]} →</a><button onclick="window.print()">打印 / 另存为 PDF</button><p class="meta">离线可用 · 图片已嵌入<br>按 2026-10-26 当前实现整理</p></aside><main><header class="hero" id="top"><div class="eyebrow">MOSS ISLAND · EDITOR HANDBOOK</div><h1>{title}</h1><p class="summary">{subtitle}</p><div class="meta">从新建开始 · 真实界面截图 · 参数对照 · 图片与状态说明</div></header><p class="no-results">没有匹配的章节，请更换关键词。</p>{body}<footer class="footer">本手册基于当前项目源码与实际界面整理。截图为真实窗口；标明“示意”的图用于解释概念，不代表额外内置素材或已实现的新玩法。本文档不修改地图、种植或库存数据。<br>图片内嵌，无需联网；两份手册放在同一目录可互相跳转。<a class="top-link" href="#top">返回顶部 ↑</a></footer></main><dialog aria-label="截图大图"><img alt=""><button>关闭大图</button></dialog><script>{JS}</script></body></html>'''

types = [
('土地','可种植田块，保存位置、大小、旋转、普通/选中贴图和点击轮廓。','默认静止；内部作物由作物系统负责摇曳。','透明PNG，通常1张；选中图可选。'),
('地表 / 道路','草地底片、石路、铺地等环境图片。','默认静止；画出水域标记的部分可参与水面效果。','1张透明PNG；大片地表也可不透明。'),
('草丛','局部草叶、花草边缘、前景植被。','启用动画后随风摇曳，风向决定偏移方向，风速影响幅度。','1张透明PNG；根部留在画布底部。'),
('环境树木','柳树、竹子、背景装饰树，不承担种植/收获。','启用动画后随风摆动；位于水域上方也不按水面晃动。','1张透明PNG；可种植果树应去作物编辑器配置。'),
('云层','天空中独立的云图片。','启用后左右往返移动，移动速度受风速影响；不是原地摆动。','1张透明PNG，四周保留透明边缘。'),
('雾气素材','可摆放、排序的局部雾片。','按云雾素材规则缓慢漂移；可关闭动画。','1张柔边透明PNG；与天气系统的全局雾分开。'),
('水面贴图','池塘、溪流或水纹的可见图片。','启用后在有效水域内产生水流与雨天涟漪；受风影响。','1张水面图片；还需要正确的不可见水域范围。'),
('建筑','不需要自带灯光配置的房屋、桥、亭等。','默认静止；不会自动识别窗户或生成光源。','1张透明PNG；有开关灯外观时建议使用灯具类型。'),
('装饰','石块、船、栅栏、非交互摆件。','默认静止。','1张透明PNG。'),
('背景','完整远景或整幅底图。','自动保持比例铺满逻辑画布，超出部分裁切；静止。','1张图片；通常不透明。背景可解锁排序，但不手动平移缩放旋转。'),
('灯具 · 昼夜双贴图','带光源的灯笼、石灯、房子或汽车。','昼夜外观切换；可配置多个相对光源，随素材位置、缩放、旋转。','白天、夜间各1张，同画布尺寸且物体对齐；可选灯芯遮罩。'),
]

light_rows=[
('发散光','从锚点向四周自然衰减，适合灯笼、灯泡、窗前光。方向与夹角不适用。'),
('筒光 / 聚光','有方向、有夹角的光束。适合门灯、车灯、手电。方向控制朝向，夹角控制扇面宽窄。'),
('直射光','较大范围的定向补光；当前是二维画面的定向照明效果，不是物理太阳或自动投影。范围项不可编辑。'),
('本体夜间亮度','调整灯具图片在夜间的可见程度，范围0.1～1.5；不改变灯芯自发光亮度，也不等于照到地上的光强。'),
('光源编号 / 添加 / 复制 / 删除','选定正在编辑的那个光源；每张灯具图片允许多个光源。复制保留该光源的配置，再分别移动。至少保留一个。'),
('光源 X / Y','相对图片的坐标。X=0左边、1右边；Y=0上边、1下边。可用负数或大于1的数，把光源放到图片外。拖动地图中的编号十字也可调整。'),
('方向角','0°向右、90°向下、180°向左、270°（或-90°）向上。素材旋转后，相对光源方向会跟随旋转。'),
('筒光夹角','5～175°。越小越集中，越大越宽；仅筒光生效。'),
('照射范围','12～1600逻辑像素。发散光和筒光越远越弱；灯具上的范围跟随素材缩放。不是屏幕物理像素。'),
('亮度','0～4。0不叠加照明；建议先从0.4～0.8调起，再调整范围和颜色，避免大片发白。'),
('颜色','决定这一个光源的色调。灯笼可用暖黄，冷光可偏蓝；不需要给整张夜间图片染成黄色。'),
('启用此光源','开启或关闭当前光源。其他光源不受影响。'),
('仅夜间开启','勾选后随昼夜变化逐渐开启；取消后白天也会照明。打开顶部夜景预览可查看夜间配置。'),
('轻微闪动','给当前光源加入小幅亮度波动，适合烛火；不是灯泡开关动画。'),
('穿透所属贴图（不照亮本体）','勾选：按所属贴图轮廓排除这一个光源对本体的加亮；不勾选：也照亮本体。它不是自动识别墙体的物理穿透或遮挡系统。无绑定图片的单独光源没有“所属贴图”可排除。'),
('擦除 / 恢复此光源照明','进入绘制窗口，擦掉不该亮的区域，或恢复误擦区域。只改当前光源，不改其他灯和原图。'),
('标记灯芯 / 自发光区域','在图片中指定灯芯、灯泡、窗内亮面。用于保持局部发光；不代替照到地面的外部光源。'),
('替换白天 / 夜间贴图','替换当前灯具图片。两张尺寸必须相同、物体位置一致；不满足时保存按钮上方显示原因与尺寸。'),
('顶部灯光锚点','只控制编辑辅助十字的显示，不控制光源实际是否开启。'),
('顶部夜景预览','切换编辑器中的日/夜预览。真实桌面的昼夜仍按天气与时间系统运行。'),
]

shapes='''<div class="diagram"><div class="shape-row"><div><svg viewBox="0 0 150 100"><path d="M75 8L140 50 75 92 10 50Z" fill="#b38e64" stroke="#466c50" stroke-width="3" stroke-dasharray="6 3"/></svg><b>方形 · 菱形投影</b><p>适合等距视角方田</p></div><div><svg viewBox="0 0 150 100"><ellipse cx="75" cy="50" rx="64" ry="35" fill="#b38e64" stroke="#466c50" stroke-width="3" stroke-dasharray="6 3"/></svg><b>圆形 / 椭圆</b><p>按图片矩形内的椭圆命中</p></div><div><svg viewBox="0 0 150 100"><path d="M30 22Q67 0 89 25L127 29 141 59 111 86 63 78 20 89 10 49Z" fill="#b38e64" stroke="#466c50" stroke-width="3" stroke-dasharray="6 3"/></svg><b>自定义 · 透明轮廓</b><p>按PNG透明区域判断点击</p></div></div><p class="meta">轮廓示意：虚线表示可点击范围，不是程序给贴图重新绘制的边框。</p></div>'''

map_sections=[
('start','从零建立一张地图',steps(['从托盘打开<b>地图编辑器</b>，进入“我的场景项目”。点击<b>＋新建空白项目</b>，输入名称并确认。新项目从空白底色开始。','先放一张背景，或用地表素材逐块拼出草地、岸边与道路；再放建筑、树、云，最后安排田块。','左侧先选素材分类，再<b>导入图片素材</b>。可在文件选择框中一次选择多张图片；类型由导入时所在分类决定。','在素材列表选中条目，点击<b>新增到地图 / 新增田块</b>。导入只登记素材，新增才会在地图中放置一个实例。','用画布或右侧图层选择对象，设置位置、大小、透明度和层级；配置水域和灯光。','先<b>保存项目</b>，再<b>应用到桌面</b>。保存只更新项目，应用才更新当前壁纸。'])+shot('map-projects.jpg','项目列表：新建、编辑、应用、复制、重命名和删除。')+shot('map-new.jpg','新建空白项目：输入名称；确认后进入编辑。')+note('地图编辑器只管理环境与田块，不添加作物状态。可种植的植物由另一份《作物编辑器使用手册》管理。复制地图项目只复制布局，不复制作物和库存。')),
('layout','认识编辑界面',shot('map-editor.jpg','左侧是分类素材与地图环境设置，中间是地图画布，右侧是统一图层；顶部负责保存、应用、水域和夜景预览。')+table(['区域 / 按钮','用途'],[('左侧素材分类','查找或导入同类素材；当前不再区分本地图/全局素材入口。导入的资源仍可复用。'),('编辑素材默认值','修改以后新增实例的默认设置；不会批量改动已经放到地图里的对象。'),('右侧图层操作区','修改当前地图中的选中实例。相同素材可以放多份，每份位置、大小、阴影和灯光配置分别调整。'),('保存项目 / 应用到桌面','先保存布局，再应用。桌面未变化时先确认是否点了应用。'),('恢复已保存布局','丢弃尚未保存的布局修改，重新载入项目保存版本；操作前先确认有没有需要保留的改动。'),('项目底色','空白地图背后的底色；不等于导入的背景图片。'),('雾气透明度 / 飘动速度','调节天气雾的整体强弱与运动，跟可摆放的雾气图片不是同一个设置。')])) ,
('types','11 种素材分别做什么',table(['分类','用途','动画 / 交互','需要什么图片'],types)+note('树和草的随风效果是贴图形变。尽量将树、草、云与建筑拆成独立透明图片；把树画死在整张背景里，程序无法仅让这棵树独立随风摆动。地图中的“环境树木”也不会自动变为可结果的果树。')),
('layers','图层、移动、缩放与旋转',shot('map-transform.jpg','图层双击后进入对象操作区。画布角点用于等比缩放，外侧圆形箭头用于旋转。')+table(['操作','方法'],[('选择 / 编辑','图层单击选中并同步画布；双击或 Enter 进入操作区。“返回图层列表”回到列表。'),('图层顺序','列表上方覆盖下方。拖动图层，或使用上移、下移、置顶、置底。土地也参与统一排序，作物跟随田块层级。'),('锁定 / 解锁','点击每行左侧锁图标。锁定只限制编辑，不隐藏素材、不停止动画。背景/底色默认锁定，解锁后可排序。'),('移动 / 多选','画布拖动未锁定对象；空白处拖框选择多个；Shift / Ctrl 点选增减，再一起拖动。'),('大小','拖选框角点，或填写等比缩放。素材默认显示高度影响初始大小；背景自动铺满，不手调高度与变换。'),('旋转','拖选框外圆形箭头；Shift 以15°吸附。也可输入角度，左转90°、右转90°或归零。背景和独立光源不使用该旋转方式。'),('复制','按 Alt 拖动，复制图片实例和其配置。田块复制外观，不复制作物存档。'),('微调','方向键移动1逻辑像素；Shift＋方向键移动10像素。'),('撤销 / 重做','Ctrl＋Z；Ctrl＋Y 或 Ctrl＋Shift＋Z。输入框正在编辑时按键优先用于输入。'),('删除图层','选中图层后按 Del，或右侧移除选中对象。锁定对象和仍种有作物的田块会受到保护。'),('删除素材条目','左侧选中素材，用删除所选素材或右键菜单。它不同于删除地图图层，已放置实例和图片文件仍保留。')])+note('背景解锁后允许改图层顺序，但仍保持自动铺满；它不会因此变成可自由拖动缩放的小图片。局部远山或房屋应使用装饰、建筑等类型。画布外的内容会裁切，不显示到作图区域之外。')),
('land','田块形状、选中态与外观',shot('map-land.jpg','土地贴图预览和更换入口在右侧。向下滚动可见形状选择与提亮程度。')+shapes+steps(['在左侧土地分类导入透明PNG，或选择内置耕地，点击<b>新增田块</b>。','选中田块，右侧更换普通态贴图；需要专门的选中画面时再上传选中态。两张图片尽量保持相同画布和对齐。','不上传选中图时，点击<b>选中态改为自动提亮</b>，再调“选中态提亮程度”（0.02～0.35，默认0.12）。自动提亮保留原透明轮廓，不生成灰色底板。','按实际土地轮廓选方形、圆形或自定义。调整田块位置、缩放和旋转，使其与地表贴合。'])+note('<b>形状菜单不会把方形图片自动裁成圆田。</b>它主要决定点击/命中范围；想要圆田或不规则田，需要先准备对应透明轮廓的土地图片。自定义模式按图片透明区域判断点击。')),
('appearance','透明度与阴影怎么调',table(['参数','含义 / 建议'],[('素材透明度','0完全透明，1不透明。图片原本透明的区域仍然透明，设1不会填满PNG背景。'),('阴影强度','0关闭，越大越明显；当前为柔和接触阴影，不是物理场景自动投影。'),('阴影范围','调整根部阴影大小。适合让石头、树、摆件贴地；过大容易变成一团黑雾。'),('阴影距离','相对锚点偏移，单位为逻辑像素。当前允许正负值，负数向所设方向的反向移动。'),('阴影方向','0°向右，90°向下。与距离一起决定阴影落在哪一侧。'),('等比缩放 / 位置','坐标基于1920×1080逻辑地图，不限制桌面只能使用1080P。背景以等比覆盖方式适配画布。')])) ,
('water','水域：画范围，不画一条蓝河',shot('map-water.jpg','水域编辑器：蓝色只是效果范围的编辑辅助标记，桌面中不可见。')+steps(['先用背景或水面贴图提供<b>实际可见的河流/池塘图片</b>。','点击顶部<b>水域标记</b>或左侧<b>绘制 / 修改地图水域</b>。','用画笔、矩形、椭圆或多边形画出水面；用橡皮擦排除桥、岸、树和其他静止物体。多边形逐点点击，完成后点“完成多边形”或右键。','调整方向、速度和边缘柔化，保存水面标记，再保存项目并应用到桌面。'])+table(['选项','解释'],[('画笔大小','控制绘制区域宽度；窄河道用小笔刷。'),('方向','0°向右，90°向下，控制水面运动方向。'),('速度','0～3，调节水流速度；不是风速输入。'),('边缘柔化','0～16，使水域效果在边缘逐渐过渡，避免桥岸切边明显。'),('撤销 / 清空','撤销上一次绘制；清空当前标记草稿。关闭窗口不保存草稿。'),('地图级水域标记','不进入图层列表，决定水流与涟漪生效位置；有地图级标记时优先使用它。')])+note('雨天涟漪在屏幕下方三分之二的有效水域内随机出现。没有可见水面、标记为空，或把河流排除在标记外，都可能让效果看不到。树和作物使用自己的风动画，不因为覆盖水域而一起流动。')),
('lighting','从零给自定义房子加灯',steps(['准备<b>白天关灯外观</b>和<b>夜间开灯外观</b>两张图片：画布尺寸完全相同、物体位置相同、四周透明。夜间图可画亮灯芯/窗内，但尽量不画大面积外溢光晕。','在灯具分类导入，设置昼夜两图后保存素材属性，再新增到地图。若保存被禁用，查看按钮上方原因；尺寸不一致会列出两张图宽高。','选中灯具，右侧添加一个或多个光源。把编号十字移到窗、灯笼或灯泡位置，也可以移到贴图外；素材移动时光源按相对位置跟随。','打开<b>夜景预览</b>，先调光源类型、范围、亮度与颜色，再调本体夜间亮度。','用<b>擦除 / 恢复此光源照明</b>，擦掉墙背面、天空等不应该亮的地方。必要时再标记灯芯自发光区域。','保存当前光源的绘制结果，再保存项目并应用到桌面。'])+shot('map-light-anchor.jpg','一个灯具可以有多个光源；X/Y 是图片相对坐标，可以超出0～1。')+note('“添加单独光源”在灯光分类下，用来创建不绑定图片的光池；它没有自己的昼夜贴图。灯具类型则把图片、相对光源和昼夜外观放在一起。两种方式都能照明，但独立光源不会自动跟随某张图片。')),
('light-options','灯光每个选项的含义',shot('map-light-options.jpg','光源范围、亮度、颜色和四个开关，以及擦除、灯芯标记、替换贴图入口。')+table(['选项','实际作用'],light_rows)+note('这里的照明是对二维画面的柔和加亮与遮罩控制。程序不会自动理解房子的墙、窗、遮挡关系；“不该亮的地方”用擦除来处理。原图自带的亮面、光晕不会随动态光源移动，也不能通过擦除动态光自动消除。')),
('paint','画出该亮与不该亮的区域',flow(['选择一个光源','擦除 / 恢复照明','擦掉不该亮处','保存灯光','保存项目并应用'])+table(['绘制项','如何使用'],[('擦除灯光','把当前光源在笔刷区域的照明减弱或移除，不删除底下图片。'),('恢复灯光','把误擦的照明恢复，不修改其他灯。'),('画笔大小','8～300逻辑像素，先大范围处理，再用小笔刷修边。'),('柔和度','0.05～1。越大边缘越软；墙边精修用较小值，地面渐变用较大值。'),('擦除 / 恢复强度','0.05～1。低强度可多次叠加，适合柔和过渡；1接近一次完全处理。'),('显示擦除标记','叠加辅助标记查看已擦区域，便于找漏涂；不是最终壁纸颜色。'),('恢复画面内受光','清除可见画面内的擦除限制，重新按光源衰减照明；不改别的光源。'),('亮度 / 范围 / 颜色','绘制时可同步微调该光源；直射光的范围项不适用。'),('保存灯光 / 取消','保存只写回当前地图草稿，还需保存项目。取消或关闭窗口不提交这次绘制。')])) ,
('faq','常见问题与完成检查', '<div class="faq">'+''.join(f'<details><summary>{q}</summary><p>{a}</p></details>' for q,a in [
('为什么换背景后某些旧建筑还在？','示例原画中的建筑如果没有拆分，仍是背景的一部分。想彻底换风格，从新建空白项目开始，用新背景与独立素材搭建。'),
('为什么树不随风？','确认导入类型为环境树木，启用类型对应动画；树必须是独立素材，而不是整张背景上的绘画。编辑器主要显示布局，应用后的桌面才是风与水动画的最终显示。'),
('为什么土地选中外观没有改变？','自定义选中贴图优先；想使用滑块提亮，先选择“选中态改为自动提亮”。需要保留透明PNG边缘。'),
('为什么光看起来飘在图片后或亮错位置？','先确认使用新版程序并应用项目；检查光源锚点与相对坐标、是否勾选穿透所属贴图。用擦除限制受光，避免在原图提前画大光晕。'),
('保存属性无法点击怎么办？','看按钮上方的错误原因。灯具两图必须齐全、能读取、尺寸一致、参数有效。不要仅凭文件名判断大小。'),
('完成前应检查什么？','检查图层排序、背景解锁状态、透明边缘、田块点击范围、水域遮罩、昼夜两图与光照，再保存并应用。建议先复制已有项目再进行大改。')])+'</div>'),
]

crop_ids=['seed','seed_dry','seed_dead','sprout','sprout_dry','sprout_dead','half','half_dry','half_dead','mature','harvested','withered']
crop_names=['种子','种子缺水','种子死亡','幼苗','幼苗缺水','幼苗枯萎','半成熟','半成熟缺水','半成熟枯萎','成熟','采收','残株枯萎']
crop_notes=['播种后正常形态；种子也需要水。','可救分支，及时浇水可恢复。','死亡终止，需要清理再播种。','正常生长阶段。','缺水分支，浇水恢复。','死亡分支，不能当作下一成长阶段。','正常生长阶段。','缺水分支，浇水恢复。','死亡分支，清理后重新播种。','可采收；可设置成熟后未采收的等待时限。','采收事件后的无果形态；不是再次播种。','成熟未摘取枯死与采后枯萎共用此图。']
tree_ids=['dormant','budbreak','sprouting','leafy','buds','flowering','fruit_set','young_fruit','swelling','mature','harvested','leaf_fall']
tree_names=['秃树 / 休眠','萌芽','发芽','展叶 / 正常','花苞','开花','谢花 / 坐果','小果','多果 / 膨果','成熟','采摘','凋零 / 落叶']
tree_notes=['种下就是树；休眠期间不产出。','枝条出现芽点。','嫩叶展开。','树冠恢复，无花无果。','花苞出现，准备开花。','开花外观；当前没有授粉操作。','花谢，出现极小果。','幼果期。','果实逐渐长大。','此阶段可采收。','采后无果/少果，进入后续循环。','落叶，周期回到秃树；死亡时也可能使用此外观。']

def tree_svg(stage):
    branches='<path d="M80 136L80 75M80 101L46 69M80 86L110 51M80 75L61 43M80 117L112 84" fill="none" stroke="#826b4e" stroke-width="8" stroke-linecap="round"/>'
    points=[(40,60),(63,40),(86,40),(111,48),(124,71),(101,83),(62,79),(77,63),(44,83)]
    art=''
    if stage>=2:
        for j,(x,y) in enumerate(points):
            if stage==11 and j%2: continue
            color='#b5ad5e' if stage==11 else '#789460'
            r=8 if stage==2 else 18
            art+=f'<ellipse cx="{x}" cy="{y}" rx="{r}" ry="{r*.8}" fill="{color}" opacity=".95"/>'
    if stage==1:
        for x,y in points[:6]: art+=f'<circle cx="{x}" cy="{y}" r="4" fill="#99a46c"/>'
    if stage in [4,5,6,7,8,9]:
        for j,(x,y) in enumerate(points[:7]):
            if stage==4: art+=f'<circle cx="{x}" cy="{y}" r="4" fill="#cb9aa0"/>'
            elif stage==5:
                for dx,dy in [(0,-5),(5,0),(0,5),(-5,0)]: art+=f'<circle cx="{x+dx}" cy="{y+dy}" r="4.3" fill="#f4e4d8"/>'
                art+=f'<circle cx="{x}" cy="{y}" r="2.5" fill="#dcbd71"/>'
            else:
                r={6:2.5,7:4,8:6,9:7}[stage]; color='#ce8053' if stage==9 else '#a6b75b'
                art+=f'<circle cx="{x}" cy="{y+3}" r="{r}" fill="{color}" stroke="#768052" stroke-width=".6"/>'
    return '<svg viewBox="0 0 160 160" role="img" aria-label="'+tree_names[stage]+'示意"><ellipse cx="80" cy="138" rx="39" ry="6" fill="#d0d7bf"/>'+branches+art+'</svg>'

user=Path(os.environ['APPDATA'])/'Godot/app_userdata/苔屿 · 桌面微观农场'
registry=json.loads((user/'crop-editor/index.json').read_text(encoding='utf-8-sig'))
rose_path=user/registry['rose'].removeprefix('user://')
rose=json.loads(rose_path.read_text(encoding='utf-8-sig'))
crop_cards='<div class="cards">'
for i,(key,name,desc) in enumerate(zip(crop_ids,crop_names,crop_notes)):
    path=rose_path.parent/rose['assets'][key]['file']
    crop_cards+=f'<article class="card"><div class="art"><img loading="lazy" src="{uri(path)}" alt="玫瑰{name}实际贴图"></div><div class="body"><b>{i+1:02d} · {name}</b><code>{key}</code><p>{desc}</p></div></article>'
crop_cards+='</div>'
tree_cards='<div class="cards">'+''.join(f'<article class="card"><div class="art">{tree_svg(i)}</div><div class="body"><b>{i+1:02d} · {tree_names[i]}</b><code>{tree_ids[i]}</code><p>{tree_notes[i]}</p></div></article>' for i in range(12))+'</div>'

def atlas(names):
    return '<div class="atlas">'+''.join(f'<div><strong>{i+1:02d}</strong>{n}</div>' for i,n in enumerate(names))+'</div>'

general_rows=[('全局最低 / 最高适温','没有阶段专用范围时的回退温度；最低值必须小于最高值。','℃'),('播种最低 / 最高温','种子阶段及种下时使用的温度范围，不等同于成年植株适温。','℃'),('不适温死亡时间','持续/累计不适温达到阈值后死亡；恢复适温后伤害可按配置恢复。不是一低于温度就立刻死亡。','真实日'),('不适温成长系数','0暂停温度不适时的成长；1保持正常成长速度，中间值减速。','0～1'),('土壤储水容量','田块可保留的水量上限。','mm'),('播种初始水量','播种后起始水量。设0会需要尽快浇水，可能一开始就显示缺水。','mm'),('每次浇水量','每次点击浇水增加的水量，最终不超过容量。','mm'),('缺水预警水量','低于阈值出现缺水外观；仍可能高于停止成长阈值。','mm'),('成长最低水量','低于此阈值时使用干旱成长系数；不等同于已经死亡。','mm'),('雨水吸收系数','控制有效降雨转为土壤水量的比例，不是雨滴视觉大小。','0～1'),('每次收获数量','一次采收记入库存的数量。','整数'),('成熟未采收枯萎时间','普通作物成熟后可以等待多久；0关闭此时间限制。果树的成熟等待主要由状态页成熟阶段时长控制。','真实日'),('采后枯萎等待时间','普通作物收获后先显示采收图，再转为残株枯萎；果树按循环阶段运行。','真实日'),('随风摇曳幅度','非种子植株的形变幅度；0关闭。还受实时风速、风向影响。','0～0.1'),('种子摇曳幅度','只控制种子形态，通常设0。','0～0.1')]

crop_sections=[
('start','新建一个植物的完整流程',shot('crop-list.jpg','打开后是带Logo的作物列表。双击编辑，或从左上角新增作物 / 新增果树。')+steps(['从托盘或设置进入<b>作物编辑器</b>，选择<b>＋新增作物</b>或<b>＋新增果树</b>。','填写名称和唯一编号。编号建议英文开头，仅用字母、数字、下划线，例如<code>lavender_v1</code>。保存后已有编号和类型会固定。','导入12张状态图，或一张平均排布的<b>6×2图集</b>；可上传独立Logo，未上传时复用成熟图。','逐个检查状态图片和独立缩放；设置各正常成长阶段/果树阶段的真实天数、耗水、完全干土死亡时间与适温。','到<b>生长温度 · 浇水与收获</b>填写全局温度、水量、产量、枯萎等待和摇曳幅度；需要细项时查看全部参数JSON。','点击<b>保存并应用</b>。保存成功后返回列表，播种选择与场景外观同步刷新，一般无需重启。'])+note('本编辑器不会根据植物名称自动查出真实农艺周期。新建值是配置模板，需要按你采用的品种与模拟规则填写；不能把模板默认天数当作该物种的真实周期。')),
('types','两种类型与图片数量',table(['类型','图片要求','成长 / 采收逻辑','适用对象'],[('作物 · 单次采收','12张状态图 + 可选1张Logo；或1张6×2图集 + 可选Logo。','正常主线种子→幼苗→半成熟→成熟；缺水、死亡是分支；收获后残株需要清理再播种。','玉米、棉花、小麦、辣椒、西红柿、烟叶、玫瑰等。'),('果树 · 循环结果','12张树阶段图 + 可选1张Logo；或1张6×2图集 + 可选Logo。','种下就是树；12阶段循环。成熟可采收，采后进入采摘外观，再落叶、休眠、重新生长。','需要重复结果、保留树体的自定义果树。')])+shot('crop-new.jpg','新建作物：名称、编号、类型与三个参数页；状态图片尚未上传时预览为空。')+note('当前只有这两种类型，没有独立的“多年生花卉/灌木”第三类型。地图编辑器的“环境树木”只是景物，不进入这里的种植与收获循环。')),
('images','图片准备：12张单图或6×2图集',table(['要求','说明'],[('推荐格式','使用透明PNG，尤其是叶片和根部。文件选择也支持WebP/JPG等，但JPG不保留透明背景，编辑器不会自动抠图。'),('相同画布与位置','所有阶段使用同一构图尺度、同一根部基线，保证切换不跳位置；幼苗本来就应小于成年植株，不要把每一株都拉满画面。'),('6×2图集','严格6列2行、平均单元格，按左→右、上→下排列。图片尺寸最好宽能被6整除、高能被2整除；程序按网格切分，不自动识别每个物体。'),('保存后输出','统一保存为512×512透明PNG，以共同缩放基准、水平居中、根部靠下对齐；单个状态的独立缩放单独保存。'),('独立缩放','每个状态0.05～10。只调整显示比例，不改变保存文件的512×512尺寸，也没有横向/纵向分别拉伸。'),('Logo','上传可选的正方形透明小图；可以独立于状态画布。未上传时使用成熟图作为Logo。')])+note('规范化画布不是自动修复所有图片：如果原图含大块白底、物体被切断、根部在不同位置，仍应先处理源图。重复保存已规范化图片不会反复缩小。')+shot('crop-example.jpg','已配置的玫瑰示例：同一个状态有独立缩放；种子保持比成年形态小。')),
('crop-states','作物的12种状态图', '<p>下列缩略图来自当前项目里实际保存的<b>玫瑰状态素材</b>。种子缺水等部分形态可以十分接近，仍需对应到正确槽位。</p>'+crop_cards+'<h3>6×2图集必须按这个顺序</h3>'+atlas(crop_names)+'<h3>真正的成长主线</h3>'+flow(['种子','幼苗','半成熟','成熟','采收','残株枯萎','铲除 / 重新播种'])+note('主线中的种子、幼苗、半成熟需要成长时长；成熟状态由采收与等待规则控制，不把12张图当成12段连续成长。缺水图是可恢复分支，死亡图在当前实现中为终止状态，浇水不会使死亡植株复活。')),
('tree-states','果树的12个阶段与循环',shot('crop-tree.jpg','新建果树：每个阶段都可以设置独立图片、缩放、阶段时长、耗水和适温。')+'<p>下图是<b>阶段含义示意图</b>，不是程序附带的一套果树贴图；创建实际果树时，需要上传你自己的12张同风格图片。</p>'+tree_cards+'<h3>果树6×2图集顺序</h3>'+atlas(tree_names)+flow(['休眠','萌芽 / 发芽 / 展叶','花苞 / 开花','坐果 / 小果 / 膨果','成熟可收获','采摘后','落叶','回到休眠'])+note('果树成熟后若不采收，阶段到期会直接进入落叶，不会自动给库存发果。采收则进入采摘阶段，再继续循环。极端缺水或温度伤害仍能造成死亡；看到落叶图不一定表示正常季节落叶，需看田块健康说明。')+'<p>低温休眠区间在全部参数中的<code>dormancy_min_c</code>与<code>dormancy_max_c</code>配置；只有有效温度观测才触发。当前没有自动按月份切换四季素材、授粉、施肥、疏果或品质计算；阶段名只描述外观与成长进度。</p>'),
('stage-settings','每张状态卡片如何填写',table(['字段','作用','如何理解'],[('选择状态图片','替换当前槽位图片。','只改这一状态；导入6×2图集会分配全部12个槽位。'),('独立缩放','统一画布上的显示倍率。','用成熟图作比较，再让幼苗保持合理比例；不要靠缩放修复位置未对齐的原图。'),('阶段时长（真实日）','普通作物的种子、幼苗、半成熟，以及果树所有阶段都有时长。','1=24小时，0.5=12小时。普通作物不在缺水/死亡图上设置成长天数。'),('耗水 mm/日','当前正常阶段每日消耗土壤水量。','不同阶段可不同；休眠期通常更低，但由你的参数决定。'),('完全干土死亡天数','土壤真正到0后，持续多久会死亡。','不是一显示缺水就开始按这个阈值死亡；0表示关闭该干旱死亡计时。'),('最低 / 最高适温','阶段的温度容许范围。','非种子阶段优先使用阶段范围；种子与种下时使用全局播种范围。最低要小于最高。')])+note('示例：普通作物阶段设7天、30天、53天，正常温度和水分下约90天到成熟。缺水或低温暂停成长时，实际等待会更长。耗水和死亡阈值是可配置模拟，不是植物真实个体的精确预测。')),
('general','温度、浇水、收获与风',shot('crop-parameters.jpg','常用参数页：全局适温、播种温度、水量阈值、雨水吸收及收获设置。')+table(['参数','含义','单位'],general_rows)+note('温度系统使用获取到的有效天气观测，不会把一次当前温度当作整段离线历史。生长时间、土壤耗水与气候伤害是不同计算，不能仅靠雨滴视觉判断田块含水量。')+'<h3>水分判断顺序</h3>'+flow(['水量充足','低于预警：显示缺水','低于成长阈值：减慢/暂停','完全干土达到死亡时长：死亡'])+'<p>正常浇水可以救回尚未死亡的缺水植株。风速与风向来自天气；非种子植株的摇曳幅度由植物配置与天气共同控制，果树没有种子形态，也按树的阶段外观摆动。</p>'),
('advanced','全部参数与两季播种', '<p>第三个标签页显示JSON，包含<code>description</code>、<code>temperature</code>、<code>watering</code>、<code>harvest</code>、<code>render</code>、<code>sowing</code>等。常用参数页会把修改同步写回这份JSON；直接改JSON后，应确认格式和各数值关系有效再保存。</p>'+table(['项目','用途'],[('description / simulation_notes','写植物说明、采用的周期依据及模拟简化。'),('sowing.recommended_months','建议播种月份列表，配合label与badge显示。月份是提示，不禁止在其他月份种植；温度条件另行判断。'),('春小麦 / 冬小麦','需要不同周期和适温时，用不同编号各建一个作物，如wheat_spring与wheat_winter；不是一个编号自动切换整套季节参数。'),('temperature.recovery_per_second','恢复适温后温度伤害的恢复速率；不要误当作成长速度。'),('watering.dry_growth_factor','低水量时的成长倍率；0暂停。'),('harvest.unit','库存产量的显示单位，例如份、个。'),('render.columns / rows','每块田的株数布局；当前使用1×1。改动会影响显示排布。'),('dormancy_min_c / max_c','果树低温休眠区间，不能代替所有阶段的适温。')])+'<h3>播期字段示例</h3><pre>'+html.escape(json.dumps({'sowing':{'label':'春秋均可参考','badge':'春秋','recommended_months':[3,4,9,10],'note':'月份仅建议，按当地气候调整。'}},ensure_ascii=False,indent=2))+'</pre>'+note('常用参数页的等待时间单位是“日”，但JSON中以<code>_seconds</code>结尾的字段单位是秒。1日=86400秒，1小时=3600秒。不要把“7天”直接写成7秒。')),
('save','保存、删除、导出与数据保护',steps(['完成全部12张状态图，并核对名称、编号、类型、时间、水分、温度和收获参数。','点击<b>保存并应用</b>。成功后目录索引指向永久植物包，下载目录中的原图不再是运行依赖。','在桌面背包选择该植物播种；仓库或田块说明会展示温度、周期与产量等资料。','需要分享或备份时，打开<b>仓库</b>，选择植物并使用<b>导出作物包</b>入口（不是作物编辑器中的顶部按钮）；包内包含配置和使用到的图片。'])+note('已有植物编号与类型固定。植物仍被任何项目的种植、库存或归档引用时，不能删除，也不能改类型或总生长周期；可以新建另一个编号来尝试不同周期。删除是目录隐藏标记，原包与旧版本保留。')+table(['位置','保存内容'],[('user://crop-editor/index.json','自定义植物的目录索引与删除标记。'),('user://crop-editor/packages/&lt;编号&gt;/&lt;版本&gt;/','永久的配置、12张规范化图片与可选Logo。'),('托盘 → 打开存档目录','user://对应当前用户数据目录，不是build目录。备份建议保存整个相关目录。')])) ,
('faq','常见问题', '<div class="faq">'+''.join(f'<details><summary>{q}</summary><p>{a}</p></details>' for q,a in [
('为什么种下马上缺水？','检查播种初始水量。如果设为0，就会需要立即浇水；想让新播种自带少量水，可设置初始水量，但不能超过土壤容量。'),
('为什么按图集导入后状态顺序错了？','编辑器按6列2行平均切分，不会识别内容；按本手册两种类型各自的顺序重新排图，避免沿用旧的11图/12图排列。'),
('为什么一个植物不同阶段大小跳动？','先统一图片画布和根部位置，再调整各状态的独立缩放。统一512×512文件尺寸并不意味着每个状态的植株像素高度相同。'),
('为什么缺水阶段不能设置成长时长？','缺水和死亡是分支，不按这12张图依次推进。等待时间设置在正常阶段的耗水、干土死亡阈值及全局收获等待里。'),
('为什么保存提示缺图或配置无效？','需要补齐全部12个槽位。检查JSON格式、适温上下限、阶段天数、水量阈值和收获设置；错误原因会显示在窗口底部状态文字中。'),
('为什么无法删除或改变周期？','还有种植、库存或其他地图归档引用。先处理相关引用，或新增一个不同编号；不要直接删除包文件。'),
('果树开花是不是要我授粉？','当前没有授粉、施肥、疏果和果品品质操作。这些只是阶段名称和视觉含义，不能理解为已加入新玩法。')])+'</div>'),
]

OUT.mkdir(parents=True,exist_ok=True)
(OUT/'地图编辑器使用手册.html').write_text(document('地图编辑器使用手册','从一张空白地图开始，把背景、土地、树木、水域和灯光组合成自己的桌面景色。',map_sections,('作物编辑器使用手册.html','作物编辑器手册')),encoding='utf-8')
(OUT/'作物编辑器使用手册.html').write_text(document('作物编辑器使用手册','看懂两种植物类型、12张状态图，以及每个阶段的真实时间、温度、水分和采收设置。',crop_sections,('地图编辑器使用手册.html','地图编辑器手册')),encoding='utf-8')
for path in OUT.glob('*.html'): print(str(path),f'{path.stat().st_size/1024/1024:.2f} MB')
