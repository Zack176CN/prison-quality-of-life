using System;
using System.Collections.Generic;
using System.IO;

namespace PrisonQoL
{
    internal static partial class ManagerLanguage
    {
        private static readonly string PreferencePath = GetPreferencePath();
        private static bool english = LoadPreference();

        private static readonly Dictionary<string, string> EnglishText = new Dictionary<string, string>(StringComparer.Ordinal) {
            { "生活与质量更新补丁", "Prison Quality of Life Patch" },
            { "勾选功能并应用，之后可直接从 Steam 启动游戏。", "Select patches, apply them, then start the game through Steam." },
            { "切换语言", "Switch language" },
            { "游戏目录", "Game folder" },
            { "自动检测", "Auto-detect" },
            { "选择目录…", "Choose folder…" },
            { "可选功能", "Optional patches" },
            { "体验优化", "Quality of life" },
            { "补丁修复", "Bug fixes" },
            { "全选", "Select all" },
            { "选择两个分组中与当前游戏版本兼容的补丁。", "Select all compatible patches in both groups." },
            { "应用前请保存并退出游戏。关闭施工补丁前，请先完成或取消已安排的相关施工。",
                "Save and close the game before applying patches. Finish or cancel affected building work before disabling construction patches." },
            { "补丁状态", "Patch status" },
            { "复查当前目录", "Recheck current folder" },
            { "恢复原文件", "Restore original" },
            { "应用", "Apply" },
            { "应用所选补丁", "Apply selected patches" },
            { "砍树后不留树桩", "Remove tree stumps when cutting trees" },
            { "工人完成拆树后照常产出木材。", "Workers still produce wood after cutting down a tree." },
            { "自动替换已安装的旧门", "Replace installed doors" },
            { "选择单格或双格新门后单击旧门所在位置，或用墙壁工具点击、拖过旧门。施工期间保留旧门。",
                "Select a one- or two-tile door and click an existing door, or click or drag over it with the wall tool. The old door stays in place during construction." },
            { "建门和墙前自动清理树木", "Clear trees before building doors and walls" },
            { "墙线、单格门或双格门覆盖树木或树桩时，工人先清理，再开始施工。",
                "Workers clear any trees or stumps in the way before building walls or one- or two-tile doors." },
            { "地图物件取样", "Map object picker" },
            { "指向物件、墙壁或地板，按快捷键打开对应建造栏，并定位和高亮目标。",
                "Point at an object, wall, or floor and press the shortcut to open its build menu and scroll to the highlighted item." },
            { "拼音搜索", "Pinyin search" },
            { "在物品、房间等建造栏的原版搜索框输入全拼或首字母。例如 jiaoshi 或 js 可找到「教室」。",
                "Use full Pinyin or initials in the in-game search box for objects, rooms, and other build menus. For example, jiaoshi or js finds the Chinese label 教室 (Classroom)." },
            { "右键取消选中物品", "Right-click to deselect build item" },
            { "在地图上右键单击，游戏先按原版规则处理工单取消，再清除建造预览并保留建造栏。按住右键拖动仍沿用原版操作。",
                "A map right-click follows the game's job cancellation rules, then deselects the build item and keeps its menu open. Right-button drag keeps the original controls." },
            { "修复改造计划进度保存", "Keep reform program progress" },
            { "保存「三振出局计划」和「鲜花疗法」的囚犯进度，下次活动时接着进行。",
                "Keep prisoners' progress in Three Strikes Program and Flower Therapy for their next session." },
            { "逻辑桥信号传播优化", "Logic bridge signal propagation" },
            { "默认关闭。逻辑桥频繁向大片连线传播时可常驻。低负载建议关闭，收益尚无实测。保留原版信号和顺序。\r\n" +
                "同一大型电路档，原版 10 倍速两轮。模拟推进 +27.45%–34.81%，FPS +38.32%–46.93%，p95／p99 帧时间缩短 7.52–9.15／8.74–9.53 ms。",
                "Off by default. Best suited to large circuits with frequent broadcasts. Gains at low load are unmeasured. Signal values and order are preserved.\r\n" +
                "Two runs on the same large-circuit save at the standard 10× speed. Simulation speed rose 27.45%–34.81% and FPS rose 38.32%–46.93%. P95 frame time fell 7.52–9.15 ms and p99 fell 8.74–9.53 ms." },
            { "均衡取货", "Balanced pickups" },
            { "在出货调度台中开启「均衡取货」。垃圾和出口货物同时积压时，加派货车交替取货。兼容旧版出货调度台。",
                "Enable at the console. When both back up, extra trucks alternate garbage and exports. Works with legacy consoles." },
            { "出货调度台", "Outbound dispatch console" },
            { "物件栏建造，价格 200。可手动或按积压加派，最多同时 5 辆。设置随监狱存档保存。启用前请停用旧版调度台模组。",
                "Build in Objects for 200. Dispatch by request or backlog (up to 5 trucks). Settings save with the prison. Disable the legacy mod first." },
            { "员工死亡士气惩罚逐渐消退", "Gradual recovery from staff death morale penalties" },
            { "每过一个完整游戏日减轻 1 点员工死亡士气惩罚，保留原版无事故奖励规则。",
                "Reduce the staff death morale penalty by 1 point per full in-game day. The incident-free bonus follows the stock rules." },
            { "快捷键", "Shortcut" },
            { "地图物件取样快捷键", "Map object picker shortcut" },
            { "鼠标中键", "Middle mouse button" },
            { "出货调度", "Outbound dispatch" },
            { "控制下方的出货调度台、均衡取货和供给货车容量。",
                "Controls the outbound dispatch console, balanced pickups and supply truck capacity below." },
            { "出货调度选项", "Outbound dispatch options" },
            { "供给货车容量", "Supply truck capacity" },
            { "首选方案  在游戏内通过出货调度台调整车长", "Preferred   Set truck length in the dispatch console" },
            { "首选方案", "Preferred" },
            { "备选方案  固定容量", "Fallback   Fixed capacity" },
            { "备选方案", "Fallback" },
            { "固定供给货车容量", "Fixed supply truck capacity" },
            { "选择全局固定容量。", "Choose a fixed capacity for all supply trucks." },
            { "固定容量（12 格）", "Fixed capacity (12 slots)" },
            { "固定容量（16 格）", "Fixed capacity (16 slots)" },
            { "游戏默认（原版 8 格）", "Game default (8 slots)" },
            { "请选择包含 Prison Architect64.exe 的游戏目录", "Select the game folder containing Prison Architect64.exe" },
            { "正在检测 Steam 游戏库…", "Checking Steam libraries…" },
            { "找到游戏目录，无法验证版本。请复查当前目录或手动选择目录。",
                "The game folder was found, but its version could not be verified. Recheck it or choose a folder manually." },
            { "Steam 游戏库中未找到游戏。请选择安装目录，或将游戏程序拖入窗口。",
                "The game was not found in your Steam libraries. Choose its installation folder or drop the game executable onto this window." },
            { "Steam 游戏库检测失败。请选择游戏目录。 {0}", "Could not check the Steam libraries. Choose the game folder manually. {0}" },
            { "请选择 Steam 中的游戏安装目录。", "Select the game's Steam installation folder." },
            { "正在检测游戏版本…", "Checking the game version…" },
            { "正在恢复原文件…", "Restoring the original file…" },
            { "正在应用所选补丁…", "Applying selected patches…" },
            { "已恢复应用前的版本。", "The version from before applying the patches has been restored." },
            { "已应用，可从 Steam 正常启动。", "Patches applied. Start the game through Steam." },
            { "检测到旧版补丁。点击「应用」保留现有勾选并移除已停用的项目。",
                "An older patch version is installed. Select Apply to keep your current choices and remove retired patches." },
            { "{0}，未启用补丁", "{0}, no patches enabled" },
            { "{0}，已启用 {1} 项补丁", "{0}, enabled patches ({1})" },
            { "补丁操作未完成", "Could not complete the patch operation" },
        };

        internal static bool IsEnglish { get { return english; } }

        internal static void Toggle()
        {
            english = !english;
            if (PreferencePath == null)
                return;
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(PreferencePath));
                File.WriteAllText(PreferencePath, english ? "en" : "zh-CN");
            }
            catch (IOException) { }
            catch (UnauthorizedAccessException) { }
        }

        internal static string Translate(string text)
        {
            if (!english || String.IsNullOrEmpty(text))
                return text;
            string translation;
            return EnglishText.TryGetValue(text, out translation) ? translation : TranslateError(text);
        }

        internal static string Translate(string text, params object[] arguments)
        {
            var translated = Translate(text);
            return arguments.Length == 0 ? translated : String.Format(translated, arguments);
        }

        private static string GetPreferencePath()
        {
            var localData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            return String.IsNullOrEmpty(localData) ? null : Path.Combine(localData, "PrisonQoL", "manager-language.txt");
        }

        private static bool LoadPreference()
        {
            if (PreferencePath == null)
                return false;
            try { return String.Equals(File.ReadAllText(PreferencePath).Trim(), "en", StringComparison.OrdinalIgnoreCase); }
            catch (IOException) { return false; }
            catch (UnauthorizedAccessException) { return false; }
        }
    }
}
