# Mission Book 图标

## 当前采用：v4「MB 书脊」

2026-10-21，用户选择[第 04 版概念](concepts/2026-10-21/04-MB书脊.png)，并授权应用到 Android 各档尺寸。正式资源采用此版书页轮廓：左页保留切口，右页两段弧线形成 B；深绿 `#173F35` 配米白 `#F7F4EA`。

- [Logo SVG](mission_book_logo_v4.svg) / [透明 Logo PNG](mission_book_logo_v4.png)：独立品牌标记。
- [自适应前景 SVG](mission_book_icon_v4.svg) / `mission_book_icon_foreground.png`：1080×1080 透明母版。
- `mission_book_icon_master.png`：1024×1024 彩色方形母版。
- [圆角、圆形与单色预览](mission_book_icon_v4_preview.png) · [制作过程和提示词](mission_book_icon_v4.prompt.md)。
- Android 普通/圆形 PNG：mdpi、hdpi、xhdpi、xxhdpi、xxxhdpi，分别 48/72/96/144/192 px；前景分别 108/162/216/324/432 px。
- Android 13 主题图标：独立 `drawable/ic_launcher_monochrome.xml`，与彩色前景使用同一组矢量轮廓；v33 的普通/圆形 adaptive XML 已引用它。v26 两份 adaptive XML 继续引用统一彩色前景和背景。
- 通知图标：相同书页标记的白色透明 PNG，五档 24/36/48/72/96 px。
- v3 两份旧母版保存在 `archive/v3/`，原始生图和历史提示词仍保留。Android v4 本轮未替换其他平台入口资源；Windows 的后续更新见下。

尺寸、透明度、四份 adaptive XML 引用及单色路径检查通过；20 张 Android PNG 均通过检查；1080 母版最大不透明半径 304.80 px，小于 330 px 安全圆半径。Android SDK 35 的 aapt2 编译全部资源成功。安装包及设备验收结果见下方本轮验证记录。

### v4 本轮安装包验证

- 使用本机 Java 21 构建；离线构建因 Flutter 引擎依赖未缓存失败，随后仅为本次进程启用现有本机代理，在线 `:app:assembleRelease -Ptarget-platform=android-arm64` 成功。未修改全局代理、JDK、Gradle 配置或依赖版本。
- 产物：`build/app/outputs/apk/release/app-release.apk`，20,718,841 字节，版本 0.2.2+4，包名 `chat.liuxin.mission_book`。这是 ARM64 预览包，继续使用项目既有 debug 签名配置；未改版本号或发布设置。
- aapt2 读取最终 APK，确认 15 张各密度启动图标与源码 PNG 逐像素一致；v33 普通/圆形图标均引用专用单色资源，包内三条路径与正式 SVG 一致。ARM64 的 libapp.so / libflutter.so 均存在。
- APK SHA-256：`8b6a40e0963129d19be82918f3b0a8e3c0052e85bcb50aef8ed55a2e3842938b`。
- 通知资源已更新源码；当前未被使用的通知 PNG 会被 release 资源收缩移除，不据此宣称通知行为已实测。
- 未安装到设备；桌面图标、系统主题及通知外观仍待设备验收。当前只替换 Android 资源，不推进业务课程或标记新知识已掌握。

### Windows 图标同步

Windows 使用同一 v4 彩色母版，圆角透明轮廓与 Android 普通图标一致。`windows/runner/resources/app_icon.ico` 包含 16、20、24、32、40、48、64、128 和 256 像素尺寸，由 Windows runner 的 `IDI_APP_ICON` 引用。

## 历史：v3「打开书本＋书签勾」

以下为 2026-10-20 的历史记录，当时的当前资源现已由 v4 替换。

2026-10-20，用户确认暂用 v3「打开书本＋书签勾」彩色图标。图像由内置 image_gen 根据 UI 手册初稿封面生成，使用 PNG。

- `mission_book_icon_source_v3.png`：1254 × 1254 原始透明生成图。
- `mission_book_icon_master.png`：1024 × 1024 彩色方形母版，深绿色背景 `#173F35`。
- `mission_book_icon_foreground.png`：1080 × 1080 透明 adaptive 前景母图。
- `mission_book_icon_v3.prompt.md`：最终生成提示词。

Android 已采用此版彩色图标。普通与圆形 PNG 导出五档 48/72/96/144/192 px；adaptive 前景导出 108/162/216/324/432 px。v26 与 v33 共用相同前景和背景引用。108 dp 图层中，72 dp 为系统裁切视口，中心直径 66 dp 圆为安全区；本版母图逐像素检查的最大不透明像素半径约 275.85 px，小于 330 px 的安全区半径。

Android 13 单色主题与通知图标继续采用现有简化书本勾 `ic_notification`，以保留其单色表达和通知辨识度。Windows、Web、iOS、macOS 的平台入口暂未更换。

依据：[Android adaptive icons](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive)。本次仅替换品牌图片与 Android 颜色资源，不涉及业务或学习课程变更。

## 本次验证

- 15 张 Android PNG 与用户确认的 v3 导出逐文件 SHA-256 一致；五档尺寸与前景角落透明度通过检查。
- v26/v33 共四个 adaptive XML 的彩色前景、背景引用核对通过；品牌母版为 1024 × 1024。
- Android SDK 35.0.0 的 aapt2 成功编译项目全部 Android 资源；相关文件 git diff --check 通过。
- ARM64 release APK 构建在依赖网络读取阶段长期等待。使用本机既有 7890 代理重试后仍等待网络，已终止这两次构建，未改全局代理、JDK 或 Gradle 配置。本轮未产出新版 APK，未安装或验收设备图标。
