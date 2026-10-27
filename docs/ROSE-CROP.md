# 玫瑰作物

配置位于 data/crops/rose/crop.json，原始图集保存在 states.png。按两行各六个顺序使用全部12张状态；配置 region 仅收紧透明边距，原图不重绘。每张图片支持独立 scale，成熟形态复用为仓库图标。

种子28天、幼苗62天、现蕾30天，共120个真实日。这是已完成休眠解除处理的种子的可调模拟参考，不是所有品种统一周期；不模拟低温层积。适生10～30℃、播种15～25℃，耗水和干土死亡阈值均为可调游戏参数。

按用户提供素材实现单次花卉采收：成熟未采摘7天后显示第12张；采摘后显示第10张3天，再显示第11张。成熟缺水复用成熟图。真实玫瑰是多年生植物，本包不模拟修剪复花。每田一株，非种子放大30%，保留随风动画。

新增通用配置 harvest.mature_lifetime_seconds（默认0，不启用）和存档可选字段 mature_seconds，未配置的旧作物保持原逻辑。作物导出功能包含本配置与原图。

资料参考：https://roses.tamu.edu/rose-breeding-for-beginners/ 、https://www.rhs.org.uk/plants/roses/growing-guide 。
