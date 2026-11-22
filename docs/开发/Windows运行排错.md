# Windows 运行与完整性排错

本机曾出现「`flutter run` 连不上设备、应用启动后点击无响应」的组合故障。根因不在 Flutter 代码，而是项目目录被设置了 **Low 完整性标签**，导致 `mission_book.exe` 以 Low 完整性运行，无法写入用户目录。

## 现象

1. `flutter run -d windows` 能编译、能启动，但随后失败：

   ```
   Finished with error: _createDevFS: (-32603) Internal error
   PathAccessException: Creation of temporary directory failed,
     path = 'C:\Users\<用户>\AppData\Local\Temp' (OS Error: 拒绝访问。, errno = 5)
   ```

2. 应用日志出现数据库只读/打不开：

   ```
   SqliteException(8): attempt to write a readonly database
     Causing statement: DROP TABLE IF EXISTS "goals"
   SqliteException(14): unable to open database file
   ```

3. `flutter_secure_storage` 无法创建数据文件：

   ```
   Cannot create file ...\AppData\Roaming\chat.liuxin\Mission Book\flutter_secure_storage.dat
     (OS Error: 拒绝访问。, errno = 5)
   ```

4. 数据库连接始终没有打开，任何等待数据库的点击都停在等待状态，表现为「点一下就没响应」。

## 根因

`E:\working\mission_book` 上有一条显式的完整性标签：

```text
Mandatory Label\Low Mandatory Level:(OI)(CI)(NW)
```

`(OI)(CI)` 让整棵目录树继承 Low，包括构建产物 `build\windows\x64\runner\Debug\mission_book.exe`。Windows 以可执行文件自身的完整性级别启动进程，因此应用进程令牌是 **Low**（SID `S-1-16-4096`）。

完整性级别对照：

| SID | 级别 |
| --- | --- |
| `S-1-16-4096` | Low |
| `S-1-16-8192` | Medium（未标注对象的默认有效级别） |
| `S-1-16-12288` | High |
| `S-1-16-16384` | System |

Low 进程受「禁止向上写」（no-write-up）约束：不能写入 Medium 对象。`%TEMP%` 和 `%APPDATA%\chat.liuxin\Mission Book` 都没有显式标签，按 Medium 处理，所以应用的临时目录创建、SQLite 建库/写库和 Secure Storage 全部被拒绝。构建目录 `E:\` 本身是 Low，所以写 `missionbook-run.log` 反而正常，容易误判为「只有数据库坏了」。

VM Service 的 `createTempDirCallback` 运行在 **应用进程** 内（`dart:_vmservice/devfs.dart`），所以 `_createDevFS` 报的是应用进程的权限错误，不是 Flutter 工具本身。

## 诊断

```powershell
# 1. 看目录树上的完整性标签；出现 Low Mandatory Level 即命中本问题
icacls.exe 'E:\working\mission_book'

# 2. 看运行中进程的令牌级别（需要能打开进程令牌）
#    令牌里 integrity 为 S-1-16-4096 表示 Low
```

PowerShell 读取令牌时，`TokenIntegrityLevel` 对应的信息类是 25，`TokenIsAppContainer` 是 29；不要用 `TokenSessionId`（12）等其它类去判断。

## 修复

把项目目录整树改为 Medium（`M`），让后续构建产物不再继承 Low：

```powershell
icacls.exe 'E:\working\mission_book' /setintegritylevel (OI)(CI)M /T
```

- 在 Git Bash 中执行时，MSYS 会把 `(OI)(CI)M` 当成路径转换，建议改用 PowerShell 或加 `MSYS_NO_PATHCONV=1`。
- `/T` 会遍历整棵树；本次处理了约 3.8 万个文件。
- 改完后重新构建，确认 exe 标签为 `Medium Mandatory Level`，再启动应用。

验证要点：

```powershell
icacls.exe 'E:\working\mission_book\build\windows\x64\runner\Debug\mission_book.exe'
# 应显示 Mandatory Label\Medium Mandatory Level
```

应用首次启动应重新生成 `%APPDATA%\chat.liuxin\Mission Book\mission_book.sqlite` 和 `flutter_secure_storage.dat`；`flutter run` 应完成 `Syncing files to device Windows` 且不再出现 `_createDevFS` 错误。

## 旧数据清空

本次按用户选择直接删除旧库、不备份：

- 删除：`mission_book.sqlite`、`mission_book.v15-backup-*.sqlite`、`mission_book_goal_import.sqlite`
- 保留：`attachments/`、`reminders.json`

旧库来自 v15；当前 `schemaVersion = 18`，[AppDatabase.onUpgrade](../../lib/data/local/app_database.dart) 的设计是清空全部业务表后按最新结构重建，因此清空旧库与升级得到同一套表结构。

## 仍存在的目录加固

修复后项目目录仍保留两条显式 ACE：

```text
Everyone:(CI)(DENY)(DC)
S-1-4-410463808-309200527:(OI)(CI)(W,D,DC)
```

`(DENY)(DELETE_CHILD)` 会拒绝删除子项，可能影响 `flutter clean`、`git clean` 等需要删除文件的命令。它与本次 Low 标签问题无关，未做改动；如后续删除操作报拒绝访问，先检查这条 ACE。

若某些安全工具重新给目录打上 Low 标签，上述症状会复现；用 `icacls` 复查即可。
