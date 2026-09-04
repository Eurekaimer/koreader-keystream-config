# KOReader Keystream Config

面向 Linux 桌面版 KOReader 的个人键盘优先配置，包含键盘导航插件、快捷键、字体补丁和桌面端兼容修复。项目把可复用逻辑放在插件中，把必须早于界面加载的字体替换放在用户补丁中，并提供最小配置示例。

当前版本按 **KOReader 2026.07.1、SDL 桌面后端、Linux** 编写并实机验证。KOReader 的插件 API 属于内部 Lua API，升级后应重新测试。

## 功能

- 阅读器：`j` / `k` 小幅滚动，`Space` / `Ctrl+J` 向下滚动屏幕高度的 35%，`Ctrl+K` 向上滚动 35%；PDF 或翻页模式中改为下一页 / 上一页。
- 阅读器：`h` 打开阅读历史，`f` 返回文件管理器，`m` 打开上方主菜单，`p` 显示/隐藏富信息状态栏，`r` 编辑当前文档的 KOReader 自定义书名，`t` 打开目录，`b` 打开书签，`q` 退出。
- 历史记录：保留每本书的字母快捷键；`Ctrl+J` / `Ctrl+K` 翻页；保留 `f` / `Ctrl+F` 返回文件管理器。
- 文件管理器：`h` 打开历史记录，同时保留其他文件条目的字母快捷键。
- 目录：`Ctrl+J` / `Ctrl+K` 翻页。
- 上方主菜单：`j` / `k` 移动焦点，`h` 返回上一级或关闭菜单，`l` / `Enter` 进入当前项目；方向键、Tab、Enter 仍保持原生行为。
- EPUB 默认使用连续滚动模式。
- 可选 LXGW WenKai 字体补丁：统一 KOReader 界面、正文默认字体、回退字体、页眉、页脚和等宽字体。
- 可选离线英汉词典：把固定版本的 ECDICT 转换为 KOReader 可直接读取的 StarDict，包含 3,402,564 个词条及动词时态、复数、比较级等词形。

## 项目结构

```text
plugins/
  vimkeys.koplugin/        KOReader 插件
    _meta.lua
    main.lua
patches/
  1-lxgw-fonts.lua         可选的早期字体补丁
  2-pdf-scroll-guard.lua   PDF 滚动泄漏守卫(必需)
examples/
  defaults.custom.lua      EPUB 连续滚动默认值
  settings/hotkeys.lua     最小键盘配置示例
licenses/
  ECDICT-LICENSE          ECDICT 第三方许可证
scripts/
  install-ecdict.sh       下载、校验、转换并安装 ECDICT
  ecdict_to_stardict.py   流式 StarDict 转换器
docs/
  architecture.md          实现、兼容性和已修复问题
```

## 安装

先完全退出 KOReader，再备份现有配置：

```bash
cp -a ~/.config/koreader ~/.config/koreader.backup
mkdir -p ~/.config/koreader/plugins ~/.config/koreader/patches
cp -a plugins/vimkeys.koplugin ~/.config/koreader/plugins/
cp -a patches/2-pdf-scroll-guard.lua ~/.config/koreader/patches/
```

如果尚无 `defaults.custom.lua`，可直接复制示例；如果文件已存在，只合并 `DCREREADER_VIEW_MODE = "scroll"`，不要覆盖其他默认值：

```bash
cp -a examples/defaults.custom.lua ~/.config/koreader/defaults.custom.lua
```

`DCREREADER_VIEW_MODE = "scroll"` 会触发 [KOReader #15910](https://github.com/koreader/koreader/issues/15910)：无 `.sdr` 的 PDF 首次打开时可能进入 CRE 滚动分支并崩溃。因此使用该默认值时必须同时安装 `2-pdf-scroll-guard.lua`。补丁按维护者建议用 `self.ui.rolling` 区分 CRE 与 PDF/DjVu，并让分页文档回退到页码进度。

### 离线英汉词典

需要 `curl`、`7z`、`python3` 和约 300 MiB 可用空间。安装器下载固定在
ECDICT `c1643ac` 的 50 MiB 压缩包，校验 SHA-256 后流式生成 3,402,564
个 StarDict 词条；不把大型词典文件提交进仓库，也不删除其他词典：

```bash
./scripts/install-ecdict.sh
./scripts/install-ecdict.sh --dry-run
# 已有固定版本压缩包时可离线安装
./scripts/install-ecdict.sh --archive /path/to/stardict.7z
```

输出目录为 `~/.config/koreader/data/dict/ecdict-en-zh/`；设置
`STARDICT_DATA_DIR` 可改写词典根目录。重复执行会复用已验证的安装，
需要重建时加 `--force`。安装后重启 KOReader，并保持“使用外部词典”
关闭；本地 StarDict 不属于 KOReader 所称的外部词典应用。

安装器会用 `sdcv`（存在时）精确查询 `computational`，确认结果包含
“计算的”后才替换旧的同名 ECDICT 目录。

`hotkeys.lua` 很可能已经包含设备、游戏手柄或个人绑定，**不要直接覆盖**。推荐在 KOReader 的“键盘快捷键”界面中按下表绑定；也可以手工合并 `examples/settings/hotkeys.lua`：

| 上下文 | 按键 | KOReader 动作 |
|---|---|---|
| 阅读器 | `j` / `k` | `key_down` / `key_up` |
| 阅读器 | `Ctrl+J` / `Ctrl+K` | `scroll_step_down` / `scroll_step_up` |
| 阅读器 | `Space` | `scroll_step_down` |
| 阅读器 | `h` | `history` |
| 阅读器 | `f` | `filemanager` |
| 阅读器 | `m` | `show_menu` |
| 阅读器 | `p` | `toggle_status_bar` |
| 阅读器 | `t` | `toc` |
| 阅读器 | `b` | `bookmarks` |
| 阅读器 | `q` | `exit` |
| 阅读器 | `r` | `edit_book_title` |
| 书名编辑器 | `Ctrl+Q` / `Ctrl+S` / Enter | 取消 / 保存 / 保存 |
| 书名编辑器 | 普通 `q` / `s` | 输入字面小写字符 |
| 书名编辑器 | `Ctrl+E` / `Ctrl+I` | 英文直输 / 启用 Fcitx IME |
| 文件管理器 | `Ctrl+J` / `Ctrl+K` | 下一页 / 上一页 |
| 上方主菜单 | `j` / `k` | 下一项 / 上一项 |
| 上方主菜单 | `h` / `l` | 返回 / 进入 |

KOReader 写入配置时使用的 `alt_plus_j` 等字段名是其内部存储格式；不同设备的修饰键映射可能不同。优先通过界面生成绑定，不要根据字段名推测实体按键。

重启 KOReader 后，在“工具 → 更多工具 → 插件管理”中确认 **Vim Keys** 已启用。

## 修改 KOReader 中显示的书名

阅读器中按 `r` 会在阅读页面上直接打开一个独立的 KOReader 自定义 Title 编辑器，不会打开或叠加“书籍信息”页面。按钮明确显示 **取消 (Ctrl+Q)** 和 **保存 (Ctrl+S)**：`Ctrl+Q` 放弃并直接回到阅读器，`Ctrl+S` 或 Enter 保存并直接回到阅读器。普通 `q` / `s` 没有命令绑定，会作为小写字符输入。`Ctrl+E` 切换到英文直输，`Ctrl+I` 启用 Fcitx IME；未安装 `/usr/bin/fcitx5-remote` 时由系统自行管理输入法，不影响取消或保存。保存只修改 KOReader 的自定义 Title 元数据，不会重命名磁盘上的文件。PDF 显示为 `united` 一类名称通常来自文件内嵌的 Title 元数据；用 `r` 覆盖即可。若要修改实际文件名，请在文件管理器中长按或右键该书，再选择 **Rename**。

## 富信息状态栏

推荐启用“同时显示所有选中项目”，把页码、百分比、当前时间、章节剩余页数、章节剩余时间、全书剩余时间和进度条放在同一条状态栏中。这样无需在多个状态栏模式间循环；阅读器中的 `p` 只负责在完整状态栏与隐藏状态之间切换。

当前验证配置的关键值如下。请合并到现有 `settings.reader.lua` 的 `footer` 表，不要覆盖整个文件：

```lua
["footer"] = {
    ["all_at_once"] = true,
    ["auto_refresh_time"] = true,
    ["hide_empty_generators"] = true,
    ["book_time_to_read"] = true,
    ["chapter_time_to_read"] = true,
    ["disable_progress_bar"] = false,
    ["page_progress"] = true,
    ["pages_left"] = true,
    ["percentage"] = true,
    ["progress_bar_position"] = "alongside",
    ["time"] = true,
},
["reader_footer_mode"] = 1,
```

也可以在 KOReader 底部排版菜单的“状态栏”设置中选择同样的项目。`auto_refresh_time` 使时间无需翻页也能按分钟更新；`hide_empty_generators` 会隐藏当前文档无法提供的空项目。

## 可选字体优化

先安装 LXGW WenKai 字体，并确认以下文件存在：

```text
/usr/share/fonts/TTF/LXGWWenKai-Regular.ttf
/usr/share/fonts/TTF/LXGWWenKai-Medium.ttf
/usr/share/fonts/TTF/LXGWWenKaiMono-Regular.ttf
/usr/share/fonts/TTF/LXGWWenKaiMono-Medium.ttf
```

然后复制补丁：

```bash
cp -a patches/1-lxgw-fonts.lua ~/.config/koreader/patches/
```

如果字体目录或文件名不同，修改补丁顶部的 `font_dir` 与四个文件名。常规字体不存在时补丁会直接退出，不改变 KOReader。已有书籍可能在 `.sdr/metadata.*.lua` 中保存了单书 `font_face`，这种覆盖优先于全局默认，需要在该书字体菜单中切换一次。

KOReader 官方用户补丁约定要求文件名以数字和连字符开头；`1-*` 补丁会在每次启动的早期执行。本项目因此把字体角色映射放在 `1-lxgw-fonts.lua`，而不是普通插件初始化阶段。

## 卸载

退出 KOReader 后删除以下内容并重启：

```bash
rm -rf ~/.config/koreader/plugins/vimkeys.koplugin
rm -f ~/.config/koreader/patches/1-lxgw-fonts.lua ~/.config/koreader/patches/2-pdf-scroll-guard.lua
rm -rf ~/.config/koreader/data/dict/ecdict-en-zh
```

手工恢复或删除本项目添加到 `hotkeys.lua` 和 `defaults.custom.lua` 的条目。项目不会自动删除用户阅读历史、书签或 `.sdr` 数据。

## 限制

- 仅在 Linux 桌面键盘环境验证；触控设备、Android、Kindle、Kobo 未验证。
- 插件依赖 KOReader 的 `BookList`、`Menu`、`ReaderToc` 和 `FileManagerHistory` 内部接口。
- `h` / `f` 在历史记录和文件管理器中原本可能被分配给第 8 / 14 个条目；插件会有意保留这两个字母用于导航。
- 字体补丁是可选 Linux 配置，不属于 Vim 键位功能，也不会下载字体。
- 完整 ECDICT 词典约占 270 MiB；首次安装需要下载并转换，之后查询完全离线。

技术细节和已修复问题见 [docs/architecture.md](docs/architecture.md)。

## 上游参考

- [KOReader 官方源码](https://github.com/koreader/koreader)
- [KOReader 内置插件目录](https://github.com/koreader/koreader/tree/master/plugins)
- [官方 Hello 插件示例](https://github.com/koreader/koreader/tree/master/plugins/hello.koplugin)
- [KOReader 用户补丁文档](https://github.com/koreader/koreader/wiki/User-patches)
