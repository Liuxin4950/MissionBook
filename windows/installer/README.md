# Windows 安装程序

使用 Inno Setup 6/7 将 Flutter Windows Release 目录打包为独立 x64 安装程序。

```powershell
powershell -ExecutionPolicy Bypass -File tool/windows/build_windows_installer.ps1
```

输出位于 `build/deliverables/MissionBook-Setup-<版本>-Windows-x64.exe`，同时生成 SHA-256 校验文件。向导默认安装到当前用户的 `%LOCALAPPDATA%\Programs\MissionBook`，可浏览并选择其他磁盘或目录，不需要管理员权限。提供开始菜单快捷方式和可选桌面快捷方式；重新运行安装程序可升级。

应用本机数据由 Windows `path_provider` 按可执行文件的产品版本信息保存在 `%APPDATA%\chat.liuxin\Mission Book`，与安装目录分开。卸载不会删除数据库、设置或附件。

当前安装包提供标准安装/升级/卸载，不带代码签名。Windows 发布者认证仍需正式签名证书。
