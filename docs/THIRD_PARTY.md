# 第三方依赖

| 名称 | 固定版本 / 来源 | 许可与用途 |
| --- | --- | --- |
| Godot Engine | 4.6 stable, official 89cea1439 | MIT；3D、界面、Windows 导出。https://godotengine.org/license/ |
| .NET Framework | Windows 内置 v4.0.30319 编译工具，目标 .NET Framework 4.x | Microsoft Windows 组件许可；只运行 Windows 桌面桥接辅助进程，不承载业务代码 |
| Open-Meteo | HTTPS Forecast API v1 | 天气数据 CC BY 4.0，https://open-meteo.com/ 。免费接口限非商业用途；商业发布需根据服务条款配置商业端点。 |
| NOAA Solar Calculator | fractional year / equation of time / declination 方程 | 本项目自行用 GDScript 实现公开方程；未引入第三方计算库。https://gml.noaa.gov/grad/solcalc/solareqns.PDF |
| Microsoft YaHei UI | 用户系统已安装字体 | 通过 SystemFont 引用，不复制或重新分发字体文件。没有该字体时使用系统回退字体。 |

历史 0.4.x 按用户指定接入 [henjicc/yipiantian](https://github.com/henjicc/yipiantian) 的三维模型与贴图，固定源码快照 `f816a91242d6bb607aeb80f1cd2c12507fee66b2`。素材清单、原路径、字节数与上游 Git LFS SHA256 校验见 `assets/reference/source-manifest.json`。包括房屋、树、桂花、竹、船、荷花、三种岸石、土壤纹理和两种作物。原作者的制作记录位于该仓库 `ArtSource/Environment/README.md` 及各资产子目录，模型主要来自 Tripo 生成与 Blender 整理；本项目保留模型与原贴图。

上游仓库未发现覆盖这些素材的通用开源许可。此次按用户要求用于本地开发和效果审阅，不将其标记为 MIT/CC0，也不声明已取得商业发布或再分发授权。上游源码归档位于被忽略的 `tools/reference/yipiantian-main`，不随运行包导出。

桌面交互架构参考该项目的“壁纸层不脱离、过滤桌面图标、转发鼠标”方案，当前 C# 实现由本工程编写。月亮位置采用 Paul Schlyter 公布的低精度轨道元素，自行实现 GDScript；省略摄动与地心视差，仅供环境表现，参考 https://stjarnhimlen.se/comp/ppcomp.html 。月相采用平均朔望月近似。未复制外部算法库。

2.0.0 已移除上述参考素材的运行时加载与发布包导出，模型改由本工程程序化构建，使用小尺寸笔触纹理与顶点颜色。原始参考素材仍留在开发目录以便回溯。

其他模型、图标、UI 与环境音沿用本工程代码生成内容；应用运行无需浏览器、Git 或在线素材服务。

Godot Engine is licensed under the MIT license:

Copyright (c) 2014-present Godot Engine contributors.
Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## 2.1.0 手绘样板素材

- Drummyfish，[4 hand-painted ground textures](https://opengameart.org/content/4-hand-painted-ground-textures)，CC0：采用 grass_34.png，作为地表笔触与明度调制。
- MELLE / Melissa Krautheim，[handpainted stone way-texture](https://opengameart.org/content/handpainted-stone-way-texture)，CC0：采用 stone way- texture_0.png 与 dirt-texture_0.png，分别用于石路和土粒调制。
- 屋瓦/木纹/灰泥/岩石等八分区图集，以及透明柳枝，为本工程使用 imagegen 生成并筛选的纹理，未提取《梦幻西游》游戏资源。
- 农舍曲面、树干、叶片卡、卷曲菜叶和自然土畦为本工程 GDScript 定制几何，不标记为网上下载的 3D 模型。检索过现成模型，但未将不匹配的简单色块模型纳入样板。

完整原始链接、文件校验、用途和导入尺寸见 assets/painted/source-manifest.json。项目采用的网上素材都有公开下载入口；上面两套纹理在作者页面均标记 CC0。

## 2.2.0 两岸田园与果树素材

远山背景、柑橘树冠透明叶片和草地笔触为根据用户提供的效果图生成的原创纹理；仅远景使用画面背景，当前原型的农舍、河道、石桥、田畦与果树仍为运行时几何。素材来源、校验与导入上限见 source-manifest.json。用户要求继续向效果图一比一对齐，最终呈现方式仍在确认，不能将当前原型描述为逐像素还原。

## 2.2.0 原图分层版（最终采用）

用户确认画面一致优先，采用原图分层的 2.5D。assets/illustrated/reference.png 为用户提供的原图，保留原始文件及校验；empty-garden.png 是 imagegen 清除可生长植物后的补底；tree-stages.png 和 crops.png 为同风格透明精灵。运行时只在种植/果园区域合成补底，其他静态区域采样原图，动态植物独立绘制。没有提取商业游戏素材。文件校验和导入上限见 assets/illustrated/source-manifest.json。

先前的两岸 3D 尝试已退出运行时，开发草稿归档在 tools/reference/river-3d-v220-prototype.gd。2.2.0 最终效果以分层版实际截图为准。

## 2.3.0 模块化草地底图

modular-meadow.png 由 imagegen 编辑现有 empty-garden.png，清除烘焙田块和花坛，保留两岸山水庭园构图；独立土地使用已有 MELLE 土壤纹理加程序化土粒调制。来源、校验与编辑指令摘要见 assets/illustrated/source-manifest.json 和 docs/ASSET-GENERATION-v230.md。2.3.0 运行时使用这一草地底图与可交互方形田块，不再合成旧图中的长条田畦。

## 2.4.0 用户土地素材与月夜图层

用户下载目录中的耕地.png、耕地选中.png 经内置 image_gen 去除纸背景后，保存为 soil-normal.png、soil-selected.png。月夜图层 moonlit-meadow.png 由同一工具对现有 modular-meadow.png 作光照重绘，增加月光受光层次与亭内暖光。完整提示词与路径见 docs/ASSET-GENERATION-v240.md，校验见 assets/illustrated/source-manifest.json。没有下载或提取商业游戏素材；用户原图未被覆盖。

## 2.5.0 区县位置目录

全国三级目录和主要行政边界采用 xiangyuecn/AreaCity-JsSpider-StatsGov 2025.251231.260403，MIT，完整许可见 third-party/AreaCity-MIT.txt。台湾乡镇边界来自 titaneric/Taiwan-GeoJSON，原始来源为政府开放行政边界，镜像仓库未独立声明许可。新增三县边界来自 OpenStreetMap contributors，经 Nominatim 获取，ODbL 1.0，版权及许可见 https://www.openstreetmap.org/copyright 与 https://opendatacommons.org/licenses/odbl/1-0/ 。原始请求地址、派生文件校验和坐标处理见 data/regions-source.json。上述数据用于本地归属匹配，不将行政边界渲染为地图。
