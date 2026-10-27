# 新增作物与播种季节

本次新增小麦、辣椒、西红柿、烟叶四类植物。小麦分春小麦、冬小麦两个独立种子选项、配置与库存，使用同一张小麦图集和图标，背包小角标“春／冬”帮助区分。

| 配置目录 | 作物 | 参考周期（从播种起） | 建议播种月份 | 生长适温 | 播种适温 |
| --- | --- | --- | --- | --- | --- |
| wheat_spring | 春小麦 | 120天 | 2—5月 | 4—28°C | 2—22°C |
| wheat_winter | 冬小麦 | 250天 | 9—12月 | 4—28°C，越冬另有范围 | 2—22°C |
| pepper | 辣椒 | 150天 | 3—6月 | 15—32°C | 20—30°C |
| tomato | 西红柿 | 130天 | 2—6月 | 12—32°C | 18—30°C |
| tobacco | 烟叶 | 180天 | 2—5月 | 15—32°C | 20—30°C |

上述为配置默认值，不是所有地区、品种都适用的固定成熟日期。建议月份采用中国北半球通用参考，仅提示，不禁止播种；实际气温仍按温度系统判断。改程序旁 `crops/<目录>/crop.json` 后重启即可调整。每块田默认1株；非种子阶段统一放大30%，种子大小不变。

## 小麦两种播期

春小麦阶段依次为种子7天、幼苗23天、分蘖拔节30天、抽穗开花30天、灌浆30天，之后成熟待收。

冬小麦为种子7天、冬前幼苗28天、越冬分蘖105天、返青拔节45天、抽穗开花30天、灌浆35天。冬前幼苗的阶段耐温为−5至25°C；越冬阶段为−12至20°C，参考耗水0.4mm/天。阶段温度优先于全局生长温度，避免冬季幼苗直接套用暖季作物规则。

冬小麦通常秋播越冬，并非在任何严寒天气都适合直接播种，也不是同一株小麦一年收两次。实际冬小麦有春化、积温、抗寒锻炼等条件；当前采用固定越冬日历阶段和阶段耐温近似，没有模拟这些机制，不能据此预测现实田间越冬结果。

参考：[农业农村部小麦秋冬种技术意见](https://zzys.moa.gov.cn/tzgg/201309/t20130912_6310559.htm)、[春小麦生长发育指南](https://extension.umn.edu/agriculture/crop-production/small-grains/spring-wheat-growth-and-development-guide)、[冬小麦耐寒与春化说明](https://extension.umn.edu/agriculture/crop-production/small-grains/plant-winter-hardy-adapted-varieties)。各地适期不同，例如[北京地区秋播指导](https://www.beijing.gov.cn/fuwu/bmfw/sy/jrts/202509/t20250924_4209166.html)采用更窄的当地窗口，配置中的月份范围不能取代当地农时。

## 辣椒、西红柿、烟叶

辣椒采用播种至出苗10天、幼苗46天、长大30天、开花结果44天、转红20天。西红柿为7、35、28、40、20天。幼苗期包含现实常见育苗过程，不能直接把种子袋上“移栽后成熟天数”当作播种至成熟的总时间。参考[蔬菜育苗时间](https://extension.usu.edu/yardandgarden/research/grow-your-own-transplants-at-home)、[辣椒育苗建议](https://extension.umd.edu/resource/growing-peppers-home-garden)与[蔬菜采收参考](https://yardandgarden.extension.iastate.edu/how-to/vegetable-harvest-guide)。

烟叶采用种子10天、幼苗50天、团棵伸根60天、旺长展叶30天、叶片成熟30天，含约60天育苗和120天田间生长期的可调整参考。参考[陕西地方志烟草育苗记载](https://dfz.shaanxi.gov.cn/zslm/fzzlk/xbsxsz/szdylpdf/201404/P020240923626374688109.pdf)和[云南农业大学烟草栽培实验指导](https://et.ynau.edu.cn/lab/yckx/Media/73_20140529234013.pdf)。细分阶段、温度伤害和缺水死亡阈值为游戏模拟参数，未宣称是统一农艺标准。

当前均采用既有“播种→生长→单次整田采收→枯株→铲除”的作物模型；番茄、辣椒的分批果实采摘和烟草分层采叶尚未模拟。采后枯株使用下排最后一张贴图，下排第五张保留在配置中以供后续扩展。每田默认小麦4份、辣椒16个、西红柿16个、烟叶24片，只是可配置的游戏入库单位。

## 图集、图标与导出

四张用户图集均原样保存为各自目录的 `states.png`，未修改像素；统一上排5格、下排6格，以透明间隔确定区域。缺水、死亡、成熟和枯株均已映射，每张素材只需调整 `scale`。采用图集统一高度基准，保留素材相对比例，并沿用运行时白边处理。

仓库图标通过内置 image_gen 生成，为透明背景的水彩与棕色线稿风格：金色麦穗束、红辣椒、红番茄、绿色烟叶。分别保存至：

- `data/crops/wheat_spring/icon.png` 与 `data/crops/wheat_winter/icon.png`
- `data/crops/pepper/icon.png`
- `data/crops/tomato/icon.png`
- `data/crops/tobacco/icon.png`

完整生成提示词与工具模式保存在 `docs/crop-icon-prompts.json`。原始生成文件也保留在 Codex 的生成目录，项目使用的是工作区内副本。

背包和仓库自动列出新作物；点击仓库图标可查看播期、温度、周期与产量，详情可滚动。托盘作物预览和仓库导出选择也自动包含全部新品种。每个导出包包含 `crop.json`、原始 `states.png` 与 `icon.png`，可完整迁移配置和素材。既有玉米、棉花及存档不会重置。
