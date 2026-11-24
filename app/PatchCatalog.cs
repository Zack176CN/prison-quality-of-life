using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Web.Script.Serialization;

namespace PrisonQoL
{
    public sealed class PatchCatalog
    {
        internal const string StaffMoraleFeature = "staffDeathMoraleDecay";
        internal const string StaffMoraleConflict = "已检测到 Tyr 的「员工死亡士气惩罚逐渐消退」。请先在 Tyr 中关闭这一项。";
        internal const string TruckCapacity8 = "truckCapacity8";
        internal const string TruckCapacity12 = "truckCapacity12";
        internal const string TruckCapacity16 = "truckCapacity16";
        internal const string LongTruckFleet = "longTruckFleet";
        internal const string NativeRoadDispatch = "nativeRoadDispatch";
        internal const string MapObjectPicker = "mapObjectPicker";
        internal const int DefaultMapObjectPickerKey = 4;
        internal static readonly int[] MapObjectPickerKeys = new[] { DefaultMapObjectPickerKey }
            .Concat("IJKLMNUVY".Select(key => (int)key)).ToArray();
        private readonly string[] featureIds;
        private readonly Build[] builds;
        private readonly ILookup<string, Build> previousBuilds;
        private readonly OffsetSignature[] tyrStaffMorale;

        private PatchCatalog(string[] ids, Build[] knownBuilds, Build[] previous, SignatureRecord[] signatures)
        {
            featureIds = ids;
            builds = knownBuilds;
            previousBuilds = previous.ToLookup(build => build.SourceHash, StringComparer.Ordinal);
            tyrStaffMorale = (signatures ?? new SignatureRecord[0]).Select(row => new OffsetSignature(row)).ToArray();
        }

        public IEnumerable<string> FeatureIds { get { return Array.AsReadOnly(featureIds); } }

        public static PatchCatalog Load(Stream stream)
        {
            if (stream == null) throw new InvalidDataException("应用内缺少补丁数据。");
            using (var reader = new StreamReader(stream, Encoding.UTF8))
            {
                var serializer = new JavaScriptSerializer { MaxJsonLength = 16 * 1024 * 1024 };
                var data = serializer.Deserialize<CatalogRecord>(reader.ReadToEnd());
                var knownBuilds = LoadBuilds(data);
                var previousCatalogs = data.previousCatalogs ?? new CatalogRecord[0];
                var previous = previousCatalogs.SelectMany(LoadBuilds);
                if (data.previousCatalog != null)
                    previous = previous.Concat(LoadBuilds(data.previousCatalog));
                var previousBuilds = previous.ToArray();
                if (previousBuilds.Any(old => !knownBuilds.Any(current => current.SourceHash == old.SourceHash &&
                    current.SourceLength == old.SourceLength && current.HasTyrStaffMorale == old.HasTyrStaffMorale)))
                    throw new InvalidDataException("旧版补丁布局与支持的游戏版本不一致。");
                return new PatchCatalog(data.featureOrder, knownBuilds, previousBuilds, data.tyrStaffMoraleSignatures);
            }
        }

        private static Build[] LoadBuilds(CatalogRecord data)
        {
            if (data == null || data.schema != 1 || data.featureOrder == null || data.builds == null ||
                data.builds.Length == 0 || data.featureOrder.Length == 0 || data.featureOrder.Any(String.IsNullOrEmpty) ||
                data.featureOrder.Distinct(StringComparer.Ordinal).Count() != data.featureOrder.Length)
                throw new InvalidDataException("补丁数据格式不受支持。");
            var optionalFeature = String.IsNullOrEmpty(data.optionalFeature) ? null : data.optionalFeature;
            if ((optionalFeature != null && !data.featureOrder.Contains(optionalFeature)) ||
                data.builds.Any(record => record == null || (record.optionalLayout != null) != (optionalFeature != null)))
                throw new InvalidDataException("附加补丁布局与功能列表不一致。");
            return data.builds.Select(record => new Build(record, data.featureOrder, optionalFeature)).ToArray();
        }

        public Build FindBase(byte[] source)
        {
            string checksum = Hash(source);
            return builds.FirstOrDefault(build => build.SourceLength == source.Length && build.SourceHash == checksum);
        }

        internal bool HasTyrStaffMorale(byte[] image)
        {
            return tyrStaffMorale.Length > 0 && tyrStaffMorale.All(row =>
                row.Variants.Any(signature => Matches(image, row.Offset, signature)));
        }

        public HashSet<string> DetectFeatures(Build build, byte[] current)
        {
            if (build.OptionalLayout != null)
            {
                var detected = DetectLayoutFeatures(build.OptionalLayout, current);
                if (detected != null && detected.Contains(build.OptionalFeature))
                    return detected;
            }
            return DetectLayoutFeatures(build, current);
        }

        internal IEnumerable<string> DetectPreviousFeatures(Build build, byte[] source, byte[] current, string checksum,
            out int mapObjectPickerKey)
        {
            mapObjectPickerKey = DefaultMapObjectPickerKey;
            string[] known;
            if (build.TryGetLegacyFeatures(checksum, out known))
                return known;
            foreach (var previous in previousBuilds[build.SourceHash])
            {
                var enabled = DetectFeatures(previous, current);
                if (enabled == null)
                    continue;
                int previousKey = ReadMapObjectPickerKey(previous, current, enabled);
                if (Hash(CreateImageWithPickerKey(previous, source, enabled, previousKey)) != checksum)
                    continue;
                if (featureIds.Contains(MapObjectPicker))
                    mapObjectPickerKey = previousKey;
                return featureIds.Where(enabled.Contains);
            }
            return null;
        }

        private static HashSet<string> DetectLayoutFeatures(Build build, byte[] current)
        {
            if (current.Length != build.SourceLength + build.OutputTailLength) return null;
            var enabled = new HashSet<string>(StringComparer.Ordinal);
            foreach (var feature in build.Features)
            {
                if (IsTruckModeChoice(feature.Key))
                    continue;
                if (feature.Value.All(edit => Matches(current, edit.Offset, edit.After)))
                    enabled.Add(feature.Key);
                else if (!feature.Value.All(edit => Matches(current, edit.Offset, edit.Before)))
                    return null;
            }
            var activeModes = build.TruckModes.Where(id =>
                MatchesTruckMode(current, build, build.Features[id])).ToArray();
            if (activeModes.Length > 1)
                return null;
            if (activeModes.Length == 1)
                enabled.Add(activeModes[0]);
            if ((activeModes.Length == 0 && !MatchesTruckMode(current, build, new Edit[0])) ||
                TruckSelectionError(enabled) != null)
                return null;
            if (enabled.Contains(MapObjectPicker) &&
                !MapObjectPickerKeys.Contains(BitConverter.ToInt32(current, build.MapObjectPickerKeyOffset.Value)))
                return null;
            return enabled.Count == 0 ? null : enabled;
        }

        internal static int ReadMapObjectPickerKey(Build build, byte[] image, HashSet<string> enabled)
        {
            if (!enabled.Contains(MapObjectPicker))
                return DefaultMapObjectPickerKey;
            if (build.OptionalLayout != null && enabled.Contains(build.OptionalFeature))
                build = build.OptionalLayout;
            return BitConverter.ToInt32(image, build.MapObjectPickerKeyOffset.Value);
        }

        private static bool MatchesTruckMode(byte[] image, Build build, Edit[] activeEdits)
        {
            // Alternatives can touch shared sites or have their own native hooks. Confirm that
            // each signed alternative's region contains only the selected mode's bytes.
            foreach (var edit in build.TruckModes.SelectMany(id => build.Features[id]))
            {
                if ((long)edit.Offset + edit.Before.Length > image.Length)
                    return false;
                for (int i = 0; i < edit.Before.Length; i++)
                {
                    int offset = edit.Offset + i;
                    var active = activeEdits.FirstOrDefault(item => offset >= item.Offset && offset - item.Offset < item.After.Length);
                    byte expected = active == null ? edit.Before[i] : active.After[offset - active.Offset];
                    if (image[offset] != expected)
                        return false;
                }
            }
            return true;
        }

        internal static bool IsTruckCapacityChoice(string id)
        {
            return id == TruckCapacity8 || id == TruckCapacity12 || id == TruckCapacity16;
        }

        internal static bool IsTruckModeChoice(string id)
        {
            return IsTruckCapacityChoice(id) || id == LongTruckFleet;
        }

        private static string TruckSelectionError(IEnumerable<string> enabled)
        {
            if (enabled.Count(IsTruckModeChoice) > 1)
                return "供给货车只能选择一种容量方案。";
            if (enabled.Contains(LongTruckFleet) && !enabled.Contains(NativeRoadDispatch))
                return "原生长车需要启用出货调度台。";
            return null;
        }

        private static bool Matches(byte[] data, int offset, byte[] signature)
        {
            if ((long)offset + signature.Length > data.Length) return false;
            for (int i = 0; i < signature.Length; i++)
                if (data[offset + i] != signature[i]) return false;
            return true;
        }

        public byte[] CreateImage(Build build, byte[] source, IEnumerable<string> selected)
        {
            return CreateImageWithPickerKey(build, source, selected, DefaultMapObjectPickerKey);
        }

        internal byte[] CreateImageWithPickerKey(Build build, byte[] source, IEnumerable<string> selected, int pickerKey)
        {
            if (build == null || source == null || source.Length != build.SourceLength || Hash(source) != build.SourceHash)
                throw new InvalidDataException("源游戏文件已变化，应用已取消。");
            var enabled = new HashSet<string>(selected, StringComparer.Ordinal);
            if (build.OptionalLayout != null && enabled.Contains(build.OptionalFeature))
                build = build.OptionalLayout;
            string truckSelectionError = TruckSelectionError(enabled);
            if (truckSelectionError != null)
                throw new InvalidOperationException(truckSelectionError);
            if (build.HasTyrStaffMorale && enabled.Contains(StaffMoraleFeature))
                throw new InvalidOperationException(StaffMoraleConflict);
            if (enabled.Any(id => !build.Features.ContainsKey(id)))
                throw new InvalidDataException("所选功能不在当前游戏版本的补丁数据中。");
            if (enabled.Contains(MapObjectPicker) && !MapObjectPickerKeys.Contains(pickerKey))
                throw new ArgumentOutOfRangeException("pickerKey", "请选择支持的地图物件取样快捷键。");
            if (enabled.Count == 0) return source;

            var edits = build.CommonEdits.Concat(enabled.SelectMany(id => build.Features[id])).OrderBy(edit => edit.Offset);
            var image = new byte[checked(source.Length + build.OutputTailLength)];
            Buffer.BlockCopy(source, 0, image, 0, source.Length);
            build.CopyTail(source, image);
            int end = 0;
            foreach (var edit in edits)
            {
                if (edit.Offset < end || (long)edit.Offset + edit.Before.Length > source.Length)
                    throw new InvalidDataException("补丁数据包含重叠或超出边界的位置。");
                for (int i = 0; i < edit.Before.Length; i++)
                    if (source[edit.Offset + i] != edit.Before[i])
                        throw new InvalidDataException("游戏的原始指令校验失败。");
                Buffer.BlockCopy(edit.After, 0, image, edit.Offset, edit.After.Length);
                end = edit.Offset + edit.Before.Length;
            }
            int maximum = build.Features.Count - Math.Max(0, build.TruckModes.Length - 1);
            if (enabled.Count == maximum)
            {
                var expectedHash = enabled.Contains(LongTruckFleet) ? build.LongTruckFleetAllFeaturesHash
                    : enabled.Contains(TruckCapacity8) ? build.TruckCapacity8AllFeaturesHash
                    : enabled.Contains(TruckCapacity16) ? build.TruckCapacity16AllFeaturesHash : build.AllFeaturesHash;
                if (Hash(image) != expectedHash)
                    throw new InvalidDataException("已生成的游戏文件未通过校验。");
            }
            if (enabled.Contains(MapObjectPicker) && pickerKey != DefaultMapObjectPickerKey)
                Buffer.BlockCopy(BitConverter.GetBytes(pickerKey), 0, image, build.MapObjectPickerKeyOffset.Value, sizeof(int));
            return image;
        }

        public static string Hash(byte[] data)
        {
            using (var sha = SHA256.Create())
                return BitConverter.ToString(sha.ComputeHash(data)).Replace("-", "").ToLowerInvariant();
        }

        public sealed class Build
        {
            public string Name { get; private set; }
            internal readonly bool HasTyrStaffMorale;
            internal readonly string SourceHash;
            internal readonly string OptionalFeature;
            internal readonly Build OptionalLayout;
            internal readonly string AllFeaturesHash;
            internal readonly string TruckCapacity8AllFeaturesHash;
            internal readonly string TruckCapacity16AllFeaturesHash;
            internal readonly string LongTruckFleetAllFeaturesHash;
            internal readonly bool HasTruckCapacityChoices;
            internal readonly string[] TruckModes;
            internal readonly int SourceLength;
            internal readonly int? MapObjectPickerKeyOffset;
            private readonly byte[] tail;
            private readonly SourceSpanRecord appendFromSource;
            private readonly Dictionary<string, string[]> legacyOutputs;
            internal int OutputTailLength {
                get { return checked(tail.Length + (appendFromSource == null ? 0 : appendFromSource.length)); }
            }
            internal readonly Edit[] CommonEdits;
            internal readonly Dictionary<string, Edit[]> Features;

            internal Build(BuildRecord record, IEnumerable<string> expected, string optionalFeature = null)
            {
                Name = record.name;
                HasTyrStaffMorale = record.tyrStaffMoraleInstalled;
                SourceHash = record.sourceSha256;
                OptionalFeature = optionalFeature;
                if (optionalFeature != null)
                {
                    var extension = record.optionalLayout;
                    if (extension == null || extension.optionalLayout != null || extension.sourceSha256 != SourceHash ||
                        extension.sourceLength != record.sourceLength || extension.tyrStaffMoraleInstalled != HasTyrStaffMorale ||
                        (extension.legacyOutputs != null && extension.legacyOutputs.Count > 0))
                        throw new InvalidDataException("附加补丁布局与原始游戏版本不一致。");
                    OptionalLayout = new Build(extension, expected);
                    if (!OptionalLayout.Features[optionalFeature].Any(edit => !edit.Before.SequenceEqual(edit.After)))
                        throw new InvalidDataException("附加补丁缺少用于检测的游戏指令。");
                    expected = expected.Where(id => id != optionalFeature);
                }
                AllFeaturesHash = record.allFeaturesSha256;
                TruckCapacity8AllFeaturesHash = record.truckCapacity8AllFeaturesSha256;
                TruckCapacity16AllFeaturesHash = record.truckCapacity16AllFeaturesSha256;
                LongTruckFleetAllFeaturesHash = record.longTruckFleetAllFeaturesSha256;
                SourceLength = record.sourceLength;
                MapObjectPickerKeyOffset = record.mapObjectPickerKeyOffset;
                tail = Convert.FromBase64String(record.append);
                appendFromSource = record.appendFromSource;
                CommonEdits = record.commonEdits.Select(entry => new Edit(entry)).ToArray();
                Features = record.features.ToDictionary(
                    pair => pair.Key, pair => pair.Value.Select(entry => new Edit(entry)).ToArray(), StringComparer.Ordinal);
                HasTruckCapacityChoices = Features.ContainsKey(TruckCapacity12) && Features.ContainsKey(TruckCapacity16);
                TruckModes = Features.Keys.Where(IsTruckModeChoice).ToArray();
                legacyOutputs = record.legacyOutputs ?? new Dictionary<string, string[]>(StringComparer.Ordinal);
                var available = expected.Where(id => !HasTyrStaffMorale || id != StaffMoraleFeature);
                if (String.IsNullOrEmpty(Name) || SourceLength <= 0 || SourceHash.Length != 64 ||
                    AllFeaturesHash.Length != 64 || !new HashSet<string>(available, StringComparer.Ordinal).SetEquals(Features.Keys))
                    throw new InvalidDataException("补丁数据中的游戏版本记录无效。");
                if (HasTruckCapacityChoices)
                {
                    var first = Features[TruckCapacity12];
                    var second = Features[TruckCapacity16];
                    if (String.IsNullOrEmpty(TruckCapacity16AllFeaturesHash) || TruckCapacity16AllFeaturesHash.Length != 64 ||
                        first.Length == 0 || first.Length != second.Length ||
                        first.Where((item, index) => item.Offset != second[index].Offset || !item.Before.SequenceEqual(second[index].Before)).Any() ||
                        !first.Where((item, index) => !item.After.SequenceEqual(second[index].After)).Any())
                        throw new InvalidDataException("货车容量补丁的备选指令范围无效。");
                }
                else if (Features.Keys.Any(IsTruckCapacityChoice))
                    throw new InvalidDataException("货车容量补丁缺少备选项。");
                if (Features.ContainsKey(TruckCapacity8) &&
                    (String.IsNullOrEmpty(TruckCapacity8AllFeaturesHash) || TruckCapacity8AllFeaturesHash.Length != 64 ||
                    Features[TruckCapacity8].Length == 0))
                    throw new InvalidDataException("原版 8 格容量补丁的校验记录无效。");
                if (Features.ContainsKey(LongTruckFleet) && (!Features.ContainsKey(NativeRoadDispatch) ||
                    String.IsNullOrEmpty(LongTruckFleetAllFeaturesHash) || LongTruckFleetAllFeaturesHash.Length != 64 ||
                    Features[LongTruckFleet].Length == 0))
                    throw new InvalidDataException("原生长车补丁的依赖或校验记录无效。");
                if (legacyOutputs.Any(entry => entry.Key.Length != 64 || entry.Value == null ||
                    entry.Value.Any(id => !Features.ContainsKey(id)) || TruckSelectionError(entry.Value) != null))
                    throw new InvalidDataException("旧补丁校验记录无效。");
                if (appendFromSource != null && (appendFromSource.sourceOffset < 0 || appendFromSource.length <= 0 ||
                    (long)appendFromSource.sourceOffset + appendFromSource.length > SourceLength ||
                    appendFromSource.tailOffset < 0 || appendFromSource.tailOffset > tail.Length))
                    throw new InvalidDataException("补丁数据中的本地游戏数据范围无效。");
                if (Features.ContainsKey(MapObjectPicker) != MapObjectPickerKeyOffset.HasValue ||
                    MapObjectPickerKeyOffset.HasValue && !HasValidMapObjectPickerSlot(MapObjectPickerKeyOffset.Value))
                    throw new InvalidDataException("地图物件取样的快捷键记录无效。");
            }

            private bool HasValidMapObjectPickerSlot(int offset)
            {
                if (offset < SourceLength || (long)offset + sizeof(int) > (long)SourceLength + OutputTailLength)
                    return false;
                var index = offset - SourceLength;
                if (appendFromSource != null && (long)index + sizeof(int) > appendFromSource.tailOffset)
                {
                    if (index < (long)appendFromSource.tailOffset + appendFromSource.length)
                        return false;
                    index -= appendFromSource.length;
                }
                return BitConverter.ToInt32(tail, index) == DefaultMapObjectPickerKey;
            }

            internal bool TryGetLegacyFeatures(string checksum, out string[] selected)
            {
                return legacyOutputs.TryGetValue(checksum, out selected);
            }

            internal void CopyTail(byte[] source, byte[] output)
            {
                if (appendFromSource == null)
                {
                    Buffer.BlockCopy(tail, 0, output, SourceLength, tail.Length);
                    return;
                }
                // Keep the existing runtime table in the player's installation.
                int offset = appendFromSource.tailOffset;
                int count = appendFromSource.length;
                Buffer.BlockCopy(tail, 0, output, SourceLength, offset);
                Buffer.BlockCopy(source, appendFromSource.sourceOffset, output, SourceLength + offset, count);
                Buffer.BlockCopy(tail, offset, output, SourceLength + offset + count, tail.Length - offset);
            }
        }

        internal sealed class Edit
        {
            public readonly int Offset;
            public readonly byte[] Before;
            public readonly byte[] After;

            public Edit(EditRecord record)
            {
                Offset = record.offset;
                Before = Convert.FromBase64String(record.before);
                After = Convert.FromBase64String(record.after);
                if (Offset < 0 || Before.Length == 0 || Before.Length != After.Length)
                    throw new InvalidDataException("补丁数据中的指令长度无效。");
            }
        }

        private sealed class OffsetSignature
        {
            internal readonly int Offset;
            internal readonly byte[][] Variants;

            internal OffsetSignature(SignatureRecord row)
            {
                Offset = row.offset;
                Variants = row.variants.Select(Convert.FromBase64String).ToArray();
                if (Offset < 0 || Variants.Length == 0 || Variants.Any(signature => signature.Length == 0))
                    throw new InvalidDataException("Tyr 冲突检测签名无效。");
            }
        }

        public sealed class CatalogRecord
        {
            public int schema { get; set; }
            public string[] featureOrder { get; set; }
            public string optionalFeature { get; set; }
            public BuildRecord[] builds { get; set; }
            public SignatureRecord[] tyrStaffMoraleSignatures { get; set; }
            public CatalogRecord[] previousCatalogs { get; set; }
            public CatalogRecord previousCatalog { get; set; }
        }

        public sealed class BuildRecord
        {
            public string name { get; set; }
            public string sourceSha256 { get; set; }
            public int sourceLength { get; set; }
            public int? mapObjectPickerKeyOffset { get; set; }
            public string allFeaturesSha256 { get; set; }
            public string truckCapacity8AllFeaturesSha256 { get; set; }
            public string truckCapacity16AllFeaturesSha256 { get; set; }
            public string longTruckFleetAllFeaturesSha256 { get; set; }
            public string append { get; set; }
            public SourceSpanRecord appendFromSource { get; set; }
            public EditRecord[] commonEdits { get; set; }
            public Dictionary<string, EditRecord[]> features { get; set; }
            public Dictionary<string, string[]> legacyOutputs { get; set; }
            public bool tyrStaffMoraleInstalled { get; set; }
            public BuildRecord optionalLayout { get; set; }
        }

        public sealed class SignatureRecord
        {
            public int offset { get; set; }
            public string[] variants { get; set; }
        }

        public sealed class SourceSpanRecord
        {
            public int sourceOffset { get; set; }
            public int tailOffset { get; set; }
            public int length { get; set; }
        }

        public sealed class EditRecord
        {
            public int offset { get; set; }
            public string before { get; set; }
            public string after { get; set; }
        }
    }
}
