using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text.RegularExpressions;
using System.Windows.Forms;
using Microsoft.Win32;

namespace PrisonQoL
{
    internal static class Program
    {
        [STAThread]
        private static void Main(string[] args)
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            try
            {
                var bundle = Assembly.GetExecutingAssembly().GetManifestResourceStream("PrisonQoL.patches.json");
                var catalog = PatchCatalog.Load(bundle);
                var selectedPath = args.Length == 1 ? args[0] : String.Empty;
                Application.Run(new MainForm(new PatchInstaller(catalog), selectedPath));
            }
            catch (Exception error)
            {
                MessageBox.Show(error.Message, "监狱建筑师体验补丁", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }
    }

    internal static class SteamGame
    {
        private const string GameExecutable = "Prison Architect64.exe";
        private const string SteamKey = @"Software\Valve\Steam";
        private static readonly StringComparer PathComparer = StringComparer.OrdinalIgnoreCase;
        private static readonly Regex VdfPair = new Regex(
            @"(?m)^[ \t]*""([^""\r\n]+)""[ \t]+""((?:\\[^\r\n]|[^""\\\r\n])*)""");

        internal static IEnumerable<string> FindDirectories()
        {
            var libraries = Libraries().Distinct(PathComparer).ToArray();
            var seen = new HashSet<string>(PathComparer);
            foreach (var library in libraries)
            {
                var apps = Path.Combine(library, "steamapps");
                var manifest = ReadValues(Path.Combine(apps, "appmanifest_233450.acf")).ToArray();
                var id = manifest.FirstOrDefault(entry => PathComparer.Equals(entry.Key, "appid")).Value;
                var folder = manifest.FirstOrDefault(entry => PathComparer.Equals(entry.Key, "installdir")).Value;
                if (id != "233450" || !IsDirectoryName(folder))
                    continue;
                var directory = NormalizeDirectory(Path.Combine(apps, "common", folder));
                if (directory.Length != 0 && seen.Add(directory))
                    yield return directory;
            }

            foreach (var library in libraries)
            {
                var directory = NormalizeDirectory(Path.Combine(library, "steamapps", "common", "Prison Architect"));
                if (directory.Length != 0 && seen.Add(directory))
                    yield return directory;
            }
        }

        internal static string NormalizeDirectory(string path)
        {
            var full = NormalizePath(path);
            if (full.Length == 0)
                return String.Empty;
            if (File.Exists(full))
            {
                if (!PathComparer.Equals(Path.GetFileName(full), GameExecutable))
                    return String.Empty;
                full = Path.GetDirectoryName(full);
            }
            return File.Exists(Path.Combine(full, GameExecutable)) ? full : String.Empty;
        }

        private static IEnumerable<string> Libraries()
        {
            foreach (var root in SteamRoots().Select(path => NormalizePath(path, true)).Where(Directory.Exists).Distinct(PathComparer))
            {
                yield return root;
                foreach (var entry in ReadValues(Path.Combine(root, "steamapps", "libraryfolders.vdf")))
                {
                    // Numbered values are legacy library paths. Modern records use a "path" property.
                    if (!PathComparer.Equals(entry.Key, "path") && !entry.Key.All(c => c >= '0' && c <= '9'))
                        continue;
                    var path = NormalizePath(entry.Value, true);
                    if (Directory.Exists(path))
                        yield return path;
                }
            }
        }

        private static IEnumerable<string> SteamRoots()
        {
            foreach (var process in GetSteamProcesses())
            {
                using (process)
                    yield return SteamRootFromFile(ReadProcessPath(process), "steam.exe");
            }
            foreach (var view in new[] { RegistryView.Registry64, RegistryView.Registry32 })
            {
                yield return SteamRootFromFile(ReadRegistry(RegistryHive.CurrentUser, view,
                    SteamKey + @"\ActiveProcess", "SteamClientDll64"), "steamclient64.dll");
                yield return SteamRootFromFile(ReadRegistry(RegistryHive.CurrentUser, view,
                    SteamKey + @"\ActiveProcess", "SteamClientDll"), "steamclient.dll");
                yield return ReadRegistry(RegistryHive.CurrentUser, view, SteamKey, "SteamPath");
                yield return SteamRootFromFile(ReadRegistry(RegistryHive.CurrentUser, view,
                    SteamKey, "SteamExe"), "steam.exe");
                yield return ReadRegistry(RegistryHive.LocalMachine, view, SteamKey, "InstallPath");
            }
            foreach (var location in new[] { Environment.SpecialFolder.ProgramFilesX86, Environment.SpecialFolder.ProgramFiles })
            {
                var folder = Environment.GetFolderPath(location);
                if (folder.Length != 0)
                    yield return Path.Combine(folder, "Steam");
            }
        }

        private static Process[] GetSteamProcesses()
        {
            try { return Process.GetProcessesByName("steam"); }
            catch (Win32Exception) { return new Process[0]; }
            catch (InvalidOperationException) { return new Process[0]; }
            catch (System.Security.SecurityException) { return new Process[0]; }
        }

        private static string ReadProcessPath(Process process)
        {
            try
            {
                var module = process.MainModule;
                return module == null ? null : module.FileName;
            }
            catch (Win32Exception) { return null; }
            catch (InvalidOperationException) { return null; }
            catch (NotSupportedException) { return null; }
            catch (System.Security.SecurityException) { return null; }
        }

        private static string SteamRootFromFile(string path, string filename)
        {
            var full = NormalizePath(path, true);
            return PathComparer.Equals(Path.GetFileName(full), filename) ? Path.GetDirectoryName(full) : String.Empty;
        }

        private static bool IsDirectoryName(string name)
        {
            return !String.IsNullOrWhiteSpace(name) && name != "." && name != ".." &&
                name.IndexOfAny(Path.GetInvalidFileNameChars()) < 0;
        }

        private static string NormalizePath(string path, bool requireRoot = false)
        {
            if (String.IsNullOrWhiteSpace(path))
                return String.Empty;
            try
            {
                var clean = path.Trim();
                if (clean.Length > 1 && clean[0] == '"' && clean[clean.Length - 1] == '"')
                    clean = clean.Substring(1, clean.Length - 2);
                if (requireRoot && !Path.IsPathRooted(clean))
                    return String.Empty;
                var full = Path.GetFullPath(clean);
                var root = Path.GetPathRoot(full);
                return full.Length > root.Length
                    ? full.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar)
                    : full;
            }
            catch (ArgumentException) { return String.Empty; }
            catch (IOException) { return String.Empty; }
            catch (NotSupportedException) { return String.Empty; }
            catch (System.Security.SecurityException) { return String.Empty; }
            catch (UnauthorizedAccessException) { return String.Empty; }
        }

        private static IEnumerable<KeyValuePair<string, string>> ReadValues(string path)
        {
            foreach (Match match in VdfPair.Matches(ReadConfig(path)))
            {
                var value = Regex.Replace(match.Groups[2].Value, @"\\([""\\])", "$1");
                yield return new KeyValuePair<string, string>(match.Groups[1].Value, value);
            }
        }

        private static string ReadConfig(string path)
        {
            try { return File.Exists(path) ? File.ReadAllText(path) : String.Empty; }
            catch (IOException) { return String.Empty; }
            catch (UnauthorizedAccessException) { return String.Empty; }
            catch (System.Security.SecurityException) { return String.Empty; }
        }

        private static string ReadRegistry(RegistryHive hive, RegistryView view, string path, string name)
        {
            try
            {
                using (var root = RegistryKey.OpenBaseKey(hive, view))
                using (var key = root.OpenSubKey(path))
                    return key == null ? null : key.GetValue(name) as string;
            }
            catch (IOException) { return null; }
            catch (System.Security.SecurityException) { return null; }
            catch (UnauthorizedAccessException) { return null; }
        }
    }
}
