using System;
using System.Collections.Generic;

namespace PrisonQoL
{
    internal static partial class ManagerLanguage
    {
        private const string CurrentHashPrefix = "当前 SHA-256  ";

        private static readonly Dictionary<string, string> ErrorTranslations = new Dictionary<string, string>(StringComparer.Ordinal)
        {
            { "监狱建筑师体验补丁", "Prison Architect Quality of Life Patch" },
            { "补丁列表包含未知功能。", "The patch list contains an unknown feature." },
            { "游戏程序刚刚发生变化，请重新读取安装状态。", "The game executable changed. Refresh the installation status and try again." },
            { "请选择监狱建筑师的 Steam 安装目录。", "Select the Steam installation folder for Prison Architect." },
            { "此目录中找不到 Prison Architect64.exe。", "Prison Architect64.exe was not found in this folder." },
            { "无法识别当前游戏程序。请确认所选目录和版本。", "The game executable could not be recognized. Check the selected folder and game version." },
            { "原始备份校验失败。请保留游戏程序并检查备份文件。", "The original backup failed verification. Keep the game executable and check the backup file." },
            { "写入的补丁副本校验失败。", "The patched copy failed verification after writing." },
            { "游戏程序在应用时被其他程序更新。请重新读取安装状态。", "Another program updated the game executable while patches were being applied. Refresh the installation status." },
            { "应用后未读到预期的游戏程序。请检查 Steam 是否正在更新。", "The game executable did not match the expected result after applying patches. Check whether Steam is updating the game." },
            { "请先在游戏中保存并退出，然后再应用补丁。", "Save your game and exit Prison Architect before applying patches." },
            { PatchCatalog.StaffMoraleConflict, "Tyr's Staff Death Morale Decay patch is enabled. Disable this option in Tyr before applying it here." },
            { "应用内缺少补丁数据。", "The manager is missing its patch data." },
            { "旧版补丁布局与支持的游戏版本不一致。", "The previous patch layout does not match a supported game version." },
            { "补丁数据格式不受支持。", "The patch data format is unsupported." },
            { "附加补丁布局与功能列表不一致。", "The optional patch layout does not match the feature list." },
            { "供给货车只能选择一种容量方案。", "Select only one supply truck capacity option." },
            { "原生长车需要启用出货调度台。", "Extended trucks require the Dispatch Console patch." },
            { "源游戏文件已变化，应用已取消。", "The source game executable changed. Applying patches was canceled." },
            { "所选功能不在当前游戏版本的补丁数据中。", "The selected features are unavailable for this game version." },
            { "请选择支持的地图物件取样快捷键。", "Select a supported map object picker shortcut." },
            { "参数名: pickerKey", "Parameter name: pickerKey" },
            { "补丁数据包含重叠或超出边界的位置。", "Patch locations overlap or fall outside the game executable." },
            { "游戏的原始指令校验失败。", "The original game instructions failed verification." },
            { "已生成的游戏文件未通过校验。", "The generated game executable failed verification." },
            { "附加补丁布局与原始游戏版本不一致。", "The optional patch layout does not match the original game version." },
            { "附加补丁缺少用于检测的游戏指令。", "The optional patch is missing the game instructions used to identify it." },
            { "补丁数据中的游戏版本记录无效。", "The game version record in the patch data is invalid." },
            { "货车容量补丁的备选指令范围无效。", "The instruction ranges for the alternative truck capacity patches are invalid." },
            { "货车容量补丁缺少备选项。", "The truck capacity patch is missing an alternative." },
            { "原版 8 格容量补丁的校验记录无效。", "Verification data for the original eight-slot truck capacity is invalid." },
            { "原生长车补丁的依赖或校验记录无效。", "Dependencies or verification data for the extended trucks patch are invalid." },
            { "旧补丁校验记录无效。", "Verification data for an earlier patch version is invalid." },
            { "补丁数据中的本地游戏数据范围无效。", "The local game data range in the patch data is invalid." },
            { "地图物件取样的快捷键记录无效。", "The map object picker shortcut record is invalid." },
            { "补丁数据中的指令长度无效。", "An instruction length in the patch data is invalid." },
            { "Tyr 冲突检测签名无效。", "The Tyr conflict detection signature is invalid." },
            { "请选择包含 Prison Architect64.exe 的游戏目录，或直接选择该游戏程序。", "Select the folder containing Prison Architect64.exe or select the executable directly." },
            { "实际启用的补丁与所选项目不一致。请复查当前目录。", "The applied patches do not match your selection. Recheck the current folder." },
        };

        private static string TranslateError(string chinese)
        {
            var lines = chinese.Split(new[] { "\r\n", "\n" }, StringSplitOptions.None);
            var changed = false;
            for (var index = 0; index < lines.Length; index++)
            {
                var line = lines[index];
                string english;
                if (!ErrorTranslations.TryGetValue(line, out english))
                {
                    if (!line.StartsWith(CurrentHashPrefix, StringComparison.Ordinal))
                        continue;
                    english = "Current SHA-256  " + line.Substring(CurrentHashPrefix.Length);
                }
                lines[index] = english;
                changed = true;
            }
            return changed ? String.Join(Environment.NewLine, lines) : chinese;
        }
    }
}
