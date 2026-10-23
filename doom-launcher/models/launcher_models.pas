unit launcher_models;

{$MODE objfpc}
{$H+}

interface

uses
  Classes,
  Contnrs,
  SysUtils;

type
  TStoredPath = record
    Value: string;
    IsAbsolute: Boolean;
  end;

  TEngine = class
  public
    DisplayName: string;
    FileName: TStoredPath;
    constructor Create(const ADisplayName: string; const AFileName: TStoredPath);
  end;

  TDataDirectory = class
  public
    DisplayName: string;
    DirectoryName: TStoredPath;
    IsReadOnly: Boolean;
    StoreDiscoveredPathsAbsolute: Boolean;
    constructor Create(const ADisplayName: string; const ADirectoryName: TStoredPath; AIsReadOnly: Boolean = False);
  end;

  TWadMetadata = class
  public
    FileName: TStoredPath;
    FileSize: Int64;
    HasMaps: Boolean;
    IsIWad: Boolean;
    MapIds: TStringList;
    ModifiedAt: TDateTime;
    constructor Create;
    destructor Destroy; override;
    function DisplayName: string;
  end;

  TLaunchOptions = record
    EnableMultiplayer: Boolean;
    FastMonsters: Boolean;
    HostGame: Boolean;
    HostName: string;
    NoMonsters: Boolean;
    PlayerCount: Integer;
    Port: Integer;
    RespawnMonsters: Boolean;
    Skill: Integer;
    StartMap: string;
  end;

  TProfile = class
  private
    FMods: TStringList;
  public
    EnginePath: TStoredPath;
    ExtraArguments: string;
    IWadPath: TStoredPath;
    Locked: Boolean;
    Name: string;
    Options: TLaunchOptions;
    constructor Create;
    destructor Destroy; override;
    procedure Assign(AProfile: TProfile);
    function Clone: TProfile;
    property Mods: TStringList read FMods;
  end;

  TLauncherSettings = class
  public
    DataDirectories: TObjectList;
    Engines: TObjectList;
    ExitAfterLaunch: Boolean;
    Profiles: TObjectList;
    SelectedProfileIndex: Integer;
    WadCache: TObjectList;
    constructor Create;
    destructor Destroy; override;
  end;

function DefaultLaunchOptions: TLaunchOptions;
function StoredPath(const AValue: string; AIsAbsolute: Boolean): TStoredPath;

implementation

function DefaultLaunchOptions: TLaunchOptions;
begin
  Result.EnableMultiplayer := False;
  Result.FastMonsters := False;
  Result.HostGame := False;
  Result.HostName := '';
  Result.NoMonsters := False;
  Result.PlayerCount := 4;
  Result.Port := 10666;
  Result.RespawnMonsters := False;
  Result.Skill := 3;
  Result.StartMap := '';
end;

function StoredPath(const AValue: string; AIsAbsolute: Boolean): TStoredPath;
begin
  Result.Value := AValue;
  Result.IsAbsolute := AIsAbsolute;
end;

constructor TEngine.Create(const ADisplayName: string; const AFileName: TStoredPath);
begin
  inherited Create;
  DisplayName := ADisplayName;
  FileName := AFileName;
end;

constructor TDataDirectory.Create(const ADisplayName: string; const ADirectoryName: TStoredPath; AIsReadOnly: Boolean);
begin
  inherited Create;
  DisplayName := ADisplayName;
  DirectoryName := ADirectoryName;
  IsReadOnly := AIsReadOnly;
  StoreDiscoveredPathsAbsolute := ADirectoryName.IsAbsolute;
end;

constructor TWadMetadata.Create;
begin
  inherited Create;
  MapIds := TStringList.Create;
  MapIds.CaseSensitive := False;
  MapIds.Sorted := True;
  MapIds.Duplicates := dupIgnore;
end;

destructor TWadMetadata.Destroy;
begin
  MapIds.Free;
  inherited Destroy;
end;

function TWadMetadata.DisplayName: string;
begin
  Result := ExtractFileName(FileName.Value);
end;

constructor TProfile.Create;
begin
  inherited Create;
  FMods := TStringList.Create;
  Options := DefaultLaunchOptions;
end;

destructor TProfile.Destroy;
begin
  FMods.Free;
  inherited Destroy;
end;

procedure TProfile.Assign(AProfile: TProfile);
begin
  EnginePath := AProfile.EnginePath;
  ExtraArguments := AProfile.ExtraArguments;
  IWadPath := AProfile.IWadPath;
  Locked := AProfile.Locked;
  Name := AProfile.Name;
  Options := AProfile.Options;
  FMods.Assign(AProfile.Mods);
end;

function TProfile.Clone: TProfile;
begin
  Result := TProfile.Create;
  Result.Assign(Self);
end;

constructor TLauncherSettings.Create;
begin
  inherited Create;
  DataDirectories := TObjectList.Create(True);
  Engines := TObjectList.Create(True);
  Profiles := TObjectList.Create(True);
  WadCache := TObjectList.Create(True);
  SelectedProfileIndex := -1;
end;

destructor TLauncherSettings.Destroy;
begin
  WadCache.Free;
  Profiles.Free;
  Engines.Free;
  DataDirectories.Free;
  inherited Destroy;
end;

end.
