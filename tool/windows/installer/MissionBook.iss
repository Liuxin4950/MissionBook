#ifndef BuildDir
  #error BuildDir must be supplied by the PowerShell packaging script
#endif
#ifndef AppVersion
  #error AppVersion must be supplied by the PowerShell packaging script
#endif
#ifndef OutputDir
  #error OutputDir must be supplied by the PowerShell packaging script
#endif

[Setup]
AppId={{90BECF43-3152-4F61-BDBA-8B77CB2F455A}
AppName=MissionBook
AppVersion={#AppVersion}
AppPublisher=MissionBook
DefaultDirName={localappdata}\Programs\MissionBook
UsePreviousAppDir=yes
UseSetupLdr=no
DefaultGroupName=MissionBook
DisableProgramGroupPage=yes
DisableDirPage=no
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
WizardResizable=yes
SetupIconFile=..\..\..\windows\runner\resources\app_icon.ico
UninstallDisplayName=MissionBook
UninstallDisplayIcon={app}\mission_book.exe
AppMutex=Local\MissionBook.SingleInstance
CloseApplications=yes
CloseApplicationsFilter=mission_book.exe
OutputDir={#OutputDir}
OutputBaseFilename=MissionBook-Setup-{#AppVersion}-Windows-x64
Compression=lzma2/normal
SolidCompression=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
english.AdditionalTasks=Additional options:
english.CreateDesktopShortcut=Create a desktop shortcut

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopShortcut}"; GroupDescription: "{cm:AdditionalTasks}"; Flags: unchecked

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\MissionBook"; Filename: "{app}\mission_book.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\MissionBook"; Filename: "{app}\mission_book.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\mission_book.exe"; Description: "{cm:LaunchProgram,MissionBook}"; WorkingDir: "{app}"; Flags: postinstall nowait skipifsilent

