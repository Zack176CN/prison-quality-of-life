using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;

namespace PrisonQoL
{
    internal sealed class InstallStatus
    {
        public string GamePath { get; private set; }
        public string BaseName { get; private set; }
        public string BackupPath { get; private set; }
        public bool HasBackup { get; private set; }
        public bool RequiresUpgrade { get; private set; }
        public bool HasTyrStaffMorale { get; private set; }
        public HashSet<string> Enabled { get; private set; }
        public int MapObjectPickerKey { get; private set; }

        internal InstallStatus(string gamePath, string baseName, string backupPath,
            bool hasBackup, IEnumerable<string> enabled, bool hasTyrStaffMorale, bool requiresUpgrade = false,
            int mapObjectPickerKey = PatchCatalog.DefaultMapObjectPickerKey)
        {
            GamePath = gamePath;
            BaseName = baseName;
            BackupPath = backupPath;
            HasBackup = hasBackup;
            RequiresUpgrade = requiresUpgrade;
            HasTyrStaffMorale = hasTyrStaffMorale;
            Enabled = new HashSet<string>(enabled, StringComparer.Ordinal);
            MapObjectPickerKey = mapObjectPickerKey;
        }
    }

    internal sealed class PatchInstaller
    {
        private const string GameFile = "Prison Architect64.exe";
        private const string BackupDirectory = "Prison QoL Backup";
        private const string BackupPrefix = "Prison Architect64.";
        private static readonly StringComparer DigestComparer = StringComparer.OrdinalIgnoreCase;
        private readonly PatchCatalog catalog;

        internal PatchInstaller(PatchCatalog catalog)
        {
            if (catalog == null)
                throw new ArgumentNullException("catalog");
            this.catalog = catalog;
        }

        internal IEnumerable<string> FeatureIds { get { return catalog.FeatureIds; } }

        public InstallStatus Inspect(string gameDirectory)
        {
            return Resolve(gameDirectory).Status;
        }

        public void Apply(string gameDirectory, IEnumerable<string> selected)
        {
            ApplyWithPickerKey(gameDirectory, selected, null);
        }

        internal void ApplyWithPickerKey(string gameDirectory, IEnumerable<string> selected, int? mapObjectPickerKey)
        {
            if (selected == null)
                throw new ArgumentNullException("selected");
            var requested = new HashSet<string>(selected, StringComparer.Ordinal);
            if (!requested.IsSubsetOf(FeatureIds))
                throw new ArgumentException("补丁列表包含未知功能。");
            EnsureGameClosed();

            var initial = Resolve(gameDirectory);
            if (initial.Status.HasTyrStaffMorale && requested.Contains(PatchCatalog.StaffMoraleFeature))
                throw new InvalidOperationException(PatchCatalog.StaffMoraleConflict);
            int pickerKey = requested.Contains(PatchCatalog.MapObjectPicker)
                ? mapObjectPickerKey ?? initial.Status.MapObjectPickerKey : PatchCatalog.DefaultMapObjectPickerKey;
            if (!initial.Status.RequiresUpgrade && initial.Status.Enabled.SetEquals(requested) &&
                initial.Status.MapObjectPickerKey == pickerKey)
                return;

            var backupFolder = Path.GetDirectoryName(initial.Status.BackupPath);
            Directory.CreateDirectory(backupFolder);
            var lockPath = Path.Combine(backupFolder, "apply.lock");
            using (new FileStream(lockPath, FileMode.OpenOrCreate, FileAccess.Write, FileShare.None))
            {
                var current = Resolve(gameDirectory);
                if (!DigestComparer.Equals(initial.InstalledHash, current.InstalledHash))
                    throw new IOException("游戏程序刚刚发生变化，请重新读取安装状态。");

                var replacement = catalog.CreateImageWithPickerKey(current.Build, current.BaseImage, requested, pickerKey);
                var replacementHash = PatchCatalog.Hash(replacement);
                EnsureBackup(current.Status.BackupPath, current.BaseImage);
                if (!DigestComparer.Equals(current.InstalledHash, replacementHash))
                    ReplaceGameFile(current, replacement, replacementHash);
            }
        }

        private ResolvedInstall Resolve(string gameDirectory)
        {
            if (String.IsNullOrWhiteSpace(gameDirectory))
                throw new ArgumentException("请选择监狱建筑师的 Steam 安装目录。");
            var installation = Path.GetFullPath(gameDirectory);
            var gamePath = Path.Combine(installation, GameFile);
            if (!File.Exists(gamePath))
                throw new FileNotFoundException("此目录中找不到 " + GameFile + "。", gamePath);

            var installed = File.ReadAllBytes(gamePath);
            var installedHash = PatchCatalog.Hash(installed);
            var folder = Path.Combine(installation, BackupDirectory);
            var build = catalog.FindBase(installed);
            if (build != null)
            {
                var backup = GetBackupPath(folder, installedHash);
                var status = new InstallStatus(gamePath, build.Name, backup,
                    File.Exists(backup) && DigestComparer.Equals(HashFile(backup), installedHash),
                    Enumerable.Empty<string>(), build.HasTyrStaffMorale);
                return new ResolvedInstall(status, build, installed, installedHash);
            }

            if (Directory.Exists(folder))
            {
                foreach (var backup in Directory.EnumerateFiles(folder, BackupPrefix + "*.exe"))
                {
                    var baseImage = File.ReadAllBytes(backup);
                    var baseHash = PatchCatalog.Hash(baseImage);
                    if (!DigestComparer.Equals(backup, GetBackupPath(folder, baseHash)))
                        continue;
                    build = catalog.FindBase(baseImage);
                    if (build == null)
                        continue;

                    var enabled = catalog.DetectFeatures(build, installed);
                    if (enabled != null)
                    {
                        int pickerKey = PatchCatalog.ReadMapObjectPickerKey(build, installed, enabled);
                        var expected = catalog.CreateImageWithPickerKey(build, baseImage, enabled, pickerKey);
                        if (DigestComparer.Equals(PatchCatalog.Hash(expected), installedHash))
                        {
                            var status = new InstallStatus(gamePath, build.Name, backup, true, enabled, build.HasTyrStaffMorale,
                                mapObjectPickerKey: pickerKey);
                            return new ResolvedInstall(status, build, baseImage, installedHash);
                        }
                    }

                    int legacyKey;
                    var legacyFeatures = catalog.DetectPreviousFeatures(build, baseImage, installed, installedHash, out legacyKey);
                    if (legacyFeatures != null)
                    {
                        var status = new InstallStatus(gamePath, build.Name, backup, true, legacyFeatures, build.HasTyrStaffMorale,
                            true, legacyKey);
                        return new ResolvedInstall(status, build, baseImage, installedHash);
                    }
                }
            }

            string conflict = catalog.HasTyrStaffMorale(installed) ? PatchCatalog.StaffMoraleConflict + Environment.NewLine : String.Empty;
            throw new InvalidOperationException(conflict + "无法识别当前游戏程序。请确认所选目录和版本。"
                + Environment.NewLine + "当前 SHA-256  " + installedHash);
        }


        private static void EnsureBackup(string path, byte[] data)
        {
            var expectedHash = PatchCatalog.Hash(data);
            if (!File.Exists(path))
            {
                var temp = NewTempPath(path, ".part");
                try
                {
                    WriteNewFile(temp, data);
                    File.Move(temp, path);
                }
                finally
                {
                    TryDelete(temp);
                }
            }

            if (!DigestComparer.Equals(HashFile(path), expectedHash))
                throw new IOException("原始备份校验失败。请保留游戏程序并检查备份文件。" + Environment.NewLine + path);
        }

        private static void ReplaceGameFile(ResolvedInstall current, byte[] replacement, string replacementHash)
        {
            var path = current.Status.GamePath;
            var temp = NewTempPath(current.Status.BackupPath, ".next");
            var displaced = NewTempPath(current.Status.BackupPath, ".previous");
            var replaceAttempted = false;
            var verified = false;
            try
            {
                WriteNewFile(temp, replacement);
                if (!DigestComparer.Equals(HashFile(temp), replacementHash))
                    throw new IOException("写入的补丁副本校验失败。");
                EnsureGameClosed();
                if (!DigestComparer.Equals(HashFile(path), current.InstalledHash))
                    throw new IOException("游戏程序刚刚发生变化，请重新读取安装状态。");

                replaceAttempted = true;
                try
                {
                    File.Replace(temp, path, displaced);
                }
                catch (IOException)
                {
                    // Some native failures leave the old executable at the displaced path.
                    if (!File.Exists(path) && File.Exists(displaced))
                        File.Move(displaced, path);
                    throw;
                }
                if (!DigestComparer.Equals(HashFile(displaced), current.InstalledHash))
                {
                    // Preserve an unexpected concurrent Steam update, even if rollback fails.
                    if (DigestComparer.Equals(HashFile(path), replacementHash))
                        File.Replace(displaced, path, null);
                    throw new IOException("游戏程序在应用时被其他程序更新。请重新读取安装状态。");
                }
                if (!DigestComparer.Equals(HashFile(path), replacementHash))
                    throw new IOException("应用后未读到预期的游戏程序。请检查 Steam 是否正在更新。");
                verified = true;
            }
            finally
            {
                TryDelete(temp);
                if (!replaceAttempted || verified)
                    TryDelete(displaced);
            }
        }

        private static void EnsureGameClosed()
        {
            var names = new[] { "Prison Architect64", "PrisonArchitect64", "Prison Architect",
                "PrisonArchitect", "Prison Architect64 QoL", "Prison Architect64 Balanced" };
            foreach (var name in names)
            {
                var processes = Process.GetProcessesByName(name);
                try
                {
                    if (processes.Length != 0)
                        throw new InvalidOperationException("请先在游戏中保存并退出，然后再应用补丁。");
                }
                finally
                {
                    foreach (var process in processes)
                        process.Dispose();
                }
            }
        }

        private static string GetBackupPath(string folder, string digest)
        {
            return Path.Combine(folder, BackupPrefix + digest.ToLowerInvariant() + ".exe");
        }

        private static string NewTempPath(string path, string extension)
        {
            return Path.Combine(Path.GetDirectoryName(path), "paqol-" + Guid.NewGuid().ToString("N") + extension);
        }

        private static string HashFile(string path)
        {
            return PatchCatalog.Hash(File.ReadAllBytes(path));
        }

        private static void WriteNewFile(string path, byte[] data)
        {
            using (var file = new FileStream(path, FileMode.CreateNew, FileAccess.Write, FileShare.None))
            {
                file.Write(data, 0, data.Length);
                file.Flush(true);
            }
        }

        private static void TryDelete(string path)
        {
            try { File.Delete(path); }
            catch (IOException) { }
            catch (UnauthorizedAccessException) { }
        }

        private sealed class ResolvedInstall
        {
            public readonly InstallStatus Status;
            public readonly PatchCatalog.Build Build;
            public readonly byte[] BaseImage;
            public readonly string InstalledHash;

            public ResolvedInstall(InstallStatus status, PatchCatalog.Build build, byte[] baseImage, string installedHash)
            {
                Status = status;
                Build = build;
                BaseImage = baseImage;
                InstalledHash = installedHash;
            }
        }
    }
}
