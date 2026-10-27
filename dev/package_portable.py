"""Package saved environment content, excluding personal progress and caches."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
from datetime import datetime

parser=argparse.ArgumentParser()
parser.add_argument('--user-data', type=Path, default=Path(os.environ['APPDATA'])/'Godot/app_userdata/苔屿 · 桌面微观农场')
parser.add_argument('--output', type=Path, default=Path(__file__).resolve().parents[1]/'build')
args=parser.parse_args()
root=Path(__file__).resolve().parents[1]
source=Path(os.path.abspath(args.user_data))
out=args.output.resolve()
seed=out/'initial-data'
refs=set()

def collect(value):
    if isinstance(value,dict):
        for child in value.values(): collect(child)
    elif isinstance(value,list):
        for child in value: collect(child)
    elif isinstance(value,str) and value.startswith('user://'):
        refs.add(value)

def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))

def copy_content(relative):
    # Windows packaged-app redirection may resolve individual files into
    # LocalCache/Roaming. Bound the requested relative path, not that OS target.
    src=Path(os.path.abspath(source/relative))
    if not src.is_relative_to(source): raise RuntimeError('Content outside user directory: '+str(src))
    if not src.is_file(): raise RuntimeError('Missing content: '+str(src))
    dst=seed/relative
    dst.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(src,dst)
    if src.suffix=='.json': collect(read(src))

if seed.exists() and any(seed.iterdir()): raise RuntimeError('initial-data already exists; use a clean output directory')
seed.mkdir(parents=True,exist_ok=True)
for name in ['active-layout.json','active-project.json','materials.json','project-migration.json']:
    relative=Path('maps')/name
    if (source/relative).exists(): copy_content(relative)
projects=list((source/'maps/projects').glob('*/project.json'))
for project in projects:
    copy_content(project.relative_to(source))
    # Ship saved layouts only. Farm progress, inventory and drafts stay private.
    preview=project.parent/'preview.png'
    if preview.exists(): copy_content(preview.relative_to(source))
index=source/'crop-editor/index.json'
if index.exists():
    copy_content(index.relative_to(source))
    for package in read(index).values():
        if package=='deleted': continue
        if not str(package).startswith('user://crop-editor/packages/'):
            raise RuntimeError('Unexpected crop package path: '+str(package))
        relative=Path(package.removeprefix('user://'))
        crop=read(source/relative)
        copy_content(relative)
        for asset in crop['assets'].values(): copy_content(relative.parent/asset['file'])
done=set()
while refs-done:
    ref=next(iter(refs-done))
    done.add(ref)
    if not (ref.startswith('user://maps/materials/') or ref.startswith('user://crop-editor/packages/')):
        raise RuntimeError('Unexpected bundled reference: '+ref)
    copy_content(Path(ref.removeprefix('user://')))
for crop in (out/'crops').glob('*/crop.json'):
    value=read(crop)
    for asset in value['assets'].values():
        path=(crop.parent/asset['file']).resolve()
        if not path.is_relative_to(crop.parent.resolve()) or not path.is_file():
            raise RuntimeError('Missing or invalid external crop asset: '+str(path))
manuals=out/'使用手册'
manuals.mkdir(exist_ok=True)
for path in (root/'docs/使用手册').glob('*.html'): shutil.copy2(path,manuals/path.name)
readme='''苔屿 · Windows x64 便携版

一、如何启动
1. 把整个文件夹解压或复制到本机一个固定目录。
2. 双击 MossIsland.exe。启动后显示桌面壁纸与系统托盘图标。
3. 不要只复制一个EXE，不要从压缩包内部直接运行。
4. 托盘可解锁桌面、打开设置、地图编辑器、作物编辑器与仓库。
5. 退出时选择托盘“保存并退出”。首次启动可能需要生成着色器缓存。

二、运行环境
适用于 Windows 10/11 64位桌面环境。无需安装 Python、Godot 或项目源码。
Windows 需要具备 .NET Framework 4.8 桌面运行组件（Windows 10/11通常自带），
并安装支持 Vulkan 的显卡驱动；当前壁纸使用 Vulkan 渲染。
不保证远程桌面、虚拟机或缺少兼容显卡驱动的机器能正常显示壁纸。
本包未在另一台实体电脑上验证。

三、目录内容
MossIsland.exe       主程序与系统托盘；只需要从这里启动。
MossImmersive.exe    壁纸与编辑器渲染程序（引擎、脚本、内置资源已嵌入）。
DesktopBridge.exe   原生桌面挂载、输入与多屏适配组件。
crops/              可编辑的作物配置与图片，必须完整保留。
initial-data/       随包地图、自定义素材和自制植物配置；必须保留以供首次启动导入。
使用手册/           两份离线HTML手册，图片已内嵌。
third-party/ 与 THIRD_PARTY.md  第三方素材来源与声明，请一并保留。
release-manifest.json  本次构建时间、文件清单与SHA-256校验值。

四、初始内容与存档
新电脑首次启动会将随包内容复制到当前Windows用户的数据目录。
已存在地图、植物或种植存档的用户不会被初始内容覆盖。
本包包含打包时已保存的地图和自定义植物；不包含个人种植进度、库存、
天气缓存、定位、开机自启设置和编辑器未保存草稿。
地图素材仍以相对的user://路径引用，无需保留原电脑的下载目录或E盘目录。
存档实际保存在：%APPDATA%\\Godot\\app_userdata\\苔屿 · 桌面微观农场
可从托盘打开存档目录。程序文件夹可复制，运行后的存档按Windows用户分别保存。
如需搬迁自己的种植进度，请先在两端退出程序，再备份和复制整个存档目录。
新位置启动后若需要开机自启，请在托盘重新设置；固定好程序目录后再开启。

五、使用方法
打开“使用手册”目录中的地图编辑器使用手册.html、作物编辑器使用手册.html。
两份文档均可离线打开、搜索、放大截图和打印。

打包时未运行功能测试，仅进行重新编译、导出与包内文件依赖检查。
'''
(out/'运行说明.txt').write_text(readme,encoding='utf-8-sig')
manifest={'product':'苔屿 · 桌面微观农场','platform':'Windows x64','built_at':datetime.now().astimezone().isoformat(timespec='seconds'),'entry_point':'MossIsland.exe','build_type':'clean portable folder','content':{'projects':len(projects),'fresh_user_seed':True,'personal_progress_included':False},'validation':'compile/export/package dependency checks; no functional tests or second-machine validation','files':[]}
for path in sorted(out.rglob('*')):
    if path.is_file() and path.name!='release-manifest.json':
        manifest['files'].append({'path':path.relative_to(out).as_posix(),'bytes':path.stat().st_size,'sha256':hashlib.file_digest(path.open('rb'),'sha256').hexdigest()})
(out/'release-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'projects':len(projects),'referenced_content_files':len(done),'release_files':len(manifest['files']),'megabytes':round(sum(f['bytes'] for f in manifest['files'])/1024/1024,1)},ensure_ascii=False))
