#define AppName "FluxShare"
#define AppVersion "1.0.0"
#ifndef BuildDir
  #define BuildDir "..\build\windows\x64\runner\Release"
#endif
#ifndef InstallerOut
  #define InstallerOut "..\dist"
#endif

[Setup]
AppId={{AF0889C0-58AD-4F30-BA41-8CF2DA7E960A}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=FluxShare
DefaultDirName={autopf}\FluxShare
DefaultGroupName=FluxShare
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
DisableProgramGroupPage=yes
OutputDir={#InstallerOut}
OutputBaseFilename=FluxShare-Setup-x64
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\fluxshare.exe

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\FluxShare"; Filename: "{app}\fluxshare.exe"
Name: "{autodesktop}\FluxShare"; Filename: "{app}\fluxshare.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\fluxshare.exe"; Description: "Launch FluxShare"; Flags: postinstall nowait skipifsilent
