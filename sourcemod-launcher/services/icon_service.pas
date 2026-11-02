unit icon_service;

{$MODE objfpc}
{$H+}

interface

uses
  Graphics;

{ Loads a 16x16 TGA, falling back to the supplied embedded PNG. }
procedure LoadModIcon(const AFileName: string; AFallback: TPortableNetworkGraphic; ATarget: TPortableNetworkGraphic);

implementation

uses
  Classes,
  SysUtils,
  FPImage,
  FPReadTGA,
  IntfGraphics,
  GraphType;

type
  TAlphaTargaReader = class(TFPReaderTarga)
  protected
    procedure WriteScanLine(Row: Integer; Img: TFPCustomImage); override;
  end;

procedure TAlphaTargaReader.WriteScanLine(Row: Integer; Img: TFPCustomImage);
var
  X: Integer;
  Color: TFPColor;
begin
  inherited WriteScanLine(Row, Img);
  // FPC 3.2.2 thresholds TGA alpha; retain the original eight-bit channel.
  if (BytesPerPixel = 32) and (AlphaBits = 8) then
    for X := 0 to Img.Width - 1 do begin
      Color := Img.Colors[X, Row];
      Color.Alpha := FScanLine[X * 4 + 3] * 257;
      Img.Colors[X, Row] := Color;
    end;
end;

procedure LoadModIcon(const AFileName: string; AFallback: TPortableNetworkGraphic; ATarget: TPortableNetworkGraphic);
var
  Stream: TFileStream;
  Header: array[0..17] of Byte;
  Image: TLazIntfImage;
  Reader: TFPReaderTarga;
begin
  ATarget.Assign(AFallback);
  if (AFileName = '') or not FileExists(AFileName) then
    Exit;
  try
    Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
    try
      Stream.ReadBuffer(Header, SizeOf(Header));
      if (Header[2] <> 2) or (Header[12] <> 16) or (Header[13] <> 0) or (Header[14] <> 16) or (Header[15] <> 0) or not (Header[16] in [24, 32]) then
        Exit;
      Stream.Position := 0;
      Image := TLazIntfImage.Create(0, 0, [riqfRGB, riqfAlpha]);
      Reader := TAlphaTargaReader.Create;
      try
        Image.LoadFromStream(Stream, Reader);
        ATarget.LoadFromIntfImage(Image);
      finally
        Reader.Free;
        Image.Free;
      end;
    finally
      Stream.Free;
    end;
  except
    on E: Exception do
      ATarget.Assign(AFallback);
  end;
end;

end.
