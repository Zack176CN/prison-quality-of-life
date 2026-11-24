using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace PrisonQoL
{
    internal sealed class MainForm : Form
    {
        private const string PatchTitle = "生活与质量更新补丁";
        private static readonly Color Ink = Color.FromArgb(31, 43, 54);
        private static readonly Color Muted = Color.FromArgb(77, 91, 104);
        private static readonly Color Accent = Color.FromArgb(17, 101, 103);
        private static readonly Color DisabledAccent = Color.FromArgb(223, 232, 235);
        private static readonly Color Error = Color.FromArgb(150, 41, 37);
        private static readonly Color Surface = Color.White;
        private const string StaffMoraleDescription = "每过一个完整游戏日减轻 1 点员工死亡士气惩罚，保留原版无事故奖励规则。";
        private const string DispatchConsoleFeature = PatchCatalog.NativeRoadDispatch;
        private const string BalancedPickupFeature = "balancedPickups";

        private readonly PatchInstaller installer;
        private readonly Dictionary<string, CheckBox> featureBoxes =
            new Dictionary<string, CheckBox>(StringComparer.Ordinal);
        private readonly List<Action> localizeControls = new List<Action>();
        private readonly Button languageButton;
        private readonly TextBox directoryBox;
        private readonly Button detectButton;
        private readonly Button browseButton;
        private readonly Button selectAllButton;
        private readonly Button applyButton;
        private readonly Button restoreButton;
        private readonly Label statusLabel;
        private readonly LinkLabel refreshLink;
        private Label staffMoraleHelp;
        private CheckBox dispatchToggle;
        private RadioButton preferredCapacity;
        private RadioButton fixedCapacity;
        private ComboBox capacityPicker;
        private ComboBox mapObjectPickerShortcut;
        private readonly string[] fixedCapacityModes;
        private InstallStatus currentStatus;
        private string statusMessage = String.Empty;
        private object[] statusArguments = new object[0];
        private bool busy;

        public MainForm(PatchInstaller installer, string initialDirectory)
        {
            this.installer = installer;
            fixedCapacityModes = new[] {
                installer.FeatureIds.Contains(PatchCatalog.TruckCapacity8) ? PatchCatalog.TruckCapacity8 : null
            }.Concat(new[] {
                PatchCatalog.TruckCapacity12, PatchCatalog.TruckCapacity16
            }.Where(installer.FeatureIds.Contains)).ToArray();
            Text = PatchTitle;
            StartPosition = FormStartPosition.CenterScreen;
            ClientSize = new Size(752, 714);
            MinimumSize = new Size(640, 500);
            BackColor = Color.FromArgb(243, 246, 248);
            ForeColor = Ink;
            Font = new Font("Microsoft YaHei UI", 9F);
            AutoScaleMode = AutoScaleMode.Dpi;
            AutoScaleDimensions = new SizeF(96, 96);
            AllowDrop = true;

            var layout = new TableLayoutPanel {
                Dock = DockStyle.Fill, Padding = new Padding(23, 16, 23, 15), RowCount = 5, ColumnCount = 1
            };
            layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 61F));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 68F));
            layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100F));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 52F));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 46F));
            Controls.Add(layout);

            var heading = new TableLayoutPanel {
                Dock = DockStyle.Fill, Margin = Padding.Empty, RowCount = 1, ColumnCount = 2
            };
            heading.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));
            heading.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 128F));
            var headingText = new Panel { Dock = DockStyle.Fill, Margin = Padding.Empty };
            headingText.Controls.Add(new Label {
                Text = PatchTitle, ForeColor = Ink, Font = new Font(Font.FontFamily, 19F, FontStyle.Bold),
                Location = new Point(0, 0), AutoSize = true
            });
            headingText.Controls.Add(new Label {
                Text = "勾选功能并应用，之后可直接从 Steam 启动游戏。", ForeColor = Muted,
                Location = new Point(1, 35), AutoSize = true
            });
            heading.Controls.Add(headingText, 0, 0);
            languageButton = CreateButton("English", false);
            languageButton.AccessibleName = "切换语言";
            languageButton.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            languageButton.Margin = new Padding(0, 2, 0, 0);
            languageButton.Size = new Size(104, 34);
            languageButton.Click += (sender, args) => {
                ManagerLanguage.Toggle();
                ApplyLanguage();
            };
            heading.Controls.Add(languageButton, 1, 0);
            layout.Controls.Add(heading, 0, 0);

            var location = new TableLayoutPanel {
                Dock = DockStyle.Fill, Margin = Padding.Empty, RowCount = 2, ColumnCount = 3
            };
            location.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));
            location.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 104F));
            location.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 110F));
            location.RowStyles.Add(new RowStyle(SizeType.Absolute, 22F));
            location.RowStyles.Add(new RowStyle(SizeType.Absolute, 36F));
            location.Controls.Add(new Label {
                Text = "游戏目录", AutoSize = true, Margin = new Padding(0, 1, 0, 0)
            }, 0, 0);
            directoryBox = new TextBox {
                AccessibleName = "游戏目录", ReadOnly = true, AllowDrop = true,
                Anchor = AnchorStyles.Left | AnchorStyles.Right,
                BackColor = Surface, Margin = new Padding(0, 0, 11, 0)
            };
            location.Controls.Add(directoryBox, 0, 1);
            detectButton = CreateButton("自动检测", false);
            detectButton.Dock = DockStyle.Fill;
            detectButton.Margin = new Padding(0, 2, 10, 2);
            location.Controls.Add(detectButton, 1, 1);
            browseButton = CreateButton("选择目录…", false);
            browseButton.Dock = DockStyle.Fill;
            browseButton.Margin = new Padding(0, 2, 0, 2);
            location.Controls.Add(browseButton, 2, 1);
            layout.Controls.Add(location, 0, 1);

            var featuresPanel = new TableLayoutPanel {
                BackColor = Surface, Dock = DockStyle.Fill, Margin = Padding.Empty, ColumnCount = 1, RowCount = 2
            };
            featuresPanel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));
            featuresPanel.RowStyles.Add(new RowStyle(SizeType.Absolute, 39F));
            featuresPanel.RowStyles.Add(new RowStyle(SizeType.Percent, 100F));
            var featureActions = new TableLayoutPanel {
                ColumnCount = 2, RowCount = 1, Dock = DockStyle.Fill, Margin = new Padding(13, 5, 13, 0)
            };
            featureActions.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));
            featureActions.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 104F));
            featureActions.Controls.Add(new Label {
                Text = "可选功能", ForeColor = Muted, Dock = DockStyle.Fill, Margin = Padding.Empty,
                TextAlign = ContentAlignment.MiddleLeft
            }, 0, 0);
            selectAllButton = CreateButton("全选", false);
            selectAllButton.AccessibleDescription = "选择两个分组中与当前游戏版本兼容的补丁。";
            selectAllButton.Dock = DockStyle.Fill;
            selectAllButton.Margin = Padding.Empty;
            selectAllButton.Click += (sender, args) => SelectAllCompatibleFeatures();
            featureActions.Controls.Add(selectAllButton, 1, 0);
            featuresPanel.Controls.Add(featureActions, 0, 0);

            var featureScroll = new Panel {
                BackColor = Surface, Dock = DockStyle.Fill, AutoScroll = true, Margin = Padding.Empty,
                AccessibleName = "可选功能"
            };
            var featureLayout = new TableLayoutPanel {
                ColumnCount = 1, Dock = DockStyle.Top, AutoSize = true, Margin = Padding.Empty,
                Padding = new Padding(13, 5, 13, 5), GrowStyle = TableLayoutPanelGrowStyle.AddRows
            };
            featureLayout.SizeChanged += (sender, args) => {
                featureScroll.AutoScrollMinSize = new Size(0, featureLayout.Height);
            };
            featureLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));
            AddFeatureGroups(featureLayout);
            featureScroll.Controls.Add(featureLayout);
            featuresPanel.Controls.Add(featureScroll, 0, 1);
            layout.Controls.Add(featuresPanel, 0, 2);

            var note = new Label {
                Text = "应用前请保存并退出游戏。关闭施工补丁前，请先完成或取消已安排的相关施工。",
                ForeColor = Muted, Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleLeft,
                Margin = new Padding(1, 4, 1, 2)
            };
            layout.Controls.Add(note, 0, 3);

            var footer = new TableLayoutPanel {
                ColumnCount = 3, RowCount = 1, Dock = DockStyle.Fill, Margin = Padding.Empty
            };
            footer.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));
            footer.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 124F));
            footer.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 119F));
            footer.RowStyles.Add(new RowStyle(SizeType.Percent, 100F));
            var feedback = new TableLayoutPanel {
                ColumnCount = 1, RowCount = 2, Dock = DockStyle.Fill, Margin = new Padding(0, 0, 10, 0)
            };
            feedback.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));
            feedback.RowStyles.Add(new RowStyle(SizeType.Percent, 100F));
            feedback.RowStyles.Add(new RowStyle(SizeType.Absolute, 18F));
            statusLabel = new Label {
                Dock = DockStyle.Fill, TextAlign = ContentAlignment.BottomLeft, AutoEllipsis = true,
                AccessibleName = "补丁状态", Margin = Padding.Empty
            };
            refreshLink = new LinkLabel {
                Text = "复查当前目录", AutoSize = true, LinkColor = Accent,
                ActiveLinkColor = Ink, Margin = Padding.Empty
            };
            feedback.Controls.Add(statusLabel, 0, 0);
            feedback.Controls.Add(refreshLink, 0, 1);
            footer.Controls.Add(feedback, 0, 0);

            restoreButton = CreateButton("恢复原文件", false);
            restoreButton.Dock = DockStyle.Fill;
            restoreButton.Margin = new Padding(0, 5, 9, 4);
            footer.Controls.Add(restoreButton, 1, 0);
            applyButton = CreateButton("应用", true);
            applyButton.AccessibleName = "应用所选补丁";
            applyButton.Dock = DockStyle.Fill;
            applyButton.Margin = new Padding(0, 5, 0, 4);
            footer.Controls.Add(applyButton, 2, 0);
            layout.Controls.Add(footer, 0, 4);

            detectButton.Click += async (sender, args) => await AutoDetectAsync();
            browseButton.Click += async (sender, args) => await BrowseAsync();
            refreshLink.LinkClicked += async (sender, args) => await RefreshAsync(true);
            applyButton.Click += async (sender, args) => await ApplyAsync(false);
            restoreButton.Click += async (sender, args) => await ApplyAsync(true);
            Shown += async (sender, args) => {
                if (String.IsNullOrWhiteSpace(initialDirectory))
                    await AutoDetectAsync();
                else
                    await SelectDirectoryAsync(initialDirectory, false);
            };
            DragEnter += CheckDrop;
            DragDrop += async (sender, args) => await DropDirectoryAsync(args);
            directoryBox.DragEnter += CheckDrop;
            directoryBox.DragDrop += async (sender, args) => await DropDirectoryAsync(args);
            AcceptButton = applyButton;
            RegisterLocalizedControls(this);
            ApplyLanguage();
            UpdateButtons();
        }

        private void RegisterLocalizedControls(Control control)
        {
            string text = control is TextBoxBase || control is ComboBox ? null : control.Text;
            string name = control.AccessibleName;
            string description = control.AccessibleDescription;
            if (!String.IsNullOrEmpty(text) || name != null || description != null)
                localizeControls.Add(() => {
                    if (!String.IsNullOrEmpty(text))
                        control.Text = ManagerLanguage.Translate(text);
                    if (name != null)
                        control.AccessibleName = ManagerLanguage.Translate(name);
                    if (description != null)
                        control.AccessibleDescription = ManagerLanguage.Translate(description);
                });
            foreach (Control child in control.Controls)
                RegisterLocalizedControls(child);
        }

        private void ApplyLanguage()
        {
            SuspendLayout();
            try
            {
                foreach (var localize in localizeControls)
                    localize();
                languageButton.Text = ManagerLanguage.IsEnglish ? "简体中文" : "English";
                LocalizeOptions(mapObjectPickerShortcut, PatchCatalog.MapObjectPickerKeys.Select(DescribePickerKey));
                LocalizeOptions(capacityPicker, fixedCapacityModes.Select(DescribeCapacityMode));
                UpdateStaffMoraleHelp();
                UpdateStatusText();
            }
            finally
            {
                ResumeLayout(true);
            }
        }

        private static void LocalizeOptions(ComboBox control, IEnumerable<string> choices)
        {
            if (control == null)
                return;
            int selection = control.SelectedIndex;
            control.BeginUpdate();
            try
            {
                control.Items.Clear();
                control.Items.AddRange(choices.Select(choice => ManagerLanguage.Translate(choice)).ToArray());
                control.SelectedIndex = selection;
            }
            finally
            {
                control.EndUpdate();
            }
        }

        private static Button CreateButton(string text, bool primary)
        {
            var control = new Button { Text = text, Cursor = Cursors.Hand, UseVisualStyleBackColor = !primary };
            if (primary)
            {
                control.FlatStyle = FlatStyle.Flat;
                control.FlatAppearance.BorderColor = Accent;
                control.BackColor = Accent;
                control.ForeColor = Color.White;
            }
            return control;
        }

        private void AddFeatureGroups(TableLayoutPanel layout)
        {
            var features = installer.FeatureIds.ToArray();
            AddFeatureHeading(layout, "体验优化");
            foreach (var feature in features.Where(id => !IsRepairFeature(id) && !IsDispatchFeature(id))
                .OrderBy(id => id == "logicBridgeSignalOptimization"))
                AddFeature(layout, feature);
            if (features.Any(IsDispatchFeature))
                AddDispatchGroup(layout);
            var repairs = features.Where(IsRepairFeature).ToArray();
            if (repairs.Length == 0)
                return;
            AddFeatureHeading(layout, "补丁修复");
            foreach (var feature in repairs)
                AddFeature(layout, feature);
        }

        private void AddFeatureHeading(TableLayoutPanel layout, string title)
        {
            AppendFeatureRow(layout, new Label {
                Text = title, ForeColor = Accent, Font = new Font(Font.FontFamily, 11F, FontStyle.Bold),
                Dock = DockStyle.Fill, Margin = Padding.Empty, TextAlign = ContentAlignment.MiddleLeft
            }, 32F);
        }

        private static bool IsRepairFeature(string id)
        {
            return id == PatchCatalog.StaffMoraleFeature || id == "reformProgramProgress";
        }

        private void AddFeature(TableLayoutPanel layout, string id)
        {
            string title;
            string description;
            bool fitDescription = false;
            switch (id)
            {
                case "removeTreeStumps":
                    title = "砍树后不留树桩";
                    description = "工人完成拆树后照常产出木材。";
                    break;
                case "doubleClickDoorReplacement":
                    title = "自动替换已安装的旧门";
                    description = "选择单格或双格新门后单击旧门所在位置，或用墙壁工具点击、拖过旧门。施工期间保留旧门。";
                    break;
                case "clearTreesForConstruction":
                    title = "建门和墙前自动清理树木";
                    description = "墙线、单格门或双格门覆盖树木或树桩时，工人先清理，再开始施工。";
                    break;
                case PatchCatalog.MapObjectPicker:
                    title = "地图物件取样";
                    description = "指向物件、墙壁或地板，按快捷键打开对应建造栏，并定位和高亮目标。";
                    fitDescription = true;
                    break;
                case "pinyinSearch":
                    title = "拼音搜索";
                    description = "在物品、房间等建造栏的原版搜索框输入全拼或首字母。例如 jiaoshi 或 js 可找到「教室」。";
                    fitDescription = true;
                    break;
                case "rightClickDeselect":
                    title = "右键取消选中物品";
                    description = "在地图上右键单击，游戏先按原版规则处理工单取消，再清除建造预览并保留建造栏。按住右键拖动仍沿用原版操作。";
                    fitDescription = true;
                    break;
                case "reformProgramProgress":
                    title = "修复改造计划进度保存";
                    description = "保存「三振出局计划」和「鲜花疗法」的囚犯进度，下次活动时接着进行。";
                    break;
                case "logicBridgeSignalOptimization":
                    title = "逻辑桥信号传播优化";
                    description = "默认关闭。逻辑桥频繁向大片连线传播时可常驻。低负载建议关闭，收益尚无实测。保留原版信号和顺序。\r\n" +
                        "同一大型电路档，原版 10 倍速两轮。模拟推进 +27.45%–34.81%，FPS +38.32%–46.93%，p95／p99 帧时间缩短 7.52–9.15／8.74–9.53 ms。";
                    fitDescription = true;
                    break;
                case BalancedPickupFeature:
                    title = "均衡取货";
                    description = "在出货调度台中开启「均衡取货」。垃圾和出口货物同时积压时，加派货车交替取货。兼容旧版出货调度台。";
                    break;
                case DispatchConsoleFeature:
                    title = "出货调度台";
                    description = "物件栏建造，价格 200。可手动或按积压加派，最多同时 5 辆。设置随监狱存档保存。启用前请停用旧版调度台模组。";
                    break;
                case PatchCatalog.StaffMoraleFeature:
                    title = "员工死亡士气惩罚逐渐消退";
                    description = StaffMoraleDescription;
                    break;
                default:
                    title = id;
                    description = String.Empty;
                    break;
            }

            bool hasShortcut = id == PatchCatalog.MapObjectPicker;
            var row = new TableLayoutPanel {
                ColumnCount = 1, RowCount = hasShortcut ? 3 : 2,
                Dock = fitDescription ? DockStyle.Fill : DockStyle.Top,
                Height = 68, Margin = Padding.Empty,
                Padding = new Padding(0, 2, 0, 2), BackColor = Surface
            };
            row.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));
            row.RowStyles.Add(new RowStyle(SizeType.Absolute, 24F));
            row.RowStyles.Add(new RowStyle(SizeType.Percent, 100F));
            var check = new CheckBox {
                Text = title, AccessibleDescription = description, Dock = DockStyle.Fill,
                Font = new Font(Font.FontFamily, 10F, FontStyle.Bold), Margin = Padding.Empty
            };
            var help = new Label {
                Text = description, Dock = DockStyle.Fill, ForeColor = Muted,
                Margin = new Padding(21, 0, 3, fitDescription ? 2 : 0)
            };
            row.Controls.Add(check, 0, 0);
            row.Controls.Add(help, 0, 1);
            if (id == PatchCatalog.StaffMoraleFeature)
                staffMoraleHelp = help;
            if (hasShortcut)
                AddMapObjectPickerShortcut(row);
            AppendFeatureRow(layout, row, hasShortcut ? 94F : 68F);
            if (fitDescription)
            {
                RowStyle style = layout.RowStyles[layout.GetRow(row)];
                MethodInvoker fitRowToDescription = () => {
                    int width = help.ClientSize.Width;
                    if (width <= 0)
                        return;
                    int height = help.GetPreferredSize(new Size(width, 0)).Height;
                    float fixedHeight = row.RowStyles.Cast<RowStyle>()
                        .Where(item => item.SizeType == SizeType.Absolute).Sum(item => item.Height);
                    height += row.Padding.Vertical + help.Margin.Vertical + (int)Math.Ceiling(fixedHeight);
                    if (style.Height != height)
                        style.Height = height;
                };
                EventHandler queueFit = (sender, args) => {
                    // Measure after the current layout pass so the scroll range uses the new row height.
                    if (help.IsHandleCreated)
                        help.BeginInvoke(fitRowToDescription);
                };
                help.HandleCreated += queueFit;
                help.SizeChanged += queueFit;
                help.FontChanged += queueFit;
                help.TextChanged += queueFit;
            }
            featureBoxes.Add(id, check);
            check.CheckedChanged += (sender, args) => {
                if (id == DispatchConsoleFeature && !check.Checked && PreferredCapacitySelected)
                    fixedCapacity.Checked = true;
                UpdateButtons();
            };
        }

        private void AddMapObjectPickerShortcut(TableLayoutPanel row)
        {
            var shortcutRow = new FlowLayoutPanel {
                Dock = DockStyle.Fill, Margin = Padding.Empty, WrapContents = false
            };
            shortcutRow.Controls.Add(new Label {
                Text = "快捷键", AutoSize = true, Margin = new Padding(21, 6, 8, 0)
            });
            mapObjectPickerShortcut = new ComboBox {
                AccessibleName = "地图物件取样快捷键", DropDownStyle = ComboBoxStyle.DropDownList,
                Width = 150, Margin = new Padding(0, 1, 0, 0)
            };
            mapObjectPickerShortcut.Items.AddRange(PatchCatalog.MapObjectPickerKeys.Select(DescribePickerKey).ToArray());
            mapObjectPickerShortcut.SelectedIndex = 0;
            mapObjectPickerShortcut.SelectedIndexChanged += (sender, args) => UpdateButtons();
            shortcutRow.Controls.Add(mapObjectPickerShortcut);
            AppendFeatureRow(row, shortcutRow, 30F);
        }

        private static string DescribePickerKey(int key)
        {
            if (key == PatchCatalog.DefaultMapObjectPickerKey)
                return "鼠标中键";
            return ((char)key).ToString();
        }

        private static bool IsDispatchFeature(string id)
        {
            return id == DispatchConsoleFeature || id == BalancedPickupFeature || PatchCatalog.IsTruckModeChoice(id);
        }

        private void AddDispatchGroup(TableLayoutPanel layout)
        {
            dispatchToggle = new CheckBox {
                Text = "出货调度", Dock = DockStyle.Fill, Margin = Padding.Empty,
                Font = new Font(Font.FontFamily, 10F, FontStyle.Bold),
                AccessibleDescription = "控制下方的出货调度台、均衡取货和供给货车容量。"
            };
            dispatchToggle.CheckedChanged += (sender, args) => UpdateButtons();
            AppendFeatureRow(layout, dispatchToggle, 28F);

            var group = new GroupBox {
                AccessibleName = "出货调度选项", Dock = DockStyle.Fill, Padding = new Padding(11, 5, 11, 5),
                Margin = new Padding(0, 0, 0, 8)
            };
            var options = new TableLayoutPanel {
                Dock = DockStyle.Fill, ColumnCount = 1, GrowStyle = TableLayoutPanelGrowStyle.AddRows,
                Margin = Padding.Empty, Padding = new Padding(18, 0, 0, 0)
            };
            options.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));
            if (installer.FeatureIds.Contains(DispatchConsoleFeature))
                AddFeature(options, DispatchConsoleFeature);
            if (installer.FeatureIds.Contains(BalancedPickupFeature))
                AddFeature(options, BalancedPickupFeature);
            bool hasPreferredMode = installer.FeatureIds.Contains(PatchCatalog.LongTruckFleet);
            if (hasPreferredMode || fixedCapacityModes.Any(mode => mode != null))
                AddCapacityPicker(options, hasPreferredMode);
            group.Controls.Add(options);
            float optionsHeight = options.RowStyles.Cast<RowStyle>().Sum(style => style.Height);
            AppendFeatureRow(layout, group, optionsHeight + 18F);
        }

        private void AddCapacityPicker(TableLayoutPanel layout, bool hasPreferredMode)
        {
            var row = new TableLayoutPanel {
                ColumnCount = 1, Dock = DockStyle.Fill, GrowStyle = TableLayoutPanelGrowStyle.AddRows, Margin = Padding.Empty
            };
            row.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));
            AppendFeatureRow(row, new Label {
                Text = "供给货车容量", Font = new Font(Font.FontFamily, 10F, FontStyle.Bold),
                Dock = DockStyle.Fill, Margin = new Padding(1, 2, 0, 0)
            }, 24F);
            if (hasPreferredMode)
            {
                preferredCapacity = new RadioButton {
                    Text = "首选方案  在游戏内通过出货调度台调整车长", AccessibleName = "首选方案", Checked = true,
                    Dock = DockStyle.Fill, Margin = new Padding(18, 0, 1, 0)
                };
                fixedCapacity = new RadioButton {
                    Text = "备选方案  固定容量", AccessibleName = "备选方案",
                    Dock = DockStyle.Fill, Margin = new Padding(18, 0, 1, 0)
                };
                AppendFeatureRow(row, preferredCapacity, 24F);
                AppendFeatureRow(row, fixedCapacity, 24F);
                preferredCapacity.CheckedChanged += (sender, args) => {
                    if (preferredCapacity.Checked)
                        featureBoxes[DispatchConsoleFeature].Checked = true;
                    UpdateButtons();
                };
                fixedCapacity.CheckedChanged += (sender, args) => UpdateButtons();
            }

            capacityPicker = new ComboBox {
                AccessibleName = "固定供给货车容量", AccessibleDescription = "选择全局固定容量。",
                DropDownStyle = ComboBoxStyle.DropDownList, Width = 254, Margin = new Padding(hasPreferredMode ? 40 : 21, 1, 0, 0)
            };
            capacityPicker.Items.AddRange(fixedCapacityModes.Select(DescribeCapacityMode).ToArray());
            capacityPicker.SelectedIndex = 0;
            capacityPicker.SelectedIndexChanged += (sender, args) => UpdateButtons();
            AppendFeatureRow(row, capacityPicker, 39F);
            AppendFeatureRow(layout, row, hasPreferredMode ? 111F : 63F);
        }

        private static string DescribeCapacityMode(string id)
        {
            switch (id)
            {
                case PatchCatalog.TruckCapacity12: return "固定容量（12 格）";
                case PatchCatalog.TruckCapacity16: return "固定容量（16 格）";
                default: return "游戏默认（原版 8 格）";
            }
        }

        private static void AppendFeatureRow(TableLayoutPanel layout, Control row, float height = 68F)
        {
            int index = layout.RowStyles.Count;
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, height));
            layout.Controls.Add(row, 0, index);
        }

        protected override void OnFormClosing(FormClosingEventArgs args)
        {
            if (busy && args.CloseReason == CloseReason.UserClosing)
            {
                args.Cancel = true;
                return;
            }
            base.OnFormClosing(args);
        }

        private async Task BrowseAsync()
        {
            if (busy)
                return;
            using (var picker = new FolderBrowserDialog {
                Description = ManagerLanguage.Translate("请选择包含 Prison Architect64.exe 的游戏目录"),
                ShowNewFolderButton = false
            })
            {
                if (Directory.Exists(directoryBox.Text))
                    picker.SelectedPath = directoryBox.Text;
                if (picker.ShowDialog(this) != DialogResult.OK)
                    return;
                await SelectDirectoryAsync(picker.SelectedPath, true);
            }
        }

        private async Task SelectDirectoryAsync(string path, bool showError)
        {
            if (busy)
                return;
            try
            {
                var directory = SteamGame.NormalizeDirectory(path);
                if (String.IsNullOrEmpty(directory))
                    throw new ArgumentException("请选择包含 Prison Architect64.exe 的游戏目录，或直接选择该游戏程序。");
                directoryBox.Text = directory;
                await RefreshAsync(showError);
            }
            catch (Exception exception)
            {
                ShowProblem(exception, showError);
            }
        }

        private void CheckDrop(object sender, DragEventArgs args)
        {
            args.Effect = !busy && ReadDroppedPath(args) != null ? DragDropEffects.Copy : DragDropEffects.None;
        }

        private async Task DropDirectoryAsync(DragEventArgs args)
        {
            var path = ReadDroppedPath(args);
            if (path != null)
                await SelectDirectoryAsync(path, true);
        }

        private static string ReadDroppedPath(DragEventArgs args)
        {
            if (args.Data == null || !args.Data.GetDataPresent(DataFormats.FileDrop))
                return null;
            var paths = args.Data.GetData(DataFormats.FileDrop) as string[];
            return paths != null && paths.Length == 1 ? paths[0] : null;
        }

        private async Task AutoDetectAsync()
        {
            if (busy)
                return;
            SetBusy(true);
            SetStatus("正在检测 Steam 游戏库…", false);
            try
            {
                var result = await Task.Run(() => InspectSteamLibraries());
                SetInstalled(result.Status);
                if (result.Directory != null)
                    directoryBox.Text = result.Directory;
                if (result.Status != null)
                    DescribeInstalled();
                else if (result.Directory != null)
                    SetStatus("找到游戏目录，无法验证版本。请复查当前目录或手动选择目录。", true);
                else
                    SetStatus("Steam 游戏库中未找到游戏。请选择安装目录，或将游戏程序拖入窗口。", true);
            }
            catch (Exception exception)
            {
                SetInstalled(null);
                SetStatus("Steam 游戏库检测失败。请选择游戏目录。 {0}", true, exception.Message);
            }
            finally
            {
                SetBusy(false);
            }
        }

        private LibraryDetection InspectSteamLibraries()
        {
            string firstCandidate = null;
            foreach (var candidate in SteamGame.FindDirectories())
            {
                if (firstCandidate == null)
                    firstCandidate = candidate;
                try
                {
                    return new LibraryDetection(candidate, installer.Inspect(candidate));
                }
                catch (Exception)
                {
                    // Leave the first unrecognized installation available to inspect after scanning.
                }
            }
            return new LibraryDetection(firstCandidate, null);
        }

        private sealed class LibraryDetection
        {
            public readonly string Directory;
            public readonly InstallStatus Status;

            public LibraryDetection(string directory, InstallStatus status)
            {
                Directory = directory;
                Status = status;
            }
        }

        private async Task RefreshAsync(bool showError)
        {
            if (busy)
                return;
            var path = directoryBox.Text;
            if (String.IsNullOrWhiteSpace(path))
            {
                SetStatus("请选择 Steam 中的游戏安装目录。", false);
                return;
            }
            SetBusy(true);
            SetStatus("正在检测游戏版本…", false);
            try
            {
                SetInstalled(await Task.Run(() => installer.Inspect(path)));
                DescribeInstalled();
            }
            catch (Exception exception)
            {
                SetInstalled(null);
                ShowProblem(exception, showError);
            }
            finally
            {
                SetBusy(false);
            }
        }

        private async Task ApplyAsync(bool restore)
        {
            if (busy || currentStatus == null)
                return;
            var path = directoryBox.Text;
            var selection = restore ? new string[0] : ReadSelection().ToArray();
            int pickerKey = SelectedMapObjectPickerKey;
            SetBusy(true);
            SetStatus(restore ? "正在恢复原文件…" : "正在应用所选补丁…", false);
            try
            {
                Exception failure = null;
                try
                {
                    var updated = await Task.Run(() => {
                        installer.ApplyWithPickerKey(path, selection, pickerKey);
                        return installer.Inspect(path);
                    });
                    SetInstalled(updated);
                    if (updated.RequiresUpgrade || !SelectionMatches(updated, selection, pickerKey))
                        throw new IOException("实际启用的补丁与所选项目不一致。请复查当前目录。");
                    SetStatus(selection.Length == 0 ? "已恢复应用前的版本。" : "已应用，可从 Steam 正常启动。", false);
                }
                catch (Exception exception)
                {
                    failure = exception;
                }
                if (failure != null)
                {
                    try
                    {
                        SetInstalled(await Task.Run(() => installer.Inspect(path)));
                    }
                    catch (Exception)
                    {
                        SetInstalled(null);
                    }
                    ShowProblem(failure, true);
                }
            }
            finally
            {
                SetBusy(false);
            }
        }

        private IEnumerable<string> ReadSelection()
        {
            bool useDispatch = DispatchOptionsEnabled;
            foreach (var item in featureBoxes.Where(item =>
                item.Value.Checked && (!IsDispatchFeature(item.Key) || useDispatch)))
                yield return item.Key;
            if (useDispatch && SelectedCapacityMode != null)
                yield return SelectedCapacityMode;
        }

        private string SelectedCapacityMode {
            get {
                if (PreferredCapacitySelected)
                    return PatchCatalog.LongTruckFleet;
                return capacityPicker == null || capacityPicker.SelectedIndex < 0
                    ? null : fixedCapacityModes[capacityPicker.SelectedIndex];
            }
        }

        private int SelectedMapObjectPickerKey {
            get {
                return mapObjectPickerShortcut == null || mapObjectPickerShortcut.SelectedIndex < 0
                    ? PatchCatalog.DefaultMapObjectPickerKey
                    : PatchCatalog.MapObjectPickerKeys[mapObjectPickerShortcut.SelectedIndex];
            }
        }

        private static bool SelectionMatches(InstallStatus status, IEnumerable<string> selection, int pickerKey)
        {
            return status.Enabled.SetEquals(selection) && (!status.Enabled.Contains(PatchCatalog.MapObjectPicker) ||
                status.MapObjectPickerKey == pickerKey);
        }

        private bool PreferredCapacitySelected { get { return preferredCapacity != null && preferredCapacity.Checked; } }
        private bool DispatchOptionsEnabled { get { return dispatchToggle == null || dispatchToggle.Checked; } }

        private void SelectAllCompatibleFeatures()
        {
            if (busy || currentStatus == null)
                return;
            if (dispatchToggle != null)
                dispatchToggle.Checked = true;
            foreach (var check in featureBoxes.Values.Where(item => item.Enabled))
                check.Checked = true;
        }

        private void SetInstalled(InstallStatus status)
        {
            currentStatus = status;
            bool firstApplication = status != null && !status.HasBackup && status.Enabled.Count == 0;
            bool dispatchConfigured = status != null && status.Enabled.Any(IsDispatchFeature);
            int fixedMode = status == null ? -1 :
                Array.FindIndex(fixedCapacityModes, id => id != null && status.Enabled.Contains(id));
            bool keepUnselectedCapacity = dispatchConfigured && !status.Enabled.Any(PatchCatalog.IsTruckModeChoice);
            bool preferCapacity = preferredCapacity != null && fixedMode < 0 && !keepUnselectedCapacity;
            foreach (var item in featureBoxes)
                item.Value.Checked = status != null &&
                    (status.Enabled.Contains(item.Key) ||
                     (item.Key == DispatchConsoleFeature && (firstApplication || preferCapacity)) ||
                     (item.Key == BalancedPickupFeature && !dispatchConfigured));
            if (mapObjectPickerShortcut != null)
            {
                var installedKey = status == null ? PatchCatalog.DefaultMapObjectPickerKey : status.MapObjectPickerKey;
                mapObjectPickerShortcut.SelectedIndex = Array.IndexOf(PatchCatalog.MapObjectPickerKeys, installedKey);
            }
            if (capacityPicker != null)
                capacityPicker.SelectedIndex = keepUnselectedCapacity ? -1 : Math.Max(fixedMode, 0);
            if (preferredCapacity != null)
            {
                if (preferCapacity)
                    preferredCapacity.Checked = true;
                else
                    fixedCapacity.Checked = true;
            }
            if (dispatchToggle != null)
                dispatchToggle.Checked = dispatchConfigured || firstApplication &&
                    (featureBoxes.ContainsKey(DispatchConsoleFeature) || featureBoxes.ContainsKey(BalancedPickupFeature));
            UpdateStaffMoraleHelp();
            UpdateButtons();
        }

        private void UpdateStaffMoraleHelp()
        {
            if (staffMoraleHelp == null)
                return;
            bool blocked = currentStatus != null && currentStatus.HasTyrStaffMorale;
            staffMoraleHelp.Text = ManagerLanguage.Translate(blocked ? PatchCatalog.StaffMoraleConflict : StaffMoraleDescription);
            staffMoraleHelp.ForeColor = blocked ? Error : Muted;
            featureBoxes[PatchCatalog.StaffMoraleFeature].AccessibleDescription = staffMoraleHelp.Text;
        }

        private void DescribeInstalled()
        {
            if (currentStatus != null)
            {
                var count = currentStatus.Enabled.Count;
                if (currentStatus.RequiresUpgrade)
                    SetStatus("检测到旧版补丁。点击「应用」保留现有勾选并移除已停用的项目。", false);
                else if (count == 0)
                    SetStatus("{0}，未启用补丁", false, currentStatus.BaseName);
                else
                    SetStatus("{0}，已启用 {1} 项补丁", false, currentStatus.BaseName, count);
            }
        }

        private void SetBusy(bool value)
        {
            busy = value;
            UseWaitCursor = value;
            UpdateButtons();
        }

        private void UpdateButtons()
        {
            var ready = !busy && currentStatus != null;
            bool useDispatch = DispatchOptionsEnabled;
            if (dispatchToggle != null)
                dispatchToggle.Enabled = ready;
            foreach (var item in featureBoxes)
                item.Value.Enabled = ready &&
                    (item.Key != PatchCatalog.StaffMoraleFeature || !currentStatus.HasTyrStaffMorale) &&
                    (!IsDispatchFeature(item.Key) || useDispatch);
            if (preferredCapacity != null)
            {
                preferredCapacity.Enabled = ready && useDispatch;
                fixedCapacity.Enabled = ready && useDispatch;
            }
            if (capacityPicker != null)
                capacityPicker.Enabled = ready && useDispatch && !PreferredCapacitySelected;
            if (mapObjectPickerShortcut != null)
                mapObjectPickerShortcut.Enabled = ready && featureBoxes[PatchCatalog.MapObjectPicker].Checked;
            selectAllButton.Enabled = ready;
            detectButton.Enabled = !busy;
            browseButton.Enabled = !busy;
            refreshLink.Enabled = !busy && !String.IsNullOrWhiteSpace(directoryBox.Text);
            applyButton.Enabled = ready && (currentStatus.RequiresUpgrade ||
                !SelectionMatches(currentStatus, ReadSelection(), SelectedMapObjectPickerKey));
            applyButton.BackColor = applyButton.Enabled ? Accent : DisabledAccent;
            applyButton.FlatAppearance.BorderColor = applyButton.BackColor;
            restoreButton.Enabled = ready && currentStatus.HasBackup &&
                (currentStatus.Enabled.Count > 0 || currentStatus.RequiresUpgrade);
        }

        private void SetStatus(string message, bool error, params object[] arguments)
        {
            statusMessage = message;
            statusArguments = arguments;
            statusLabel.ForeColor = error ? Error : Muted;
            UpdateStatusText();
        }

        private void UpdateStatusText()
        {
            var translatedArguments = statusArguments.Select(value => value is string
                ? ManagerLanguage.Translate((string)value) : value).ToArray();
            statusLabel.Text = ManagerLanguage.Translate(statusMessage, translatedArguments);
            statusLabel.AccessibleDescription = statusLabel.Text;
        }

        private void ShowProblem(Exception exception, bool showDialog)
        {
            SetStatus(exception.Message, true);
            if (showDialog)
                MessageBox.Show(this, statusLabel.Text, ManagerLanguage.Translate("补丁操作未完成"),
                    MessageBoxButtons.OK, MessageBoxIcon.Warning);
        }
    }
}
