# 农事工具图片与可移动界面

图标由内置 image_gen 工具生成，透明 PNG，原图保留在 assets/icons/farm-tools/，Godot 导入限为 128px 并生成 mipmaps，以减少运行时占用。

- 背包：assets/icons/farm-tools/backpack.png
- 铲子：assets/icons/farm-tools/shovel.png
- 浇水壶：assets/icons/farm-tools/watering.png

## 最终生成提示词

三张分别使用下列完整模板，替换 SUBJECT 为对应内容：

Use case: stylized-concept. Asset type: one standalone inventory tool icon for a Chinese pastoral hand-painted 2.5D farming wallpaper game. Primary request: SUBJECT. Centered complete object, fills 80% of square canvas, generous transparent margin, clear silhouette readable at 40px. Delicate dark olive drawn outlines, warm earthy colors, softly painted watercolor-gouache texture, restrained shading, cozy Chinese countryside illustration style. Transparent background with clean alpha edges. No text, no letters, no symbols, no emoji, no frame, no tile, no surrounding scene. Generate exactly one object icon.

SUBJECT:

- a single small rustic tan canvas seed backpack with green fabric flap and visible seed pouch
- a single gardening harvest shovel, warm wooden short handle and blue-gray iron spade blade, diagonal composition
- a single sage green metal watering can with curved handle and long spout, a few tiny blue water droplets near spout

## 操作

解锁桌面并选中田块后显示图片工具栏；所有工具仅针对当前选中的田块。拖动工具栏左侧“拖动”区域或天气文字区域，松开保存位置。位置按可用屏幕区域比例保存到 preferences.cfg 的 hud_tools_position 与 hud_weather_position；分辨率变化后恢复并约束在屏幕内。锁定时天气保持当前位置显示且不接收鼠标，工具栏隐藏。未选中田块时工具栏隐藏。

界面调整：工具栏以六点图形手柄替代文字；工具按钮各状态保持相同的圆角与内边距。悬停提示采用不透明浅底深字。作物详情顶部（含六点手柄）支持拖动，位置存为 hud_details_position；种子面板跟随详情位置并自动避开屏幕边界。锁定桌面时不可拖动。
