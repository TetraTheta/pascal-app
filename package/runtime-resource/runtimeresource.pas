{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit runtimeresource;

{$warn 5023 off : no warning about unused units}
interface

uses
  runtime_resource, register_runtime_resource, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('register_runtime_resource', @register_runtime_resource.Register);
end;

initialization
  RegisterPackage('RuntimeResource', @Register);
end.
