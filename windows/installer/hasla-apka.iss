; Instalator Hasła apka dla Windows (Inno Setup 6).
; Budowany automatycznie na GitHubie: iscc /DAppVersion=1.2.3 windows\installer\hasla-apka.iss

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

[Setup]
AppId={{6B0C7E52-3D7B-4F3A-9C2E-5A1D8E4B7F10}
AppName=Hasła apka
AppVersion={#AppVersion}
AppPublisher=Mitrix89
DefaultDirName={localappdata}\Programs\Hasla apka
DefaultGroupName=Hasła apka
DisableProgramGroupPage=yes
; Instalacja tylko dla bieżącego użytkownika: nie wymaga uprawnień administratora.
PrivilegesRequired=lowest
OutputDir=..\..\build\installer
OutputBaseFilename=HaslaApka-Setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\hasla_apka.exe
SetupIconFile=..\runner\resources\app_icon.ico

[Languages]
Name: "polish"; MessagesFile: "compiler:Languages\Polish.isl"

[Tasks]
Name: "desktopicon"; Description: "Utwórz skrót na pulpicie"; GroupDescription: "Skróty:"

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Hasła apka"; Filename: "{app}\hasla_apka.exe"
Name: "{autodesktop}\Hasła apka"; Filename: "{app}\hasla_apka.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\hasla_apka.exe"; Description: "Uruchom Hasła apka"; Flags: nowait postinstall skipifsilent
