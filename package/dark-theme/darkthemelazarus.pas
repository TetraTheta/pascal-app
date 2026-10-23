{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit darkthemelazarus;

{$warn 5023 off : no warning about unused units}
interface

uses
  registerDarkThemeLazarus, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('registerDarkThemeLazarus', @registerDarkThemeLazarus.Register
    );
end;

initialization
  RegisterPackage('DarkThemeLazarus', @Register);
end.
