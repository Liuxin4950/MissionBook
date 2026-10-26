# Android chroot 中构建预览 APK

初次核验：2026-10-20；发布注册流程补正：2026-10-26。适用于本机 ARM64 Android chroot 环境；路径、代理端口和工具版本以后应先核对，不默认永远有效。

## 环境与产物

- 项目：`/root/Working/MissionBook`。
- Flutter：`/opt/flutter`；Android SDK：`/opt/android-sdk`，由 `android/local.properties` 配置。
- Gradle 构建依赖缓存：`/root/.gradle`。已有 SDK 不代表 Gradle、插件、引擎库和所需 SDK 版本都已缓存。
- 本机 HTTP 代理：`127.0.0.1:7890`。本次已验证可用；Android 开着 VPN 不等于 Java 已显式使用代理。
- ARM64 APK：`build/app/outputs/flutter-apk/app-release.apk`。
- Android 共享下载目录：`/sdcard/Download`，本机挂载可写。

## 标准步骤

在项目根目录执行。首次构建、依赖变化或插件元数据缺失后先恢复依赖：

```bash
cd /root/Working/MissionBook
flutter pub get
flutter analyze --no-pub
```

`pub get` 用于恢复依赖与自动生成的插件元数据，不需要先升级依赖。检查锁文件差异，避免将版本变化当成普通恢复。

针对本机 Android 构建 ARM64 release 预览包，给本次 Java/Gradle 命令显式传代理：

```bash
JAVA_TOOL_OPTIONS='-Dhttp.proxyHost=127.0.0.1 -Dhttp.proxyPort=7890 -Dhttps.proxyHost=127.0.0.1 -Dhttps.proxyPort=7890 -Dhttp.nonProxyHosts=localhost|127.*' \
  flutter build apk --release --target-platform android-arm64 \
  > /tmp/missionbook-apk-build-proxy.log 2>&1
```

代理设置仅作用于本次命令及子进程；先确认端口可用。无需永久修改项目或全局 Gradle 配置。日志中 `Picked up JAVA_TOOL_OPTIONS` 证明 Java 收到了参数；结合实际下载和构建结果判断是否可用。

构建运行中可从另一终端查看日志：

```bash
tail -30 /tmp/missionbook-apk-build-proxy.log
```

成功必须同时确认命令成功、日志有 `Built ...app-release.apk`、产物存在；不能只凭进程退出或旧 APK 存在就宣称成功。

复制到 Android 下载目录，文件名中的版本应与本次版本对应：

```bash
cp build/app/outputs/flutter-apk/app-release.apk /sdcard/Download/MissionBook-0.2.2-preview.apk
sha256sum build/app/outputs/flutter-apk/app-release.apk /sdcard/Download/MissionBook-0.2.2-preview.apk
```

两行 SHA-256 应一致。用户在 Android 文件管理器的“下载”中点击 APK 安装；复制成功不等于安装或启动验收完成。

如果 ADB 检测到目标设备，也可使用：

```bash
adb devices -l
adb -s <实际设备编号> install -r build/app/outputs/flutter-apk/app-release.apk
```

本次 `adb devices -l` 无设备，因此采用共享目录交付，未声称自动安装成功。

## 本机已遇到的情况

### 插件注册文件引用不存在的类

本次首轮 Java 编译提示 `FlutterLocalNotificationsPlugin`、`JniPlugin`、`JniFlutterPlugin` 不存在。项目缺少 `.flutter-plugins-dependencies`，自动生成注册代码与 Gradle 插件加载不一致。

执行 `flutter pub get` 后恢复插件元数据，Android 插件路径存在、`native_build` 为 true，重新构建成功。不要手改 `GeneratedPluginRegistrant.java`、删除插件注册或添加空类掩盖问题。

### 首次构建下载很多

本次补齐 Gradle 8.14、Maven 依赖、Flutter 引擎库、SDK Build-Tools 35.0.0 和 Platform 35。SDK 安装在 `/opt/android-sdk`；Gradle 缓存在 `/root/.gradle`，属于不同内容。

下载慢时检查日志、临时文件大小是否增长，以及 Java 的代理参数；不要把持续下载误判为失败，也不要反复重启。必要重试前结束旧构建及其残留子进程，避免并行写同一编译产物。

### ARM64 主机上的构建工具

本机 `/root/.gradle/gradle.properties` 已配置：

```properties
android.aapt2FromMavenOverride=/opt/android-sdk/build-tools/37.0.0/aapt2
```

该 aapt2 已验证为 ARM aarch64；SDK 36 中的 aapt2 为 x86-64。先核对实际工具与配置，不覆盖现有 ARM64 适配。

本机 Flutter 的 release `gen_snapshot` 实际通过 QEMU 执行 x86_64 编译器，因此即使网络完成，AOT 编译仍可能需要数分钟。只构建 `android-arm64` 可减少无关架构工作；不要把编译耗时都归因于代理。

## 2026-10-26：Flutter 3.47 的发布插件注册

当前环境升级为 Flutter 3.47.4 / Dart 3.13.3，项目已有 `integration_test` 开发依赖。若发布构建报 `GeneratedPluginRegistrant.java` 引用 `dev.flutter.plugins.integration_test` 但找不到类，不能手改自动注册代码或删除测试插件来掩盖问题。

已核对本机 Flutter tools：`runner/flutter_command.dart` 的 `regeneratePlatformSpecificToolingIfApplicable` 在 `shouldRunPub == false` 时直接返回；`flutter_plugins.dart` 的 `injectPlugins(releaseMode: true)` 才筛掉只用于开发的插件。因此“先 pub get，再 --no-pub 发布”可能沿用开发模式注册代码。应串行执行带默认 pub 步骤的发布命令，让本次构建生成自己的注册文件：

```bash
flutter build apk --release --target-platform android-arm64
```

不要在同一工作区同时运行会重建插件注册文件的其他 Flutter 命令。已有 AOT 产物可复用；此修正不需要修改业务依赖、用户数据或 Flutter SDK。

## 本次结果与边界

2026-10-20：ARM64 release APK 构建成功，约 18.9 MB；复制到共享下载目录并核对 SHA-256 一致。现有 release 配置使用 debug 签名，属于本地预览包，不代表正式发布签名已配置。

此包仅预览当前已实现界面和应用装配；创建表单与真实列表尚未接通。构建成功不证明 Android 启动、业务持久化或功能验收通过。后续结果分别记录在[学习进度](../教学/学习进度.md)。
