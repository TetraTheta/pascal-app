unit launch_arguments_dialog;

{$MODE objfpc}
{$H+}

interface

uses
  Classes,
  Forms,
  StdCtrls;

type
  TLaunchArgumentsDialog = class(TForm)
    ArgumentsMemo: TMemo;
    CopyButton: TButton;
    OKButton: TButton;
    procedure CopyClick(Sender: TObject);
  end;

procedure ShowLaunchArgumentsDialog(AArguments: TStrings);

var
  LaunchArgumentsDialog: TLaunchArgumentsDialog;

implementation

{$R *.lfm}

uses
  Clipbrd;

procedure TLaunchArgumentsDialog.CopyClick(Sender: TObject);
begin
  Clipboard.AsText := ArgumentsMemo.Text;
end;

procedure ShowLaunchArgumentsDialog(AArguments: TStrings);
var
  Dialog: TLaunchArgumentsDialog;
begin
  Dialog := TLaunchArgumentsDialog.Create(nil);
  try
    Dialog.ArgumentsMemo.Lines.Assign(AArguments);
    Dialog.ShowModal;
  finally
    Dialog.Free;
  end;
end;

end.
