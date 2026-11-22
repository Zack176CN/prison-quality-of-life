# Prison Quality of Life 1.6.3

[简体中文](README.md)

Prison Quality of Life is a Windows patch manager for Prison Architect. Pick the improvements you want in `Prison QoL.exe`, apply them, and start the game normally through Steam. The options cover construction, reform programs, staff morale, and outbound logistics.

Supports **Windows Steam x64 build 10630057**. The manager recognizes the stock game, Tyr 1.5.0 with its default fixes, and the same Tyr setup with its staff morale tweak enabled. It checks the game executable by SHA-256 before allowing changes.

## Install and apply

1. Subscribe on Steam Workshop. Start the game once and confirm **Prison Quality of Life** is listed under **Extras → Mods**. Save and exit the game completely. If you already have the patch manager, start at step 3. [Steam Workshop listing](https://steamcommunity.com/sharedfiles/filedetails/?id=3843268843)
2. Press **Win + E**, paste the folder below into File Explorer's address bar, and open **Prison QoL.exe**. If that folder is missing, search `%LOCALAPPDATA%\Introversion\Prison Architect\mods` for `Prison QoL.exe`. The item's root `manifest.txt` shows its name as `Prison Quality of Life`. The bilingual `README - Prison QoL.txt` sits beside the manager.

   ```text
   %LOCALAPPDATA%\Introversion\Prison Architect\mods\-451698453\data\prisonqol
   ```

3. Verify the detected game folder and version. Use **自动检测** (Auto-detect) to scan your Steam libraries again. To select an installation yourself, right-click **Prison Architect** in your Steam Library and choose **Manage → Browse local files**. In the manager, click **选择目录…** (Choose folder) and select the folder containing `Prison Architect64.exe`. You can also drag that folder or executable onto the window.
4. Check your patches, click **应用** (Apply) and wait for the success message. Close the manager and start the game from Steam. The first-use selection includes **Outbound Dispatch**, **Outbound Dispatch Console**, and **Preferred** truck capacity. The manager reads previously applied choices when you open it again.
5. When upgrading from 1.0.0–1.6.2, keep `Prison QoL Backup` in the game install folder. Open the new manager, review the detected choices, and apply.

## Construction and management patches

With the game closed, check the features you want and apply them. Use the usual in-game tools after restarting.

| Option | What to do and what changes |
| --- | --- |
| **No new stumps** | Order workers to cut down trees as usual. You still get timber, and the cleared tile stays free of new stumps. Remove existing stumps with the usual tools. |
| **Replace installed doors** | Select a different one- or two-tile door and click a tile occupied by the installed door. With the wall tool, click one tile or drag across the doorway. After the replacement is built, workers can haul away the boxed door. A two-tile door yields one boxed item. |
| **Clear trees before building** | Place a one- or two-tile door on a tree or stump, or drag a wall through the area. Workers clear the construction footprint first. This can be used together with No new stumps. |
| **Retain reform program progress** | Run **Three Strikes Program** (Second Chances DLC) or **Flower Therapy** (Going Green DLC) as usual. The roster uses its configured capacity when it refreshes, so students can build on the progress recorded in the save. |
| **Fading staff death morale penalty** | Once there is an active penalty, it falls by one point every 1,440 in-game minutes. Death statistics, the incident-free timer, and incident-free rewards use the game's usual rules. Loading a world resets the decay state. |

To close a two-tile doorway, drag the wall over both tiles. A single wall tile or a one-tile door leaves one tile open. When installing a new two-tile door, the adjacent tile also has to be buildable. For wider gates such as road gates, follow the game's normal construction steps.

The program fix picks up progress still recorded in a save. Cleared progress and completed course results follow what is stored in that save. If you manually installed a loose `data/reform_programs_dlc.txt` override, back up that file and move it out of `data` with the game closed to use the stock course definitions from `main.dat`.

## Outbound dispatch, balanced pickup, and truck capacity

### Build a console and send trucks

1. Save and close the game. In the manager, check **出货调度** (Outbound Dispatch) and **出货调度台** (Outbound Dispatch Console). Also check **均衡取货** (Balanced Pickup) if you want extra trucks to alternate between garbage and exports. Apply the changes and launch through Steam.
2. Search **Objects** for **Outbound Dispatch Console**, or find it in the recommendations for **Deliveries**, **Garbage**, or **Exports**. It costs **200** and fits on one buildable tile indoors or outdoors. You can place it outside those zones.
3. Select the completed console and click **Request 1 truck** or **Request 2 trucks**. Up to **five** trucks can wait in the queue, and additional trucks are spaced at least **five in-game minutes** apart. **Limit** runs from **one to five** and includes supply trucks already on site. A blocked road entrance delays dispatch.
4. For automatic dispatch, cycle **Auto** through Off, 15, 30, or 60 in-game minutes. Set **Backlog** to **4, 8, or 16 stacks**. It starts at 8. Each check can request one truck when the backlog reaches the threshold.
5. **Waste** and **Exports** count stacks in the zones served by the road stops. Let game time advance if the console is still counting. **Last** reports the latest request or attempt, including a full vehicle limit, a blocked entrance, and a backlog below the threshold.
6. With the Balanced Pickup patch applied, switch **Balanced Pickup** on at the console. When both categories are backed up, extra trucks alternate between garbage-only and export-only trips. When only one is backed up, they follow the usual pickup rules. For example, when both zones are full, request two trucks and check what each one takes.

All consoles in a prison share the same queue and settings. Reloading the world resets controls such as automatic dispatch, balanced pickup, and the next truck's length.

### Choose 8, 12, or 16 cargo slots

Pick one mode in the manager under **Outbound Dispatch → Supply Truck Capacity**.

| Mode | Where to set it | Which trucks it affects |
| --- | --- | --- |
| **Preferred** (首选方案) | Apply with the console enabled. In the game, use **Truck length** to cycle between standard 8, medium 12, and long 16 slots. Choose the length before you request a truck. | Future manual and automatic dispatches from the console. Regular deliveries keep 8 slots. After a reload, the next dispatched truck starts at 8 slots. |
| **Fallback** (备选方案) | Close the game. Select the game default (8), fixed 12, or fixed 16 slots in the manager, then apply. | All supply trucks, including regular deliveries. They use the stock body, with the first eight cargo positions drawn. Hover over the truck to see its full load. |

The 12 and 16 figures refer to cargo slots. In Preferred mode the bed has two columns, and the standard, medium, and long trucks occupy 8, 10, and 12 road tiles respectively. To keep the same capacity on every truck as in one of the old mods, choose the matching fixed capacity. To lengthen only the trucks requested by the console, choose Preferred.

Before switching modes, turn off automatic dispatch and stop making new requests. Let the queue clear and the trucks leave the map, then save and exit. To remove the console patch from a prison you want to keep playing, dismantle its consoles first and save.

## Move an existing prison from the old logistics mods

1. Use **Save Prison** to make a backup copy. If you have an old dispatch console, turn off automatic dispatch and balanced pickup, stop manual requests, and let the extra trucks leave.
2. Dismantle the old consoles and save the copy you want to migrate. Under **Extras → Mods**, disable the legacy 12-slot, 16-slot, and **Outbound Logistics - Dispatch** items you used. Exit the game completely.
3. Apply your options in `Prison QoL.exe`. Start through Steam and open the migration save. You can retire the old `Start Balanced Logistics.cmd` launcher. If the first load shows a missing-mod warning, check that it names the retired items you just disabled.
4. Rebuild the console from **Objects** if you want to dispatch trucks. Set Auto, Limit, Balanced Pickup, and Truck length as needed. Once the migrated prison works with your choices, you can unsubscribe from the old Workshop items.

## Tyr, backups, and restore

- **Tyr's morale option is active.** The manager greys out its corresponding option. To switch, exit the game. If you already applied this manager's patches, first use **恢复原文件** (Restore original file) to get back to the previous Tyr executable. In Tyr 1.5.0, uncheck **Staff death morale penalty fades** and apply. Reopen the QoL manager and apply its morale option along with any other patches you want.
- **The executable backup.** On first apply, the manager saves the stock or Tyr executable in `Prison QoL Backup` inside the game folder. Subsequent changes are assembled from that verified file. Use **Save Prison** for a separate backup of your prison.
- **Remove individual patches.** Finish or cancel affected construction jobs. Before disabling the console, let dispatched trucks leave, dismantle the consoles and save. Exit the game, uncheck the relevant options and apply. Turning off **Outbound Dispatch** removes the entire logistics group.
- **Restore everything and unsubscribe.** Prepare the save as described above, close the game and click **恢复原文件** (Restore original file). Unsubscribe after the restore succeeds. After a Steam update or file validation, use **复查当前目录** (Refresh current folder) to check the game version and applied options again.

## Build from source

Use Windows x64, Python 3.10 or later, PowerShell, and .NET Framework 4.x with the x64 `csc.exe` compiler. To generate the catalog, prepare two executable copies from your own game install. One is the supported stock Steam version. The other is the same game build with the supported default Tyr 1.5.0 fixes, with or without its staff morale tweak. The catalog builder verifies both inputs.

Open PowerShell at the repository root. Replace the two input paths with your own.

```powershell
$stockExe = 'C:\PA-build-inputs\stock\Prison Architect64.exe'
$tyrExe = 'C:\PA-build-inputs\tyr-1.5.0\Prison Architect64.exe'
python .\build_patch_catalog.py --steam $stockExe --tyr $tyrExe --output .\patches.json
if ($LASTEXITCODE -ne 0) { throw 'Catalog generation failed' }
& .\app\Build-App.ps1 -CatalogPath .\patches.json
```

The script builds `Prison QoL.exe` at the repository root and embeds the generated catalog in the manager. This repository provides the sources and build scripts. Supply your game files and generate the catalog locally using the steps above.

| Path | Contents |
| --- | --- |
| [`app/`](app/) | WinForms manager, Steam installation detection, executable checks, apply, and restore. |
| [`features/`](features/) | Native construction, logistics, reform, and morale patches and their build data. |
| [`build_patch_catalog.py`](build_patch_catalog.py) | Verifies the supported game builds and creates the manager's patch catalog. |
| [`patch_image.py`](patch_image.py) | Build helper for editing the Windows x64 game image in memory. |

## Feedback and credits

When reporting a problem, include the game build shown in the manager, your Tyr settings, the patches you selected, and the in-game steps and result. For a long-truck issue, also include the capacity mode, truck length, road layout, and whether the truck just spawned or was loaded from a save.

- The published Tyr 1.5.0 patch definitions inform compatibility checks. Tyr's MIT notice accompanies the source. [Tyr 1.5.0](https://github.com/Tyr077/tyrs-prison-architect-community-patch/tree/v1.5.0) · [Tyr MIT notice](features/staff_morale_decay/TYR-LICENSE.txt)
- Thanks to wackypanda for reporting the course progress bug and providing a workaround to compare against. [Original Workshop item](https://steamcommunity.com/sharedfiles/filedetails/?id=3458434752)

Tyr's license applies to the corresponding third-party material. The rest of this project has no project-wide license at present.
