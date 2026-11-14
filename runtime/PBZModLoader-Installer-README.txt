PBZModLoader Windows 安装器

1. 退出游戏。将安装器 ZIP 解压到游戏目录之外，例如 Downloads\PBZModLoader。
2. 下载玩家主包 PBZModLoader-<版本>-win64.zip，将未解压的主包 ZIP 放到
   PBZModLoader-Install.cmd 旁边。同一目录只放一个玩家主包 ZIP。
3. 双击 PBZModLoader-Install.cmd。检测到唯一的 Steam 安装时会自动使用它。
   如需选择，指定同时包含 ProjectPBZ 和 platform 的游戏根目录，例如 D:\Games\PBZ。
   也可把游戏根目录拖到 .cmd 上，直接指定安装位置。
4. 安装器将入口 DLL 放在 PBZ.exe 旁，Steam 为 platform\steam，WeGame 为 platform\wegame。
   下载的 MOD 放到游戏根目录下的 ProjectPBZ\PBZModLoader\mods。安装成功后从游戏平台启动游戏。

如果已完整解压玩家主包，也可以把新的 .cmd 复制到主包的解压目录后运行。解压目录仍须位于游戏目录之外。
发现多个已确认属于 PBZModLoader 的入口时，输入编号选择保留并升级的入口。其余已确认的 DLL
会移入游戏根目录下的 PBZModLoader-Backups。来源不明的 DLL 留在原处。输入 0 或按回车可取消。
升级保留 mods.ini 和 mods/。只发现来源不明的 DLL 时，请查看玩家主包中的手动安装说明。

PBZModLoader Windows Installer

1. Close the game. Extract the installer ZIP to a folder outside the game, such as Downloads\PBZModLoader.
2. Download the main player ZIP, PBZModLoader-<version>-win64.zip, and put it beside
   PBZModLoader-Install.cmd. Leave the player ZIP unopened and keep just one player ZIP in that folder.
3. Run PBZModLoader-Install.cmd. It uses the Steam installation if it finds exactly one.
   If prompted, select the game root containing both ProjectPBZ and platform, for example D:\Games\PBZ.
   You can also drag the game root onto the .cmd file to target that installation.
4. The installer places the entry DLL beside PBZ.exe in platform\steam or platform\wegame.
   Put downloaded mods under ProjectPBZ\PBZModLoader\mods in the game root. After installation,
   start the game from Steam or WeGame.

If you already extracted the full player ZIP outside the game, you can copy the new .cmd into that
folder and run it there. If multiple confirmed PBZModLoader DLLs are found, enter the number of
the entry to keep and update. The installer moves the other confirmed DLLs to PBZModLoader-Backups
under the game root. Unrecognized DLLs stay in place. Enter 0 or press Enter to cancel.
An upgrade preserves your mods.ini and mods. If the installer finds only unrecognized DLLs,
see the manual installation guide in the player ZIP.
