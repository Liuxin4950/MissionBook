# Mission Book 图标

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
