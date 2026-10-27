# GitHub 发布指南

建议名称：moss-island；显示名：苔屿 · Moss Island。

建议描述：Windows 2.5D 桌面种植壁纸，内置地图与作物编辑器，支持昼夜、天气、风和可绘制灯光。

建议 topics：godot、windows、wallpaper、farming、map-editor、gdscript。

## 源码

1. 在 GitHub 创建 Public 空仓库，不再自动生成 README、LICENSE 或 .gitignore。
2. 在本机 GitHub Desktop／Git 凭据管理器登录，无需向聊天发送令牌。
3. 检查 `git status --short` 和待提交文件。当前 .gitignore 排除 build、dist、tools、.godot、.release-backups、历史无许可参考素材及生成的 crop raw 副本。
4. 检查 `git ls-files --cached`：不应含个人存档、定位缓存、密钥及源码目录之外的文件。忽略规则不会自动移除以前已经跟踪的文件。
5. 按自己的真实身份配置 Git 作者，提交，并绑定实际仓库 URL 后推送。不要直接照抄别人的用户名。

远程仓库：https://github.com/743567274/moss-island 。发布前请确认本地提交已推送成功；本地整理不等于已经公开发布。

## 编译发布包

```powershell
.\dev\build.ps1 -SkipTests
```

完整保留 `build` 下程序、作物包、许可证、第三方说明。压缩该文件夹后上传 GitHub Releases。编译脚本会复制 LICENSE 和 ASSETS.md。

现有 `dev/package_portable.py` 是作者本地地图迁移工具，默认读取当前用户地图与自定义作物；公开发布时不要未经检查直接运行，否则可能带入私人项目。此前已生成的便携 ZIP 也不会因文档修改而自动更新，发布前需要重新生成并核对。

GPL 发行二进制时应同时提供对应版本完整源码。建议先打版本标签，在同一 Release 附上匹配标签的源码与便携包，并保留构建说明。发布说明如实写明已做的检查，不将编译成功描述为跨机器测试成功。

## 素材与数据

作者确认主要素材由豆包生成，详细说明见根目录 ASSETS.md；历史使用的其他素材保留原来源记录。

尚需发布者核对的事项：台湾边界镜像未声明独立许可，须确认政府原始数据授权；在线天气服务有独立使用条款。这些内容不是项目自有 GPL 代码。

## 发布前检查

- README 截图与 Markdown 链接有效。
- 素材目录和地理数据保留相应署名与许可。
- 单个 Git 文件不超过 GitHub 的普通 Git 文件限制；大资源另行使用 LFS 或 Releases。
- 当前用户进度、库存、位置和测试日志没有混入源码或公开初始数据。
- 在 GitHub 创建实际仓库后，更新 README 的下载说明及仓库链接。
