unit keyvalues;

{$MODE objfpc}
{$H+}

interface

uses
  Classes,
  SysUtils,
  Contnrs;

type
  { An ordered KeyValues tree; duplicate keys remain separate children. }
  TKeyValue = class
  public
    Name: string;
    Value: string;
    Children: TObjectList;
    constructor Create(const AName: string = ''; const AValue: string = '');
    destructor Destroy; override;
    function Child(const AName: string): TKeyValue;
    function Text(const AName: string): string;
  end;

{ Parses text or raises EConvertError for incomplete or malformed input. }
function ParseKeyValues(const AText: string): TKeyValue;
function ReadKeyValues(const AFileName: string): TKeyValue;

implementation

constructor TKeyValue.Create(const AName, AValue: string);
begin
  inherited Create;
  Name := AName;
  Value := AValue;
  Children := TObjectList.Create(True);
end;

destructor TKeyValue.Destroy;
begin
  Children.Free;
  inherited Destroy;
end;

function TKeyValue.Child(const AName: string): TKeyValue;
var
  I: Integer;
begin
  for I := 0 to Children.Count - 1 do
    if SameText(TKeyValue(Children[I]).Name, AName) then
      Exit(TKeyValue(Children[I]));
  Result := nil;
end;

function TKeyValue.Text(const AName: string): string;
var
  Node: TKeyValue;
begin
  Node := Child(AName);
  if Assigned(Node) then
    Result := Node.Value
  else
    Result := '';
end;

function ParseKeyValues(const AText: string): TKeyValue;
var
  Position: SizeInt;
  Token: string;
  Structural: Boolean;

  function Next: Boolean;
  var
    Start: SizeInt;
  begin
    Token := '';
    Structural := False;
    while Position <= Length(AText) do begin
      if AText[Position] <= ' ' then
        Inc(Position)
      else if (AText[Position] = '/') and (Copy(AText, Position, 2) = '//') then begin
        while (Position <= Length(AText)) and not (AText[Position] in [#10, #13]) do
          Inc(Position);
      end
      else
        Break;
    end;
    if Position > Length(AText) then
      Exit(False);
    if AText[Position] in ['{', '}'] then begin
      Token := AText[Position];
      Structural := True;
      Inc(Position);
    end
    else if AText[Position] = '"' then begin
      Inc(Position);
      while (Position <= Length(AText)) and (AText[Position] <> '"') do begin
        if (AText[Position] = '\') and (Position < Length(AText)) and (AText[Position + 1] in ['\', '"']) then
          Inc(Position);
        Token := Token + AText[Position];
        Inc(Position);
      end;
      if Position > Length(AText) then
        raise EConvertError.Create('Unterminated KeyValues string.');
      Inc(Position);
    end
    else begin
      Start := Position;
      while (Position <= Length(AText)) and (AText[Position] > ' ') and not (AText[Position] in ['{', '}']) do
        Inc(Position);
      Token := Copy(AText, Start, Position - Start);
    end;
    Result := True;
  end;

  procedure ReadChildren(AParent: TKeyValue; ANested: Boolean; ADepth: Integer);
  var
    Key: string;
    Node: TKeyValue;
  begin
    if ADepth > 64 then
      raise EConvertError.Create('KeyValues nesting is too deep.');
    while Next do begin
      if Structural then begin
        if (Token = '}') and ANested then
          Exit;
        raise EConvertError.Create('Unexpected KeyValues brace.');
      end;
      Key := Token;
      if not Next then
        raise EConvertError.Create('Missing KeyValues value.');
      Node := TKeyValue.Create(Key);
      AParent.Children.Add(Node);
      if Structural then begin
        if Token <> '{' then
          raise EConvertError.Create('Missing KeyValues value.');
        ReadChildren(Node, True, ADepth + 1);
      end
      else
        Node.Value := Token;
    end;
    if ANested then
      raise EConvertError.Create('Unclosed KeyValues block.');
  end;

begin
  Position := 1;
  if Copy(AText, 1, 3) = #$EF#$BB#$BF then
    Position := 4;
  Result := TKeyValue.Create;
  try
    ReadChildren(Result, False, 0);
  except
    Result.Free;
    raise;
  end;
end;

function ReadKeyValues(const AFileName: string): TKeyValue;
var
  Stream: TFileStream;
  Content: string;
begin
  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  try
    if Stream.Size > 8 * 1024 * 1024 then
      raise EConvertError.Create('KeyValues file exceeds 8 MiB.');
    SetLength(Content, Stream.Size);
    if Content <> '' then
      Stream.ReadBuffer(Content[1], Length(Content));
    Result := ParseKeyValues(Content);
  finally
    Stream.Free;
  end;
end;

end.
