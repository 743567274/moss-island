# 2.4.0 素材处理记录

使用内置 image_gen 工具，没有使用 API/CLI，也没有改动下载目录中的原图。工程保存路径：

- `E:/python/3D桌面/assets/illustrated/soil-normal.png`：来自 `C:/Users/Cozy/Downloads/耕地.png` 的透明背景提取。
- `E:/python/3D桌面/assets/illustrated/soil-selected.png`：来自 `C:/Users/Cozy/Downloads/耕地选中.png` 的透明背景提取，保留用户图中的暖色和细金色轮廓。
- `E:/python/3D桌面/assets/illustrated/moonlit-meadow.png`：对本工程草地底图的月夜重绘。

哈希、字节数及导入尺寸上限见 assets/illustrated/source-manifest.json。土地最长边导入为 1024，月夜最长边上限 2048，均使用 VRAM 压缩和 Mipmap。运行时读取有效 alpha 边界，将两张土地素材归一化到同一田块包围框；不对已经包含等距投影的图片再次投影。纸背景为真实透明，非接近白色的矩形覆盖。

## 实际使用的提示词

### 普通土地

Use case: background-extraction. Edit target: the provided cultivated farmland illustration. Remove ONLY the off-white paper background to genuine transparent alpha, preserving the single isometric square soil tile, all hand-painted brown soil ridges, little stones, organic edge and existing illustration detail. Do not redesign, recolor, simplify or change the camera angle. Keep the entire tile uncropped, centered with a small transparent margin, with its diamond footprint horizontal. No text, no white matte, no checkerboard baked into pixels, no added glow or frame. Output one isolated transparent game sprite.

### 选中土地

Use case: background-extraction. Edit target: user-provided selected cultivated farmland illustration. Remove ONLY the cream paper background to genuine transparent alpha. Preserve the hand-painted isometric square farmland tile with its soil ridges, tiny stones, warm brighter selected colors and narrow golden glowing organic outline exactly as supplied. No redesign or camera change. Keep the whole diamond tile uncropped, centered with a small transparent margin and horizontally oriented. Do not add plants, text, any frame, background, checkerboard or white matte. Output one transparent selected-state game sprite.

### 月夜光照图层

Use case: lighting-weather. Edit target: this exact hand-painted Chinese riverside courtyard background for a 2.5D game. Relight ONLY into an atmospheric moonlit night with dimensional light and shadow, not a uniformly dark filter. Strictly preserve exact composition, camera, shapes and locations of the house, willow, both bridges, river/lotus, empty grass banks, pavilion, straw heaps, fences and mountains. Keep both banks EMPTY GRASS, no soil plots, crops or extra trees. Preserve the same watercolor ink illustration medium. Cool silver-blue moonlight from upper left catches roof tile ridges, bridge stone upper edges, willow leaf edges, grassy bank rims; cast soft deeper blue shadows to the lower right. River has a gentle narrow broken silver reflection, dark blue near-bank water. Mountains recede in layered muted blue haze, sky dark indigo. Warm amber light glows through existing cottage windows and softly spills onto its entrance steps and nearby grass. Add one small warm hanging lantern INSIDE the pavilion, beneath roof at center between columns; its warm glow pools on pavilion floor only and nearest wooden beams. No lantern outside pavilion. Background remains quiet, legible at night, with substantially darker shadows than day and local highlights. Do not add moon disc, stars, text, people, snow or weather particles. Match original full-frame aspect and geometry precisely; do not crop or move any object.

生成工具可能轻微重绘边缘或笔触，因此不声称逐像素保留原图。原始文件继续保存在用户下载目录中。
