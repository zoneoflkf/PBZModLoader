# 项目约束

## 功能修改与部署

- 修改完功能后，主动部署到游戏中。

## 游戏运行测试

- 默认由用户手动进行游戏测试，助手通过查看日志分析结果；除非用户明确要求助手进行测试，否则不要直接使用 computer-use 运行游戏进行测试。
- 启动游戏进行任何测试时，统一使用 **1280×720 分辨率的窗口模式**。
- 测试时必须通过项目脚本 `scripts/影之刃零-窗口模式1280x720.cmd` 启动游戏，不直接启动游戏可执行文件或另行调用 Steam 启动命令。该脚本依赖`scripts/PBZ-Windowed.ps1`，会传入 `-windowed -ResX=1280 -ResY=720` 并在启动时设置普通窗口尺寸，不持续监控或自动恢复尺寸。
- 开始测试前，确认游戏实际处于窗口模式，客户区尺寸为 **1280×720**；测试期间不使用最大化或全屏模式。
- 如果游戏已经运行或窗口尺寸异常，使用 `scripts/影之刃零-恢复1280x720.cmd` 强制恢复尺寸并居中，确认恢复正确后再测试。
- 如果脚本缺失或恢复未生效，应先修复脚本或显示配置，满足上述窗口模式和尺寸要求后再测试。

## Nexus Mods 发布（PBZModLoader）

本工程更新已有的 [PBZModLoader 文件页（113）](https://www.nexusmods.com/phantombladezero/mods/113?tab=files)。[PBZ Sandbox（371）](https://www.nexusmods.com/phantombladezero/mods/371) 是依赖本加载器的另一个 MOD。即使 113 的历史文件中有 MOD Demo，也不要把加载器或开发模板发到 371。

| 本次改动 | 发布文件 | Nexus 设置 |
| --- | --- | --- |
| DLL、加载逻辑、运行脚本、随包编译器或玩家安装布局有变 | `PBZModLoader-<加载器版本>-win64.zip` | **Main files**，设为默认下载，页面版本跟随加载器 |
| 只有 `game-api` 类型声明或开发模板有变 | `PBZModLoader-TS-Template-<模板版本>-SDK-<SDK版本>.zip` | **Optional files**，保留玩家主包和页面版本 |
| 只有介绍、封面或更新日志有变 | 编辑对应页面或文件的 changelog | 不重复上传 ZIP |

发布前先用内置浏览器核对 113 公开页的主文件、可选模板及版本，再对照上次发布以来的代码改动。加载器、模板、SDK 分别定版；根目录 `package.json` 的版本不是加载器版本。自 1.0.0 起默认发正式版，不再沿用旧包的 `-preview` 后缀。只更新 SDK 时，玩家无需更换加载器；若声明变更影响已有 MOD，在模板更新说明中写明迁移办法。

### 构建、验包与部署

1. **玩家包：**在仓库根目录运行 `npm.cmd ci`、`npm.cmd test` 和 `.\build.ps1 -Compiler <llvm-mingw 的 clang++.exe 路径> -Test`。适配游戏更新时，加 `-GameExe <实际游戏 EXE 路径>` 做只读特征回归。用 `.\package.ps1 -Version <加载器版本>` 打包；脚本拒绝覆盖同名产物。确需同版本修正时，先将旧发布目录、ZIP 和清单移至 `releases/archive/`，再生成并比对差异。
2. **玩家包验收：**使用 `releases/` 下通过校验的 ZIP 与配套 `.zip.manifest.json`。ZIP 根部应直接可见 `ProjectPBZ/`、`platform/`、`备用入口/` 和 `PBZModLoader-安装说明.txt`。核对 Steam、WeGame 各自的 `version.dll`、四个备用代理、随包编译器和许可证。特别检查 ZIP **及解压后**都存在空的 `ProjectPBZ/PBZModLoader/mods/`；发行包不预装示例 MOD。确认文件白名单、逐文件解压哈希及待上传 ZIP 的 SHA-256 与清单相符。
3. **部署与实测：**退出游戏，备份将覆盖的文件，保留玩家的 `mods.ini` 和 `mods/`。更新实际游戏 EXE 旁已选用的那个代理 DLL，以及 `bootstrap.js`、`manager.js` 和随包编译器；不覆盖其他工具的同名 DLL，不同时启用多个入口。将已部署的运行文件与发布清单比对哈希。按上节方式由用户实测启动、加载 MOD 及本次改动涉及的场景，从 `ProjectPBZ/PBZModLoader/evidence/<本次运行>/loader.log` 核对加载结果；构建、宿主测试或哈希校验通过不能写成游戏实测通过。
4. **开发模板：**以 `sdk/` 为源，在仓库根目录安装依赖后运行 `npm.cmd run sdk:sync`、`npm.cmd test`。从 `templates/ts-mod/` 打独立 ZIP：顶层为 `PBZModLoader-TS-Template/`，包含 README、示例、构建脚本、锁文件及完整 `vendor/game-api/`，排除 `node_modules/` 和 `dist/`。在干净目录解压，从模板目录依次运行 `npm.cmd ci`、`npm.cmd run check`、`npm.cmd run build`，确认生成 `dist/my-mod/main.js`。核对内置 SDK 文件与 `sdk/` 一致，在配套清单记录两个版本、ZIP 的 SHA-256 和验证结果。

### 上传和更新说明

1. 在内置浏览器进入 113 的 **Manage → Files**，找到要替换的文件，选择 **Update**，上传已校验的 ZIP，勾选 **Archive existing file** 保留旧版。玩家包的 `Display name` 填 `PBZModLoader <加载器版本>`，`File version` 填同一版本，设为主下载并勾选 **Update mod version to match this file’s version**。模板的显示名和说明标明模板及 SDK 两个版本，`File version` 填模板版本，不勾选同步页面版本或设为主下载。未验证管理器安装前，采用手动安装，不启用 **Allow mod manager download**。
2. 保存文件前填写本版中英文 changelog，写清玩家或作者要更新什么、怎么升级。**General** 中以现有公开正文为底稿，保留开头的「交流QQ群：1130285067」、双语安装／升级／卸载说明、兼容范围、开发模板和 AI Agent 入门指引，以及第三方署名。摘要限 350 字符，文件简介限 255 字符，正文可用 **View source** 编辑 BBCode。测试数量、部署哈希留在内部记录；按表单要求如实注明 AI 辅助内容。
3. 文案以本版实际行为为准：玩家无需 Node.js，按 **Alt+F5** 热重载，参与热重载的 MOD 需导出 `stop()` 清理旧实例；开发者使用独立模板。WeGame 已实测加载器自动加载和 MOD 运行，不据此声称四个备用入口、全部 SDK API 或与其他 MOD 共存均已验证。`releases/PBZModLoader-Nexus-release-copy.txt` 是首次预览版的旧稿，不要把其中的 Ctrl+F5、预装示例或“WeGame 未验证”带回正文或封面。

### 发布后核验与异常处理

- 重新打开 113 的公开页：在 **Files** 核对默认玩家包、页面版本、可选模板的两个版本、旧文件归档及扫描状态；在 **Description / Changelogs** 核对本次修改是否生效。留存公开页截图到 `releases/nexus/`。文件已出现但还在病毒扫描时，报告“已发布，待扫描完成后开放下载”；仅保存草稿不能算公开发布。
- 登录或 Cloudflare 真人验证由用户在保留的浏览器页面完成。遇到 403 或保存失败，先保留本地文案，再查看公开页哪些改动已生效。主文件已发布就只补改缺失的版本、介绍或 changelog，不重复上传，也不把部分成功报告为全部完成。
- 同步 [GitHub Release](https://github.com/zoneoflkf/PBZModLoader/releases) 时，使用与 Nexus 同一份已校验 ZIP，在对应的 `v<加载器版本>` 下提供玩家包、校验清单、安装说明和对应的模板附件；核对附件哈希。同步检查 `README.md` 与 `README.en.md` 开头的 Nexus 入口、模板直链、封面热键及平台说明。已上传 ZIP 内的旧说明不会随网页更新，若需更正包内内容，按同版本修正或新版本流程重新验包。
