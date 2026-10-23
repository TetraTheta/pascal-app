unit register_runtime_resource;

{$MODE objfpc}
{$H+}

interface

procedure Register;

implementation

uses
  Classes,
  SysUtils,
  LazIDEIntf,
  runtime_resource;

function ResolveProjectFile(const AFileName: string): string;
begin
  Result := '';
  if Assigned(LazarusIDE) and Assigned(LazarusIDE.ActiveProject) then
    Result := ExpandFileName(IncludeTrailingPathDelimiter(LazarusIDE.ActiveProject.Directory) + AFileName);
end;

procedure Register;
begin
  DesignFileResolver := @ResolveProjectFile;
  RegisterComponents('Runtime Resource', [TRuntimeResourceImage, TRuntimeResourceBitBtn, TRuntimeResourceSpeedButton]);
end;

end.
