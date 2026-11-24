生活与质量更新 · Prison Quality of Life 1.6.10
适用于《监狱建筑师》Windows Steam x64 构建 10630057。支持原版和已识别的 Tyr 1.5.0 配置。订阅后通过 Prison QoL.exe 选择并应用补丁，再从 Steam 正常启动。
本版增加右键取消建造选中、建造栏拼音搜索，以及可定位和高亮墙壁、地板、物件的地图取样。管理器按「体验优化」和「补丁修复」分组，并提供「全选」。

订阅、安装与升级
1. 点击「订阅」，等 Steam 下载完成，再启动一次游戏。在「附加功能 → 模组」确认 Prison Quality of Life 出现。保存并完全退出游戏。
2. 按 Win + E 打开文件资源管理器，把下列目录粘贴到地址栏并回车，然后双击 Prison QoL.exe。
%LOCALAPPDATA%\Introversion\Prison Architect\mods\-451698453\data\prisonqol
3. 找不到目录时，在 %LOCALAPPDATA%\Introversion\Prison Architect\mods 搜索 Prison QoL.exe。条目根目录的 manifest.txt 中名称为 Prison Quality of Life。程序旁的 README - Prison QoL.txt 是双语指南。
4. 核对自动识别的安装路径和版本。点「自动检测」可重新搜索，或点「选择目录…」指定含 Prison Architect64.exe 的文件夹。在 Steam 库右键《监狱建筑师》，点「管理 → 浏览本地文件」即可找到。
5. 在「体验优化」和「补丁修复」中勾选所需功能。点「全选」可勾选两组的兼容功能并开启出货调度，已有的容量方案和取样快捷键继续沿用。核对后点击「应用」。看到「已应用，可从 Steam 正常启动」后，从 Steam 进入游戏。
6. 首次使用时默认勾选出货调度、调度台和均衡取货，容量采用首选方案。已有出货调度配置时，均衡取货沿用已应用的选择。已恢复原文件或只应用过其他功能时，均衡取货显示为预选项，开启「出货调度」后才能应用。
7. 升级时请保留游戏目录中的 Prison QoL Backup。用订阅目录里的新版程序打开游戏目录，看到旧版提示后核对已读取的选项，并再次点「应用」。首次应用时，管理器会把应用前的原版或 Tyr 游戏文件存入该目录。需要恢复时，先退出游戏，再点击「恢复原文件」。

建造交互
• 地图物件取样。勾选并应用后，将光标指向已放置的物件、门、墙壁、围栏或地板，按鼠标中键，或使用管理器中自选的快捷键。游戏打开对应的物品、墙壁和门、地板或公用设施栏，滚到所选条目并高亮。选项会沿用原版的内容和研究限制。物件与地板重叠时优先取样物件。
• 取样后的菜单。如果目标被当前筛选隐藏，会先调整相关的物件类型或内容包筛选。目标仍被搜索词隐藏时才清空搜索词。自选快捷键在搜索框内可照常输入。
• 拼音搜索。启用并应用后，在物品、房间、墙壁和门、地板或快速建造的原版搜索框输入中文名、无声调全拼或首字母。例如 guidian 和 gd 都可查找「跪垫」，jiaoshi 和 js 可查找「教室」。支持大小写，ü 可写成 v。首字母可能匹配多个项目，游戏原有分类和内容限制照常生效。
• 右键取消选中物品。启用并应用后，从建造栏或用地图取样选中物品，然后在地图上右键单击。游戏先按原版规则处理该次右键的工单取消，再清除建造预览及高亮，保留建造栏、标签页和搜索词。墙壁、门、地板和普通公用设施也可这样取消。按住右键拖动、搬动物件和设施连线沿用原版操作。

使用出货调度台、自动派车和均衡取货
1. 从独立的旧物流模组迁移时，先在「保存监狱」另存一份备份。若使用旧模组的调度台，关闭自动调度和均衡取货，停止手动派车，等额外车驶离，再拆除旧调度台并保存迁移用存档。在「附加功能 → 模组」停用旧 12 格、16 格和 Outbound Logistics - Dispatch，完全退出。应用新版后直接从 Steam 启动，停用旧 Start Balanced Logistics.cmd。首次重载若提示缺少模组，请核对是否为刚停用的旧模组。确认存档使用新版功能后，可在 Steam 的对应旧条目退订。
2. 在管理器勾选「出货调度」及其下的「出货调度台」。想轮流清运垃圾和出口货物时，同时勾选「均衡取货」。点击「应用」，从 Steam 启动并载入监狱。
3. 在「物件」栏搜索「出货调度台」，也可在送货区、垃圾区或出货区的推荐物件中找到它。造价 200，占一格，可建在室内、室外或区域外。建成后选中设备。
4. 点击「召唤一辆货车」或「召唤两辆货车」。队列最多等待 5 辆，每次加派至少间隔 5 个游戏分钟。「货车上限」可设为 1–5，已进场的供给货车也会计入。道路入口被占用时，请等现有车辆通过。
5. 反复点击「自动调度」在关闭和每 15、30、60 游戏分钟检查之间切换。点击「积压门槛」选择 4、8 或 16 堆（默认 8 堆）。达到门槛时每次尝试加派一辆。保持停靠点和垃圾区、出货区可用。
6. 看菜单底部的「垃圾积压」「出货积压」和「最近调度」。积压统计覆盖停靠点服务的区域。加载后暂时显示「待统计」时，让游戏时间推进。「最近调度」可看到请求入队、发车、等待间隔、入口被占用、达到上限或未达门槛等结果。
7. 在设备菜单启用「均衡取货」。两类都有积压时，加派车交替专收垃圾或出口货物。只有一类积压时，车辆按通常规则取货。
8. 同一座监狱的各台共用设置。用「保存监狱」保存自动调度、均衡取货、货车上限、积压门槛和首选方案的车长，再次载入时会读回。排队等待发出的手动请求在重新载入时清空，需要时重新下单。
9. 升级后可保留旧档内已建好的原生调度台。没有调度记录的监狱从原默认设置开始，选定设置后保存一次即可。

选择 8、12 或 16 格货车
• 首选方案在管理器启用后，选中已建成的调度台，点击「车长」在标准 8 格、中型 12 格、加长 16 格间循环。新加派的车辆使用所选车型。车长随监狱保存，重载后仍用于新派车辆。正常送货车保持原版 8 格。
• 备选方案在管理器设置。退出游戏，在「出货调度 → 供给货车容量」选「备选方案」，再选「游戏默认（原版 8 格）」「固定容量（12 格）」或「固定容量（16 格）」。固定容量也用于正常送货车。车身沿用原版，车上画面只显示前 8 个货位，可用车辆提示核对货量。
• 切换方案前，关闭自动调度，停止添加请求，等队列处理完并让现有车辆离场，再保存退出。要在同一存档里关闭调度台补丁，请先拆除全部调度台并存档。

逻辑桥信号传播优化
• 默认关闭。频繁向大片连线传播时适合常驻，保留原版信号值与传播顺序。低负载收益尚无实测，建议保持关闭。
• 同一大型电路存档的两轮原版 10 倍速对照中，实际模拟推进提高 27.45%–34.81%，FPS 提高 38.32%–46.93%。p95 帧时间缩短 7.52–9.15 ms，p99 缩短 8.74–9.53 ms。

施工、课程与恢复
• 「砍树后不留树桩」保留工人砍伐和木材产出，砍完时不再生成新树桩。
• 「自动替换已安装的旧门」支持单格和双格门。选另一种门后单击旧门占用格，或选墙壁工具点按或拖过旧门。旧门在新门或墙体完工后打包。要封住整个双格门洞，用墙工具拖过两格。新门的相邻占用格仍须可施工。
• 开启「建门和墙前自动清理树木」后，可将门或墙安排在有树木或树桩的格子，工人先清理再建造。关闭施工补丁前先完成或取消相关任务。
• 「修复改造计划进度保存」在刷新名单时采用课程额定人数，适用于三振出局计划（Second Chances）和鲜花疗法（Going Green）。应用后在游戏中照常开课，可继续积累存档中已有的进度。曾手动覆盖 data/reform_programs_dlc.txt 的玩家可备份并移出覆盖文件以使用原版器材要求。
• 「员工死亡士气惩罚逐渐消退」每过 1,440 游戏分钟减轻 1 点，沿用原版死亡统计和无事故奖励。识别到 Tyr 的对应选项时本项会变灰。若要改用本补丁，先退出游戏并恢复应用前的 Tyr 文件，在 Tyr 关闭 Staff death morale penalty fades，再回到本管理器应用。
• 需要停用所有补丁时，完全退出游戏后打开管理器点「恢复原文件」。完成后可退订。每次 Steam 校验或更新游戏文件后，都可以重新打开管理器核对状态。

English · Prison Quality of Life 1.6.10
For Windows Steam x64 build 10630057, stock and supported Tyr 1.5.0 profiles. Apply your choices in Prison QoL.exe, then launch through Steam.
This release adds right-click build deselection, Pinyin in build menu search, and a map picker that scrolls to and highlights objects, walls, and floors. The manager groups its options under Quality of life and Bug fixes and adds Select all.

Subscribe, install or upgrade
1. Subscribe, wait for Steam to download the item, then start the game once. Find Prison Quality of Life under Extras → Mods. Save and exit.
2. Press Win + E, paste this folder into File Explorer's address bar, and open Prison QoL.exe.
%LOCALAPPDATA%\Introversion\Prison Architect\mods\-451698453\data\prisonqol
3. If missing, search %LOCALAPPDATA%\Introversion\Prison Architect\mods for Prison QoL.exe. The root manifest.txt will say Prison Quality of Life. Read README - Prison QoL.txt next to the manager for the full guide.
4. Verify the folder and version. Click 自动检测 (Auto-detect) to scan again or 选择目录… (Choose folder) to select the folder containing Prison Architect64.exe. In Steam Library, right-click Prison Architect and choose Manage → Browse local files to locate it.
5. Choose options under Quality of life and Bug fixes. Select all checks the compatible options in both groups and enables Outbound Dispatch while keeping the capacity mode and picker shortcut. Review your choices and click 应用 (Apply). Launch through Steam after success.
6. On first use, Outbound Dispatch, Outbound Dispatch Console and Balanced pickups are checked, and the capacity mode is Preferred. Existing dispatch settings keep the previously applied Balanced Pickup choice. After restoring the game executable or applying only other features, Balanced pickups remains preselected within the disabled group. Turn on Outbound Dispatch to apply it.
7. Keep Prison QoL Backup in the game folder when upgrading. Open the newer manager from the updated subscription folder, review the imported options, and click Apply. On first application the manager saves the original or Tyr executable to that folder. To restore it, close the game and choose 恢复原文件 (Restore original).

Building controls
• Map object picker. Point to a placed object, door, wall, fence, or floor, then press Middle Mouse or the shortcut you chose in the manager. The game opens Objects, Walls & Doors, Flooring or Utilities, scrolls the entry into view and highlights it. The usual research and content rules apply. A buildable object takes precedence when it overlaps a floor.
• Menu filters after picking. The picker adjusts any object-type or content-pack filter that hides the selected item. It clears the search only when the item remains hidden. Custom shortcuts still type normally in a search field.
• Pinyin search. After applying the option, use the existing search box in Objects, Rooms, Walls & Doors, Flooring or Quick Builds. Search by displayed name, toneless Pinyin, or initials. Try guidian or gd for 跪垫 (Prayer Mat), or jiaoshi or js for 教室 (Classroom). Matching ignores case, and v can stand for ü. A set of initials can match more than one entry. The game's category and content rules still apply.
• Right-click to deselect build item. Apply the option, select a build item, or pick it from the map, then right-click the map. Any stock job cancellation triggered by that click runs first. The preview and highlight clear while the build menu, tab and search stay open. This covers walls, doors, flooring and ordinary utilities. Right-button dragging, moving objects, and utility connection tools retain their stock controls.

Use the console, automatic dispatch and balanced pickup
1. When moving from the standalone legacy mods, use Save Prison to make a backup. For a console from the old mod, turn off Auto and Balanced Pickup, stop manual requests, wait for extra trucks to leave, then dismantle old consoles and save the copy you will migrate. In Extras > Mods, disable the legacy 12-slot, 16-slot and Outbound Logistics - Dispatch items, then exit completely. After applying this patch, launch through Steam and retire Start Balanced Logistics.cmd. If a missing-mod warning appears, check that it names the old mods you disabled. Once the migrated save works, you can unsubscribe from the legacy items.
2. Check 出货调度 (Outbound Dispatch) and 出货调度台 (console), plus 均衡取货 (Balanced Pickup) if desired. Apply and launch through Steam.
3. Find Outbound Dispatch Console in Objects or in Deliveries, Garbage and Exports recommendations. It costs 200 and fits on one buildable tile indoors or outdoors, inside or outside the zones. Select it when built.
4. Click Request 1 truck or Request 2 trucks. Up to five requests can wait, with at least five in-game minutes between extra trucks. Set Limit from one to five trucks. Existing supply trucks count toward the limit. Dispatch waits if the road entrance is occupied.
5. Click Auto to cycle Off, 15, 30 or 60 game minutes. Use Backlog to set 4, 8 or 16 stacks (default 8). Each check can send one extra truck when the threshold is met. Keep the road stops and the Garbage and Exports zones accessible.
6. Waste and Exports show counts for zones linked to road stops. Let game time advance while they read “counting.” Last shows the latest attempt or request.
7. Turn on Balanced Pickup in the console. Extra trucks alternate garbage-only and exports-only pickups when both have a backlog. With one category backed up, usual rules apply.
8. Consoles in the same prison share settings. Use Save Prison to store Auto, Balanced Pickup, Limit, Backlog and the Preferred truck length. Reopening the save restores them. Pending manual requests clear on reload. Request more trucks when needed.
9. Keep the built-in console when updating an older prison. An older save without stored settings starts with the original defaults. Set the options and save once to keep them in that prison file.

Choose 8, 12 or 16 slots
• Preferred (首选方案) adds the in-game Truck length control. Choose 8, 12 or 16 slots for newly dispatched trucks. The saved choice applies to new dispatches after reload. Ordinary supply deliveries keep the stock 8 slots.
• Fallback (备选方案) sets a fixed capacity of 8, 12 or 16 in the manager for normal supply trucks and extra dispatches. Trucks keep the stock body. The first eight slots are drawn, and the truck tooltip shows its complete load.
• To change modes, turn off Auto, stop requesting trucks and wait for queued or active trucks to finish and leave. Save and exit before changing modes. Before disabling the console patch for an existing prison, dismantle its consoles and save.

Logic bridge signal propagation optimization
• Off by default. Useful for regular play with large circuits that broadcast frequently. Preserves the original signal values and propagation order. Gains at low load are unmeasured, so leave it off in light circuits.
• In two stock 10× runs on the same large-circuit save, simulation advanced 27.45%–34.81% faster and FPS rose 38.32%–46.93%. p95 frame time fell by 7.52–9.15 ms and p99 by 8.74–9.53 ms.

Construction, programs and restore
• No new stumps keeps ordinary tree removal and log production. Workers leave no new stump after felling a tree.
• Replace installed doors supports one- and two-tile doors. Select a different door and click a tile occupied by the old door, or click or drag with the wall tool. The old door is boxed after its replacement is built. Drag a wall across both tiles to close a two-tile doorway. Other tiles occupied by the new door must still be buildable.
• Clear trees before building lets workers clear trees and stumps in the footprint before building a door or wall. Finish or cancel affected jobs before disabling construction patches.
• Retain reform program progress uses the normal roster capacity for Three Strikes Program (Second Chances) and Flower Therapy (Going Green). Schedule classes as usual. Students can build on progress still in the save. If you manually installed a loose data/reform_programs_dlc.txt override, back up and move that override out of the game folder to return to stock equipment requirements.
• Fading staff death morale penalty removes one point per 1,440 game minutes and preserves stock death statistics and incident-free rewards. To switch from Tyr's equivalent, close the game, restore the previous Tyr executable, turn off Staff death morale penalty fades in Tyr, then apply this option here.
• To remove all patches, close the game and click 恢复原文件 (Restore original file) before unsubscribing. Recheck the manager after Steam validates or updates the game files.

Steam 创意工坊 / Steam Workshop
https://steamcommunity.com/sharedfiles/filedetails/?id=3843268843

项目源码 / Project source
https://github.com/Zack176CN/prison-quality-of-life

兼容性签名来源 / Compatibility signature source
Tyr, Prison Architect Community Patch v1.5.0.
https://github.com/Tyr077/tyrs-prison-architect-community-patch/tree/v1.5.0

MIT License

Copyright (c) 2026 Tyr

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

拼音数据 / Pinyin data
Unicode 17.0.0 Unihan
https://www.unicode.org/Public/17.0.0/ucd/Unihan.zip

UNICODE LICENSE V3

COPYRIGHT AND PERMISSION NOTICE

Copyright © 1991-2026 Unicode, Inc.

NOTICE TO USER: Carefully read the following legal agreement. BY
DOWNLOADING, INSTALLING, COPYING OR OTHERWISE USING DATA FILES, AND/OR
SOFTWARE, YOU UNEQUIVOCALLY ACCEPT, AND AGREE TO BE BOUND BY, ALL OF THE
TERMS AND CONDITIONS OF THIS AGREEMENT. IF YOU DO NOT AGREE, DO NOT
DOWNLOAD, INSTALL, COPY, DISTRIBUTE OR USE THE DATA FILES OR SOFTWARE.

Permission is hereby granted, free of charge, to any person obtaining a
copy of data files and any associated documentation (the "Data Files") or
software and any associated documentation (the "Software") to deal in the
Data Files or Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, and/or sell
copies of the Data Files or Software, and to permit persons to whom the
Data Files or Software are furnished to do so, provided that either (a)
this copyright and permission notice appear with all copies of the Data
Files or Software, or (b) this copyright and permission notice appear in
associated Documentation.

THE DATA FILES AND SOFTWARE ARE PROVIDED "AS IS", WITHOUT WARRANTY OF ANY
KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT OF
THIRD PARTY RIGHTS.

IN NO EVENT SHALL THE COPYRIGHT HOLDER OR HOLDERS INCLUDED IN THIS NOTICE
BE LIABLE FOR ANY CLAIM, OR ANY SPECIAL INDIRECT OR CONSEQUENTIAL DAMAGES,
OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THE DATA
FILES OR SOFTWARE.

Except as contained in this notice, the name of a copyright holder shall
not be used in advertising or otherwise to promote the sale, use or other
dealings in these Data Files or Software without prior written
authorization of the copyright holder.
