# 生活与质量更新 1.6.10

[English](README.en.md)

《监狱建筑师》的 Windows 补丁管理器。适用于 Steam x64 构建 **10630057**，支持原版、Tyr 1.5.0 默认修复，以及已额外启用 Tyr 员工士气衰减的配置。勾选所需功能并应用后，照常从 Steam 启动游戏。

## 下载和安装

### 从 GitHub 下载

1. 保存监狱并完全退出游戏。
2. 下载并解压 **Prison-QoL-1.6.10-Windows-x64.zip**，双击其中的 **Prison QoL.exe**。 [GitHub 1.6.10 发布页](https://github.com/Zack176CN/prison-quality-of-life/releases/tag/v1.6.10)
3. 核对管理器检测到的游戏目录和版本。要手动选择，在 Steam 库右键《监狱建筑师》，点「管理 → 浏览本地文件」，然后在管理器选择包含 `Prison Architect64.exe` 的目录。
4. 勾选需要的选项，点击「应用」。看到成功提示后关闭管理器，从 Steam 启动游戏。

### 从 Steam 创意工坊安装

1. 订阅「生活与质量更新」，启动一次游戏。等「附加功能 → 模组」出现 **Prison Quality of Life**，保存并完全退出。 [创意工坊页面](https://steamcommunity.com/sharedfiles/filedetails/?id=3843268843)
2. 按 **Win + E**，将下方路径粘贴到地址栏，打开 **Prison QoL.exe**。如果目录不同，在 `%LOCALAPPDATA%\Introversion\Prison Architect\mods` 下搜索 **Prison QoL.exe**，并用相邻的 `manifest.txt` 核对条目名称。

   ```text
   %LOCALAPPDATA%\Introversion\Prison Architect\mods\-451698453\data\prisonqol
   ```

3. 核对游戏目录，勾选补丁和「应用」。成功后照常从 Steam 启动。

管理器右上角可切换中文与 English。更新时请保留游戏目录内的 `Prison QoL Backup`。关闭游戏后，可在新版管理器核对原勾选项并重新应用，也可点击「恢复原文件」回到打补丁前的原版或 Tyr 程序。

## 功能和使用方法

- **地图物件取样**。启用后，将光标指向已建物件、墙壁、门或地板，按鼠标中键取样。也可在管理器内更换按键。补丁会打开对应建造栏和标签页，选中并滚动定位该项目。已有搜索或筛选只在其隐藏目标时才调整。
- **拼音搜索**。启用后，可在支持搜索的物品、房间、墙壁、地板及快速建造栏输入全拼或首字母。查找「跪垫」可输入 `guidian` 或 `gd`，查找「行刑室」可输入 `xing xing shi` 或 `xxs`。原版名称搜索仍可使用。
- **右键取消选中物品**。启用后，对地图右键单击。游戏先按原版规则处理同一次右键触发的工单取消，然后清除当前建造预览和高亮，保留建造栏及筛选。按住右键拖动、搬动物件和公用设施连线沿用原版操作。
- **施工和经营**。砍树不留新树桩。可直接换门或用墙替换旧门，开工前可自动清除施工范围的树木。另有改造计划进度修复和兼容原版事故统计的员工士气衰减。
- **出货调度**。从物件栏建造出货调度台，费用 200。可手动排队发车、按积压自动加派，以及设置同时运行的货车上限。使用「均衡取货」可在垃圾和出口货物积压时交替派车。调度台偏好保存在监狱存档中。
- **供给货车容量**。首选方案在调度台内为加派车选择 8、12 或 16 个货位。备选方案在管理器内为供给货车选择固定容量。切换方案或停用调度台前，请按指南处理仍在途的加派车辆。
- **逻辑桥信号传播优化**。默认关闭，可在管理器中单独选用。指南列出了实际测试的适用场景和观测结果。

更详细的操作、选项限制、旧物流模组迁移和 Tyr 切换步骤都在随安装包提供的双语指南里。 [完整操作指南](docs/README%20-%20Prison%20QoL.txt)

## 从源码构建

Windows x64 下需要 Python 3.10 或更新版本、PowerShell，以及自带 x64 `csc.exe` 的 .NET Framework 4.x。准备自己的同构建 Steam 原版和 Tyr 1.5.0 可执行文件副本。Tyr 副本可启用或关闭其士气衰减选项。

```powershell
$stockExe = 'C:\PA-build-inputs\stock\Prison Architect64.exe'
$tyrExe = 'C:\PA-build-inputs\tyr-1.5.0\Prison Architect64.exe'
python .\build_patch_catalog.py --steam $stockExe --tyr $tyrExe --output .\patches.json
if ($LASTEXITCODE -ne 0) { throw '补丁目录生成失败' }
& .\app\Build-App.ps1 -CatalogPath .\patches.json
```

构建脚本在仓库根目录生成 `Prison QoL.exe`，补丁目录会编入程序。仓库内有管理器、原生功能、生成资料及旧版兼容数据，构建所用游戏程序由玩家自行提供。

## 反馈和致谢

反馈时请提供管理器显示的游戏版本、Tyr 配置、启用的选项和游戏内复现步骤。取样或拼音问题请附上目标名称和输入内容。出货调度问题请注明所选容量方案和车长。

- Tyr 的公开补丁定义用于构建兼容检测。MIT 声明适用于相应第三方材料。 [Tyr 1.5.0](https://github.com/Tyr077/tyrs-prison-architect-community-patch/tree/v1.5.0) · [Tyr MIT 声明](features/staff_morale_decay/TYR-LICENSE.txt)
- 拼音数据由 Unicode 17.0.0 Unihan 生成。 [Unicode 声明](features/pinyin_search/LICENSE-UNICODE.txt)
- 感谢 wackypanda 报告并提供课程进度问题的参考修复。 [原始创意工坊条目](https://steamcommunity.com/sharedfiles/filedetails/?id=3458434752)

除注明的第三方材料外，本项目尚未采用统一许可证。
