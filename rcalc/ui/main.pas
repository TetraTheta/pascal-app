unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Spin, StdCtrls;

type
  { TFloatSpinEdit }

  // Lazarus 디자이너에는 기본 TFloatSpinEdit로 보이게 두되,
  // 이 유닛 안에서는 같은 이름의 클래스로 가로채 표시 형식만 바꾼다.
  // 이런 패턴을 interposer class라고 부른다.
  TFloatSpinEdit = class(Spin.TFloatSpinEdit)
  public
    function ValueToStr(const AValue: Double): string; override;
  end;

  { TMainForm }

  TMainForm = class(TForm)
    buttonCalculate: TButton;
    labelA: TLabel;
    labelB: TLabel;
    labelX: TLabel;
    labelY: TLabel;
    listBoxResult: TListBox;
    numericUpDownA: TFloatSpinEdit;
    numericUpDownB: TFloatSpinEdit;
    numericUpDownX: TFloatSpinEdit;
    numericUpDownY: TFloatSpinEdit;
    textBoxResult: TEdit;
    procedure buttonCalculateClick(Sender: TObject);
    procedure listBoxResultDblClick(Sender: TObject);
  private
    procedure AddList(const S: string);
    procedure Calculate(const AddToList: Boolean = False);
    procedure ConfigureSpinEdits;
    function TryReadResult(const S: string; out X, Y, A, B: Double): Boolean;
  public
    procedure InitializeValues(const X, Y, A: Double);
  end;

var
  MainForm: TMainForm;

implementation

// main.lfm에 저장된 폼/컨트롤 배치를 이 유닛의 TMainForm과 연결한다.
{$R *.lfm}

const
  // TFloatSpinEdit.DecimalPlaces는 표시뿐 아니라 값 반올림에도 영향을 준다.
  // 입력 정밀도를 보존하려고 넉넉히 열고, 실제 표시는 ValueToStr에서 정리한다.
  MaxDecimalPlaces = 15;

function CleanFloat(const Value: Double): string;
begin
  Result := FormatFloat('0.###############', Value);
end;

{ TFloatSpinEdit }

// Spin.TFloatSpinEdit의 virtual 메서드를 override한다.
// LCL이 컨트롤 텍스트를 갱신할 때 이 메서드를 호출하므로,
// 이벤트에서 Text를 고치는 것보다 안정적으로 trailing zero를 제거할 수 있다.
function TFloatSpinEdit.ValueToStr(const AValue: Double): string;
begin
  Result := CleanFloat(GetLimitedValue(AValue));
end;

{ TMainForm }

procedure TMainForm.buttonCalculateClick(Sender: TObject);
begin
  Calculate(True);
end;

procedure TMainForm.listBoxResultDblClick(Sender: TObject);
var
  A: Double;
  B: Double;
  X: Double;
  Y: Double;
begin
  if listBoxResult.ItemIndex < 0 then Exit;

  // 결과 문자열의 방정식 부분을 다시 입력값으로 복원한다.
  // 원본 WinForms 앱도 ListBox 항목 더블클릭에서 같은 흐름을 사용한다.
  if not TryReadResult(listBoxResult.Items[listBoxResult.ItemIndex], X, Y, A, B) then
  begin
    MessageDlg('Failed to parse result with regex!', mtError, [mbOK], 0);
    Exit;
  end;

  numericUpDownX.Value := X;
  numericUpDownY.Value := Y;
  numericUpDownA.Value := A;
  Calculate(False);
end;

procedure TMainForm.AddList(const S: string);
var
  I: Integer;
begin
  for I := 0 to listBoxResult.Items.Count - 1 do
  begin
    if S <> listBoxResult.Items[I] then Continue;
    listBoxResult.ItemIndex := I;
    Exit;
  end;

  listBoxResult.Items.Add(S);
  listBoxResult.ItemIndex := listBoxResult.Items.Count - 1;
end;

procedure TMainForm.Calculate(const AddToList: Boolean);
var
  A: Double;
  B: Double;
  ResultText: string;
  X: Double;
  Y: Double;
begin
  X := numericUpDownX.Value;
  Y := numericUpDownY.Value;
  A := numericUpDownA.Value;

  if (X = 0) or (Y = 0) or (A = 0) then
  begin
    textBoxResult.Text := 'ERROR: You can''t have 0 for ratio calculation!';
    Exit;
  end;

  B := Y / X * A;
  ResultText :=
    'Result: ' + CleanFloat(B) +
    ' / Equation: [' + CleanFloat(X) +
    ' : ' + CleanFloat(Y) +
    '] = [' + CleanFloat(A) +
    ' : ' + CleanFloat(B) + ']';

  numericUpDownB.Value := B;
  textBoxResult.Text := ResultText;
  if AddToList then AddList(ResultText);
end;

procedure TMainForm.ConfigureSpinEdits;
begin
  // .lfm에도 같은 값이 있지만, IDE에서 속성이 바뀌어도 런타임 정책은 유지한다.
  numericUpDownA.DecimalPlaces := MaxDecimalPlaces;
  numericUpDownB.DecimalPlaces := MaxDecimalPlaces;
  numericUpDownX.DecimalPlaces := MaxDecimalPlaces;
  numericUpDownY.DecimalPlaces := MaxDecimalPlaces;
end;

function TMainForm.TryReadResult(const S: string; out X, Y, A, B: Double): Boolean;

  function TryReadPair(const Pair: string; out First, Second: Double): Boolean;
  var
    ColonPos: SizeInt;
  begin
    ColonPos := Pos(':', Pair);
    Result :=
      (ColonPos > 0) and
      TryStrToFloat(Trim(Copy(Pair, 1, ColonPos - 1)), First) and
      TryStrToFloat(Trim(Copy(Pair, ColonPos + 1, Length(Pair))), Second);
  end;

var
  LeftClose: SizeInt;
  LeftOpen: SizeInt;
  RightClose: SizeInt;
  RightOpen: SizeInt;
begin
  LeftOpen := Pos('[', S);
  LeftClose := Pos(']', S);
  RightOpen := Pos('[', Copy(S, LeftClose + 1, Length(S)));
  if RightOpen > 0 then Inc(RightOpen, LeftClose);
  RightClose := Pos(']', Copy(S, RightOpen + 1, Length(S)));
  if RightClose > 0 then Inc(RightClose, RightOpen);

  Result :=
    (LeftOpen > 0) and
    (LeftClose > LeftOpen) and
    (RightOpen > LeftClose) and
    (RightClose > RightOpen) and
    TryReadPair(Copy(S, LeftOpen + 1, LeftClose - LeftOpen - 1), X, Y) and
    TryReadPair(Copy(S, RightOpen + 1, RightClose - RightOpen - 1), A, B);
end;

procedure TMainForm.InitializeValues(const X, Y, A: Double);
begin
  ConfigureSpinEdits;
  numericUpDownX.Value := X;
  numericUpDownY.Value := Y;
  numericUpDownA.Value := A;
  Calculate(True);
end;

end.

