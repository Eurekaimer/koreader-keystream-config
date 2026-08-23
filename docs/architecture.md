# 实现与兼容性

## 为什么同时使用插件和用户补丁

KOReader 的扩展机制有两个不同的生命周期：

1. `*.koplugin` 由插件加载器发现，适合注册 Dispatcher 动作、接入阅读器和文件管理器模块、修改运行中的菜单。
2. `patches/N-name.lua` 是官方支持的用户补丁入口。官方文档规定 `1-*` 在每次启动的早期执行，适合在第一个界面控件请求字体之前替换字体角色映射。

因此 `vimkeys.koplugin` 只负责键盘行为；`1-lxgw-fonts.lua` 只负责字体。把字体替换塞入普通插件会太晚：部分界面控件可能已经缓存了原字体。

## 插件生命周期

`vimkeys.koplugin/main.lua` 遵循内置插件的结构：

- 继承 `WidgetContainer`；
- `name = "vimkeys"`；
- `is_doc_only = false`，使阅读器和文件管理器都能创建实例；
- 阅读器实例注册 `scroll_step_down`、`scroll_step_up` 和 `edit_book_title` Dispatcher 动作；
- 文件管理器实例在 `registerPostInitCallback` 中等待 `file_chooser` 创建完成后再修改菜单。

插件包装 `history:onShowHist()`、`toc:onShowToc()` 和 `menu:onShowMenu()`，先执行原方法，再对本次新建的菜单实例安装按键。包装只安装一次，并保留原函数引用，避免重复加载时形成递归包装。

## 自定义书名快捷键

`edit_book_title` 只在阅读器中可用。`r` 触发 `EditBookTitle` 后，插件直接在阅读页面上创建独立 `InputDialog`，不打开、初始化或叠加可见的 `BookInfo` / `KeyValuePage`。对话框按钮显示 **Cancel (Ctrl+Q)** / **Save (Ctrl+S)**；`Ctrl+Q` 取消，`Ctrl+S` 或 Enter 保存。当前 KOReader 的 SDL/XIM 组合即使在 Fcitx 显示 EN 时仍会把小写字母送回中文预编辑，而且 `InputText:onKeyPress()` 不调用 `InputContainer` 的 `key_events` 分发；实机跟踪还确认 `InputText:addChars("a")` 最终得到 `啊`。插件因此只在已安装 `/usr/bin/fcitx5-remote` 的英文直输模式中关闭 SDL 文本输入，从原始 `KeyPress` 计算可打印 ASCII，直接更新当前 `InputText` 的 `charlist` 并重建文本框，同时丢弃错误的 Fcitx `TextInput`；普通 `q` / `s` 由这条路径写成字面小写字符。`Ctrl+I` 重新启用 SDL 文本输入并执行 `fcitx5-remote -o`，中文继续走原生 `TextInput`；`Ctrl+E` 先停用 SDL 文本输入再执行 `-c`，恢复 ASCII 直输且不提交残留预编辑。取消、保存、光标和删除等非文本按键均委托原生处理。未安装该程序时不启用这层工作站兼容逻辑，保留系统原生输入法行为。

保存路径直接复用 KOReader 的 `DocSettings` 语义：从当前 `doc_settings` 读取未扩展的 `doc_props`，创建或打开 custom metadata 文件，写入 `custom_props.title` 并调用 `flushCustomMetadata(file)`；成功后同步内存中的 `title` / `display_title`，广播 `InvalidateMetadataCache` 和带原生字段结构的 `BookMetadataChanged`。空标题和写入失败都会保持编辑器打开，失败时显示 `InfoMessage`。取消和成功保存都只关闭这一层对话框，因此不会残留“书籍信息”页面。该功能只修改 KOReader 自定义 Title，不修改磁盘文件名；所用内部 Lua 接口升级后必须重新验证。

## h / f 为什么不能只靠原版快捷键配置

原版 Hotkeys 插件可以在裸阅读器界面把 `h` 绑定到 History、把 `f` 绑定到 File manager。但 History、TOC 和文件列表本身是全屏 `Menu` / `BookList`，它们优先处理字母条目快捷键；阅读器底层快捷键收不到已被菜单消费的按键。

本插件在具体菜单上处理冲突：

- History 的字母快捷键保留，但从列表中移除 `F`，再将 `f` / `Ctrl+F` 直接绑定到“关闭菜单并返回文件管理器”。
- File Manager 的文件字母快捷键保留，但移除 `H`，再把 `h` 直接绑定到 History。
- History 和 TOC 直接接收 `Ctrl+J` / `Ctrl+K`，调用菜单的 `onNextPage()` / `onPrevPage()`。

这实现了稳定的阅读器 → `h` → History → `f` → File Manager 流程，而不依赖按键穿透覆盖层。

## 已修复问题

### History 字母选书失效

仅给 `BookList.item_shortcuts` 赋值不够。History 创建时快捷键开关可能仍为关闭状态，且 `key_events.SelectByShortCut` 可能引用旧表。插件同时：

1. 设置 `is_enable_shortcut = true`；
2. 生成排除 `F` 的新快捷键表；
3. 重建 `SelectByShortCut`；
4. 调用 `menu:updateItems()` 重画条目及快捷键标签。

### f 被第 14 个条目吞掉

KOReader 的字母条目序列中 `F` 位于第 14 位。当一页可显示至少 14 行时，History 会把 `f` 当成第 14 个条目的快捷键。即使该索引没有有效条目，事件仍可能被消费。插件从 History 条目快捷键中移除 `F`，由专用事件处理返回文件管理器。

### h 与文件列表冲突

File Manager 使用同一套字母条目机制。插件从文件条目快捷键中移除 `H`，避免 `h` 被解释成第 8 个文件，并在菜单本身打开 History。

### 覆盖层中 Ctrl+J/K 不工作

阅读器 Dispatcher 动作只负责裸阅读器。History 和 TOC 打开后，顶层菜单先接收事件，因此插件把 Ctrl 组合键安装到每个菜单实例，而不是依赖底层阅读器事件。

## 上方主菜单的 Vim 导航

阅读器的上方主菜单是 `TouchMenu`，继承 KOReader 的 `FocusManager`。方向键、Tab 和 Enter 原本已经能移动或激活焦点，但字母 `j/k/h/l` 没有对应关系。全局修改 `FocusManager` 会与 History 和文件列表的字母条目快捷键冲突，因此插件只包装 `ReaderMenu:onShowMenu()`，对新建的主菜单实例增加：

- `j` / `k`：调用 `onFocusMove({0, ±1})`；
- `h`：调用 `onBack()`，返回上一级；在菜单根部则关闭；
- `l`：调用 `onPress()`，等价于 Enter 激活当前焦点。

这种限定作用域的实现不会改变输入框、History、TOC 或其他对话框的字母语义。

## 富信息状态栏

`p` 使用 KOReader 原生 Dispatcher 动作 `toggle_status_bar`，最终调用 `ReaderFooter:onToggleFooterMode()`。当 `footer.all_at_once = true` 时，该方法只在“全部已选信息”与“关闭”之间切换，不再逐个循环页码、时间和百分比模式。

推荐同时启用 `page_progress`、`percentage`、`time`、`pages_left`、`chapter_time_to_read` 和 `book_time_to_read`，保留 `progress_bar_position = "alongside"`。`auto_refresh_time = true` 让时钟按分钟刷新，`hide_empty_generators = true` 避免无目录或无统计数据时留下空分隔符。

## 滚动语义

`scrollStep(direction)` 按文档类型分流：

- 可重排文档、连续滚动模式：以阅读区域高度 `ui.dimen.h` 的 30% 调整当前位置；
- 可重排文档、翻页模式：调用 `onGotoViewRel(±1)`；
- PDF/DjVu 等分页文档：调用分页模块的 `onGotoViewRel(±1)`。

因此同一组 Ctrl+J/K 在 EPUB 中表现为小于一屏的连续滚动，在 PDF 中表现为单页翻转。

## 字体补丁

补丁先检查常规字体文件。存在时：

- 启用系统字体；
- 设置文档默认字体、回退字体、页眉和等宽字体；
- 设置 CSS generic family：`serif`、`sans-serif`、`fangsong`、`cursive`、`fantasy` 和 `monospace`；
- 设置页脚字体；
- 在 `ui/font` 首次加载前替换 KOReader UI 的 regular、medium 和 mono 字体角色；
- 注册 regular/medium 与 mono/mono-medium 的粗体配对。

补丁不会覆盖某本书已经持久化的 `font_face`。这属于 KOReader 的单书设置优先级，而不是补丁失败。

## 兼容性检查

每次升级 KOReader 后至少验证：

1. 启动日志包含 `RD loaded plugin vimkeys`，且没有 Lua traceback；
2. EPUB 连续模式中 Ctrl+J/K 各移动约 30% 屏幕；
3. PDF 中 Ctrl+J/K 各翻一页；
4. 阅读器按 `h` 打开 History，History 的字母选书仍有效；
5. History 中 Ctrl+J/K 翻页，`f` 返回 File Manager；
6. File Manager 中 `h` 打开 History；
7. TOC 中 Ctrl+J/K 翻页；
8. 阅读器中 `m` 打开上方主菜单，`j/k` 移动焦点，`l` 进入项目，`h` 返回；
9. 阅读器中按 `r` 只在阅读页面上叠加独立标题输入框，不出现“书籍信息”底层页面；输入 `abc qs` 必须保留全部小写字符，普通 `q/s` 不触发命令；`Ctrl+Q` 取消且无残页，`Ctrl+S` 或 Enter 保存并直接返回阅读器；`Ctrl+I` 可启用 Fcitx 中文输入，`Ctrl+E` 恢复英文直输；
10. 富信息状态栏同时显示页码、百分比、时间、剩余信息和进度条，`p` 可隐藏并再次恢复；
11. 启用字体补丁时日志包含 `LXGW font patch applied`，正文日志显示 `set font face LXGW WenKai`；
12. 中文和英文标题、菜单、正文均无方框或缺字。

## 上游依据

- 官方用户补丁文档：<https://github.com/koreader/koreader/wiki/User-patches>
- 内置插件实现：<https://github.com/koreader/koreader/tree/master/plugins>
- 插件加载器：<https://github.com/koreader/koreader/blob/master/frontend/ui/pluginloader.lua>
- 菜单实现：<https://github.com/koreader/koreader/blob/master/frontend/ui/widget/menu.lua>

这些接口未声明为稳定的第三方 API；源码实现比非版本化示例更具约束力。
