unit runtime_resource;

{$mode objfpc}{$H+}

interface

uses
  Buttons, Classes, ExtCtrls;

type
  TResourceFileResolver = function(const AFileName: string): string;

  { TRuntimeResourceImage previews a project image and loads its RCDATA at runtime. }
  TRuntimeResourceImage = class(TImage)
  private
    FResourceName: string;
    FSourceFile: string;
    procedure RefreshImage;
    procedure SetResourceName(const AValue: string);
    procedure SetSourceFile(const AValue: string);
  protected
    procedure Loaded; override;
  published
    property Picture stored False;
    property ResourceName: string read FResourceName write SetResourceName;
    property SourceFile: string read FSourceFile write SetSourceFile;
  end;

  { TRuntimeResourceBitBtn previews a project glyph and loads its RCDATA at runtime. }
  TRuntimeResourceBitBtn = class(TBitBtn)
  private
    FResourceName: string;
    FSourceFile: string;
    procedure RefreshImage;
    procedure SetResourceName(const AValue: string);
    procedure SetSourceFile(const AValue: string);
  protected
    procedure Loaded; override;
  published
    property Glyph stored False;
    property ResourceName: string read FResourceName write SetResourceName;
    property SourceFile: string read FSourceFile write SetSourceFile;
  end;

  { TRuntimeResourceSpeedButton previews a project glyph and loads its RCDATA at runtime. }
  TRuntimeResourceSpeedButton = class(TSpeedButton)
  private
    FResourceName: string;
    FSourceFile: string;
    procedure RefreshImage;
    procedure SetResourceName(const AValue: string);
    procedure SetSourceFile(const AValue: string);
  protected
    procedure Loaded; override;
  published
    property Glyph stored False;
    property ResourceName: string read FResourceName write SetResourceName;
    property SourceFile: string read FSourceFile write SetSourceFile;
  end;

var
  DesignFileResolver: TResourceFileResolver;

implementation

uses
  Graphics, SysUtils, Windows;

function LoadPng(const ASourceFile, AResourceName: string; const ADesigning: Boolean): TPortableNetworkGraphic;
var
  FileName: string;
  Resource: TResourceStream;
begin
  Result := nil;
  if ADesigning then
  begin
    if (ASourceFile = '') or not Assigned(DesignFileResolver) then
      Exit;
    FileName := DesignFileResolver(ASourceFile);
    if not FileExists(FileName) then
      Exit;
    Result := TPortableNetworkGraphic.Create;
    try
      Result.LoadFromFile(FileName);
    except
      FreeAndNil(Result);
      raise;
    end;
  end
  else if AResourceName <> '' then
  begin
    Resource := TResourceStream.Create(HInstance, AResourceName, RT_RCDATA);
    try
      Result := TPortableNetworkGraphic.Create;
      try
        Result.LoadFromStream(Resource);
      except
        FreeAndNil(Result);
        raise;
      end;
    finally
      Resource.Free;
    end;
  end;
end;

procedure TRuntimeResourceImage.Loaded;
begin
  inherited Loaded;
  RefreshImage;
end;

procedure TRuntimeResourceImage.RefreshImage;
var
  Png: TPortableNetworkGraphic;
begin
  if csLoading in ComponentState then
    Exit;
  Png := LoadPng(FSourceFile, FResourceName, csDesigning in ComponentState);
  try
    if Assigned(Png) then
      Picture.Assign(Png)
    else
      Picture.Clear;
  finally
    Png.Free;
  end;
end;

procedure TRuntimeResourceImage.SetResourceName(const AValue: string);
begin
  if FResourceName = AValue then
    Exit;
  FResourceName := AValue;
  RefreshImage;
end;

procedure TRuntimeResourceImage.SetSourceFile(const AValue: string);
begin
  if FSourceFile = AValue then
    Exit;
  FSourceFile := AValue;
  RefreshImage;
end;

procedure TRuntimeResourceBitBtn.Loaded;
begin
  inherited Loaded;
  RefreshImage;
end;

procedure TRuntimeResourceBitBtn.RefreshImage;
var
  Png: TPortableNetworkGraphic;
begin
  if csLoading in ComponentState then
    Exit;
  Png := LoadPng(FSourceFile, FResourceName, csDesigning in ComponentState);
  try
    Glyph.Assign(Png);
  finally
    Png.Free;
  end;
end;

procedure TRuntimeResourceBitBtn.SetResourceName(const AValue: string);
begin
  if FResourceName = AValue then
    Exit;
  FResourceName := AValue;
  RefreshImage;
end;

procedure TRuntimeResourceBitBtn.SetSourceFile(const AValue: string);
begin
  if FSourceFile = AValue then
    Exit;
  FSourceFile := AValue;
  RefreshImage;
end;

procedure TRuntimeResourceSpeedButton.Loaded;
begin
  inherited Loaded;
  RefreshImage;
end;

procedure TRuntimeResourceSpeedButton.RefreshImage;
var
  Png: TPortableNetworkGraphic;
begin
  if csLoading in ComponentState then
    Exit;
  Png := LoadPng(FSourceFile, FResourceName, csDesigning in ComponentState);
  try
    Glyph.Assign(Png);
  finally
    Png.Free;
  end;
end;

procedure TRuntimeResourceSpeedButton.SetResourceName(const AValue: string);
begin
  if FResourceName = AValue then
    Exit;
  FResourceName := AValue;
  RefreshImage;
end;

procedure TRuntimeResourceSpeedButton.SetSourceFile(const AValue: string);
begin
  if FSourceFile = AValue then
    Exit;
  FSourceFile := AValue;
  RefreshImage;
end;

end.
